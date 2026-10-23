//! CrispASR engine — Qwen3-ASR via the CrispASR CLI binary, invoked as a
//! subprocess (2026-10-13).
//!
//! **Why a subprocess, not the FFI binding.** The `crispasr`/`crispasr-sys`
//! Rust crates (v0.8.43) expose a `Session` API that binds the shared
//! library `libcrispasr.so` directly — but on real testing that path
//! segfaults inside the native library's own weight-loading code
//! (`mmap_buffer_get_base`, confirmed via gdb backtrace) for BOTH the
//! 0.6B and 1.7B Qwen3-ASR GGUFs on this machine, so it is not a
//! memory-pressure fluke. The prebuilt CLI binary (statically linked,
//! does not use `libcrispasr.so` at all) transcribes the same files
//! correctly. Until that FFI/shared-lib regression is understood (filed
//! upstream), this engine drives the proven-working CLI instead —
//! slower (process spawn overhead) but it actually works, which the FFI
//! path currently does not.
//!
//! **Maturity caveat (still applies):** CrispASR is a young (~7 month
//! old), effectively solo-maintained project (crates.io `crispasr`, MIT).
//! See `/home/kali/trareon-sprints/BASELINE_FLEURS.md` (2026-10-13
//! sections) for the accuracy/speed numbers that motivated trying it
//! anyway: Qwen3-ASR-1.7B scores WER 5.35 on FLEURS-id vs
//! whisper-large-v3-turbo's 8.13, and Qwen3-ASR-0.6B is the only
//! candidate that stays real-time on CPU alone (RTF 0.60).
//!
//! Whisper remains the non-experimental default; this engine is only
//! ever reached via an explicit tier pick (see `model_select.rs`'s
//! `EngineTier::is_experimental`), never silently substituted in.

use std::path::{Path, PathBuf};
use std::process::Command;

use crate::error::{TranscribeError, TranscribeResult};
use crate::export::Segment;

use super::{DecodeOptions, SttEngine};

/// Drives the `crispasr` CLI binary as a subprocess per call. Resolved
/// paths are checked to exist once, at construction, not re-checked per
/// `transcribe()` call.
pub struct CrispAsrEngine {
    cli_path: PathBuf,
    model_path: PathBuf,
    /// CLI `--backend` value — `"qwen3"` or `"qwen3-1.7b"` (CrispASR's own
    /// `--backend` list has both as distinct values; which one matches a
    /// given GGUF is resolved by `model_select.rs`'s catalog, not guessed
    /// here).
    backend_flag: String,
    /// e.g. `"qwen3-asr-1.7b"` — provenance only, see
    /// `CrispAsrEngine::variant_label`.
    variant_label: String,
}

impl CrispAsrEngine {
    /// `cli_path`: path to the `crispasr` executable (the release
    /// tarball's binary, e.g. `crispasr-linux-x86_64/crispasr`).
    /// `backend_flag`: CLI `--backend` value appropriate for
    /// `model_path`'s variant (see `model_select.rs`).
    pub fn load(
        cli_path: &Path,
        model_path: &Path,
        backend_flag: &str,
        variant_label: &str,
    ) -> TranscribeResult<Self> {
        if !cli_path.is_file() {
            return Err(TranscribeError::Transcription(format!(
                "CrispASR CLI not found at {}",
                cli_path.display()
            )));
        }
        if !model_path.is_file() {
            return Err(TranscribeError::Transcription(format!(
                "CrispASR model not found at {}",
                model_path.display()
            )));
        }
        Ok(Self {
            cli_path: cli_path.to_path_buf(),
            model_path: model_path.to_path_buf(),
            backend_flag: backend_flag.to_string(),
            variant_label: variant_label.to_string(),
        })
    }

    pub fn model_path(&self) -> &Path {
        &self.model_path
    }

    /// Which Qwen3-ASR size this instance was loaded for (e.g.
    /// `"qwen3-asr-1.7b"`), for provenance metadata written alongside a
    /// transcript — so a document can always say exactly which model
    /// produced it, not just "crispasr-qwen3".
    pub fn variant_label(&self) -> &str {
        &self.variant_label
    }
}

/// Minimal shape of `crispasr --output-json-full`'s file — only the
/// fields this engine actually reads; CrispASR's JSON has more (per-token
/// probabilities, build metadata) that we don't need here.
#[derive(serde::Deserialize)]
struct CrispAsrJson {
    transcription: Vec<CrispAsrSegment>,
}

#[derive(serde::Deserialize)]
struct CrispAsrSegment {
    offsets: CrispAsrOffsets,
    text: String,
}

#[derive(serde::Deserialize)]
struct CrispAsrOffsets {
    /// Milliseconds, relative to the start of the audio file passed in
    /// this one subprocess call (chunk-relative, not session-absolute —
    /// `chunk_start_secs` is added on top in `transcribe` below, same
    /// convention `WhisperEngine` uses).
    from: f64,
    to: f64,
}

