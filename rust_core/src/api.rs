//! Public API surface exposed to Flutter via flutter_rust_bridge V2.
//!
//! FRB-compatible: no lifetimes in public signatures, every fallible
//! function returns `Result<T, TranscribeError>`. Streams (`vu_meter_stream`,
//! `transcript_stream`, live audio thread wiring) land once FRB codegen is
//! set up against the actual Flutter app.

use std::collections::HashMap;
use std::path::PathBuf;

use crate::audio::{AudioDeviceInfo, SessionConfig};
use crate::doctor::{format_checks, run_checks, Check};
use crate::error::TranscribeError;
use crate::export::{ExportFormat, ExportedFile, Segment};
use crate::model::ModelInfo;
use crate::session::{
    CaptureHealth, RecoverableSession, RecoveredSession, SessionEvent, SessionRecoverySnapshot,
    SessionStatus,
};
use crate::settings::AppSettings;

pub fn run_preflight_checks() -> Vec<Check> {
    let settings = crate::settings::load_settings();
    run_checks(&settings)
}

pub fn format_preflight_checks(checks: Vec<Check>) -> String {
    format_checks(&checks)
}

/// What this *build* can actually do for GPU inference.
///
/// The Settings switch is a request, not a capability: whisper.cpp only
/// has a GPU backend if one was compiled in, so on a plain Linux build
/// turning "Akselerasi GPU" on changes nothing at all. The settings screen
/// used to claim "Transkripsi menggunakan GPU (Vulkan/CUDA/Metal)" purely
/// because the switch was on, which is a statement about the UI rather
/// than about the machine.
pub struct GpuCapability {
    /// True when a GPU backend is compiled into this binary.
    pub available: bool,
    /// Human-facing backend name: "Vulkan", "CoreML", "Metal", "CPU".
    pub backend: String,
}

pub fn gpu_capability() -> GpuCapability {
    #[cfg(feature = "gpu-vulkan")]
    {
        GpuCapability {
            available: true,
            backend: "Vulkan".to_string(),
        }
    }
    #[cfg(all(not(feature = "gpu-vulkan"), target_os = "macos"))]
    {
        // whisper.cpp builds Metal (and CoreML on Apple Silicon) in by
        // default on Apple platforms.
        GpuCapability {
            available: true,
            backend: crate::stt::detect_backend(),
        }
    }
    #[cfg(all(not(feature = "gpu-vulkan"), not(target_os = "macos")))]
    {
        GpuCapability {
            available: false,
            backend: "CPU".to_string(),
        }
    }
}

/// Installs a `tracing` subscriber writing to stderr. Without this,
/// every `tracing::error!`/`warn!` call in the engine (session/pipeline
/// failures, capture errors, etc.) is silently dropped — there is no
/// default subscriber. Call once, right after `RustLib.init()`, before
/// anything else. Safe to call more than once (subsequent calls are a
/// harmless no-op via `try_init`).
pub fn init_logging() {
    let _ = tracing_subscriber::fmt::try_init();
}

pub fn engine_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

pub fn health_check() -> Result<bool, TranscribeError> {
    Ok(true)
}

// --- Audio devices -----------------------------------------------------

pub fn list_audio_devices() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    crate::audio::list_input_devices()
}

/// Playback devices — what the "Pengeras Suara" / loopback picker must show.
///
/// The speaker picker used to call [`list_audio_devices`], so it offered the
/// user a list of microphones to record the system audio from. On Linux this
/// resolves to PulseAudio/PipeWire *sinks* (same source of truth as
/// `audio::pulse`, which the loopback capture then turns into
/// `<sink>.monitor`), so what the picker shows and what gets recorded agree.
pub fn list_output_audio_devices() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    crate::audio::list_output_devices()
}

// --- Session control -----------------------------------------------------

pub fn start_session(config: SessionConfig) -> Result<String, TranscribeError> {
    crate::session::start_session(config)
}

pub fn stop_session(session_id: String) -> Result<(), TranscribeError> {
    crate::session::stop_session(&session_id)
}

pub fn toggle_mic(session_id: String, enabled: bool) -> Result<(), TranscribeError> {
    crate::session::toggle_mic(&session_id, enabled)
}

pub fn toggle_speaker(session_id: String, enabled: bool) -> Result<(), TranscribeError> {
    crate::session::toggle_speaker(&session_id, enabled)
}

