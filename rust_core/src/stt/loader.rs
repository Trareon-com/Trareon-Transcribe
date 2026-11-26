//! Picks the STT engine for a model file.
//!
//! The model a user picks is a file, and the file decides the engine: a
//! whisper.cpp `ggml-*.bin` goes to [`WhisperEngine`], a Qwen3-ASR GGUF
//! (the "Eksperimental" tiers) goes to CrispASR. The live worker already
//! made that choice (`pipeline.rs`'s `LiveWorker::spawn`), but the file
//! paths (import, transcript completion) loaded every model straight into
//! whisper.cpp, so picking "Akurat-Eksperimental" for an import failed with
//! "Failed to create a new whisper context". Every non-live caller goes
//! through [`load_engine`] now, so the two can no longer disagree.

use std::path::Path;
#[cfg(any(feature = "crispasr-experimental", test))]
use std::path::PathBuf;

use super::{SttEngine, WhisperEngine};
use crate::error::{TranscribeError, TranscribeResult};

/// CrispASR `--backend` value for `model_path`, or `None` when the file is
/// not a CrispASR model. Keyed on the filename, the same rule the live
/// worker uses.
fn crispasr_backend_flag(model_path: &Path) -> Option<&'static str> {
    let filename = model_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("");
    crate::model_select::EngineTier::crispasr_backend_flag_for_filename(filename)
}

/// Whether `model_path` is a CrispASR (Qwen3-ASR) model rather than a
/// whisper.cpp one.
pub fn is_crispasr_model(model_path: &Path) -> bool {
    crispasr_backend_flag(model_path).is_some()
}

/// Loads the engine `model_path` needs. `use_gpu`/`gpu_device` only apply
/// to whisper; the CrispASR CLI picks its own backend.
pub fn load_engine(
    model_path: &Path,
    use_gpu: bool,
    gpu_device: i32,
) -> TranscribeResult<Box<dyn SttEngine>> {
    match crispasr_backend_flag(model_path) {
        Some(backend_flag) => load_crispasr(model_path, backend_flag),
        None => Ok(Box::new(WhisperEngine::load_with_gpu(
            model_path, use_gpu, gpu_device,
        )?)),
    }
}

#[cfg(feature = "crispasr-experimental")]
fn load_crispasr(model_path: &Path, backend_flag: &str) -> TranscribeResult<Box<dyn SttEngine>> {
    let cli_path = resolve_crispasr_cli_path(model_path).ok_or_else(|| {
        TranscribeError::Model(format!(
            "CrispASR CLI not found next to {} (set CRISPASR_CLI_PATH or place {} alongside the model)",
            model_path.display(),
            crispasr_cli_name()
        ))
    })?;
    let filename = model_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("");
    // Provenance label: the catalog id ("qwen3-asr-1.7b"), not the filename.
    let variant_label = crate::model::KNOWN_MODELS
        .iter()
        .find(|entry| entry.filename == filename)
        .map(|entry| entry.id)
        .unwrap_or(filename);
    Ok(Box::new(super::CrispAsrEngine::load(
        &cli_path,
        model_path,
        backend_flag,
        variant_label,
    )?))
}

#[cfg(not(feature = "crispasr-experimental"))]
fn load_crispasr(model_path: &Path, _backend_flag: &str) -> TranscribeResult<Box<dyn SttEngine>> {
    Err(TranscribeError::Model(format!(
        "{} is an experimental (CrispASR) model, and this build does not include the \
         crispasr-experimental feature",
        model_path.display()
    )))
}

#[cfg(feature = "crispasr-experimental")]
fn crispasr_cli_name() -> &'static str {
    if cfg!(windows) {
        "crispasr.exe"
    } else {
        "crispasr"
    }
}

