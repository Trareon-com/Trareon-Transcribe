//! Session registry: tracks live capture sessions by UUID and their
//! mic/speaker toggle state. The same module owns crash recovery.
//!
//! # What survives a crash
//!
//! Each live session gets a directory under the OS config dir:
//!
//! ```text
//! <config>/TrareonTranscribe/recovery/<session-id>/
//!     snapshot.json      session config, timings, title, segment count
//!     transcript.jsonl   every finalized segment, appended as it is emitted
//!     mic.wav.part       captured audio, streamed, header fixed up on stop
//!     speaker.wav.part
//! ```
//!
//! Before this, the snapshot held configuration only — so recovery restored
//! a session with `segments: []` and no audio, while the UI banner told the
//! user the session could be recovered. A crash in the second hour of a
//! meeting lost the meeting.
//!
//! Recovery reopens all three: the journal is replayed into the segment
//! list, the `.part` files are reopened and appended to (so the saved WAV
//! covers the whole meeting, not just the part after the restart), and new
//! segments are offset onto the end of the recovered timeline — a restarted
//! Whisper pipeline counts from zero again, and without the offset its
//! first segment would collide with the key of one recorded before the
//! crash.

use std::cell::RefCell;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{mpsc, Arc, Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

use serde::Serialize;
use uuid::Uuid;

use crate::audio::sink::{AudioSink, ChannelHealth, ClosedAudio, SILENCE_WARNING_SECS};
use crate::audio::wav_writer::{self, StreamingWavWriter};
use crate::audio::{AudioCapture, SessionConfig, SessionMode};
use crate::decode::TARGET_SAMPLE_RATE;
use crate::dedupe::is_echo;
use crate::error::TranscribeError;
use crate::export::Segment;
use crate::journal::{self, TranscriptJournal};
use crate::memory;
use crate::pipeline::{HptRoute, LiveEvent, LiveWorker, LiveWorkerConfig};

/// Files inside a session's recovery directory.
const SNAPSHOT_FILE: &str = "snapshot.json";
const JOURNAL_FILE: &str = "transcript.jsonl";
const MIC_AUDIO_FILE: &str = "mic.wav";
const SPEAKER_AUDIO_FILE: &str = "speaker.wav";

/// Captured audio is mono at the STT sample rate throughout.
const CAPTURE_CHANNELS: u16 = 1;

/// Long sessions (>4h) auto-split per hour to bound memory growth (PP-21).
pub const AUTO_SPLIT_INTERVAL_SECS: u64 = 3600;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum AutoSplitReason {
    TimeBoundary,
    MemoryPressure,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionStatus {
    pub session_id: String,
    pub elapsed_seconds: f64,
    pub mic_enabled: bool,
    pub speaker_enabled: bool,
    pub segments_count: u32,
    pub model_loaded: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum NoticeLevel {
    /// The session is running, but with less than the user asked for.
    Warning,
    /// Something the user asked for has stopped working.
    Error,
}

#[derive(Debug, Clone, Serialize)]
pub enum SessionEvent {
    Transcript(Segment),
    Vu {
        source: String,
        level: f32,
    },
    /// The live hypothesis' uncommitted tail, for the greyed "sementara"
    /// line under the transcript.
    ///
    /// LocalAgreement-2 only finalises words two consecutive decodes agree
    /// on (see [`crate::streaming`]); this is everything after that
    /// prefix. It replaces itself on every decode and an empty string
    /// clears it, so it is never appended to the transcript and never
    /// written to the journal.
    Tentative {
        source: String,
        text: String,
    },
    /// Something the user has to be told mid-session: a capture source that
    /// couldn't be opened, or one that died while recording. Previously these
    /// were only `tracing::warn!`ed, so a session that recorded nothing at all
    /// looked identical to one that was simply quiet.
    Notice {
        level: NoticeLevel,
        source: String,
        message: String,
    },
}

/// What happened when one source's capture was attempted at session start.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum CaptureAttempt {
    /// This source isn't part of the requested mode/toggles.
    Disabled,
    Started,
    Failed(String),
}

/// Whether a session with these capture outcomes should start, and what the
/// user needs to be told. Pure so the policy is unit-testable without a
/// sound card; see the tests at the bottom of this module.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum StartDecision {
    Proceed,
    /// Start anyway — at least one source works — but say what is missing.
    ProceedWithWarning(String),
    /// Refuse to start: nothing would be recorded. Failing here is what keeps
    /// the UI from sitting in "Memulai…" and then silently recording nothing.
    Fail(String),
}

/// Decides the above from the two per-source outcomes.
///
/// The rule that matters for "Rapat Online" (mic + system audio): one source
/// failing is a warning, not a failure — a meeting recorded from the speakers
/// alone is still worth having — but *both* failing must be an error, because
/// the alternative is a session that produces an empty transcript with no
/// explanation.
pub(crate) fn decide_start(mic: &CaptureAttempt, speaker: &CaptureAttempt) -> StartDecision {
    let sources = [("Mikrofon", mic), ("Audio sistem", speaker)];
    let failures: Vec<String> = sources
        .iter()
        .filter_map(|(label, attempt)| match attempt {
            CaptureAttempt::Failed(reason) => Some(format!("{label} — {reason}")),
            _ => None,
        })
        .collect();
    if failures.is_empty() {
        return StartDecision::Proceed;
    }

    let detail = failures.join("; ");
    if sources
        .iter()
        .any(|(_, attempt)| **attempt == CaptureAttempt::Started)
    {
        StartDecision::ProceedWithWarning(format!(
            "Sebagian sumber audio tidak dapat dibuka; rekaman berjalan tanpa sumber \
             tersebut. {detail}"
        ))
    } else {
        StartDecision::Fail(format!(
            "Sesi tidak dapat dimulai: tidak ada sumber audio yang berhasil dibuka. \
             {detail}"
        ))
    }
}

struct SessionState {
    session_id: String,
    config: SessionConfig,
    /// User-facing session title, mirrored here so the recovery dialog can
    /// name a crashed session instead of showing a UUID.
    title: String,
    started_at: std::time::Instant,
    started_at_unix_ms: u64,
    last_split_at: std::time::Instant,
    last_split_at_unix_ms: u64,
    segments_count: u32,
    /// Added to every incoming segment timestamp. Non-zero only for a
    /// recovered session: the pipeline restarts at t=0, and the recovered
    /// transcript already occupies that part of the timeline.
    resume_offset_secs: f64,
    /// Wall-clock the session had already accumulated before it crashed,
    /// so the elapsed timer continues rather than restarting at 00:00.
    recovered_elapsed_secs: f64,
    /// Append-only transcript journal. `None` only when it could not be
    /// opened at all — the session still records, it is simply not
    /// crash-recoverable, and that is said out loud via a notice.
    journal: Option<TranscriptJournal>,
    mic_capture: Option<CaptureChannel>,
    speaker_capture: Option<CaptureChannel>,
    pending_events: Vec<SessionEvent>,
    /// Segments emitted so far, across BOTH mic and speaker sources —
    /// this is where cross-source echo-dedupe actually happens, since
    /// each `LivePipeline` only ever sees its own source (see
    /// `pipeline` module doc comment). Trimmed to a rolling window.
    recent_emitted: Vec<Segment>,
    /// Device-health events (Sprint 13 B6); `None` if the watchdog could not
    /// be started. Drained in [`SessionState::collect_worker_events`].
    watchdog_rx: Option<mpsc::Receiver<crate::watchdog::WatchdogEvent>>,
    /// Shuts the watchdog thread down on [`stop_session`]. Dropping the
    /// sender would do the same (the thread's `try_recv` sees a closed
    /// channel), but sending an explicit stop avoids relying on that.
    watchdog_stop_tx: Option<mpsc::Sender<()>>,
}

/// Segments older than this relative to the newest one are dropped from
/// `recent_emitted` — keeps the dedupe window bounded for long sessions
/// without needing exact wall-clock bookkeeping.
const RECENT_EMITTED_WINDOW_SECS: f64 = 30.0;

struct CaptureChannel {
    /// Polled for a fatal stream error (see
    /// [`crate::audio::stream_error`]) as well as owning the capture thread.
    capture: AudioCapture,
    worker: LiveWorker,
    source: String,
    events_rx: mpsc::Receiver<LiveEvent>,
    /// Where this source's samples go: a streaming WAV in the recovery
    /// directory by default, a bounded RAM buffer when that could not be
    /// opened. Filled by the tee thread in `start_capture`, independent of
    /// the STT worker.
    sink: Arc<Mutex<AudioSink>>,
    /// How much audio this source has actually delivered, and when it was
    /// last above the noise floor.
    health: Arc<ChannelHealth>,
    /// Problems the tee thread cannot report itself (it has no access to
    /// the event queue): a disk write that failed, a RAM buffer that hit
    /// its cap. Drained into notices by `collect_worker_events`.
    sink_errors: Arc<Mutex<Vec<String>>>,
    /// Latches once a silence warning has been raised, so a dead source
    /// produces one notice and not one per poll. Re-armed when audio
    /// comes back.
    silence_warned: bool,
    /// Kept so the speaker channel can be respawned in place (same model,
    /// same language, same everything) when [`reopen_speaker_capture`]
    /// re-opens the stream after a `DeviceReconnected` watchdog event.
    worker_config: LiveWorkerConfig,
}

/// Audio a stopped session left behind, waiting for the caller (Dart, via
/// `api::export_session_audio`) to place it — the output directory and
/// title are only known at stop time, same as the transcript export.
#[derive(Debug, Default)]
#[flutter_rust_bridge::frb(ignore)]
pub struct StoppedAudio {
    /// Finished WAVs in the recovery directory, to be moved into the
    /// session folder. The common case.
    pub mic_file: Option<PathBuf>,
    pub speaker_file: Option<PathBuf>,
    /// Samples still in memory, from the RAM fallback path.
    pub mic_samples: Option<Vec<f32>>,
    pub speaker_samples: Option<Vec<f32>>,
}

impl StoppedAudio {
    fn is_empty(&self) -> bool {
        self.mic_file.is_none()
            && self.speaker_file.is_none()
            && self.mic_samples.is_none()
            && self.speaker_samples.is_none()
    }
}

fn audio_registry() -> &'static Mutex<HashMap<String, StoppedAudio>> {
    static REGISTRY: OnceLock<Mutex<HashMap<String, StoppedAudio>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Takes (removes) the audio retained for `session_id`. Returns an empty
/// [`StoppedAudio`] if the session had no live capture (never started, or
/// a batch-file transcription) or if this was already called for it.
#[flutter_rust_bridge::frb(ignore)]
pub fn take_session_audio(session_id: &str) -> StoppedAudio {
    audio_registry()
        .lock()
        .map(|mut reg| reg.remove(session_id).unwrap_or_default())
        .unwrap_or_default()
}

#[derive(Debug, Clone, Serialize, serde::Deserialize)]
pub struct SessionRecoverySnapshot {
    pub session_id: String,
    pub config: SessionConfig,
    pub started_at_unix_ms: u64,
    pub last_split_at_unix_ms: u64,
    pub segments_count: u32,
    /// User-facing title, so the recovery dialog can name the session.
    /// Defaulted for snapshots written before it existed.
    #[serde(default)]
    pub title: String,
    /// Last time this snapshot was rewritten — i.e. roughly when the app
    /// died. `updated_at - started_at` is the session's duration.
    #[serde(default)]
    pub updated_at_unix_ms: u64,
    /// Seconds of timeline already consumed by earlier runs of this
    /// session, carried forward so a session recovered twice keeps
    /// accumulating rather than restarting its clock.
    #[serde(default)]
    pub elapsed_secs: f64,
    /// Capture counters from earlier runs, so the integrity summary of a
    /// recovered session describes the whole meeting. Without these it
    /// reports the session's full duration next to only the seconds
    /// captured since the restart.
    #[serde(default)]
    pub mic_counters: ChannelCounters,
    #[serde(default)]
    pub speaker_counters: ChannelCounters,
}

/// How much audio one source has delivered, and how much of it was above
/// the noise floor. Persisted so it survives a crash.
#[derive(Debug, Clone, Copy, Default, Serialize, serde::Deserialize)]
pub struct ChannelCounters {
    pub total_samples: u64,
    pub voiced_samples: u64,
}

/// One entry in the recovery dialog: the snapshot plus what is actually
/// on disk for it. Computed at listing time rather than persisted, because
/// the honest answer to "what can be recovered" is whatever survived the
/// crash, not whatever the app last claimed.
#[derive(Debug, Clone, Serialize)]
pub struct RecoverableSession {
    pub snapshot: SessionRecoverySnapshot,
    /// Falls back to the session id when the session was never titled.
    pub title: String,
    pub started_at_unix_ms: u64,
    pub updated_at_unix_ms: u64,
    pub duration_secs: f64,
    /// Segments actually present in the journal — not the count the
    /// snapshot claimed, which is what the old banner reported.
    pub segment_count: u32,
    pub mic_audio_secs: f64,
    pub speaker_audio_secs: f64,
}

impl RecoverableSession {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn has_audio(&self) -> bool {
        self.mic_audio_secs > 0.0 || self.speaker_audio_secs > 0.0
    }

    /// Nothing worth offering the user: no transcript and no audio. These
    /// are cleaned up automatically rather than listed.
    fn is_empty(&self) -> bool {
        self.segment_count == 0 && !self.has_audio()
    }
}

/// What [`recover_session`] gives back: the restored session plus the
/// transcript that used to be silently dropped.
#[derive(Debug, Clone, Serialize)]
pub struct RecoveredSession {
    pub session_id: String,
    pub segments: Vec<Segment>,
    /// Where the restored timeline ends; new segments continue from here.
    pub resume_offset_secs: f64,
    pub mic_audio_secs: f64,
    pub speaker_audio_secs: f64,
}

/// Live capture health for one source. Drives both the "rekaman
/// terkonfirmasi" indicator during recording and the integrity summary at
/// Stop, so the two can never disagree.
#[derive(Debug, Clone, Serialize)]
pub struct ChannelCapture {
    /// `"mic"` or `"spk"`.
    pub source: String,
    /// Whether the user asked for this source at all.
    pub expected: bool,
    /// Audio above the noise floor has been observed. An open stream that
    /// has delivered nothing is *not* confirmed — that distinction is the
    /// whole point.
    pub confirmed: bool,
    pub seconds_captured: f64,
    pub seconds_voiced: f64,
    pub percent_silent: f64,
    /// How long this source has been below the noise floor.
    pub silent_for_secs: f64,
    /// False when this source fell back to (or was demoted to) RAM.
    pub writing_to_disk: bool,
    /// Seconds of captured audio the live worker has not transcribed yet.
    ///
    /// Zero on a device that keeps up. On one that does not this climbs for
    /// the whole meeting, and used to be invisible until Stop threw the
    /// backlog away — which is how a 6-minute recording ended up with 8
    /// seconds of transcript and no warning anywhere.
    pub lag_secs: f64,
}

/// Lag past which the live transcript is visibly behind the meeting and
/// the user is told. Below this it is ordinary inference latency.
pub const LAG_WARNING_SECS: f64 = 20.0;

/// Snapshot of a running session's capture health.
#[derive(Debug, Clone, Serialize)]
pub struct CaptureHealth {
    pub session_id: String,
    pub elapsed_secs: f64,
    pub segment_count: u32,
    pub channels: Vec<ChannelCapture>,
    /// Ready-to-show Indonesian warnings — an expected source that has
    /// delivered nothing, or one that has gone quiet for a long time.
    pub warnings: Vec<String>,
}

impl CaptureHealth {
    /// True once every expected source has delivered real audio. This is
    /// the "rekaman terkonfirmasi" state.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn all_expected_confirmed(&self) -> bool {
        let expected: Vec<_> = self.channels.iter().filter(|c| c.expected).collect();
        !expected.is_empty() && expected.iter().all(|c| c.confirmed)
    }
}

