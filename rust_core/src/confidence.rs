//! Confidence-based segment routing.
//!
//! Whisper's per-segment confidence is exposed as `Segment.confidence`
//! (0..1, where 1.0 = high confidence). This module classifies segments
//! into Accept / Flag / Discard so the pipeline can drop obvious
//! hallucinations and surface low-confidence text for review.

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

/// Filter and annotate segments in-place using confidence signals.
/// Returns the count of discarded segments.
///
/// Discards segments whose text carries no real content (fewer than two
/// alphanumeric characters — silence/hallucination patterns) and flags
/// segments whose `confidence` falls below 0.5 so the UI can render them
/// distinctly.
pub fn apply_confidence_routing(segments: &mut Vec<Segment>) -> usize {
    let before = segments.len();
    segments.retain_mut(|seg| {
        let alnum_count = seg.text.chars().filter(|c| c.is_alphanumeric()).count();
        if alnum_count < 2 {
            return false;
        }
        seg.low_confidence = seg.confidence < 0.5;
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
}
