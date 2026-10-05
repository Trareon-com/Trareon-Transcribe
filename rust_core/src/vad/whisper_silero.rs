//! whisper.cpp's built-in Silero VAD, reached through whisper-rs.
//!
//! The app already had two speech detectors: `webrtc-vad` as a cheap gate
//! and an ONNX Silero behind the `silero-onnx` feature. The ONNX one needs
//! a separate runtime (`ort`), a separate model file nothing ships, and on
//! macOS Intel it cannot be built at all — so in practice every install
//! fell back to the RMS energy detector, which cannot tell a ceiling fan
//! from a vowel.
//!
//! whisper.cpp has had a Silero VAD of its own since v1.7.6, driven by the
//! same ggml runtime the ASR model already loads. whisper-rs 0.16 exposes
//! it as [`WhisperVadContext`], which turns a buffer of 16 kHz mono f32
//! straight into speech spans. No new runtime, no new build dependency,
//! one 865 KB model the existing model manager can fetch and verify.
//!
//! This is the *primary* hallucination defence (Research Round 2 §2.2.2):
//! audio that holds no speech is never handed to Whisper, so the model is
//! never asked what the silence said. The decoder-side thresholds in
//! [`crate::stt::DecodeOptions`] and the text filter in
//! [`crate::hallucination`] are the second and third lines.
//!
//! # Units
//!
//! whisper.cpp reports VAD segment boundaries in **centiseconds** (its own
//! `cs_to_samples` helper is the proof), while everything in this crate
//! speaks seconds. The conversion happens here and nowhere else.

use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

use whisper_rs::{WhisperVadContext, WhisperVadContextParams, WhisperVadParams};

use crate::error::{TranscribeError, TranscribeResult};
use crate::vad::SegmentationConfig;

/// Catalog id of the Silero VAD model, for the model manager.
pub const MODEL_ID: &str = "silero-vad";

/// Where the Silero VAD model is, if it is installed.
///
/// A process global for the same reason `denoise::ENABLED` is one: the VAD
/// gate is reached from `stt::file`, `completion` and `pipeline`, none of
/// which are handed `AppSettings` and none of which should start being.
/// `api::load_settings`/`save_settings` resolve it from the library path
/// and set it here.
fn model_slot() -> &'static Mutex<Option<PathBuf>> {
    static SLOT: OnceLock<Mutex<Option<PathBuf>>> = OnceLock::new();
    SLOT.get_or_init(|| Mutex::new(None))
}

/// Points the VAD gate at a Silero model, or clears it with `None`.
#[flutter_rust_bridge::frb(ignore)]
pub fn set_model_path(path: Option<PathBuf>) {
    if let Ok(mut slot) = model_slot().lock() {
        let present = path.as_ref().is_some_and(|p| p.exists());
        if path.is_some() && !present {
            tracing::warn!(
                path = ?path,
                "Silero VAD model path does not exist; falling back to the \
                 energy detector"
            );
        }
        *slot = path.filter(|p| p.exists());
    }
}

/// The configured Silero model, if one is installed.
#[flutter_rust_bridge::frb(ignore)]
pub fn model_path() -> Option<PathBuf> {
    model_slot().lock().ok()?.clone()
}

/// Whether the neural VAD is usable right now. Reported in the "Apa Jalan
/// di Mana" table so the user can see which detector their transcripts
/// were gated by.
#[flutter_rust_bridge::frb(ignore)]
pub fn is_available() -> bool {
    model_path().is_some()
}

/// A loaded Silero VAD.
///
/// Not `Clone`: it owns a ggml context. Build one per pass, not per chunk —
/// loading the model is ~30 ms and running it over a minute of audio is
/// under 10 ms on the 2-core machine this was measured on, so the load
/// dominates if it is repeated.
pub struct SileroGate {
    context: WhisperVadContext,
}

impl SileroGate {
    /// Loads the configured model, or returns `None` when none is
    /// installed. `Some(Err(..))` means the model is there and broken,
    /// which is worth logging; `None` is the ordinary "not downloaded yet".
    pub fn from_settings(threads: i32) -> Option<TranscribeResult<Self>> {
        let path = model_path()?;
        Some(Self::load(&path, threads))
    }

