//! Append-only transcript journal — the thing that makes a crash survivable.
//!
//! Recovery snapshots used to carry configuration only (`mode`, toggles,
//! model path, a segment *count*), so a crash ninety minutes into a meeting
//! restored a session with `segments: []` while the banner promised the
//! session could be recovered. This module is the missing half: every
//! finalized segment is appended to `transcript.jsonl` inside the session's
//! recovery directory as it is emitted, and [`replay`] reconstructs exactly
//! the list the UI had.
//!
//! **Durability policy.** Each segment is written and flushed to the OS
//! immediately (so a process crash — the common case — loses nothing), and
//! `fsync`ed at most once per [`FSYNC_INTERVAL`] (so a power cut loses at
//! most a couple of seconds, without paying a disk barrier per segment on
//! a machine already saturated by Whisper). Segments arrive every few
//! seconds at most, so "flush per segment" is a handful of small writes a
//! minute, not a hot loop.
//!
//! **Format.** One JSON-encoded [`Segment`] per line — the same shape the
//! exporter writes to `transcript.json`, so the journal is readable by the
//! same tooling and by a human with `tail`. A torn final line (the process
//! died mid-write) is skipped by [`replay`] rather than failing the whole
//! recovery.

use std::fs::{File, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use crate::error::TranscribeError;
use crate::export::Segment;

/// Upper bound on how much wall-clock a power cut can cost. Not a flush
/// interval: every segment is flushed to the OS the moment it is written.
pub const FSYNC_INTERVAL: Duration = Duration::from_secs(2);

/// Whisper's marker for "this chunk was silence". The UI drops these
/// (`SessionNotifier._isBlankAudio`), so journalling them would make a
/// recovered session differ from the one that was lost.
const BLANK_AUDIO: &str = "[BLANK_AUDIO]";

/// The HPT merge key: the quick pass and the refine pass of one utterance
/// share `(source, timestamp)`. Mirrors Dart's `TranscriptSegment.segmentKey`
/// exactly — if the two ever disagree, a recovered transcript grows
/// duplicate rows where the live one replaced them in place.
fn segment_key(segment: &Segment) -> String {
    format!("{}@{:.2}", segment.source, segment.timestamp)
}

fn is_blank_audio(segment: &Segment) -> bool {
    segment.text.trim() == BLANK_AUDIO
}

/// Writer half. Held open for the lifetime of a session.
pub struct TranscriptJournal {
    file: File,
    path: PathBuf,
    last_sync: Instant,
    entries_written: u64,
}

impl TranscriptJournal {
    /// Opens `path` for appending, creating it and its parent if needed.
    /// Appending (not truncating) is what lets a recovered session keep
    /// writing into the journal it is recovering from.
    pub fn open_append(path: &Path) -> Result<Self, TranscribeError> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(TranscribeError::from)?;
        }
        let file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(path)
            .map_err(TranscribeError::from)?;
        Ok(Self {
            file,
            path: path.to_path_buf(),
            last_sync: Instant::now(),
            entries_written: 0,
        })
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn entries_written(&self) -> u64 {
        self.entries_written
    }

    /// Appends one segment. Blank-audio markers are dropped so the journal
    /// matches what the UI showed.
    pub fn append(&mut self, segment: &Segment) -> Result<(), TranscribeError> {
        if is_blank_audio(segment) {
            return Ok(());
        }
        let mut line = serde_json::to_vec(segment)
            .map_err(|e| TranscribeError::InvalidInput(e.to_string()))?;
        line.push(b'\n');
        // One write_all per line: a partial write is what produces the torn
        // last line `replay` is built to tolerate.
        self.file.write_all(&line).map_err(TranscribeError::from)?;
        self.file.flush().map_err(TranscribeError::from)?;
        self.entries_written += 1;
        if self.last_sync.elapsed() >= FSYNC_INTERVAL {
            self.sync()?;
        }
        Ok(())
    }

    /// Forces the OS to put everything written so far on the platter.
    pub fn sync(&mut self) -> Result<(), TranscribeError> {
        self.file.sync_data().map_err(TranscribeError::from)?;
        self.last_sync = Instant::now();
        Ok(())
    }
}

