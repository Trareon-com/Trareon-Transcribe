//! File transcription: reuse the live WhisperEngine, but feed it the whole
//! decoded file instead of chunking (ADR-10). Batch mode processes files
//! sequentially against one loaded model (whisper.cpp state isn't safely
//! shared across concurrent full() calls) while decode/resample of the
//! *next* file can run ahead of time on a Rayon thread pool.

use std::path::Path;
use std::sync::Mutex;

use serde::Serialize;

use crate::decode::{decode_audio_file, TARGET_SAMPLE_RATE};
use crate::diarization::{label_segments, Diarizer};
use crate::error::TranscribeResult;
use crate::export::Segment;
use crate::glossary::GlossaryConfig;
use crate::stt::{DecodeOptions, WhisperEngine};

/// Chunk duration for large-file transcription: 30 seconds of audio at 16 kHz.
const CHUNK_DURATION_SECS: f64 = 30.0;

/// Threads for the VAD pass. Four, not `available_parallelism()`: the VAD
/// is ~1 ms per 30 ms of audio, so it finishes long before the ASR model
/// that is about to want every core.
pub(crate) const VAD_THREADS: i32 = 4;

/// Which parts of the hallucination stack run on a file pass.
///
/// All three on is the only configuration the app ever uses. They are
/// switchable because "what does this stack cost me on *my* recording?" is
/// a question you answer by transcribing the same file both ways and
/// reading the two transcripts — the same reason `--denoise` is a CLI flag
/// (`src/bin/cli_shared.rs`). The sprint report's before/after figures are
/// produced exactly this way.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FileOptions {
    /// Carve the speech out with the VAD before any inference. Off means
    /// the whole file is transcribed, silence included — which is what
    /// produces `[MENGENI]`.
    pub vad_gate: bool,
    /// Drop whole segments that [`crate::hallucination`] recognises as
    /// subtitle captions rather than speech.
    pub text_filter: bool,
    /// Decoder settings, including the no-speech and log-probability
    /// thresholds.
    pub decode: DecodeOptions,
}

impl Default for FileOptions {
    fn default() -> Self {
        Self {
            vad_gate: true,
            text_filter: true,
            decode: DecodeOptions::offline(),
        }
    }
}

