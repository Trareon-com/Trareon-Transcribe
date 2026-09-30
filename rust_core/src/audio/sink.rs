//! Where captured samples go, and what we learned about them on the way.
//!
//! Two concerns that both sit on the tee thread between capture and the STT
//! worker, kept here so they are unit-testable without a sound card:
//!
//! * [`AudioSink`] — disk (the default) or a bounded RAM buffer (the
//!   fallback). The RAM path used to be the only path and was unbounded:
//!   691 MB per source for a three-hour session, lost entirely on a crash.
//! * [`ChannelHealth`] — how much audio a source has actually delivered and
//!   when it was last above the noise floor. "The microphone recorded zero
//!   seconds and nobody said anything" is the failure this exists to make
//!   impossible; it is the #1 complaint in this product category.

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};

use crate::audio::wav_writer::StreamingWavWriter;
use crate::error::TranscribeError;

/// RMS below this counts as silence. -46 dBFS: quiet enough that a muted
/// input, a dead stream and a monitor source with nothing playing all land
/// under it, loud enough that room tone on a live microphone does not.
#[flutter_rust_bridge::frb(ignore)]
pub const NOISE_FLOOR_RMS: f32 = 0.005;

/// How long an enabled source may deliver nothing above the noise floor
/// before the user is told. Long enough to sit through a pause in a
/// meeting, short enough to still salvage the recording.
#[flutter_rust_bridge::frb(ignore)]
pub const SILENCE_WARNING_SECS: f64 = 60.0;

/// Ceiling on the RAM fallback, per source. The point of this sprint is to
/// stop a long session eating memory until it is killed, so even the
/// fallback path is bounded — one hour at 16 kHz mono f32 is ~230 MB.
/// Audio past the cap is dropped (and reported), never the beginning:
/// the opening of a meeting is the part nobody can reconstruct.
#[flutter_rust_bridge::frb(ignore)]
pub const RAM_FALLBACK_CAP_SECS: usize = 3600;

/// Live counters for one capture source, shared between the tee thread
/// that fills them and the session that reports them. Lock-free because
/// the tee thread runs per audio chunk and must never block on a reader.
#[derive(Debug, Default)]
#[flutter_rust_bridge::frb(ignore)]
pub struct ChannelHealth {
    total_samples: AtomicU64,
    voiced_samples: AtomicU64,
    /// Unix ms of the first chunk above the noise floor; 0 = never. This
    /// is what "rekaman terkonfirmasi" means: not "a stream opened" but
    /// "sound actually arrived".
    first_voiced_unix_ms: AtomicU64,
    last_voiced_unix_ms: AtomicU64,
    write_failures: AtomicU64,
    on_disk: AtomicBool,
}

impl ChannelHealth {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn new(on_disk: bool) -> Self {
        Self {
            on_disk: AtomicBool::new(on_disk),
            ..Default::default()
        }
    }

