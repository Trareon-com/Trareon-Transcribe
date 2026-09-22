//! STT engine: whisper-rs binding to whisper.cpp. One inference context per
//! loaded model, guarded by a mutex — whisper.cpp state is not safely
//! shared across concurrent `full()` calls, so callers must serialize
//! through a single inference thread/queue (see api.rs session handling).

use std::path::Path;
use std::sync::{Mutex, OnceLock};

use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

use crate::error::{TranscribeError, TranscribeResult};
use crate::export::Segment;

pub mod file;
pub mod whisper_cd;

/// Returns the best inference backend for the current platform.
///
/// Priority:
///   - macOS Apple Silicon → CoreML (Neural Engine, 4–5× faster than Metal)
///   - macOS Intel         → Metal
///   - Linux with CUDA     → CUDA
///   - Windows with CUDA   → CUDA
///   - Windows without CUDA → DML (DirectML)
///   - Linux              → CPU (with optional OpenMP via whisper-rs openmp feature)
#[cfg(target_os = "macos")]
fn best_backend() -> &'static str {
    if is_apple_silicon() {
        "coreml" // CoreML uses Neural Engine
    } else {
        "metal" // Intel Mac
    }
}

#[cfg(not(target_os = "macos"))]
fn best_backend() -> &'static str {
    #[cfg(feature = "cuda")]
    {
        "cuda"
    }
    #[cfg(all(not(feature = "cuda"), target_os = "windows"))]
    {
        "dml"
    }
    #[cfg(all(not(feature = "cuda"), not(target_os = "windows")))]
    {
        "cpu"
    }
}

/// Cached result of Apple Silicon detection — computed once, reused forever.
static APPLE_SILICON_CACHE: OnceLock<bool> = OnceLock::new();

/// Probe CPU brand/vendor string for known Apple Silicon identifiers.
/// Result is cached after first call using OnceLock.
#[cfg(target_os = "macos")]
fn is_apple_silicon() -> bool {
    *APPLE_SILICON_CACHE.get_or_init(|| {
        use std::process::Command;
        let output = Command::new("sysctl")
            .args(["-n", "machdep.cpu.brand_string"])
            .output()
            .ok();
        output
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .map(|s| {
                s.contains("Apple")
                    || s.contains("M1")
                    || s.contains("M2")
                    || s.contains("M3")
                    || s.contains("M4")
            })
            .unwrap_or(false)
    })
}

/// Detect and return the recommended backend name for diagnostics.
pub fn detect_backend() -> String {
    best_backend().to_string()
}

pub struct WhisperEngine {
    context: Mutex<WhisperContext>,
    model_path: String,
    use_gpu: bool,
}

impl WhisperEngine {
    /// Load a GGML/GGUF model from disk. Returns an error (never panics)
    /// if the file is missing, unreadable, or not a valid whisper model.
    pub fn load(model_path: &Path) -> TranscribeResult<Self> {
        Self::load_with_gpu(model_path, false, 0)
    }

    /// Load a GGML/GGUF model with optional GPU acceleration.
    /// `use_gpu`: enable GPU inference (Metal on macOS, CUDA on Windows/Linux).
    /// `gpu_device`: GPU device index (0 = default).
    pub fn load_with_gpu(
        model_path: &Path,
        use_gpu: bool,
        gpu_device: i32,
    ) -> TranscribeResult<Self> {
        if !model_path.exists() {
            return Err(TranscribeError::Model(format!(
                "model file not found: {}",
                model_path.display()
            )));
        }

        let path_str = model_path
            .to_str()
            .ok_or_else(|| TranscribeError::Model("model path is not valid UTF-8".into()))?;

        let mut params = WhisperContextParameters::new();
        params.use_gpu(use_gpu).gpu_device(gpu_device);

        let context = WhisperContext::new_with_params(path_str, params)
            .map_err(|e| TranscribeError::Model(format!("failed to load model: {e}")))?;

        // Auto-detected backend is resolved once at engine initialization
        // and logged so diagnostics/settings can surface what's actually
        // running (CoreML/Metal on macOS, CUDA/DML/CPU elsewhere).
        tracing::info!(
            backend = detect_backend(),
            gpu = use_gpu,
            device = gpu_device,
            "whisper engine initialized with auto-detected backend"
        );

        Ok(Self {
            context: Mutex::new(context),
            model_path: path_str.to_string(),
            use_gpu,
        })
    }

    pub fn model_path(&self) -> &str {
        &self.model_path
    }

