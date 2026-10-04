//! Long-meeting summarisation by map-reduce (F15).
//!
//! A three-hour rapat is around 90 000 characters of transcript.
//! [`crate::summary::MAX_TRANSCRIPT_CHARS`] is 24 000, so before this the
//! middle of every long meeting was elided by `truncate_transcript` and
//! the summary silently described the first hour and the last forty
//! minutes.
//!
//! The repair is the standard one: cut the transcript into time windows,
//! summarise each, then summarise the summaries. What it costs is one
//! model round trip per window — a three-hour meeting is ten of them, so
//! progress has to be visible or the user concludes the app hung.
//!
//! # Why time windows and not character counts
//!
//! A window that ends mid-agenda-item produces a partial summary about
//! half a topic, and the reduce step cannot put it back together. Ten
//! minutes is long enough to contain a whole agenda item and short
//! enough that twenty of them still fit the reduce step's budget.
//! Windows are only ever *shortened* when a stretch is unusually dense —
//! never extended past the character cap, which would reintroduce the
//! truncation this module exists to remove.

use serde::Serialize;

use crate::export::Segment;

/// Default window length. Ten minutes is roughly one agenda item.
pub const WINDOW_SECS: f64 = 600.0;

/// Hard character cap per window, so a dense ten minutes still fits a
/// small local model's context.
pub const MAX_WINDOW_CHARS: usize = 12_000;

/// One window of the meeting, ready to summarise.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct TranscriptChunk {
    /// 1-based, for "Bagian 3 dari 10".
    pub index: u32,
    pub total: u32,
    pub start_secs: f64,
    pub end_secs: f64,
    /// Rendered `[mm:ss] Speaker: text` lines.
    pub text: String,
}

impl TranscriptChunk {
    /// "00:00–10:00", for the progress line and the partial's heading.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(&self) -> String {
        format!("{}–{}", clock(self.start_secs), clock(self.end_secs))
    }
}

fn clock(seconds: f64) -> String {
    let total = seconds.max(0.0) as u64;
    format!("{:02}:{:02}", total / 60, total % 60)
}

/// Whether `transcript` needs the map-reduce path at all.
///
/// One round trip is always better than eleven when the whole meeting
/// fits, both for speed and because the single-pass summary sees every
/// connection at once.
pub fn needs_map_reduce(transcript_chars: usize, budget_chars: usize) -> bool {
    budget_chars > 0 && transcript_chars > budget_chars
}

/// Cuts `segments` into windows of at most `window_secs` and
/// `max_chars`.
///
/// A single segment longer than `max_chars` still gets its own window
/// rather than being dropped — losing a speech because it ran long is
/// the failure mode this whole module exists to prevent.
pub fn chunk_by_time(
    segments: &[Segment],
    window_secs: f64,
    max_chars: usize,
) -> Vec<TranscriptChunk> {
    let usable: Vec<&Segment> = segments
        .iter()
        .filter(|s| !s.is_partial && !s.text.trim().is_empty())
        .collect();
    if usable.is_empty() {
        return Vec::new();
    }
    let window_secs = if window_secs > 0.0 {
        window_secs
    } else {
        WINDOW_SECS
    };
    let max_chars = if max_chars > 0 { max_chars } else { usize::MAX };

    let mut chunks: Vec<TranscriptChunk> = Vec::new();
    let mut current = String::new();
    let mut start = usable[0].timestamp;
    let mut end = start;

    for segment in usable {
        let line = render(segment);
        let would_span = segment.timestamp + segment.duration - start;
        let would_exceed_time = !current.is_empty() && would_span > window_secs;
        let would_exceed_chars = !current.is_empty() && current.len() + line.len() + 1 > max_chars;
        if would_exceed_time || would_exceed_chars {
            chunks.push(TranscriptChunk {
                index: 0,
                total: 0,
                start_secs: start,
                end_secs: end,
                text: std::mem::take(&mut current),
            });
            start = segment.timestamp;
        }
        if !current.is_empty() {
            current.push('\n');
        }
        current.push_str(&line);
        end = segment.timestamp + segment.duration.max(0.0);
    }
    if !current.is_empty() {
        chunks.push(TranscriptChunk {
            index: 0,
            total: 0,
            start_secs: start,
            end_secs: end,
            text: current,
        });
    }
    let total = chunks.len() as u32;
    for (index, chunk) in chunks.iter_mut().enumerate() {
        chunk.index = index as u32 + 1;
        chunk.total = total;
    }
    chunks
}

fn render(segment: &Segment) -> String {
    let total = segment.timestamp.max(0.0) as u64;
    format!(
        "[{:02}:{:02}] {}: {}",
        total / 60,
        total % 60,
        segment.speaker.trim(),
        segment.text.trim()
    )
}