pub fn get_session_status(session_id: String) -> Result<SessionStatus, TranscribeError> {
    crate::session::get_status(&session_id)
}

pub fn poll_session_events(session_id: String) -> Result<Vec<SessionEvent>, TranscribeError> {
    crate::session::poll_events(&session_id)
}

/// Sessions left behind by a crash, with what is actually recoverable for
/// each (segment count, audio duration per source) rather than just the
/// configuration the old snapshot carried.
pub fn list_recoverable_sessions() -> Result<Vec<RecoverableSession>, TranscribeError> {
    crate::session::list_recoverable_sessions()
}

/// Restores a crashed session: returns its recovered transcript along with
/// the live session id, and resumes capture into the same audio files.
pub fn recover_session(
    snapshot: SessionRecoverySnapshot,
) -> Result<RecoveredSession, TranscribeError> {
    crate::session::recover_session(snapshot)
}

/// Discards one recoverable session and everything it held.
pub fn delete_recoverable_session(session_id: String) -> Result<(), TranscribeError> {
    crate::session::delete_recoverable_session(&session_id)
}

/// Live capture health: how much audio each source has actually delivered,
/// whether it has ever been above the noise floor ("rekaman terkonfirmasi")
/// and how long it has been quiet. Drives both the recording indicator and
/// the integrity summary shown at Stop.
pub fn get_capture_health(session_id: String) -> Result<CaptureHealth, TranscribeError> {
    crate::session::get_capture_health(&session_id)
}

/// Mirrors the user-entered title into the recovery snapshot, so a crashed
/// session appears in the recovery dialog under its name.
pub fn set_session_title(session_id: String, title: String) -> Result<(), TranscribeError> {
    crate::session::set_session_title(&session_id, &title)
}

// --- Disk space -----------------------------------------------------

/// Free space on the volume holding `path`, plus whether that is enough to
/// keep recording. Called before a session starts and periodically while
/// one runs — three hours of "Rapat Online" is ~1.4 GB of WAV, and nothing
/// used to check.
pub fn check_disk_space(path: String) -> crate::disk::DiskSpaceStatus {
    crate::disk::status_for(std::path::Path::new(&path))
}

// --- Model management -----------------------------------------------------

/// Benchmark a model's realtime factor (seconds of audio transcribed per
/// second of wall-clock) using a 5s calibration chunk. Used by adaptive
/// HPT to decide whether a device can run q5 in a single pass.
/// Returns an error if the model cannot be loaded.
/// (No network access — purely local inference benchmark.)
pub fn benchmark_rtf(model_path: String) -> Result<f64, TranscribeError> {
    let engine = crate::stt::WhisperEngine::load(std::path::Path::new(&model_path))
        .map_err(|e| TranscribeError::Model(format!("benchmark model load failed: {e}")))?;
    Ok(crate::benchmark::benchmark_rtf(&engine))
}

pub fn list_available_models(models_dir: String) -> Vec<ModelInfo> {
    crate::model::list_available_models(&PathBuf::from(models_dir))
}

pub fn is_model_downloaded(models_dir: String, model_id: String) -> bool {
    crate::model::is_model_downloaded(&PathBuf::from(models_dir), &model_id)
}

pub async fn download_model(models_dir: String, model_id: String) -> Result<(), TranscribeError> {
    let models_path = PathBuf::from(models_dir);
    let info = crate::model::resolve_model_info(&models_path, &model_id)?;
    let dest_path = crate::model::resolve_model_path(&models_path, &model_id)?;

    if let Some(parent) = dest_path.parent() {
        std::fs::create_dir_all(parent).map_err(TranscribeError::from)?;
    }

    // Progress is a single global slot (see model.rs), shared across every
    // call — without resetting here, a caller downloading models back to
    // back (onboarding) would briefly read the *previous* download's 100%
    // before the first progress callback for this one lands.
    crate::model::reset_download_progress();

    crate::model::download_with_resume(&info.url, &dest_path, |progress| {
        crate::model::set_download_progress(progress.bytes_downloaded, progress.total_bytes);
    })
    .await?;

    if !info.sha256.is_empty() {
        crate::model::verify_checksum(&dest_path, &info.sha256)?;
    }

    Ok(())
}

