//! Rate-limited reporting for audio stream errors, with escalation to fatal.
//!
//! cpal delivers stream errors on the audio callback thread. On a device that
//! is broken rather than merely glitching, that callback fires as fast as the
//! backend can poll — a GUI smoke test on Linux/PipeWire produced **6.6
//! million identical `alsa::poll() returned POLLERR` lines, 1.5 GB of stderr,
//! in two minutes**. That is enough to fill a user's disk on its own, and
//! while it happened it starved the rest of the process badly enough that
//! session start appeared to hang.
//!
//! [`StreamErrorReporter`] turns such a burst into one log line plus at most
//! one "and N more" summary per [`SUMMARY_INTERVAL`], and escalates a
//! *persistent* error to [`ErrorAction::Fatal`] so the caller tears the
//! stream down and tells the user, instead of spinning forever.
//!
//! The policy is deliberately **message-independent**: rate limiting keyed on
//! the error text would be defeated by a device that alternates between two
//! errors, which is back to one log line per error. The caller still logs the
//! text it has; the reporter only decides *whether* to log.
//!
//! It is a pure function of the timestamps it is handed, so it is unit tested
//! with synthetic clocks and no audio device.

use std::time::{Duration, Instant};

/// After the first line, at most one summary line per interval.
#[flutter_rust_bridge::frb(ignore)]
pub const SUMMARY_INTERVAL: Duration = Duration::from_secs(5);

/// A stream that reports this many errors inside [`FATAL_WINDOW`] is broken,
/// not glitching: no working device produces 20 errors a second. Deliberately
/// well above what a handful of buffer xruns on a loaded machine would reach.
#[flutter_rust_bridge::frb(ignore)]
pub const FATAL_THRESHOLD: u32 = 100;

/// Sliding window for [`FATAL_THRESHOLD`]. Errors spaced further apart than
/// this restart the count, so occasional xruns over a long recording never
/// accumulate into a false "device is broken" verdict.
#[flutter_rust_bridge::frb(ignore)]
pub const FATAL_WINDOW: Duration = Duration::from_secs(5);

/// What the caller should do about one observed stream error.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[flutter_rust_bridge::frb(ignore)]
pub enum ErrorAction {
    /// Emit a log line for the error just observed. `suppressed` is how many
    /// errors were swallowed since the previous line (`0` on the first).
    Log { suppressed: u32 },
    /// Say nothing — a line was emitted very recently.
    Suppress,
    /// The stream is persistently failing: stop it and surface an error to
    /// the user. Emitted **exactly once**; every later error is `Suppress`,
    /// so a teardown race cannot produce a second error event.
    Fatal { total: u32 },
}

/// Collapses a burst of stream errors and decides when one has gone on long
/// enough to be fatal. Cheap enough to call from an audio callback: one
/// `Instant::now()` and a couple of comparisons in the common case.
#[derive(Debug)]
#[flutter_rust_bridge::frb(ignore)]
pub struct StreamErrorReporter {
    summary_interval: Duration,
    fatal_threshold: u32,
    fatal_window: Duration,
    /// Errors seen in the current window, including the one that opened it.
    count: u32,
    window_started: Instant,
    last_logged: Instant,
    logged_any: bool,
    suppressed: u32,
    fatal_emitted: bool,
}

impl StreamErrorReporter {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn new(now: Instant) -> Self {
        Self::with_policy(now, SUMMARY_INTERVAL, FATAL_THRESHOLD, FATAL_WINDOW)
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn with_policy(
        now: Instant,
        summary_interval: Duration,
        fatal_threshold: u32,
        fatal_window: Duration,
    ) -> Self {
        Self {
            summary_interval,
            fatal_threshold,
            fatal_window,
            count: 0,
            window_started: now,
            last_logged: now,
            logged_any: false,
            suppressed: 0,
            fatal_emitted: false,
        }
    }

    /// Records one stream error observed at `now` and returns what to do.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn observe(&mut self, now: Instant) -> ErrorAction {
        if self.fatal_emitted {
            return ErrorAction::Suppress;
        }

        if now.duration_since(self.window_started) > self.fatal_window {
            self.window_started = now;
            self.count = 0;
        }
        self.count += 1;
        if self.count >= self.fatal_threshold {
            self.fatal_emitted = true;
            return ErrorAction::Fatal { total: self.count };
        }

        if !self.logged_any || now.duration_since(self.last_logged) >= self.summary_interval {
            self.logged_any = true;
            self.last_logged = now;
            return ErrorAction::Log {
                suppressed: std::mem::take(&mut self.suppressed),
            };
        }

        self.suppressed += 1;
        ErrorAction::Suppress
    }
}

impl Default for StreamErrorReporter {
    fn default() -> Self {
        Self::new(Instant::now())
    }
}

