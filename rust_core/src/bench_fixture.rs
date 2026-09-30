//! Synthetic "three hour meeting" fixture — the Rust half of
//! `test/fixtures/large_session.dart`.
//!
//! Both sides generate the same shape (5 000 segments over 3 hours, one
//! utterance every ~2.16 s) so a number measured in Dart and a number
//! measured here describe the same meeting. Test-only: nothing in the
//! shipped binary depends on it.

use crate::export::Segment;

/// Segment count of the canonical fixture.
pub const BENCH_SEGMENT_COUNT: usize = 5000;

/// Wall-clock span of the canonical fixture, in seconds (3 hours).
pub const BENCH_DURATION_SECS: f64 = 3.0 * 60.0 * 60.0;

const WORDS: [&str; 20] = [
    "rapat",
    "anggaran",
    "laporan",
    "tindak",
    "lanjut",
    "keputusan",
    "peserta",
    "notulen",
    "agenda",
    "evaluasi",
    "kuartal",
    "target",
    "kendala",
    "koordinasi",
    "dokumen",
    "jadwal",
    "presentasi",
    "usulan",
    "anggota",
    "divisi",
];

/// Same deterministic mixer as the Dart fixture, so the two corpora are
/// comparable rather than merely similar.
fn mix(x: u32) -> u32 {
    let mut v = x.wrapping_mul(0x27d4_eb2d) & 0x7fff_ffff;
    v ^= v >> 15;
    v = v.wrapping_mul(0x85eb_ca6b) & 0x7fff_ffff;
    v ^= v >> 13;
    v
}

/// Builds `count` segments spread evenly over `total_secs`, each with a
/// distinct `(source, timestamp)` key.
pub fn bench_segments(count: usize, total_secs: f64) -> Vec<Segment> {
    let step = total_secs / count as f64;
    (0..count)
        .map(|i| {
            let r = mix(7 + i as u32);
            let word_count = 6 + (r % 9) as usize;
            let text = (0..word_count)
                .map(|w| WORDS[(mix(r + w as u32) % WORDS.len() as u32) as usize])
                .collect::<Vec<_>>()
                .join(" ");
            Segment {
                source: if i % 2 == 0 { "mic" } else { "spk" }.to_string(),
                speaker: format!("Pembicara {}", (r % 4) + 1),
                text,
                timestamp: ((i as f64 * step) * 100.0).round() / 100.0,
                duration: ((step * 0.9) * 100.0).round() / 100.0,
                language: "id".to_string(),
                confidence: 0.6 + (r % 40) as f32 / 100.0,
                avg_log_prob: -0.1 - (r % 50) as f32 / 100.0,
                is_partial: false,
                low_confidence: r.is_multiple_of(23),
            }
        })
        .collect()
}

/// The canonical 5 000-segment, three-hour fixture.
pub fn three_hour_meeting() -> Vec<Segment> {
    bench_segments(BENCH_SEGMENT_COUNT, BENCH_DURATION_SECS)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_fixture_is_three_hours_of_distinct_segments() {
        let segments = three_hour_meeting();
        assert_eq!(segments.len(), BENCH_SEGMENT_COUNT);
        let keys: std::collections::HashSet<String> = segments
            .iter()
            .map(|s| format!("{}@{:.2}", s.source, s.timestamp))
            .collect();
        assert_eq!(
            keys.len(),
            BENCH_SEGMENT_COUNT,
            "every segment needs its own merge key, or the benchmark is \
             measuring replacements instead of appends"
        );
        let last = segments.last().unwrap();
        assert!(
            last.timestamp > BENCH_DURATION_SECS - 5.0,
            "the fixture must actually span three hours, got {}",
            last.timestamp
        );
    }

    #[test]
    fn the_fixture_is_deterministic() {
        let a = bench_segments(64, 128.0);
        let b = bench_segments(64, 128.0);
        let texts_a: Vec<&str> = a.iter().map(|s| s.text.as_str()).collect();
        let texts_b: Vec<&str> = b.iter().map(|s| s.text.as_str()).collect();
        assert_eq!(texts_a, texts_b);
    }
}