/// Rebuilds the transcript from `path`, applying the same merge rules the
/// live UI applies:
///
/// * segments are keyed by `(source, timestamp)` and keep their first-seen
///   position, so a refined pass replaces its quick pass in place rather
///   than appending a duplicate;
/// * a partial never overwrites an already-refined row — the accurate pass
///   is authoritative, regardless of arrival order;
/// * unparseable lines are skipped, because the last line of a journal
///   whose process was killed is routinely half-written.
///
/// Returns an empty list for a missing file: a session that crashed before
/// its first segment is recoverable, just empty.
pub fn replay(path: &Path) -> Vec<Segment> {
    let Ok(file) = File::open(path) else {
        return Vec::new();
    };
    let mut order: Vec<String> = Vec::new();
    let mut by_key: std::collections::HashMap<String, Segment> = std::collections::HashMap::new();

    for line in BufReader::new(file).lines() {
        let Ok(line) = line else { break };
        if line.trim().is_empty() {
            continue;
        }
        let Ok(segment) = serde_json::from_str::<Segment>(&line) else {
            // A torn tail is expected; a corrupt line in the middle is not,
            // but dropping one row beats losing the whole meeting.
            tracing::warn!(path = %path.display(), "skipping unparseable journal line");
            continue;
        };
        if is_blank_audio(&segment) {
            continue;
        }
        let key = segment_key(&segment);
        match by_key.get(&key) {
            Some(existing) if segment.is_partial && !existing.is_partial => {}
            Some(_) => {
                by_key.insert(key, segment);
            }
            None => {
                order.push(key.clone());
                by_key.insert(key, segment);
            }
        }
    }

    order
        .into_iter()
        .filter_map(|key| by_key.remove(&key))
        .collect()
}

/// Number of segments [`replay`] would return, without materialising them.
/// Used by the recovery dialog, which lists every recoverable session and
/// would otherwise parse every transcript to show a count.
pub fn replay_count(path: &Path) -> u32 {
    replay(path).len() as u32
}

