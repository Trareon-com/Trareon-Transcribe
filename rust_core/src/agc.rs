//! Pre-VAD/ASR automatic gain (Sprint 14a item 9).
//!
//! Mac test finding (10 Okt 2026): speech captured quietly (mic volume 12,
//! ~-37 dBFS at the mic) lost 5 of 6 sentences to the VAD stages — only
//! loud speech (~-34 dBFS) made it through in full. [`silence_gate`] does
//! not explain this: its floor is -60 dBFS, and -37 dBFS is well above it.
//! The actual sensitivity lives in webrtc-vad's own classifier, which (like
//! most spectral VADs) degrades at low amplitude independently of
//! [`crate::vad::EnergyDetector`]'s confirmation threshold.
//!
//! This module raises quiet-but-real audio into the range the VAD stages
//! were tuned for *before* either one sees it, rather than trying to lower
//! every threshold downstream (which would also let more noise through).
//!
//! # Why this does not just amplify everything quiet
//!
//! A pure-noise fixture and a quiet-speech fixture can sit at the exact
//! same RMS level — level alone cannot tell them apart, so a gain large
//! enough to rescue -45 dBFS speech necessarily also raises -45 dBFS noise
//! by the same amount. Two choices keep that from becoming new
//! hallucinations: the gain is capped well short of making a boosted
//! sample read as full-scale speech ([`MAX_GAIN_DB`], target ceiling
//! [`TARGET_DBFS`] of only -30 dBFS, not 0), and anything already below
//! [`crate::silence_gate::SILENCE_THRESHOLD_DBFS`] is left alone entirely
//! — that gate already owns the "this is not speech" decision for the
//! quietest tier, and boosting right up to its boundary would just move
//! the false positives rather than remove them.
//!
//! What this does **not** do: distinguish a quiet voice from quiet
//! broadband noise sitting at the same level between the floor and the
//! target — no level-only measurement can. The -45 dBFS floor target in
//! the Sprint 14a brief assumes real speech's harmonic structure still
//! gives Whisper (and WebRTC's spectral classifier) something to key on
//! once it is merely loud enough to clear the amplitude cliff; this module
//! only gets it there.

use crate::silence_gate::{rms_dbfs, SILENCE_THRESHOLD_DBFS};

/// RMS level this module tries to bring quiet audio up to. Chosen well
/// clear of webrtc-vad's practical sensitivity floor (empirically well
/// below -34 dBFS) without pushing boosted noise anywhere near a level
/// that reads as confident speech.
pub const TARGET_DBFS: f32 = -30.0;

/// Largest boost ever applied, in dB. 20 dB is 10x in amplitude — enough to
/// carry -50 dBFS up to the target, but capped so a near-floor sample
/// (just above [`SILENCE_THRESHOLD_DBFS`]) cannot be amplified into
/// something that reads as loud, clean speech.
pub const MAX_GAIN_DB: f32 = 20.0;

/// Returns `samples` unchanged if it is already at/above [`TARGET_DBFS`] or
/// at/below [`SILENCE_THRESHOLD_DBFS`] (nothing to safely boost); otherwise
/// a gain-adjusted copy, clamped to `[-1.0, 1.0]` so boosting never
/// introduces clipping distortion.
pub fn apply_gain(samples: &[f32]) -> Vec<f32> {
    let level = rms_dbfs(samples);
    if !level.is_finite() || level <= SILENCE_THRESHOLD_DBFS || level >= TARGET_DBFS {
        return samples.to_vec();
    }
    let gain_db = (TARGET_DBFS - level).min(MAX_GAIN_DB);
    let gain = 10f32.powf(gain_db / 20.0);
    samples
        .iter()
        .map(|s| (s * gain).clamp(-1.0, 1.0))
        .collect()
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
    fn quiet_speech_level_tone_is_boosted_toward_the_target() {
        // ~-45 dBFS, the Sprint 14a brief's target floor.
        let samples = tone(16_000, 0.0056);
        let before = rms_dbfs(&samples);
        assert!(before < -40.0, "sanity: {before} dBFS");

        let boosted = apply_gain(&samples);
        let after = rms_dbfs(&boosted);
        assert!(
            after > before + 5.0,
            "expected real boost, before={before} after={after}"
        );
        assert!(
            after <= TARGET_DBFS + 0.5,
            "must not overshoot the target: {after} dBFS"
        );
    }

    #[test]
    fn already_loud_speech_is_left_alone() {
        let samples = tone(16_000, 0.5); // well above TARGET_DBFS
        let boosted = apply_gain(&samples);
        assert_eq!(boosted, samples);
    }

    #[test]
    fn digital_silence_is_left_alone() {
        let samples = vec![0.0f32; 16_000];
        let boosted = apply_gain(&samples);
        assert!(boosted.iter().all(|&s| s == 0.0));
    }

    #[test]
    fn noise_at_or_below_the_silence_floor_is_not_boosted() {
        // Exactly the quiet-room-noise case silence_gate already owns.
        let samples = tone(16_000, 0.0008); // well under -60 dBFS
        let level = rms_dbfs(&samples);
        assert!(level <= SILENCE_THRESHOLD_DBFS, "sanity: {level} dBFS");
        let boosted = apply_gain(&samples);
        assert_eq!(
            boosted, samples,
            "must not amplify audio the floor already gates"
        );
    }

    #[test]
    fn gain_is_capped_near_the_silence_floor() {
        // Just above the floor: a naive gain-to-target here would be huge.
        let samples = tone(16_000, 0.0019); // just above -60 dBFS
        let before = rms_dbfs(&samples);
        assert!(
            before > SILENCE_THRESHOLD_DBFS && before < -55.0,
            "sanity: {before} dBFS"
        );
        let boosted = apply_gain(&samples);
        let after = rms_dbfs(&boosted);
        assert!(
            after - before <= MAX_GAIN_DB + 0.5,
            "gain exceeded the cap: {before} -> {after} dBFS"
        );
    }

    #[test]
    fn output_never_clips_beyond_full_scale() {
        let samples = tone(16_000, 0.03); // moderately quiet
        let boosted = apply_gain(&samples);
        assert!(boosted.iter().all(|&s| (-1.0..=1.0).contains(&s)));
    }

    #[test]
    fn empty_input_is_handled() {
        assert_eq!(apply_gain(&[]), Vec::<f32>::new());
    }
}
