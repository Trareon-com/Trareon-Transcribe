//! The one ONNX Runtime environment this process is allowed to have.
//!
//! `ort` 2.0.0-rc.15 replaced the old `ort::init().commit()` (which installed a
//! process-global environment as a side effect) with an explicit
//! `Environment` value that every `Session::builder` must be handed. ONNX
//! Runtime still refuses a second environment per process, so it is built once
//! here and shared — both the Silero VAD and the Indonesian embedding model
//! load through this.

use std::sync::OnceLock;

use ort::environment::Environment;

use crate::error::{TranscribeError, TranscribeResult};

static ENVIRONMENT: OnceLock<Environment> = OnceLock::new();

/// Returns the shared ONNX Runtime environment, creating it on first use.
///
/// Errors instead of panicking: a host without the ONNX Runtime shared library
/// is a "this feature is unavailable" situation the UI is expected to explain,
/// not a crash.
pub fn get() -> TranscribeResult<&'static Environment> {
    if let Some(env) = ENVIRONMENT.get() {
        return Ok(env);
    }

    let built = ort::init()
        .with_name("trareon-transcribe")
        // Microsoft's prebuilt binaries send telemetry by default; this app is
        // local-first and makes no unsolicited network calls.
        .with_telemetry(false)
        .build()
        .map_err(|e| TranscribeError::Model(format!("ONNX Runtime init failed: {e}")))?;

    // Another thread may have won the race; either way the installed
    // environment is the one to use.
    let _ = ENVIRONMENT.set(built);
    ENVIRONMENT
        .get()
        .ok_or_else(|| TranscribeError::Model("ONNX Runtime environment unavailable".into()))
}
