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
    /// Ask the model to cite the transcript segment behind each point
    /// (F7). Off by default: it costs prompt budget and a weak model
    /// spends it inventing numbers.
    #[serde(default)]
    pub with_citations: bool,
    /// Ask for the structured "Tindak Lanjut" JSON block (F6).
    #[serde(default)]
    pub with_action_items: bool,
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
            with_citations: false,
            with_action_items: false,
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

/// The `##` section headings a built-in template asks the model for.
///
/// Used by the "duplicate this template" flow (F8): a user who wants "the
/// notulen one, but with a Risiko section" starts from the real headings
/// rather than a blank textarea.
#[flutter_rust_bridge::frb(ignore)]
pub fn builtin_headings(template: SummaryTemplate) -> Vec<String> {
    let headings: &[&str] = match template {
        SummaryTemplate::NotulenRapat => &[
            "Ringkasan",
            "Peserta",
            "Pembahasan",
            "Keputusan",
            "Tindak Lanjut",
        ],
        SummaryTemplate::RingkasanEksekutif => &["Ringkasan Eksekutif"],
        SummaryTemplate::ActionItems => &["Keputusan", "Action Items"],
        SummaryTemplate::Standup => &["Selesai", "Berikutnya", "Hambatan"],
        SummaryTemplate::Kustom => &[],
    };
    headings.iter().map(|h| (*h).to_string()).collect()
}

