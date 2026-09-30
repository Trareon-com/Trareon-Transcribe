//! Session registry: tracks live capture sessions by UUID and their
//! mic/speaker toggle state. The same module also owns crash-recovery
//! snapshots so we can restore an interrupted session after restart.

use std::cell::RefCell;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{mpsc, Arc, Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

use serde::Serialize;
use uuid::Uuid;

use crate::audio::{AudioCapture, SessionConfig, SessionMode};
use crate::dedupe::is_echo;
use crate::error::TranscribeError;
use crate::export::Segment;
use crate::memory;
use crate::pipeline::{HptRoute, LiveEvent, LiveWorker, LiveWorkerConfig};

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
    started_at: std::time::Instant,
    started_at_unix_ms: u64,
    last_split_at: std::time::Instant,
    last_split_at_unix_ms: u64,
    segments_count: u32,
    mic_capture: Option<CaptureChannel>,
    speaker_capture: Option<CaptureChannel>,
    pending_events: Vec<SessionEvent>,
    /// Segments emitted so far, across BOTH mic and speaker sources —
    /// this is where cross-source echo-dedupe actually happens, since
    /// each `LivePipeline` only ever sees its own source (see
    /// `pipeline` module doc comment). Trimmed to a rolling window.
    recent_emitted: Vec<Segment>,
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
    /// Raw 16kHz mono samples for this source, retained for WAV export
    /// (blueprint §7.1: per-track mic.wav + speaker.wav) — filled by the
    /// tee thread in `start_capture`, independent of the STT worker.
    raw_audio: Arc<Mutex<Vec<f32>>>,
}

/// Raw audio retained after a session stops, so the caller (Dart, via
/// `api::export_session_audio`) can write mic.wav/speaker.wav once it
/// knows the final output directory and title — both only known at stop
/// time, same as the transcript export. Cleared on export or session
/// removal so long-running sessions don't leak this buffer forever.
type RawAudioBySource = (Option<Vec<f32>>, Option<Vec<f32>>);

fn audio_registry() -> &'static Mutex<HashMap<String, RawAudioBySource>> {
    static REGISTRY: OnceLock<Mutex<HashMap<String, RawAudioBySource>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Takes (removes) the raw mic/speaker audio retained for `session_id`, if
/// any. Returns `(None, None)` if the session had no live capture (e.g. it
/// was never started, or was a batch-file transcription) or if this was
/// already called for this session.
pub fn take_raw_audio(session_id: &str) -> RawAudioBySource {
    audio_registry()
        .lock()
        .map(|mut reg| reg.remove(session_id).unwrap_or((None, None)))
        .unwrap_or((None, None))
}

#[derive(Debug, Clone, Serialize, serde::Deserialize)]
pub struct SessionRecoverySnapshot {
    pub session_id: String,
    pub config: SessionConfig,
    pub started_at_unix_ms: u64,
    pub last_split_at_unix_ms: u64,
    pub segments_count: u32,
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
    start_session_with_id(id, config)
}

pub fn recover_session(snapshot: SessionRecoverySnapshot) -> Result<String, TranscribeError> {
    start_session_with_id(snapshot.session_id, snapshot.config)
}

