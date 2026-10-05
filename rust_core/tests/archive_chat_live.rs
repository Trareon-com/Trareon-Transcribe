//! F12 exit criterion: the archive chat answers a question over three
//! synthetic meetings, and cites the right one.
//!
//! Gated behind `TRAREON_ARCHIVE_LIVE=1` because it needs a model
//! endpoint. Run against a local Ollama:
//!
//! ```bash
//! TRAREON_ARCHIVE_LIVE=1 cargo test --test archive_chat_live -- --nocapture
//! ```
//!
//! Defaults to `qwen2.5:0.5b` on loopback, which is deliberately the
//! weakest model anyone would plausibly use: if retrieval is doing its
//! job, even a 0.5B model lands on the right meeting, and if it is not,
//! no amount of model quality hides that.
//!
//! The retrieval half of this runs unconditionally in
//! `archive::tests::the_right_meeting_wins_across_three`; only the
//! composed answer needs the endpoint.

use rust_core::archive;
use rust_core::export::Segment;
use rust_core::summary::{
    SummaryConfig, SummaryProvider, SummaryTemplate, DEFAULT_OLLAMA_BASE_URL,
};

fn enabled() -> bool {
    std::env::var("TRAREON_ARCHIVE_LIVE").as_deref() == Ok("1")
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
        template: SummaryTemplate::Kustom,
        custom_prompt: String::new(),
        language: "id".to_string(),
        timeout_secs: 600,
        with_citations: false,
        with_action_items: false,
    }
}

fn seg(text: &str, timestamp: f64, speaker: &str) -> Segment {
    Segment {
        source: "spk".into(),
        speaker: speaker.into(),
        text: text.into(),
        timestamp,
        duration: 5.0,
        language: "id".into(),
        confidence: 0.9,
        avg_log_prob: -0.3,
        is_partial: false,
        low_confidence: false,
        words: Vec::new(),
    }
}

/// Three meetings, each holding exactly one fact the others do not.
fn seed(library: &std::path::Path) {
    let mut db = archive::open(library).expect("open index");
    archive::index_session(
        &mut db,
        "/lib/20260801-Rapat Anggaran",
        "Rapat Anggaran",
        "2026-08-01",
        &[
            seg("Selamat pagi, agenda hari ini pagu anggaran.", 0.0, "Saya"),
            seg(
                "Pagu anggaran tahun depan disepakati naik sepuluh persen.",
                40.0,
                "Peserta 1",
            ),
        ],
        "Rapat memutuskan kenaikan pagu anggaran sepuluh persen.",
        1,
        1,
    )
    .expect("index 1");
    archive::index_session(
        &mut db,
        "/lib/20260815-Rapat Vendor",
        "Rapat Vendor",
        "2026-08-15",
        &[seg(
            "Kontrak vendor katering diperpanjang enam bulan.",
            45.0,
            "Peserta 1",
        )],
        "",
        1,
        1,
    )
    .expect("index 2");
    archive::index_session(
        &mut db,
        "/lib/20260901-Rapat Jadwal",
        "Rapat Jadwal",
        "2026-09-01",
        &[seg(
            "Tenggat peluncuran aplikasi digeser ke bulan November.",
            90.0,
            "Peserta 3",
        )],
        "",
        1,
        1,
    )
    .expect("index 3");
}

#[tokio::test]
async fn the_archive_answers_a_question_and_cites_the_right_meeting() {
    if !enabled() {
        eprintln!("skipping: set TRAREON_ARCHIVE_LIVE=1 to run");
        return;
    }
    let library = std::env::temp_dir().join(format!("trareon_arsip_live_{}", uuid::Uuid::new_v4()));
    std::fs::create_dir_all(&library).unwrap();
    seed(&library);

    let question = "Kapan tenggat peluncuran aplikasi?";
    let db = archive::open(&library).expect("open index");
    let sources =
        archive::search(&db, question, archive::MAX_CONTEXT_PASSAGES as u32).expect("search");
    assert!(!sources.is_empty(), "retrieval found nothing");
    assert_eq!(
        sources[0].title, "Rapat Jadwal",
        "retrieval must rank the right meeting first; got {sources:#?}"
    );

    let prompt = archive::build_question_prompt(question, &sources);
    let answer = rust_core::summary::ask(config(), prompt)
        .await
        .expect("the endpoint must answer; is Ollama running?");
    println!("--- JAWABAN ---\n{answer}\n---------------");
    for (index, source) in sources.iter().enumerate() {
        println!("[K{}] {}", index + 1, source.citation());
    }

    let lower = answer.to_lowercase();
    assert!(
        lower.contains("november"),
        "the answer must carry the fact from the right meeting: {answer}"
    );
    assert!(
        answer.contains("[K"),
        "the answer must cite a passage: {answer}"
    );
    let _ = std::fs::remove_dir_all(&library);
}
