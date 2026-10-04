//! Transcript coverage: which seconds of a recording the transcript
//! actually accounts for, and which it does not.
//!
//! # Why this exists
//!
//! The live worker is a single thread doing Whisper inference on a channel
//! of captured audio. When the chosen model runs slower than real time —
//! `large-v3-turbo-q5` on a two-core laptop measures RTF ≈ 0.05 — the
//! channel grows without bound and the worker never catches up. At Stop the
//! worker is told to exit and everything still queued is gone.
//!
//! Measured on a real 6-minute session recorded by this app: the speaker
//! track contained speech at 0-30 s and again at 150-180 s, and the live
//! transcript held two segments, both from the first 8 seconds. The audio
//! was intact; re-transcribing the same WAV from disk recovered both
//! occurrences. Nothing in the app noticed the other 5 minutes 52 seconds
//! had never been looked at.
//!
//! This module is the bookkeeping that makes that noticeable: given the
//! segments and the recording's duration, it reports what fraction is
//! covered and hands back the exact ranges that are not, so the post-stop
//! pass can transcribe those and only those.
//!
//! [`merge_by_timestamp`] then folds the recovered segments back in. Its
//! one subtlety: the dedupe must be *local*. A meeting where the same
//! sentence is said at 00:10 and again at 02:30 is ordinary; dropping the
//! second because it reads like the first would be the very data loss this
//! module exists to undo.

use crate::export::Segment;

/// A half-open span of the recording, in seconds from its start.
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct TimeRange {
    pub start: f64,
    pub end: f64,
}

impl TimeRange {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn new(start: f64, end: f64) -> Self {
        Self { start, end }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn duration(&self) -> f64 {
        (self.end - self.start).max(0.0)
    }
}

/// What a transcript accounts for, and what it misses.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CoverageReport {
    /// Seconds of the recording covered by at least one segment.
    pub covered_secs: f64,
    /// Length of the recording.
    pub total_secs: f64,
    /// `covered_secs / total_secs`, clamped to `0.0..=1.0`. `1.0` when the
    /// recording has no length (nothing can be missing from nothing).
    pub fraction: f64,
    /// Stretches with no segment over them, longest-lived first in time
    /// order. Only gaps of at least `min_gap_secs` are reported.
    pub gaps: Vec<TimeRange>,
    /// `gaps` summed.
    pub missing_secs: f64,
}

impl CoverageReport {
    /// Whether the transcript is complete enough to call the session
    /// finished. Deliberately strict: a session is not "selesai" while any
    /// reportable gap remains.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn is_complete(&self) -> bool {
        self.gaps.is_empty()
    }
}

/// Shortest gap worth a second transcription pass.
///
/// Below this a "gap" is just the space between two utterances: Whisper
/// emits segments with gaps of a second or two between them all the time,
/// and chasing those would re-transcribe the whole file forever.
pub const MIN_GAP_SECS: f64 = 5.0;

/// Slack added around each gap before transcribing it, so a sentence that
/// starts just before the gap is not clipped mid-word. Whisper needs
/// context either side to segment correctly.
pub const GAP_PADDING_SECS: f64 = 1.0;

/// The spans a set of segments covers, merged and in time order.
pub fn covered_ranges(segments: &[Segment]) -> Vec<TimeRange> {
    let mut ranges: Vec<TimeRange> = segments
        .iter()
        .filter(|segment| !segment.is_partial)
        .map(|segment| {
            let start = segment.timestamp.max(0.0);
            // A zero-duration segment still proves that instant was looked
            // at; give it the smallest span that reads as covered.
            let end = (segment.timestamp + segment.duration.max(0.0)).max(start);
            TimeRange::new(start, end)
        })
        .collect();
    merge_ranges(&mut ranges);
    ranges
}

