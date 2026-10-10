//! Confidence-based segment routing.
//!
//! Whisper's per-segment confidence is exposed as `Segment.confidence`
//! (0..1, where 1.0 = high confidence). This module classifies segments
//! into Accept / Flag / Discard so the pipeline can drop obvious
//! hallucinations and surface low-confidence text for review.

use std::io::Write;

use flate2::write::GzEncoder;
use flate2::Compression;

use crate::export::Segment;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SegmentRoute {
    Accept,
    Flag,
    Discard,
}

/// Route a segment based on Whisper's per-segment confidence signals.
///
/// Thresholds (tuned for Indonesian voice dictation):
///   - Discard: no_speech > 0.6 && avg_logprob < -1.0  (likely silence/hallucination)
///   - Discard: compression_ratio > 2.4                   (excessive repetition)
///   - Flag:    avg_logprob < -0.5                        (low confidence, surface anyway)
///   - Accept:  otherwise
pub fn route_segment(
    _text: &str,
    _no_speech_prob: f32,
    _avg_logprob: f32,
    _compression_ratio: f32,
) -> SegmentRoute {
    if _no_speech_prob > 0.6 && _avg_logprob < -1.0 {
        return SegmentRoute::Discard;
    }
    if _compression_ratio > 2.4 {
        return SegmentRoute::Discard;
    }
    if _avg_logprob < -0.5 {
        return SegmentRoute::Flag;
    }
    SegmentRoute::Accept
}

/// Confidence below which a segment is flagged `low_confidence` for the
/// "Tinjau" review filter rather than shown as plain fact.
///
/// 0.70, not the 0.5 this used to be: a real session measured a segment
/// ("di video selanjutnya.", confidence 0.61) that is itself a hallucinated
/// fragment but sat comfortably above 0.5, so it reached the transcript
/// with no visible warning. 0.70 is still well clear of confident real
/// speech (observed 0.85–0.98 on `rapat_id.mp3`) while catching that case
/// and the honest-but-unsure dictation this flag also exists for.
pub const LOW_CONFIDENCE_THRESHOLD: f32 = 0.70;

/// Mean token log-probability below which a segment is flagged regardless
/// of its `confidence` figure — a second, independent signal so a segment
/// that is merely probable but was spoken under heavy decoding uncertainty
/// still gets the same review flag.
pub const LOW_CONFIDENCE_LOGPROB_THRESHOLD: f32 = -0.5;

/// gzip compression ratio above which text is treated as degenerate
/// repetition rather than language (B2) — matches whisper.cpp CLI's own
/// `compression_ratio_threshold` default, so this is the same signal
/// OpenAI's reference decoder uses, not a new number invented for this
/// codebase.
pub const COMPRESSION_RATIO_THRESHOLD: f32 = 2.4;

/// `raw_len / gzip_len` of `text`'s UTF-8 bytes. Ordinary language
/// (including Indonesian) typically compresses to 1.5–2x; a decoder stuck
/// looping on one token or phrase compresses far better than that, which
/// is what [`COMPRESSION_RATIO_THRESHOLD`] is set to catch. Texts too
/// short to compress meaningfully (under 8 bytes) return 1.0 — never a
/// false "loop".
pub fn compression_ratio(text: &str) -> f32 {
    let raw = text.as_bytes();
    if raw.len() < 8 {
        return 1.0;
    }
    let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
    if encoder.write_all(raw).is_err() {
        return 1.0;
    }
    let Ok(compressed) = encoder.finish() else {
        return 1.0;
    };
    if compressed.is_empty() {
        return 1.0;
    }
    raw.len() as f32 / compressed.len() as f32
}

