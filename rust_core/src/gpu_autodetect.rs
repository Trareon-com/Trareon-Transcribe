//! Measured GPU-vs-CPU preference for whisper inference (Sprint 15/16).
//!
//! `settings.rs` made GPU strictly opt-in because a GPU with too little
//! VRAM for the model can be *slower* than CPU once weights spill out of
//! dedicated memory — a real risk, but one nobody had ever actually
//! measured on a concrete device. Cross-platform benchmarking for the
//! 3-tier model menu (`/home/kali/trareon-sprints/TIER_MODEL_DECISION.md`,
//! Oct 2026) measured the opposite empirically everywhere it was tried,
//! including the weakest device on hand — a 2017 Intel HD Graphics 630
//! iGPU, 12-20x faster than its own CPU despite neither beating RTF 1.0.
//!
//! Neither finding generalizes safely to "always on" or "always off": a
//! laptop's actual GPU could be anything. This module replaces both
//! assumptions with the thing this codebase already does for model choice
//! and live-pipeline routing (`model_select.rs`, `pipeline::route_for_rtf`)
//! — measure the *specific* device, once, at setup time, and act on the
//! number instead of a guess.

use std::path::Path;
use std::time::Duration;

use crate::benchmark::{benchmark_deadline, benchmark_rtf_bounded, BenchmarkOutcome};
use crate::pipeline::HPT_LIVE_FLOOR;
use crate::stt::WhisperEngine;

/// How long each of the two calibration attempts (CPU, GPU) may run before
/// being judged "too slow to matter" rather than timed precisely.
///
/// Reuses the live floor's own deadline (~6 s on `BENCHMARK_AUDIO_SECS =
/// 5.0`): the GPU/CPU choice only needs to know which side is faster, not
/// by how much, so there is no reason to let a slow device block setup for
/// the tens of seconds a full measurement would need (see `benchmark.rs`'s
/// own account of a 110 s run on a 2-core laptop).
fn calibration_deadline() -> Duration {
    benchmark_deadline(HPT_LIVE_FLOOR)
}

/// One side's calibration result, pared down to what [`prefer_gpu`] needs:
/// whether it finished in time, and if so, how fast.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum CalibrationResult {
    /// Finished within [`calibration_deadline`]; here is the RTF.
    Measured(f64),
    /// Did not finish in time — definitely below the live floor, but the
    /// exact number was never worth waiting for.
    TooSlow,
    /// The engine would not even load on this backend (missing GPU driver,
    /// no compatible device, model doesn't fit, etc).
    Unavailable,
}

/// Loads `model_path` with the given GPU setting and calibrates it, folding
/// a load failure into [`CalibrationResult::Unavailable`] so callers don't
/// need a separate error path for "no GPU here" vs "GPU here but slow".
fn calibrate(model_path: &Path, use_gpu: bool) -> CalibrationResult {
    let engine = match WhisperEngine::load_with_gpu(model_path, use_gpu, 0) {
        Ok(engine) => engine,
        Err(_) => return CalibrationResult::Unavailable,
    };
    match benchmark_rtf_bounded(engine, calibration_deadline()) {
        BenchmarkOutcome::Measured { rtf, .. } => CalibrationResult::Measured(rtf),
        BenchmarkOutcome::TooSlow => CalibrationResult::TooSlow,
    }
}

/// The measure-don't-assume decision at the center of this module, kept
/// pure and separate from engine loading so it is unit-testable without a
/// real model file or a real GPU (mirrors `pipeline::route_for_rtf`).
///
/// Rules, each one answering a question GPU vendor/VRAM heuristics cannot:
/// - GPU never loaded (`Unavailable`): no driver/device here, use CPU.
/// - Both measured: whichever RTF is strictly higher wins. A tie keeps the
///   existing CPU-only default — switching backends must earn its keep.
/// - GPU measured, CPU too slow to measure: GPU is strictly better evidence
///   than an unmeasured CPU number, take it.
/// - GPU too slow to measure, CPU measured: the VRAM-swap failure mode
///   `settings.rs` warned about, caught for real — keep CPU.
/// - Both too slow to measure: no evidence GPU helps on this device for
///   this model, and neither backend is live-capable anyway (a separate,
///   model-size problem `model_select.rs` already handles) — keep the
///   conservative default.
pub fn prefer_gpu(cpu: CalibrationResult, gpu: CalibrationResult) -> bool {
    match (cpu, gpu) {
        (_, CalibrationResult::Unavailable) => false,
        (CalibrationResult::Measured(c), CalibrationResult::Measured(g)) => g > c,
        (CalibrationResult::TooSlow, CalibrationResult::Measured(_)) => true,
        (CalibrationResult::Measured(_), CalibrationResult::TooSlow) => false,
        (CalibrationResult::TooSlow, CalibrationResult::TooSlow) => false,
        (CalibrationResult::Unavailable, _) => gpu != CalibrationResult::Unavailable,
    }
}

/// Runs the full measurement on `model_path` and returns whether GPU should
/// be enabled by default. Intended for a one-time setup-wizard check: two
/// bounded calibration runs, each capped at [`calibration_deadline`], so
/// the worst case is roughly 12 s rather than the minutes a full benchmark
/// on a slow device can take.
///
/// Errors only when the model file itself is unusable on *both* backends —
/// at that point the caller has a model problem, not a GPU-decision one.
pub fn recommend_gpu(model_path: &Path) -> bool {
    let cpu = calibrate(model_path, false);
    let gpu = calibrate(model_path, true);
    prefer_gpu(cpu, gpu)
}

#[cfg(test)]
mod tests {
    use super::*;
    use CalibrationResult::{Measured, TooSlow, Unavailable};

    #[test]
    fn no_gpu_backend_keeps_cpu() {
        assert!(!prefer_gpu(Measured(0.24), Unavailable));
        assert!(!prefer_gpu(TooSlow, Unavailable));
    }

    #[test]
    fn a_clearly_faster_gpu_wins() {
        // Kali's measured Intel HD 630 numbers: base CPU 0.03 vs GPU 0.37.
        assert!(prefer_gpu(Measured(0.03), Measured(0.37)));
        // RTX2060: base CPU 0.24 vs GPU 1.55.
        assert!(prefer_gpu(Measured(0.24), Measured(1.55)));
    }

    #[test]
    fn a_tie_keeps_the_existing_default() {
        assert!(!prefer_gpu(Measured(1.0), Measured(1.0)));
    }

    #[test]
    fn a_slower_gpu_loses_even_if_it_loaded() {
        // The VRAM-swap failure mode settings.rs was written to guard
        // against: GPU loads fine but is measurably worse than CPU.
        assert!(!prefer_gpu(Measured(2.0), Measured(0.5)));
    }

    #[test]
    fn gpu_finishing_while_cpu_times_out_is_strong_evidence_for_gpu() {
        assert!(prefer_gpu(TooSlow, Measured(0.1)));
    }

    #[test]
    fn cpu_finishing_while_gpu_times_out_is_the_warned_about_case() {
        assert!(!prefer_gpu(Measured(0.1), TooSlow));
    }

    #[test]
    fn neither_finishing_is_not_evidence_for_switching() {
        assert!(!prefer_gpu(TooSlow, TooSlow));
    }

    #[test]
    fn calibration_deadline_is_short_enough_for_a_setup_wizard() {
        // Two sequential calibrations must not turn "Memulai..." into a
        // minutes-long freeze the way an unbounded benchmark would.
        let total = calibration_deadline() * 2;
        assert!(
            total.as_secs_f64() < 15.0,
            "two calibrations take {total:?}, too slow for setup"
        );
    }
}