impl SttEngine for CrispAsrEngine {
    /// `initial_prompt` and the whisper-specific hallucination-threshold
    /// fields of `options` (`no_speech_thold`, `logprob_thold`,
    /// `suppress_nst`) have no CrispASR/Qwen3-ASR equivalent today and
    /// are silently ignored rather than erroring.
    ///
    /// Word-level timestamps are not produced by the Qwen3-ASR backend
    /// (confirmed: `--output-json-full`'s per-token `t0`/`t1` are always
    /// `-1` for this backend), so returned segments carry an empty
    /// `words` list — callers needing word timing should run these
    /// through the same `words::interpolate_words` path whisper segments
    /// without measured words already fall back to.
    fn transcribe(
        &self,
        samples: &[f32],
        source: &str,
        chunk_start_secs: f64,
        language: Option<&str>,
        _initial_prompt: Option<&str>,
        _options: DecodeOptions,
    ) -> TranscribeResult<Vec<Segment>> {
        if samples.is_empty() {
            return Err(TranscribeError::InvalidInput(
                "cannot transcribe empty audio buffer".into(),
            ));
        }

        // Same preprocessing path as WhisperEngine (denoise + normalise)
        // so the two engines see identical input and a tier switch is a
        // fair comparison, not confounded by different preprocessing.
        let processed = if crate::denoise::is_enabled() {
            crate::preprocess::preprocess(&crate::denoise::denoise_16k(samples))
        } else {
            crate::preprocess::preprocess(samples)
        };

        let work_dir =
            std::env::temp_dir().join(format!("trareon_crispasr_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&work_dir).map_err(|e| {
            TranscribeError::Transcription(format!("failed to create scratch dir: {e}"))
        })?;
        // Always clean up the scratch dir, even on an early return below —
        // this guard's Drop runs on every exit path.
        let _cleanup = ScratchGuard(&work_dir);

        let wav_path = work_dir.join("input.wav");
        write_wav_16k_mono(&wav_path, &processed)?;

        let out_stem = work_dir.join("out");
        let mut cmd = Command::new(&self.cli_path);
        cmd.arg("--backend")
            .arg(&self.backend_flag)
            .arg("-m")
            .arg(&self.model_path)
            .arg("-f")
            .arg(&wav_path)
            .arg("-ojf") // --output-json-full
            .arg("-of")
            .arg(&out_stem)
            .arg("-np"); // no-prints: only the JSON file, nothing on stdout we need
        if let Some(lang) = language.filter(|l| *l != "auto") {
            cmd.arg("-l").arg(lang);
        }

        let output = cmd.output().map_err(|e| {
            TranscribeError::Transcription(format!("failed to spawn CrispASR CLI: {e}"))
        })?;
        if !output.status.success() {
            return Err(TranscribeError::Transcription(format!(
                "CrispASR CLI exited with {}: {}",
                output.status,
                String::from_utf8_lossy(&output.stderr)
            )));
        }

        let json_path = work_dir.join("out.json");
        let json_text = std::fs::read_to_string(&json_path).map_err(|e| {
            TranscribeError::Transcription(format!(
                "CrispASR produced no JSON output at {}: {e}",
                json_path.display()
            ))
        })?;
        let parsed: CrispAsrJson = serde_json::from_str(&json_text).map_err(|e| {
            TranscribeError::Transcription(format!("failed to parse CrispASR JSON: {e}"))
        })?;

        Ok(parsed
            .transcription
            .into_iter()
            .map(|seg| Segment {
                source: source.to_string(),
                speaker: String::new(),
                text: seg.text,
                timestamp: chunk_start_secs + seg.offsets.from / 1000.0,
                duration: ((seg.offsets.to - seg.offsets.from) / 1000.0).max(0.0),
                language: language.unwrap_or("auto").to_string(),
                // Qwen3-ASR/CrispASR does not expose a no-speech
                // probability or log-probability comparable to
                // whisper's own hallucination signals; left at neutral
                // defaults rather than faking whisper's scale.
                confidence: 1.0,
                avg_log_prob: 0.0,
                is_partial: false,
                low_confidence: false,
                words: Vec::new(),
            })
            .collect())
    }

    fn engine_id(&self) -> &'static str {
        "crispasr-qwen3"
    }

    fn is_experimental(&self) -> bool {
        true
    }
}

/// Deletes the scratch directory on drop (success or error path alike).
struct ScratchGuard<'a>(&'a Path);

impl Drop for ScratchGuard<'_> {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(self.0);
    }
}

fn write_wav_16k_mono(path: &Path, samples: &[f32]) -> TranscribeResult<()> {
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate: 16_000,
        bits_per_sample: 32,
        sample_format: hound::SampleFormat::Float,
    };
    let mut writer = hound::WavWriter::create(path, spec).map_err(|e| {
        TranscribeError::Transcription(format!("failed to create scratch wav: {e}"))
    })?;
    for &s in samples {
        writer.write_sample(s).map_err(|e| {
            TranscribeError::Transcription(format!("failed to write scratch wav: {e}"))
        })?;
    }
    writer
        .finalize()
        .map_err(|e| TranscribeError::Transcription(format!("failed to finalize scratch wav: {e}")))
}
