//! "3 detik pertama": a short level measurement of the input before a
//! session starts (QUALITY-PROFILE-BLUEPRINT §5 phase 2, issue #69).
//!
//! The Dart quality resolver decides whether noise reduction and AGC help
//! this room from two numbers: how far speech sits above the noise floor
//! (SNR) and how loud the loudest moment is (peak). Both are measured here
//! from the same capture path a session uses, so the probe hears exactly
//! what the session would.
//!
//! The capture itself needs a real device; [`analyze`] is the pure part
//! and is what the unit tests cover.

use std::sync::mpsc;
use std::time::{Duration, Instant};

use crate::audio::capture::AudioCapture;
use crate::decode::TARGET_SAMPLE_RATE;
use crate::error::TranscribeError;
use crate::silence_gate::{peak, rms_dbfs};

/// Result of [`probe_input`].
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AudioProbe {
    /// Speech band (90th percentile frame level) minus noise floor (10th
    /// percentile), in dB. 0 when the input never rose above its floor.
    pub snr_db: f64,
    /// Loudest sample in dBFS. [`FLOOR_DBFS`] for digital silence.
    pub peak_dbfs: f64,
    /// Audio actually analysed, in milliseconds.
    pub ms: u32,
}

/// Level reported for digital silence instead of negative infinity, which
/// neither JSON nor the Dart side can carry. Well below any real room.
pub const FLOOR_DBFS: f64 = -100.0;

/// Frame length for the level distribution: 20 ms, short enough that a
/// pause between words is its own frame, long enough for a stable RMS.
const FRAME_MS: u32 = 20;

/// Shortest and longest probe the API accepts. Under half a second there
/// are too few frames for percentiles to mean anything; over ten seconds
/// the user is kept waiting before a recording they asked to start.
const MIN_MS: u32 = 500;
const MAX_MS: u32 = 10_000;

/// Measures `samples` (mono, [`TARGET_SAMPLE_RATE`]). Pure: no device.
pub fn analyze(samples: &[f32]) -> AudioProbe {
    let frame_len = (TARGET_SAMPLE_RATE * FRAME_MS / 1000) as usize;
    let ms = (samples.len() as u64 * 1000 / TARGET_SAMPLE_RATE as u64) as u32;

    let mut levels: Vec<f64> = samples
        .chunks(frame_len)
        .filter(|frame| frame.len() == frame_len)
        .map(|frame| clamp_db(rms_dbfs(frame)))
        .collect();
    let peak_dbfs = clamp_db(amplitude_to_db(peak(samples)));

    if levels.is_empty() {
        return AudioProbe {
            snr_db: 0.0,
            peak_dbfs,
            ms,
        };
    }
    levels.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let noise = percentile(&levels, 0.10);
    let speech = percentile(&levels, 0.90);

    AudioProbe {
        snr_db: (speech - noise).max(0.0),
        peak_dbfs,
        ms,
    }
}

/// Opens the input the way a session would, listens for `millis`
/// (clamped to 0.5–10 s), and measures it.
///
/// `device_name` is the saved device name, or `None` for the system
/// default. A failure here is reported to the caller, which starts the
/// session with the conservative defaults: a probe must never be the
/// reason a recording does not start.
pub fn probe_input(
    device_name: Option<String>,
    millis: u32,
) -> Result<AudioProbe, TranscribeError> {
    let millis = millis.clamp(MIN_MS, MAX_MS);
    let (tx, rx) = mpsc::channel::<Vec<f32>>();
    let mut capture = AudioCapture::start("mic", device_name, tx)?;

    let wanted = (TARGET_SAMPLE_RATE as u64 * millis as u64 / 1000) as usize;
    let deadline = Instant::now() + Duration::from_millis(millis as u64 + 1_000);
    let mut samples: Vec<f32> = Vec::with_capacity(wanted);
    while samples.len() < wanted {
        let left = deadline.saturating_duration_since(Instant::now());
        if left.is_zero() {
            break;
        }
        match rx.recv_timeout(left) {
            Ok(chunk) => samples.extend_from_slice(&chunk),
            Err(_) => break,
        }
    }
    capture.stop();

    if let Some(failure) = capture.take_failure() {
        return Err(TranscribeError::AudioDevice(failure));
    }
    if samples.is_empty() {
        return Err(TranscribeError::AudioDevice(
            "probe received no audio from the input device".into(),
        ));
    }
    samples.truncate(wanted);
    Ok(analyze(&samples))
}