/// Composes the instruction for a user-authored template from its free-text
/// instructions plus the section headings it declares.
///
/// Spelling the headings out as an explicit, ordered list is what makes a
/// custom template's output stable enough to parse back into the notulen form
/// — a model given only prose instructions renames sections between runs.
#[flutter_rust_bridge::frb(ignore)]
pub fn compose_custom_instruction(instructions: &str, headings: &[String]) -> String {
    let base = instructions.trim();
    let sections: Vec<String> = headings
        .iter()
        .map(|h| h.trim().trim_start_matches('#').trim().to_string())
        .filter(|h| !h.is_empty())
        .collect();
    if sections.is_empty() {
        return base.to_string();
    }
    let rendered = sections
        .iter()
        .map(|h| format!("## {h}"))
        .collect::<Vec<_>>()
        .join("\n");
    if base.is_empty() {
        format!("Tulis ringkasan rapat dengan bagian berikut, dalam urutan ini:\n{rendered}")
    } else {
        format!("{base}\n\nGunakan bagian berikut, dalam urutan ini:\n{rendered}")
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

/// System prompt for answering a question over retrieved passages (F12).
///
/// Deliberately *not* [`system_prompt`]. That one tells the model it is a
/// notulis turning a transcript into a document and to emit "Markdown
/// murni tanpa kalimat pembuka atau penutup" — correct for a summary and
/// actively wrong for a question, because it pushes the model towards a
/// heading instead of an answer. Against a real Ollama `qwen2.5:0.5b`,
/// asking "Kapan tenggat peluncuran aplikasi?" with the summarisation
/// system prompt returned the topic line
/// `01:30 - 02:00 [Tenggat peluncuran aplikasi]`; the same passages and
/// the same question with the prompt below return the fact and its
/// citation. A small model obeys its system prompt literally, which is a
/// reason to get it right rather than a reason to require a big model.
pub fn question_system_prompt(language: &str) -> String {
    let output_language = if language.eq_ignore_ascii_case("en") {
        "English"
    } else {
        "Bahasa Indonesia"
    };
    format!(
        "Anda menjawab pertanyaan tentang arsip rapat.\n\
         Aturan wajib:\n\
         - Tulis jawaban dalam {output_language}, sebagai kalimat utuh.\n\
         - Gunakan HANYA kutipan yang diberikan. Jangan mengarang nama, \
           angka, tanggal, atau keputusan.\n\
         - Akhiri setiap pernyataan dengan rujukan kutipannya: [K1], [K2].\n\
         - Jika kutipan tidak cukup, tulis \"Tidak ditemukan di arsip rapat\".\n\
         - Jangan menyalin ulang judul atau stempel waktu kutipan sebagai \
           jawaban; jawablah pertanyaannya."
    )
}

/// The user message: instruction + transcript (truncated to
/// [`MAX_TRANSCRIPT_CHARS`]) + whatever the notulis flagged during the meeting.
///
/// The bookmark block is appended *after* the truncation so a three-hour
/// meeting cannot drop the very moments the user marked as important — which
/// is the whole point of having marked them.
#[flutter_rust_bridge::frb(ignore)]
pub fn build_prompt(config: &SummaryConfig, transcript: &str, bookmarks: &[String]) -> String {
    let instruction = full_instruction(config);
    let body = truncate_transcript(transcript.trim(), MAX_TRANSCRIPT_CHARS);
    let mut prompt = format!("{instruction}\n\n--- TRANSKRIP ---\n{body}\n--- AKHIR TRANSKRIP ---");
    let marks: Vec<&str> = bookmarks
        .iter()
        .map(|b| b.trim())
        .filter(|b| !b.is_empty())
        .collect();
    if !marks.is_empty() {
        prompt.push_str("\n\n--- POIN YANG DITANDAI NOTULIS (utamakan ini) ---\n");
        prompt.push_str(&marks.join("\n"));
        prompt.push_str("\n--- AKHIR POIN DITANDAI ---");
    }
    prompt
}

/// The template's instruction plus whatever optional blocks the config
/// asks for (citations F7, action items F6), in the order the model
/// should produce them.
#[flutter_rust_bridge::frb(ignore)]
pub fn full_instruction(config: &SummaryConfig) -> String {
    let mut instruction = template_instruction(config.template, &config.custom_prompt);
    if config.with_citations {
        instruction.push_str("\n\n");
        instruction.push_str(&crate::provenance::provenance_instruction());
    }
    if config.with_action_items {
        instruction.push_str("\n\n");
        instruction.push_str(&crate::actions::action_items_instruction());
    }
    instruction
}

// ---------------------------------------------------------------------------
// Long meetings: map-reduce (F15)
// ---------------------------------------------------------------------------

/// Where a running map-reduce summary has got to.
///
/// A single global slot, like the batch-transcription one: only one
/// summary runs at a time (the button disables itself), and polling is
/// how Dart sees inside a single long-lived FRB future.
static PROGRESS: std::sync::Mutex<Option<crate::mapreduce::MapReduceProgress>> =
    std::sync::Mutex::new(None);

#[flutter_rust_bridge::frb(ignore)]
pub fn publish_progress(progress: crate::mapreduce::MapReduceProgress) {
    if let Ok(mut slot) = PROGRESS.lock() {
        *slot = Some(progress);
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn read_progress() -> Option<crate::mapreduce::MapReduceProgress> {
    PROGRESS.lock().ok()?.clone()
}

/// Clears the slot, so a caller cannot read the *previous* run's last
/// window before the first update of this one lands.
#[flutter_rust_bridge::frb(ignore)]
pub fn reset_progress() {
    if let Ok(mut slot) = PROGRESS.lock() {
        *slot = None;
    }
}

/// Summarises a meeting too long for one request, window by window.
///
/// `on_progress` is called before each round trip; a three-hour meeting
/// is eighteen of them and the user needs to see which.
///
/// Falls back to a single request when the transcript fits — one round
/// trip is both faster and better, because the model sees every
/// connection at once.
pub async fn generate_summary_long(
    config: SummaryConfig,
    segments: Vec<Segment>,
    bookmarks: Vec<String>,
    mut on_progress: impl FnMut(crate::mapreduce::MapReduceProgress),
) -> Result<String, TranscribeError> {
    validate(&config)?;
    let rendered = if config.with_citations {
        crate::provenance::numbered_transcript(&segments)
    } else {
        transcript_text(&segments)
    };
    if rendered.trim().is_empty() {
        return Err(TranscribeError::Summary(
            "Transkrip kosong — tidak ada yang bisa diringkas.".into(),
        ));
    }
    if !crate::mapreduce::needs_map_reduce(rendered.len(), MAX_TRANSCRIPT_CHARS) {
        return generate_summary(config, rendered, bookmarks).await;
    }

    let chunks = crate::mapreduce::chunk_by_time(
        &segments,
        crate::mapreduce::WINDOW_SECS,
        crate::mapreduce::MAX_WINDOW_CHARS,
    );
    let total = chunks.len() as u32;
    let mut partials = Vec::with_capacity(chunks.len());
    for (index, chunk) in chunks.iter().enumerate() {
        on_progress(crate::mapreduce::MapReduceProgress::mapping(
            index as u32,
            total,
            &chunk.label(),
        ));
        // The map step wants notes, not a finished document, so it runs
        // with the window instruction rather than the user's template.
        let map_config = SummaryConfig {
            template: SummaryTemplate::Kustom,
            custom_prompt: crate::mapreduce::map_instruction(chunk),
            // Citations and the action-item JSON belong to the reduce
            // step; asking for them per window produces eighteen
            // conflicting JSON blocks.
            with_citations: false,
            with_action_items: false,
            ..config.clone()
        };
        // A window the endpoint refused is recorded as empty rather than
        // failing the run: seventeen windows of notes beat none.
        let partial = match generate_summary(map_config, chunk.text.clone(), Vec::new()).await {
            Ok(text) => text,
            Err(e) => {
                tracing::warn!(window = chunk.index, %e, "map step failed for one window");
                String::new()
            }
        };
        partials.push(partial);
    }
    if partials.iter().all(|p| p.trim().is_empty()) {
        return Err(TranscribeError::Summary(
            "Tidak ada bagian rapat yang berhasil diringkas. Periksa endpoint \
             dan model yang dipilih."
                .into(),
        ));
    }

    on_progress(crate::mapreduce::MapReduceProgress::reducing(total));
    let joined = crate::mapreduce::join_partials(&chunks, &partials);
    let reduce_config = SummaryConfig {
        template: SummaryTemplate::Kustom,
        custom_prompt: crate::mapreduce::reduce_instruction(&full_instruction(&config)),
        with_citations: false,
        with_action_items: false,
        ..config
    };
    generate_summary(reduce_config, joined, bookmarks).await
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

/// Per-request knobs that differ between the summary, question and
/// notulen paths.
#[derive(Debug, Clone, Copy, Default)]
pub struct ChatOptions {
    /// Ask the endpoint to constrain the answer to JSON.
    ///
    /// Only for the notulen path, whose prompt demands one JSON object.
    /// A Markdown summary asked for JSON comes back as a JSON *string*
    /// containing the Markdown.
    pub json: bool,
    /// Ask a reasoning model not to reason.
    ///
    /// A thinking model left in thinking mode spends most of its budget
    /// on tokens the document never shows. Ollama rejects `think` for
    /// models that have no thinking mode, so [`chat_once`] retries
    /// without it rather than failing the request.
    pub no_think: bool,
}

fn request_body(
    config: &SummaryConfig,
    system: &str,
    prompt: &str,
    options: ChatOptions,
) -> serde_json::Value {
    let messages = serde_json::json!([
        { "role": "system", "content": system },
        { "role": "user", "content": prompt },
    ]);
    match config.provider {
        SummaryProvider::Ollama => {
            let mut body = serde_json::json!({
                "model": config.model,
                "messages": messages,
                "stream": false,
                "options": { "temperature": 0.2 },
            });
            if options.json {
                body["format"] = serde_json::json!("json");
            }
            if options.no_think {
                body["think"] = serde_json::json!(false);
            }
            body
        }
        SummaryProvider::OpenAiCompatible => {
            let mut body = serde_json::json!({
                "model": config.model,
                "messages": messages,
                "stream": false,
                "temperature": 0.2,
            });
            if options.json {
                body["response_format"] = serde_json::json!({ "type": "json_object" });
            }
            body
        }
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

/// One chat round trip against the configured endpoint.
///
/// The single place in the crate that performs an outbound request with
/// user content. Every feature that needs a model — summary, archive
/// question, notulen — goes through here, which is what keeps
/// `privacy::tests`' "only two modules may open a socket" claim true.
pub async fn chat_once(
    config: &SummaryConfig,
    system: &str,
    prompt: &str,
    options: ChatOptions,
) -> Result<String, TranscribeError> {
    let url = chat_endpoint(config.provider, &config.base_url);
    let send = |options: ChatOptions| {
        let body = request_body(config, system, prompt, options);
        let url = url.clone();
        async move {
            let mut request = client(config.timeout_secs)?.post(&url).json(&body);
            if !config.api_key.trim().is_empty() {
                request = request.bearer_auth(config.api_key.trim());
            }
            let response = request.send().await.map_err(|e| {
                TranscribeError::Summary(format!(
                    "tidak bisa menghubungi {url}: {e}. Pastikan layanan berjalan dan \
                     URL benar."
                ))
            })?;
            let status = response.status();
            let text = response.text().await.map_err(|e| {
                TranscribeError::Summary(format!("gagal membaca jawaban {url}: {e}"))
            })?;
            Ok::<_, TranscribeError>((status, text))
        }
    };

    let (mut status, mut body) = send(options).await?;
    if !status.is_success() && options.no_think && body.to_lowercase().contains("think") {
        // The endpoint has no thinking mode to turn off. Asking again
        // without the field is better than reporting a failure the user
        // cannot act on.
        let (retry_status, retry_body) = send(ChatOptions {
            no_think: false,
            ..options
        })
        .await?;
        status = retry_status;
        body = retry_body;
    }

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

/// Sends `transcript` to the configured endpoint and returns Markdown.
pub async fn generate_summary(
    config: SummaryConfig,
    transcript: String,
    bookmarks: Vec<String>,
) -> Result<String, TranscribeError> {
    validate(&config)?;
    if transcript.trim().is_empty() {
        return Err(TranscribeError::Summary(
            "Transkrip kosong — tidak ada yang bisa diringkas.".into(),
        ));
    }
    let prompt = build_prompt(&config, &transcript, &bookmarks);
    chat_once(
        &config,
        &system_prompt(&config.language),
        &prompt,
        ChatOptions::default(),
    )
    .await
}

/// Sends one already-composed prompt to the configured endpoint.
///
/// The seam the archive chat (F12) goes through. `archive` builds the
/// prompt from locally retrieved passages and hands it here, so the one
/// module in the crate that opens a socket stays the one module in the
/// crate that opens a socket — which is the property `privacy::tests`
/// checks and the Privacy Report claims.
pub async fn ask(config: SummaryConfig, prompt: String) -> Result<String, TranscribeError> {
    validate(&config)?;
    if prompt.trim().is_empty() {
        return Err(TranscribeError::Summary("Pertanyaan kosong.".into()));
    }
    chat_once(
        &config,
        // Not the summarisation prompt: see `question_system_prompt`.
        &question_system_prompt(&config.language),
        &prompt,
        ChatOptions::default(),
    )
    .await
}

// ---------------------------------------------------------------------------
// Notulen: strict JSON, with map-reduce for long meetings
// ---------------------------------------------------------------------------

/// What a notulen request produced before any checking.
#[derive(Debug, Clone)]
pub struct NotulenResponse {
    pub parsed: crate::notulen::schema::ParsedNotulen,
    /// The model's answer verbatim, for the diagnostics pane. A notulen
    /// the parser mangled is only debuggable if the original survived.
    pub mentah: String,
    /// `true` when the meeting needed the map-reduce path.
    pub map_reduce: bool,
}

/// The options the notulen path always uses.
///
/// `json` because the prompt demands exactly one JSON object, and
/// `no_think` because a reasoning model's visible reasoning is tokens
/// the document never shows — on a 6 GB GPU that is the difference
/// between forty seconds and six minutes per meeting.
fn notulen_chat_options() -> ChatOptions {
    ChatOptions {
        json: true,
        no_think: true,
    }
}

/// Generates a notulen as strict JSON from `segments`.
///
/// Falls back to the map-reduce path when the transcript is longer than
/// one request can carry; a single pass is both faster and better when
/// the meeting fits, because the model sees every connection at once.
pub async fn generate_notulen(
    config: SummaryConfig,
    template: crate::notulen::NotulenTemplate,
    segments: Vec<Segment>,
    bookmarks: Vec<String>,
    mut on_progress: impl FnMut(crate::mapreduce::MapReduceProgress),
) -> Result<NotulenResponse, TranscribeError> {
    validate(&config)?;
    // Partials dropped once, here, so that three things index the same
    // list: the numbering the model cites into, the windows map-reduce
    // cuts, and the segments `factcheck::periksa` resolves ids against.
    // They used to disagree, which made every citation past the first
    // partial point at the wrong moment.
    let segments: Vec<Segment> = segments.into_iter().filter(|s| !s.is_partial).collect();
    let numbered = crate::provenance::numbered_transcript(&segments);
    if numbered.trim().is_empty() {
        return Err(TranscribeError::Summary(
            "Transkrip kosong — tidak ada yang bisa dinotulenkan.".into(),
        ));
    }

    let system = crate::notulen::prompt::system_prompt(template);
    if !crate::mapreduce::needs_map_reduce(numbered.len(), MAX_TRANSCRIPT_CHARS) {
        let prompt = crate::notulen::prompt::user_prompt(template, &numbered, &bookmarks);
        let mentah = chat_once(&config, &system, &prompt, notulen_chat_options()).await?;
        return Ok(NotulenResponse {
            parsed: crate::notulen::schema::parse(&mentah)?,
            mentah,
            map_reduce: false,
        });
    }

    // --- map: notes per window ------------------------------------------
    //
    // The windows are numbered against the *whole* transcript, not
    // restarted per window, so a segment id in a window's notes still
    // resolves after the reduce step. That is the only reason citations
    // survive a three-hour meeting.
    let chunks = crate::mapreduce::chunk_by_time(
        &segments,
        crate::mapreduce::WINDOW_SECS,
        crate::mapreduce::MAX_WINDOW_CHARS,
    );
    let total = chunks.len() as u32;
    let mut partials: Vec<String> = Vec::with_capacity(chunks.len());
    for (index, chunk) in chunks.iter().enumerate() {
        on_progress(crate::mapreduce::MapReduceProgress::mapping(
            index as u32,
            total,
            &chunk.label(),
        ));
        let offset = chunk.first_index as usize;
        let end = (offset + chunk.count as usize).min(segments.len());
        let numbered_window =
            crate::provenance::numbered_transcript_from(&segments[offset.min(end)..end], offset);

        let instruction =
            crate::notulen::prompt::map_prompt(chunk.index, chunk.total, &chunk.label());
        let prompt = format!(
            "{instruction}\n\n--- TRANSKRIP BAGIAN INI (bernomor segmen) ---\n\
             {numbered_window}\n--- AKHIR BAGIAN ---"
        );
        // Notes are prose, so no JSON constraint here; the reduce step is
        // what has to emit the schema.
        let partial = match chat_once(
            &config,
            &system,
            &prompt,
            ChatOptions {
                json: false,
                no_think: true,
            },
        )
        .await
        {
            Ok(text) => text,
            Err(e) => {
                // A window the endpoint refused is recorded as empty
                // rather than failing the run: seventeen windows of notes
                // beat none.
                tracing::warn!(window = chunk.index, %e, "map step failed for one window");
                String::new()
            }
        };
        partials.push(partial);
    }
    if partials.iter().all(|p| p.trim().is_empty()) {
        return Err(TranscribeError::Summary(
            "Tidak ada bagian rapat yang berhasil diringkas. Periksa endpoint \
             dan model yang dipilih."
                .into(),
        ));
    }

    // --- reduce: one document -------------------------------------------
    on_progress(crate::mapreduce::MapReduceProgress::reducing(total));
    let notes = crate::mapreduce::join_partials(&chunks, &partials);
    let mut prompt = crate::notulen::prompt::reduce_prompt(template, &notes);
    let marks: Vec<&str> = bookmarks
        .iter()
        .map(|b| b.trim())
        .filter(|b| !b.is_empty())
        .collect();
    if !marks.is_empty() {
        prompt.push_str("\n\n--- POIN YANG DITANDAI NOTULIS ---\n");
        prompt.push_str(&marks.join("\n"));
        prompt.push_str("\n--- AKHIR POIN DITANDAI ---");
    }
    let mentah = chat_once(&config, &system, &prompt, notulen_chat_options()).await?;
    Ok(NotulenResponse {
        parsed: crate::notulen::schema::parse(&mentah)?,
        mentah,
        map_reduce: true,
    })
}

// ---------------------------------------------------------------------------
// First-run setup: is the runtime there, and can we fetch a model
// ---------------------------------------------------------------------------

/// What the setup step found at the configured endpoint.
#[derive(Debug, Clone, Serialize)]
pub struct OllamaStatus {
    pub tersedia: bool,
    /// Version string the endpoint reported, empty when unreachable.
    pub versi: String,
    /// Models already installed there.
    pub model: Vec<String>,
    /// Indonesian sentence for the UI, whether it worked or not.
    pub pesan: String,
}

/// Checks whether an Ollama runtime answers at `base_url`.
///
/// Sends no transcript content — `/api/version` and `/api/tags` carry no
/// user data — and never errors: "not installed" is the expected answer
/// on first run, and an `Err` would make the setup screen look broken
/// rather than instructive.
pub async fn detect_ollama(base_url: String) -> OllamaStatus {
    let base = trim_base(&base_url);
    if base.is_empty() {
        return OllamaStatus {
            tersedia: false,
            versi: String::new(),
            model: Vec::new(),
            pesan: "URL endpoint belum diisi.".to_string(),
        };
    }
    let Ok(client) = client(10) else {
        return OllamaStatus {
            tersedia: false,
            versi: String::new(),
            model: Vec::new(),
            pesan: "Gagal menyiapkan HTTP client.".to_string(),
        };
    };
    let version = match client.get(format!("{base}/api/version")).send().await {
        Ok(response) if response.status().is_success() => response
            .json::<serde_json::Value>()
            .await
            .ok()
            .and_then(|v| {
                v.get("version")
                    .and_then(|s| s.as_str())
                    .map(str::to_string)
            })
            .unwrap_or_default(),
        _ => {
            return OllamaStatus {
                tersedia: false,
                versi: String::new(),
                model: Vec::new(),
                pesan: format!(
                    "Ollama tidak menjawab di {base}. Pasang Ollama lalu tekan \
                     \"Periksa lagi\"."
                ),
            }
        }
    };
    let model = list_summary_models(SummaryProvider::Ollama, base.to_string(), String::new())
        .await
        .unwrap_or_default();
    let pesan = if model.is_empty() {
        format!(
            "Ollama {version} berjalan di {base}, tetapi belum ada model \
             terpasang. Unduh model yang disarankan di bawah."
        )
    } else {
        format!(
            "Ollama {version} berjalan di {base} dengan {} model terpasang.",
            model.len()
        )
    };
    OllamaStatus {
        tersedia: true,
        versi: version,
        model,
        pesan,
    }
}

/// Downloads `model` into the Ollama at `base_url`, reporting progress.
///
/// Streamed rather than requested with `stream: false`, because a 5 GB
/// download with no progress is indistinguishable from a hang — and the
/// first thing a user does to a hung download is kill the app.
///
/// Records one [`crate::pdp::audit::AuditAction::ModelPulled`] entry on
/// success, so the Privacy Report shows that the app fetched something
/// over the network and from where.
pub async fn pull_model(
    base_url: String,
    model: String,
    mut on_progress: impl FnMut(crate::llm_setup::PullProgress),
) -> Result<(), TranscribeError> {
    use futures_util::StreamExt;

    let base = trim_base(&base_url);
    if base.is_empty() {
        return Err(TranscribeError::Summary(
            "URL endpoint ringkasan belum diisi.".into(),
        ));
    }
    if model.trim().is_empty() {
        return Err(TranscribeError::Summary("Model belum dipilih.".into()));
    }
    let url = format!("{base}/api/pull");
    // No timeout: a model is gigabytes and a slow connection is not an
    // error. The user cancels by leaving the screen.
    let response = reqwest::Client::builder()
        .build()
        .map_err(|e| TranscribeError::Summary(format!("gagal membuat HTTP client: {e}")))?
        .post(&url)
        .json(&serde_json::json!({ "model": model.trim(), "stream": true }))
        .send()
        .await
        .map_err(|e| {
            TranscribeError::Summary(format!(
                "tidak bisa menghubungi {url}: {e}. Pastikan Ollama berjalan."
            ))
        })?;
    let status = response.status();
    if !status.is_success() {
        let body = response.text().await.unwrap_or_default();
        return Err(TranscribeError::Summary(format!(
            "HTTP {} dari {url} — {}",
            status.as_u16(),
            snippet(&body)
        )));
    }

    let mut stream = response.bytes_stream();
    // The stream is newline-delimited JSON, and a chunk boundary lands
    // mid-line often enough that parsing per chunk loses lines.
    let mut buffer = String::new();
    let mut succeeded = false;
    let mut last_error = String::new();
    while let Some(chunk) = stream.next().await {
        let bytes =
            chunk.map_err(|e| TranscribeError::Summary(format!("unduhan terputus: {e}")))?;
        buffer.push_str(&String::from_utf8_lossy(&bytes));
        while let Some(at) = buffer.find('\n') {
            let line: String = buffer.drain(..=at).collect();
            if let Some(progress) = crate::llm_setup::parse_pull_line(&line) {
                if progress.status == "error" {
                    last_error = progress.label.clone();
                }
                succeeded |= progress.done;
                on_progress(progress);
            }
        }
    }
    // A stream that ended mid-line still has one line left in it.
    if let Some(progress) = crate::llm_setup::parse_pull_line(&buffer) {
        if progress.status == "error" {
            last_error = progress.label.clone();
        }
        succeeded |= progress.done;
        on_progress(progress);
    }

    if !succeeded {
        return Err(TranscribeError::Summary(if last_error.is_empty() {
            format!("Unduhan {model} berakhir tanpa konfirmasi berhasil.")
        } else {
            last_error
        }));
    }
    crate::pdp::audit::record(
        crate::pdp::audit::AuditEntry::new(crate::pdp::audit::AuditAction::ModelPulled, &model)
            .to(base)
            .with_detail("Model notulen diunduh ke endpoint ringkasan"),
    );
    Ok(())
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
            words: Vec::new(),
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
        let prompt = build_prompt(&config, "[00:00] Saya: kita putuskan pakai Rust", &[]);
        assert!(prompt.contains("Action Items"));
        assert!(prompt.contains("kita putuskan pakai Rust"));
        assert!(prompt.contains("--- AKHIR TRANSKRIP ---"));
    }

    #[test]
    fn bookmarks_are_appended_after_the_transcript_truncation() {
        let config = SummaryConfig::default();
        // A transcript well past the cap: the bookmark block must still be
        // in the prompt, because truncation happens before it is added.
        let long = "x".repeat(MAX_TRANSCRIPT_CHARS + 5_000);
        let prompt = build_prompt(&config, &long, &["[05:12] keputusan penting".to_string()]);
        assert!(prompt.contains("dipotong"), "the transcript was truncated");
        assert!(prompt.contains("[05:12] keputusan penting"));
        assert!(
            prompt.find("--- AKHIR TRANSKRIP ---").unwrap()
                < prompt.find("[05:12] keputusan penting").unwrap()
        );
    }

    #[test]
    fn a_prompt_without_bookmarks_is_unchanged() {
        let config = SummaryConfig::default();
        let with_blanks = build_prompt(&config, "halo", &["".into(), "   ".into()]);
        assert_eq!(with_blanks, build_prompt(&config, "halo", &[]));
        assert!(!with_blanks.contains("DITANDAI"));
    }

    #[test]
    fn builtin_headings_match_the_template_instructions() {
        // The headings drive the "duplicate this template" flow, so they must
        // be the headings the instruction actually asks for.
        for template in [
            SummaryTemplate::NotulenRapat,
            SummaryTemplate::RingkasanEksekutif,
            SummaryTemplate::ActionItems,
        ] {
            let instruction = template_instruction(template, "").to_lowercase();
            for heading in builtin_headings(template) {
                assert!(
                    instruction.contains(&heading.to_lowercase()),
                    "{template:?} instruction never mentions {heading:?}"
                );
            }
        }
        assert!(builtin_headings(SummaryTemplate::Kustom).is_empty());
    }

    #[test]
    fn custom_instruction_spells_out_the_section_headings_in_order() {
        let composed = compose_custom_instruction(
            "  Fokus pada risiko anggaran.  ",
            &["Pembahasan".into(), "## Risiko".into(), "  ".into()],
        );
        assert!(composed.starts_with("Fokus pada risiko anggaran."));
        assert!(composed.contains("## Pembahasan\n## Risiko"));
        assert!(!composed.contains("## ## "), "headings are normalised");
    }

    #[test]
    fn custom_instruction_falls_back_sensibly() {
        // Headings without prose still produce a usable instruction …
        assert!(compose_custom_instruction("", &["Risiko".into()]).contains("## Risiko"));
        // … and prose without headings is passed through verbatim.
        assert_eq!(
            compose_custom_instruction(" Ringkas saja. ", &[]),
            "Ringkas saja."
        );
    }

    #[test]
    fn a_custom_template_instruction_reaches_the_prompt() {
        let config = SummaryConfig {
            template: SummaryTemplate::Kustom,
            custom_prompt: compose_custom_instruction("Fokus risiko.", &["Risiko".into()]),
            ..Default::default()
        };
        let prompt = build_prompt(&config, "[00:00] Saya: ada risiko kurs", &[]);
        assert!(prompt.contains("Fokus risiko."));
        assert!(prompt.contains("## Risiko"));
    }

    /// The question path must not inherit the summarisation persona.
    ///
    /// Regression test for a real failure: `ask()` used the notulen
    /// system prompt, whose "Markdown murni tanpa kalimat pembuka"
    /// instruction made a small model answer "Kapan tenggat peluncuran
    /// aplikasi?" with the topic line `01:30 - 02:00 [Tenggat peluncuran
    /// aplikasi]` instead of the fact.
    #[test]
    fn asking_a_question_does_not_use_the_summarising_persona() {
        let question = question_system_prompt("id");
        let summarise = system_prompt("id");
        assert_ne!(question, summarise);
        // The summariser's shape instructions are what broke the answer.
        assert!(summarise.contains("Markdown murni"));
        assert!(!question.contains("Markdown murni"));
        assert!(!question.contains("notulis rapat profesional"));
        // What the answer path does need.
        assert!(question.contains("[K1]"));
        assert!(question.contains("kalimat utuh"));
        assert!(question.contains("Tidak ditemukan di arsip rapat"));
        // And it still refuses to invent, like every other prompt here.
        assert!(question.contains("Jangan mengarang"));
        assert!(question_system_prompt("en").contains("English"));
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
        assert!(generate_summary(no_model, "halo".into(), Vec::new())
            .await
            .is_err());

        let no_url = SummaryConfig {
            base_url: "   ".into(),
            model: "qwen2.5:7b".into(),
            ..Default::default()
        };
        assert!(generate_summary(no_url, "halo".into(), Vec::new())
            .await
            .is_err());
    }

    #[tokio::test]
    async fn refuses_to_send_an_empty_transcript() {
        let config = SummaryConfig {
            model: "qwen2.5:7b".into(),
            ..Default::default()
        };
        let err = generate_summary(config, "   \n ".into(), Vec::new())
            .await
            .unwrap_err();
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
            let body = request_body(&config, "SYSTEM", "PROMPT", ChatOptions::default());
            let messages = body["messages"].as_array().unwrap();
            assert_eq!(messages.len(), 2);
            assert_eq!(messages[0]["role"], "system");
            assert_eq!(messages[0]["content"], "SYSTEM");
            assert_eq!(messages[1]["role"], "user");
            assert_eq!(messages[1]["content"], "PROMPT");
            assert_eq!(
                body["stream"], false,
                "streaming would break parse_chat_response"
            );
            // The summary path must not ask for JSON: a Markdown summary
            // constrained to JSON comes back as a JSON *string* holding
            // the Markdown.
            assert!(body.get("format").is_none());
            assert!(body.get("response_format").is_none());
            assert!(body.get("think").is_none());
        }
    }

    #[test]
    fn the_notulen_options_ask_each_provider_for_json_in_its_own_dialect() {
        let ollama = request_body(
            &SummaryConfig {
                model: "m".into(),
                ..Default::default()
            },
            "S",
            "P",
            notulen_chat_options(),
        );
        assert_eq!(ollama["format"], "json");
        assert_eq!(ollama["think"], false);

        let openai = request_body(
            &SummaryConfig {
                provider: SummaryProvider::OpenAiCompatible,
                model: "m".into(),
                ..Default::default()
            },
            "S",
            "P",
            notulen_chat_options(),
        );
        assert_eq!(openai["response_format"]["type"], "json_object");
        // `think` is an Ollama extension; sending it to an OpenAI-shaped
        // endpoint is a 400 from some servers and silently ignored by
        // others, and neither is useful.
        assert!(openai.get("think").is_none());
    }

    #[tokio::test]
    async fn a_notulen_request_refuses_an_empty_transcript() {
        let config = SummaryConfig {
            model: "m".into(),
            ..Default::default()
        };
        let err = generate_notulen(
            config,
            crate::notulen::NotulenTemplate::Dinas,
            Vec::new(),
            Vec::new(),
            |_| {},
        )
        .await
        .unwrap_err();
        assert!(err.to_string().contains("kosong"), "got: {err}");
    }

    #[tokio::test]
    async fn a_notulen_request_of_only_partials_is_an_empty_transcript() {
        // Partials are dropped before the transcript is numbered, so a
        // live-preview-only transcript must be reported as empty rather
        // than sent to the endpoint.
        let config = SummaryConfig {
            model: "m".into(),
            ..Default::default()
        };
        let mut partial = seg("Saya", "teks cepat", 0.0, true);
        partial.is_partial = true;
        let err = generate_notulen(
            config,
            crate::notulen::NotulenTemplate::Dinas,
            vec![partial],
            Vec::new(),
            |_| {},
        )
        .await
        .unwrap_err();
        assert!(err.to_string().contains("kosong"), "got: {err}");
    }
}
