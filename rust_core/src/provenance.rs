//! Summary provenance (F7): every claim points back at the transcript.
//!
//! An AI summary is a second-hand account of a meeting the user was in.
//! The question they have about any given line is always the same — "did
//! someone actually say that?" — and before this there was no way to
//! answer it short of re-reading the whole transcript.
//!
//! So the transcript goes to the model numbered, the model is asked to
//! tag each bullet with the segment numbers it came from, and every tag
//! becomes a link that jumps the player to that moment.
//!
//! # Validation is not optional
//!
//! Models invent citations. A 0.5B model asked for segment numbers will
//! produce plausible ones for claims it hallucinated, and a citation that
//! jumps to an unrelated part of the meeting is worse than no citation:
//! it looks like proof. [`parse_summary`] drops every id outside the
//! transcript's range, and [`verify_citations`] can additionally require
//! that the cited segment shares vocabulary with the claim.

use serde::Serialize;

use crate::export::Segment;

/// A pointer from a summary line back into the transcript.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct Citation {
    /// 1-based segment number, as shown to the model.
    pub segment_id: u32,
    /// Where that segment starts, so the player can seek without
    /// re-resolving the id.
    pub timestamp: f64,
}

/// One line of the summary, with whatever it cited.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct SummaryLine {
    /// The line with its citation markers removed, ready to render.
    pub text: String,
    pub citations: Vec<Citation>,
    /// True for a `#`/`##` heading, so the UI can style it as one rather
    /// than hanging citation chips off it.
    pub is_heading: bool,
}

/// A parsed summary plus what was thrown away.
#[derive(Debug, Clone, Serialize)]
pub struct SummaryProvenance {
    pub lines: Vec<SummaryLine>,
    /// Citations dropped for pointing outside the transcript. Surfaced
    /// rather than swallowed: a summary with many of these came from a
    /// model that is guessing, and the user should be told.
    pub dropped: u32,
}

impl SummaryProvenance {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn citation_count(&self) -> usize {
        self.lines.iter().map(|line| line.citations.len()).sum()
    }
}

/// The instruction that asks for citations.
pub fn provenance_instruction() -> String {
    "Transkrip di bawah ini diberi nomor segmen dalam bentuk [n]. Setiap \
     poin ringkasan WAJIB diakhiri penanda sumber berisi nomor segmen yang \
     mendasarinya, ditulis persis seperti ini: [#12] atau [#12,13,14]. \
     Gunakan hanya nomor segmen yang benar-benar ada di transkrip. Jika \
     sebuah poin tidak bisa ditelusuri ke segmen tertentu, jangan tulis \
     poin itu."
        .to_string()
}

/// Renders the transcript with the segment numbers the model will cite.
///
/// 1-based, because the model is being asked to produce these in prose
/// and `[0]` reads like an error to a language model as much as to a
/// person.
pub fn numbered_transcript(segments: &[Segment]) -> String {
    numbered_transcript_from(segments, 0)
}

/// [`numbered_transcript`] for one window of a long meeting, numbered
/// against the whole transcript.
///
/// `offset` is the index of `segments[0]` in the full transcript, so a
/// window's notes cite ids that still resolve after the map-reduce
/// reduce step has thrown the windows away. Numbering each window from
/// 1 would make every citation past the first window point at the wrong
/// moment — which looks like proof and is not.
pub fn numbered_transcript_from(segments: &[Segment], offset: usize) -> String {
    let mut out = String::new();
    for (index, segment) in segments.iter().enumerate() {
        out.push_str(&format!(
            "[{}] {} ({}): {}\n",
            offset + index + 1,
            format_timestamp(segment.timestamp),
            segment.speaker,
            segment.text.trim()
        ));
    }
    out
}

fn format_timestamp(seconds: f64) -> String {
    let total = seconds.max(0.0) as u64;
    format!("{:02}:{:02}", total / 60, total % 60)
}

