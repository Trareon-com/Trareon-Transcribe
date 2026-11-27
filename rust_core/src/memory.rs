//! Memory pressure detection for long sessions (>4h auto-split, PP-21).
//! The threshold check is pure logic (fully unit-tested); the actual
//! system read goes through `sysinfo`, which isn't meaningfully mockable
//! and isn't exercised in CI beyond "doesn't panic".

pub const MEMORY_PRESSURE_THRESHOLD: f32 = 0.8;

/// Ratio in [0.0, 1.0] of used/total system RAM.
pub fn system_memory_usage_ratio() -> f32 {
    use sysinfo::System;
    // sysinfo 0.40 returns `Err` on unsupported platforms: no reading
    // means no pressure signal, same as the `total == 0` case below.
    let Ok(mut sys) = System::new() else {
        return 0.0;
    };
    sys.refresh_memory();
    let total = sys.total_memory();
    if total == 0 {
        return 0.0;
    }
    sys.used_memory() as f32 / total as f32
}

pub fn is_under_memory_pressure(ratio: f32) -> bool {
    ratio >= MEMORY_PRESSURE_THRESHOLD
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn below_threshold_is_not_pressure() {
        assert!(!is_under_memory_pressure(0.5));
        assert!(!is_under_memory_pressure(0.79));
    }

    #[test]
    fn at_or_above_threshold_is_pressure() {
        assert!(is_under_memory_pressure(0.8));
        assert!(is_under_memory_pressure(0.95));
        assert!(is_under_memory_pressure(1.0));
    }

    #[test]
    fn system_memory_ratio_is_bounded_and_does_not_panic() {
        let ratio = system_memory_usage_ratio();
        assert!((0.0..=1.5).contains(&ratio), "ratio={ratio}");
    }
}
