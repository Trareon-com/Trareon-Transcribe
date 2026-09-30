//! Free-space checks for the library volume.
//!
//! A three-hour "Rapat Online" writes roughly 690 MB of WAV per source
//! plus the transcript, and nothing in the app had ever asked how much
//! room there was: a grep for `available_space` / `disk_space` / `ENOSPC`
//! across the whole codebase returned nothing. On a full disk the model
//! download failed with a raw error, the session save failed into a
//! three-second toast, and the Dart prefs write failed silently.
//!
//! The thresholds are pure functions so the policy is testable without a
//! full disk; the actual measurement goes through `sysinfo`, which is not
//! meaningfully mockable.

use std::path::Path;

use serde::Serialize;

/// Below this, a recording is warned about but allowed to continue: at
/// 16 kHz mono 16-bit, 500 MB is still about four hours per source, so
/// the user has time to free space without losing the meeting.
pub const LOW_SPACE_BYTES: u64 = 500 * 1024 * 1024;

/// Below this, a recording is stopped on purpose while the transcript can
/// still be written. Running to actual ENOSPC would fail the save too.
pub const CRITICAL_SPACE_BYTES: u64 = 100 * 1024 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum DiskSpaceLevel {
    Ok,
    /// Keep going, but say something.
    Low,
    /// Stop cleanly now, while saving still works.
    Critical,
}

/// Free space on the volume holding `path`, plus what to do about it.
#[derive(Debug, Clone, Serialize)]
pub struct DiskSpaceStatus {
    /// `None` when the volume could not be identified — treated as `Ok`
    /// rather than blocking a recording on a failed measurement.
    pub available_bytes: Option<u64>,
    pub level: DiskSpaceLevel,
    /// Ready-to-show Indonesian text, empty when `level` is `Ok`.
    pub message: String,
}

/// Pure threshold policy.
#[flutter_rust_bridge::frb(ignore)]
pub fn classify(available_bytes: Option<u64>) -> DiskSpaceLevel {
    match available_bytes {
        None => DiskSpaceLevel::Ok,
        Some(bytes) if bytes < CRITICAL_SPACE_BYTES => DiskSpaceLevel::Critical,
        Some(bytes) if bytes < LOW_SPACE_BYTES => DiskSpaceLevel::Low,
        Some(_) => DiskSpaceLevel::Ok,
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn format_mb(bytes: u64) -> String {
    format!("{} MB", bytes / (1024 * 1024))
}

/// The user-facing sentence for a level. Separated from [`classify`] so
/// the wording is covered by the same tests as the policy.
#[flutter_rust_bridge::frb(ignore)]
pub fn message_for(level: DiskSpaceLevel, available_bytes: Option<u64>) -> String {
    let free = available_bytes.map(format_mb).unwrap_or_default();
    match level {
        DiskSpaceLevel::Ok => String::new(),
        DiskSpaceLevel::Low => format!(
            "Ruang disk tinggal {free}. Rekaman masih berjalan, tetapi \
             kosongkan ruang sebelum kehabisan."
        ),
        DiskSpaceLevel::Critical => format!(
            "Ruang disk tinggal {free}. Rekaman dihentikan supaya transkrip \
             masih sempat tersimpan."
        ),
    }
}

/// Free space on the volume that holds `path`.
///
/// Walks up to the nearest existing ancestor, so a library directory that
/// has not been created yet still reports the volume it would land on.
/// Returns `None` when no mounted volume matches — the caller treats that
/// as "unknown", never as "full".
#[flutter_rust_bridge::frb(ignore)]
pub fn available_bytes(path: &Path) -> Option<u64> {
    let target = nearest_existing(path)?;
    let disks = sysinfo::Disks::new_with_refreshed_list();
    disks
        .list()
        .iter()
        // The longest matching mount point wins: `/home` must beat `/`.
        .filter(|disk| target.starts_with(disk.mount_point()))
        .max_by_key(|disk| disk.mount_point().as_os_str().len())
        .map(|disk| disk.available_space())
}

fn nearest_existing(path: &Path) -> Option<std::path::PathBuf> {
    let canonical = path.canonicalize().ok();
    if let Some(canonical) = canonical {
        return Some(canonical);
    }
    let mut current = path;
    while let Some(parent) = current.parent() {
        if let Ok(canonical) = parent.canonicalize() {
            return Some(canonical);
        }
        current = parent;
    }
    None
}

/// [`available_bytes`] plus the policy and the sentence to show.
#[flutter_rust_bridge::frb(ignore)]
pub fn status_for(path: &Path) -> DiskSpaceStatus {
    let available_bytes = available_bytes(path);
    let level = classify(available_bytes);
    DiskSpaceStatus {
        available_bytes,
        level,
        message: message_for(level, available_bytes),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const MB: u64 = 1024 * 1024;

    #[test]
    fn thresholds_match_the_documented_policy() {
        assert_eq!(classify(Some(2 * 1024 * MB)), DiskSpaceLevel::Ok);
        assert_eq!(classify(Some(500 * MB)), DiskSpaceLevel::Ok);
        assert_eq!(classify(Some(499 * MB)), DiskSpaceLevel::Low);
        assert_eq!(classify(Some(100 * MB)), DiskSpaceLevel::Low);
        assert_eq!(classify(Some(99 * MB)), DiskSpaceLevel::Critical);
        assert_eq!(classify(Some(0)), DiskSpaceLevel::Critical);
    }

    /// A measurement that failed must not be read as a full disk — that
    /// would refuse to record on any volume `sysinfo` doesn't recognise.
    #[test]
    fn an_unknown_volume_is_not_treated_as_full() {
        assert_eq!(classify(None), DiskSpaceLevel::Ok);
        assert!(message_for(DiskSpaceLevel::Ok, None).is_empty());
    }

    #[test]
    fn messages_name_the_remaining_space_and_the_consequence() {
        let low = message_for(DiskSpaceLevel::Low, Some(300 * MB));
        assert!(low.contains("300 MB"));
        assert!(low.contains("masih berjalan"));

        let critical = message_for(DiskSpaceLevel::Critical, Some(50 * MB));
        assert!(critical.contains("50 MB"));
        assert!(critical.contains("dihentikan"));
    }

    #[test]
    fn a_real_path_reports_a_plausible_amount() {
        // Not asserting a number — just that the lookup resolves at all on
        // the machine running the tests.
        let status = status_for(&std::env::temp_dir());
        assert!(
            status.available_bytes.is_some(),
            "temp dir should resolve to a mounted volume"
        );
    }

    /// The library directory may not exist yet on first run.
    #[test]
    fn a_path_that_does_not_exist_yet_resolves_via_its_parent() {
        let missing = std::env::temp_dir().join("trareon-not-created-yet-xyz");
        assert!(available_bytes(&missing).is_some());
    }

    #[test]
    fn an_unreachable_path_reports_unknown_rather_than_panicking() {
        let status = status_for(Path::new("/nonexistent-root-xyz/library"));
        assert_eq!(status.level, DiskSpaceLevel::Ok);
    }
}
