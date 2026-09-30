//! AI meeting summaries — the **only** networked feature in the app.
//!
//! # Privacy contract
//!
//! Everything else in Trareon Transcribe is offline: capture, VAD, Whisper
//! inference, diarization, export. This module is the single deliberate
//! exception and it is opt-in per request:
//!
//! * No function here runs unless the user presses "Buat Ringkasan".
//! * Nothing in the transcription hot path (`stt/`, `pipeline.rs`,
//!   `session.rs`, `audio/`, `decode/`, `preprocess.rs`, `diarization.rs`)
//!   may reference this module — enforced by `privacy::tests`.
//! * The endpoint is whatever the user configured. The default,
//!   [`DEFAULT_OLLAMA_BASE_URL`], is a loopback address, so the default
//!   configuration still never leaves the machine.
//! * Only the transcript text is sent — never audio, never file paths,
//!   never device names.
//!
//! # Providers
//!
//! * [`SummaryProvider::Ollama`] — `POST {base}/api/chat`, no auth.
//! * [`SummaryProvider::OpenAiCompatible`] — `POST {base}/chat/completions`
//!   with `Authorization: Bearer <key>`. Works with OpenAI itself, LM Studio,
//!   llama.cpp's server, vLLM, OpenRouter, Groq, …
//!
//! Prompt construction, URL derivation and response parsing are pure
//! functions so the whole shape of the feature is unit-testable with no
//! network access at all; only [`generate_summary`] and
//! [`list_summary_models`] actually open a socket.

use serde::{Deserialize, Serialize};

use crate::error::TranscribeError;
use crate::export::Segment;

/// Ollama's default loopback endpoint. Chosen as the default so the
/// out-of-the-box summary configuration is still fully local.
pub const DEFAULT_OLLAMA_BASE_URL: &str = "http://localhost:11434";

/// Upper bound on transcript characters sent to the model. Long meetings
/// otherwise overflow a small context window and the endpoint either errors
/// or silently truncates the *end* — losing exactly the decisions and action
/// items a summary is wanted for. [`truncate_transcript`] keeps both ends.
pub const MAX_TRANSCRIPT_CHARS: usize = 24_000;

pub const DEFAULT_TIMEOUT_SECS: u64 = 180;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SummaryProvider {
    Ollama,
    OpenAiCompatible,
}

/// Indonesian meeting-summary templates. `Kustom` uses
/// [`SummaryConfig::custom_prompt`] verbatim as the instruction.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SummaryTemplate {
    /// Full minutes: agenda, discussion, decisions, follow-ups.
    NotulenRapat,
    /// Short prose brief for someone who wasn't there.
    RingkasanEksekutif,
    /// Decisions and action items only, with owners.
    ActionItems,
    /// Daily-standup shape: done / next / blockers, per person.
    Standup,
    Kustom,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SummaryConfig {
    pub provider: SummaryProvider,
    /// e.g. `http://localhost:11434` or `https://api.openai.com/v1`.
    pub base_url: String,
    /// Bearer token for OpenAI-compatible endpoints. Empty for Ollama.
    pub api_key: String,
    /// e.g. `qwen2.5:7b`, `gpt-4o-mini`.
    pub model: String,
    pub template: SummaryTemplate,
    /// Instruction used when `template == Kustom`.
    pub custom_prompt: String,
    /// Output language: `"id"` or `"en"`.
    pub language: String,
    pub timeout_secs: u64,
}

impl Default for SummaryConfig {
    fn default() -> Self {
        Self {
            provider: SummaryProvider::Ollama,
            base_url: DEFAULT_OLLAMA_BASE_URL.to_string(),
            api_key: String::new(),
            model: String::new(),
            template: SummaryTemplate::NotulenRapat,
            custom_prompt: String::new(),
            language: "id".to_string(),
            timeout_secs: DEFAULT_TIMEOUT_SECS,
        }
    }
}

// ---------------------------------------------------------------------------
// Pure: transcript rendering
// ---------------------------------------------------------------------------