/// Pure decision logic — trivially unit-testable without real timers or a
/// real memory read.
fn should_split(elapsed_since_last_split_secs: u64, memory_ratio: f32) -> Option<AutoSplitReason> {
    if memory::is_under_memory_pressure(memory_ratio) {
        Some(AutoSplitReason::MemoryPressure)
    } else if elapsed_since_last_split_secs >= AUTO_SPLIT_INTERVAL_SECS {
        Some(AutoSplitReason::TimeBoundary)
    } else {
        None
    }
}

fn registry() -> &'static Mutex<HashMap<String, SessionState>> {
    static REGISTRY: OnceLock<Mutex<HashMap<String, SessionState>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

thread_local! {
    static RECOVERY_DIR_OVERRIDE: RefCell<Option<PathBuf>> = const { RefCell::new(None) };
}

#[cfg(test)]
pub(crate) fn set_recovery_dir_override(path: Option<PathBuf>) {
    RECOVERY_DIR_OVERRIDE.with(|slot| {
        *slot.borrow_mut() = path;
    });
}

pub fn start_session(config: SessionConfig) -> Result<String, TranscribeError> {
    let id = Uuid::new_v4().to_string();
    start_session_with_id(id, config, ResumeState::default())
}

/// Brings a crashed session back: its transcript, its audio, and its clock.
///
/// The transcript comes from the journal; the audio from the `.part` files,
/// which are reopened and appended to so the eventual WAV covers the whole
/// meeting. New segments are offset onto the end of the recovered timeline
/// — a restarted pipeline counts from zero, and the recovered transcript
/// already occupies that stretch, so without the offset the first new
/// segment would silently replace the first recovered one (they share the
/// `source@timestamp` merge key).
///
/// The offset is taken from the longest recovered audio track when there is
/// one, because that is how much real time the recording covers; the end of
/// the last recovered segment is the fallback for a RAM-path session.
pub fn recover_session(
    snapshot: SessionRecoverySnapshot,
) -> Result<RecoveredSession, TranscribeError> {
    let dir = session_recovery_dir(&snapshot.session_id)?;
    let segments = journal::replay(&dir.join(JOURNAL_FILE));
    let mic_audio_secs = recoverable_audio_secs(&dir, MIC_AUDIO_FILE);
    let speaker_audio_secs = recoverable_audio_secs(&dir, SPEAKER_AUDIO_FILE);
    let resume_offset_secs = mic_audio_secs
        .max(speaker_audio_secs)
        .max(journal::last_segment_end_secs(&segments));

    let resume = ResumeState {
        title: snapshot.title.clone(),
        segments: segments.clone(),
        resume_offset_secs,
        elapsed_secs: snapshot.elapsed_secs.max(resume_offset_secs),
        mic_counters: snapshot.mic_counters,
        speaker_counters: snapshot.speaker_counters,
    };
    let session_id = start_session_with_id(snapshot.session_id, snapshot.config, resume)?;

    Ok(RecoveredSession {
        session_id,
        segments,
        resume_offset_secs,
        mic_audio_secs,
        speaker_audio_secs,
    })
}

fn start_capture(
    enabled: bool,
    device_name: Option<String>,
    worker_config: LiveWorkerConfig,
    audio_path: Option<PathBuf>,
    resumed: ChannelCounters,
) -> Result<(Option<CaptureChannel>, CaptureAttempt), TranscribeError> {
    if !enabled {
        return Ok((None, CaptureAttempt::Disabled));
    }
    let source = worker_config.source.clone();
    let (raw_tx, raw_rx) = mpsc::channel();
    // Speaker (loopback) uses platform-specific capture (WASAPI / CoreAudio
    // Process Tap / PulseAudio monitor). Mic uses cpal, except on Linux with
    // a sound server, where it also goes through PulseAudio/PipeWire.
    let capture = match if source == "spk" {
        crate::audio::loopback::start_loopback(device_name, raw_tx)
    } else {
        AudioCapture::start(&source, device_name, raw_tx)
    } {
        Ok(c) => c,
        Err(e) => {
            // Reported, not swallowed: returning `Ok(None)` here is how a
            // "Rapat Online" session used to start with zero working capture
            // and no indication of it anywhere but the log.
            tracing::warn!(%source, %e, "capture could not be started");
            return Ok((None, CaptureAttempt::Failed(e.to_string())));
        }
    };

    // Disk is the default; RAM is the documented fallback for when the
    // recovery directory can't be written at all (read-only volume, no
    // space). Falling back is announced, not silent, because it changes
    // what a crash costs.
    let mut sink_errors: Vec<String> = Vec::new();
    let sink = match audio_path {
        Some(path) => match StreamingWavWriter::open(&path, TARGET_SAMPLE_RATE, CAPTURE_CHANNELS) {
            Ok(writer) => AudioSink::disk(writer),
            Err(e) => {
                tracing::warn!(%source, %e, "audio disk sink unavailable; using RAM fallback");
                sink_errors.push(format!(
                    "Audio {} tidak bisa ditulis ke disk ({e}); untuk sementara disimpan di \
                     memori dan tidak akan selamat dari crash.",
                    source_label(&source)
                ));
                AudioSink::ram()
            }
        },
        None => AudioSink::ram(),
    };
    let health = Arc::new(ChannelHealth::resumed(
        sink.is_disk(),
        resumed.total_samples,
        resumed.voiced_samples,
    ));
    let sink = Arc::new(Mutex::new(sink));
    let sink_errors = Arc::new(Mutex::new(sink_errors));

    let (worker, events_rx) = spawn_tee_and_worker(
        source.clone(),
        raw_rx,
        Arc::clone(&sink),
        Arc::clone(&health),
        Arc::clone(&sink_errors),
        worker_config.clone(),
    )?;
    Ok((
        Some(CaptureChannel {
            capture,
            worker,
            source,
            events_rx,
            sink,
            health,
            sink_errors,
            silence_warned: false,
            worker_config,
        }),
        CaptureAttempt::Started,
    ))
}

/// The tee thread (fan the raw stream out to the WAV sink / health counters
/// while also forwarding it to the STT worker) plus the worker itself.
///
/// Factored out of [`start_capture`] so [`reopen_speaker_capture`] can spawn
/// a fresh capture thread against the *same* sink/health/errors a session
/// already had open — re-opening the stream must not start a second WAV
/// file or reset the channel's health counters.
fn spawn_tee_and_worker(
    source: String,
    raw_rx: mpsc::Receiver<Vec<f32>>,
    sink: Arc<Mutex<AudioSink>>,
    health: Arc<ChannelHealth>,
    sink_errors: Arc<Mutex<Vec<String>>>,
    worker_config: LiveWorkerConfig,
) -> Result<(LiveWorker, mpsc::Receiver<LiveEvent>), TranscribeError> {
    let (samples_tx, samples_rx) = mpsc::channel::<Vec<f32>>();
    let tee_source = source.clone();
    // Isolated to its own thread so the live transcription pipeline
    // (samples_rx consumer) is untouched — this thread simply exits once
    // `raw_tx` (owned by AudioCapture) is dropped, i.e. when capture stops.
    std::thread::spawn(move || {
        while let Ok(chunk) = raw_rx.recv() {
            health.observe(&chunk, unix_ms_now().unwrap_or(0));
            if let Ok(mut sink) = sink.lock() {
                if let Err(e) = sink.append(&chunk, TARGET_SAMPLE_RATE) {
                    // Reported once (the sink latches), never fatal: losing
                    // the rest of the audio file must not also cost the
                    // transcript, and what is already on disk stays.
                    tracing::error!(source = %tee_source, %e, "captured audio could not be stored");
                    health.note_write_failure();
                    if let Ok(mut errors) = sink_errors.lock() {
                        errors.push(format!(
                            "Audio {} berhenti tersimpan: {e}. Transkrip tetap berjalan.",
                            source_label(&tee_source)
                        ));
                    }
                }
            }
            if samples_tx.send(chunk).is_err() {
                break;
            }
        }
    });

    let (events_tx, events_rx) = mpsc::channel();
    // A failure to load/init the STT pipeline (e.g. missing or corrupt model
    // file) MUST propagate so the caller surfaces it to the user instead of
    // silently starting a session that never transcribes anything.
    let worker = LiveWorker::spawn(worker_config, samples_rx, events_tx)?;
    Ok((worker, events_rx))
}

