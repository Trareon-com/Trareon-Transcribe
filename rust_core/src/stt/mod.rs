//! STT engine: whisper-rs binding to whisper.cpp. One inference context per
//! loaded model, guarded by a mutex — whisper.cpp state is not safely
//! shared across concurrent `full()` calls, so callers must serialize
//! through a single inference thread/queue (see api.rs session handling).

use std::path::Path;
use std::sync::Mutex;
#[cfg(target_os = "macos")]
use std::sync::OnceLock;

use whisper_rs::{
    DtwMode, DtwModelPreset, DtwParameters, FullParams, SamplingStrategy, WhisperContext,
    WhisperContextParameters,
};

use crate::error::{TranscribeError, TranscribeResult};
use crate::export::Segment;

pub mod file;
pub mod whisper_cd;
pub mod words;

use words::TokenSpan;

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
#[cfg(target_os = "macos")]
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

/// Decoder settings that decide how hard the engine works at *not*
/// inventing speech, and whether it reports per-word times.
///
/// Every field here is a lever Research Round 2 §2.2 names. They are
/// deliberately a value type rather than engine state: the same loaded
/// engine serves the live preview (which wants `no_context`, because a
/// chunk's prompt is the previous chunk's guesses) and the post-stop pass
/// (which wants context and word timestamps).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DecodeOptions {
    /// Segments whose no-speech probability is at least this are dropped.
    /// Also handed to whisper.cpp as `no_speech_thold`.
    pub no_speech_thold: f32,
    /// Segments whose mean token log-probability is below this are dropped.
    /// Also handed to whisper.cpp as `logprob_thold`.
    pub logprob_thold: f32,
    /// `condition_on_previous_text = false`. On chunked live inference the
    /// previous chunk's text is the model's own output, so conditioning on
    /// it lets one hallucination seed the next.
    pub no_context: bool,
    /// Suppress non-speech tokens (`-sns`): the `[Musik]`/`(applause)`
    /// family, cut off at the decoder rather than filtered out of the text.
    pub suppress_nst: bool,
    /// Ask whisper for per-token timestamps and aggregate them into words.
    pub word_timestamps: bool,
}

impl DecodeOptions {
    /// Settings for the live preview: no context carried between chunks,
    /// and per-token timestamps, which LocalAgreement-2 needs in order to
    /// know *where* each word of a hypothesis sits (see
    /// [`crate::streaming`]).
    ///
    /// Token timestamps are nearly free — the decoder has the numbers
    /// either way. What the live path does not pay for is DTW alignment,
    /// which is an engine-level choice ([`EngineOptions::dtw_alignment`])
    /// costing ~128 MB of context memory; the post-stop pass turns that on
    /// and re-times the words accurately.
    pub const fn live() -> Self {
        Self {
            no_speech_thold: NO_SPEECH_THOLD,
            logprob_thold: LOGPROB_THOLD,
            no_context: true,
            suppress_nst: true,
            word_timestamps: true,
        }
    }

    /// Settings for a file import, a re-transcribe, or the post-stop
    /// completion pass: full context, word timestamps on.
    pub const fn offline() -> Self {
        Self {
            no_speech_thold: NO_SPEECH_THOLD,
            logprob_thold: LOGPROB_THOLD,
            no_context: false,
            suppress_nst: true,
            word_timestamps: true,
        }
    }
}

impl Default for DecodeOptions {
    fn default() -> Self {
        Self::offline()
    }
}

/// No-speech probability at or above which a segment is not speech.
///
/// whisper.cpp's own default is 0.6. Research Round 2 §2.2.7 recommends
/// 0.6 as a *secondary* filter behind VAD gating, which is how it is used
/// here: by the time a segment reaches this check, the VAD already decided
/// the audio under it held speech, so the only segments this drops are the
/// ones the decoder itself is telling us it made up.
pub const NO_SPEECH_THOLD: f32 = 0.6;

/// Mean token log-probability below which a segment is discarded.
///
/// whisper.cpp's CLI default is -1.0. Hallucinated boilerplate is often
/// *high*-probability (§2.2.3), so this catches the other failure: the
/// decoder guessing at noise. Measured on `rapat_id.mp3`, real Indonesian
/// speech segments sit between -0.6 and -0.2, well clear of this.
pub const LOGPROB_THOLD: f32 = -1.0;