fn amplitude_to_db(amplitude: f32) -> f32 {
    if amplitude <= 0.0 {
        f32::NEG_INFINITY
    } else {
        20.0 * amplitude.log10()
    }
}

fn clamp_db(db: f32) -> f64 {
    if db.is_finite() {
        (db as f64).max(FLOOR_DBFS)
    } else {
        FLOOR_DBFS
    }
}

/// Nearest-rank percentile of an ascending slice.
fn percentile(sorted: &[f64], p: f64) -> f64 {
    let rank = ((sorted.len() - 1) as f64 * p).round() as usize;
    sorted[rank.min(sorted.len() - 1)]
}

#[cfg(test)]
mod tests {
    use super::*;

    const RATE: usize = TARGET_SAMPLE_RATE as usize;

    /// A sine at `amplitude` (0..1) for `secs` seconds.
    fn tone(amplitude: f32, secs: f32) -> Vec<f32> {
        let n = (RATE as f32 * secs) as usize;
        (0..n)
            .map(|i| {
                amplitude * (2.0 * std::f32::consts::PI * 220.0 * i as f32 / RATE as f32).sin()
            })
            .collect()
    }

    /// Deterministic noise in [-amplitude, amplitude] (LCG, no rand crate).
    fn noise(amplitude: f32, secs: f32, seed: u32) -> Vec<f32> {
        let n = (RATE as f32 * secs) as usize;
        let mut state = seed;
        (0..n)
            .map(|_| {
                state = state.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
                (state as f32 / u32::MAX as f32 * 2.0 - 1.0) * amplitude
            })
            .collect()
    }

    fn mix(a: &[f32], b: &[f32]) -> Vec<f32> {
        a.iter().zip(b).map(|(x, y)| x + y).collect()
    }

    #[test]
    fn digital_silence_is_the_floor_not_infinity() {
        let probe = analyze(&vec![0.0; RATE * 3]);
        assert_eq!(probe.peak_dbfs, FLOOR_DBFS);
        assert_eq!(probe.snr_db, 0.0);
        assert_eq!(probe.ms, 3_000);
    }

    #[test]
    fn a_quiet_room_reads_near_minus_sixty() {
        // ~-60 dBFS RMS noise floor: uniform noise of amplitude a has RMS
        // a/sqrt(3); a = 0.00173 gives about -60 dBFS.
        let probe = analyze(&noise(0.001_73, 3.0, 7));
        assert!(probe.peak_dbfs < -50.0, "{probe:?}");
        assert!(
            probe.snr_db < 3.0,
            "steady noise has no speech band: {probe:?}"
        );
    }

    #[test]
    fn speech_over_a_clean_floor_has_a_high_snr() {
        // 1 s of "speech" (a -20 dBFS-ish tone) then 2 s of a -60 dBFS
        // floor, all over the same floor.
        let floor = noise(0.001_73, 3.0, 11);
        let mut signal = tone(0.14, 1.0);
        signal.extend(vec![0.0; RATE * 2]);
        let probe = analyze(&mix(&floor, &signal));
        assert!(probe.snr_db > 25.0, "{probe:?}");
        assert!(
            probe.peak_dbfs > -20.0 && probe.peak_dbfs < -15.0,
            "{probe:?}"
        );
    }

    #[test]
    fn speech_in_a_noisy_room_has_a_low_snr() {
        // Same speech, floor raised to about -30 dBFS.
        let floor = noise(0.055, 3.0, 13);
        let mut signal = tone(0.14, 1.0);
        signal.extend(vec![0.0; RATE * 2]);
        let probe = analyze(&mix(&floor, &signal));
        assert!(probe.snr_db < 15.0, "{probe:?}");
    }

    #[test]
    fn too_little_audio_still_answers() {
        let probe = analyze(&[0.5; 10]);
        assert_eq!(probe.snr_db, 0.0);
        assert!(probe.peak_dbfs > -7.0);
    }
}
