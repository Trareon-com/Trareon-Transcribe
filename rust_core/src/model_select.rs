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
    ("qwen3-asr-0.6b", 8.61),
    ("qwen3-asr-1.7b", 5.35),
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

// ============================================================================
// 6-option tier selector (Sprint 7, 2026-10-13) — the UI-facing unit, one
// level above `recommend_default_model`. A tier bundles an engine choice
// (whisper vs CrispASR) with a specific model size; `Auto` is the only
// tier that does not map to one fixed model — it resolves to one of the
// five manual tiers at session start based on device RAM (never GPU-only
// signals: a slow CPU fallback must still be usable).
//
// Design rules this type encodes (agreed with Master 2026-10-13):
//   1. A tier is picked ONCE per session (RAM+tier at session start).
//      There is no mid-session "found a better tier" swap — only an
//      emergency fallback to `Fast` (whisper) if the chosen engine fails
//      to load or crashes mid-session. Different sessions may pick
//      differently.
//   2. All 6 options are shown together, every time (Setup Wizard,
//      Settings, and the main-page chip) — never a hidden auto-pick
//      that silently substitutes CrispASR for whisper. `Auto` itself is
//      transparent: it always resolves to a *named* non-experimental
//      tier, which the UI should display once picked (e.g. "Otomatis
//      (Moderat)"), not leave as an opaque "Auto" forever.
//   3. The two "Eksperimental" tiers are CrispASR/Qwen3-ASR — never the
//      default, always an explicit opt-in, always falls back to `Fast`
//      (whisper `base`) on engine failure rather than surfacing a raw
//      crash to the user.
/// One of the 6 options shown in the tier selector UI (Setup Wizard,
/// Settings, and the main-page chip near "Mulai Rekam").
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum EngineTier {
    /// Resolves to one of the 5 manual tiers below at session start,
    /// based on device RAM — see [`EngineTier::resolve_auto`]. Shown as
    /// the recommended default in the UI.
    Auto,
    /// Whisper `base` — lightest, runs on almost anything.
    Fast,
    /// CrispASR / Qwen3-ASR-0.6B — same speed class as `Fast` but
    /// measurably more accurate on FLEURS-id (WER 8.61 vs base's 36.68);
    /// the only CrispASR variant that stays real-time on CPU alone.
    FastExperimental,
    /// Whisper `small`.
    Balanced,
    /// Whisper `large-v3-turbo-q5` — the non-experimental ceiling.
    Accurate,
    /// CrispASR / Qwen3-ASR-1.7B — best measured FLEURS-id accuracy of
    /// any candidate (WER 5.35), heavier and GPU-hungrier than
    /// `Accurate`.
    AccurateExperimental,
}

impl EngineTier {
    /// All 6 options, in the fixed display order the UI should always
    /// use (Otomatis first, then alternating Cepat/Moderat/Akurat with
    /// each tier's Eksperimental sibling directly after it).
    pub const ALL: [EngineTier; 6] = [
        EngineTier::Auto,
        EngineTier::Fast,
        EngineTier::FastExperimental,
        EngineTier::Balanced,
        EngineTier::Accurate,
        EngineTier::AccurateExperimental,
    ];