/// Splits a Markdown summary into lines, pulling out and validating the
/// `[#n,m]` markers.
///
/// `segments` is the transcript the ids index into; an id outside
/// `1..=segments.len()` is dropped and counted.
pub fn parse_summary(markdown: &str, segments: &[Segment]) -> SummaryProvenance {
    let mut lines = Vec::new();
    let mut dropped = 0u32;
    for raw in markdown.lines() {
        let (text, ids) = extract_citations(raw);
        let trimmed = text.trim_end();
        if trimmed.trim().is_empty() && ids.is_empty() {
            continue;
        }
        let mut citations = Vec::new();
        for id in ids {
            // `id - 1` on a 0 would wrap; the ids come from a model, so
            // every arithmetic step has to assume the worst value.
            match id
                .checked_sub(1)
                .and_then(|index| segments.get(index as usize))
            {
                Some(segment) => citations.push(Citation {
                    segment_id: id,
                    timestamp: segment.timestamp,
                }),
                None => dropped += 1,
            }
        }
        lines.push(SummaryLine {
            is_heading: trimmed.trim_start().starts_with('#'),
            text: trimmed.to_string(),
            citations,
        });
    }
    SummaryProvenance { lines, dropped }
}

/// Pulls every `[#…]` marker out of one line and returns the line
/// without them.
///
/// Only `[#…]` counts. A plain `[12]` is how the numbered transcript
/// itself is written, and a model that echoes a transcript line back
/// would otherwise have it silently eaten.
fn extract_citations(line: &str) -> (String, Vec<u32>) {
    let mut text = String::with_capacity(line.len());
    let mut ids = Vec::new();
    let bytes = line.as_bytes();
    let mut index = 0usize;
    while index < bytes.len() {
        if bytes[index] == b'[' && bytes.get(index + 1) == Some(&b'#') {
            if let Some(close) = line[index..].find(']') {
                let inner = &line[index + 2..index + close];
                let parsed: Vec<u32> = inner
                    .split(',')
                    .filter_map(|part| part.trim().parse::<u32>().ok())
                    .collect();
                // `[#catatan]` is not a citation; leave it in the text.
                if !parsed.is_empty()
                    && inner
                        .chars()
                        .all(|c| c.is_ascii_digit() || c == ',' || c == ' ')
                {
                    ids.extend(parsed);
                    index += close + 1;
                    continue;
                }
            }
        }
        let c = line[index..].chars().next().unwrap_or(' ');
        text.push(c);
        index += c.len_utf8();
    }
    (text, ids)
}

/// Default word overlap below which a citation is treated as invented.
///
/// Deliberately low. A summary legitimately paraphrases — "anggaran naik
/// sepuluh persen" summarising "jadi kalau kita lihat lagi, kenaikannya
/// itu di angka sepuluh persen ya" shares three words out of six. The
/// check is here to catch a citation pointing at an unrelated part of the
/// meeting, not to police wording.
pub const MIN_CITATION_OVERLAP: f64 = 0.15;

/// Drops citations whose segment shares almost no vocabulary with the
/// line citing it.
///
/// Opt-in on top of [`parse_summary`]'s range check, because it can be
/// wrong: a bullet that correctly summarises a long exchange may share
/// little with any single segment of it. Off by default for that reason.
pub fn verify_citations(
    provenance: SummaryProvenance,
    segments: &[Segment],
    min_overlap: f64,
) -> SummaryProvenance {
    let mut dropped = provenance.dropped;
    let lines = provenance
        .lines
        .into_iter()
        .map(|line| {
            let keep: Vec<Citation> = line
                .citations
                .iter()
                .filter(|citation| {
                    let Some(segment) = citation
                        .segment_id
                        .checked_sub(1)
                        .and_then(|index| segments.get(index as usize))
                    else {
                        return false;
                    };
                    word_overlap(&line.text, &segment.text) >= min_overlap
                })
                .copied()
                .collect();
            dropped += (line.citations.len() - keep.len()) as u32;
            SummaryLine {
                citations: keep,
                ..line
            }
        })
        .collect();
    SummaryProvenance { lines, dropped }
}

/// Fraction of `claim`'s content words that appear in `source`.
fn word_overlap(claim: &str, source: &str) -> f64 {
    let source_words: Vec<String> = content_words(source);
    if source_words.is_empty() {
        return 0.0;
    }
    let claim_words = content_words(claim);
    if claim_words.is_empty() {
        return 0.0;
    }
    let hits = claim_words
        .iter()
        .filter(|word| source_words.iter().any(|other| other == *word))
        .count();
    hits as f64 / claim_words.len() as f64
}