/// Re-opens the speaker (loopback) capture against whatever the OS default
/// output device is right now, reusing the session's existing WAV sink and
/// health counters so the audio file and `ChannelHealth` stay continuous.
///
/// Called when the watchdog reports `DeviceReconnected` (Sprint 13 B6): a
/// TWS/Bluetooth profile switch (A2DP↔HFP) or sleep/wake changes the
/// system's default sink, but the old `start_loopback` stream keeps reading
/// from the now-dead `<old-sink>.monitor` — silently, with no error, just
/// silence forever. The old stream is dropped here and a new one opened
/// against the current default, mirroring exactly what `start_capture` does
/// at session start.
fn reopen_speaker_capture(state: &mut SessionState) -> Option<SessionEvent> {
    if !state.config.speaker_enabled {
        return None;
    }
    let old = state.speaker_capture.take()?;
    let CaptureChannel {
        capture,
        worker,
        sink,
        health,
        sink_errors,
        worker_config,
        ..
    } = old;
    // Closes the old stream/process first: otherwise two loopback captures
    // (one dead, one new) could both try to read the same monitor source.
    drop(capture);
    drop(worker);

    let (raw_tx, raw_rx) = mpsc::channel();
    let device_name = state.config.speaker_device_id.clone();
    let new_capture = match crate::audio::loopback::start_loopback(device_name, raw_tx) {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!(%e, "speaker capture could not be re-opened after reconnect");
            return Some(SessionEvent::Notice {
                level: NoticeLevel::Error,
                source: "spk".to_string(),
                message: format!(
                    "Audio sistem tidak bisa dibuka ulang setelah perangkat tersambung \
                     kembali ({e}). Suara sistem berhenti terekam."
                ),
            });
        }
    };
    let (worker, events_rx) = match spawn_tee_and_worker(
        "spk".to_string(),
        raw_rx,
        Arc::clone(&sink),
        Arc::clone(&health),
        Arc::clone(&sink_errors),
        worker_config.clone(),
    ) {
        Ok(pair) => pair,
        Err(e) => {
            tracing::warn!(%e, "STT worker could not be respawned for the re-opened speaker capture");
            return Some(SessionEvent::Notice {
                level: NoticeLevel::Error,
                source: "spk".to_string(),
                message: format!(
                    "Audio sistem tersambung kembali tetapi transkripsinya gagal dimulai ulang ({e})."
                ),
            });
        }
    };
    state.speaker_capture = Some(CaptureChannel {
        capture: new_capture,
        worker,
        source: "spk".to_string(),
        events_rx,
        sink,
        health,
        sink_errors,
        silence_warned: false,
        worker_config,
    });
    tracing::info!("speaker capture re-opened after device reconnect");
    None
}

/// Indonesian label for a capture source, for user-facing messages.
fn source_label(source: &str) -> &'static str {
    if source == "spk" {
        "audio sistem"
    } else {
        "mikrofon"
    }
}

pub fn stop_session(session_id: &str) -> Result<(), TranscribeError> {
    let mut reg = registry()
        .lock()
        .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?;
    let mut state = reg
        .remove(session_id)
        .ok_or_else(|| TranscribeError::SessionNotFound(session_id.to_string()))?;
    drop(reg);

    if let Some(stop_tx) = state.watchdog_stop_tx.take() {
        let _ = stop_tx.send(());
    }

    // Last fsync before the journal is closed: everything emitted up to
    // this moment is on the platter, not merely in the page cache.
    if let Some(journal) = state.journal.as_mut() {
        let _ = journal.sync();
    }
    state.journal = None;

    let mut audio = StoppedAudio::default();
    // Dropping the capture first closes `raw_tx`, which ends the tee
    // thread — otherwise `close()` could race a chunk still in flight and
    // finalize a header that is already out of date.
    for (channel, is_mic) in [
        (state.mic_capture.take(), true),
        (state.speaker_capture.take(), false),
    ] {
        let Some(channel) = channel else { continue };
        let CaptureChannel {
            capture,
            worker,
            sink,
            ..
        } = channel;
        drop(capture);
        drop(worker);
        let Ok(mut guard) = sink.lock() else { continue };
        // Swap an empty sink in so the writer can be consumed by value.
        let closed = std::mem::replace(&mut *guard, AudioSink::ram()).close();
        match closed {
            Ok(ClosedAudio::File(Some(path))) if is_mic => audio.mic_file = Some(path),
            Ok(ClosedAudio::File(Some(path))) => audio.speaker_file = Some(path),
            Ok(ClosedAudio::Samples(samples)) if is_mic => audio.mic_samples = Some(samples),
            Ok(ClosedAudio::Samples(samples)) => audio.speaker_samples = Some(samples),
            Ok(ClosedAudio::File(None)) => {}
            Err(e) => tracing::error!(%e, "failed to finalize captured audio"),
        }
    }

    if !audio.is_empty() {
        if let Ok(mut audio_reg) = audio_registry().lock() {
            audio_reg.insert(session_id.to_string(), audio);
        }
    }

    // The snapshot and journal go now — the session is no longer
    // recoverable, it is finished. The finalized WAVs stay put until
    // `export_session_audio` moves them into the session folder, which
    // happens after the transcript export and therefore after this call.
    retire_recovery_state(session_id)
}

pub fn toggle_mic(session_id: &str, enabled: bool) -> Result<(), TranscribeError> {
    with_session_mut(session_id, |s| s.config.mic_enabled = enabled)?;
    persist_session_snapshot(session_id)
}

pub fn toggle_speaker(session_id: &str, enabled: bool) -> Result<(), TranscribeError> {
    with_session_mut(session_id, |s| s.config.speaker_enabled = enabled)?;
    persist_session_snapshot(session_id)
}

pub fn set_session_mode(session_id: &str, mode: SessionMode) -> Result<(), TranscribeError> {
    with_session_mut(session_id, |s| {
        let (mic, spk) = mode.default_toggles();
        s.config.mode = mode;
        s.config.mic_enabled = mic;
        s.config.speaker_enabled = spk;
    })?;
    persist_session_snapshot(session_id)
}

pub fn record_segment(session_id: &str) -> Result<(), TranscribeError> {
    with_session_mut(session_id, |s| s.segments_count += 1)?;
    persist_session_snapshot(session_id)
}

/// Mirrors the user-entered session title into the recovery snapshot, so a
/// crashed session shows up in the recovery dialog under the name the user
/// gave it rather than as a UUID.
pub fn set_session_title(session_id: &str, title: &str) -> Result<(), TranscribeError> {
    with_session_mut(session_id, |s| s.title = title.to_string())?;
    persist_session_snapshot(session_id)
}

/// Call periodically (e.g. every minute) from the live capture loop. If it
/// returns `Some`, the caller should flush the current chunk to disk and
/// start a new file segment, then call [`mark_split`].
pub fn check_auto_split(session_id: &str) -> Result<Option<AutoSplitReason>, TranscribeError> {
    let reg = registry()
        .lock()
        .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?;
    let state = reg
        .get(session_id)
        .ok_or_else(|| TranscribeError::SessionNotFound(session_id.to_string()))?;

    let elapsed = state.last_split_at.elapsed().as_secs();
    let memory_ratio = memory::system_memory_usage_ratio();
    Ok(should_split(elapsed, memory_ratio))
}

pub fn mark_split(session_id: &str) -> Result<(), TranscribeError> {
    with_session_mut(session_id, |s| {
        s.last_split_at = std::time::Instant::now();
        s.last_split_at_unix_ms = unix_ms_now().unwrap_or(s.last_split_at_unix_ms);
    })?;
    persist_session_snapshot(session_id)
}

pub fn get_status(session_id: &str) -> Result<SessionStatus, TranscribeError> {
    let mut reg = registry()
        .lock()
        .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?;
    let state = reg
        .get_mut(session_id)
        .ok_or_else(|| TranscribeError::SessionNotFound(session_id.to_string()))?;
    state.collect_worker_events();
    let status = SessionStatus {
        session_id: session_id.to_string(),
        elapsed_seconds: state.elapsed_secs(),
        mic_enabled: state.config.mic_enabled,
        speaker_enabled: state.config.speaker_enabled,
        segments_count: state.segments_count,
        model_loaded: true,
    };
    drop(reg);
    let _ = persist_session_snapshot(session_id);
    Ok(status)
}

pub fn poll_events(session_id: &str) -> Result<Vec<SessionEvent>, TranscribeError> {
    let mut reg = registry()
        .lock()
        .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?;
    let events = {
        let state = reg
            .get_mut(session_id)
            .ok_or_else(|| TranscribeError::SessionNotFound(session_id.to_string()))?;
        state.collect_worker_events();
        std::mem::take(&mut state.pending_events)
    };

    drop(reg);
    // Best-effort, exactly like `get_status` above: `events` have already
    // been removed from `pending_events` by the `mem::take`, so propagating a
    // persist failure with `?` here would discard transcript and VU events
    // that are never re-delivered — the UI would simply lose that speech.
    // Snapshotting is crash recovery; it is never worth a live event.
    let _ = persist_session_snapshot(session_id);
    Ok(events)
}

/// Everything the recovery dialog needs, newest first.
///
/// Snapshots whose session left nothing behind — no journal entries and no
/// audio — are deleted here rather than listed. They are the residue of a
/// session that died within seconds of starting, and offering to "recover"
/// them produces an empty session the user then has to clean up by hand.
/// Flat `*.inprogress` files from builds before the per-session directory
/// are removed for the same reason: they carry configuration only, which
/// is exactly the thing that made recovery useless.
pub fn list_recoverable_sessions() -> Result<Vec<RecoverableSession>, TranscribeError> {
    let dir = recovery_dir()?;
    let mut out = Vec::new();
    if !dir.exists() {
        return Ok(out);
    }
    for entry in fs::read_dir(&dir).map_err(TranscribeError::from)? {
        let Ok(entry) = entry else { continue };
        let path = entry.path();
        if path.is_file() {
            if path.extension().and_then(|v| v.to_str()) == Some("inprogress") {
                tracing::info!(path = %path.display(), "removing pre-journal recovery snapshot");
                let _ = fs::remove_file(&path);
            }
            continue;
        }
        if !path.is_dir() {
            continue;
        }
        let Ok(snapshot) = load_snapshot_file(&path.join(SNAPSHOT_FILE)) else {
            // A directory with no readable snapshot is either mid-creation
            // or the leftovers of a stopped session whose audio was already
            // exported. Either way there is nothing to offer.
            remove_dir_if_stale(&path);
            continue;
        };
        // A session already running under this id (the user recovered it
        // this launch) must not also be offered for recovery.
        if is_registered(&snapshot.session_id) {
            continue;
        }
        let recoverable = describe_recoverable(snapshot, &path);
        if recoverable.is_empty() {
            tracing::info!(id = %recoverable.snapshot.session_id, "discarding empty recovery snapshot");
            let _ = fs::remove_dir_all(&path);
            continue;
        }
        out.push(recoverable);
    }
    out.sort_by_key(|entry| std::cmp::Reverse(entry.updated_at_unix_ms));
    Ok(out)
}

/// Discards a recoverable session and everything it held. Called from the
/// recovery dialog's per-session "Hapus"; the previous banner could only
/// dismiss the whole list, leaving the files behind forever.
pub fn delete_recoverable_session(session_id: &str) -> Result<(), TranscribeError> {
    let dir = session_recovery_dir(session_id)?;
    match fs::remove_dir_all(&dir) {
        Ok(()) => Ok(()),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(err) => Err(TranscribeError::from(err)),
    }
}

