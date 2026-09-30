//! Crash-survivable streaming WAV writer.
//!
//! Captured audio used to live in `Vec<f32>` until the user pressed Stop:
//! 691 MB per source for a three-hour session, 1.38 GB for "Rapat Online",
//! and all of it gone on any crash. This writes each source straight to
//! disk as it arrives.
//!
//! **Why not `hound`.** A WAV header states the data length up front, and
//! a writer that only fixes it on a clean `finalize()` leaves a file that
//! says "0 samples" after a `kill -9` — the bytes are there, but nothing
//! will play them. So the header is written by hand and patched in two
//! places, and [`repair`] can do the same patch after the fact from the
//! file's own length. The batch/export path still uses `hound`, where the
//! whole buffer is known in advance.
//!
//! **Format.** 16-bit signed PCM, mono, at the capture rate — byte-for-byte
//! what `export::write_wav` produces, so a recovered recording is
//! indistinguishable from a cleanly-stopped one.
//!
//! **Naming.** In-flight files carry a `.part` suffix. A `.wav` in the
//! recovery directory therefore means "header is correct, safe to move",
//! and `.part` means "needs [`repair`] first" — no separate state file to
//! get out of sync with the bytes.

use std::fs::{File, OpenOptions};
use std::io::{Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use crate::error::TranscribeError;

/// Canonical PCM WAV header length: RIFF(12) + fmt (24) + data(8).
#[flutter_rust_bridge::frb(ignore)]
pub const WAV_HEADER_BYTES: u64 = 44;

const BITS_PER_SAMPLE: u16 = 16;
const BYTES_PER_SAMPLE: u64 = 2;

/// Same rationale as the transcript journal: flush every write so a
/// process crash loses nothing, `fsync` on an interval so a power cut
/// loses seconds rather than paying a barrier per 100 ms chunk.
#[flutter_rust_bridge::frb(ignore)]
pub const FSYNC_INTERVAL: Duration = Duration::from_secs(2);

/// The suffix an unfinalized recording carries.
#[flutter_rust_bridge::frb(ignore)]
pub const PART_EXTENSION: &str = "part";

fn header(sample_rate: u32, channels: u16, data_bytes: u32) -> [u8; WAV_HEADER_BYTES as usize] {
    let byte_rate = sample_rate * channels as u32 * BITS_PER_SAMPLE as u32 / 8;
    let block_align = channels * BITS_PER_SAMPLE / 8;
    let mut out = [0u8; WAV_HEADER_BYTES as usize];
    out[0..4].copy_from_slice(b"RIFF");
    out[4..8].copy_from_slice(&(36u32.saturating_add(data_bytes)).to_le_bytes());
    out[8..12].copy_from_slice(b"WAVE");
    out[12..16].copy_from_slice(b"fmt ");
    out[16..20].copy_from_slice(&16u32.to_le_bytes()); // PCM fmt chunk size
    out[20..22].copy_from_slice(&1u16.to_le_bytes()); // PCM
    out[22..24].copy_from_slice(&channels.to_le_bytes());
    out[24..28].copy_from_slice(&sample_rate.to_le_bytes());
    out[28..32].copy_from_slice(&byte_rate.to_le_bytes());
    out[32..34].copy_from_slice(&block_align.to_le_bytes());
    out[34..36].copy_from_slice(&BITS_PER_SAMPLE.to_le_bytes());
    out[36..40].copy_from_slice(b"data");
    out[40..44].copy_from_slice(&data_bytes.to_le_bytes());
    out
}

/// Appends 16-bit PCM to a `.part` file, patching the header on
/// [`finalize`](StreamingWavWriter::finalize).
#[flutter_rust_bridge::frb(ignore)]
pub struct StreamingWavWriter {
    file: File,
    part_path: PathBuf,
    final_path: PathBuf,
    sample_rate: u32,
    channels: u16,
    samples_written: u64,
    last_sync: Instant,
    scratch: Vec<u8>,
}

impl StreamingWavWriter {
    /// Creates (or reopens, for a recovered session) `<final_path>.part`.
    ///
    /// Reopening seeks to the end and keeps the samples already there, so a
    /// resumed recording produces one continuous file rather than orphaning
    /// what was captured before the crash.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn open(
        final_path: &Path,
        sample_rate: u32,
        channels: u16,
    ) -> Result<Self, TranscribeError> {
        if let Some(parent) = final_path.parent() {
            std::fs::create_dir_all(parent).map_err(TranscribeError::from)?;
        }
        let part_path = part_path_for(final_path);
        let existing_bytes = std::fs::metadata(&part_path)
            .map(|m| m.len())
            .unwrap_or(0)
            .saturating_sub(WAV_HEADER_BYTES);
        let mut file = OpenOptions::new()
            .create(true)
            .read(true)
            .write(true)
            .truncate(false)
            .open(&part_path)
            .map_err(TranscribeError::from)?;

        if existing_bytes == 0 {
            // Placeholder sizes; patched by `finalize` or `repair`.
            file.set_len(0).map_err(TranscribeError::from)?;
            file.write_all(&header(sample_rate, channels, 0))
                .map_err(TranscribeError::from)?;
            file.flush().map_err(TranscribeError::from)?;
        }
        file.seek(SeekFrom::End(0)).map_err(TranscribeError::from)?;

        Ok(Self {
            file,
            part_path,
            final_path: final_path.to_path_buf(),
            sample_rate,
            channels,
            samples_written: existing_bytes / BYTES_PER_SAMPLE,
            last_sync: Instant::now(),
            scratch: Vec::new(),
        })
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn samples_written(&self) -> u64 {
        self.samples_written
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn seconds_written(&self) -> f64 {
        if self.sample_rate == 0 || self.channels == 0 {
            return 0.0;
        }
        self.samples_written as f64 / (self.sample_rate as f64 * self.channels as f64)
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn part_path(&self) -> &Path {
        &self.part_path
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn append(&mut self, samples: &[f32]) -> Result<(), TranscribeError> {
        if samples.is_empty() {
            return Ok(());
        }
        self.scratch.clear();
        self.scratch.reserve(samples.len() * 2);
        for &sample in samples {
            let clamped = (sample.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
            self.scratch.extend_from_slice(&clamped.to_le_bytes());
        }
        self.file
            .write_all(&self.scratch)
            .map_err(TranscribeError::from)?;
        self.file.flush().map_err(TranscribeError::from)?;
        self.samples_written += samples.len() as u64;
        if self.last_sync.elapsed() >= FSYNC_INTERVAL {
            self.file.sync_data().map_err(TranscribeError::from)?;
            self.last_sync = Instant::now();
        }
        Ok(())
    }

    /// Patches the header, fsyncs, and renames `.part` to the final name.
    /// Returns the final path, or `None` when nothing was ever captured —
    /// an empty WAV is worse than no WAV, because the library would offer
    /// it for playback.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn finalize(mut self) -> Result<Option<PathBuf>, TranscribeError> {
        let data_bytes = self.samples_written * BYTES_PER_SAMPLE;
        patch_header(&mut self.file, self.sample_rate, self.channels, data_bytes)?;
        self.file.sync_all().map_err(TranscribeError::from)?;
        drop(self.file);

        if self.samples_written == 0 {
            let _ = std::fs::remove_file(&self.part_path);
            return Ok(None);
        }
        std::fs::rename(&self.part_path, &self.final_path).map_err(TranscribeError::from)?;
        Ok(Some(self.final_path.clone()))
    }
}

/// `foo.wav` -> `foo.wav.part`.
#[flutter_rust_bridge::frb(ignore)]
pub fn part_path_for(final_path: &Path) -> PathBuf {
    let mut name = final_path.as_os_str().to_os_string();
    name.push(".");
    name.push(PART_EXTENSION);
    PathBuf::from(name)
}

fn patch_header(
    file: &mut File,
    sample_rate: u32,
    channels: u16,
    data_bytes: u64,
) -> Result<(), TranscribeError> {
    let data_bytes = u32::try_from(data_bytes).unwrap_or(u32::MAX);
    file.seek(SeekFrom::Start(0))
        .map_err(TranscribeError::from)?;
    file.write_all(&header(sample_rate, channels, data_bytes))
        .map_err(TranscribeError::from)?;
    file.flush().map_err(TranscribeError::from)?;
    file.seek(SeekFrom::End(0)).map_err(TranscribeError::from)?;
    Ok(())
}

/// Turns a `.part` left behind by a crash into a playable WAV.
///
/// The length is taken from the file itself, so whatever reached the disk
/// is what you get back — this is the step that makes "kill -9 at minute
/// ninety" recoverable rather than merely "not lost on disk".
///
/// Returns the final path, or `None` if the file was header-only (nothing
/// was captured before the crash) or absent.
#[flutter_rust_bridge::frb(ignore)]
pub fn repair(
    part_path: &Path,
    final_path: &Path,
    sample_rate: u32,
    channels: u16,
) -> Result<Option<PathBuf>, TranscribeError> {
    let Ok(metadata) = std::fs::metadata(part_path) else {
        return Ok(None);
    };
    let data_bytes = metadata.len().saturating_sub(WAV_HEADER_BYTES);
    // Trailing odd byte: a write torn mid-sample. Dropping it keeps the
    // frame alignment the header promises.
    let data_bytes = data_bytes - (data_bytes % BYTES_PER_SAMPLE);
    if data_bytes == 0 {
        let _ = std::fs::remove_file(part_path);
        return Ok(None);
    }
    let mut file = OpenOptions::new()
        .read(true)
        .write(true)
        .open(part_path)
        .map_err(TranscribeError::from)?;
    file.set_len(WAV_HEADER_BYTES + data_bytes)
        .map_err(TranscribeError::from)?;
    patch_header(&mut file, sample_rate, channels, data_bytes)?;
    file.sync_all().map_err(TranscribeError::from)?;
    drop(file);
    std::fs::rename(part_path, final_path).map_err(TranscribeError::from)?;
    Ok(Some(final_path.to_path_buf()))
}

/// Seconds of audio a `.part` or finished WAV holds, from its length alone.
/// Used by the recovery dialog to say how much audio it is offering back
/// without reading the samples.
#[flutter_rust_bridge::frb(ignore)]
pub fn duration_secs(path: &Path, sample_rate: u32, channels: u16) -> f64 {
    let Ok(metadata) = std::fs::metadata(path) else {
        return 0.0;
    };
    if sample_rate == 0 || channels == 0 {
        return 0.0;
    }
    let data_bytes = metadata.len().saturating_sub(WAV_HEADER_BYTES);
    let frames = data_bytes / (BYTES_PER_SAMPLE * channels as u64);
    frames as f64 / sample_rate as f64
}

#[cfg(test)]
mod tests {
    use super::*;

    const RATE: u32 = 16_000;

    fn temp_dir() -> PathBuf {
        let dir = std::env::temp_dir().join(format!("trareon_wav_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn tone(samples: usize) -> Vec<f32> {
        (0..samples)
            .map(|i| ((i as f32) * 0.05).sin() * 0.5)
            .collect()
    }

    fn read_back(path: &Path) -> (hound::WavSpec, Vec<i16>) {
        let mut reader = hound::WavReader::open(path).expect("a valid WAV");
        let spec = reader.spec();
        let samples = reader.samples::<i16>().map(|s| s.unwrap()).collect();
        (spec, samples)
    }

    #[test]
    fn a_finalized_file_is_a_valid_wav_hound_can_read() {
        let dir = temp_dir();
        let target = dir.join("mic.wav");
        let mut writer = StreamingWavWriter::open(&target, RATE, 1).unwrap();
        writer.append(&tone(16_000)).unwrap();
        writer.append(&tone(8_000)).unwrap();
        let finalized = writer.finalize().unwrap().expect("samples were written");

        assert_eq!(finalized, target);
        assert!(!part_path_for(&target).exists(), ".part is renamed away");
        let (spec, samples) = read_back(&target);
        assert_eq!(spec.channels, 1);
        assert_eq!(spec.sample_rate, RATE);
        assert_eq!(spec.bits_per_sample, 16);
        assert_eq!(samples.len(), 24_000);
    }

    /// The whole point: the process dies without calling `finalize`, so the
    /// header still says zero — and the samples are recovered anyway.
    #[test]
    fn a_part_file_from_a_crash_is_repaired_to_a_playable_wav() {
        let dir = temp_dir();
        let target = dir.join("spk.wav");
        let mut writer = StreamingWavWriter::open(&target, RATE, 1).unwrap();
        writer.append(&tone(32_000)).unwrap();
        // No finalize(): simulate `kill -9`.
        std::mem::forget(writer);

        let part = part_path_for(&target);
        assert!(part.exists());
        let repaired = repair(&part, &target, RATE, 1).unwrap().expect("samples");
        assert_eq!(repaired, target);

        let (spec, samples) = read_back(&target);
        assert_eq!(spec.sample_rate, RATE);
        assert_eq!(samples.len(), 32_000, "two seconds of audio survived");
    }

    #[test]
    fn repair_drops_a_sample_torn_mid_write_rather_than_misaligning() {
        let dir = temp_dir();
        let target = dir.join("mic.wav");
        let mut writer = StreamingWavWriter::open(&target, RATE, 1).unwrap();
        writer.append(&tone(1_000)).unwrap();
        let part = writer.part_path().to_path_buf();
        std::mem::forget(writer);

        // One stray byte: the second half of a sample never made it.
        let mut raw = std::fs::read(&part).unwrap();
        raw.push(0x7f);
        std::fs::write(&part, raw).unwrap();

        repair(&part, &target, RATE, 1).unwrap().unwrap();
        let (_, samples) = read_back(&target);
        assert_eq!(samples.len(), 1_000);
    }

    #[test]
    fn a_session_that_captured_nothing_leaves_no_file_behind() {
        let dir = temp_dir();
        let target = dir.join("mic.wav");
        let writer = StreamingWavWriter::open(&target, RATE, 1).unwrap();
        assert_eq!(writer.finalize().unwrap(), None);
        assert!(!target.exists());
        assert!(!part_path_for(&target).exists());

        let target2 = dir.join("spk.wav");
        let writer2 = StreamingWavWriter::open(&target2, RATE, 1).unwrap();
        let part2 = writer2.part_path().to_path_buf();
        std::mem::forget(writer2);
        assert_eq!(repair(&part2, &target2, RATE, 1).unwrap(), None);
        assert!(!target2.exists());
    }

    /// A recovered session keeps recording into the same file, so the saved
    /// WAV holds the whole meeting and not just the part after the restart.
    #[test]
    fn reopening_a_part_file_continues_the_same_recording() {
        let dir = temp_dir();
        let target = dir.join("mic.wav");
        let mut first = StreamingWavWriter::open(&target, RATE, 1).unwrap();
        first.append(&tone(16_000)).unwrap();
        std::mem::forget(first);

        let mut resumed = StreamingWavWriter::open(&target, RATE, 1).unwrap();
        assert_eq!(resumed.samples_written(), 16_000, "picks up the tail");
        assert_eq!(resumed.seconds_written(), 1.0);
        resumed.append(&tone(16_000)).unwrap();
        resumed.finalize().unwrap().unwrap();

        let (_, samples) = read_back(&target);
        assert_eq!(samples.len(), 32_000);
    }

    #[test]
    fn duration_is_readable_from_the_file_length_alone() {
        let dir = temp_dir();
        let target = dir.join("mic.wav");
        let mut writer = StreamingWavWriter::open(&target, RATE, 1).unwrap();
        writer.append(&tone(24_000)).unwrap();
        let part = writer.part_path().to_path_buf();
        std::mem::forget(writer);

        assert!((duration_secs(&part, RATE, 1) - 1.5).abs() < 1e-9);
        assert_eq!(duration_secs(Path::new("/nope.wav"), RATE, 1), 0.0);
    }

    #[test]
    fn samples_round_trip_within_quantisation_error() {
        let dir = temp_dir();
        let target = dir.join("mic.wav");
        let mut writer = StreamingWavWriter::open(&target, RATE, 1).unwrap();
        let input = vec![0.0f32, 0.5, -0.5, 1.0, -1.0, 2.0, -2.0];
        writer.append(&input).unwrap();
        writer.finalize().unwrap().unwrap();

        let (_, samples) = read_back(&target);
        assert_eq!(samples[0], 0);
        assert!((samples[1] as f32 / i16::MAX as f32 - 0.5).abs() < 1e-3);
        assert_eq!(samples[3], i16::MAX, "clamped, not wrapped");
        assert_eq!(samples[5], i16::MAX, "out-of-range input is clamped");
        assert_eq!(samples[6], -i16::MAX);
    }
}