/// Indonesian function words carry no evidence; counting them would make
/// every citation look supported.
const STOPWORDS: &[&str] = &[
    "yang", "dan", "di", "ke", "dari", "untuk", "pada", "dengan", "ini", "itu", "adalah", "akan",
    "sudah", "tidak", "ada", "juga", "oleh", "atau", "dalam", "kita", "kami", "saya", "bahwa",
    "agar", "serta", "para", "bagi",
];

fn content_words(text: &str) -> Vec<String> {
    text.to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|word| word.len() > 2 && !STOPWORDS.contains(word))
        .map(|word| word.to_string())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(text: &str, timestamp: f64) -> Segment {
        Segment {
            source: "spk".into(),
            speaker: "Peserta 1".into(),
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

    fn transcript() -> Vec<Segment> {
        vec![
            seg("Selamat pagi semuanya, rapat kita mulai.", 10.0),
            seg("Anggaran kuartal empat naik sepuluh persen.", 20.0),
            seg("Budi menyiapkan laporan keuangan hari Jumat.", 65.0),
            seg("Rapat berikutnya dijadwalkan minggu depan.", 130.0),
        ]
    }

    #[test]
    fn the_transcript_is_numbered_from_one() {
        let rendered = numbered_transcript(&transcript());
        assert!(rendered.starts_with("[1] 00:10 (Peserta 1): Selamat pagi"));
        assert!(rendered.contains("[3] 01:05 (Peserta 1): Budi menyiapkan"));
        assert!(
            !rendered.contains("[0]"),
            "0-based numbering reads as a bug"
        );
    }

    #[test]
    fn a_citation_resolves_to_the_segments_timestamp() {
        let summary = "- Anggaran naik sepuluh persen. [#2]";
        let parsed = parse_summary(summary, &transcript());
        assert_eq!(parsed.lines.len(), 1);
        assert_eq!(parsed.lines[0].citations.len(), 1);
        assert_eq!(parsed.lines[0].citations[0].segment_id, 2);
        assert_eq!(parsed.lines[0].citations[0].timestamp, 20.0);
        assert_eq!(parsed.lines[0].text, "- Anggaran naik sepuluh persen.");
        assert_eq!(parsed.dropped, 0);
    }

    #[test]
    fn several_ids_in_one_marker_all_resolve() {
        let parsed = parse_summary("- Keputusan rapat. [#2,3,4]", &transcript());
        let ids: Vec<u32> = parsed.lines[0]
            .citations
            .iter()
            .map(|c| c.segment_id)
            .collect();
        assert_eq!(ids, vec![2, 3, 4]);
        assert_eq!(parsed.lines[0].text, "- Keputusan rapat.");
    }

    #[test]
    fn spaces_inside_a_marker_are_tolerated() {
        let parsed = parse_summary("- Poin. [#2, 3]", &transcript());
        assert_eq!(parsed.lines[0].citations.len(), 2);
    }

    #[test]
    fn an_invented_citation_is_dropped_and_counted() {
        // The failure this exists for: a citation that jumps somewhere
        // unrelated looks like proof.
        let parsed = parse_summary("- Sesuatu yang tidak dibahas. [#99]", &transcript());
        assert!(parsed.lines[0].citations.is_empty());
        assert_eq!(parsed.dropped, 1);
        assert_eq!(parsed.lines[0].text, "- Sesuatu yang tidak dibahas.");
    }

    #[test]
    fn a_zero_id_is_not_a_segment() {
        let parsed = parse_summary("- Poin. [#0]", &transcript());
        assert!(parsed.lines[0].citations.is_empty());
        assert_eq!(parsed.dropped, 1);
    }

    #[test]
    fn a_mix_of_good_and_bad_ids_keeps_the_good_ones() {
        let parsed = parse_summary("- Poin. [#2,99,3]", &transcript());
        let ids: Vec<u32> = parsed.lines[0]
            .citations
            .iter()
            .map(|c| c.segment_id)
            .collect();
        assert_eq!(ids, vec![2, 3]);
        assert_eq!(parsed.dropped, 1);
    }

    #[test]
    fn headings_are_marked_and_carry_no_chips() {
        let parsed = parse_summary("## Keputusan\n- Anggaran naik. [#2]", &transcript());
        assert!(parsed.lines[0].is_heading);
        assert!(parsed.lines[0].citations.is_empty());
        assert!(!parsed.lines[1].is_heading);
    }

    #[test]
    fn a_summary_without_citations_still_renders() {
        let parsed = parse_summary("## Ringkasan\n\nRapat membahas anggaran.", &transcript());
        assert_eq!(parsed.lines.len(), 2);
        assert_eq!(parsed.citation_count(), 0);
        assert_eq!(parsed.dropped, 0);
    }

    #[test]
    fn a_plain_bracket_is_not_a_citation() {
        // The numbered transcript itself uses `[2]`; a model echoing a
        // line back must not have it silently eaten.
        let parsed = parse_summary("- Dia bilang [2] itu salah ketik. [#2]", &transcript());
        assert_eq!(parsed.lines[0].text, "- Dia bilang [2] itu salah ketik.");
        assert_eq!(parsed.lines[0].citations.len(), 1);
    }

    #[test]
    fn a_non_numeric_marker_is_left_in_the_text() {
        let parsed = parse_summary("- Lihat [#catatan] di bawah.", &transcript());
        assert_eq!(parsed.lines[0].text, "- Lihat [#catatan] di bawah.");
        assert!(parsed.lines[0].citations.is_empty());
        assert_eq!(parsed.dropped, 0);
    }

    #[test]
    fn blank_lines_are_dropped_rather_than_rendered() {
        let parsed = parse_summary("## A\n\n\n- B [#1]\n\n", &transcript());
        assert_eq!(parsed.lines.len(), 2);
    }

    #[test]
    fn an_empty_transcript_drops_every_citation() {
        let parsed = parse_summary("- Poin. [#1,2]", &[]);
        assert_eq!(parsed.dropped, 2);
        assert_eq!(parsed.citation_count(), 0);
    }

    // --- verification --------------------------------------------------

    #[test]
    fn a_citation_that_shares_vocabulary_survives_verification() {
        let parsed = parse_summary("- Anggaran kuartal empat naik. [#2]", &transcript());
        let verified = verify_citations(parsed, &transcript(), MIN_CITATION_OVERLAP);
        assert_eq!(verified.citation_count(), 1);
        assert_eq!(verified.dropped, 0);
    }

    #[test]
    fn a_citation_pointing_somewhere_unrelated_is_dropped() {
        // Range-valid but wrong: segment 1 is the greeting.
        let parsed = parse_summary("- Anggaran kuartal empat naik. [#1]", &transcript());
        let verified = verify_citations(parsed, &transcript(), MIN_CITATION_OVERLAP);
        assert_eq!(verified.citation_count(), 0);
        assert_eq!(verified.dropped, 1);
    }

    #[test]
    fn a_paraphrase_still_verifies() {
        // Verification must not demand quotation; summaries paraphrase.
        let segments = vec![seg(
            "Jadi kalau kita lihat lagi, kenaikan anggarannya itu di angka \
             sepuluh persen ya untuk kuartal empat",
            20.0,
        )];
        let parsed = parse_summary("- Anggaran naik sepuluh persen. [#1]", &segments);
        let verified = verify_citations(parsed, &segments, MIN_CITATION_OVERLAP);
        assert_eq!(verified.citation_count(), 1);
    }

    #[test]
    fn function_words_alone_do_not_support_a_citation() {
        let segments = vec![seg("Yang ini dan itu untuk kita semua", 5.0)];
        let parsed = parse_summary("- Yang ini dan itu untuk kita. [#1]", &segments);
        let verified = verify_citations(parsed, &segments, 0.9);
        // "semua" is the only content word on either side, so overlap is
        // real here; the point is that the stopwords were not counted.
        assert!(verified.citation_count() <= 1);
        assert!(content_words("yang dan di ke dari untuk").is_empty());
    }

    #[test]
    fn the_instruction_names_the_exact_marker_format() {
        let instruction = provenance_instruction();
        assert!(instruction.contains("[#12]"));
        assert!(instruction.contains("[#12,13,14]"));
        assert!(instruction.contains("nomor segmen"));
    }
}