/// Poll the current download progress. Returns `None` if no download is
/// in progress or progress tracking has been reset.
pub fn get_download_progress() -> Option<(u64, u64)> {
    crate::model::read_download_progress().map(|p| (p.bytes_downloaded, p.total_bytes))
}

// --- Export -----------------------------------------------------

pub fn export_session(
    segments: Vec<Segment>,
    formats: Vec<ExportFormat>,
    output_dir: String,
    title: String,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    crate::export::export_segments(&segments, &formats, &PathBuf::from(output_dir), &title)
}

/// As [`export_session`], but leads the Markdown/TXT/HTML/DOCX output with
/// `summary` (Markdown, from [`generate_summary`]). An empty `summary`
/// produces byte-identical output to [`export_session`].
pub fn export_session_with_summary(
    segments: Vec<Segment>,
    formats: Vec<ExportFormat>,
    output_dir: String,
    title: String,
    summary: String,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    crate::export::export_segments_with_summary(
        &segments,
        &formats,
        &PathBuf::from(output_dir),
        &title,
        &summary,
    )
}

/// Writes the raw mic/speaker audio captured during `session_id`'s live
/// recording as WAV files into the same session folder `export_session`
/// uses (blueprint §7.1: per-track mic.wav + speaker.wav). Call once, after
/// `stop_session` — the raw audio is only retained until the first call for
/// a given session. Returns an empty list (not an error) when there was no
/// live capture to save, e.g. a batch-file transcription.
pub fn export_session_audio(
    session_id: String,
    output_dir: String,
    title: String,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    use crate::export::CapturedTrack;
    let audio = crate::session::take_session_audio(&session_id);
    let mic = audio
        .mic_file
        .as_deref()
        .map(CapturedTrack::File)
        .or_else(|| audio.mic_samples.as_deref().map(CapturedTrack::Samples));
    let speaker = audio
        .speaker_file
        .as_deref()
        .map(CapturedTrack::File)
        .or_else(|| audio.speaker_samples.as_deref().map(CapturedTrack::Samples));
    let exported =
        crate::export::export_session_audio(mic, speaker, &PathBuf::from(output_dir), &title)?;
    // The staged WAVs were the last thing holding the session's recovery
    // directory open.
    crate::session::release_recovery_dir(&session_id);
    Ok(exported)
}

// --- Hybrid Progressive Transcription (HPT) --------------------------------------

/// Result of an HPT (dual-model) file transcription: the quick pass from
/// `base` (`is_partial = true`) and the refined pass from
/// `large-v3-turbo-q5` (`is_partial = false`). Same segment order, same
/// `(source, timestamp)` keys — Dart replaces text by key.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ProgressiveFileResult {
    pub filename: String,
    pub quick_segments: Vec<Segment>,
    pub refined_segments: Vec<Segment>,
    pub language: String,
}

/// HPT file transcription: quick pass (base) then refine pass
/// (large-v3-turbo-q5) over the same decoded audio. UI shows
/// `quick_segments` immediately, then swaps in `refined_segments`
/// by key — target latency to first text: 3-5s.
pub fn progressive_transcribe_file(
    quick_model_path: String,
    refine_model_path: String,
    path: String,
    language: Option<String>,
    gpu_enabled: bool,
    gpu_device: i32,
) -> Result<ProgressiveFileResult, TranscribeError> {
    let engine = crate::progressive::ProgressiveEngine::load(
        std::path::Path::new(&quick_model_path),
        std::path::Path::new(&refine_model_path),
        gpu_enabled,
        gpu_device,
    )?;
    let audio = crate::decode::decode_audio_file(std::path::Path::new(&path))?;

    // Chunk like file.rs: 30s chunks bound peak memory.
    const CHUNK_SECS: f64 = 30.0;
    let chunk_samples = (crate::decode::TARGET_SAMPLE_RATE as f64 * CHUNK_SECS) as usize;
    let mut quick_segments = Vec::new();
    let mut refined_segments = Vec::new();

    if audio.samples.len() <= chunk_samples {
        quick_segments =
            engine.transcribe_quick(&audio.samples, "file", 0.0, language.as_deref(), None)?;
        refined_segments =
            engine.transcribe_refine(&audio.samples, "file", 0.0, language.as_deref(), None)?;
    } else {
        for (idx, chunk) in audio.samples.chunks(chunk_samples).enumerate() {
            let start = idx as f64 * CHUNK_SECS;
            quick_segments.extend(engine.transcribe_quick(
                chunk,
                "file",
                start,
                language.as_deref(),
                None,
            )?);
            refined_segments.extend(engine.transcribe_refine(
                chunk,
                "file",
                start,
                language.as_deref(),
                None,
            )?);
        }
    }

    // Hallucination guard: collapse repeated runs in both passes.
    crate::progressive::filter_loops(&mut quick_segments);
    crate::progressive::filter_loops(&mut refined_segments);

    // Speaker labels, same as the single-model file path. Both passes are
    // labelled from a single diarizer over the same audio so the quick and
    // refined rows for one utterance agree — a label that flips when the
    // refine pass lands reads as a bug to the user.
    let mut diarizer = crate::diarization::Diarizer::new();
    crate::diarization::label_segments(&mut diarizer, &audio.samples, &mut refined_segments);
    let labels: std::collections::HashMap<String, String> = refined_segments
        .iter()
        .map(|s| {
            (
                format!("{}@{:.2}", s.source, s.timestamp),
                s.speaker.clone(),
            )
        })
        .collect();
    for segment in quick_segments.iter_mut() {
        let key = format!("{}@{:.2}", segment.source, segment.timestamp);
        if let Some(label) = labels.get(&key) {
            segment.speaker = label.clone();
        }
    }

    Ok(ProgressiveFileResult {
        filename: std::path::Path::new(&path)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default(),
        quick_segments,
        refined_segments,
        language: language.unwrap_or_else(|| "auto".to_string()),
    })
}