/// The instruction for one window of a long meeting.
///
/// Asks for notes rather than a finished summary: a per-window summary
/// written as prose reads like ten disconnected meeting reports once the
/// reduce step concatenates them.
pub fn map_instruction(chunk: &TranscriptChunk) -> String {
    format!(
        "Ini BAGIAN {} dari {} sebuah rapat panjang (menit {}). Buat catatan \
         padat dari bagian ini saja: topik yang dibahas, keputusan yang \
         diambil, tugas yang disepakati beserta penanggung jawab dan \
         tenggatnya, dan angka atau nama penting yang disebut. Tulis sebagai \
         daftar poin, bukan paragraf. Jangan menyimpulkan keseluruhan rapat \
         — bagian lain belum Anda lihat.",
        chunk.index,
        chunk.total,
        chunk.label()
    )
}

/// The instruction for the reduce step, over the collected notes.
pub fn reduce_instruction(template_instruction: &str) -> String {
    format!(
        "Di bawah ini adalah catatan per bagian dari satu rapat panjang, \
         berurutan. Gabungkan menjadi SATU dokumen utuh — bukan ringkasan \
         dari ringkasan yang mengulang struktur per bagian. Hilangkan \
         pengulangan, gabungkan tugas yang sama, dan pertahankan setiap \
         keputusan, nama, angka dan tenggat yang disebut.\n\n{template_instruction}"
    )
}

/// Joins the per-window notes into the reduce step's input.
pub fn join_partials(chunks: &[TranscriptChunk], partials: &[String]) -> String {
    let mut out = String::new();
    for (chunk, partial) in chunks.iter().zip(partials) {
        if partial.trim().is_empty() {
            continue;
        }
        out.push_str(&format!(
            "## Bagian {} ({})\n{}\n\n",
            chunk.index,
            chunk.label(),
            partial.trim()
        ));
    }
    out.trim_end().to_string()
}

/// How far through a map-reduce run the caller is.
#[derive(Debug, Clone, Serialize)]
pub struct MapReduceProgress {
    /// 0-based count of windows already summarised.
    pub done: u32,
    pub total: u32,
    /// Indonesian line for the UI.
    pub label: String,
}