fn start_capture(
    enabled: bool,
    device_name: Option<String>,
    worker_config: LiveWorkerConfig,
) -> Result<(Option<CaptureChannel>, CaptureAttempt), TranscribeError> {
    if !enabled {
        return Ok((None, CaptureAttempt::Disabled));
    }
    let source = worker_config.source.clone();
    let (raw_tx, raw_rx) = mpsc::channel();
    let (samples_tx, samples_rx) = mpsc::channel();
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

    let raw_audio: Arc<Mutex<Vec<f32>>> = Arc::new(Mutex::new(Vec::new()));
    let raw_audio_writer = Arc::clone(&raw_audio);
    // Tee: every chunk forwarded to the STT worker (unchanged) is also
    // accumulated here for later WAV export. Isolated to its own thread so
    // the live transcription pipeline (samples_rx consumer) is untouched —
    // this thread simply exits once `raw_tx` (owned by AudioCapture) is
    // dropped, i.e. when capture stops.
    std::thread::spawn(move || {
        while let Ok(chunk) = raw_rx.recv() {
            if let Ok(mut buf) = raw_audio_writer.lock() {
                buf.extend_from_slice(&chunk);
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
    Ok((
        Some(CaptureChannel {
            capture,
            worker,
            source,
            events_rx,
            raw_audio,
        }),
        CaptureAttempt::Started,
    ))
}

pub fn stop_session(session_id: &str) -> Result<(), TranscribeError> {
    let mut reg = registry()
        .lock()
        .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?;
    let state = reg
        .remove(session_id)
        .ok_or_else(|| TranscribeError::SessionNotFound(session_id.to_string()))?;
    drop(reg);

    let mic_audio = state
        .mic_capture
        .as_ref()
        .and_then(|c| c.raw_audio.lock().ok().map(|buf| buf.clone()))
        .filter(|buf| !buf.is_empty());
    let speaker_audio = state
        .speaker_capture
        .as_ref()
        .and_then(|c| c.raw_audio.lock().ok().map(|buf| buf.clone()))
        .filter(|buf| !buf.is_empty());
    if mic_audio.is_some() || speaker_audio.is_some() {
        if let Ok(mut audio_reg) = audio_registry().lock() {
            audio_reg.insert(session_id.to_string(), (mic_audio, speaker_audio));
        }
    }

    remove_snapshot_file(session_id)?;
    Ok(())
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
        elapsed_seconds: state.started_at.elapsed().as_secs_f64(),
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
    persist_session_snapshot(session_id)?;
    Ok(events)
}

pub fn list_recoverable_sessions() -> Result<Vec<SessionRecoverySnapshot>, TranscribeError> {
    let dir = recovery_dir()?;
    let mut out = Vec::new();
    if !dir.exists() {
        return Ok(out);
    }
    for entry in fs::read_dir(dir).map_err(TranscribeError::from)? {
        let entry = entry.map_err(TranscribeError::from)?;
        let path = entry.path();
        if path.extension().and_then(|v| v.to_str()) != Some("inprogress") {
            continue;
        }
        if let Ok(snapshot) = load_snapshot_file(&path) {
            out.push(snapshot);
        }
    }
    out.sort_by(|a, b| a.session_id.cmp(&b.session_id));
    Ok(out)
}

fn start_session_with_id(id: String, config: SessionConfig) -> Result<String, TranscribeError> {
    let now = std::time::Instant::now();
    let now_unix_ms = unix_ms_now()?;
    let language = crate::settings::load_settings().language;
    let refine_model_path = config
        .refine_model_path
        .clone()
        .filter(|p| !p.is_empty() && p != &config.model_path)
        .map(PathBuf::from);
    let worker_config = |source: &str| LiveWorkerConfig {
        quick_model_path: PathBuf::from(&config.model_path),
        refine_model_path: refine_model_path.clone(),
        hpt_mode: config.hpt_mode,
        source: source.to_string(),
        language: language.clone(),
        vad_enabled: config.vad_enabled,
        gpu_enabled: config.gpu_enabled,
        gpu_device: config.gpu_device,
    };
    let (mic_capture, mic_attempt) = start_capture(
        config.mic_enabled,
        config.mic_device_id.clone(),
        worker_config("mic"),
    )?;
    let (speaker_capture, speaker_attempt) = start_capture(
        config.speaker_enabled,
        config.speaker_device_id.clone(),
        worker_config("spk"),
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
                      jadi transkrip langsung memakai model cepat. Setelah sesi selesai, \
                      gunakan \"Transkrip Ulang\" untuk menjalankan ulang dengan model \
                      akurat."
                .to_string(),
        });
    }
    let state = SessionState {
        session_id: id.clone(),
        config,
        started_at: now,
        started_at_unix_ms: now_unix_ms,
        last_split_at: now,
        last_split_at_unix_ms: now_unix_ms,
        segments_count: 0,
        mic_capture,
        speaker_capture,
        pending_events,
        recent_emitted: Vec::new(),
    };
    registry()
        .lock()
        .map_err(|_| TranscribeError::Transcription("session registry lock poisoned".into()))?
        .insert(id.clone(), state);
    persist_session_snapshot(&id)?;
    Ok(id)
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
        }
    };
    write_snapshot_file(&snapshot)
}