    /// Stable string key for persistence (settings file, CLI flags) —
    /// never the Indonesian label, which is allowed to be reworded.
    pub fn id(&self) -> &'static str {
        match self {
            EngineTier::Auto => "auto",
            EngineTier::Fast => "fast",
            EngineTier::FastExperimental => "fast_experimental",
            EngineTier::Balanced => "balanced",
            EngineTier::Accurate => "accurate",
            EngineTier::AccurateExperimental => "accurate_experimental",
        }
    }

    pub fn from_id(id: &str) -> Option<EngineTier> {
        EngineTier::ALL.into_iter().find(|t| t.id() == id)
    }

    /// Indonesian display label for the tier chip/list — intentionally
    /// does not repeat the word "mode" or "tingkat" since the UI already
    /// labels the whole control (e.g. "Kualitas Transkripsi").
    pub fn label_id(&self) -> &'static str {
        match self {
            EngineTier::Auto => "Otomatis",
            EngineTier::Fast => "Cepat",
            EngineTier::FastExperimental => "Cepat (Eksperimental)",
            EngineTier::Balanced => "Moderat",
            EngineTier::Accurate => "Akurat",
            EngineTier::AccurateExperimental => "Akurat (Eksperimental)",
        }
    }

    /// `true` for the two CrispASR/Qwen3-ASR tiers — the UI should badge
    /// these (e.g. a small flask icon) and the engine layer must never
    /// reach them except via an explicit user pick for the *current*
    /// session (rule 3 above). `Auto` is never itself experimental: it
    /// only ever resolves to a non-experimental tier.
    pub fn is_experimental(&self) -> bool {
        matches!(
            self,
            EngineTier::FastExperimental | EngineTier::AccurateExperimental
        )
    }

    /// `true` for the two CrispASR tiers — the engine construction code
    /// uses this to decide whether to build a `CrispAsrEngine` (via the
    /// `crispasr-experimental` feature) or the plain `WhisperEngine`.
    pub fn uses_crispasr(&self) -> bool {
        self.is_experimental()
    }

    /// Catalog id (`model::KNOWN_MODELS`) for this tier's model file.
    /// `None` only for `Auto`, which has no fixed model of its own —
    /// callers must resolve it first via [`EngineTier::resolve_auto`].
    pub fn model_catalog_id(&self) -> Option<&'static str> {
        match self {
            EngineTier::Auto => None,
            EngineTier::Fast => Some("base"),
            EngineTier::FastExperimental => Some("qwen3-asr-0.6b"),
            EngineTier::Balanced => Some("small"),
            EngineTier::Accurate => Some("large-v3-turbo-q5"),
            EngineTier::AccurateExperimental => Some("qwen3-asr-1.7b"),
        }
    }

    /// CrispASR CLI `--backend` value for this tier, or `None` for a
    /// whisper tier. Values confirmed against the shipped CLI's
    /// `--help` (2026-10-13): `qwen3` selects the 0.6B weights,
    /// `qwen3-1.7b` the 1.7B weights — this is NOT a model-size typo,
    /// CrispASR's own flag naming is simply inconsistent between the
    /// two sizes.
    pub fn crispasr_backend_flag(&self) -> Option<&'static str> {
        match self {
            EngineTier::FastExperimental => Some("qwen3"),
            EngineTier::AccurateExperimental => Some("qwen3-1.7b"),
            _ => None,
        }
    }

    /// Resolves `Auto` to a concrete, named tier for `ram_mb` of device
    /// RAM — reusing [`recommend_default_model`]'s thresholds so the two
    /// never drift apart. Always returns a non-experimental tier: `Auto`
    /// never silently hands the user a CrispASR engine they did not ask
    /// for. No-op (returns `self`) for any tier other than `Auto`.
    pub fn resolve_auto(&self, ram_mb: u64) -> EngineTier {
        if *self != EngineTier::Auto {
            return *self;
        }
        match recommend_default_model(ram_mb) {
            "large-v3-turbo-q5" => EngineTier::Accurate,
            "small" => EngineTier::Balanced,
            _ => EngineTier::Fast,
        }
    }

    /// The tier an experimental engine should fall back to if it fails
    /// to load or crashes mid-session (rule 1/3 above) — always `Fast`
    /// (whisper `base`), the one tier guaranteed to load on any device
    /// this app supports. A no-op for non-experimental tiers, since they
    /// have no fallback to perform.
    pub fn crash_fallback(&self) -> EngineTier {
        if self.is_experimental() {
            EngineTier::Fast
        } else {
            *self
        }
    }

    /// Reverse lookup used by `pipeline::LiveWorker::spawn` to decide
    /// whether a `LiveWorkerConfig::quick_model_path` is a CrispASR
    /// model (dispatch to [`crate::stt::CrispAsrStreamEngine`]) or a
    /// whisper one (the existing HPT/VAD path) — keyed on the model
    /// FILE NAME (`model::CatalogEntry::filename`), since that is what a
    /// `PathBuf` on disk actually carries; the catalog id alone is not
    /// recoverable from a path. Returns the matching tier's
    /// `crispasr_backend_flag()` directly since that is the only thing
    /// the caller needs from the match.
    pub fn crispasr_backend_flag_for_filename(filename: &str) -> Option<&'static str> {
        match filename {
            "qwen3-asr-0.6b-q4_k.gguf" => EngineTier::FastExperimental.crispasr_backend_flag(),
            "qwen3-asr-1.7b-q4_k.gguf" => EngineTier::AccurateExperimental.crispasr_backend_flag(),
            _ => None,
        }
    }
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

    #[test]
    fn every_tier_round_trips_through_its_id() {
        for tier in EngineTier::ALL {
            assert_eq!(EngineTier::from_id(tier.id()), Some(tier));
        }
        assert_eq!(EngineTier::from_id("does-not-exist"), None);
    }

    #[test]
    fn only_the_two_eksperimental_tiers_are_experimental() {
        let experimental: Vec<&str> = EngineTier::ALL
            .iter()
            .filter(|t| t.is_experimental())
            .map(|t| t.id())
            .collect();
        assert_eq!(
            experimental,
            vec!["fast_experimental", "accurate_experimental"]
        );
    }

    #[test]
    fn auto_never_resolves_to_itself_or_to_an_experimental_tier() {
        for ram_mb in [0, 1, 2_048, 4_096, 6_144, 16_384] {
            let resolved = EngineTier::Auto.resolve_auto(ram_mb);
            assert_ne!(resolved, EngineTier::Auto, "ram_mb={ram_mb}");
            assert!(!resolved.is_experimental(), "ram_mb={ram_mb}");
        }
    }

    #[test]
    fn resolve_auto_is_a_no_op_for_every_non_auto_tier() {
        for tier in EngineTier::ALL {
            if tier != EngineTier::Auto {
                assert_eq!(tier.resolve_auto(16_384), tier);
                assert_eq!(tier.resolve_auto(0), tier);
            }
        }
    }

    #[test]
    fn every_non_auto_tier_has_a_real_catalog_entry() {
        for tier in EngineTier::ALL {
            if let Some(id) = tier.model_catalog_id() {
                assert!(
                    KNOWN_MODELS.iter().any(|e| e.id == id),
                    "{} ({}) has no catalog entry",
                    tier.id(),
                    id
                );
            } else {
                assert_eq!(tier, EngineTier::Auto);
            }
        }
    }

    #[test]
    fn only_experimental_tiers_have_a_crispasr_backend_flag() {
        for tier in EngineTier::ALL {
            assert_eq!(
                tier.crispasr_backend_flag().is_some(),
                tier.is_experimental(),
                "{}",
                tier.id()
            );
        }
    }

    #[test]
    fn crash_fallback_only_changes_experimental_tiers_and_always_lands_on_fast() {
        for tier in EngineTier::ALL {
            let fallback = tier.crash_fallback();
            if tier.is_experimental() {
                assert_eq!(fallback, EngineTier::Fast);
            } else {
                assert_eq!(fallback, tier);
            }
        }
    }

    #[test]
    fn every_measured_tier_model_has_a_fleurs_accuracy_label() {
        // The two CrispASR variants must be labelled too, not just the
        // whisper ones already covered above.
        assert_eq!(
            accuracy_label("qwen3-asr-0.6b"),
            Some("WER FLEURS-id: 8,6%".to_string())
        );
        assert_eq!(
            accuracy_label("qwen3-asr-1.7b"),
            Some("WER FLEURS-id: 5,3%".to_string())
        );
    }
}