/// Renders segments as `[mm:ss] Speaker: text`, one per line.
///
/// Partial (HPT quick-pass) segments are skipped: they are superseded by the
/// refined pass and summarising both would double-count every utterance.
#[flutter_rust_bridge::frb(ignore)]
pub fn transcript_text(segments: &[Segment]) -> String {
    segments
        .iter()
        .filter(|s| !s.is_partial && !s.text.trim().is_empty())
        .map(|s| {
            let total = s.timestamp.max(0.0) as u64;
            format!(
                "[{:02}:{:02}] {}: {}",
                total / 60,
                total % 60,
                s.speaker.trim(),
                s.text.trim()
            )
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// Caps `text` at `max_chars`, keeping the first 60% and the last 40% with an
/// elision marker in between — the opening sets context, the close carries the
/// decisions.
#[flutter_rust_bridge::frb(ignore)]
pub fn truncate_transcript(text: &str, max_chars: usize) -> String {
    let chars: Vec<char> = text.chars().collect();
    if chars.len() <= max_chars || max_chars == 0 {
        return text.to_string();
    }
    let head = max_chars * 6 / 10;
    let tail = max_chars - head;
    let head_text: String = chars[..head].iter().collect();
    let tail_text: String = chars[chars.len() - tail..].iter().collect();
    format!("{head_text}\n\n[... bagian tengah transkrip dipotong ...]\n\n{tail_text}")
}

// ---------------------------------------------------------------------------
// Pure: prompt construction
// ---------------------------------------------------------------------------

/// The task instruction for `template`, in Indonesian.
#[flutter_rust_bridge::frb(ignore)]
pub fn template_instruction(template: SummaryTemplate, custom_prompt: &str) -> String {
    match template {
        SummaryTemplate::NotulenRapat => "Tulis NOTULEN RAPAT lengkap dengan struktur berikut:\n\
             ## Ringkasan\n(2-3 kalimat inti rapat)\n\
             ## Peserta\n(daftar pembicara yang muncul di transkrip)\n\
             ## Pembahasan\n(poin-poin utama, dikelompokkan per topik)\n\
             ## Keputusan\n(setiap keputusan yang diambil)\n\
             ## Tindak Lanjut\n(tabel: Tugas | Penanggung Jawab | Tenggat)"
            .to_string(),
        SummaryTemplate::RingkasanEksekutif => {
            "Tulis RINGKASAN EKSEKUTIF singkat (maksimal 200 kata) untuk seseorang yang \
             tidak hadir. Fokus pada: apa yang dibahas, apa yang diputuskan, dan apa \
             dampaknya. Gunakan paragraf mengalir, bukan daftar."
                .to_string()
        }
        SummaryTemplate::ActionItems => {
            "Ekstrak hanya KEPUTUSAN dan ACTION ITEMS dengan struktur:\n\
             ## Keputusan\n(daftar bernomor; sertakan alasan bila disebutkan)\n\
             ## Action Items\n(tabel: Tugas | Penanggung Jawab | Tenggat)\n\
             Jika penanggung jawab atau tenggat tidak disebutkan, tulis \"-\"."
                .to_string()
        }
        SummaryTemplate::Standup => "Tulis ringkasan STANDUP per orang dengan struktur:\n\
             ### <Nama>\n- Selesai: ...\n- Berikutnya: ...\n- Hambatan: ...\n\
             Jika sebuah bagian tidak disebutkan orang tersebut, tulis \"-\"."
            .to_string(),
        SummaryTemplate::Kustom => {
            let trimmed = custom_prompt.trim();
            if trimmed.is_empty() {
                "Ringkas transkrip rapat berikut dalam poin-poin singkat.".to_string()
            } else {
                trimmed.to_string()
            }
        }
    }
}

/// System message: role, output language, and the anti-hallucination rules.
#[flutter_rust_bridge::frb(ignore)]
pub fn system_prompt(language: &str) -> String {
    let output_language = if language.eq_ignore_ascii_case("en") {
        "English"
    } else {
        "Bahasa Indonesia"
    };
    format!(
        "Anda adalah notulis rapat profesional. Anda menerima transkrip hasil \
         speech-to-text yang mungkin mengandung salah dengar.\n\
         Aturan wajib:\n\
         - Tulis jawaban dalam {output_language}.\n\
         - Gunakan HANYA informasi yang ada di transkrip. Jangan mengarang \
           nama, angka, tanggal, atau keputusan.\n\
         - Jika sebuah bagian tidak ada di transkrip, tulis \"Tidak disebutkan\".\n\
         - Pertahankan nama orang, istilah teknis, dan angka persis seperti di transkrip.\n\
         - Keluarkan Markdown murni tanpa kalimat pembuka atau penutup."
    )
}

/// The user message: instruction + transcript, truncated to
/// [`MAX_TRANSCRIPT_CHARS`].
#[flutter_rust_bridge::frb(ignore)]
pub fn build_prompt(config: &SummaryConfig, transcript: &str) -> String {
    let instruction = template_instruction(config.template, &config.custom_prompt);
    let body = truncate_transcript(transcript.trim(), MAX_TRANSCRIPT_CHARS);
    format!("{instruction}\n\n--- TRANSKRIP ---\n{body}\n--- AKHIR TRANSKRIP ---")
}

// ---------------------------------------------------------------------------
// Pure: endpoint URLs
// ---------------------------------------------------------------------------

fn trim_base(base_url: &str) -> &str {
    base_url.trim().trim_end_matches('/')
}

/// Chat-completion URL for `provider` under `base_url`.
///
/// Tolerates a base that already carries the full path (users paste
/// `https://host/v1/chat/completions` from provider docs constantly), so the
/// path is never doubled.
#[flutter_rust_bridge::frb(ignore)]
pub fn chat_endpoint(provider: SummaryProvider, base_url: &str) -> String {
    let base = trim_base(base_url);
    match provider {
        SummaryProvider::Ollama => {
            if base.ends_with("/api/chat") {
                base.to_string()
            } else {
                format!("{base}/api/chat")
            }
        }
        SummaryProvider::OpenAiCompatible => {
            if base.ends_with("/chat/completions") {
                base.to_string()
            } else {
                format!("{base}/chat/completions")
            }
        }
    }
}

/// Model-listing URL for `provider` under `base_url`.
#[flutter_rust_bridge::frb(ignore)]
pub fn models_endpoint(provider: SummaryProvider, base_url: &str) -> String {
    let base = trim_base(base_url);
    match provider {
        SummaryProvider::Ollama => format!("{base}/api/tags"),
        SummaryProvider::OpenAiCompatible => format!("{base}/models"),
    }
}

// ---------------------------------------------------------------------------
// Pure: response parsing
// ---------------------------------------------------------------------------

/// Extracts the assistant message from either provider's response shape.
///
/// Ollama replies `{"message":{"content":...}}`; OpenAI-compatible endpoints
/// reply `{"choices":[{"message":{"content":...}}]}`. Both are accepted
/// regardless of the configured provider, because "OpenAI-compatible" servers
/// vary and a working response should not be rejected on a technicality.
#[flutter_rust_bridge::frb(ignore)]
pub fn parse_chat_response(body: &str) -> Result<String, TranscribeError> {
    let json: serde_json::Value = serde_json::from_str(body).map_err(|e| {
        TranscribeError::Summary(format!(
            "jawaban endpoint bukan JSON yang valid: {e} — {}",
            snippet(body)
        ))
    })?;

    if let Some(error) = json.get("error") {
        let message = error
            .get("message")
            .and_then(|m| m.as_str())
            .unwrap_or_else(|| error.as_str().unwrap_or("unknown"));
        return Err(TranscribeError::Summary(format!(
            "endpoint menolak permintaan: {message}"
        )));
    }

    let content = json
        .pointer("/message/content")
        .or_else(|| json.pointer("/choices/0/message/content"))
        .or_else(|| json.pointer("/choices/0/text"))
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty());

    content.map(str::to_string).ok_or_else(|| {
        TranscribeError::Summary(format!(
            "jawaban endpoint tidak berisi teks ringkasan — {}",
            snippet(body)
        ))
    })
}

/// Extracts model ids from either `/api/tags` (Ollama) or `/models` (OpenAI).
#[flutter_rust_bridge::frb(ignore)]
pub fn parse_models_response(body: &str) -> Result<Vec<String>, TranscribeError> {
    let json: serde_json::Value = serde_json::from_str(body).map_err(|e| {
        TranscribeError::Summary(format!(
            "daftar model bukan JSON yang valid: {e} — {}",
            snippet(body)
        ))
    })?;

    let entries = json
        .get("models")
        .or_else(|| json.get("data"))
        .and_then(|v| v.as_array())
        .ok_or_else(|| {
            TranscribeError::Summary(format!("daftar model tidak dikenali — {}", snippet(body)))
        })?;

    let mut names: Vec<String> = entries
        .iter()
        .filter_map(|entry| {
            entry
                .get("name")
                .or_else(|| entry.get("id"))
                .or_else(|| entry.get("model"))
                .and_then(|v| v.as_str())
                .map(str::to_string)
        })
        .collect();
    names.sort();
    names.dedup();
    Ok(names)
}

/// First 200 characters of a response, for error messages. Bounded so a
/// multi-megabyte HTML error page can't end up in a toast.
fn snippet(body: &str) -> String {
    let trimmed = body.trim();
    if trimmed.is_empty() {
        return "(jawaban kosong)".to_string();
    }
    let short: String = trimmed.chars().take(200).collect();
    if trimmed.chars().count() > 200 {
        format!("{short}…")
    } else {
        short
    }
}

// ---------------------------------------------------------------------------
// Networked entry points
// ---------------------------------------------------------------------------

fn client(timeout_secs: u64) -> Result<reqwest::Client, TranscribeError> {
    reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(timeout_secs.clamp(5, 900)))
        .build()
        .map_err(|e| TranscribeError::Summary(format!("gagal membuat HTTP client: {e}")))
}

fn request_body(config: &SummaryConfig, prompt: &str) -> serde_json::Value {
    let messages = serde_json::json!([
        { "role": "system", "content": system_prompt(&config.language) },
        { "role": "user", "content": prompt },
    ]);
    match config.provider {
        SummaryProvider::Ollama => serde_json::json!({
            "model": config.model,
            "messages": messages,
            "stream": false,
            "options": { "temperature": 0.2 },
        }),
        SummaryProvider::OpenAiCompatible => serde_json::json!({
            "model": config.model,
            "messages": messages,
            "stream": false,
            "temperature": 0.2,
        }),
    }
}

fn validate(config: &SummaryConfig) -> Result<(), TranscribeError> {
    if trim_base(&config.base_url).is_empty() {
        return Err(TranscribeError::Summary(
            "URL endpoint ringkasan belum diisi.".into(),
        ));
    }
    if config.model.trim().is_empty() {
        return Err(TranscribeError::Summary(
            "Model ringkasan belum dipilih.".into(),
        ));
    }
    Ok(())
}

/// Sends `transcript` to the configured endpoint and returns Markdown.
///
/// This is the only place in the crate that performs an outbound request
/// with user content, and it runs exactly once per explicit user action.
pub async fn generate_summary(
    config: SummaryConfig,
    transcript: String,
) -> Result<String, TranscribeError> {
    validate(&config)?;
    if transcript.trim().is_empty() {
        return Err(TranscribeError::Summary(
            "Transkrip kosong — tidak ada yang bisa diringkas.".into(),
        ));
    }

    let url = chat_endpoint(config.provider, &config.base_url);
    let prompt = build_prompt(&config, &transcript);

    let mut request = client(config.timeout_secs)?
        .post(&url)
        .json(&request_body(&config, &prompt));
    if !config.api_key.trim().is_empty() {
        request = request.bearer_auth(config.api_key.trim());
    }

    let response = request.send().await.map_err(|e| {
        TranscribeError::Summary(format!(
            "tidak bisa menghubungi {url}: {e}. Pastikan layanan berjalan dan URL benar."
        ))
    })?;

    let status = response.status();
    let body = response
        .text()
        .await
        .map_err(|e| TranscribeError::Summary(format!("gagal membaca jawaban {url}: {e}")))?;

    if !status.is_success() {
        // Some servers put a useful message in a JSON error body even on 4xx,
        // so try the structured path first and fall back to the raw snippet.
        return Err(match parse_chat_response(&body) {
            Err(TranscribeError::Summary(msg)) if msg.starts_with("endpoint menolak") => {
                TranscribeError::Summary(format!("HTTP {}: {msg}", status.as_u16()))
            }
            _ => TranscribeError::Summary(format!(
                "HTTP {} dari {url} — {}",
                status.as_u16(),
                snippet(&body)
            )),
        });
    }

    parse_chat_response(&body)
}

/// Lists the models the configured endpoint offers, so the UI can present a
/// dropdown instead of a free-text field. Sends no transcript content.
pub async fn list_summary_models(
    provider: SummaryProvider,
    base_url: String,
    api_key: String,
) -> Result<Vec<String>, TranscribeError> {
    if trim_base(&base_url).is_empty() {
        return Err(TranscribeError::Summary(
            "URL endpoint ringkasan belum diisi.".into(),
        ));
    }
    let url = models_endpoint(provider, &base_url);
    let mut request = client(30)?.get(&url);
    if !api_key.trim().is_empty() {
        request = request.bearer_auth(api_key.trim());
    }

    let response = request.send().await.map_err(|e| {
        TranscribeError::Summary(format!(
            "tidak bisa menghubungi {url}: {e}. Pastikan layanan berjalan dan URL benar."
        ))
    })?;
    let status = response.status();
    let body = response
        .text()
        .await
        .map_err(|e| TranscribeError::Summary(format!("gagal membaca jawaban {url}: {e}")))?;
    if !status.is_success() {
        return Err(TranscribeError::Summary(format!(
            "HTTP {} dari {url} — {}",
            status.as_u16(),
            snippet(&body)
        )));
    }
    parse_models_response(&body)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(speaker: &str, text: &str, ts: f64, partial: bool) -> Segment {
        Segment {
            source: "mic".into(),
            speaker: speaker.into(),
            text: text.into(),
            timestamp: ts,
            duration: 2.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: partial,
            low_confidence: false,
        }
    }

    // --- transcript rendering -------------------------------------------

    #[test]
    fn transcript_text_formats_timestamps_and_speakers() {
        let segments = vec![
            seg("Saya", "selamat pagi", 5.0, false),
            seg("Peserta 1", "pagi juga", 65.0, false),
        ];
        assert_eq!(
            transcript_text(&segments),
            "[00:05] Saya: selamat pagi\n[01:05] Peserta 1: pagi juga"
        );
    }

    #[test]
    fn transcript_text_skips_partials_and_blanks() {
        let segments = vec![
            seg("Saya", "teks cepat", 0.0, true),
            seg("Saya", "teks akurat", 0.0, false),
            seg("Saya", "   ", 10.0, false),
        ];
        assert_eq!(transcript_text(&segments), "[00:00] Saya: teks akurat");
    }

    #[test]
    fn truncate_keeps_both_ends() {
        let text: String = std::iter::repeat_n('a', 500)
            .chain(std::iter::repeat_n('z', 500))
            .collect();
        let out = truncate_transcript(&text, 100);
        assert!(out.starts_with('a'), "opening context must survive");
        assert!(out.ends_with('z'), "closing decisions must survive");
        assert!(out.contains("dipotong"));
    }

    #[test]
    fn truncate_is_a_noop_below_the_limit() {
        assert_eq!(truncate_transcript("halo", 100), "halo");
        assert_eq!(truncate_transcript("halo", 0), "halo");
    }

    // --- prompts ---------------------------------------------------------

    #[test]
    fn every_template_produces_a_distinct_non_empty_instruction() {
        let templates = [
            SummaryTemplate::NotulenRapat,
            SummaryTemplate::RingkasanEksekutif,
            SummaryTemplate::ActionItems,
            SummaryTemplate::Standup,
        ];
        let mut seen: Vec<String> = Vec::new();
        for t in templates {
            let instruction = template_instruction(t, "");
            assert!(!instruction.trim().is_empty(), "{t:?} has no instruction");
            assert!(
                !seen.contains(&instruction),
                "{t:?} duplicates another template"
            );
            seen.push(instruction);
        }
    }

    #[test]
    fn custom_template_uses_the_user_prompt_and_falls_back_when_blank() {
        assert_eq!(
            template_instruction(SummaryTemplate::Kustom, "  Buat daftar risiko.  "),
            "Buat daftar risiko."
        );
        assert!(template_instruction(SummaryTemplate::Kustom, "   ").contains("Ringkas"));
    }

    #[test]
    fn prompt_embeds_instruction_and_transcript() {
        let config = SummaryConfig {
            template: SummaryTemplate::ActionItems,
            ..Default::default()
        };
        let prompt = build_prompt(&config, "[00:00] Saya: kita putuskan pakai Rust");
        assert!(prompt.contains("Action Items"));
        assert!(prompt.contains("kita putuskan pakai Rust"));
        assert!(prompt.contains("--- AKHIR TRANSKRIP ---"));
    }

    #[test]
    fn system_prompt_switches_output_language() {
        assert!(system_prompt("id").contains("Bahasa Indonesia"));
        assert!(system_prompt("en").contains("English"));
        assert!(system_prompt("EN").contains("English"));
        // The anti-hallucination rule is non-negotiable in both languages.
        assert!(system_prompt("id").contains("Jangan mengarang"));
        assert!(system_prompt("en").contains("Jangan mengarang"));
    }

    // --- endpoints -------------------------------------------------------

    #[test]
    fn ollama_endpoints() {
        assert_eq!(
            chat_endpoint(SummaryProvider::Ollama, "http://localhost:11434"),
            "http://localhost:11434/api/chat"
        );
        assert_eq!(
            chat_endpoint(SummaryProvider::Ollama, "http://localhost:11434/"),
            "http://localhost:11434/api/chat"
        );
        assert_eq!(
            models_endpoint(SummaryProvider::Ollama, "http://localhost:11434"),
            "http://localhost:11434/api/tags"
        );
    }

    #[test]
    fn openai_endpoints() {
        assert_eq!(
            chat_endpoint(
                SummaryProvider::OpenAiCompatible,
                "https://api.openai.com/v1"
            ),
            "https://api.openai.com/v1/chat/completions"
        );
        assert_eq!(
            models_endpoint(
                SummaryProvider::OpenAiCompatible,
                "https://api.openai.com/v1/"
            ),
            "https://api.openai.com/v1/models"
        );
    }

    #[test]
    fn endpoint_path_is_never_doubled() {
        // Users paste the full URL out of provider docs; doubling the path
        // yields a 404 that looks like "the endpoint is down".
        assert_eq!(
            chat_endpoint(
                SummaryProvider::OpenAiCompatible,
                "https://api.openai.com/v1/chat/completions"
            ),
            "https://api.openai.com/v1/chat/completions"
        );
        assert_eq!(
            chat_endpoint(SummaryProvider::Ollama, "http://localhost:11434/api/chat"),
            "http://localhost:11434/api/chat"
        );
    }

    // --- response parsing ------------------------------------------------

    #[test]
    fn parses_ollama_shape() {
        // Escaped rather than raw: the payload contains `"##`, which would
        // terminate an `r#"…"#` / `r##"…"##` literal mid-string.
        let body = "{\"model\":\"qwen2.5:7b\",\"message\":{\"role\":\"assistant\",\
                    \"content\":\"## Ringkasan\\nHalo\"},\"done\":true}";
        assert_eq!(parse_chat_response(body).unwrap(), "## Ringkasan\nHalo");
    }

    #[test]
    fn parses_openai_shape() {
        let body = r##"{"choices":[{"index":0,"message":{"role":"assistant","content":" ## Notulen "}}]}"##;
        assert_eq!(parse_chat_response(body).unwrap(), "## Notulen");
    }

    #[test]
    fn surfaces_structured_endpoint_errors() {
        let body =
            r#"{"error":{"message":"model 'nope' not found","type":"invalid_request_error"}}"#;
        let err = parse_chat_response(body).unwrap_err().to_string();
        assert!(err.contains("model 'nope' not found"), "got: {err}");
    }

    #[test]
    fn rejects_non_json_and_empty_content() {
        assert!(parse_chat_response("<html>502 Bad Gateway</html>").is_err());
        assert!(parse_chat_response(r#"{"message":{"content":"  "}}"#).is_err());
        assert!(parse_chat_response("").is_err());
    }

    #[test]
    fn error_snippets_are_bounded() {
        let huge = "x".repeat(10_000);
        let err = parse_chat_response(&huge).unwrap_err().to_string();
        assert!(
            err.len() < 400,
            "error message must stay toast-sized: {}",
            err.len()
        );
    }

    #[test]
    fn parses_model_lists_from_both_providers() {
        let ollama = r#"{"models":[{"name":"qwen2.5:7b"},{"name":"llama3.2:3b"}]}"#;
        assert_eq!(
            parse_models_response(ollama).unwrap(),
            vec!["llama3.2:3b".to_string(), "qwen2.5:7b".to_string()]
        );
        let openai = r#"{"data":[{"id":"gpt-4o-mini"},{"id":"gpt-4o"}]}"#;
        assert_eq!(
            parse_models_response(openai).unwrap(),
            vec!["gpt-4o".to_string(), "gpt-4o-mini".to_string()]
        );
    }

    #[test]
    fn unrecognised_model_list_is_an_error_not_an_empty_dropdown() {
        assert!(parse_models_response(r#"{"unexpected":true}"#).is_err());
    }

    // --- validation ------------------------------------------------------

    #[tokio::test]
    async fn refuses_to_call_out_without_a_model_or_url() {
        let no_model = SummaryConfig::default();
        assert!(generate_summary(no_model, "halo".into()).await.is_err());

        let no_url = SummaryConfig {
            base_url: "   ".into(),
            model: "qwen2.5:7b".into(),
            ..Default::default()
        };
        assert!(generate_summary(no_url, "halo".into()).await.is_err());
    }

    #[tokio::test]
    async fn refuses_to_send_an_empty_transcript() {
        let config = SummaryConfig {
            model: "qwen2.5:7b".into(),
            ..Default::default()
        };
        let err = generate_summary(config, "   \n ".into()).await.unwrap_err();
        assert!(err.to_string().contains("kosong"));
    }

    #[test]
    fn default_endpoint_is_loopback() {
        // The out-of-the-box configuration must not reach the public internet.
        assert!(DEFAULT_OLLAMA_BASE_URL.contains("localhost"));
        assert_eq!(SummaryConfig::default().base_url, DEFAULT_OLLAMA_BASE_URL);
        assert!(SummaryConfig::default().api_key.is_empty());
    }

    #[test]
    fn request_body_carries_system_and_user_messages_for_both_providers() {
        for provider in [SummaryProvider::Ollama, SummaryProvider::OpenAiCompatible] {
            let config = SummaryConfig {
                provider,
                model: "m".into(),
                ..Default::default()
            };
            let body = request_body(&config, "PROMPT");
            let messages = body["messages"].as_array().unwrap();
            assert_eq!(messages.len(), 2);
            assert_eq!(messages[0]["role"], "system");
            assert_eq!(messages[1]["role"], "user");
            assert_eq!(messages[1]["content"], "PROMPT");
            assert_eq!(
                body["stream"], false,
                "streaming would break parse_chat_response"
            );
        }
    }
}
