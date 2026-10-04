//! Live end-to-end check for the AI summary against a real endpoint.
//!
//! Skipped unless `TRAREON_SUMMARY_LIVE=1` is set, because CI has no model
//! server and a test that silently depends on one is worse than no test.
//!
//! Run it against a local Ollama:
//!
//! ```sh
//! ollama pull qwen2.5:0.5b
//! TRAREON_SUMMARY_LIVE=1 TRAREON_SUMMARY_MODEL=qwen2.5:0.5b \
//!   cargo test --test summary_live -- --nocapture
//! ```
//!
//! Override `TRAREON_SUMMARY_URL` / `TRAREON_SUMMARY_MODEL` /
//! `TRAREON_SUMMARY_KEY` to point at an OpenAI-compatible endpoint instead.

use rust_core::export::Segment;
use rust_core::summary::{
    generate_summary, list_summary_models, transcript_text, SummaryConfig, SummaryProvider,
    SummaryTemplate, DEFAULT_OLLAMA_BASE_URL,
};

fn enabled() -> bool {
    std::env::var("TRAREON_SUMMARY_LIVE").as_deref() == Ok("1")
}

fn config() -> SummaryConfig {
    let api_key = std::env::var("TRAREON_SUMMARY_KEY").unwrap_or_default();
    SummaryConfig {
        provider: if api_key.is_empty() {
            SummaryProvider::Ollama
        } else {
            SummaryProvider::OpenAiCompatible
        },
        base_url: std::env::var("TRAREON_SUMMARY_URL")
            .unwrap_or_else(|_| DEFAULT_OLLAMA_BASE_URL.to_string()),
        api_key,
        model: std::env::var("TRAREON_SUMMARY_MODEL")
            .unwrap_or_else(|_| "qwen2.5:0.5b".to_string()),
        template: SummaryTemplate::ActionItems,
        custom_prompt: String::new(),
        language: "id".to_string(),
        timeout_secs: 300,
        with_citations: false,
        with_action_items: false,
    }
}

fn seg(speaker: &str, text: &str, timestamp: f64) -> Segment {
    Segment {
        source: "mic".into(),
        speaker: speaker.into(),
        text: text.into(),
        timestamp,
        duration: 4.0,
        language: "id".into(),
        confidence: 0.9,
        avg_log_prob: -0.3,
        is_partial: false,
        low_confidence: false,
    }
}

#[tokio::test]
async fn lists_models_from_a_real_endpoint() {
    if !enabled() {
        eprintln!("skipped: set TRAREON_SUMMARY_LIVE=1 to run");
        return;
    }
    let config = config();
    let models = list_summary_models(config.provider, config.base_url, config.api_key)
        .await
        .expect("endpoint should list models");
    assert!(!models.is_empty(), "endpoint reported no models");
    eprintln!("models: {models:?}");
}

#[tokio::test]
async fn summarises_an_indonesian_meeting_transcript() {
    if !enabled() {
        eprintln!("skipped: set TRAREON_SUMMARY_LIVE=1 to run");
        return;
    }

    let segments = vec![
        seg(
            "Saya",
            "Selamat pagi semua, kita bahas anggaran kuartal empat.",
            0.0,
        ),
        seg(
            "Peserta 1",
            "Anggaran pemasaran naik dua puluh persen jadi lima ratus juta rupiah.",
            6.0,
        ),
        seg(
            "Saya",
            "Setuju. Budi tolong siapkan rinciannya sebelum hari Jumat.",
            14.0,
        ),
        seg(
            "Peserta 2",
            "Baik, saya kirim draft ke email semua peserta hari Kamis.",
            21.0,
        ),
    ];

    let transcript = transcript_text(&segments);
    assert!(
        transcript.contains("[00:14] Saya:"),
        "transcript: {transcript}"
    );

    let summary = generate_summary(config(), transcript, Vec::new())
        .await
        .expect("summary generation should succeed");

    eprintln!("--- summary ---\n{summary}\n---------------");
    assert!(!summary.trim().is_empty(), "summary was empty");
}