fn describe_recoverable(snapshot: SessionRecoverySnapshot, dir: &Path) -> RecoverableSession {
    let segment_count = journal::replay_count(&dir.join(JOURNAL_FILE));
    let mic_audio_secs = recoverable_audio_secs(dir, MIC_AUDIO_FILE);
    let speaker_audio_secs = recoverable_audio_secs(dir, SPEAKER_AUDIO_FILE);
    let updated_at_unix_ms = if snapshot.updated_at_unix_ms == 0 {
        snapshot.started_at_unix_ms
    } else {
        snapshot.updated_at_unix_ms
    };
    let title = if snapshot.title.trim().is_empty() {
        format!(
            "Sesi {}",
            &snapshot.session_id[..8.min(snapshot.session_id.len())]
        )
    } else {
        snapshot.title.clone()
    };
    // Prefer the wall clock the session actually accumulated; fall back to
    // the longest audio track for a snapshot from before that was carried.
    let duration_secs = snapshot
        .elapsed_secs
        .max(updated_at_unix_ms.saturating_sub(snapshot.started_at_unix_ms) as f64 / 1000.0)
        .max(mic_audio_secs)
        .max(speaker_audio_secs);
    RecoverableSession {
        started_at_unix_ms: snapshot.started_at_unix_ms,
        updated_at_unix_ms,
        snapshot,
        title,
        duration_secs,
        segment_count,
        mic_audio_secs,
        speaker_audio_secs,
    }
}

/// Seconds of audio recoverable for one source, whether it was finalized
/// (`.wav`) or left mid-write by a crash (`.wav.part`) — the length comes
/// from the file itself either way.
fn recoverable_audio_secs(dir: &Path, filename: &str) -> f64 {
    let final_path = dir.join(filename);
    let secs = wav_writer::duration_secs(&final_path, TARGET_SAMPLE_RATE, CAPTURE_CHANNELS);
    if secs > 0.0 {
        return secs;
    }
    wav_writer::duration_secs(
        &wav_writer::part_path_for(&final_path),
        TARGET_SAMPLE_RATE,
        CAPTURE_CHANNELS,
    )
}

fn is_registered(session_id: &str) -> bool {
    registry()
        .lock()
        .map(|reg| reg.contains_key(session_id))
        .unwrap_or(false)
}

/// Removes a recovery directory that holds nothing recoverable. Guarded on
/// emptiness rather than age: a directory being created right now already
/// has its snapshot written (see `start_session_with_id`).
///
/// A directory with no snapshot but *with* audio is left alone and logged:
/// it cannot be recovered (there is no config to resume from) but it holds
/// a recording, and deleting the user's audio to tidy up is not a trade
/// this code gets to make. Builds before `stop_session` always claimed the
/// audio could leave these behind.
fn remove_dir_if_stale(dir: &Path) {
    let has_content = [
        dir.join(JOURNAL_FILE),
        dir.join(MIC_AUDIO_FILE),
        dir.join(SPEAKER_AUDIO_FILE),
        wav_writer::part_path_for(&dir.join(MIC_AUDIO_FILE)),
        wav_writer::part_path_for(&dir.join(SPEAKER_AUDIO_FILE)),
    ]
    .iter()
    .any(|p| p.exists());
    if has_content {
        tracing::warn!(
            path = %dir.display(),
            "recovery directory holds audio but no snapshot; keeping it rather \
             than deleting a recording that cannot be resumed"
        );
        return;
    }
    let _ = fs::remove_dir_all(dir);
}

/// Live capture health, used both by the recording UI ("rekaman
/// terkonfirmasi") and by the integrity summary shown at Stop.
pub fn get_capture_health(session_id: &str) -> Result<CaptureHealth, TranscribeError> {
    let reg = registry()
        .lock()
        .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?;
    let state = reg
        .get(session_id)
        .ok_or_else(|| TranscribeError::SessionNotFound(session_id.to_string()))?;
    Ok(state.capture_health())
}

/// Everything a resumed session carries over from the run that crashed.
#[derive(Debug, Default)]
#[flutter_rust_bridge::frb(ignore)]
struct ResumeState {
    title: String,
    segments: Vec<Segment>,
    resume_offset_secs: f64,
    elapsed_secs: f64,
    mic_counters: ChannelCounters,
    speaker_counters: ChannelCounters,
}

/// What language to actually transcribe a live session with (Sprint 14a
/// item 11). Mirrors Dart's `effectiveSessionLanguage`
/// (`lib/state/models.dart`) — the two must stay in sync, because this is
/// the copy that governs what the engine actually decodes with, while the
/// Dart copy only labels the saved session for "Transkrip Ulang".
///
/// `global` is the persisted `AppSettings::language`: `None` means no
/// explicit override, in which case only `Offline` (no second speaker
/// whose language could differ from the room's, and the one mode the
/// blueprint lists as "Indonesia only" for accuracy) still forces `"id"`.
/// A `Some` value is an explicit choice — made in Settings, or carried
/// over from a pre-14a install that always wrote `"id"` — and always wins.
fn effective_session_language(global: Option<String>, mode: SessionMode) -> Option<String> {
    global.or_else(|| (mode == SessionMode::Offline).then(|| "id".to_string()))
}

/// What to actually decode a session with, folding in the per-session
/// override on top of [`effective_session_language`] (Sprint 14a item 11).
/// `config_language` — `SessionConfig::language` — is an explicit choice
/// made for *this meeting only* (via the session options menu, not
/// Settings) and always wins when present; otherwise the global/per-mode
/// resolution applies exactly as before.
fn resolve_session_language(
    config_language: Option<String>,
    global: Option<String>,
    mode: SessionMode,
) -> Option<String> {
    config_language.or_else(|| effective_session_language(global, mode))
}

fn start_session_with_id(
    id: String,
    config: SessionConfig,
    resume: ResumeState,
) -> Result<String, TranscribeError> {
    let now = std::time::Instant::now();
    let now_unix_ms = unix_ms_now()?;
    let language = resolve_session_language(
        config.language.clone(),
        crate::settings::load_settings().language,
        config.mode,
    );
    let refine_model_path = config
        .refine_model_path
        .clone()
        .filter(|p| !p.is_empty() && p != &config.model_path)
        .map(PathBuf::from);
    let fallback_model_path = config
        .fallback_model_path
        .clone()
        .filter(|p| !p.is_empty() && p != &config.model_path)
        .map(PathBuf::from)
        .filter(|p| p.exists());
    let worker_config = |source: &str| LiveWorkerConfig {
        quick_model_path: PathBuf::from(&config.model_path),
        refine_model_path: refine_model_path.clone(),
        hpt_mode: config.hpt_mode,
        source: source.to_string(),
        language: language.clone(),
        vad_enabled: config.vad_enabled,
        gpu_enabled: config.gpu_enabled,
        gpu_device: config.gpu_device,
        glossary: config.glossary.clone(),
        fallback_model_path: fallback_model_path.clone(),
    };
    // Audio-to-disk is the default; the setting exists so one release can
    // fall back to the RAM path if streaming turns out to destabilise the
    // capture threads Round 2 just stabilised.
    let session_dir = session_recovery_dir(&id)?;
    let audio_path = |filename: &str| -> Option<PathBuf> {
        config.audio_to_disk.then(|| session_dir.join(filename))
    };
    let (mic_capture, mic_attempt) = start_capture(
        config.mic_enabled,
        config.mic_device_id.clone(),
        worker_config("mic"),
        audio_path(MIC_AUDIO_FILE),
        resume.mic_counters,
    )?;
    let (speaker_capture, speaker_attempt) = start_capture(
        config.speaker_enabled,
        config.speaker_device_id.clone(),
        worker_config("spk"),
        audio_path(SPEAKER_AUDIO_FILE),
        resume.speaker_counters,
    )?;
    let mut pending_events = Vec::new();
    match decide_start(&mic_attempt, &speaker_attempt) {
        StartDecision::Proceed => {}
        StartDecision::ProceedWithWarning(message) => {
            tracing::warn!(%message, "starting session with a degraded capture set");
            pending_events.push(SessionEvent::Notice {
                level: NoticeLevel::Warning,
                source: "session".to_string(),
                message,
            });
        }
        // Returning here drops whichever captures did start, so a refused
        // session leaves no orphaned capture threads or helper processes.
        StartDecision::Fail(message) => return Err(TranscribeError::AudioDevice(message)),
    }
    // Adaptive HPT may have concluded the accurate model can't keep up with
    // live audio here. That silently changes what the user gets, so it is
    // said out loud — the alternative it replaces produced no transcript at
    // all on the device this was measured on.
    let downgraded = [mic_capture.as_ref(), speaker_capture.as_ref()]
        .into_iter()
        .flatten()
        .any(|channel| channel.worker.route() == Some(HptRoute::QuickOnly));
    if downgraded {
        pending_events.push(SessionEvent::Notice {
            level: NoticeLevel::Warning,
            source: "session".to_string(),
            message: "Perangkat ini terlalu lambat untuk model akurat secara langsung, \
                      jadi transkrip langsung memakai model cepat. Transkrip akurat \
                      dibuat otomatis setelah rapat selesai."
                .to_string(),
        });
    }
    // The journal is what makes the difference between "the app crashed"
    // and "the meeting is gone", so failing to open it is worth telling
    // the user about — but not worth refusing to record over.
    let journal = match TranscriptJournal::open_append(&session_dir.join(JOURNAL_FILE)) {
        Ok(journal) => Some(journal),
        Err(e) => {
            tracing::error!(%e, "transcript journal unavailable; session is not crash-recoverable");
            pending_events.push(SessionEvent::Notice {
                level: NoticeLevel::Warning,
                source: "session".to_string(),
                message: format!(
                    "Jurnal transkrip tidak bisa dibuka ({e}). Rekaman tetap berjalan, \
                     tetapi sesi ini tidak akan bisa dipulihkan jika aplikasi berhenti \
                     mendadak."
                ),
            });
            None
        }
    };

    let segments_count = resume.segments.len() as u32;
    // Monitor whichever device names are actually configured; an empty hint
    // list still works (watchdog.rs treats it as "any input + any output
    // present"), it just can't tell a sink swap from a device that was
    // never there. Only worth running at all if some capture is live.
    let watchdog_hints: Vec<String> = [&config.mic_device_id, &config.speaker_device_id]
        .into_iter()
        .flatten()
        .cloned()
        .collect();
    let (watchdog_rx, watchdog_stop_tx) = if config.mic_enabled || config.speaker_enabled {
        let (rx, tx) = crate::watchdog::start_watchdog(2, watchdog_hints);
        (Some(rx), Some(tx))
    } else {
        (None, None)
    };
    let state = SessionState {
        session_id: id.clone(),
        config,
        title: resume.title,
        started_at: now,
        started_at_unix_ms: now_unix_ms,
        last_split_at: now,
        last_split_at_unix_ms: now_unix_ms,
        segments_count,
        resume_offset_secs: resume.resume_offset_secs,
        recovered_elapsed_secs: resume.elapsed_secs,
        journal,
        mic_capture,
        speaker_capture,
        pending_events,
        // Seeding the echo window from the recovered tail would compare
        // new speech against text from before the crash, which is not an
        // echo of anything currently playing.
        recent_emitted: Vec::new(),
        watchdog_rx,
        watchdog_stop_tx,
    };
    registry()
        .lock()
        .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?
        .insert(id.clone(), state);
    persist_session_snapshot(&id)?;
    Ok(id)
}

fn counters_of(channel: Option<&CaptureChannel>) -> ChannelCounters {
    channel
        .map(|c| ChannelCounters {
            total_samples: c.health.total_samples(),
            voiced_samples: c.health.voiced_samples(),
        })
        .unwrap_or_default()
}

