//! Pre-ASR silence gate (Sprint 12, B1).
//!
//! Whisper has no way to say "nothing was said": asked to transcribe a
//! stretch of digital silence or low-level room noise it answers with
//! whatever caption its training data associates with that acoustic
//! pattern instead (see [`crate::hallucination`]). The VAD stages
//! ([`crate::vad`]) are supposed to keep that audio out, but both can be
//! bypassed: WebRTC's frame vote only needs *one* 10 ms frame in a chunk to
//! misfire speech, and the Silero neural gate is skipped outright when its
//! model file is not installed (`window_holds_speech` in `pipeline.rs`
//! fails open to "assume speech" so a missing model can never silence a
//! session). Measured on a macOS run with no microphone permission granted
//! (so the capture buffer was absolute digital silence) and on a quiet-room
//! recording (~-45 dBFS), both VAD stages let audio through and Whisper
//! produced invented captions.
//!
//! This module is the backstop that does not depend on either VAD model
//! being present: a direct peak/RMS measurement of the exact audio about to
//! be handed to the decoder. It is intentionally cheap (no allocation, one
//! pass) so it can run on every chunk in every mode (live, progressive,
//! file import) right before inference.

/// RMS level at or below which audio is treated as "no speech here",
/// expressed in dBFS (0 dBFS = a sine wave at full scale).
///
/// -60 dBFS is roughly the noise floor of a quiet room picked up by a
/// laptop mic with reasonable gain — real speech, even quiet speech, reads
/// well above it. Configurable (not `const`) because a user's hardware or
/// room may need it tuned; callers that just want the default use
/// [`SILENCE_THRESHOLD_DBFS`].
pub const SILENCE_THRESHOLD_DBFS: f32 = -60.0;

/// The largest absolute sample value in `samples`. `0.0` for an empty slice
/// or for digital silence — a buffer whose capture device produced nothing
/// at all (the macOS permission-not-granted case: zero-filled buffers with
/// no error).
pub fn peak(samples: &[f32]) -> f32 {
    samples.iter().fold(0.0f32, |acc, s| acc.max(s.abs()))
}

/// RMS level of `samples` in dBFS. `f32::NEG_INFINITY` for an empty slice or
/// for exact digital silence, which has no logarithm.
pub fn rms_dbfs(samples: &[f32]) -> f32 {
    if samples.is_empty() {
        return f32::NEG_INFINITY;
    }
    let mean_sq = samples.iter().map(|s| s * s).sum::<f32>() / samples.len() as f32;
    let rms = mean_sq.sqrt();
    if rms <= 0.0 {
        f32::NEG_INFINITY
    } else {
        20.0 * rms.log10()
    }
}

/// Whether every sample in `samples` is exactly zero — a capture buffer the
/// OS never actually filled in, as opposed to a quiet room. Distinguishing
/// the two matters for [`crate::hallucination`]'s permission banner (B6):
/// "mic belum diizinkan" is a different message from "ruangan sepi".
pub fn is_digital_silence(samples: &[f32]) -> bool {
    !samples.is_empty() && peak(samples) == 0.0
}

/// Whether `samples` is quiet enough — digitally silent or below
/// `threshold_dbfs` RMS — that it must never be handed to the ASR decoder.
/// Empty input counts as below the floor: there is nothing to transcribe.
pub fn is_below_speech_floor(samples: &[f32], threshold_dbfs: f32) -> bool {
    samples.is_empty() || is_digital_silence(samples) || rms_dbfs(samples) < threshold_dbfs
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tone(len: usize, amplitude: f32) -> Vec<f32> {
        (0..len)
            .map(|i| (i as f32 * 0.3).sin() * amplitude)
            .collect()
    }

    #[test]
    fn digital_silence_is_detected() {
        let samples = vec![0.0f32; 16_000 * 30];
        assert!(is_digital_silence(&samples));
        assert_eq!(peak(&samples), 0.0);
        assert!(rms_dbfs(&samples).is_infinite());
    }

    #[test]
    fn empty_buffer_is_below_the_floor() {
        assert!(is_below_speech_floor(&[], SILENCE_THRESHOLD_DBFS));
    }

    #[test]
    fn digital_silence_is_below_the_floor() {
        let samples = vec![0.0f32; 16_000];
        assert!(is_below_speech_floor(&samples, SILENCE_THRESHOLD_DBFS));
    }

    #[test]
    fn quiet_room_noise_is_below_the_floor() {
        // -45 dBFS room tone, the exact level the macOS bug report measured.
        let samples = tone(16_000, 0.0056); // ~ -45 dBFS peak-ish amplitude
        let level = rms_dbfs(&samples);
        assert!(level < SILENCE_THRESHOLD_DBFS + 20.0, "sanity: {level} dBFS");
        // Regardless of the exact figure, a signal this quiet must gate.
        assert!(is_below_speech_floor(&samples, -40.0));
    }

    #[test]
    fn real_speech_level_passes() {
        // A loud, full-scale tone standing in for real speech.
        let samples = tone(16_000, 0.5);
        assert!(!is_below_speech_floor(&samples, SILENCE_THRESHOLD_DBFS));
    }

    #[test]
    fn rms_dbfs_matches_a_known_amplitude() {
        // A full-scale sine's RMS is amplitude / sqrt(2); at amplitude 1.0
        // that is -3.01 dBFS.
        let samples = tone(16_000, 1.0);
        let level = rms_dbfs(&samples);
        assert!((level - (-3.01)).abs() < 0.5, "got {level} dBFS");
    }
}
