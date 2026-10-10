//! Single source of truth for "which Whisper model should this device use
//! by default" (Sprint 14a). Before this module the answer was computed
//! twice — once in `setup_wizard_screen.dart` (`_suggestModel`, a hardcoded
//! RAM-only `if ramMb >= 8192 { turbo } else { base }`) and once implicitly
//! by whatever the user happened to pick in Settings — and neither read the
//! model catalog's own `min_ram_gb`, so a RAM threshold change in
//! `model::KNOWN_MODELS` would not change the recommendation.
//!
//! This does not re-decide the live-vs-accurate speed trade-off: that is
//! already adaptive HPT's job (`pipeline::route_for_rtf`), which benchmarks
//! the *installed* models at session start and switches between dual-pass
//! and direct-refine per device. What this module answers is upstream of
//! that: which model is accurate enough to be worth recommending as the
//! default in the first place, given the RAM actually available.

use crate::model::catalog_entry;

/// Word error rate on the FLEURS-id benchmark (687 utterances, measured
/// 2026-10-10; see `/home/kali/trareon-sprints/BASELINE_FLEURS.md`), for the
/// models this app can download. Lower is better. `cahya-medium-id` is
/// measured there too but is not in `model::KNOWN_MODELS` (no pinned
/// download), so it has no entry here — there is nothing to recommend it
/// as.
const FLEURS_WER: &[(&str, f32)] = &[
    ("large-v3-turbo-q5", 8.13),
    ("large-v3-turbo", 8.13), // same weights, unquantized
    ("small", 17.63),
    ("base", 36.68),
    ("tiny", 36.68), // no FLEURS-id measurement exists; base's figure is the
                     // closest honest upper bound rather than inventing one
];

/// Candidates considered for the default model, most accurate first. Only
/// entries actually present in `model::KNOWN_MODELS` are considered, so a
/// catalog change here never needs a second edit.
const CANDIDATES_BY_ACCURACY: &[&str] = &["large-v3-turbo-q5", "small", "base"];

/// RAM headroom added on top of a model's own `min_ram_gb`, in MB. The
/// catalog figure is model-weights-only; the OS, the Flutter UI, and the
/// rest of the pipeline (VAD, denoise, ring buffers) need room too, and a
/// recommendation that leaves no slack produces a thrashing, swapping
/// machine rather than a merely-slower one.
const RAM_HEADROOM_MB: u64 = 2048;

/// The most accurate model whose catalog `min_ram_gb` (plus headroom) fits
/// in `ram_mb`. Falls back to `"base"` (always bundled, `min_ram_gb: 1`)
/// when nothing else fits or the catalog entry is missing — `"base"` is the
/// one model this function must never fail to recommend, since it is also
/// the hardcoded fallback `AppSettings::default()` uses when no device
/// information is available at all.
///
/// Used both for the setup wizard's live-model suggestion and for the
/// file-import default: a file import has no real-time deadline, so
/// "most accurate that fits in RAM" is exactly the right answer there too
/// (the speed trade-off that live has is handled separately by adaptive
/// HPT and does not change which model fits in memory).
pub fn recommend_default_model(ram_mb: u64) -> &'static str {
    for &id in CANDIDATES_BY_ACCURACY {
        if model_fits(id, ram_mb) {
            return id;
        }
    }
    "base"
}

fn model_fits(id: &str, ram_mb: u64) -> bool {
    match catalog_entry(id) {
        Some(entry) => ram_mb >= entry.min_ram_gb as u64 * 1024 + RAM_HEADROOM_MB,
        None => false,
    }
}

/// A human-readable Indonesian accuracy label for `model_id`, sourced from
/// [`FLEURS_WER`] — e.g. `"WER FLEURS-id: 8,1%"` — or `None` when the model
/// has no measurement on file. Comma, not a period, for the decimal
/// separator: this app is Indonesian-first and every other number in the UI
/// already reads that way.
pub fn accuracy_label(model_id: &str) -> Option<String> {
    let (_, wer) = FLEURS_WER.iter().find(|(id, _)| *id == model_id)?;
    Some(format!("WER FLEURS-id: {}%", format_id_decimal(*wer)))
}

fn format_id_decimal(value: f32) -> String {
    format!("{value:.1}").replace('.', ",")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::KNOWN_MODELS;

    #[test]
    fn a_strong_device_gets_the_most_accurate_model() {
        // turbo-q5 needs 4 GB + 2 GB headroom = 6144 MB.
        assert_eq!(recommend_default_model(16_384), "large-v3-turbo-q5");
        assert_eq!(recommend_default_model(6_144), "large-v3-turbo-q5");
    }

    #[test]
    fn a_mid_device_gets_small_not_the_heaviest_model() {
        // small needs 2 GB + 2 GB headroom = 4096 MB, below turbo's 6144.
        assert_eq!(recommend_default_model(4_096), "small");
        assert_eq!(recommend_default_model(6_143), "small");
    }

    #[test]
    fn a_weak_device_falls_back_to_base() {
        assert_eq!(recommend_default_model(2_048), "base");
        assert_eq!(recommend_default_model(0), "base");
    }

    #[test]
    fn every_candidate_is_an_actual_catalog_entry() {
        for &id in CANDIDATES_BY_ACCURACY {
            assert!(
                KNOWN_MODELS.iter().any(|e| e.id == id),
                "{id} is recommended but not in the catalog"
            );
        }
    }

    #[test]
    fn accuracy_labels_use_indonesian_decimal_commas() {
        assert_eq!(
            accuracy_label("large-v3-turbo-q5"),
            Some("WER FLEURS-id: 8,1%".to_string())
        );
        assert_eq!(
            accuracy_label("base"),
            Some("WER FLEURS-id: 36,7%".to_string())
        );
    }

    #[test]
    fn an_unmeasured_model_has_no_label() {
        assert_eq!(accuracy_label("silero-vad"), None);
        assert_eq!(accuracy_label("does-not-exist"), None);
    }

    #[test]
    fn the_fallback_is_always_recommendable_from_zero_ram() {
        // base is the AppSettings::default() value when no device info is
        // known at all; it must always fit.
        assert_eq!(recommend_default_model(1), "base");
    }
}