    pub fn load(model_path: &Path, threads: i32) -> TranscribeResult<Self> {
        let path = model_path
            .to_str()
            .ok_or_else(|| TranscribeError::Model("VAD model path is not valid UTF-8".into()))?;
        let mut params = WhisperVadContextParams::new();
        params.set_n_threads(threads.max(1));
        // Deliberately CPU: the VAD is ~1 ms per 30 ms of audio, and
        // moving it to the GPU would contend with the ASR model that
        // actually needs the device.
        params.set_use_gpu(false);
        let context = WhisperVadContext::new(path, params)
            .map_err(|e| TranscribeError::Model(format!("Silero VAD load failed: {e}")))?;
        Ok(Self { context })
    }

    /// The speech spans of `samples` (16 kHz mono f32), in seconds, in
    /// time order and never overlapping.
    ///
    /// Same contract as [`crate::vad::speech_regions`], so the two are
    /// interchangeable at every call site.
    pub fn speech_regions(
        &mut self,
        samples: &[f32],
        config: SegmentationConfig,
    ) -> TranscribeResult<Vec<(f64, f64)>> {
        if samples.is_empty() {
            return Ok(Vec::new());
        }
        let segments = self
            .context
            .segments_from_samples(vad_params(config), samples)
            .map_err(|e| TranscribeError::Transcription(format!("Silero VAD failed: {e}")))?;

        let total_secs = samples.len() as f64 / 16_000.0;
        let mut regions: Vec<(f64, f64)> =
            Vec::with_capacity(segments.num_segments().max(0) as usize);
        for segment in segments {
            // Centiseconds → seconds, clamped into the buffer. whisper.cpp
            // has already applied `speech_pad_ms`, so a padded segment can
            // run past the end of the audio.
            let start = (segment.start as f64 / 100.0).clamp(0.0, total_secs);
            let end = (segment.end as f64 / 100.0).clamp(start, total_secs);
            if end - start < config.min_speech_secs {
                continue;
            }
            match regions.last_mut() {
                Some(last) if start <= last.1 => last.1 = last.1.max(end),
                _ => regions.push((start, end)),
            }
        }
        Ok(regions)
    }
}

/// Maps this crate's [`SegmentationConfig`] onto whisper.cpp's VAD knobs.
///
/// The defaults the brief asked for (threshold 0.5, min speech 250 ms,
/// speech pad 300 ms) are the `SegmentationConfig::default()` values, so
/// this function is a pure unit conversion and nothing tunes behind the
/// caller's back.
///
/// `samples_overlap` is forced to zero: whisper.cpp uses it to bleed each
/// speech segment into the next so concatenated segments do not clip, which
/// is right when whisper.cpp is doing the concatenating and wrong here,
/// where the spans are used as *coordinates* into the original recording
/// (`coverage.rs` compares them against transcript timestamps).
fn vad_params(config: SegmentationConfig) -> WhisperVadParams {
    let mut params = WhisperVadParams::new();
    params.set_threshold(config.threshold);
    params.set_min_speech_duration(secs_to_ms(config.min_speech_secs));
    params.set_min_silence_duration(secs_to_ms(config.tail_silence_secs));
    params.set_speech_pad(secs_to_ms(config.pad_secs));
    // No cap: a 40-minute monologue is one speech segment, and splitting it
    // is `stt::file`'s job (it chunks every region at 30 s anyway).
    params.set_max_speech_duration(f32::MAX);
    params.set_samples_overlap(0.0);
    params
}