/// Sorts and coalesces overlapping or touching ranges in place.
fn merge_ranges(ranges: &mut Vec<TimeRange>) {
    ranges.sort_by(|a, b| a.start.total_cmp(&b.start));
    let mut merged: Vec<TimeRange> = Vec::with_capacity(ranges.len());
    for range in ranges.iter() {
        match merged.last_mut() {
            Some(last) if range.start <= last.end => {
                last.end = last.end.max(range.end);
            }
            _ => merged.push(*range),
        }
    }
    *ranges = merged;
}

/// The stretches of `0.0..total_secs` that `covered` does not reach, each
/// at least `min_gap_secs` long.
pub fn gaps_in(covered: &[TimeRange], total_secs: f64, min_gap_secs: f64) -> Vec<TimeRange> {
    if total_secs <= 0.0 {
        return Vec::new();
    }
    let mut gaps = Vec::new();
    let mut cursor = 0.0f64;
    for range in covered {
        if range.start > cursor {
            let gap = TimeRange::new(cursor, range.start.min(total_secs));
            if gap.duration() >= min_gap_secs {
                gaps.push(gap);
            }
        }
        cursor = cursor.max(range.end);
        if cursor >= total_secs {
            break;
        }
    }
    if cursor < total_secs {
        let gap = TimeRange::new(cursor, total_secs);
        if gap.duration() >= min_gap_secs {
            gaps.push(gap);
        }
    }
    gaps
}

/// Full coverage report for `segments` over a recording of `total_secs`.
pub fn report(segments: &[Segment], total_secs: f64, min_gap_secs: f64) -> CoverageReport {
    let covered = covered_ranges(segments);
    // `+ 0.0` normalises the negative zero an empty `f64` sum produces,
    // which otherwise reaches the UI as "-0 detik tertranskrip".
    let covered_secs: f64 = covered
        .iter()
        .map(|range| {
            let end = range.end.min(total_secs.max(0.0));
            (end - range.start).max(0.0)
        })
        .sum::<f64>()
        + 0.0;
    let gaps = gaps_in(&covered, total_secs, min_gap_secs);
    let missing_secs = gaps.iter().map(TimeRange::duration).sum::<f64>() + 0.0;
    let fraction = if total_secs <= 0.0 {
        1.0
    } else {
        (covered_secs / total_secs).clamp(0.0, 1.0)
    };
    CoverageReport {
        covered_secs,
        total_secs,
        fraction,
        gaps,
        missing_secs,
    }
}

/// Widens each gap by [`GAP_PADDING_SECS`] on both sides and re-merges, so
/// a sentence straddling a gap boundary is transcribed whole.
pub fn padded_gaps(gaps: &[TimeRange], total_secs: f64) -> Vec<TimeRange> {
    let mut padded: Vec<TimeRange> = gaps
        .iter()
        .map(|gap| {
            TimeRange::new(
                (gap.start - GAP_PADDING_SECS).max(0.0),
                (gap.end + GAP_PADDING_SECS).min(total_secs),
            )
        })
        .collect();
    merge_ranges(&mut padded);
    padded
}

/// Default tolerance for [`merge_by_timestamp`]: two segments whose starts
/// are within this many seconds *and* whose text matches are the same
/// utterance seen twice, once by the live pass and once by the completion
/// pass. Whisper's chunk boundaries move by up to a second between runs.
pub const MERGE_TOLERANCE_SECS: f64 = 2.0;

/// Text similarity above which two near-simultaneous segments are the same
/// utterance. Shares the echo-dedupe threshold deliberately — the question
/// being asked is the same one.
pub const MERGE_SIMILARITY: f64 = 0.8;