fn persist_session_snapshot(session_id: &str) -> Result<(), TranscribeError> {
    let snapshot = {
        let reg = registry()
            .lock()
            .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?;
        let state = reg
            .get(session_id)
            .ok_or_else(|| TranscribeError::SessionNotFound(session_id.to_string()))?;
        SessionRecoverySnapshot {
            session_id: state.session_id.clone(),
            config: state.config.clone(),
            started_at_unix_ms: state.started_at_unix_ms,
            last_split_at_unix_ms: state.last_split_at_unix_ms,
            segments_count: state.segments_count,
            title: state.title.clone(),
            updated_at_unix_ms: unix_ms_now().unwrap_or(state.started_at_unix_ms),
            elapsed_secs: state.elapsed_secs(),
            mic_counters: counters_of(state.mic_capture.as_ref()),
            speaker_counters: counters_of(state.speaker_capture.as_ref()),
        }
    };
    write_snapshot_file(&snapshot)
}

/// Root of the crash-recovery area. Under the OS app-config directory
/// (not temp), so it survives a reboot and is isolated per-user — this
/// directory holds transcript text and captured audio, so `/tmp`'s
/// world-readability would be a privacy regression.
fn recovery_dir() -> Result<PathBuf, TranscribeError> {
    if let Some(path) = RECOVERY_DIR_OVERRIDE.with(|slot| slot.borrow().clone()) {
        return Ok(path);
    }
    let dir = dirs::config_dir()
        .ok_or_else(|| TranscribeError::InvalidInput("no config dir".into()))?
        .join("TrareonTranscribe")
        .join("recovery");
    Ok(dir)
}

/// One directory per session: snapshot, journal and the two `.part` WAVs
/// live together, so recovering or discarding a session is one operation
/// on one path rather than five guesses at filenames.
fn session_recovery_dir(session_id: &str) -> Result<PathBuf, TranscribeError> {
    Ok(recovery_dir()?.join(sanitize_session_id(session_id)))
}

/// Session ids are UUIDs, but they arrive from Dart and land in a path.
/// Anything that isn't UUID-shaped is replaced rather than trusted.
fn sanitize_session_id(session_id: &str) -> String {
    let cleaned: String = session_id
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' {
                c
            } else {
                '_'
            }
        })
        .collect();
    if cleaned.is_empty() {
        "unnamed".to_string()
    } else {
        cleaned
    }
}

fn write_snapshot_file(snapshot: &SessionRecoverySnapshot) -> Result<(), TranscribeError> {
    let dir = session_recovery_dir(&snapshot.session_id)?;
    fs::create_dir_all(&dir).map_err(TranscribeError::from)?;
    let final_path = dir.join(SNAPSHOT_FILE);
    let tmp_path = dir.join(format!("{SNAPSHOT_FILE}.tmp"));
    let json = serde_json::to_vec_pretty(snapshot)
        .map_err(|e| TranscribeError::InvalidInput(e.to_string()))?;
    // Temp + rename in the same directory: a snapshot rewritten every poll
    // must never be observed half-written by the next launch.
    fs::write(&tmp_path, json).map_err(TranscribeError::from)?;
    fs::rename(&tmp_path, &final_path).map_err(TranscribeError::from)
}

/// Drops the parts of a session's recovery state that make it *recoverable*
/// (snapshot + journal) while leaving the finalized WAVs for
/// `export_session_audio` to move. Removes the directory outright if
/// nothing is left in it.
fn retire_recovery_state(session_id: &str) -> Result<(), TranscribeError> {
    let dir = session_recovery_dir(session_id)?;
    if !dir.exists() {
        return Ok(());
    }
    for file in [SNAPSHOT_FILE, JOURNAL_FILE] {
        match fs::remove_file(dir.join(file)) {
            Ok(()) => {}
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => {}
            Err(err) => return Err(TranscribeError::from(err)),
        }
    }
    release_recovery_dir(session_id);
    Ok(())
}

/// Removes a session's recovery directory once it is empty. Called after
/// the finalized audio has been moved into the session folder — the last
/// thing that had a claim on it.
#[flutter_rust_bridge::frb(ignore)]
pub fn release_recovery_dir(session_id: &str) {
    let Ok(dir) = session_recovery_dir(session_id) else {
        return;
    };
    let is_empty = fs::read_dir(&dir)
        .map(|mut entries| entries.next().is_none())
        .unwrap_or(false);
    if is_empty {
        let _ = fs::remove_dir(&dir);
    }
}

fn load_snapshot_file(path: &Path) -> Result<SessionRecoverySnapshot, TranscribeError> {
    const MAX_SNAPSHOT_SIZE: u64 = 10 * 1024 * 1024; // 10 MB
    let metadata = fs::metadata(path).map_err(TranscribeError::from)?;
    if metadata.len() > MAX_SNAPSHOT_SIZE {
        return Err(TranscribeError::InvalidInput(format!(
            "snapshot file too large ({} bytes, max {}): {}",
            metadata.len(),
            MAX_SNAPSHOT_SIZE,
            path.display()
        )));
    }
    let content = fs::read_to_string(path).map_err(TranscribeError::from)?;
    serde_json::from_str(&content).map_err(|e| TranscribeError::InvalidInput(e.to_string()))
}

fn unix_ms_now() -> Result<u64, TranscribeError> {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| TranscribeError::InvalidInput(e.to_string()))?;
    Ok(now.as_millis() as u64)
}

impl SessionState {
    /// Wall clock for this session, including time accumulated before a
    /// crash it was recovered from.
    fn elapsed_secs(&self) -> f64 {
        self.recovered_elapsed_secs + self.started_at.elapsed().as_secs_f64()
    }

    fn collect_worker_events(&mut self) {
        let dedupe_enabled = self.config.mode.echo_dedupe_enabled();
        let offset = self.resume_offset_secs;

        // Device-health: a `DeviceReconnected` means the OS's default
        // output device changed (TWS profile switch, sleep/wake) and the
        // speaker capture may still be silently reading a dead monitor
        // source — re-open it against whatever is default now. Collected
        // into a Vec first since `reopen_speaker_capture` needs `&mut
        // self` while this loop is reading `self.watchdog_rx`.
        let reconnected = self.watchdog_rx.as_ref().is_some_and(|rx| {
            rx.try_iter().any(|event| {
                matches!(
                    event,
                    crate::watchdog::WatchdogEvent::DeviceReconnected { .. }
                )
            })
        });
        if reconnected {
            if let Some(notice) = reopen_speaker_capture(self) {
                self.pending_events.push(notice);
            }
        }

        // PRIORITY QUEUE: drain ALL mic events entirely before touching
        // speaker events. This ensures mic segments (direct user speech)
        // are dispatched and visible to the UI before any loopback-captured
        // speaker segments, giving the user a snappier live-transcript feel.
        //
        // Inlined (not extracted to a helper) so the borrow checker sees
        // per-field borrows — calling a `&mut self` method while holding a
        // reference into one of its fields would be rejected.
        // A stream that died mid-session (see `audio::stream_error`) reaches
        // the user here. `take_failure` yields it once, so the toast isn't
        // re-raised on every 200 ms poll.
        for channel in [self.mic_capture.as_ref(), self.speaker_capture.as_ref()]
            .into_iter()
            .flatten()
        {
            if let Some(message) = channel.capture.take_failure() {
                self.pending_events.push(SessionEvent::Notice {
                    level: NoticeLevel::Error,
                    source: channel.source.clone(),
                    message,
                });
            }
            // Problems the tee thread could only record, not report:
            // a failed disk write, a RAM fallback that hit its cap.
            if let Ok(mut errors) = channel.sink_errors.lock() {
                for message in errors.drain(..) {
                    self.pending_events.push(SessionEvent::Notice {
                        level: NoticeLevel::Error,
                        source: channel.source.clone(),
                        message,
                    });
                }
            }
        }

        let mut emitted: Vec<Segment> = Vec::new();
        for capture in [self.mic_capture.as_ref(), self.speaker_capture.as_ref()]
            .into_iter()
            .flatten()
        {
            while let Ok(event) = capture.events_rx.try_recv() {
                match event {
                    LiveEvent::Segment(mut segment) => {
                        // A recovered session's pipeline restarts at t=0.
                        // Shifting here (rather than in the pipeline) keeps
                        // the offset in one place and off the hot path.
                        segment.timestamp += offset;
                        if let Some(segment) =
                            accept_or_drop_echo(segment, &mut self.recent_emitted, dedupe_enabled)
                        {
                            self.segments_count = self.segments_count.saturating_add(1);
                            emitted.push(segment);
                        }
                    }
                    LiveEvent::Vu { source, level } => {
                        self.pending_events.push(SessionEvent::Vu { source, level });
                    }
                    LiveEvent::Tentative { source, text } => {
                        // Not a transcript line and never journalled: it
                        // is the uncommitted tail of the live hypothesis,
                        // free to change on the next decode. Only the
                        // committed segments go to disk.
                        self.pending_events
                            .push(SessionEvent::Tentative { source, text });
                    }
                }
            }
        }

        // Journal before dispatch: a segment the UI has seen but the disk
        // has not is exactly the gap this module exists to close.
        for segment in emitted {
            if let Some(journal) = self.journal.as_mut() {
                if let Err(e) = journal.append(&segment) {
                    tracing::error!(%e, "transcript journal write failed");
                }
            }
            self.pending_events.push(SessionEvent::Transcript(segment));
        }

        self.raise_silence_warnings();
    }

    /// Tells the user when an expected source has stopped delivering audio.
    ///
    /// The failure this catches is the category's most-reported one: a
    /// microphone that was open the whole meeting and recorded nothing,
    /// discovered afterwards. Each channel warns once and re-arms when
    /// sound comes back, so a long pause costs one notice, not one per poll.
    fn raise_silence_warnings(&mut self) {
        let Ok(now_unix_ms) = unix_ms_now() else {
            return;
        };
        let elapsed = self.elapsed_secs();
        let mut notices = Vec::new();
        for channel in [self.mic_capture.as_mut(), self.speaker_capture.as_mut()]
            .into_iter()
            .flatten()
        {
            let silent_for = channel.health.silent_for_secs(now_unix_ms, elapsed);
            if silent_for < SILENCE_WARNING_SECS {
                // Audio is flowing again: re-arm so a later outage is
                // reported too.
                channel.silence_warned = false;
                continue;
            }
            if channel.silence_warned {
                continue;
            }
            channel.silence_warned = true;
            let label = source_label(&channel.source);
            let minutes = (silent_for / 60.0).floor() as u64;
            notices.push((
                channel.source.clone(),
                if channel.health.confirmed() {
                    format!(
                        "Tidak ada suara dari {label} selama {minutes} menit terakhir. \
                         Periksa apakah perangkat masih aktif atau ter-mute."
                    )
                } else {
                    format!(
                        "{} belum merekam suara apa pun sejak sesi dimulai \
                         ({minutes} menit). Periksa perangkat dan izin mikrofon — \
                         rekaman ini kemungkinan besar kosong.",
                        capitalize(label)
                    )
                },
            ));
        }
        for (source, message) in notices {
            tracing::warn!(%source, %message, "capture health warning");
            self.pending_events.push(SessionEvent::Notice {
                level: NoticeLevel::Warning,
                source,
                message,
            });
        }
    }