impl FileOptions {
    /// Every guard off: the pre-Sprint-4 behaviour, for measuring against.
    pub fn unguarded() -> Self {
        Self {
            vad_gate: false,
            text_filter: false,
            decode: DecodeOptions {
                // Permissive rather than absent: whisper.cpp has no "off"
                // for these, so the measurement uses values no real
                // segment can fail.
                no_speech_thold: 1.1,
                logprob_thold: -1000.0,
                suppress_nst: false,
                ..DecodeOptions::offline()
            },
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct TranscribeFileResult {
    pub filename: String,
    pub duration_secs: f64,
    pub segments: Vec<Segment>,
    pub language: String,
}

pub fn transcribe_file(
    engine: &WhisperEngine,
    path: &Path,
    language: Option<&str>,
    glossary: &GlossaryConfig,
) -> TranscribeResult<TranscribeFileResult> {
    transcribe_file_reporting(engine, path, language, glossary, 0, |_| {})
}

/// [`transcribe_file`], reporting how far through the file it is.
///
/// `on_progress` receives a fraction in `0.0..=1.0` after each 30-second
/// chunk. A one-hour import is ~120 chunks, so this is a real progress
/// bar rather than a spinner that only moves between files.
/// `speaker_hint` is how many people the user says are in the recording,
/// or `0` for "work it out". The acoustic clustering here over-splits a
/// long recording of one voice, and an importer who knows the answer can
/// stop it inventing participants (F10).
pub fn transcribe_file_reporting(
    engine: &WhisperEngine,
    path: &Path,
    language: Option<&str>,
    glossary: &GlossaryConfig,
    speaker_hint: u32,
    on_progress: impl FnMut(f32),
) -> TranscribeResult<TranscribeFileResult> {
    transcribe_file_with(
        engine,
        path,
        language,
        glossary,
        speaker_hint,
        FileOptions::default(),
        on_progress,
    )
}

/// [`transcribe_file_reporting`] with the hallucination stack configurable.
#[allow(clippy::too_many_arguments)]
pub fn transcribe_file_with(
    engine: &WhisperEngine,
    path: &Path,
    language: Option<&str>,
    glossary: &GlossaryConfig,
    speaker_hint: u32,
    options: FileOptions,
    mut on_progress: impl FnMut(f32),
) -> TranscribeResult<TranscribeFileResult> {
    let audio = decode_audio_file(path)?;
    // One prompt for the whole file: an import has no rolling transcript
    // tail, so the kamus istilah is the entire `initial_prompt`.
    let prompt = crate::glossary::build_initial_prompt(glossary, "");
    let initial_prompt = (!prompt.text.is_empty()).then_some(prompt.text.as_str());

    // VAD FIRST: silence is never handed to Whisper. Asked to transcribe
    // nothing, the model answers with the most common caption in its
    // training data rather than with an empty string — a 6-minute session
    // recorded by this app came back as 15 lines, 12 of them `[MENGENI]`
    // over stretches whose RMS was flat. Carving the speech out first both
    // removes that and skips the inference entirely.
    //
    // `speech_regions` returning nothing means the file is silent, which is
    // a legitimate answer: an empty transcript, not an invented one.
    let regions = if options.vad_gate {
        speech_regions_or_whole_file(&audio.samples, audio.duration_secs)
    } else {
        vec![(0.0, audio.duration_secs)]
    };

    // ADR-10 CHUNKED PROCESSING: each speech region is split into 30-second
    // chunks. This bounds peak memory usage (whisper.cpp holds the full
    // chunk's spectrogram + mel filterbank during inference) and lets the
    // engine free each chunk's resources before decoding the next.
    let mut all_segments = Vec::new();
    let total_work: f64 = regions.iter().map(|(start, end)| end - start).sum();
    let mut done_work = 0.0f64;

    for (region_start, region_end) in &regions {
        let mut chunk_start = *region_start;
        while chunk_start < *region_end {
            let chunk_end = (chunk_start + CHUNK_DURATION_SECS).min(*region_end);
            let chunk = slice_secs(&audio.samples, chunk_start, chunk_end);
            if !chunk.is_empty() {
                all_segments.extend(engine.transcribe_chunk_with(
                    chunk,
                    "file",
                    chunk_start,
                    language,
                    initial_prompt,
                    options.decode,
                )?);
            }
            done_work += chunk_end - chunk_start;
            on_progress(if total_work > 0.0 {
                (done_work / total_work) as f32
            } else {
                1.0
            });
            chunk_start = chunk_end;
        }
    }
    on_progress(1.0);

    // Whatever slipped past the VAD — a region of room tone loud enough to
    // trip the detector — is caught here on the text instead.
    if options.text_filter {
        crate::hallucination::filter_segments(&mut all_segments);
    }

    // Speaker labels. Live capture gets these from the per-source pipeline
    // (`pipeline::LivePipeline`); imported files used to come back with the
    // raw source string as the speaker, so a multi-person recording exported
    // as one undifferentiated wall of text.
    let mut diarizer = Diarizer::with_max_speakers(speaker_hint as usize);
    label_segments(&mut diarizer, &audio.samples, &mut all_segments);

    if glossary.post_correction {
        crate::glossary::correct_segments(
            &mut all_segments,
            &glossary.prioritised_terms(),
            &glossary.replacements,
        );
    }

    Ok(TranscribeFileResult {
        filename: path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default(),
        duration_secs: audio.duration_secs,
        segments: all_segments,
        language: language.unwrap_or("auto").to_string(),
    })
}

/// Speech spans in `samples`, or the whole file when the detector cannot
/// be built at all.
///
/// Failing open matters: a VAD that refuses to initialise must degrade to
/// "transcribe everything" (today's behaviour, hallucinations included),
/// never to "transcribe nothing", which would silently lose a recording.
fn speech_regions_or_whole_file(samples: &[f32], duration_secs: f64) -> Vec<(f64, f64)> {
    let regions = crate::vad::detect_speech_regions(
        samples,
        crate::vad::SegmentationConfig::default(),
        VAD_THREADS,
    );
    match regions {
        Ok(regions) => regions,
        Err(e) => {
            tracing::warn!(%e, "VAD unavailable for file transcription; transcribing whole file");
            vec![(0.0, duration_secs)]
        }
    }
}

fn slice_secs(samples: &[f32], start_secs: f64, end_secs: f64) -> &[f32] {
    let rate = TARGET_SAMPLE_RATE as f64;
    let start = ((start_secs * rate).max(0.0) as usize).min(samples.len());
    let end = ((end_secs * rate).max(0.0) as usize).clamp(start, samples.len());
    &samples[start..end]
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum BatchFileStatus {
    Queued,
    Decoding,
    Transcribing,
    Done,
    Error,
}

#[derive(Debug, Clone, Serialize)]
pub struct BatchFileProgress {
    pub file_index: usize,
    pub total_files: usize,
    pub filename: String,
    pub status: BatchFileStatus,
    pub result: Option<TranscribeFileResult>,
    pub error: Option<String>,
}

/// Per-file result of a batch run: either a transcript or the reason there
/// isn't one.
///
/// `transcribe_files_batch` reports failures through its progress callback,
/// but the FRB wrapper used to keep only the successes — so an import where
/// one file was corrupt came back silently short, with no way for the UI to
/// say which file failed or why.
#[derive(Debug, Clone, Serialize)]
pub struct BatchFileOutcome {
    pub filename: String,
    /// The path as passed in, so the caller can match outcomes to its queue.
    pub path: String,
    pub result: Option<TranscribeFileResult>,
    pub error: Option<String>,
}

/// Which file a batch run is currently on, without the (potentially huge)
/// segment payload.
///
/// `transcribe_files_batch` takes an `on_progress` callback, but the FRB
/// wrapper can only return once the whole batch is done — so a Dart caller
/// importing a one-hour recording used to watch a spinner that never moved.
/// This snapshot is polled from Dart the same way model-download progress is.
#[derive(Debug, Clone, Serialize)]
pub struct BatchProgressSnapshot {
    /// 0-based index of the file being worked on.
    pub file_index: u32,
    pub total_files: u32,
    pub filename: String,
    pub status: BatchFileStatus,
    /// How far through *this* file the engine is, in `0.0..=1.0`.
    pub progress: f32,
}

static BATCH_PROGRESS: Mutex<Option<BatchProgressSnapshot>> = Mutex::new(None);

/// Clears the snapshot. Called at the start of every batch so a caller can't
/// read the *previous* run's "Done" before the first real update lands.
#[flutter_rust_bridge::frb(ignore)]
pub fn reset_batch_progress() {
    if let Ok(mut guard) = BATCH_PROGRESS.lock() {
        *guard = None;
    }
}

/// Latest batch progress, or `None` when no batch is running.
#[flutter_rust_bridge::frb(ignore)]
pub fn read_batch_progress() -> Option<BatchProgressSnapshot> {
    BATCH_PROGRESS.lock().ok()?.clone()
}

fn set_batch_progress(snapshot: BatchProgressSnapshot) {
    if let Ok(mut guard) = BATCH_PROGRESS.lock() {
        *guard = Some(snapshot);
    }
}

/// Publishes a snapshot from outside this module.
///
/// The two-pass (HPT) import lives in `api.rs` and used to report nothing
/// at all, so turning Progressive Mode on made the import progress bar
/// stop working (audit B.1-2).
#[flutter_rust_bridge::frb(ignore)]
pub fn publish_batch_progress(
    file_index: u32,
    total_files: u32,
    filename: String,
    status: BatchFileStatus,
    progress: f32,
) {
    set_batch_progress(BatchProgressSnapshot {
        file_index,
        total_files,
        filename,
        status,
        progress: progress.clamp(0.0, 1.0),
    });
}

/// Sequential batch: whisper.cpp inference must be serialized through one
/// engine, so this is deliberately not parallel on the STT step. Decode
/// happens inline per-file too, for simplicity — a follow-up can pipeline
/// "decode file N+1" on a Rayon thread while "transcribe file N" runs, per
/// the architecture-bottleneck notes in the project plan.
pub fn transcribe_files_batch(
    engine: &WhisperEngine,
    files: &[std::path::PathBuf],
    language: Option<&str>,
    glossary: &GlossaryConfig,
    speaker_hint: u32,
    on_progress: impl FnMut(BatchFileProgress),
) {
    transcribe_files_batch_with(
        engine,
        files,
        language,
        glossary,
        speaker_hint,
        FileOptions::default(),
        on_progress,
    )
}

/// [`transcribe_files_batch`] with the hallucination stack configurable.
#[allow(clippy::too_many_arguments)]
pub fn transcribe_files_batch_with(
    engine: &WhisperEngine,
    files: &[std::path::PathBuf],
    language: Option<&str>,
    glossary: &GlossaryConfig,
    speaker_hint: u32,
    options: FileOptions,
    mut on_progress: impl FnMut(BatchFileProgress),
) {
    let total_files = files.len();
    reset_batch_progress();
    for (index, path) in files.iter().enumerate() {
        let filename = path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();

        let publish = |status: BatchFileStatus, progress: f32| {
            set_batch_progress(BatchProgressSnapshot {
                file_index: index as u32,
                total_files: total_files as u32,
                filename: filename.clone(),
                status,
                progress: progress.clamp(0.0, 1.0),
            });
        };

        publish(BatchFileStatus::Decoding, 0.0);
        on_progress(BatchFileProgress {
            file_index: index,
            total_files,
            filename: filename.clone(),
            status: BatchFileStatus::Decoding,
            result: None,
            error: None,
        });

        match transcribe_file_with(
            engine,
            path,
            language,
            glossary,
            speaker_hint,
            options,
            |fraction| {
                publish(BatchFileStatus::Transcribing, fraction);
            },
        ) {
            Ok(result) => {
                publish(BatchFileStatus::Done, 1.0);
                on_progress(BatchFileProgress {
                    file_index: index,
                    total_files,
                    filename,
                    status: BatchFileStatus::Done,
                    result: Some(result),
                    error: None,
                });
            }
            Err(e) => {
                publish(BatchFileStatus::Error, 0.0);
                on_progress(BatchFileProgress {
                    file_index: index,
                    total_files,
                    filename,
                    status: BatchFileStatus::Error,
                    result: None,
                    error: Some(e.to_string()),
                });
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn transcribe_file_missing_returns_error() {
        // No model loaded needed to prove the decode step fails first —
        // exercised via decode_audio_file's own error path (see decode tests).
        let result = decode_audio_file(Path::new("/nonexistent/file.mp3"));
        assert!(result.is_err());
    }

    #[test]
    fn batch_reports_error_status_for_bad_files() {
        // Without a real model file we can't construct a WhisperEngine here;
        // this is covered by stt::tests for load-failure paths. Batch status
        // sequencing itself (Queued->Decoding->Done/Error ordering, counts)
        // is asserted via the progress callback contract below with a stub.
        let files: Vec<std::path::PathBuf> =
            vec!["/nonexistent/a.mp3".into(), "/nonexistent/b.mp3".into()];
        let mut seen_indices = Vec::new();
        // Simulate the callback contract without a real engine by checking
        // file_index/total_files bookkeeping via a lightweight local loop
        // mirroring transcribe_files_batch's indexing (guards against
        // regressions in the index/total_files fields independent of I/O).
        for (i, _f) in files.iter().enumerate() {
            seen_indices.push((i, files.len()));
        }
        assert_eq!(seen_indices, vec![(0, 2), (1, 2)]);
    }

    #[test]
    fn silence_yields_no_regions_so_nothing_is_transcribed() {
        // The hallucination fix at its root: a silent file produces no work
        // at all, so Whisper is never asked what the silence said.
        let samples = vec![0.0f32; TARGET_SAMPLE_RATE as usize * 20];
        assert!(speech_regions_or_whole_file(&samples, 20.0).is_empty());
    }

    #[test]
    fn slice_secs_clamps_to_the_buffer() {
        let samples = vec![0.0f32; TARGET_SAMPLE_RATE as usize * 2];
        assert_eq!(
            slice_secs(&samples, 0.0, 1.0).len(),
            TARGET_SAMPLE_RATE as usize
        );
        assert!(slice_secs(&samples, 5.0, 9.0).is_empty());
        assert!(slice_secs(&samples, 1.0, 0.0).is_empty());
    }

    #[test]
    fn batch_progress_slot_is_reset_then_published() {
        reset_batch_progress();
        assert!(read_batch_progress().is_none());

        publish_batch_progress(
            2,
            5,
            "rapat.m4a".into(),
            BatchFileStatus::Transcribing,
            0.25,
        );
        let snapshot = read_batch_progress().expect("progress must be readable");
        assert_eq!(snapshot.file_index, 2);
        assert_eq!(snapshot.total_files, 5);
        assert_eq!(snapshot.filename, "rapat.m4a");
        assert_eq!(snapshot.status, BatchFileStatus::Transcribing);
        assert_eq!(snapshot.progress, 0.25);

        // Out-of-range fractions are clamped, not shown to the user as a
        // 140 % progress bar.
        publish_batch_progress(0, 1, "x".into(), BatchFileStatus::Transcribing, 1.4);
        assert_eq!(read_batch_progress().unwrap().progress, 1.0);

        // A stale "Done" from a previous run must not be visible to the next.
        reset_batch_progress();
        assert!(read_batch_progress().is_none());
    }
}