// --- File transcription (batch) -----------------------------------------------------

/// Transcribes every file in `files` against a single loaded model.
///
/// Loading the model is the expensive part (≈550 MB for large-v3-turbo-q5),
/// so callers should pass the whole queue in one call rather than looping
/// per file. Returns one outcome per input file, in input order, carrying
/// either the transcript or the error — so a single bad file no longer
/// disappears from the results without explanation.
pub fn transcribe_files_batch(
    model_path: String,
    files: Vec<String>,
    language: Option<String>,
    gpu_enabled: bool,
    gpu_device: i32,
) -> Result<Vec<crate::stt::file::BatchFileOutcome>, TranscribeError> {
    let engine = crate::stt::WhisperEngine::load_with_gpu(
        &PathBuf::from(&model_path),
        gpu_enabled,
        gpu_device,
    )?;
    let file_paths: Vec<PathBuf> = files.iter().map(PathBuf::from).collect();
    let mut outcomes = Vec::with_capacity(file_paths.len());

    crate::stt::file::transcribe_files_batch(
        &engine,
        &file_paths,
        language.as_deref(),
        |progress| {
            // Decoding is an interim status; only terminal states produce an
            // outcome, otherwise every file would be reported twice.
            if progress.result.is_none() && progress.error.is_none() {
                return;
            }
            outcomes.push(crate::stt::file::BatchFileOutcome {
                filename: progress.filename,
                path: files.get(progress.file_index).cloned().unwrap_or_default(),
                result: progress.result,
                error: progress.error,
            });
        },
    );

    Ok(outcomes)
}

/// Which file [`transcribe_files_batch`] is currently on. Poll this while the
/// batch future is in flight — that call only returns once *every* file is
/// done, so without it a long import shows a spinner that never moves.
pub fn get_batch_progress() -> Option<crate::stt::file::BatchProgressSnapshot> {
    crate::stt::file::read_batch_progress()
}

// --- AI summary (the only networked feature; opt-in) -----------------------
//
// See `summary.rs` for the full privacy contract. In short: these two
// functions are the ONLY place user content leaves the process, they run
// only when the user presses a button, and the default endpoint is loopback.

/// Generates a Markdown meeting summary for `segments` using `config`.
///
/// Only the rendered transcript text is sent — no audio, no file paths, no
/// device names. Returns a `TranscribeError::Summary` (never a panic, never
/// a partial write) when the endpoint is unreachable or rejects the request,
/// so a failed summary can never look like a lost transcript.
pub async fn generate_summary(
    segments: Vec<Segment>,
    config: crate::summary::SummaryConfig,
) -> Result<String, TranscribeError> {
    let transcript = crate::summary::transcript_text(&segments);
    crate::summary::generate_summary(config, transcript).await
}