    fn capture_health(&self) -> CaptureHealth {
        let now_unix_ms = unix_ms_now().unwrap_or(0);
        let elapsed = self.elapsed_secs();
        let mut channels = Vec::new();
        let mut warnings = Vec::new();

        for (channel, expected, source) in [
            (self.mic_capture.as_ref(), self.config.mic_enabled, "mic"),
            (
                self.speaker_capture.as_ref(),
                self.config.speaker_enabled,
                "spk",
            ),
        ] {
            let Some(channel) = channel else {
                if expected {
                    // Asked for but never opened: `decide_start` already
                    // warned, but the integrity summary must still say the
                    // track is missing rather than omit it.
                    channels.push(ChannelCapture {
                        source: source.to_string(),
                        expected: true,
                        confirmed: false,
                        seconds_captured: 0.0,
                        seconds_voiced: 0.0,
                        percent_silent: 100.0,
                        silent_for_secs: elapsed,
                        writing_to_disk: false,
                        lag_secs: 0.0,
                    });
                    warnings.push(format!(
                        "{} tidak pernah berhasil dibuka, jadi tidak ada rekamannya.",
                        capitalize(source_label(source))
                    ));
                }
                continue;
            };
            let health = &channel.health;
            let capture = ChannelCapture {
                source: source.to_string(),
                expected,
                confirmed: health.confirmed(),
                seconds_captured: health.seconds_captured(TARGET_SAMPLE_RATE),
                seconds_voiced: health.seconds_voiced(TARGET_SAMPLE_RATE),
                percent_silent: health.percent_silent(),
                silent_for_secs: health.silent_for_secs(now_unix_ms, elapsed),
                writing_to_disk: health.on_disk(),
                lag_secs: worker_lag_secs(channel),
            };
            if capture.lag_secs >= LAG_WARNING_SECS {
                warnings.push(format!(
                    "Transkrip langsung {} tertinggal {:.0} detik dari rekaman. Sisanya \
                     diselesaikan otomatis setelah sesi berhenti.",
                    source_label(source),
                    capture.lag_secs
                ));
            }
            if expected && !capture.confirmed {
                warnings.push(format!(
                    "{} tidak menghasilkan suara sama sekali ({:.0} detik terekam, \
                     semuanya senyap).",
                    capitalize(source_label(source)),
                    capture.seconds_captured
                ));
            } else if expected && capture.silent_for_secs >= SILENCE_WARNING_SECS {
                warnings.push(format!(
                    "Tidak ada suara dari {} selama {:.0} menit terakhir.",
                    source_label(source),
                    capture.silent_for_secs / 60.0
                ));
            }
            if expected && !capture.writing_to_disk {
                warnings.push(format!(
                    "Audio {} tidak ditulis ke disk, jadi tidak akan selamat dari crash.",
                    source_label(source)
                ));
            }
            channels.push(capture);
        }

        CaptureHealth {
            session_id: self.session_id.clone(),
            elapsed_secs: elapsed,
            segment_count: self.segments_count,
            channels,
            warnings,
        }
    }
}

/// How far behind the live worker on `channel` is, in seconds of audio.
///
/// Capture counts every sample it hands over; the worker counts every
/// sample it has actually run through Whisper. The difference is the
/// backlog, and the backlog is what Stop used to discard.
fn worker_lag_secs(channel: &CaptureChannel) -> f64 {
    let delivered = channel.health.total_samples();
    let processed = channel.worker.processed_samples();
    delivered.saturating_sub(processed) as f64 / TARGET_SAMPLE_RATE as f64
}

fn capitalize(text: &str) -> String {
    let mut chars = text.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}

/// Cross-source echo check + recent-emitted bookkeeping, split out as a
/// pure function so it's unit-testable without a live capture thread.
/// Returns `None` if the segment should be dropped as an echo, otherwise
/// `Some(segment)` after recording it in `recent_emitted`.
fn accept_or_drop_echo(
    segment: Segment,
    recent_emitted: &mut Vec<Segment>,
    dedupe_enabled: bool,
) -> Option<Segment> {
    if dedupe_enabled && is_echo(&segment, recent_emitted) {
        return None;
    }
    recent_emitted.push(segment.clone());
    trim_recent_emitted(recent_emitted);
    Some(segment)
}

/// Keep only segments within [`RECENT_EMITTED_WINDOW_SECS`] of the newest
/// one, so the dedupe buffer doesn't grow unbounded over a long session.
fn trim_recent_emitted(segments: &mut Vec<Segment>) {
    let Some(newest) = segments
        .iter()
        .map(|s| s.timestamp)
        .fold(None, |acc, t| Some(acc.map_or(t, |m: f64| m.max(t))))
    else {
        return;
    };
    segments.retain(|s| newest - s.timestamp <= RECENT_EMITTED_WINDOW_SECS);
}