/// The DTW alignment-head preset matching a ggml model file.
///
/// whisper.cpp's dynamic-time-warping token timestamps need to know which
/// attention heads of *this* architecture align text to audio; there is no
/// way to read that out of the file, so it is keyed off the name the
/// catalog gives it. An unrecognised name returns `None` and the engine
/// falls back to whisper's heuristic token times, which are good to about
/// ±200 ms (§2.4.4) — enough for click-to-seek, which is what asked for
/// them.
fn dtw_preset_for(model_path: &Path) -> Option<DtwModelPreset> {
    let name = model_path.file_name()?.to_str()?.to_ascii_lowercase();
    // Order matters: "large-v3-turbo" also contains "large-v3".
    for (needle, preset) in [
        ("large-v3-turbo", DtwModelPreset::LargeV3Turbo),
        ("large-v3", DtwModelPreset::LargeV3),
        ("large-v2", DtwModelPreset::LargeV2),
        ("large-v1", DtwModelPreset::LargeV1),
        ("medium.en", DtwModelPreset::MediumEn),
        ("medium", DtwModelPreset::Medium),
        ("small.en", DtwModelPreset::SmallEn),
        ("small", DtwModelPreset::Small),
        ("base.en", DtwModelPreset::BaseEn),
        ("base", DtwModelPreset::Base),
        ("tiny.en", DtwModelPreset::TinyEn),
        ("tiny", DtwModelPreset::Tiny),
    ] {
        if name.contains(needle) {
            return Some(preset);
        }
    }
    None
}

/// How a [`WhisperEngine`] is loaded. Separate from [`DecodeOptions`]
/// because these cannot change without reloading the model.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct EngineOptions {
    pub use_gpu: bool,
    pub gpu_device: i32,
    /// Allocate whisper.cpp's DTW alignment buffers, giving token
    /// timestamps aligned by dynamic time warping instead of the heuristic.
    /// Costs ~128 MB of context memory, so the live path leaves it off.
    pub dtw_alignment: bool,
}