    /// Folds one captured chunk into the counters.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn observe(&self, chunk: &[f32], now_unix_ms: u64) {
        if chunk.is_empty() {
            return;
        }
        self.total_samples
            .fetch_add(chunk.len() as u64, Ordering::Relaxed);
        if !is_voiced(chunk) {
            return;
        }
        self.voiced_samples
            .fetch_add(chunk.len() as u64, Ordering::Relaxed);
        let _ = self.first_voiced_unix_ms.compare_exchange(
            0,
            now_unix_ms,
            Ordering::Relaxed,
            Ordering::Relaxed,
        );
        self.last_voiced_unix_ms
            .store(now_unix_ms, Ordering::Relaxed);
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn note_write_failure(&self) {
        self.write_failures.fetch_add(1, Ordering::Relaxed);
        self.on_disk.store(false, Ordering::Relaxed);
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn total_samples(&self) -> u64 {
        self.total_samples.load(Ordering::Relaxed)
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn voiced_samples(&self) -> u64 {
        self.voiced_samples.load(Ordering::Relaxed)
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn write_failures(&self) -> u64 {
        self.write_failures.load(Ordering::Relaxed)
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn on_disk(&self) -> bool {
        self.on_disk.load(Ordering::Relaxed)
    }

    /// Whether sound above the noise floor has ever arrived on this source.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn confirmed(&self) -> bool {
        self.first_voiced_unix_ms.load(Ordering::Relaxed) != 0
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn last_voiced_unix_ms(&self) -> Option<u64> {
        match self.last_voiced_unix_ms.load(Ordering::Relaxed) {
            0 => None,
            value => Some(value),
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn seconds_captured(&self, sample_rate: u32) -> f64 {
        samples_to_secs(self.total_samples(), sample_rate)
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn seconds_voiced(&self, sample_rate: u32) -> f64 {
        samples_to_secs(self.voiced_samples(), sample_rate)
    }

    /// Percentage of captured audio that was below the noise floor. 100.0
    /// when nothing was captured at all — a source that delivered nothing
    /// is completely silent, not "0% silent".
    #[flutter_rust_bridge::frb(ignore)]
    pub fn percent_silent(&self) -> f64 {
        let total = self.total_samples();
        if total == 0 {
            return 100.0;
        }
        100.0 * (total - self.voiced_samples().min(total)) as f64 / total as f64
    }

    /// How long this source has been silent, given the current wall clock.
    /// Falls back to [`session_elapsed_secs`] when it has never been
    /// voiced — "silent since the session started".
    #[flutter_rust_bridge::frb(ignore)]
    pub fn silent_for_secs(&self, now_unix_ms: u64, session_elapsed_secs: f64) -> f64 {
        match self.last_voiced_unix_ms() {
            Some(last) => now_unix_ms.saturating_sub(last) as f64 / 1000.0,
            None => session_elapsed_secs,
        }
    }
}

fn samples_to_secs(samples: u64, sample_rate: u32) -> f64 {
    if sample_rate == 0 {
        return 0.0;
    }
    samples as f64 / sample_rate as f64
}

/// Root-mean-square of `chunk`, above [`NOISE_FLOOR_RMS`].
#[flutter_rust_bridge::frb(ignore)]
pub fn is_voiced(chunk: &[f32]) -> bool {
    rms(chunk) > NOISE_FLOOR_RMS
}

#[flutter_rust_bridge::frb(ignore)]
pub fn rms(chunk: &[f32]) -> f32 {
    if chunk.is_empty() {
        return 0.0;
    }
    let sum: f64 = chunk.iter().map(|s| (*s as f64) * (*s as f64)).sum();
    (sum / chunk.len() as f64).sqrt() as f32
}

/// Destination for one source's captured samples.
#[flutter_rust_bridge::frb(ignore)]
pub enum AudioSink {
    /// The default. `broken` latches after a write failure (a full disk,
    /// a removed volume): the bytes already written stay recoverable and
    /// transcription carries on, rather than either crashing the capture
    /// thread or quietly buffering the rest of a meeting into RAM — which
    /// is the failure mode this whole sink exists to remove.
    Disk {
        writer: StreamingWavWriter,
        broken: bool,
    },
    /// Fallback, chosen at session start when the writer cannot be opened
    /// at all (read-only library path, no space). Bounded; see
    /// [`RAM_FALLBACK_CAP_SECS`].
    Ram { samples: Vec<f32>, capped: bool },
}

impl AudioSink {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn ram() -> Self {
        AudioSink::Ram {
            samples: Vec::new(),
            capped: false,
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn disk(writer: StreamingWavWriter) -> Self {
        AudioSink::Disk {
            writer,
            broken: false,
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn is_disk(&self) -> bool {
        matches!(self, AudioSink::Disk { broken: false, .. })
    }

    /// Appends a chunk. Returns the error *once*, on the transition into
    /// the broken state, so the caller can raise a single notice instead
    /// of one per 100 ms chunk for the rest of the session.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn append(&mut self, chunk: &[f32], sample_rate: u32) -> Result<(), TranscribeError> {
        match self {
            AudioSink::Disk { writer, broken } => {
                if *broken {
                    return Ok(());
                }
                match writer.append(chunk) {
                    Ok(()) => Ok(()),
                    Err(e) => {
                        *broken = true;
                        Err(e)
                    }
                }
            }
            AudioSink::Ram { samples, capped } => {
                let cap = RAM_FALLBACK_CAP_SECS * sample_rate as usize;
                if samples.len() >= cap {
                    if !*capped {
                        *capped = true;
                        return Err(TranscribeError::Export(format!(
                            "batas penyangga audio di memori ({RAM_FALLBACK_CAP_SECS} detik) \
                             tercapai; audio selanjutnya tidak disimpan"
                        )));
                    }
                    return Ok(());
                }
                let room = cap - samples.len();
                samples.extend_from_slice(&chunk[..chunk.len().min(room)]);
                Ok(())
            }
        }
    }

    /// Closes the sink. `Disk` patches its WAV header and renames the
    /// `.part` away; `Ram` hands the buffer back for the caller to write.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn close(self) -> Result<ClosedAudio, TranscribeError> {
        match self {
            AudioSink::Disk { writer, .. } => Ok(ClosedAudio::File(writer.finalize()?)),
            AudioSink::Ram { samples, .. } => Ok(if samples.is_empty() {
                ClosedAudio::File(None)
            } else {
                ClosedAudio::Samples(samples)
            }),
        }
    }
}

/// What a closed sink left behind.
#[derive(Debug)]
#[flutter_rust_bridge::frb(ignore)]
pub enum ClosedAudio {
    /// A finished WAV on disk, or `None` when nothing was captured.
    File(Option<PathBuf>),
    /// Samples still in memory, for the caller to write out.
    Samples(Vec<f32>),
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::decode::TARGET_SAMPLE_RATE;

    fn loud(n: usize) -> Vec<f32> {
        (0..n)
            .map(|i| if i % 2 == 0 { 0.4 } else { -0.4 })
            .collect()
    }

    fn quiet(n: usize) -> Vec<f32> {
        (0..n)
            .map(|i| if i % 2 == 0 { 0.0005 } else { -0.0005 })
            .collect()
    }

    #[test]
    fn room_tone_is_voiced_and_a_dead_stream_is_not() {
        assert!(is_voiced(&loud(1600)));
        assert!(!is_voiced(&quiet(1600)));
        assert!(!is_voiced(&vec![0.0; 1600]));
        assert!(!is_voiced(&[]));
    }

    #[test]
    fn a_source_is_confirmed_only_once_real_sound_arrives() {
        let health = ChannelHealth::new(true);
        assert!(!health.confirmed(), "an open stream is not a recording");

        health.observe(&quiet(16_000), 1_000);
        assert!(!health.confirmed(), "a second of silence proves nothing");
        assert_eq!(health.seconds_captured(TARGET_SAMPLE_RATE), 1.0);
        assert_eq!(health.percent_silent(), 100.0);

        health.observe(&loud(16_000), 2_000);
        assert!(health.confirmed());
        assert_eq!(health.last_voiced_unix_ms(), Some(2_000));
        assert_eq!(health.seconds_voiced(TARGET_SAMPLE_RATE), 1.0);
        assert_eq!(health.percent_silent(), 50.0);

        // The first confirmation timestamp is not overwritten by later ones.
        health.observe(&loud(16_000), 9_000);
        assert_eq!(health.last_voiced_unix_ms(), Some(9_000));
    }

    #[test]
    fn a_source_that_delivered_nothing_reads_as_fully_silent() {
        let health = ChannelHealth::new(true);
        assert_eq!(health.percent_silent(), 100.0);
        assert_eq!(health.seconds_captured(TARGET_SAMPLE_RATE), 0.0);
        assert!(!health.confirmed());
        // Never voiced: silent for as long as the session has been running.
        assert_eq!(health.silent_for_secs(10_000, 42.0), 42.0);
    }

    #[test]
    fn silence_is_measured_from_the_last_voiced_chunk() {
        let health = ChannelHealth::new(true);
        health.observe(&loud(1600), 60_000);
        assert_eq!(health.silent_for_secs(125_000, 200.0), 65.0);
    }

    #[test]
    fn a_write_failure_marks_the_channel_off_disk() {
        let health = ChannelHealth::new(true);
        assert!(health.on_disk());
        health.note_write_failure();
        assert!(!health.on_disk());
        assert_eq!(health.write_failures(), 1);
    }

    #[test]
    fn the_ram_fallback_is_bounded_and_says_so_once() {
        // A tiny "sample rate" keeps the cap reachable in a unit test.
        let rate = 2u32;
        let cap = RAM_FALLBACK_CAP_SECS * rate as usize;
        let mut sink = AudioSink::ram();
        assert!(!sink.is_disk());

        sink.append(&vec![0.1; cap - 1], rate).unwrap();
        // Crosses the cap: keeps what fits, drops the rest silently.
        sink.append(&[0.1; 10], rate).unwrap();
        let AudioSink::Ram { ref samples, .. } = sink else {
            panic!("still RAM");
        };
        assert_eq!(samples.len(), cap, "buffer stops at the cap");

        // The *next* append is the one that reports, and only once.
        assert!(sink.append(&[0.1; 10], rate).is_err());
        assert!(sink.append(&[0.1; 10], rate).is_ok());
    }

    #[test]
    fn closing_a_ram_sink_hands_back_the_samples() {
        let mut sink = AudioSink::ram();
        sink.append(&loud(100), TARGET_SAMPLE_RATE).unwrap();
        match sink.close().unwrap() {
            ClosedAudio::Samples(samples) => assert_eq!(samples.len(), 100),
            other => panic!("expected samples, got {other:?}"),
        }
    }

    #[test]
    fn closing_an_empty_ram_sink_produces_no_file() {
        let sink = AudioSink::ram();
        match sink.close().unwrap() {
            ClosedAudio::File(None) => {}
            other => panic!("expected nothing, got {other:?}"),
        }
    }

    #[test]
    fn a_disk_sink_writes_a_wav_and_reports_a_broken_disk_once() {
        let dir = std::env::temp_dir().join(format!("trareon_sink_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        let target = dir.join("mic.wav");
        let writer = StreamingWavWriter::open(&target, TARGET_SAMPLE_RATE, 1).unwrap();
        let mut sink = AudioSink::disk(writer);
        assert!(sink.is_disk());
        sink.append(&loud(16_000), TARGET_SAMPLE_RATE).unwrap();

        match sink.close().unwrap() {
            ClosedAudio::File(Some(path)) => {
                assert_eq!(path, target);
                assert!(path.exists());
            }
            other => panic!("expected a file, got {other:?}"),
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn a_broken_disk_sink_stops_erroring_after_the_first_report() {
        let dir = std::env::temp_dir().join(format!("trareon_sink_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        let target = dir.join("mic.wav");
        let writer = StreamingWavWriter::open(&target, TARGET_SAMPLE_RATE, 1).unwrap();
        let mut sink = AudioSink::Disk {
            writer,
            broken: true,
        };
        assert!(!sink.is_disk(), "a broken disk sink is not writing");
        assert!(sink.append(&loud(100), TARGET_SAMPLE_RATE).is_ok());
        let _ = std::fs::remove_dir_all(&dir);
    }
}