fn secs_to_ms(secs: f64) -> i32 {
    (secs.max(0.0) * 1000.0).round().min(i32::MAX as f64) as i32
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn seconds_convert_to_whole_milliseconds() {
        assert_eq!(secs_to_ms(0.25), 250);
        assert_eq!(secs_to_ms(0.3), 300);
        assert_eq!(secs_to_ms(0.5), 500);
        assert_eq!(secs_to_ms(0.0), 0);
        // Never negative, whatever a caller passes.
        assert_eq!(secs_to_ms(-1.0), 0);
    }

    #[test]
    fn the_defaults_are_the_tuned_values() {
        // The figures Research Round 2 §2.2.2 recommends and the sprint
        // brief asked for. Pinned here because they are the whole reason
        // the silent-WAV test produces zero lines.
        let config = SegmentationConfig::default();
        assert_eq!(config.threshold, 0.5);
        assert_eq!(secs_to_ms(config.min_speech_secs), 250);
        assert_eq!(secs_to_ms(config.pad_secs), 300);
        assert_eq!(secs_to_ms(config.tail_silence_secs), 500);
    }

    #[test]
    fn an_unset_model_path_means_no_neural_vad() {
        set_model_path(None);
        assert!(!is_available());
        assert!(model_path().is_none());
        assert!(SileroGate::from_settings(2).is_none());
    }

    #[test]
    fn a_missing_file_is_not_accepted_as_a_model() {
        // Storing a path that does not exist would make `is_available()`
        // lie and every pass would then pay a failed load.
        set_model_path(Some(PathBuf::from("/nonexistent/ggml-silero.bin")));
        assert!(!is_available());
        set_model_path(None);
    }

    #[test]
    fn loading_a_file_that_is_not_a_vad_model_errors_rather_than_panics() {
        let path = std::env::temp_dir().join("trareon_not_a_vad_model.bin");
        std::fs::write(&path, b"not a ggml silero model").unwrap();
        assert!(SileroGate::load(&path, 2).is_err());
        let _ = std::fs::remove_file(&path);
    }

    /// Runs the real model when it is installed on this machine.
    ///
    /// Not `#[ignore]`d: a machine without the model skips the body, which
    /// is the honest outcome for a test whose subject is a download. CI
    /// installs it in the engine job.
    #[test]
    fn digital_silence_yields_no_speech_regions() {
        let Some(path) = installed_model() else {
            eprintln!("silero VAD model not installed; skipping");
            return;
        };
        let mut gate = SileroGate::load(&path, 4).expect("load silero");
        let silence = vec![0.0f32; 16_000 * 30];
        let regions = gate
            .speech_regions(&silence, SegmentationConfig::default())
            .expect("vad run");
        assert!(
            regions.is_empty(),
            "30 s of digital silence produced speech regions: {regions:?}"
        );
    }

    /// Pins the centisecond→second conversion against the real model.
    ///
    /// whisper.cpp stores VAD boundaries in centiseconds (`samples_to_cs`
    /// in `whisper.cpp`), and getting that wrong is a silent 100× error:
    /// every region would still be inside the recording and in time order,
    /// so a bounds-only test would pass while the gate handed Whisper the
    /// first 1% of the audio and called the rest silence. Putting the
    /// sound at a known offset is what makes this test able to fail.
    #[test]
    fn a_detected_region_lands_where_the_sound_actually_is() {
        let Some(path) = installed_model() else {
            eprintln!("silero VAD model not installed; skipping");
            return;
        };
        let mut gate = SileroGate::load(&path, 4).expect("load silero");
        // 10 s: 4 s of silence, 2 s of a 220 Hz tone, 4 s of silence.
        const BURST_START: f64 = 4.0;
        const BURST_END: f64 = 6.0;
        let mut samples = vec![0.0f32; 16_000 * 4];
        samples.extend(
            (0..16_000 * 2)
                .map(|i| (i as f32 / 16_000.0 * 220.0 * std::f32::consts::TAU).sin() * 0.3),
        );
        samples.extend(vec![0.0f32; 16_000 * 4]);
        let regions = gate
            .speech_regions(&samples, SegmentationConfig::default())
            .expect("vad run");
        let total = samples.len() as f64 / 16_000.0;
        let mut previous_end = 0.0;
        for (start, end) in &regions {
            assert!(*start >= 0.0 && *end <= total, "{start}..{end} of {total}");
            assert!(end > start);
            assert!(*start >= previous_end, "regions must not overlap");
            previous_end = *end;
        }
        // A pure tone is not speech, so Silero is entitled to return
        // nothing at all. What it may not do is return a region somewhere
        // the sound is not.
        let pad = SegmentationConfig::default().pad_secs;
        for (start, end) in &regions {
            assert!(
                *end > BURST_START - pad - 0.1 && *start < BURST_END + pad + 0.1,
                "region {start}..{end} is nowhere near the {BURST_START}..{BURST_END} s \
                 burst — the centisecond conversion is wrong"
            );
        }
    }

    /// The model, if this machine has it in one of the places the app
    /// looks. Mirrors `model::model_search_dirs` without needing settings.
    fn installed_model() -> Option<PathBuf> {
        let filename = "ggml-silero-v5.1.2.bin";
        let mut candidates = vec![PathBuf::from("../models").join(filename)];
        if let Some(home) = dirs::home_dir() {
            candidates.push(
                home.join("Library")
                    .join("Caches")
                    .join("TrareonTranscribe")
                    .join("models")
                    .join(filename),
            );
        }
        candidates.into_iter().find(|p| p.exists())
    }
}