/// Filter and annotate segments in-place using confidence signals.
/// Returns the count of discarded segments.
///
/// Discards segments whose text carries no real content (fewer than two
/// alphanumeric characters — silence/hallucination patterns) or whose text
/// compresses implausibly well ([`COMPRESSION_RATIO_THRESHOLD`], B2 — a
/// second, text-shape signal independent of [`crate::hallucination`]'s
/// explicit loop detector), and flags segments whose `confidence` or
/// `avg_log_prob` falls below the review thresholds so the UI can render
/// them distinctly and the "Tinjau" filter can pick them up.
pub fn apply_confidence_routing(segments: &mut Vec<Segment>) -> usize {
    let before = segments.len();
    segments.retain_mut(|seg| {
        let alnum_count = seg.text.chars().filter(|c| c.is_alphanumeric()).count();
        if alnum_count < 2 {
            return false;
        }
        if compression_ratio(&seg.text) > COMPRESSION_RATIO_THRESHOLD {
            return false;
        }
        seg.low_confidence = seg.low_confidence
            || seg.confidence < LOW_CONFIDENCE_THRESHOLD
            || seg.avg_log_prob < LOW_CONFIDENCE_LOGPROB_THRESHOLD;
        true
    });
    before - segments.len()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_segment(text: &str) -> Segment {
        Segment {
            source: "MIC".into(),
            speaker: "MIC".into(),
            text: text.into(),
            timestamp: 0.0,
            duration: 5.0,
            language: "id".into(),
            confidence: 1.0,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
            words: Vec::new(),
        }
    }

    #[test]
    fn normal_text_accepted() {
        let seg = make_segment("halo dunia ini adalah test");
        assert_eq!(
            route_segment(&seg.text, 0.1, -0.2, 1.2),
            SegmentRoute::Accept
        );
        let mut v = vec![seg.clone()];
        apply_confidence_routing(&mut v);
        assert!(!v[0].low_confidence);
    }

    #[test]
    fn high_no_speech_and_low_logprob_discarded() {
        let seg = make_segment("....");
        assert_eq!(
            route_segment(&seg.text, 0.8, -1.5, 1.0),
            SegmentRoute::Discard
        );
    }

    #[test]
    fn excessive_compression_discarded() {
        let seg = make_segment("uh uh uh uh uh uh uh uh");
        assert_eq!(
            route_segment(&seg.text, 0.1, -0.2, 3.0),
            SegmentRoute::Discard
        );
    }

    #[test]
    fn low_avg_logprob_flagged() {
        let seg = make_segment("something unclear");
        assert_eq!(route_segment(&seg.text, 0.1, -0.7, 1.2), SegmentRoute::Flag);
    }

    #[test]
    fn apply_confidence_routing_removes_discarded() {
        let mut segs = vec![
            make_segment("halo"),
            make_segment("...."),
            make_segment("dunia"),
        ];
        let dropped = apply_confidence_routing(&mut segs);
        assert_eq!(dropped, 1);
        assert_eq!(segs.len(), 2);
        assert_eq!(segs[0].text, "halo");
        assert_eq!(segs[1].text, "dunia");
    }

    #[test]
    fn apply_confidence_routing_flags_low_confidence() {
        let mut seg = make_segment("something unclear");
        seg.confidence = 0.4;
        let mut segs = vec![seg];
        apply_confidence_routing(&mut segs);
        assert!(segs[0].low_confidence);
    }

    #[test]
    fn apply_confidence_routing_keeps_high_confidence() {
        let mut seg = make_segment("kalimat jelas sekali");
        seg.confidence = 0.9;
        let mut segs = vec![seg];
        apply_confidence_routing(&mut segs);
        assert!(!segs[0].low_confidence);
    }

    #[test]
    fn the_061_confidence_fragment_is_flagged() {
        // The exact figure measured on a real macOS session: "di video
        // selanjutnya." came back at confidence 0.61, which the old 0.5
        // threshold let through with no review flag at all.
        let mut seg = make_segment("di video selanjutnya.");
        seg.confidence = 0.61;
        let mut segs = vec![seg];
        apply_confidence_routing(&mut segs);
        assert!(segs[0].low_confidence);
    }

    #[test]
    fn low_avg_log_prob_flags_even_with_decent_confidence() {
        let mut seg = make_segment("kalimat agak ragu-ragu");
        seg.confidence = 0.8;
        seg.avg_log_prob = -0.6;
        let mut segs = vec![seg];
        apply_confidence_routing(&mut segs);
        assert!(segs[0].low_confidence);
    }

    #[test]
    fn a_repeated_token_compresses_above_threshold() {
        let ratio = compression_ratio(&"uh ".repeat(40));
        assert!(
            ratio > COMPRESSION_RATIO_THRESHOLD,
            "expected a loop to compress well past {COMPRESSION_RATIO_THRESHOLD}, got {ratio}"
        );
    }

    #[test]
    fn real_indonesian_speech_compresses_under_threshold() {
        let ratio = compression_ratio(
            "Baik, kita lanjut ke agenda berikutnya yaitu anggaran triwulan \
             ketiga dan evaluasi program kerja bagian keuangan.",
        );
        assert!(
            ratio < COMPRESSION_RATIO_THRESHOLD,
            "expected real speech well under {COMPRESSION_RATIO_THRESHOLD}, got {ratio}"
        );
    }

    #[test]
    fn a_short_text_never_trips_the_compression_signal() {
        // Too short for gzip's own framing overhead to tell the difference.
        assert_eq!(compression_ratio("ya"), 1.0);
    }

    #[test]
    fn apply_confidence_routing_discards_an_implausibly_compressible_segment() {
        let mut segs = vec![make_segment(&"uh ".repeat(40))];
        let dropped = apply_confidence_routing(&mut segs);
        assert_eq!(dropped, 1);
        assert!(segs.is_empty());
    }

    #[test]
    fn apply_confidence_routing_keeps_real_speech_regardless_of_compression() {
        let mut segs = vec![make_segment(
            "Selamat pagi semuanya, terima kasih telah hadir di rapat ini pagi ini.",
        )];
        apply_confidence_routing(&mut segs);
        assert_eq!(segs.len(), 1);
    }
}