/// Folds `incoming` into `existing`, keeping everything already there.
///
/// `existing` wins every conflict: it holds the live transcript, which the
/// user may have edited, renamed speakers in, or bookmarked. An incoming
/// segment is dropped only when an existing one starts within
/// `tolerance_secs` of it *and* says substantially the same thing.
///
/// The window is what makes a repeated sentence safe. "Baik, kita mulai"
/// at 00:10 and again at 02:30 are 140 seconds apart, so the second is
/// never compared against the first.
pub fn merge_by_timestamp(
    existing: Vec<Segment>,
    incoming: Vec<Segment>,
    tolerance_secs: f64,
) -> Vec<Segment> {
    if incoming.is_empty() {
        return existing;
    }
    let mut merged = existing;
    merged.sort_by(|a, b| a.timestamp.total_cmp(&b.timestamp));

    for candidate in incoming {
        if !is_duplicate_of(&candidate, &merged, tolerance_secs) {
            let at = merged.partition_point(|s| s.timestamp <= candidate.timestamp);
            merged.insert(at, candidate);
        }
    }
    merged
}

/// Whether `candidate` restates something already in `existing` at
/// essentially the same moment. `existing` must be sorted by timestamp.
fn is_duplicate_of(candidate: &Segment, existing: &[Segment], tolerance_secs: f64) -> bool {
    // Only the neighbourhood matters, so walk out from the insertion point
    // rather than scanning the whole transcript per candidate.
    let from = existing.partition_point(|s| s.timestamp < candidate.timestamp - tolerance_secs);
    for prior in existing[from..].iter() {
        if prior.timestamp > candidate.timestamp + tolerance_secs {
            break;
        }
        if text_similarity(&prior.text, &candidate.text) >= MERGE_SIMILARITY {
            return true;
        }
    }
    false
}

