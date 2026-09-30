//! Realtime-factor benchmark used by adaptive HPT to pick a live pipeline.

use std::sync::mpsc;
use std::time::{Duration, Instant};

use crate::stt::WhisperEngine;

/// Length of the synthetic clip the benchmark transcribes. RTF is
/// seconds-of-audio per second-of-wall-clock, so this is the numerator.
pub const BENCHMARK_AUDIO_SECS: f64 = 5.0;

/// Extra wall-clock allowed on top of the derived deadline, covering thread
/// start-up and scheduler jitter so a device sitting right on the threshold
/// isn't misclassified by a few hundred milliseconds.
const DEADLINE_GRACE: Duration = Duration::from_millis(1_000);

pub fn benchmark_rtf(engine: &WhisperEngine) -> f64 {
    let samples = benchmark_samples();
    let start = Instant::now();
    let _ = engine.transcribe_chunk(&samples, "benchmark", 0.0, Some("id"), None);
    let elapsed = start.elapsed().as_secs_f64();
    if elapsed == 0.0 {
        10.0
    } else {
        BENCHMARK_AUDIO_SECS / elapsed
    }
}

fn benchmark_samples() -> Vec<f32> {
    let count = (BENCHMARK_AUDIO_SECS * 16_000.0) as usize;
    (0..count)
        .map(|i| ((i as f32 / 16000.0) * 440.0 * 2.0 * std::f32::consts::PI).sin())
        .collect()
}

/// How long the benchmark may block session start before its answer is a
/// foregone conclusion.
///
/// Derived, not guessed. The benchmark exists only to answer "is
/// `rtf >= threshold`?". Once `BENCHMARK_AUDIO_SECS / threshold` seconds of
/// wall-clock have passed without a result, `rtf` is already below
/// `threshold` — the exact figure cannot change the decision, and waiting for
/// it only holds the UI's "Memulai…" button. On the 2-core laptop this was
/// measured on, `large-v3-turbo-q5` took **110 s** to finish the 5 s clip, and
/// "Rapat Online" paid that twice: `start_session` blocked for 221.8 s.
pub fn benchmark_deadline(threshold: f64) -> Duration {
    if threshold <= 0.0 {
        return Duration::MAX;
    }
    Duration::from_secs_f64(BENCHMARK_AUDIO_SECS / threshold) + DEADLINE_GRACE
}

/// Result of [`benchmark_rtf_bounded`].
pub enum BenchmarkOutcome {
    /// Finished within the deadline. The engine comes back so the caller can
    /// reuse it rather than loading the same ~550 MB model a second time.
    Measured { rtf: f64, engine: WhisperEngine },
    /// Still running at the deadline, so the device is below the threshold
    /// that produced that deadline. The engine stays with the detached
    /// benchmark thread, which finishes and drops it on its own.
    TooSlow,
}

/// Runs [`benchmark_rtf`] on its own thread and stops *waiting* for it at
/// `deadline`.
///
/// The benchmark itself cannot be cancelled — `whisper_full` has no interrupt
/// — so on the slow path one thread keeps running for however long the model
/// needs, then exits. That costs a core briefly on a machine that has already
/// been judged slow; blocking session start on it costs the user minutes of a
/// frozen button. Callers should cache the decision so this happens at most
/// once per process.
pub fn benchmark_rtf_bounded(engine: WhisperEngine, deadline: Duration) -> BenchmarkOutcome {
    let (tx, rx) = mpsc::channel::<(f64, WhisperEngine)>();
    std::thread::spawn(move || {
        let rtf = benchmark_rtf(&engine);
        // Fails when the caller has already given up; the engine is then
        // dropped here, which is exactly what should happen.
        let _ = tx.send((rtf, engine));
    });

    match rx.recv_timeout(deadline) {
        Ok((rtf, engine)) => BenchmarkOutcome::Measured { rtf, engine },
        Err(_) => BenchmarkOutcome::TooSlow,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pipeline::HPT_DIRECT_THRESHOLD;

    #[test]
    fn benchmark_sine_wave_is_five_seconds() {
        let samples = benchmark_samples();
        assert_eq!(samples.len(), 80_000);
        assert_eq!(samples.len() as f64 / 16_000.0, BENCHMARK_AUDIO_SECS);
    }

    #[test]
    fn the_deadline_is_the_point_past_which_the_answer_cannot_change() {
        // A device that hasn't finished 5 s of audio in 5/1.2 s is, by
        // definition, under the threshold.
        let deadline = benchmark_deadline(HPT_DIRECT_THRESHOLD);
        let derived = BENCHMARK_AUDIO_SECS / HPT_DIRECT_THRESHOLD;
        assert!(deadline.as_secs_f64() >= derived);
        assert!(
            deadline.as_secs_f64() <= derived + 2.0,
            "grace must stay small — it is dead time in front of the user"
        );
    }

    #[test]
    fn the_deadline_bounds_start_far_below_what_a_slow_device_actually_takes() {
        // The measured case: large-v3-turbo-q5 needed 110 s per benchmark,
        // and a Rapat Online start ran two of them.
        let deadline = benchmark_deadline(HPT_DIRECT_THRESHOLD).as_secs_f64();
        assert!(
            deadline < 10.0,
            "a {deadline}s deadline still freezes the record button"
        );
    }

    #[test]
    fn a_faster_threshold_demands_a_shorter_wait() {
        assert!(benchmark_deadline(4.0) < benchmark_deadline(1.2));
    }

    #[test]
    fn a_nonsensical_threshold_does_not_divide_by_zero() {
        assert_eq!(benchmark_deadline(0.0), Duration::MAX);
        assert_eq!(benchmark_deadline(-1.0), Duration::MAX);
    }
}