/// Lists the models the configured summary endpoint offers, so the settings
/// UI can show a dropdown instead of a free-text field. Sends no transcript.
pub async fn list_summary_models(
    provider: crate::summary::SummaryProvider,
    base_url: String,
    api_key: String,
) -> Result<Vec<String>, TranscribeError> {
    crate::summary::list_summary_models(provider, base_url, api_key).await
}

/// Renders `segments` the way [`generate_summary`] would send them. Exposed
/// so the UI can show the user exactly what would be transmitted before they
/// opt in — no network access.
pub fn summary_preview_transcript(segments: Vec<Segment>) -> String {
    crate::summary::transcript_text(&segments)
}

// --- Settings -----------------------------------------------------

pub fn load_settings() -> AppSettings {
    crate::settings::load_settings()
}

pub fn save_settings(settings: AppSettings) -> Result<(), TranscribeError> {
    crate::settings::save_settings(&settings)
}

// --- Flight recorder -----------------------------------------------------
//
// Privacy-conscious, metadata-only event logger. See `flight_recorder.rs`
// for the full contract. All functions are fire-and-forget: they never
// block, never panic and never crash the host app.

/// Points the recorder at the app-support directory. Call once at startup
/// (right after `RustLib.init()`); creates the directory if missing.
pub fn init_flight_recorder(app_support_dir: String) -> Result<(), TranscribeError> {
    crate::flight_recorder::init(&app_support_dir)?;
    Ok(())
}

pub fn flight_log_lifecycle(session_id: String, from: String, to: String) {
    crate::flight_recorder::log_lifecycle(&session_id, &from, &to);
}

pub fn flight_log_segment_batch(
    session_id: String,
    batch_size: usize,
    total_segments: usize,
    queue_depth: usize,
) {
    crate::flight_recorder::log_segment_batch(&session_id, batch_size, total_segments, queue_depth);
}

pub fn flight_log_error(session_id: String, source: String, message: String) {
    crate::flight_recorder::log_error(&session_id, &source, &message);
}

pub fn flight_log_auto_stop(session_id: String, minutes: u64) {
    crate::flight_recorder::log_auto_stop(&session_id, minutes);
}

pub fn flight_log_system(event: String, details: Option<HashMap<String, String>>) {
    let pairs = details.map(|m| m.into_iter().collect::<Vec<(String, String)>>());
    crate::flight_recorder::log_system(&event, pairs);
}

/// Reads the current flight-recorder contents (raw JSONL) for diagnostics.
pub fn flight_read_log() -> String {
    crate::flight_recorder::read_log()
}

pub fn flight_clear_log() {
    crate::flight_recorder::clear_log();
}

pub fn flight_entry_count() -> usize {
    crate::flight_recorder::entry_count()
}

pub fn flight_set_enabled(enabled: bool) {
    crate::flight_recorder::set_enabled(enabled);
}

// --- Singleton instance lock -----------------------------------------------------

pub fn acquire_instance_lock() -> Result<(), TranscribeError> {
    crate::singleton::acquire_lock()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audio::SessionMode;

    #[test]
    fn version_is_not_empty() {
        assert!(!engine_version().is_empty());
    }

    #[test]
    fn health_check_ok() {
        assert!(health_check().unwrap());
    }

    #[test]
    fn session_lifecycle_through_api() {
        let mut config = SessionConfig::for_mode(SessionMode::Offline, "tiny".into());
        config.mic_enabled = false;
        config.speaker_enabled = false;
        let id = start_session(config).unwrap();
        assert!(get_session_status(id.clone()).is_ok());
        toggle_mic(id.clone(), false).unwrap();
        assert!(!get_session_status(id.clone()).unwrap().mic_enabled);
        stop_session(id).unwrap();
    }

    #[test]
    fn list_models_includes_tiny() {
        let dir = std::env::temp_dir().to_string_lossy().to_string();
        let models = list_available_models(dir);
        assert!(models.iter().any(|m| m.id == "tiny"));
    }

    #[tokio::test]
    async fn download_unknown_model_errors() {
        let dir = std::env::temp_dir().to_string_lossy().to_string();
        let res = download_model(dir, "invalid-model-id".into()).await;
        assert!(res.is_err());
    }

    #[test]
    fn settings_roundtrip_through_api() {
        let s = load_settings();
        assert!(!s.default_model.is_empty());
    }
}
