//! "Tanya Langsung" (Sprint 21): answer a question from the transcript of
//! the meeting that is still being recorded — not the archive.
//!
//! `archive` (F12) answers from every past meeting via an FTS5 index built
//! after a session is final. This module answers from the one session
//! that is still growing right now, which has no index yet and does not
//! need one: a live meeting's transcript is small enough to reason about
//! directly. The caller (the recording screen) hands over whatever
//! segments the live pipeline already holds in memory; nothing is read
//! from disk here.
//!
//! The same hallucination guard as F12 applies: the prompt forbids the
//! model from answering with anything outside the cited passages, and an
//! empty or irrelevant transcript gets an honest "no context" / "not
//! mentioned" answer rather than an invented one.

use serde::Serialize;

use crate::error::TranscribeError;
use crate::export::Segment;
use crate::summary::SummaryConfig;

/// Budget for how much transcript reaches the model, in words.
///
/// A live meeting easily runs past this in an hour; above it the model
/// either truncates silently or runs very slowly on the weak local
/// hardware this app targets. Below the budget, the whole transcript so
/// far is used — no selection needed, and none of its ordering is
/// disturbed.
pub const MAX_LIVE_CONTEXT_WORDS: usize = 3000;

/// One passage from the live transcript that the answer was allowed to
/// use for citation. Single-session, so no session/title/date — just
/// where in *this* recording it came from.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct LiveQaHit {
    pub timestamp: f64,
    pub speaker: String,
    pub text: String,
}

/// An answer plus the passages it was allowed to use.
#[derive(Debug, Clone, Serialize)]
pub struct LiveQaAnswer {
    pub answer: String,
    pub sources: Vec<LiveQaHit>,
}

fn word_count(text: &str) -> usize {
    text.split_whitespace().count()
}

/// Lowercased, de-stopworded question terms, for relevance scoring.
///
/// Shares `archive`'s Indonesian stopword list rather than keeping a
/// second copy that could drift from it.
fn query_terms(question: &str) -> Vec<String> {
    question
        .split(|c: char| !c.is_alphanumeric())
        .filter(|word| word.chars().count() >= 3)
        .filter(|word| !crate::archive::is_stopword(word))
        .map(|word| word.to_lowercase())
        .collect()
}

/// How many of `terms` appear in `segment`'s text.
fn term_overlap(segment: &Segment, terms: &[String]) -> usize {
    if terms.is_empty() {
        return 0;
    }
    let text = segment.text.to_lowercase();
    terms
        .iter()
        .filter(|term| text.contains(term.as_str()))
        .count()
}

