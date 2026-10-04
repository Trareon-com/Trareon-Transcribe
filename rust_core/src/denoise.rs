//! Optional RNNoise denoising before ASR (F17).
//!
//! `preprocess` already does a DC blocker, an 80 Hz high-pass and a
//! normalise. Those help with rumble and quiet recordings and do nothing
//! at all about the noise that actually breaks Indonesian meeting audio:
//! a ceiling fan, an air conditioner, traffic through an open window,
//! keyboard clatter. RNNoise is a small recurrent model trained for
//! exactly that, and `nnnoiseless` is a pure-Rust port of it — no C
//! dependency, no download, nothing to send anywhere.
//!
//! # Why this is off by default
//!
//! Denoising is not free of risk. It is a learned suppressor, and on
//! already-clean speech it can thin consonants enough to cost a word.
//! Whether it helps is a property of the room, so it is a setting the
//! user turns on for their room rather than something decided for them.
//!
//! # Sample rates
//!
//! RNNoise is defined at 48 kHz in 10 ms frames and every decode path in
//! this app targets 16 kHz mono. So: upsample ×3, denoise, downsample ÷3.
//! Both conversions are linear interpolation rather than a polyphase
//! filter — the signal is band-limited to 8 kHz already, so the ×3
//! upsample invents nothing above Nyquist and the ÷3 has nothing to
//! alias. Using `rubato` here would be more correct in principle and
//! measurably slower for a difference no ASR model can see.
//!
//! The model also expects 16-bit-scaled floats (`[-32768, 32767]`), not
//! the `[-1, 1]` the rest of this crate uses; getting that wrong makes it
//! treat the whole recording as silence and return zeros, which is why
//! the scaling is spelled out rather than implied.

use std::sync::atomic::{AtomicBool, Ordering};

use nnnoiseless::DenoiseState;

/// Whether the ASR path should denoise.
///
/// A process-global rather than a parameter on `transcribe_chunk`,
/// because that call sits under three layers that have no business
/// knowing about audio settings, and the flight recorder's `set_enabled`
/// already established the pattern here. Set from the settings load/save
/// path so a change takes effect on the next chunk rather than the next
/// launch.
static ENABLED: AtomicBool = AtomicBool::new(false);

#[flutter_rust_bridge::frb(ignore)]
pub fn set_enabled(on: bool) {
    ENABLED.store(on, Ordering::Relaxed);
}

#[flutter_rust_bridge::frb(ignore)]
pub fn is_enabled() -> bool {
    ENABLED.load(Ordering::Relaxed)
}

/// 48 kHz / 16 kHz. The whole module exists in the gap between these.
const UPSAMPLE: usize = 3;

const I16_SCALE: f32 = 32_768.0;

/// Denoises 16 kHz mono PCM in `[-1, 1]`, returning the same length.
///
/// Returns the input unchanged when there is less than one RNNoise frame
/// of audio (10 ms at 48 kHz, i.e. 160 samples at 16 kHz): a fragment
/// that short carries no noise estimate worth having, and padding it out
/// would feed the model silence it would then fade in from.
pub fn denoise_16k(samples: &[f32]) -> Vec<f32> {
    let frame = DenoiseState::FRAME_SIZE;
    if samples.len() * UPSAMPLE < frame {
        return samples.to_vec();
    }

    let upsampled = resample_linear(samples, samples.len() * UPSAMPLE);

    let mut state = DenoiseState::new();
    let mut denoised = Vec::with_capacity(upsampled.len());
    let mut input = vec![0.0f32; frame];
    let mut output = vec![0.0f32; frame];

    for chunk in upsampled.chunks(frame) {
        // The tail is zero-padded to a full frame and then trimmed back
        // below, so the last few milliseconds of a recording are denoised
        // like the rest instead of being passed through raw.
        input[..chunk.len()].copy_from_slice(chunk);
        input[chunk.len()..].fill(0.0);
        for sample in input.iter_mut() {
            *sample *= I16_SCALE;
        }
        state.process_frame(&mut output, &input);
        denoised.extend(output.iter().map(|s| s / I16_SCALE));
    }
    denoised.truncate(upsampled.len());

    // RNNoise's first frame contains fade-in artifacts (its own docs say
    // so). Restoring the original there is better than shipping a
    // quarter-second of ramp into the ASR.
    let fade = frame.min(denoised.len());
    denoised[..fade].copy_from_slice(&upsampled[..fade]);

    let mut out = resample_linear(&denoised, samples.len());
    // Length is the contract: callers splice this back into a timeline
    // and a sample-count drift becomes a timestamp drift.
    out.resize(samples.len(), 0.0);
    out
}