    /// Whether this engine was loaded with GPU acceleration requested
    /// (Metal on macOS, CUDA on Windows/Linux) — surfaced for
    /// diagnostics/settings UI, not read internally after construction.
    pub fn gpu_enabled(&self) -> bool {
        self.use_gpu
    }

    /// Transcribe a chunk of 16kHz mono f32 PCM. `language` is `None` for
    /// auto-detect (per-segment code-switching per PRD), or an ISO-639-1
    /// code to force a language. `initial_prompt` provides context from prior
    /// transcript to improve continuity / reduce code-switch hallucinations.
    pub fn transcribe_chunk(
        &self,
        samples: &[f32],
        source: &str,
        chunk_start_secs: f64,
        language: Option<&str>,
        initial_prompt: Option<&str>,
    ) -> TranscribeResult<Vec<Segment>> {
        if samples.is_empty() {
            return Err(TranscribeError::InvalidInput(
                "cannot transcribe empty audio buffer".into(),
            ));
        }

        // Apply noise reduction preprocessing
        let processed = crate::preprocess::preprocess(samples);

        let ctx = self
            .context
            .lock()
            .map_err(|_| TranscribeError::Transcription("whisper context lock poisoned".into()))?;

        let mut state = ctx
            .create_state()
            .map_err(|e| TranscribeError::Transcription(format!("failed to create state: {e}")))?;

        let mut params = FullParams::new(SamplingStrategy::BeamSearch {
            beam_size: 5,
            patience: 1.0,
        });
        params.set_print_special(false);
        params.set_print_progress(false);
        params.set_print_realtime(false);
        params.set_print_timestamps(false);
        params.set_language(language.or(Some("auto")));
        params.set_audio_ctx(1500);
        if let Some(prompt) = initial_prompt {
            params.set_initial_prompt(prompt);
        }
        // params.token_timestamps(true);  // disabled until FRB regen

        state
            .full(params, &processed)
            .map_err(|e| TranscribeError::Transcription(format!("inference failed: {e}")))?;

        let num_segments = state
            .full_n_segments()
            .map_err(|e| TranscribeError::Transcription(e.to_string()))?;

        let mut out = Vec::with_capacity(num_segments as usize);
        for i in 0..num_segments {
            let text = state
                .full_get_segment_text(i)
                .map_err(|e| TranscribeError::Transcription(e.to_string()))?;
            let t0 = state
                .full_get_segment_t0(i)
                .map_err(|e| TranscribeError::Transcription(e.to_string()))?
                as f64
                / 100.0;
            let t1 = state
                .full_get_segment_t1(i)
                .map_err(|e| TranscribeError::Transcription(e.to_string()))?
                as f64
                / 100.0;

            // Compute average log probability from token data for confidence routing.
            let n_tokens = state.full_n_tokens(i).unwrap_or(0);
            let mut log_probs = Vec::with_capacity(n_tokens as usize);
            for tok in 0..n_tokens {
                if let Ok(token_data) = state.full_get_token_data(i, tok) {
                    log_probs.push(token_data.plog);
                }
            }
            let avg_log_prob = if log_probs.is_empty() {
                0.0_f32
            } else {
                log_probs.iter().sum::<f32>() / log_probs.len() as f32
            };
            // Whisper confidence: convert from log probability (typically -1.0 to 0.0)
            // to a 0..1 scale where 1.0 = high confidence.
            let confidence = (1.0 + avg_log_prob).clamp(0.0, 1.0);
            let low_confidence = confidence < 0.5;

            out.push(Segment {
                source: source.to_string(),
                speaker: source.to_uppercase(),
                text: text.trim().to_string(),
                timestamp: chunk_start_secs + t0,
                duration: (t1 - t0).max(0.0),
                language: segment_language(&text, language).to_string(),
                confidence,
                avg_log_prob,
                is_partial: false,
                low_confidence,
            });
        }

        Ok(out)
    }
}

impl WhisperEngine {
    /// Contrastive decoding transcription — currently a passthrough to
    /// `transcribe_chunk`.
    ///
    /// True contrastive decoding (combining logits from a normal pass and a
    /// shifted-negative pass via `adjusted = positive - alpha * negative`)
    /// requires whisper-rs `full_with_logits` exposure via FRB, which isn't
    /// available yet. Running the shifted-negative pass without consuming
    /// its result would just double inference cost for no benefit, so this
    /// stays a thin wrapper until that API lands.
    pub fn transcribe_chunk_cd(
        &self,
        samples: &[f32],
        source: &str,
        chunk_start_secs: f64,
        language: Option<&str>,
        initial_prompt: Option<&str>,
        alpha_: f32,
    ) -> TranscribeResult<Vec<Segment>> {
        let _ = alpha_; // CD alpha — used when full logits API is wired
        self.transcribe_chunk(samples, source, chunk_start_secs, language, initial_prompt)
    }
}