/// End of the last recovered segment, in seconds. This is where a resumed
/// session's timeline has to continue from: a recovered session restarts
/// its Whisper pipeline at t=0, and without an offset its first new segment
/// would collide with the key of a segment recorded before the crash.
pub fn last_segment_end_secs(segments: &[Segment]) -> f64 {
    segments
        .iter()
        .map(|s| s.timestamp + s.duration)
        .fold(0.0, f64::max)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Microseconds of CPU this thread has actually burned, for the complexity
    /// benchmark below.
    ///
    /// Wall-clock cannot carry that assertion: `cargo test` runs the benchmark
    /// alongside 380 other tests on as many threads as the machine has cores,
    /// and a *descheduled* thread accumulates wall-clock without doing any work
    /// — an inflation with no upper bound. Measured on four cores, the identical
    /// replay cost anywhere from 94 ms to 468 ms, so no amount of sampling or
    /// threshold-widening makes a wall-clock ratio trustworthy. A thread CPU
    /// clock simply does not tick while the thread is parked, which removes the
    /// noise at the source instead of averaging over it.
    #[cfg(unix)]
    fn thread_cpu_micros() -> u128 {
        let mut ts = libc::timespec {
            tv_sec: 0,
            tv_nsec: 0,
        };
        // SAFETY: `ts` is a live, fully initialised `timespec`; `clock_gettime`
        // only writes into it and reports failure through its return value.
        let rc = unsafe { libc::clock_gettime(libc::CLOCK_THREAD_CPUTIME_ID, &mut ts) };
        assert_eq!(rc, 0, "clock_gettime(CLOCK_THREAD_CPUTIME_ID) failed");
        let secs = u128::try_from(ts.tv_sec).unwrap_or_default();
        let nanos = u128::try_from(ts.tv_nsec).unwrap_or_default();
        secs * 1_000_000 + nanos / 1_000
    }

    /// Wall-clock stand-in where there is no POSIX thread clock. `libc` is a
    /// unix-only dependency and `cargo test --lib` is a Linux job in CI, so this
    /// is only ever reached by a developer running the suite on Windows.
    #[cfg(not(unix))]
    fn thread_cpu_micros() -> u128 {
        use std::sync::OnceLock;
        static START: OnceLock<Instant> = OnceLock::new();
        START.get_or_init(Instant::now).elapsed().as_micros()
    }

    fn temp_dir() -> PathBuf {
        let dir = std::env::temp_dir().join(format!("trareon_journal_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn seg(source: &str, text: &str, ts: f64, is_partial: bool) -> Segment {
        Segment {
            source: source.to_string(),
            speaker: source.to_uppercase(),
            text: text.to_string(),
            timestamp: ts,
            duration: 2.0,
            language: "id".to_string(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial,
            low_confidence: false,
            words: Vec::new(),
        }
    }

    #[test]
    fn append_then_replay_roundtrips_in_order() {
        let dir = temp_dir();
        let path = dir.join("transcript.jsonl");
        let mut journal = TranscriptJournal::open_append(&path).unwrap();
        journal.append(&seg("mic", "satu", 0.0, false)).unwrap();
        journal.append(&seg("spk", "dua", 3.0, false)).unwrap();
        journal.append(&seg("mic", "tiga", 6.0, false)).unwrap();
        journal.sync().unwrap();

        let replayed = replay(&path);
        let texts: Vec<_> = replayed.iter().map(|s| s.text.as_str()).collect();
        assert_eq!(texts, ["satu", "dua", "tiga"]);
        assert_eq!(journal.entries_written(), 3);
    }

    /// The HPT case: the quick pass lands first, the refine pass replaces it
    /// in place. A recovered transcript with both rows would be a visible
    /// regression against the live one.
    #[test]
    fn a_refined_pass_replaces_its_quick_pass_in_place() {
        let dir = temp_dir();
        let path = dir.join("transcript.jsonl");
        let mut journal = TranscriptJournal::open_append(&path).unwrap();
        journal.append(&seg("mic", "halo smua", 0.0, true)).unwrap();
        journal
            .append(&seg("spk", "berikutnya", 3.0, false))
            .unwrap();
        journal
            .append(&seg("mic", "halo semua", 0.0, false))
            .unwrap();

        let replayed = replay(&path);
        assert_eq!(replayed.len(), 2, "no duplicate row for the same utterance");
        assert_eq!(replayed[0].text, "halo semua");
        assert!(!replayed[0].is_partial);
        assert_eq!(replayed[1].text, "berikutnya", "order is preserved");
    }

    #[test]
    fn a_late_partial_never_overwrites_a_refined_row() {
        let dir = temp_dir();
        let path = dir.join("transcript.jsonl");
        let mut journal = TranscriptJournal::open_append(&path).unwrap();
        journal
            .append(&seg("mic", "halo semua", 0.0, false))
            .unwrap();
        journal.append(&seg("mic", "halo smua", 0.0, true)).unwrap();

        let replayed = replay(&path);
        assert_eq!(replayed.len(), 1);
        assert_eq!(replayed[0].text, "halo semua");
    }

    #[test]
    fn blank_audio_is_never_journalled() {
        let dir = temp_dir();
        let path = dir.join("transcript.jsonl");
        let mut journal = TranscriptJournal::open_append(&path).unwrap();
        journal
            .append(&seg("mic", "[BLANK_AUDIO]", 0.0, false))
            .unwrap();
        journal.append(&seg("mic", "nyata", 3.0, false)).unwrap();

        assert_eq!(journal.entries_written(), 1);
        assert_eq!(replay(&path).len(), 1);
    }

    /// The exact shape of a `kill -9`: the last line never finished.
    #[test]
    fn a_torn_final_line_costs_one_segment_not_the_meeting() {
        let dir = temp_dir();
        let path = dir.join("transcript.jsonl");
        let mut journal = TranscriptJournal::open_append(&path).unwrap();
        for i in 0..5 {
            journal
                .append(&seg("mic", &format!("baris {i}"), i as f64 * 3.0, false))
                .unwrap();
        }
        drop(journal);

        // Chop the file mid-way through what would have been line 6.
        let mut raw = std::fs::read(&path).unwrap();
        raw.extend_from_slice(br#"{"source":"mic","speaker":"MIC","te"#);
        std::fs::write(&path, raw).unwrap();

        let replayed = replay(&path);
        assert_eq!(replayed.len(), 5);
        assert_eq!(replayed[4].text, "baris 4");
    }

    #[test]
    fn reopening_appends_rather_than_truncating() {
        let dir = temp_dir();
        let path = dir.join("transcript.jsonl");
        let mut first = TranscriptJournal::open_append(&path).unwrap();
        first
            .append(&seg("mic", "sebelum crash", 0.0, false))
            .unwrap();
        drop(first);

        let mut second = TranscriptJournal::open_append(&path).unwrap();
        second
            .append(&seg("mic", "setelah pulih", 120.0, false))
            .unwrap();

        let replayed = replay(&path);
        assert_eq!(replayed.len(), 2);
        assert_eq!(replayed[0].text, "sebelum crash");
    }

    #[test]
    fn replaying_a_missing_journal_is_empty_not_an_error() {
        assert!(replay(Path::new("/definitely/not/a/journal.jsonl")).is_empty());
    }

    #[test]
    fn last_segment_end_is_where_a_resumed_session_continues() {
        let segments = vec![seg("mic", "a", 0.0, false), seg("spk", "b", 10.0, false)];
        assert_eq!(last_segment_end_secs(&segments), 12.0);
        assert_eq!(last_segment_end_secs(&[]), 0.0);
    }

    /// Permanent benchmark: the journal is what a three-hour meeting is
    /// recovered from, so writing and replaying one has to be cheap enough
    /// that recovery is instant rather than a second spinner after a crash.
    ///
    /// The assertion that matters is the *shape*: the cost per segment must not
    /// grow with the number of segments. `replay` is keyed by a `HashMap`, so it
    /// is linear; a scan-per-line implementation would be quadratic and this
    /// test is what would catch that coming back.
    ///
    /// Two things make that assertion reliable rather than flaky:
    ///
    /// * It is **equal-work**, not equal-calls — the small journal is replayed
    ///   [`SIZE_FACTOR`] times against a single pass over the big one, so both
    ///   sides digest the same number of segments. Linear replay then makes the
    ///   two costs equal and quadratic makes the big one [`SIZE_FACTOR`]×
    ///   dearer, with no size-dependent baseline to calibrate away.
    /// * It is measured in **thread CPU time** ([`thread_cpu_micros`]), so
    ///   sharing the machine with the rest of the suite cannot inflate it.
    ///
    /// The latency budget at the end stays on wall-clock, because what it
    /// promises is about the wall-clock a user waits; its headroom is more than
    /// an order of magnitude, so contention cannot reach it.
    #[test]
    fn a_three_hour_journal_writes_and_replays_linearly() {
        use crate::bench_fixture::{bench_segments, three_hour_meeting, BENCH_SEGMENT_COUNT};

        /// How many times bigger the big journal is than the small one.
        const SIZE_FACTOR: usize = 4;

        /// Rounds of the whole equal-work comparison. Cache state and allocator
        /// warmth still vary between rounds, and both only ever *add* cost, so
        /// the cheapest round of each side is the honest estimate.
        const ROUNDS: usize = 3;

        /// What one equal-work measurement cost, in microseconds.
        struct Cost {
            cpu: u128,
            wall: u128,
        }

        /// Cost of replaying `path` `repeats` times.
        ///
        /// Replay only reads, so repeating it has no side effects. The result is
        /// verified outside the measured region so the assertions cannot show up
        /// as measured cost.
        fn replay_cost(path: &Path, expected: &[Segment], repeats: usize) -> Cost {
            let mut last = Vec::new();
            let cpu_start = thread_cpu_micros();
            let wall_start = Instant::now();
            for _ in 0..repeats {
                last = replay(path);
            }
            let cost = Cost {
                cpu: thread_cpu_micros().saturating_sub(cpu_start),
                wall: wall_start.elapsed().as_micros(),
            };
            assert_eq!(last.len(), expected.len());
            assert_eq!(last.last().unwrap().text, expected.last().unwrap().text);
            cost
        }

        /// Cheapest of [`ROUNDS`] equal-work measurements, by CPU.
        fn cheapest_cost(path: &Path, expected: &[Segment], repeats: usize) -> Cost {
            (0..ROUNDS)
                .map(|_| replay_cost(path, expected, repeats))
                .min_by_key(|cost| cost.cpu)
                .expect("ROUNDS is never zero")
        }

        fn write(dir: &Path, segments: &[Segment]) -> (PathBuf, u128) {
            let path = dir.join(format!("transcript-{}.jsonl", segments.len()));
            let mut journal = TranscriptJournal::open_append(&path).unwrap();
            let write_start = Instant::now();
            for segment in segments {
                journal.append(segment).unwrap();
            }
            journal.sync().unwrap();
            (path, write_start.elapsed().as_micros())
        }

        let dir = temp_dir();
        let quarter = bench_segments(BENCH_SEGMENT_COUNT / SIZE_FACTOR, 45.0 * 60.0);
        let full = three_hour_meeting();
        assert_eq!(
            full.len(),
            quarter.len() * SIZE_FACTOR,
            "the equal-work comparison below only holds if the big journal is \
             exactly SIZE_FACTOR times the small one"
        );

        let (small_path, small_write) = write(&dir, &quarter);
        let (big_path, big_write) = write(&dir, &full);

        // Equal segments processed on both sides: SIZE_FACTOR small replays
        // against one big one.
        let small_cost = cheapest_cost(&small_path, &quarter, SIZE_FACTOR);
        let big_cost = cheapest_cost(&big_path, &full, 1);

        println!(
            "[perf] journal write {} segs = {}ms, {} segs = {}ms",
            quarter.len(),
            small_write / 1000,
            full.len(),
            big_write / 1000
        );
        println!(
            "[perf] journal replay, {} segs each way (cheapest of {ROUNDS}): \
             {}x{} segs = {}ms CPU, 1x{} segs = {}ms CPU ({}ms wall)",
            full.len(),
            SIZE_FACTOR,
            quarter.len(),
            small_cost.cpu / 1000,
            full.len(),
            big_cost.cpu / 1000,
            big_cost.wall / 1000
        );

        // Linear ⇒ ~1.0; quadratic ⇒ ~SIZE_FACTOR. Half-way between the two, in
        // the log scale a complexity class lives in, is sqrt(SIZE_FACTOR).
        let per_segment_growth = big_cost.cpu as f64 / small_cost.cpu.max(1) as f64;
        assert!(
            per_segment_growth < (SIZE_FACTOR as f64).sqrt(),
            "replaying one {}-segment journal burned {per_segment_growth:.1}x the \
             CPU of replaying {SIZE_FACTOR} journals holding the same {} segments \
             in total — the per-segment cost grows with size, which is the shape \
             of a quadratic replay, not a linear one",
            full.len(),
            full.len()
        );
        assert!(
            big_cost.wall < 2_000_000,
            "recovering a three-hour transcript took {}ms",
            big_cost.wall / 1000
        );
    }

    /// The HPT worst case at scale: every segment arrives twice, quick then
    /// refined. `replay` must still return exactly one row per utterance.
    #[test]
    fn a_three_hour_journal_of_refined_passes_replays_one_row_per_utterance() {
        use crate::bench_fixture::three_hour_meeting;

        let dir = temp_dir();
        let path = dir.join("hpt.jsonl");
        let segments = three_hour_meeting();
        let mut journal = TranscriptJournal::open_append(&path).unwrap();
        for segment in &segments {
            let mut quick = segment.clone();
            quick.is_partial = true;
            quick.text = format!("cepat: {}", segment.text);
            journal.append(&quick).unwrap();
        }
        for segment in &segments {
            journal.append(segment).unwrap();
        }
        journal.sync().unwrap();

        let start = Instant::now();
        let replayed = replay(&path);
        println!(
            "[perf] journal replay of {} lines (2 passes) = {}ms",
            segments.len() * 2,
            start.elapsed().as_millis()
        );
        assert_eq!(replayed.len(), segments.len());
        assert!(replayed.iter().all(|s| !s.is_partial));
        assert_eq!(replayed[0].text, segments[0].text);
        assert_eq!(replayed.last().unwrap().text, segments.last().unwrap().text);
    }
}