/// Recovery snapshots contain only session configuration metadata
/// (mode, mic/speaker toggles, model path) — no transcript content.
/// Stored under the OS app-config directory (not temp), so they persist
/// across reboots and are isolated per-user.
fn recovery_dir() -> Result<PathBuf, TranscribeError> {
    if let Some(path) = RECOVERY_DIR_OVERRIDE.with(|slot| slot.borrow().clone()) {
        return Ok(path);
    }
    // OS config dir is per-user and not world-readable (unlike /tmp).
    let dir = dirs::config_dir()
        .ok_or_else(|| TranscribeError::InvalidInput("no config dir".into()))?
        .join("TrareonTranscribe")
        .join("recovery");
    Ok(dir)
}

fn recovery_path(session_id: &str) -> Result<PathBuf, TranscribeError> {
    Ok(recovery_dir()?.join(format!("{session_id}.inprogress")))
}

fn write_snapshot_file(snapshot: &SessionRecoverySnapshot) -> Result<(), TranscribeError> {
    let dir = recovery_dir()?;
    fs::create_dir_all(&dir).map_err(TranscribeError::from)?;
    let final_path = recovery_path(&snapshot.session_id)?;
    let tmp_path = final_path.with_extension("inprogress.tmp");
    let json = serde_json::to_vec_pretty(snapshot)
        .map_err(|e| TranscribeError::InvalidInput(e.to_string()))?;
    fs::write(&tmp_path, json).map_err(TranscribeError::from)?;
    fs::rename(&tmp_path, &final_path).map_err(TranscribeError::from)
}

fn remove_snapshot_file(session_id: &str) -> Result<(), TranscribeError> {
    let path = recovery_path(session_id)?;
    match fs::remove_file(path) {
        Ok(_) => Ok(()),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(err) => Err(TranscribeError::from(err)),
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
    fn collect_worker_events(&mut self) {
        let dedupe_enabled = self.config.mode.echo_dedupe_enabled();

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
        }

        if let Some(capture) = self.mic_capture.as_ref() {
            while let Ok(event) = capture.events_rx.try_recv() {
                match event {
                    LiveEvent::Segment(segment) => {
                        if let Some(segment) =
                            accept_or_drop_echo(segment, &mut self.recent_emitted, dedupe_enabled)
                        {
                            self.segments_count = self.segments_count.saturating_add(1);
                            self.pending_events.push(SessionEvent::Transcript(segment));
                        }
                    }
                    LiveEvent::Vu { source, level } => {
                        self.pending_events.push(SessionEvent::Vu { source, level });
                    }
                }
            }
        }
        if let Some(capture) = self.speaker_capture.as_ref() {
            while let Ok(event) = capture.events_rx.try_recv() {
                match event {
                    LiveEvent::Segment(segment) => {
                        if let Some(segment) =
                            accept_or_drop_echo(segment, &mut self.recent_emitted, dedupe_enabled)
                        {
                            self.segments_count = self.segments_count.saturating_add(1);
                            self.pending_events.push(SessionEvent::Transcript(segment));
                        }
                    }
                    LiveEvent::Vu { source, level } => {
                        self.pending_events.push(SessionEvent::Vu { source, level });
                    }
                }
            }
        }
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

    #[test]
    fn recovery_snapshot_roundtrip_and_cleanup() {
        let dir =
            std::env::temp_dir().join(format!("transcribe_recovery_{}", uuid::Uuid::new_v4()));
        let _ = std::fs::remove_dir_all(&dir);
        set_recovery_dir_override(Some(dir.clone()));

        let id = start_session(test_config()).unwrap();
        let snapshots = list_recoverable_sessions().unwrap();
        assert_eq!(snapshots.len(), 1);
        assert_eq!(snapshots[0].session_id, id);

        stop_session(&id).unwrap();
        let snapshots = list_recoverable_sessions().unwrap();
        assert!(snapshots.is_empty());

        let _ = std::fs::remove_dir_all(&dir);
        set_recovery_dir_override(None);
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