fn with_session_mut(
    session_id: &str,
    f: impl FnOnce(&mut SessionState),
) -> Result<(), TranscribeError> {
    let mut reg = registry()
        .lock()
        .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?;
    let state = reg
        .get_mut(session_id)
        .ok_or_else(|| TranscribeError::SessionNotFound(session_id.to_string()))?;
    f(state);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_config() -> SessionConfig {
        // Capture disabled: these tests exercise the session registry /
        // lifecycle, not the STT pipeline, so no model file is required.
        let mut cfg = SessionConfig::for_mode(SessionMode::Online, "tiny".into());
        cfg.mic_enabled = false;
        cfg.speaker_enabled = false;
        cfg
    }

    /// Sprint 14a item 11: before this, `start_session_with_id` read
    /// `AppSettings::language` raw, so changing its default from
    /// `Some("id")` to `None` (so Online/Webinar stop forcing Indonesian)
    /// would have silently also stopped Offline forcing it — the one mode
    /// the brief requires to stay Indonesian by default.
    #[test]
    fn offline_with_no_override_still_forces_indonesian() {
        assert_eq!(
            effective_session_language(None, SessionMode::Offline),
            Some("id".to_string())
        );
    }

    #[test]
    fn online_and_webinar_with_no_override_are_auto() {
        assert_eq!(effective_session_language(None, SessionMode::Online), None);
        assert_eq!(effective_session_language(None, SessionMode::Webinar), None);
    }

    #[test]
    fn an_explicit_global_choice_wins_in_every_mode() {
        for mode in [
            SessionMode::Webinar,
            SessionMode::Online,
            SessionMode::Offline,
        ] {
            assert_eq!(
                effective_session_language(Some("en".to_string()), mode),
                Some("en".to_string())
            );
        }
    }

    /// Sprint 14a item 11: a per-session override (the options menu, not
    /// Settings) must win even over Offline's hardcoded Indonesian default
    /// and over an explicit global choice — it is the most specific of the
    /// three.
    #[test]
    fn a_per_session_override_wins_over_offlines_forced_indonesian() {
        assert_eq!(
            resolve_session_language(Some("en".to_string()), None, SessionMode::Offline),
            Some("en".to_string())
        );
    }

    #[test]
    fn a_per_session_override_wins_over_an_explicit_global_choice() {
        assert_eq!(
            resolve_session_language(
                Some("en".to_string()),
                Some("id".to_string()),
                SessionMode::Online
            ),
            Some("en".to_string())
        );
    }

    #[test]
    fn no_per_session_override_falls_back_to_the_global_resolution() {
        assert_eq!(
            resolve_session_language(None, None, SessionMode::Online),
            None
        );
        assert_eq!(
            resolve_session_language(None, None, SessionMode::Offline),
            Some("id".to_string())
        );
    }

    #[test]
    fn nothing_enabled_proceeds_without_a_notice() {
        assert_eq!(
            decide_start(&CaptureAttempt::Disabled, &CaptureAttempt::Disabled),
            StartDecision::Proceed
        );
    }

    #[test]
    fn everything_working_proceeds_without_a_notice() {
        assert_eq!(
            decide_start(&CaptureAttempt::Started, &CaptureAttempt::Started),
            StartDecision::Proceed
        );
        assert_eq!(
            decide_start(&CaptureAttempt::Started, &CaptureAttempt::Disabled),
            StartDecision::Proceed
        );
    }

    #[test]
    fn a_failed_mic_with_working_loopback_warns_and_proceeds() {
        // "Rapat Online" on a machine whose mic can't be opened: the meeting
        // audio is still worth recording, but the user has to know their own
        // voice isn't in it.
        let decision = decide_start(
            &CaptureAttempt::Failed("POLLERR".into()),
            &CaptureAttempt::Started,
        );
        let StartDecision::ProceedWithWarning(message) = decision else {
            panic!("expected a warning, got {decision:?}");
        };
        assert!(message.contains("Mikrofon"), "must name the dead source");
        assert!(message.contains("POLLERR"), "must keep the reason");
        assert!(
            !message.contains("Audio sistem"),
            "must not blame the source that works: {message}"
        );
    }

    #[test]
    fn a_failed_loopback_with_working_mic_warns_and_proceeds() {
        let decision = decide_start(
            &CaptureAttempt::Started,
            &CaptureAttempt::Failed("no monitor source".into()),
        );
        let StartDecision::ProceedWithWarning(message) = decision else {
            panic!("expected a warning, got {decision:?}");
        };
        assert!(message.contains("Audio sistem"));
        assert!(!message.contains("Mikrofon"));
    }

    #[test]
    fn every_source_failing_refuses_to_start() {
        // The actual GUI bug: both sources dead, session started anyway, and
        // the UI waited forever for a transcript that could never arrive.
        let decision = decide_start(
            &CaptureAttempt::Failed("POLLERR".into()),
            &CaptureAttempt::Failed("no monitor source".into()),
        );
        let StartDecision::Fail(message) = decision else {
            panic!("expected a failure, got {decision:?}");
        };
        assert!(message.contains("tidak dapat dimulai"));
        assert!(message.contains("Mikrofon") && message.contains("Audio sistem"));
    }

    #[test]
    fn the_only_enabled_source_failing_refuses_to_start() {
        // "Rapat Offline" (mic only) and "Webinar" (system audio only) have
        // nothing to fall back to, so a single failure is fatal there.
        assert!(matches!(
            decide_start(
                &CaptureAttempt::Failed("x".into()),
                &CaptureAttempt::Disabled
            ),
            StartDecision::Fail(_)
        ));
        assert!(matches!(
            decide_start(
                &CaptureAttempt::Disabled,
                &CaptureAttempt::Failed("x".into())
            ),
            StartDecision::Fail(_)
        ));
    }

    #[test]
    fn a_refused_start_surfaces_as_an_audio_device_error() {
        // Threaded end-to-end through start_session so `decide_start` can't be
        // wired up and then ignored: a mic-only session whose only device
        // cannot be opened must return Err, not a running session that will
        // never produce a segment.
        //
        // Pinned to cpal because the PulseAudio path deliberately *recovers*
        // from an unknown device hint (stale settings from the previous build
        // carry cpal ALSA names), so on a machine with a sound server an
        // unknown name would correctly succeed and prove nothing.
        // No other test starts a capture, so this process-wide override is
        // safe; it is restored anyway.
        let previous = std::env::var(crate::audio::capture::BACKEND_ENV).ok();
        std::env::set_var(crate::audio::capture::BACKEND_ENV, "cpal");

        let mut cfg = SessionConfig::for_mode(SessionMode::Offline, "tiny".into());
        cfg.mic_enabled = true;
        cfg.speaker_enabled = false;
        cfg.mic_device_id = Some("definitely-not-a-real-device-xyz123".into());
        let result = start_session(cfg);

        match previous {
            Some(value) => std::env::set_var(crate::audio::capture::BACKEND_ENV, value),
            None => std::env::remove_var(crate::audio::capture::BACKEND_ENV),
        }

        let Err(TranscribeError::AudioDevice(message)) = result else {
            panic!("expected an audio device error, got {result:?}");
        };
        assert!(
            message.contains("tidak dapat dimulai"),
            "error must be the actionable Indonesian one: {message}"
        );
    }

    #[test]
    fn start_stop_roundtrip() {
        let id = start_session(test_config()).unwrap();
        assert!(get_status(&id).is_ok());
        stop_session(&id).unwrap();
        assert!(get_status(&id).is_err());
    }

    /// Sprint 13 B6: a `DeviceReconnected` watchdog event must not try to
    /// re-open a speaker capture the user never turned on. Real
    /// loopback/cpal I/O is deliberately kept out of this module's tests
    /// (see `test_config`'s comment) so this only covers the two
    /// environment-independent short-circuits; the actual re-open against
    /// a real device swap was exercised manually (see Sprint 13 report).
    #[test]
    fn reopen_speaker_capture_is_a_noop_when_speaker_is_disabled() {
        let id = start_session(test_config()).unwrap();
        let notice = {
            let mut reg = registry().lock().unwrap();
            let state = reg.get_mut(&id).unwrap();
            assert!(!state.config.speaker_enabled);
            reopen_speaker_capture(state)
        };
        assert!(notice.is_none());
        stop_session(&id).unwrap();
    }

    // The "speaker enabled but nothing currently in `speaker_capture`"
    // branch (`let Some(old) = state.speaker_capture.take() else { return
    // None }`) is not separately tested end-to-end here: on Linux,
    // `start_loopback` deliberately recovers from an unmatched device hint
    // by falling back to the default monitor (see the comment on
    // `a_refused_start_surfaces_as_an_audio_device_error`), so there is no
    // hardware-independent way to force speaker capture to fail to start
    // on this platform the way the mic/cpal path can. The branch itself is
    // a single `Option::take().else` short-circuit, covered by code
    // inspection rather than a brittle environment-dependent test.

    /// Scopes `RECOVERY_DIR_OVERRIDE` (thread-local, so each test gets its
    /// own) to a fresh temp directory and cleans it up afterwards.
    struct RecoveryHome(PathBuf);

    impl RecoveryHome {
        fn new() -> Self {
            let dir =
                std::env::temp_dir().join(format!("transcribe_recovery_{}", uuid::Uuid::new_v4()));
            let _ = std::fs::remove_dir_all(&dir);
            std::fs::create_dir_all(&dir).unwrap();
            set_recovery_dir_override(Some(dir.clone()));
            Self(dir)
        }

        fn path(&self) -> &Path {
            &self.0
        }
    }

    impl Drop for RecoveryHome {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
            set_recovery_dir_override(None);
        }
    }

    /// Lays down the state a `kill -9` would have left: a snapshot, a
    /// journal with `segment_texts` in it, and (optionally) an unfinalized
    /// `.part` recording. Nothing here calls `start_session`, because the
    /// crashed process is precisely the one that is no longer running.
    fn stage_crashed_session(
        home: &RecoveryHome,
        segment_texts: &[&str],
        mic_seconds: f64,
    ) -> SessionRecoverySnapshot {
        let id = Uuid::new_v4().to_string();
        let dir = home.path().join(&id);
        std::fs::create_dir_all(&dir).unwrap();

        let mut journal = TranscriptJournal::open_append(&dir.join(JOURNAL_FILE)).unwrap();
        for (index, text) in segment_texts.iter().enumerate() {
            journal
                .append(&seg("mic", text, index as f64 * 3.0))
                .unwrap();
        }
        journal.sync().unwrap();

        if mic_seconds > 0.0 {
            let mut writer =
                StreamingWavWriter::open(&dir.join(MIC_AUDIO_FILE), TARGET_SAMPLE_RATE, 1).unwrap();
            let samples = (TARGET_SAMPLE_RATE as f64 * mic_seconds) as usize;
            writer.append(&vec![0.25f32; samples]).unwrap();
            // Deliberately no finalize(): the header still says zero.
            std::mem::forget(writer);
        }

        let snapshot = SessionRecoverySnapshot {
            session_id: id,
            config: test_config(),
            started_at_unix_ms: 1_000_000,
            last_split_at_unix_ms: 1_000_000,
            segments_count: segment_texts.len() as u32,
            title: "Rapat Anggaran".to_string(),
            updated_at_unix_ms: 1_000_000 + 90 * 60 * 1000,
            elapsed_secs: 90.0 * 60.0,
            mic_counters: ChannelCounters {
                total_samples: TARGET_SAMPLE_RATE as u64 * 300,
                voiced_samples: TARGET_SAMPLE_RATE as u64 * 120,
            },
            speaker_counters: ChannelCounters::default(),
        };
        std::fs::write(
            dir.join(SNAPSHOT_FILE),
            serde_json::to_vec_pretty(&snapshot).unwrap(),
        )
        .unwrap();
        snapshot
    }

    /// UX-01, end to end: this is the failure the whole sprint is named
    /// after. A session that crashed ninety minutes in used to come back
    /// with `segments: []` and no audio.
    #[test]
    fn a_crashed_session_is_listed_with_its_real_transcript_and_audio() {
        let home = RecoveryHome::new();
        let staged = stage_crashed_session(&home, &["satu", "dua", "tiga"], 4.0);

        let listed = list_recoverable_sessions().unwrap();
        assert_eq!(listed.len(), 1);
        let entry = &listed[0];
        assert_eq!(entry.snapshot.session_id, staged.session_id);
        assert_eq!(entry.title, "Rapat Anggaran");
        assert_eq!(
            entry.segment_count, 3,
            "counted from the journal, not from the snapshot's claim"
        );
        assert!(entry.has_audio());
        assert!((entry.mic_audio_secs - 4.0).abs() < 0.01);
        assert_eq!(entry.speaker_audio_secs, 0.0);
        assert!((entry.duration_secs - 5400.0).abs() < 1.0);
    }

    #[test]
    fn recovering_restores_the_segments_and_resumes_the_timeline() {
        let home = RecoveryHome::new();
        let staged = stage_crashed_session(&home, &["satu", "dua"], 30.0);

        let recovered = recover_session(staged).unwrap();
        let texts: Vec<_> = recovered.segments.iter().map(|s| s.text.as_str()).collect();
        assert_eq!(texts, ["satu", "dua"]);
        assert!(
            (recovered.resume_offset_secs - 30.0).abs() < 0.01,
            "new segments continue from the end of the recovered audio, \
             not from zero: {}",
            recovered.resume_offset_secs
        );
        assert!((recovered.mic_audio_secs - 30.0).abs() < 0.01);

        let status = get_status(&recovered.session_id).unwrap();
        assert_eq!(status.segments_count, 2, "the count is restored too");
        assert!(
            status.elapsed_seconds >= 5400.0,
            "the clock continues rather than restarting at 00:00"
        );

        // A session that is already running must not also be offered for
        // recovery — recovering it twice would orphan the first one.
        assert!(list_recoverable_sessions().unwrap().is_empty());
        stop_session(&recovered.session_id).unwrap();
    }

    /// The `.part` file is reopened, not replaced: the saved WAV has to
    /// cover the whole meeting, not just what came after the restart.
    #[test]
    fn recovering_keeps_writing_into_the_audio_it_recovered() {
        let home = RecoveryHome::new();
        let staged = stage_crashed_session(&home, &["satu"], 2.0);
        let id = staged.session_id.clone();
        let part = wav_writer::part_path_for(&home.path().join(&id).join(MIC_AUDIO_FILE));
        let bytes_before = std::fs::metadata(&part).unwrap().len();

        let recovered = recover_session(staged).unwrap();
        // Capture is disabled in test config, so nothing new is appended —
        // what matters is that the existing samples were not truncated.
        assert!(part.exists(), "the recording in progress is still there");
        assert_eq!(std::fs::metadata(&part).unwrap().len(), bytes_before);
        stop_session(&recovered.session_id).unwrap();
    }

    /// The integrity summary of a recovered session has to describe the
    /// whole meeting: it used to report the full duration next to only the
    /// seconds captured since the restart, because the counters restarted
    /// with the capture threads while the clock and the audio file did not.
    /// The counters therefore have to survive in the snapshot; what a
    /// seeded [`ChannelHealth`] then reports is covered in `audio::sink`.
    #[test]
    fn capture_counters_survive_a_crash_in_the_snapshot() {
        let home = RecoveryHome::new();
        let staged = stage_crashed_session(&home, &["satu"], 5.0);
        let path = home.path().join(&staged.session_id).join(SNAPSHOT_FILE);

        let reloaded = load_snapshot_file(&path).unwrap();
        assert_eq!(
            reloaded.mic_counters.total_samples,
            TARGET_SAMPLE_RATE as u64 * 300
        );
        assert_eq!(
            reloaded.mic_counters.voiced_samples,
            TARGET_SAMPLE_RATE as u64 * 120
        );
        // A source that never ran carries zeroes, not garbage.
        assert_eq!(reloaded.speaker_counters.total_samples, 0);

        // And the recovered session is seeded from them.
        let recovered = recover_session(reloaded).unwrap();
        stop_session(&recovered.session_id).unwrap();
    }

    /// Snapshots written before the counters existed must still load.
    #[test]
    fn a_snapshot_without_counters_loads_with_zeroes() {
        let home = RecoveryHome::new();
        let staged = stage_crashed_session(&home, &["satu"], 0.0);
        let path = home.path().join(&staged.session_id).join(SNAPSHOT_FILE);
        let mut value: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&path).unwrap()).unwrap();
        let object = value.as_object_mut().unwrap();
        object.remove("mic_counters");
        object.remove("speaker_counters");
        std::fs::write(&path, serde_json::to_vec_pretty(&value).unwrap()).unwrap();

        let reloaded = load_snapshot_file(&path).unwrap();
        assert_eq!(reloaded.mic_counters.total_samples, 0);
        assert_eq!(reloaded.segments_count, 1, "the rest still loads");
    }

    #[test]
    fn a_snapshot_with_no_transcript_and_no_audio_is_cleaned_up_silently() {
        let home = RecoveryHome::new();
        let staged = stage_crashed_session(&home, &[], 0.0);
        let dir = home.path().join(&staged.session_id);
        assert!(dir.exists());

        assert!(list_recoverable_sessions().unwrap().is_empty());
        assert!(!dir.exists(), "nothing to recover, nothing left behind");
    }

    /// Snapshots from before the journal existed carry configuration only,
    /// which is exactly what made recovery useless. Offering them would be
    /// repeating the lie.
    #[test]
    fn pre_journal_inprogress_files_are_discarded() {
        let home = RecoveryHome::new();
        let legacy = home
            .path()
            .join("11111111-2222-3333-4444-555555555555.inprogress");
        std::fs::write(&legacy, b"{}").unwrap();

        assert!(list_recoverable_sessions().unwrap().is_empty());
        assert!(!legacy.exists());
    }

    /// Tidying up must never take a recording with it.
    #[test]
    fn a_directory_with_audio_but_no_snapshot_is_kept() {
        let home = RecoveryHome::new();
        let staged = stage_crashed_session(&home, &[], 3.0);
        let dir = home.path().join(&staged.session_id);
        std::fs::remove_file(dir.join(SNAPSHOT_FILE)).unwrap();

        assert!(list_recoverable_sessions().unwrap().is_empty());
        assert!(
            dir.exists(),
            "an unresumable recording is still the user's audio"
        );
    }

    #[test]
    fn deleting_a_recoverable_session_removes_everything_it_held() {
        let home = RecoveryHome::new();
        let staged = stage_crashed_session(&home, &["satu"], 1.0);
        let dir = home.path().join(&staged.session_id);
        assert!(dir.exists());

        delete_recoverable_session(&staged.session_id).unwrap();
        assert!(!dir.exists());
        assert!(list_recoverable_sessions().unwrap().is_empty());
        // Idempotent: deleting from a stale dialog must not error.
        delete_recoverable_session(&staged.session_id).unwrap();
    }

    #[test]
    fn stopping_clears_the_recovery_state_so_it_is_not_offered_again() {
        let home = RecoveryHome::new();
        let id = start_session(test_config()).unwrap();
        let dir = home.path().join(&id);
        assert!(dir.join(SNAPSHOT_FILE).exists());
        assert!(dir.join(JOURNAL_FILE).exists());

        stop_session(&id).unwrap();
        assert!(!dir.exists(), "no capture, so nothing is staged for export");
        assert!(list_recoverable_sessions().unwrap().is_empty());
    }

    /// `export_session_audio` runs *after* `stop_session`, so stopping must
    /// not take the finalized WAVs with it.
    #[test]
    fn stopping_leaves_finalized_audio_for_the_export_that_follows() {
        let home = RecoveryHome::new();
        let id = start_session(test_config()).unwrap();
        let dir = home.path().join(&id);
        // Stand in for the tee thread: a finished recording in the session's
        // recovery directory.
        let mut writer =
            StreamingWavWriter::open(&dir.join(MIC_AUDIO_FILE), TARGET_SAMPLE_RATE, 1).unwrap();
        writer.append(&vec![0.2f32; 16_000]).unwrap();
        writer.finalize().unwrap().unwrap();

        stop_session(&id).unwrap();
        assert!(
            dir.join(MIC_AUDIO_FILE).exists(),
            "the audio must survive until export_session_audio moves it"
        );
        assert!(!dir.join(SNAPSHOT_FILE).exists());
        assert!(!dir.join(JOURNAL_FILE).exists());

        // ...and the directory goes once the audio has been claimed.
        std::fs::remove_file(dir.join(MIC_AUDIO_FILE)).unwrap();
        release_recovery_dir(&id);
        assert!(!dir.exists());
    }

    #[test]
    fn a_live_session_journals_every_segment_it_emits() {
        let home = RecoveryHome::new();
        let id = start_session(test_config()).unwrap();
        let journal_path = home.path().join(&id).join(JOURNAL_FILE);

        with_session_mut(&id, |state| {
            let journal = state.journal.as_mut().expect("journal is open");
            journal.append(&seg("mic", "halo", 0.0)).unwrap();
            journal.append(&seg("spk", "dunia", 3.0)).unwrap();
        })
        .unwrap();

        let replayed = journal::replay(&journal_path);
        assert_eq!(replayed.len(), 2);
        stop_session(&id).unwrap();
    }

    #[test]
    fn a_session_id_can_never_escape_the_recovery_directory() {
        let home = RecoveryHome::new();
        let dir = session_recovery_dir("../../etc/passwd").unwrap();
        assert!(dir.starts_with(home.path()));
        assert_eq!(dir.file_name().unwrap(), "______etc_passwd");
        assert_eq!(
            session_recovery_dir("").unwrap().file_name().unwrap(),
            "unnamed"
        );
    }

    #[test]
    fn capture_health_reports_a_source_that_was_asked_for_but_never_opened() {
        let home = RecoveryHome::new();
        // The config asks for a microphone but no channel exists — the
        // exact shape of "the mic was never opened and nobody said so".
        // Reached here via toggle_mic so the test needs no sound card.
        let id = start_session(test_config()).unwrap();
        toggle_mic(&id, true).unwrap();
        let _ = home;

        let health = get_capture_health(&id).unwrap();
        let mic = health
            .channels
            .iter()
            .find(|c| c.source == "mic")
            .expect("the expected source is listed even when it never opened");
        assert!(mic.expected);
        assert!(!mic.confirmed);
        assert_eq!(mic.percent_silent, 100.0);
        assert!(!health.all_expected_confirmed());
        assert!(
            health
                .warnings
                .iter()
                .any(|w| w.contains("tidak ada rekamannya")),
            "the summary must say the track is missing: {:?}",
            health.warnings
        );
        stop_session(&id).unwrap();
    }

    #[test]
    fn capture_health_on_a_session_with_nothing_enabled_is_not_confirmed() {
        let home = RecoveryHome::new();
        let id = start_session(test_config()).unwrap();
        let _ = home;
        let health = get_capture_health(&id).unwrap();
        assert!(health.channels.is_empty());
        assert!(
            !health.all_expected_confirmed(),
            "no expected source means nothing has been confirmed"
        );
        assert!(health.warnings.is_empty());
        stop_session(&id).unwrap();
    }

    #[test]
    fn the_session_title_reaches_the_recovery_snapshot() {
        let home = RecoveryHome::new();
        let id = start_session(test_config()).unwrap();
        set_session_title(&id, "Rapat Koordinasi").unwrap();

        let snapshot = load_snapshot_file(&home.path().join(&id).join(SNAPSHOT_FILE)).unwrap();
        assert_eq!(snapshot.title, "Rapat Koordinasi");
        stop_session(&id).unwrap();
    }

    #[test]
    fn stop_unknown_session_errors() {
        assert!(stop_session("not-a-real-session-id").is_err());
    }

    #[test]
    fn toggle_mic_updates_status() {
        let id = start_session(test_config()).unwrap();
        toggle_mic(&id, false).unwrap();
        let status = get_status(&id).unwrap();
        assert!(!status.mic_enabled);
        stop_session(&id).unwrap();
    }

    #[test]
    fn toggle_speaker_updates_status() {
        let id = start_session(test_config()).unwrap();
        toggle_speaker(&id, false).unwrap();
        let status = get_status(&id).unwrap();
        assert!(!status.speaker_enabled);
        stop_session(&id).unwrap();
    }

    #[test]
    fn set_mode_applies_default_toggles() {
        let id = start_session(test_config()).unwrap();
        set_session_mode(&id, SessionMode::Webinar).unwrap();
        let status = get_status(&id).unwrap();
        assert!(!status.mic_enabled && status.speaker_enabled);
        stop_session(&id).unwrap();
    }

    #[test]
    fn record_segment_increments_count() {
        let id = start_session(test_config()).unwrap();
        record_segment(&id).unwrap();
        record_segment(&id).unwrap();
        let status = get_status(&id).unwrap();
        assert_eq!(status.segments_count, 2);
        stop_session(&id).unwrap();
    }

    /// `poll_events` drains `pending_events` before it snapshots, so a
    /// snapshot failure must not be propagated: the events are already gone
    /// from the registry and nothing re-delivers them. Returning `Err` here
    /// silently deleted transcript text and VU levels — the UI showed a gap
    /// in the meeting with no error anywhere.
    #[test]
    fn poll_events_keeps_drained_events_when_the_snapshot_cannot_be_written() {
        let home = RecoveryHome::new();
        let id = start_session(test_config()).unwrap();

        with_session_mut(&id, |s| {
            s.pending_events.push(SessionEvent::Transcript(Segment {
                source: "mic".into(),
                speaker: "MIC".into(),
                text: "satu dua tiga".into(),
                timestamp: 1.0,
                duration: 1.5,
                language: "id".into(),
                confidence: 0.9,
                is_partial: false,
                low_confidence: false,
                words: Vec::new(),
                avg_log_prob: -0.2,
            }));
            s.pending_events.push(SessionEvent::Vu {
                source: "mic".into(),
                level: 0.4,
            });
        })
        .unwrap();

        // Make the snapshot write fail for real rather than mocking it: a
        // recovery root that is a regular file makes `create_dir_all` fail,
        // which is what a read-only or full volume looks like here.
        let blocked = home.path().join("not-a-directory");
        std::fs::write(&blocked, b"x").unwrap();
        set_recovery_dir_override(Some(blocked.join("recovery")));
        assert!(
            persist_session_snapshot(&id).is_err(),
            "precondition: the snapshot write has to be failing"
        );

        let events = poll_events(&id).expect("a failed snapshot must not fail the poll");
        assert_eq!(
            events.len(),
            2,
            "both drained events are still delivered: {events:?}"
        );
        assert!(matches!(events[0], SessionEvent::Transcript(_)));
        assert!(matches!(events[1], SessionEvent::Vu { .. }));

        // And they really were drained — a second poll is empty, which is
        // why losing them the first time would have been permanent.
        assert!(poll_events(&id).unwrap().is_empty());

        set_recovery_dir_override(Some(home.path().to_path_buf()));
        stop_session(&id).unwrap();
    }

    #[test]
    fn toggle_on_unknown_session_errors() {
        assert!(toggle_mic("nonexistent", true).is_err());
    }

    #[test]
    fn no_split_before_interval_or_pressure() {
        assert_eq!(should_split(0, 0.1), None);
        assert_eq!(should_split(AUTO_SPLIT_INTERVAL_SECS - 1, 0.5), None);
    }

    #[test]
    fn time_boundary_triggers_split() {
        assert_eq!(
            should_split(AUTO_SPLIT_INTERVAL_SECS, 0.1),
            Some(AutoSplitReason::TimeBoundary)
        );
    }

    #[test]
    fn memory_pressure_triggers_split_even_before_interval() {
        assert_eq!(
            should_split(10, 0.85),
            Some(AutoSplitReason::MemoryPressure)
        );
    }

    #[test]
    fn memory_pressure_takes_priority_over_time_boundary() {
        // Both conditions true — memory pressure is the more urgent reason.
        assert_eq!(
            should_split(AUTO_SPLIT_INTERVAL_SECS, 0.9),
            Some(AutoSplitReason::MemoryPressure)
        );
    }

    #[test]
    fn check_auto_split_and_mark_split_roundtrip() {
        let id = start_session(test_config()).unwrap();
        // Freshly started session, real memory ratio on a test machine
        // should be well under the emergency threshold.
        let result = check_auto_split(&id).unwrap();
        assert_ne!(result, Some(AutoSplitReason::TimeBoundary));
        mark_split(&id).unwrap();
        stop_session(&id).unwrap();
    }

    #[test]
    fn check_auto_split_unknown_session_errors() {
        assert!(check_auto_split("nonexistent").is_err());
    }

    fn seg(source: &str, text: &str, ts: f64) -> Segment {
        Segment {
            source: source.to_string(),
            speaker: source.to_uppercase(),
            text: text.to_string(),
            timestamp: ts,
            duration: 0.0,
            language: "auto".to_string(),
            confidence: 1.0,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
            words: Vec::new(),
        }
    }

    #[test]
    fn cross_source_echo_is_dropped_when_dedupe_enabled() {
        let mut recent = vec![seg("mic", "halo semua selamat pagi", 10.0)];
        let spk_echo = seg("spk", "halo semua selamat pagi", 10.5);

        let result = accept_or_drop_echo(spk_echo, &mut recent, true);

        assert!(
            result.is_none(),
            "speaker echo of mic segment should be dropped"
        );
        // The buffer should still only contain the original mic segment —
        // the dropped echo must not be recorded.
        assert_eq!(recent.len(), 1);
    }

    #[test]
    fn cross_source_echo_kept_when_dedupe_disabled() {
        let mut recent = vec![seg("mic", "halo semua selamat pagi", 10.0)];
        let spk_echo = seg("spk", "halo semua selamat pagi", 10.5);

        let result = accept_or_drop_echo(spk_echo, &mut recent, false);

        assert!(
            result.is_some(),
            "dedupe disabled: echo should pass through"
        );
        assert_eq!(recent.len(), 2);
    }

    #[test]
    fn distinct_text_from_other_source_is_kept() {
        let mut recent = vec![seg("mic", "halo semua", 10.0)];
        let spk_unique = seg("spk", "topik rapat hari ini adalah budget", 10.5);

        let result = accept_or_drop_echo(spk_unique, &mut recent, true);

        assert!(result.is_some());
        assert_eq!(recent.len(), 2);
    }

    #[test]
    fn same_source_never_deduped_against_itself() {
        let mut recent = vec![seg("mic", "halo semua selamat pagi", 10.0)];
        let mic_repeat = seg("mic", "halo semua selamat pagi", 10.5);

        let result = accept_or_drop_echo(mic_repeat, &mut recent, true);

        assert!(
            result.is_some(),
            "same-source repeats are not echo-filtered"
        );
        assert_eq!(recent.len(), 2);
    }

    #[test]
    fn trim_recent_emitted_drops_entries_outside_window() {
        let mut recent = vec![
            seg("mic", "lama sekali", 0.0),
            seg("spk", "baru saja", 100.0),
        ];
        trim_recent_emitted(&mut recent);
        assert_eq!(recent.len(), 1);
        assert_eq!(recent[0].text, "baru saja");
    }

    #[test]
    fn trim_recent_emitted_keeps_all_within_window() {
        let mut recent = vec![seg("mic", "a", 0.0), seg("spk", "b", 5.0)];
        trim_recent_emitted(&mut recent);
        assert_eq!(recent.len(), 2);
    }
}