/// User-facing (Indonesian) message for a capture stream that died mid-session.
///
/// `source` is the internal channel id (`"mic"` / `"spk"`), spelled out here
/// because the raw backend text ("`alsa::poll()` returned POLLERR") tells a
/// user nothing about which half of their recording just stopped.
#[flutter_rust_bridge::frb(ignore)]
pub fn fatal_stream_message(source: &str, backend_error: &str) -> String {
    let what = match source {
        "mic" => "Mikrofon",
        "spk" => "Audio sistem",
        other => other,
    };
    format!(
        "{what} berhenti merekam: perangkat audio terus melaporkan error \
         ({backend_error}). Sumber ini dimatikan agar rekaman lain tetap \
         berjalan — periksa perangkat audio di Pengaturan."
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn reporter() -> (StreamErrorReporter, Instant) {
        let t0 = Instant::now();
        (StreamErrorReporter::new(t0), t0)
    }

    #[test]
    fn first_error_is_logged() {
        let (mut r, t0) = reporter();
        assert_eq!(r.observe(t0), ErrorAction::Log { suppressed: 0 });
    }

    #[test]
    fn immediate_repeats_are_suppressed_not_logged() {
        let (mut r, t0) = reporter();
        r.observe(t0);
        for i in 1..10 {
            assert_eq!(
                r.observe(t0 + Duration::from_micros(i)),
                ErrorAction::Suppress,
                "repeat {i} should have been suppressed"
            );
        }
    }

    #[test]
    fn a_tight_loop_escalates_to_fatal_instead_of_flooding() {
        // The real bug: ~55_000 errors/second (6.6 M lines in two minutes).
        // At most one line may be emitted, and the stream must be declared
        // dead almost immediately.
        let (mut r, t0) = reporter();
        let mut logged = 0;
        let mut fatal_at = None;
        for i in 0..1_000_000u64 {
            // 55 kHz ≈ 18 µs apart.
            let now = t0 + Duration::from_micros(i * 18);
            match r.observe(now) {
                ErrorAction::Log { .. } => logged += 1,
                ErrorAction::Suppress => {}
                ErrorAction::Fatal { total } => {
                    fatal_at = Some((i, total));
                    break;
                }
            }
        }
        assert_eq!(logged, 1, "only the first occurrence should be logged");
        let (index, total) = fatal_at.expect("a tight error loop must become fatal");
        assert_eq!(total, FATAL_THRESHOLD);
        assert!(
            index < 200,
            "fatal should be reached within a few hundred errors, was {index}"
        );
    }

    #[test]
    fn fatal_is_emitted_exactly_once_and_silences_everything_after() {
        let (mut r, t0) = reporter();
        let mut fatals = 0;
        let mut logs_after_fatal = 0;
        for i in 0..10_000u64 {
            match r.observe(t0 + Duration::from_micros(i * 18)) {
                ErrorAction::Fatal { .. } => fatals += 1,
                ErrorAction::Log { .. } if fatals > 0 => logs_after_fatal += 1,
                _ => {}
            }
        }
        assert_eq!(fatals, 1);
        assert_eq!(logs_after_fatal, 0);
        // Still silent much later, while teardown is in flight.
        assert_eq!(
            r.observe(t0 + Duration::from_secs(60)),
            ErrorAction::Suppress
        );
    }

    #[test]
    fn a_slow_trickle_is_summarised_not_escalated() {
        // One error every 2 s: annoying, not fatal. Each summary line reports
        // how many were swallowed since the previous one.
        let (mut r, t0) = reporter();
        assert_eq!(r.observe(t0), ErrorAction::Log { suppressed: 0 });
        assert_eq!(
            r.observe(t0 + Duration::from_secs(2)),
            ErrorAction::Suppress
        );
        assert_eq!(
            r.observe(t0 + Duration::from_secs(4)),
            ErrorAction::Suppress
        );
        assert_eq!(
            r.observe(t0 + Duration::from_secs(6)),
            ErrorAction::Log { suppressed: 2 }
        );
    }

    #[test]
    fn occasional_xruns_over_a_long_session_never_become_fatal() {
        // One xrun every 10 s for three hours — a loaded machine, not a
        // broken device. Must never escalate, because escalation stops
        // that half of the recording.
        let (mut r, t0) = reporter();
        for i in 0..1_080u64 {
            let action = r.observe(t0 + Duration::from_secs(i * 10));
            assert!(
                !matches!(action, ErrorAction::Fatal { .. }),
                "escalated at xrun {i}"
            );
        }
    }

    #[test]
    fn logging_is_capped_at_one_line_per_interval_regardless_of_rate() {
        // 1 kHz of errors for a simulated minute, with escalation disabled,
        // must still produce at most one line per SUMMARY_INTERVAL.
        let t0 = Instant::now();
        let mut r = StreamErrorReporter::with_policy(t0, SUMMARY_INTERVAL, u32::MAX, FATAL_WINDOW);
        let mut logged = 0;
        for i in 0..60_000u64 {
            if let ErrorAction::Log { .. } = r.observe(t0 + Duration::from_millis(i)) {
                logged += 1;
            }
        }
        // 60 s / 5 s = 12 summaries, plus the first line.
        assert!(logged <= 13, "emitted {logged} lines for 60 s of errors");
        assert!(logged >= 12, "summaries stopped coming ({logged})");
    }

    #[test]
    fn fatal_message_names_the_source_in_indonesian() {
        let message = fatal_stream_message("mic", "`alsa::poll()` returned POLLERR");
        assert!(message.starts_with("Mikrofon"));
        assert!(message.contains("POLLERR"), "keep the backend detail");
        assert!(fatal_stream_message("spk", "x").starts_with("Audio sistem"));
    }
}