/// The segments the answer is allowed to see: the whole transcript when
/// it fits `word_budget`, otherwise the most relevant ones (ties broken
/// by recency), re-ordered chronologically so the model reads them the
/// way the meeting happened.
///
/// Partial (uncommitted) segments and blank text are dropped first, same
/// as `archive::index_session` — a live hypothesis the decoder has not
/// finalised yet is not something to answer a question from.
fn select_context<'a>(
    segments: &'a [Segment],
    question: &str,
    word_budget: usize,
) -> Vec<&'a Segment> {
    let usable: Vec<&Segment> = segments
        .iter()
        .filter(|segment| !segment.is_partial && !segment.text.trim().is_empty())
        .collect();

    let total: usize = usable.iter().map(|segment| word_count(&segment.text)).sum();
    if total <= word_budget {
        return usable;
    }

    let terms = query_terms(question);
    let mut ranked = usable;
    ranked.sort_by(|a, b| {
        let score_a = term_overlap(a, &terms);
        let score_b = term_overlap(b, &terms);
        score_b.cmp(&score_a).then(
            b.timestamp
                .partial_cmp(&a.timestamp)
                .unwrap_or(std::cmp::Ordering::Equal),
        )
    });

    let mut selected = Vec::new();
    let mut words = 0usize;
    for segment in ranked {
        let w = word_count(&segment.text);
        if words + w > word_budget && !selected.is_empty() {
            break;
        }
        selected.push(segment);
        words += w;
    }
    selected.sort_by(|a, b| {
        a.timestamp
            .partial_cmp(&b.timestamp)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    selected
}

/// "12:30" from seconds — the same rendering `archive::ArchiveHit::citation`
/// uses, minus the title/date this single-session answer has no use for.
fn format_timestamp(seconds: f64) -> String {
    let total = seconds.max(0.0) as u64;
    format!("{:02}:{:02}", total / 60, total % 60)
}

/// The question, the retrieved passages, and the rule that the answer
/// must cite them — `archive::build_question_prompt`'s sibling, adapted
/// to one linear transcript instead of ranked FTS hits across sessions.
pub fn build_live_qa_prompt(question: &str, segments: &[&Segment]) -> String {
    let mut prompt = String::from(
        "Anda menjawab pertanyaan tentang rapat yang SEDANG berlangsung, \
         berdasarkan transkrip rapat ini sejauh ini. Gunakan HANYA kutipan \
         di bawah ini; jangan menambahkan pengetahuan dari luar. Setiap \
         pernyataan dalam jawaban WAJIB diakhiri rujukan ke kutipan yang \
         mendukungnya, ditulis sebagai [K1], [K2], dan seterusnya. Jika \
         kutipan yang tersedia tidak cukup untuk menjawab, katakan \
         \"Tidak disebutkan di rapat ini\" dan berhenti di situ.\n\n\
         --- KUTIPAN (TRANSKRIP SEJAUH INI) ---\n",
    );
    for (index, segment) in segments.iter().enumerate() {
        prompt.push_str(&format!(
            "[K{}] {} — {}: {}\n",
            index + 1,
            format_timestamp(segment.timestamp),
            segment.speaker,
            segment.text.trim()
        ));
    }
    prompt.push_str("--- AKHIR KUTIPAN ---\n\nPERTANYAAN: ");
    prompt.push_str(question.trim());
    prompt
}

/// Answers `question` from `segments` — a snapshot of the live
/// transcript taken at the moment the user asked, not re-taken later.
///
/// Refuses outright, without touching the network, when there is no
/// finalised transcript yet: a question asked ten seconds into a meeting
/// has nothing to be answered from, and sending an empty prompt to the
/// model would either error or, worse, invite it to invent something.
pub async fn answer_from_live_transcript(
    config: SummaryConfig,
    question: &str,
    segments: &[Segment],
) -> Result<LiveQaAnswer, TranscribeError> {
    if question.trim().is_empty() {
        return Err(TranscribeError::Summary("Pertanyaan kosong.".into()));
    }
    let context = select_context(segments, question, MAX_LIVE_CONTEXT_WORDS);
    if context.is_empty() {
        return Ok(LiveQaAnswer {
            answer: "Belum ada cukup konteks dari rapat ini untuk menjawab.".to_string(),
            sources: Vec::new(),
        });
    }
    let sources: Vec<LiveQaHit> = context
        .iter()
        .map(|segment| LiveQaHit {
            timestamp: segment.timestamp,
            speaker: segment.speaker.clone(),
            text: segment.text.trim().to_string(),
        })
        .collect();
    let prompt = build_live_qa_prompt(question, &context);
    let answer = crate::summary::ask(config, prompt).await?;
    Ok(LiveQaAnswer { answer, sources })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(text: &str, timestamp: f64, speaker: &str) -> Segment {
        Segment {
            source: "spk".into(),
            speaker: speaker.into(),
            text: text.into(),
            timestamp,
            duration: 4.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
            words: Vec::new(),
        }
    }

    #[tokio::test]
    async fn an_empty_transcript_is_refused_without_touching_the_network() {
        // SummaryConfig::default() has no reachable endpoint; if this
        // reached `summary::ask` it would hang or error on a connection,
        // not return the safe sentence below.
        let answer =
            answer_from_live_transcript(SummaryConfig::default(), "Apa keputusannya?", &[])
                .await
                .unwrap();
        assert_eq!(
            answer.answer,
            "Belum ada cukup konteks dari rapat ini untuk menjawab."
        );
        assert!(answer.sources.is_empty());
    }

    #[tokio::test]
    async fn a_transcript_of_only_partial_segments_is_also_refused() {
        let mut partial = seg("baru mulai", 0.0, "Saya");
        partial.is_partial = true;
        let answer = answer_from_live_transcript(
            SummaryConfig::default(),
            "Apa yang dibahas?",
            &[partial, seg("   ", 5.0, "Saya")],
        )
        .await
        .unwrap();
        assert_eq!(
            answer.answer,
            "Belum ada cukup konteks dari rapat ini untuk menjawab."
        );
    }

    #[tokio::test]
    async fn an_empty_question_is_an_error() {
        let segments = vec![seg("kita bahas anggaran", 0.0, "Saya")];
        let result = answer_from_live_transcript(SummaryConfig::default(), "   ", &segments).await;
        assert!(result.is_err());
    }

    #[test]
    fn a_transcript_under_budget_is_used_whole_and_in_order() {
        let segments = vec![
            seg("satu", 0.0, "A"),
            seg("dua", 5.0, "B"),
            seg("tiga", 10.0, "A"),
        ];
        let context = select_context(&segments, "apa saja", 100);
        assert_eq!(context.len(), 3);
        assert_eq!(context[0].text, "satu");
        assert_eq!(context[2].text, "tiga");
    }

    #[test]
    fn partial_and_blank_segments_never_reach_the_context() {
        let mut partial = seg("sementara", 0.0, "A");
        partial.is_partial = true;
        let segments = vec![partial, seg("   ", 1.0, "A"), seg("nyata", 2.0, "A")];
        let context = select_context(&segments, "apa saja", 100);
        assert_eq!(context.len(), 1);
        assert_eq!(context[0].text, "nyata");
    }

    #[test]
    fn a_long_transcript_is_trimmed_to_the_budget_and_stays_chronological() {
        let segments: Vec<Segment> = (0..50)
            .map(|i| seg("kata kata kata kata kata", i as f64, "A"))
            .collect();
        // Five words per segment; a budget of 12 should keep roughly the
        // first few segments that fit, never all fifty.
        let context = select_context(&segments, "tidak relevan sama sekali", 12);
        assert!(context.len() < segments.len());
        assert!(!context.is_empty());
        for window in context.windows(2) {
            assert!(
                window[0].timestamp <= window[1].timestamp,
                "must stay chronological"
            );
        }
    }

    #[test]
    fn relevant_segments_are_kept_over_irrelevant_ones_when_trimming() {
        let mut segments = Vec::new();
        for i in 0..40 {
            segments.push(seg(
                "pembahasan umum yang tidak terlalu penting hari ini",
                i as f64,
                "A",
            ));
        }
        // One early, clearly relevant segment buried under forty others.
        segments[2] = seg(
            "Keputusan anggaran disepakati naik sepuluh persen",
            2.0,
            "A",
        );
        let context = select_context(&segments, "keputusan anggaran", 30);
        assert!(
            context
                .iter()
                .any(|s| s.text.contains("Keputusan anggaran")),
            "the relevant segment must survive trimming: {context:#?}"
        );
    }

    #[test]
    fn the_prompt_numbers_its_passages_and_forbids_outside_knowledge() {
        let segments = [seg("Pagu naik sepuluh persen.", 30.0, "Peserta 1")];
        let refs: Vec<&Segment> = segments.iter().collect();
        let prompt = build_live_qa_prompt("Berapa kenaikan pagu?", &refs);
        assert!(prompt.contains("[K1] 00:30 — Peserta 1: Pagu naik sepuluh persen."));
        assert!(prompt.contains("HANYA kutipan"));
        assert!(prompt.contains("Tidak disebutkan di rapat ini"));
        assert!(prompt.ends_with("Berapa kenaikan pagu?"));
    }

    #[test]
    fn a_prompt_with_no_passages_still_tells_the_model_to_refuse() {
        let prompt = build_live_qa_prompt("Apa keputusannya?", &[]);
        assert!(prompt.contains("Tidak disebutkan di rapat ini"));
    }
}