impl MapReduceProgress {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn mapping(done: u32, total: u32, window: &str) -> Self {
        Self {
            done,
            total,
            label: format!("Meringkas bagian {} dari {total} ({window})…", done + 1),
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn reducing(total: u32) -> Self {
        Self {
            done: total,
            total,
            label: "Menggabungkan ringkasan seluruh bagian…".to_string(),
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn fraction(&self) -> f64 {
        if self.total == 0 {
            return 1.0;
        }
        // The reduce step is roughly one more unit of work.
        (self.done as f64 / (self.total as f64 + 1.0)).clamp(0.0, 1.0)
    }
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

    /// A three-hour meeting, one segment every 10 s.
    fn long_meeting() -> Vec<Segment> {
        (0..1080)
            .map(|i| {
                seg(
                    "Pembahasan anggaran dan tindak lanjutnya di unit kerja terkait.",
                    i as f64 * 10.0,
                    9.0,
                )
            })
            .collect()
    }

    #[test]
    fn a_short_meeting_needs_no_map_reduce() {
        assert!(!needs_map_reduce(5_000, 24_000));
        assert!(!needs_map_reduce(24_000, 24_000));
        assert!(needs_map_reduce(24_001, 24_000));
        // A zero budget is "no limit", not "chunk everything".
        assert!(!needs_map_reduce(100_000, 0));
    }

    #[test]
    fn a_three_hour_meeting_cuts_into_ten_minute_windows() {
        let chunks = chunk_by_time(&long_meeting(), WINDOW_SECS, MAX_WINDOW_CHARS);
        // 180 minutes / 10 = 18 windows, give or take the char cap.
        assert!(
            (18..=24).contains(&chunks.len()),
            "got {} windows",
            chunks.len()
        );
        assert_eq!(chunks[0].index, 1);
        assert_eq!(chunks[0].total, chunks.len() as u32);
        assert_eq!(chunks.last().unwrap().index, chunks.len() as u32);
    }

    #[test]
    fn no_window_exceeds_either_limit() {
        for chunk in chunk_by_time(&long_meeting(), WINDOW_SECS, MAX_WINDOW_CHARS) {
            assert!(
                chunk.text.len() <= MAX_WINDOW_CHARS,
                "window {} is {} chars",
                chunk.index,
                chunk.text.len()
            );
            assert!(
                chunk.end_secs - chunk.start_secs <= WINDOW_SECS + 10.0,
                "window {} spans {:.0}s",
                chunk.index,
                chunk.end_secs - chunk.start_secs
            );
        }
    }

    #[test]
    fn every_segment_lands_in_exactly_one_window() {
        // The property that matters: nothing is dropped and nothing is
        // counted twice, which is what truncation got wrong.
        let segments = long_meeting();
        let chunks = chunk_by_time(&segments, WINDOW_SECS, MAX_WINDOW_CHARS);
        let lines: usize = chunks.iter().map(|c| c.text.lines().count()).sum();
        assert_eq!(lines, segments.len());
    }

    #[test]
    fn the_windows_cover_the_meeting_without_gaps() {
        let chunks = chunk_by_time(&long_meeting(), WINDOW_SECS, MAX_WINDOW_CHARS);
        for pair in chunks.windows(2) {
            assert!(
                pair[1].start_secs >= pair[0].start_secs,
                "windows must run forwards"
            );
            assert!(
                pair[1].start_secs - pair[0].end_secs <= 10.0,
                "gap of {:.0}s between windows",
                pair[1].start_secs - pair[0].end_secs
            );
        }
    }

    #[test]
    fn a_dense_window_is_split_on_characters_not_truncated() {
        let long_line = "kata ".repeat(400); // ~2000 chars
        let segments: Vec<Segment> = (0..10)
            .map(|i| seg(&long_line, i as f64 * 10.0, 9.0))
            .collect();
        // 100 minutes' worth of window, but only 5 000 chars allowed.
        let chunks = chunk_by_time(&segments, 6_000.0, 5_000);
        assert!(chunks.len() > 1, "a dense stretch must split");
        let lines: usize = chunks.iter().map(|c| c.text.lines().count()).sum();
        assert_eq!(lines, segments.len(), "nothing may be dropped");
    }

    #[test]
    fn one_oversized_segment_gets_its_own_window_rather_than_being_dropped() {
        let huge = "kata ".repeat(5_000); // 25 000 chars
        let segments = vec![seg("pendek", 0.0, 5.0), seg(&huge, 10.0, 60.0)];
        let chunks = chunk_by_time(&segments, WINDOW_SECS, 5_000);
        let lines: usize = chunks.iter().map(|c| c.text.lines().count()).sum();
        assert_eq!(lines, 2);
    }

    #[test]
    fn partial_segments_are_skipped() {
        let mut partial = seg("sementara", 0.0, 5.0);
        partial.is_partial = true;
        let chunks = chunk_by_time(
            &[partial, seg("final", 10.0, 5.0)],
            WINDOW_SECS,
            MAX_WINDOW_CHARS,
        );
        assert_eq!(chunks.len(), 1);
        assert_eq!(chunks[0].text.lines().count(), 1);
        assert!(chunks[0].text.contains("final"));
    }

    #[test]
    fn an_empty_transcript_produces_no_windows() {
        assert!(chunk_by_time(&[], WINDOW_SECS, MAX_WINDOW_CHARS).is_empty());
        let mut blank = seg("   ", 0.0, 1.0);
        blank.text = "  ".into();
        assert!(chunk_by_time(&[blank], WINDOW_SECS, MAX_WINDOW_CHARS).is_empty());
    }

    #[test]
    fn a_window_is_labelled_in_minutes() {
        let chunks = chunk_by_time(&long_meeting(), WINDOW_SECS, MAX_WINDOW_CHARS);
        assert!(chunks[0].label().starts_with("00:00–"));
        assert!(chunks[1].label().contains('–'));
    }

    #[test]
    fn the_map_instruction_names_the_part_and_forbids_concluding() {
        let chunks = chunk_by_time(&long_meeting(), WINDOW_SECS, MAX_WINDOW_CHARS);
        let instruction = map_instruction(&chunks[2]);
        assert!(instruction.contains("BAGIAN 3 dari"));
        assert!(instruction.contains("Jangan menyimpulkan keseluruhan rapat"));
    }

    #[test]
    fn the_reduce_instruction_forbids_a_summary_of_summaries() {
        let instruction = reduce_instruction("Buat notulen rapat.");
        assert!(instruction.contains("SATU dokumen utuh"));
        assert!(instruction.contains("Buat notulen rapat."));
    }

    #[test]
    fn partials_join_under_their_window_headings() {
        let chunks = chunk_by_time(&long_meeting(), WINDOW_SECS, MAX_WINDOW_CHARS);
        let joined = join_partials(
            &chunks[..2],
            &["- Topik A".to_string(), "- Topik B".to_string()],
        );
        assert!(joined.contains("## Bagian 1 (00:00–"));
        assert!(joined.contains("- Topik A"));
        assert!(joined.contains("## Bagian 2"));
        assert!(joined.contains("- Topik B"));
    }

    #[test]
    fn a_window_the_model_returned_nothing_for_is_skipped_not_left_blank() {
        let chunks = chunk_by_time(&long_meeting(), WINDOW_SECS, MAX_WINDOW_CHARS);
        let joined = join_partials(&chunks[..2], &["".to_string(), "- Topik B".to_string()]);
        assert!(!joined.contains("## Bagian 1"));
        assert!(joined.contains("## Bagian 2"));
    }

    #[test]
    fn progress_reads_as_indonesian_and_never_exceeds_one() {
        let first = MapReduceProgress::mapping(0, 10, "00:00–10:00");
        assert_eq!(first.label, "Meringkas bagian 1 dari 10 (00:00–10:00)…");
        assert!(first.fraction() < 0.1);
        let reducing = MapReduceProgress::reducing(10);
        assert_eq!(reducing.label, "Menggabungkan ringkasan seluruh bagian…");
        assert!(reducing.fraction() > 0.9 && reducing.fraction() <= 1.0);
        assert_eq!(MapReduceProgress::reducing(0).fraction(), 1.0);
    }
}
