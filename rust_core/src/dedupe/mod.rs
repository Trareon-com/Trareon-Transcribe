//! Echo-dedupe: when mic and speaker are both live (Online mode), the mic
//! often re-captures speaker audio through the room/headphones. Compare
//! MIC vs SPK text within a 5s window; drop the later one if >80% similar.

use crate::export::Segment;

pub const DEDUPE_WINDOW_SECS: f64 = 5.0;
pub const SIMILARITY_THRESHOLD: f64 = 0.8;

/// Returns true if `candidate` should be dropped as an echo of something
/// already present in `existing` (source differs, timestamps within window,
/// text similarity above threshold).
pub fn is_echo(candidate: &Segment, existing: &[Segment]) -> bool {
    for prior in existing.iter().rev() {
        let time_diff = candidate.timestamp - prior.timestamp;
        if time_diff > DEDUPE_WINDOW_SECS {
            break;
        }
        if prior.source != candidate.source
            && time_diff.abs() <= DEDUPE_WINDOW_SECS
            && text_similarity(&candidate.text, &prior.text) >= SIMILARITY_THRESHOLD
        {
            return true;
        }
    }
    false
}

/// Filter a batch, keeping the first occurrence and dropping later echoes.
pub fn dedupe_segments(segments: Vec<Segment>) -> Vec<Segment> {
    let mut kept: Vec<Segment> = Vec::with_capacity(segments.len());
    for seg in segments {
        if !is_echo(&seg, &kept) {
            kept.push(seg);
        }
    }
    kept
}

/// Normalized similarity in [0.0, 1.0] using Levenshtein distance via `strsim`.
fn text_similarity(a: &str, b: &str) -> f64 {
    let a = a.trim().to_lowercase();
    let b = b.trim().to_lowercase();
    if a.is_empty() && b.is_empty() {
        return 1.0;
    }
    if a.is_empty() || b.is_empty() {
        return 0.0;
    }
    let dist = strsim::levenshtein(&a, &b) as f64;
    let max_len = a.chars().count().max(b.chars().count()) as f64;
    1.0 - (dist / max_len)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(source: &str, text: &str, ts: f64) -> Segment {
        Segment {
            source: source.to_string(),
            speaker: source.to_uppercase(),
            text: text.to_string(),
            timestamp: ts,
            duration: 1.0,
            language: "id".to_string(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
        }
    }

    #[test]
    fn exact_duplicate_across_sources_is_echo() {
        let mic = seg("mic", "halo semua selamat pagi", 10.0);
        let spk = seg("spk", "halo semua selamat pagi", 11.0);
        assert!(is_echo(&spk, &[mic]));
    }

    #[test]
    fn different_text_is_not_echo() {
        let mic = seg("mic", "halo semua", 10.0);
        let spk = seg("spk", "topik rapat hari ini adalah budget", 11.0);
        assert!(!is_echo(&spk, &[mic]));
    }

    #[test]
    fn outside_time_window_is_not_echo() {
        let mic = seg("mic", "halo semua selamat pagi", 0.0);
        let spk = seg("spk", "halo semua selamat pagi", 10.0);
        assert!(!is_echo(&spk, &[mic]));
    }

    #[test]
    fn same_source_never_deduped() {
        let mic1 = seg("mic", "halo semua selamat pagi", 10.0);
        let mic2 = seg("mic", "halo semua selamat pagi", 10.5);
        assert!(!is_echo(&mic2, &[mic1]));
    }

    #[test]
    fn partial_similarity_above_threshold_is_echo() {
        let mic = seg("mic", "selamat pagi semuanya di rapat ini", 5.0);
        let spk = seg("spk", "selamat pagi semuanya di rapat ini,", 5.2);
        assert!(is_echo(&spk, &[mic]));
    }

    #[test]
    fn dedupe_segments_keeps_first_drops_echo() {
        let segments = vec![
            seg("mic", "halo semua selamat pagi", 1.0),
            seg("spk", "halo semua selamat pagi", 1.5),
            seg("mic", "lanjut ke topik berikutnya", 6.0),
        ];
        let out = dedupe_segments(segments);
        assert_eq!(out.len(), 2);
        assert_eq!(out[0].source, "mic");
        assert_eq!(out[1].text, "lanjut ke topik berikutnya");
    }
}