/// Linear resample to exactly `target_len` samples.
fn resample_linear(samples: &[f32], target_len: usize) -> Vec<f32> {
    if samples.is_empty() || target_len == 0 {
        return Vec::new();
    }
    if samples.len() == target_len {
        return samples.to_vec();
    }
    if samples.len() == 1 {
        return vec![samples[0]; target_len];
    }
    let ratio = (samples.len() - 1) as f64 / (target_len - 1).max(1) as f64;
    (0..target_len)
        .map(|i| {
            let position = i as f64 * ratio;
            let low = position.floor() as usize;
            let high = (low + 1).min(samples.len() - 1);
            let fraction = (position - low as f64) as f32;
            samples[low] * (1.0 - fraction) + samples[high] * fraction
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rms(samples: &[f32]) -> f32 {
        if samples.is_empty() {
            return 0.0;
        }
        (samples.iter().map(|s| s * s).sum::<f32>() / samples.len() as f32).sqrt()
    }

    /// One second of a 300 Hz tone — a crude voiced-speech stand-in.
    fn tone(seconds: f32, hz: f32, amplitude: f32) -> Vec<f32> {
        let n = (16_000.0 * seconds) as usize;
        (0..n)
            .map(|i| (i as f32 * hz * 2.0 * std::f32::consts::PI / 16_000.0).sin() * amplitude)
            .collect()
    }

    /// Deterministic broadband noise. A fixed LCG rather than `rand`:
    /// a denoising test that passes or fails depending on the seed is
    /// not a test.
    fn noise(len: usize, amplitude: f32) -> Vec<f32> {
        let mut seed = 0x2545_F491_4F6C_DD1Du64;
        (0..len)
            .map(|_| {
                seed ^= seed << 13;
                seed ^= seed >> 7;
                seed ^= seed << 17;
                ((seed >> 40) as f32 / 2048.0 - 1.0) * amplitude
            })
            .collect()
    }

    #[test]
    fn the_switch_is_off_until_something_turns_it_on() {
        // Shipping with this on would change every existing install's
        // transcripts because the app updated.
        assert!(!is_enabled());
        set_enabled(true);
        assert!(is_enabled());
        set_enabled(false);
        assert!(!is_enabled());
    }

    #[test]
    fn length_is_preserved_exactly() {
        for len in [160, 1_000, 16_000, 24_321] {
            let input = tone(len as f32 / 16_000.0, 300.0, 0.3);
            assert_eq!(
                denoise_16k(&input).len(),
                input.len(),
                "length drift at {len} samples becomes a timestamp drift"
            );
        }
    }

    #[test]
    fn audio_too_short_to_denoise_is_returned_unchanged() {
        let tiny = vec![0.1, -0.1, 0.2];
        assert_eq!(denoise_16k(&tiny), tiny);
        assert!(denoise_16k(&[]).is_empty());
    }

    #[test]
    fn broadband_noise_is_attenuated() {
        let noisy = noise(16_000 * 2, 0.25);
        let cleaned = denoise_16k(&noisy);
        // Measured past the documented fade-in frame.
        let skip = DenoiseState::FRAME_SIZE;
        assert!(
            rms(&cleaned[skip..]) < rms(&noisy[skip..]) * 0.7,
            "noise RMS {} was not meaningfully reduced (was {})",
            rms(&cleaned[skip..]),
            rms(&noisy[skip..])
        );
    }

    #[test]
    fn a_voiced_tone_survives() {
        let speech = tone(2.0, 300.0, 0.3);
        let cleaned = denoise_16k(&speech);
        let skip = DenoiseState::FRAME_SIZE;
        // The suppressor is allowed to touch the level; it is not allowed
        // to delete the signal.
        assert!(
            rms(&cleaned[skip..]) > rms(&speech[skip..]) * 0.3,
            "the tone was all but removed: {} vs {}",
            rms(&cleaned[skip..]),
            rms(&speech[skip..])
        );
    }

    #[test]
    fn silence_stays_silent() {
        let cleaned = denoise_16k(&vec![0.0f32; 16_000]);
        assert!(
            rms(&cleaned) < 1e-4,
            "silence gained energy: {}",
            rms(&cleaned)
        );
    }

    #[test]
    fn resampling_round_trips_a_tone_closely() {
        let original = tone(0.5, 300.0, 0.3);
        let up = resample_linear(&original, original.len() * UPSAMPLE);
        let down = resample_linear(&up, original.len());
        assert_eq!(down.len(), original.len());
        let error: f32 = original
            .iter()
            .zip(&down)
            .map(|(a, b)| (a - b).abs())
            .fold(0.0, f32::max);
        assert!(error < 0.02, "round trip error {error} is too large");
    }

    #[test]
    fn resampling_handles_degenerate_inputs() {
        assert!(resample_linear(&[], 10).is_empty());
        assert!(resample_linear(&[1.0, 2.0], 0).is_empty());
        assert_eq!(resample_linear(&[0.5], 4), vec![0.5; 4]);
    }
}