/// Per-segment language classifier for Indonesian↔English code-switching.
///
/// Heuristics (pure std, O(n) over the word tokens — no external deps):
///   - `language` forced by caller wins outright.
///   - count pure-ASCII-alpha tokens (EN-like) and exact EN
///     stopword hits.
///   - ≥2 EN keywords + >50% Latin → `"en"`
///   - ≥1 EN keyword + >30% Latin (mixed) → `"id-en"` (code-switch)
///   - else → `"id"`
///
/// This runs cheap after inference; it does not re-encode audio.
fn segment_language(text: &str, explicit: Option<&str>) -> &'static str {
    if let Some(l) = explicit {
        match l {
            "en" => return "en",
            "id" => return "id",
            "id-en" => return "id-en",
            _ => {} // "auto"/""/unknown → fall through to heuristics
        }
    }
    const EN_KEYWORDS: &[&str] = &[
        "the", "and", "to", "of", "in", "is", "it", "for", "on", "with", "you", "that", "we",
        "they", "he", "she", "this", "have", "from", "or", "as", "at", "by", "be", "not", "but",
        "an", "were", "our", "us", "so",
    ];
    const ID_KEYWORDS: &[&str] = &[
        "terima", "kasih", "bisa", "gak", "nggak", "kirim", "saya", "kamu", "itu", "halo", "bro",
        "di", "dari", "akan", "sudah", "udah", "ada", "aja", "juga", "ya", "dong", "deh", "tuhan",
        "lho", "tolong", "bukan", "ini", "makasih",
    ];
    let words: Vec<&str> = text
        .split(|c: char| c.is_whitespace() || c.is_ascii_punctuation())
        .filter(|w| !w.is_empty())
        .collect();
    if words.is_empty() {
        return "id";
    }
    let ascii_alpha = words
        .iter()
        .filter(|w| !w.is_empty() && w.chars().all(|c| c.is_ascii_alphabetic()))
        .count();
    let en_hits = words
        .iter()
        .filter(|w| EN_KEYWORDS.contains(&w.to_ascii_lowercase().as_str()))
        .count();
    let id_hits = words
        .iter()
        .filter(|w| ID_KEYWORDS.contains(&w.to_ascii_lowercase().as_str()))
        .count();
    let ratio = ascii_alpha as f32 / words.len() as f32;
    if en_hits >= 2 && ratio > 0.5 {
        "en"
    } else if en_hits >= 1 && id_hits >= 1 {
        // EN keyword + Indonesian keyword in same segment → code-switch
        "id-en"
    } else if en_hits >= 1 && ratio > 0.7 {
        // almost all tokens are Latin, single EN keyword → English
        "en"
    } else {
        "id"
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn load_missing_model_errors_not_panics() {
        let result = WhisperEngine::load(Path::new("/nonexistent/model/tiny.gguf"));
        assert!(result.is_err());
    }

    #[test]
    fn load_invalid_model_file_errors() {
        let path = std::env::temp_dir().join("transcribe_not_a_model.gguf");
        std::fs::write(&path, b"not a real ggml model").unwrap();
        let result = WhisperEngine::load(&path);
        assert!(result.is_err());
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn classify_pure_english() {
        assert_eq!(segment_language("the quick brown fox is here", None), "en");
    }

    #[test]
    fn classify_pure_indonesian() {
        assert_eq!(segment_language("terima kasih banyak ya", None), "id");
        assert_eq!(segment_language("apa kabar?", None), "id");
    }

    #[test]
    fn classify_codeswitch_id_en() {
        assert_eq!(
            segment_language("halo bro, bisa gak kirim the file?", None),
            "id-en"
        );
        assert_eq!(segment_language("saya butuh the link itu", None), "id-en");
    }

    #[test]
    fn explicit_language_wins() {
        // Forced EN overrides Indonesian-looking text.
        assert_eq!(segment_language("terima kasih", Some("en")), "en");
        // "auto" is treated as unset → falls through to heuristics.
        assert_eq!(segment_language("the quick brown fox", Some("auto")), "en");
    }
}