/// Normalised Levenshtein similarity in `0.0..=1.0`.
fn text_similarity(a: &str, b: &str) -> f64 {
    let a = a.trim().to_lowercase();
    let b = b.trim().to_lowercase();
    if a.is_empty() && b.is_empty() {
        return 1.0;
    }
    if a.is_empty() || b.is_empty() {
        return 0.0;
    }
    let distance = strsim::levenshtein(&a, &b) as f64;
    let longest = a.chars().count().max(b.chars().count()) as f64;
    1.0 - (distance / longest)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(text: &str, timestamp: f64, duration: f64) -> Segment {
        Segment {
            source: "spk".into(),
            speaker: "Peserta 1".into(),
            text: text.into(),
            timestamp,
            duration,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
        }
    }

    #[test]
    fn a_complete_transcript_has_no_gaps() {
        let segments = vec![seg("satu", 0.0, 30.0), seg("dua", 30.0, 30.0)];
        let report = report(&segments, 60.0, MIN_GAP_SECS);
        assert!(report.is_complete());
        assert_eq!(report.fraction, 1.0);
        assert_eq!(report.missing_secs, 0.0);
    }

    #[test]
    fn the_measured_failure_is_reported_as_a_gap() {
        // The real session: 360 s of audio, two live segments covering
        // t=1..8 s, and nothing else. The second occurrence of the speech
        // at ~150 s was never transcribed.
        let segments = vec![seg("halo", 1.0, 4.0), seg("selamat pagi", 5.0, 3.0)];
        let report = report(&segments, 360.0, MIN_GAP_SECS);
        assert!(!report.is_complete());
        assert_eq!(report.covered_secs, 7.0);
        assert!(
            (report.fraction - 7.0 / 360.0).abs() < 1e-9,
            "fraction was {}",
            report.fraction
        );
        // One gap before the speech and one after it.
        assert_eq!(report.gaps.len(), 1, "gaps: {:?}", report.gaps);
        assert_eq!(report.gaps[0], TimeRange::new(8.0, 360.0));
        assert_eq!(report.missing_secs, 352.0);
    }

    #[test]
    fn a_leading_gap_is_reported() {
        let segments = vec![seg("telat mulai", 120.0, 10.0)];
        let report = report(&segments, 200.0, MIN_GAP_SECS);
        assert_eq!(
            report.gaps,
            vec![TimeRange::new(0.0, 120.0), TimeRange::new(130.0, 200.0)]
        );
    }

    #[test]
    fn short_pauses_between_utterances_are_not_gaps() {
        // 2 s of breath between sentences is not untranscribed audio.
        let segments = vec![seg("satu", 0.0, 4.0), seg("dua", 6.0, 4.0)];
        let report = report(&segments, 10.0, MIN_GAP_SECS);
        assert!(report.is_complete(), "gaps: {:?}", report.gaps);
    }

    #[test]
    fn overlapping_segments_are_counted_once() {
        let segments = vec![seg("satu", 0.0, 10.0), seg("dua", 5.0, 10.0)];
        let report = report(&segments, 15.0, MIN_GAP_SECS);
        assert_eq!(report.covered_secs, 15.0);
        assert!(report.is_complete());
    }

    #[test]
    fn partial_segments_do_not_count_as_coverage() {
        // An HPT quick-pass segment is provisional; the refine pass replaces
        // it. Counting it would hide a gap the refine pass never filled.
        let mut partial = seg("sementara", 0.0, 30.0);
        partial.is_partial = true;
        let report = report(&[partial], 30.0, MIN_GAP_SECS);
        assert_eq!(report.covered_secs, 0.0);
        assert_eq!(report.gaps, vec![TimeRange::new(0.0, 30.0)]);
    }

    #[test]
    fn an_empty_transcript_misses_everything() {
        let report = report(&[], 120.0, MIN_GAP_SECS);
        assert_eq!(report.fraction, 0.0);
        assert_eq!(report.gaps, vec![TimeRange::new(0.0, 120.0)]);
        // Not "-0 detik tertranskrip": an empty f64 sum is negative zero.
        assert!(report.covered_secs.is_sign_positive());
        assert!(report.fraction.is_sign_positive());
    }

    #[test]
    fn a_zero_length_recording_is_complete() {
        let report = report(&[], 0.0, MIN_GAP_SECS);
        assert!(report.is_complete());
        assert_eq!(report.fraction, 1.0);
    }

    #[test]
    fn coverage_beyond_the_recording_does_not_exceed_it() {
        // A recovered session's offsets can push the last segment past the
        // WAV's length; the fraction must stay sane.
        let segments = vec![seg("panjang", 0.0, 500.0)];
        let report = report(&segments, 100.0, MIN_GAP_SECS);
        assert_eq!(report.covered_secs, 100.0);
        assert_eq!(report.fraction, 1.0);
    }

    #[test]
    fn padding_widens_gaps_without_leaving_the_recording() {
        let gaps = vec![TimeRange::new(0.0, 10.0), TimeRange::new(50.0, 60.0)];
        let padded = padded_gaps(&gaps, 60.0);
        assert_eq!(
            padded,
            vec![TimeRange::new(0.0, 11.0), TimeRange::new(49.0, 60.0)]
        );
    }

    #[test]
    fn padding_merges_gaps_it_makes_touch() {
        let gaps = vec![TimeRange::new(0.0, 10.0), TimeRange::new(11.5, 20.0)];
        let padded = padded_gaps(&gaps, 20.0);
        assert_eq!(padded, vec![TimeRange::new(0.0, 20.0)]);
    }

    // --- merge ---------------------------------------------------------

    #[test]
    fn merge_inserts_gap_segments_in_time_order() {
        let existing = vec![seg("awal", 1.0, 5.0)];
        let incoming = vec![seg("tengah", 150.0, 5.0), seg("akhir", 300.0, 5.0)];
        let merged = merge_by_timestamp(existing, incoming, MERGE_TOLERANCE_SECS);
        let texts: Vec<&str> = merged.iter().map(|s| s.text.as_str()).collect();
        assert_eq!(texts, vec!["awal", "tengah", "akhir"]);
    }

    #[test]
    fn merge_drops_a_restatement_of_the_same_moment() {
        let existing = vec![seg("selamat pagi semuanya", 10.0, 4.0)];
        let incoming = vec![seg("selamat pagi semuanya.", 10.4, 4.0)];
        let merged = merge_by_timestamp(existing, incoming, MERGE_TOLERANCE_SECS);
        assert_eq!(merged.len(), 1);
        assert_eq!(merged[0].text, "selamat pagi semuanya");
    }

    #[test]
    fn merge_keeps_the_same_sentence_said_again_minutes_later() {
        // The property the test audio is built to check: rapat_id.mp3 played
        // twice produces identical text at 00:01 and 02:30. Treating the
        // second as a duplicate is exactly the bug this module repairs.
        let existing = vec![seg("selamat pagi semuanya", 1.0, 4.0)];
        let incoming = vec![seg("selamat pagi semuanya", 151.0, 4.0)];
        let merged = merge_by_timestamp(existing, incoming, MERGE_TOLERANCE_SECS);
        assert_eq!(merged.len(), 2, "a legitimate repeat must survive");
        assert_eq!(merged[1].timestamp, 151.0);
    }

    #[test]
    fn merge_keeps_different_text_at_the_same_moment() {
        // Mic and speaker both transcribed; different speech, same instant.
        let existing = vec![seg("anggaran naik sepuluh persen", 10.0, 4.0)];
        let incoming = vec![seg("saya kurang setuju soal itu", 10.2, 4.0)];
        let merged = merge_by_timestamp(existing, incoming, MERGE_TOLERANCE_SECS);
        assert_eq!(merged.len(), 2);
    }

    #[test]
    fn merge_never_removes_an_existing_segment() {
        // The live transcript may carry user edits; the completion pass is
        // additive by construction.
        let existing = vec![
            seg("Pak Budi: anggaran naik", 10.0, 4.0),
            seg("catatan manual", 20.0, 1.0),
        ];
        let before = existing.len();
        let merged = merge_by_timestamp(existing, vec![seg("anggaran naik", 10.1, 4.0)], 2.0);
        assert!(merged.len() >= before);
        assert!(merged.iter().any(|s| s.text == "catatan manual"));
    }

    #[test]
    fn merging_into_an_empty_transcript_keeps_everything() {
        let incoming = vec![seg("satu", 0.0, 4.0), seg("dua", 10.0, 4.0)];
        let merged = merge_by_timestamp(Vec::new(), incoming, MERGE_TOLERANCE_SECS);
        assert_eq!(merged.len(), 2);
    }

    #[test]
    fn merging_nothing_is_a_no_op() {
        let existing = vec![seg("satu", 0.0, 4.0)];
        let merged = merge_by_timestamp(existing.clone(), Vec::new(), MERGE_TOLERANCE_SECS);
        assert_eq!(merged.len(), existing.len());
    }

    #[test]
    fn merged_output_is_sorted_by_timestamp() {
        let existing = vec![seg("c", 30.0, 1.0), seg("a", 1.0, 1.0)];
        let incoming = vec![seg("b", 15.0, 1.0), seg("d", 45.0, 1.0)];
        let merged = merge_by_timestamp(existing, incoming, MERGE_TOLERANCE_SECS);
        let stamps: Vec<f64> = merged.iter().map(|s| s.timestamp).collect();
        assert_eq!(stamps, vec![1.0, 15.0, 30.0, 45.0]);
    }

    #[test]
    fn coverage_improves_after_a_merge() {
        // End to end over the measured failure: a 360 s session with 7 s of
        // live coverage, plus a completion pass over the gap.
        let live = vec![seg("halo", 1.0, 4.0), seg("selamat pagi", 5.0, 3.0)];
        assert!(report(&live, 360.0, MIN_GAP_SECS).fraction < 0.05);
        let recovered = vec![seg("halo", 150.0, 4.0), seg("selamat pagi", 154.0, 26.0)];
        let merged = merge_by_timestamp(live, recovered, MERGE_TOLERANCE_SECS);
        assert_eq!(merged.len(), 4);
        let after = report(&merged, 360.0, MIN_GAP_SECS);
        assert_eq!(after.covered_secs, 37.0);
    }
}