pub struct WhisperEngine {
    context: Mutex<WhisperContext>,
    model_path: String,
    use_gpu: bool,
    /// Whether this context was built with DTW alignment heads. Reported in
    /// the provenance block so a transcript says how its word times were
    /// produced.
    dtw_alignment: bool,
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
        Self::load_with_options(
            model_path,
            EngineOptions {
                use_gpu,
                gpu_device,
                dtw_alignment: false,
            },
        )
    }

    /// [`Self::load_with_gpu`] plus the choice of DTW word alignment.
    pub fn load_with_options(model_path: &Path, options: EngineOptions) -> TranscribeResult<Self> {
        let EngineOptions {
            use_gpu,
            gpu_device,
            dtw_alignment,
        } = options;
        if !model_path.exists() {
            return Err(TranscribeError::Model(format!(
                "model file not found: {}",
                model_path.display()
            )));
        }

        let path_str = model_path
            .to_str()
            .ok_or_else(|| TranscribeError::Model("model path is not valid UTF-8".into()))?;

        // Only claim DTW when the model is one whisper.cpp has alignment
        // heads for. Enabling it with the wrong preset does not produce
        // worse timestamps, it aborts inside whisper.cpp.
        let dtw_preset = dtw_alignment.then(|| dtw_preset_for(model_path)).flatten();
        let dtw_alignment = dtw_preset.is_some();

        let mut params = WhisperContextParameters::new();
        params.use_gpu(use_gpu).gpu_device(gpu_device);
        if let Some(model_preset) = dtw_preset {
            params.dtw_parameters(DtwParameters {
                mode: DtwMode::ModelPreset { model_preset },
                ..DtwParameters::default()
            });
        }

        let context = WhisperContext::new_with_params(path_str, params)
            .map_err(|e| TranscribeError::Model(format!("failed to load model: {e}")))?;

        // Auto-detected backend is resolved once at engine initialization
        // and logged so diagnostics/settings can surface what's actually
        // running (CoreML/Metal on macOS, CUDA/DML/CPU elsewhere).
        tracing::info!(
            backend = detect_backend(),
            gpu = use_gpu,
            device = gpu_device,
            dtw = dtw_alignment,
            "whisper engine initialized with auto-detected backend"
        );

        Ok(Self {
            context: Mutex::new(context),
            model_path: path_str.to_string(),
            use_gpu,
            dtw_alignment,
        })
    }

    pub fn model_path(&self) -> &str {
        &self.model_path
    }

    /// Whether word timestamps from this engine are DTW-aligned (±50 ms)
    /// rather than whisper's heuristic token times (±200 ms).
    pub fn dtw_alignment(&self) -> bool {
        self.dtw_alignment
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
        self.transcribe_chunk_with(
            samples,
            source,
            chunk_start_secs,
            language,
            initial_prompt,
            DecodeOptions::default(),
        )
    }

    /// [`Self::transcribe_chunk`] with explicit decoder settings.
    ///
    /// The hallucination stack lives here rather than in each caller so the
    /// live, import, re-transcribe and post-stop paths cannot drift apart —
    /// which is exactly what had happened: the thresholds were set in none
    /// of them.
    pub fn transcribe_chunk_with(
        &self,
        samples: &[f32],
        source: &str,
        chunk_start_secs: f64,
        language: Option<&str>,
        initial_prompt: Option<&str>,
        options: DecodeOptions,
    ) -> TranscribeResult<Vec<Segment>> {
        if samples.is_empty() {
            return Err(TranscribeError::InvalidInput(
                "cannot transcribe empty audio buffer".into(),
            ));
        }

        // Apply noise reduction preprocessing. RNNoise first when the
        // user asked for it (F17): the suppressor wants the signal as
        // captured, and running it after the normalise would have it
        // estimate noise from a level the normalise chose.
        let processed = if crate::denoise::is_enabled() {
            crate::preprocess::preprocess(&crate::denoise::denoise_16k(samples))
        } else {
            crate::preprocess::preprocess(samples)
        };

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
        // The hallucination stack (Research Round 2 §2.2). VAD gating
        // upstream is the primary defence; these are the decoder-side
        // backstops for whatever audio gets through it.
        params.set_no_speech_thold(options.no_speech_thold);
        params.set_logprob_thold(options.logprob_thold);
        params.set_no_context(options.no_context);
        params.set_suppress_nst(options.suppress_nst);
        params.set_suppress_blank(true);
        if options.word_timestamps {
            params.set_token_timestamps(true);
        }

        state
            .full(params, &processed)
            .map_err(|e| TranscribeError::Transcription(format!("inference failed: {e}")))?;

        let num_segments = state.full_n_segments();

        let mut out = Vec::with_capacity(num_segments as usize);
        for i in 0..num_segments {
            let seg = state
                .get_segment(i)
                .ok_or_else(|| TranscribeError::Transcription(format!("segment {i} not found")))?;
            let text = seg
                .to_str()
                .map_err(|e| TranscribeError::Transcription(e.to_string()))?;
            let t0 = seg.start_timestamp() as f64 / 100.0;
            let t1 = seg.end_timestamp() as f64 / 100.0;

            // One pass over the tokens serves both the segment-level
            // confidence (mean log probability) and, when asked for, the
            // per-word spans.
            let n_tokens = seg.n_tokens();
            let mut log_probs = Vec::with_capacity(n_tokens.max(0) as usize);
            let mut token_spans: Vec<TokenSpan> = if options.word_timestamps {
                Vec::with_capacity(n_tokens.max(0) as usize)
            } else {
                Vec::new()
            };
            for index in 0..n_tokens {
                let Some(token) = seg.get_token(index) else {
                    continue;
                };
                let data = token.token_data();
                log_probs.push(data.plog);
                if !options.word_timestamps {
                    continue;
                }
                // `to_str_lossy` rather than `to_str`: whisper routinely
                // splits a multi-byte character across two tokens, so a
                // single token's bytes are often not valid UTF-8 on their
                // own. A replacement character in one piece is survivable;
                // losing the whole segment's word timings to an `Err` is
                // not.
                let Ok(token_text) = token.to_str_lossy() else {
                    continue;
                };
                token_spans.push(TokenSpan {
                    text: token_text.into_owned(),
                    start: chunk_start_secs + data.t0 as f64 / 100.0,
                    end: chunk_start_secs + data.t1 as f64 / 100.0,
                    prob: data.p.clamp(0.0, 1.0),
                });
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

            // Decoder-side hallucination gate: the model's own verdict on
            // whether there was speech here at all, plus how sure it was of
            // what it wrote. VAD gating upstream means most silence never
            // reaches this point; what this catches is room tone loud
            // enough to pass the detector.
            let no_speech_prob = seg.no_speech_probability();
            if no_speech_prob >= options.no_speech_thold
                || (!log_probs.is_empty() && avg_log_prob < options.logprob_thold)
            {
                tracing::debug!(
                    text = %text.trim(),
                    no_speech_prob,
                    avg_log_prob,
                    "dropped a segment the decoder itself reports as non-speech"
                );
                continue;
            }

            let trimmed = text.trim().to_string();
            let start = chunk_start_secs + t0;
            let duration = (t1 - t0).max(0.0);
            let words = if !options.word_timestamps {
                Vec::new()
            } else {
                let aggregated = words::aggregate_words(&token_spans);
                // A build or model that reports no usable token times at
                // all must still give the player something to seek on.
                if aggregated.is_empty() {
                    words::interpolate_words(&trimmed, start, duration)
                } else {
                    aggregated
                }
            };

            out.push(Segment {
                source: source.to_string(),
                speaker: source.to_uppercase(),
                text: trimmed,
                timestamp: start,
                duration,
                language: segment_language(text, language).to_string(),
                confidence,
                avg_log_prob,
                is_partial: false,
                low_confidence,
                words,
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
pub(crate) fn segment_language(text: &str, explicit: Option<&str>) -> &'static str {
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
    fn the_live_path_carries_no_context_between_chunks() {
        // Research Round 2 §2.2.5: on chunked live inference the previous
        // chunk's text is the model's own output, so conditioning on it
        // lets one hallucination seed the next.
        let live = DecodeOptions::live();
        assert!(
            live.no_context,
            "live inference must not condition on previous text"
        );
        assert!(
            live.word_timestamps,
            "LocalAgreement-2 compares hypotheses word by word"
        );
        assert!(live.suppress_nst);
    }

    #[test]
    fn the_offline_path_keeps_context_and_word_timestamps() {
        let offline = DecodeOptions::offline();
        assert!(!offline.no_context);
        assert!(offline.word_timestamps);
        assert!(offline.suppress_nst);
        // The default must be the accurate one: a caller that does not
        // think about this is an import or a re-transcribe, not the live
        // worker (which names `live()` explicitly).
        assert_eq!(DecodeOptions::default(), offline);
    }

    #[test]
    fn both_paths_share_the_hallucination_thresholds() {
        for options in [DecodeOptions::live(), DecodeOptions::offline()] {
            assert_eq!(options.no_speech_thold, NO_SPEECH_THOLD);
            assert_eq!(options.logprob_thold, LOGPROB_THOLD);
        }
        assert_eq!(NO_SPEECH_THOLD, 0.6);
        assert_eq!(LOGPROB_THOLD, -1.0);
    }

    #[test]
    fn dtw_presets_match_the_catalog_filenames() {
        // Every id in `model::KNOWN_MODELS` must resolve, or word
        // timestamps silently fall back to the heuristic for that model.
        for (filename, expected) in [
            ("ggml-tiny.bin", "Tiny"),
            ("ggml-base.bin", "Base"),
            ("ggml-small.bin", "Small"),
            ("ggml-medium.bin", "Medium"),
            ("ggml-large-v3-turbo.bin", "LargeV3Turbo"),
            ("ggml-large-v3-turbo-q5_0.bin", "LargeV3Turbo"),
        ] {
            let preset = dtw_preset_for(Path::new(filename))
                .unwrap_or_else(|| panic!("{filename} has no DTW preset"));
            assert_eq!(format!("{preset:?}"), expected, "{filename}");
        }
    }

    #[test]
    fn turbo_is_not_mistaken_for_plain_large_v3() {
        // "large-v3-turbo" contains "large-v3"; the wrong preset does not
        // degrade the timestamps, it aborts inside whisper.cpp.
        let preset = dtw_preset_for(Path::new("/x/ggml-large-v3-turbo-q5_0.bin")).unwrap();
        assert_eq!(format!("{preset:?}"), "LargeV3Turbo");
        let plain = dtw_preset_for(Path::new("/x/ggml-large-v3.bin")).unwrap();
        assert_eq!(format!("{plain:?}"), "LargeV3");
    }

    #[test]
    fn an_unknown_model_name_has_no_dtw_preset() {
        // The fallback path: heuristic token timestamps, not a crash.
        assert!(dtw_preset_for(Path::new("ggml-medium-id.bin")).is_some());
        assert!(dtw_preset_for(Path::new("something-else.bin")).is_none());
        assert!(dtw_preset_for(Path::new("/")).is_none());
    }

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
