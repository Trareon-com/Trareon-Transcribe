//! Public API surface exposed to Flutter via flutter_rust_bridge V2.
//!
//! FRB-compatible: no lifetimes in public signatures, every fallible
//! function returns `Result<T, TranscribeError>`. Streams (`vu_meter_stream`,
//! `transcript_stream`, live audio thread wiring) land once FRB codegen is
//! set up against the actual Flutter app.

use std::collections::HashMap;
use std::path::PathBuf;

use crate::audio::{AudioDeviceInfo, SessionConfig, SessionMode};
use crate::doctor::{format_checks, run_checks, Check};
use crate::error::TranscribeError;
use crate::export::{ExportFormat, ExportedFile, Segment};
use crate::model::ModelInfo;
use crate::session::{SessionEvent, SessionRecoverySnapshot, SessionStatus};
use crate::settings::{AppConfig, AppSettings};

pub fn get_app_config() -> AppConfig {
    AppConfig::load().unwrap_or_default()
}

pub fn run_preflight_checks() -> Vec<Check> {
    let settings = crate::settings::load_settings();
    run_checks(&settings)
}

pub fn format_preflight_checks(checks: Vec<Check>) -> String {
    format_checks(&checks)
}

pub fn resume_pending_transcriptions(library_path: String) -> Result<Vec<String>, TranscribeError> {
    let paths = crate::pipeline::LiveWorker::resume_pending_transcriptions(std::path::Path::new(
        &library_path,
    ))?;
    Ok(paths
        .iter()
        .map(|p| p.to_string_lossy().to_string())
        .collect())
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

pub fn list_output_audio_devices() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    crate::audio::device::list_output_devices()
}

pub fn get_loopback_device(name_hint: String) -> Result<AudioDeviceInfo, TranscribeError> {
    crate::audio::get_loopback_device(&name_hint)
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

pub fn set_session_mode(session_id: String, mode: SessionMode) -> Result<(), TranscribeError> {
    crate::session::set_session_mode(&session_id, mode)
}

pub fn get_session_status(session_id: String) -> Result<SessionStatus, TranscribeError> {
    crate::session::get_status(&session_id)
}

pub fn poll_session_events(session_id: String) -> Result<Vec<SessionEvent>, TranscribeError> {
    crate::session::poll_events(&session_id)
}

pub fn list_recoverable_sessions() -> Result<Vec<SessionRecoverySnapshot>, TranscribeError> {
    crate::session::list_recoverable_sessions()
}

pub fn recover_session(snapshot: SessionRecoverySnapshot) -> Result<String, TranscribeError> {
    crate::session::recover_session(snapshot)
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
        if let Err(e) = crate::model::verify_checksum(&dest_path, &info.sha256) {
            // A file that fails checksum is corrupt/partial. Leaving it on disk
            // makes the model read as "installed" and lets a later
            // download_with_resume append onto the bad bytes (poisoned resume),
            // so it can never self-heal. Remove it so the next attempt
            // re-downloads from scratch.
            let _ = std::fs::remove_file(&dest_path);
            return Err(e);
        }
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
    let (mic, speaker) = crate::session::take_raw_audio(&session_id);
    crate::export::export_session_audio(
        mic.as_deref(),
        speaker.as_deref(),
        &PathBuf::from(output_dir),
        &title,
    )
}

/// Sanitize a candidate filename so it is safe to use on all target
/// filesystems (Windows/macOS/Linux). Falls back to "untitled" when the
/// input would otherwise be empty after stripping.
pub fn export_sanitize_filename(raw: String) -> String {
    crate::export::sanitize_filename(&raw)
}

// --- File transcription -----------------------------------------------------

pub fn decode_audio_file(path: String) -> Result<crate::decode::AudioBuffer, TranscribeError> {
    crate::decode::decode_audio_file(std::path::Path::new(&path))
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
) -> Result<ProgressiveFileResult, TranscribeError> {
    let engine = crate::progressive::ProgressiveEngine::load(
        std::path::Path::new(&quick_model_path),
        std::path::Path::new(&refine_model_path),
        false,
        0,
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

pub fn transcribe_files_batch(
    model_path: String,
    files: Vec<String>,
    language: Option<String>,
) -> Result<Vec<crate::stt::file::TranscribeFileResult>, TranscribeError> {
    let engine = crate::stt::WhisperEngine::load(&PathBuf::from(&model_path))?;
    let file_paths: Vec<PathBuf> = files.iter().map(PathBuf::from).collect();
    let mut results = Vec::new();

    crate::stt::file::transcribe_files_batch(
        &engine,
        &file_paths,
        language.as_deref(),
        |progress| {
            if let Some(result) = progress.result {
                results.push(result);
            }
        },
    );

    Ok(results)
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

pub fn is_another_instance_running() -> Result<bool, TranscribeError> {
    crate::singleton::is_another_instance_running()
}

pub fn acquire_instance_lock() -> Result<(), TranscribeError> {
    crate::singleton::acquire_lock()
}

pub fn release_instance_lock() -> Result<(), TranscribeError> {
    crate::singleton::release_lock()
}

#[cfg(test)]
mod tests {
    use super::*;

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
