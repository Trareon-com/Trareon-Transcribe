//! Whisper Contrastive Decoding (CD) helpers.
//!
//! Implements contrastive decoding helpers as described in:
//! Kim et al., "Contrastive Decoding: A Systematic Study of Human-like Summarization"
//!
//! Two-pass approach:
//! 1. Normal forward pass on original audio → "positive" logits
//! 2. Forward pass on time-shifted audio → "negative" logits
//! 3. Combine: `logits = positive - alpha * negative`, then greedily decode
//!
//! The intuition: negative logits suppress hallucinated tokens that correlate
//! with temporal artifacts in the audio features.
//!
//! Note: `WhisperCDEngine` has been removed as dead code. The actual
//! contrastive decoding logic lives in `WhisperEngine::transcribe_chunk_cd`
//! in `stt/mod.rs`.

/// Shift duration in seconds for negative audio generation.
const SHIFT_SECS: f64 = 1.0;

/// Generate "negative" audio for contrastive decoding: prepend silence, shift
/// audio forward by `shift_samples`, effectively misaligning the waveform with
/// the acoustic model and making the model "less certain".
///
/// Example: with 16000 Hz sample rate and 1s shift → 16000 zero samples prepended.
pub fn generate_shifted_negative(samples: &[f32], shift_samples: usize) -> Vec<f32> {
    let shift = shift_samples.min(samples.len());
    let mut neg = vec![0.0f32; shift];
    neg.extend_from_slice(&samples[..samples.len().saturating_sub(shift)]);
    neg
}

/// Contrastive decoding: combine positive and negative logits.
///
/// `positive_logits` — logits from normal forward pass
/// `negative_logits` — logits from shifted-negative forward pass
/// `alpha` — suppression weight; higher = more conservative output
///
/// Returns adjusted logits: `p[i] - alpha * n[i]` for each token position.
pub fn apply_cd_logits(positive_logits: &[f32], negative_logits: &[f32], alpha: f32) -> Vec<f32> {
    let min_len = positive_logits.len().min(negative_logits.len());
    positive_logits
        .iter()
        .zip(negative_logits.iter())
        .take(min_len)
        .map(|(p, n)| p - alpha * n)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_shifted_negative_prepends_silence() {
        let samples: Vec<f32> = (0..10).map(|i| i as f32).collect();
        let shifted = generate_shifted_negative(&samples, 3);
        assert_eq!(shifted.len(), 10);
        assert_eq!(&shifted[..3], &[0.0, 0.0, 0.0]); // silence prepended
        assert_eq!(&shifted[3..], &[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]); // truncated
    }

    #[test]
    fn generate_shifted_negative_truncates_short_audio() {
        let samples = vec![0.1f32, 0.2f32];
        let shifted = generate_shifted_negative(&samples, 5);
        // shift > len → full silence (clamped)
        assert!(shifted.iter().all(|&s| s == 0.0));
    }

    #[test]
    fn apply_cd_logits_subtracts_negative() {
        let pos = vec![1.0, 2.0, 3.0, 4.0];
        let neg = vec![0.5, 0.5, 0.5, 0.5];
        let result = apply_cd_logits(&pos, &neg, 1.0);
        assert_eq!(result, vec![0.5, 1.5, 2.5, 3.5]);
    }

    #[test]
    fn apply_cd_logits_with_alpha() {
        let pos = vec![1.0, 2.0, 3.0];
        let neg = vec![0.5, 0.5, 0.5];
        let result = apply_cd_logits(&pos, &neg, 0.5);
        assert_eq!(result, vec![0.75, 1.75, 2.75]);
    }

    #[test]
    fn apply_cd_logits_handles_mismatched_lengths() {
        let pos = vec![1.0, 2.0, 3.0, 4.0];
        let neg = vec![0.5, 0.5];
        let result = apply_cd_logits(&pos, &neg, 1.0);
        assert_eq!(result, vec![0.5, 1.5]); // truncated to min length
    }
}