/// Where to find the `crispasr` CLI binary for an installed model, in order:
///
/// 1. `CRISPASR_CLI_PATH`, for development and for testing another build.
/// 2. The copy shipped inside the app: `Contents/Helpers/crispasr/` on
///    macOS (put there by `macos/scripts/bundle_crispasr.sh`), or a
///    `crispasr/` folder beside the executable elsewhere. Downloading a
///    model only fetches the GGUF, so without this a fresh install could
///    never run the Eksperimental tiers.
/// 3. A binary sitting next to the model file, the convention the manual
///    cross-platform validation used before the CLI was bundled.
#[cfg(feature = "crispasr-experimental")]
pub fn resolve_crispasr_cli_path(model_path: &Path) -> Option<PathBuf> {
    if let Ok(from_env) = std::env::var("CRISPASR_CLI_PATH") {
        let candidate = PathBuf::from(from_env);
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    let exe_dir = std::env::current_exe()
        .ok()
        .and_then(|exe| exe.parent().map(Path::to_path_buf));
    let model_dir = model_path.parent().map(Path::to_path_buf);
    cli_candidates(exe_dir.as_deref(), model_dir.as_deref())
        .into_iter()
        .find(|candidate| candidate.is_file())
}

/// The bundled and beside-the-model locations, in search order. Split out
/// so the order is testable without a real app bundle.
#[cfg(feature = "crispasr-experimental")]
fn cli_candidates(exe_dir: Option<&Path>, model_dir: Option<&Path>) -> Vec<PathBuf> {
    let name = crispasr_cli_name();
    let mut candidates = Vec::new();
    if let Some(exe_dir) = exe_dir {
        // macOS: exe is Contents/MacOS/<app>, helpers live in Contents/Helpers.
        candidates.push(exe_dir.join("../Helpers/crispasr").join(name));
        candidates.push(exe_dir.join("crispasr").join(name));
    }
    if let Some(model_dir) = model_dir {
        candidates.push(model_dir.join(name));
    }
    candidates
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scratch_dir(tag: &str) -> PathBuf {
        let dir =
            std::env::temp_dir().join(format!("trareon_loader_{tag}_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn qwen3_gguf_files_are_crispasr_models() {
        assert!(is_crispasr_model(Path::new("/m/qwen3-asr-1.7b-q4_k.gguf")));
        assert!(is_crispasr_model(Path::new("/m/qwen3-asr-0.6b-q4_k.gguf")));
        assert!(!is_crispasr_model(Path::new(
            "/m/ggml-large-v3-turbo-q5_0.bin"
        )));
        assert!(!is_crispasr_model(Path::new("/m/ggml-base.bin")));
    }

    /// The bug this module fixes: a Qwen3 GGUF handed to the file path was
    /// loaded into whisper.cpp. Whatever the build, it must now never reach
    /// whisper, so the error can never be whisper's "failed to create a
    /// new whisper context".
    #[test]
    fn a_crispasr_model_never_reaches_whisper() {
        let dir = scratch_dir("no_cli");
        let model = dir.join("qwen3-asr-1.7b-q4_k.gguf");
        std::fs::write(&model, b"not a real model").unwrap();

        let error = load_engine(&model, false, 0)
            .err()
            .expect("no CLI next to the model");
        let message = error.to_string();
        assert!(
            !message.contains("whisper context"),
            "went to whisper: {message}"
        );
        assert!(
            message.contains("CrispASR") || message.contains("crispasr"),
            "{message}"
        );

        std::fs::remove_dir_all(&dir).ok();
    }

    #[cfg(feature = "crispasr-experimental")]
    #[test]
    fn the_bundled_cli_wins_over_one_beside_the_model() {
        let exe_dir = Path::new("/Apps/T.app/Contents/MacOS");
        let model_dir = Path::new("/lib");
        let candidates = cli_candidates(Some(exe_dir), Some(model_dir));
        assert_eq!(
            candidates.first().unwrap(),
            &exe_dir
                .join("../Helpers/crispasr")
                .join(crispasr_cli_name())
        );
        assert_eq!(
            candidates.last().unwrap(),
            &model_dir.join(crispasr_cli_name())
        );
    }

    #[cfg(feature = "crispasr-experimental")]
    #[test]
    fn a_crispasr_model_with_its_cli_loads_the_crispasr_engine() {
        let dir = scratch_dir("with_cli");
        let model = dir.join("qwen3-asr-1.7b-q4_k.gguf");
        std::fs::write(&model, b"not a real model").unwrap();
        std::fs::write(dir.join(crispasr_cli_name()), b"").unwrap();

        let engine = load_engine(&model, false, 0).expect("CLI sits next to the model");
        assert_eq!(engine.engine_id(), "crispasr-qwen3");
        assert!(engine.is_experimental());

        std::fs::remove_dir_all(&dir).ok();
    }
}
