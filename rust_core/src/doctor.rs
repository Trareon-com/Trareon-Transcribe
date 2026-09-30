//! Doctor — pre-flight diagnostic checks before recording starts.
//!
//! Mirrors quill's `Doctor` pattern: check microphone permission,
//! library path writability, and model availability so the user
//! gets immediate feedback instead of a silent failure mid-session.

use std::path::PathBuf;

use crate::settings::AppSettings;

/// The outcome of a single diagnostic check.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CheckStatus {
    Ok,
    Warn(String),
    Fail(String),
}

/// One diagnostic check result with a human-readable remediation hint.
#[derive(Debug, Clone)]
pub struct Check {
    pub name: String,
    pub status: CheckStatus,
    pub remediation: Option<String>,
}

impl Check {
    pub fn ok(name: impl Into<String>) -> Self {
        Check {
            name: name.into(),
            status: CheckStatus::Ok,
            remediation: None,
        }
    }

    pub fn warn(name: impl Into<String>, msg: impl Into<String>) -> Self {
        Check {
            name: name.into(),
            status: CheckStatus::Warn(msg.into()),
            remediation: None,
        }
    }

    pub fn fail(name: impl Into<String>, msg: impl Into<String>, fix: impl Into<String>) -> Self {
        Check {
            name: name.into(),
            status: CheckStatus::Fail(msg.into()),
            remediation: Some(fix.into()),
        }
    }
}

/// Run all pre-flight checks and return the results.
///
/// Checks performed:
/// 1. Library path exists and is writable (output directory)
/// 2. Default model file exists on disk
/// 3. Config directory is writable (so settings can be saved)
/// 4. At least one input device is enumerable (no mic = silent recording)
/// 5. The library volume has room for a recording
///
/// Every message and remediation is in Indonesian: these strings are shown
/// verbatim in the app's "Diagnostik" screen and in the start-up preflight,
/// and mixing English error text into an Indonesian-first product is how
/// the audit found the rest of the copy drifting.
pub fn run_checks(settings: &AppSettings) -> Vec<Check> {
    vec![
        check_library_path(settings),
        check_model_available(settings),
        check_config_dir_writable(),
        check_audio_input(),
        check_free_space(settings),
    ]
}

/// Check that the library (output) directory exists and is writable.
fn check_library_path(settings: &AppSettings) -> Check {
    let path = PathBuf::from(&settings.library_path);
    if !path.exists() {
        match std::fs::create_dir_all(&path) {
            Ok(()) => Check::ok("library_path"),
            Err(e) => Check::fail(
                "library_path",
                format!("tidak bisa membuat {}: {}", path.display(), e),
                "Periksa izin folder induknya, atau pilih folder lain di Pengaturan → Folder output.",
            ),
        }
    } else if !path.is_dir() {
        Check::fail(
            "library_path",
            format!("{} ada, tapi bukan folder", path.display()),
            "Hapus atau ganti nama berkas itu, lalu coba lagi.",
        )
    } else {
        // Writable check: try to create a temp file
        let probe = path.join(".trareon_write_probe");
        match std::fs::write(&probe, b"") {
            Ok(()) => {
                let _ = std::fs::remove_file(&probe);
                Check::ok("library_path")
            }
            Err(e) => Check::fail(
                "library_path",
                format!("{} tidak bisa ditulis: {}", path.display(), e),
                "Periksa izin folder, atau pilih folder lain di Pengaturan → Folder output.",
            ),
        }
    }
}
/// Check that the default transcription model file exists on disk.
fn check_model_available(settings: &AppSettings) -> Check {
    let model_path = crate::model::resolve_model_path(
        std::path::Path::new(&settings.library_path),
        &settings.default_model,
    )
    .unwrap_or_else(|_| std::path::PathBuf::from(&settings.library_path));
    if model_path.exists() {
        Check::ok("model")
    } else {
        Check::warn(
            "model",
            format!(
                "model \"{}\" tidak ditemukan di {}",
                settings.default_model,
                model_path.display()
            ),
        )
    }
}

/// Check that the config directory (~/.config/TrareonTranscribe) is writable.
fn check_config_dir_writable() -> Check {
    let dir = match dirs::config_dir() {
        Some(d) => d.join("TrareonTranscribe"),
        None => {
            return Check::warn(
                "config_dir",
                "Sistem tidak melaporkan folder konfigurasi, jadi pengaturan mungkin tidak tersimpan.",
            );
        }
    };
    match std::fs::create_dir_all(&dir) {
        Ok(()) => {
            let probe = dir.join(".write_probe");
            match std::fs::write(&probe, b"") {
                Ok(()) => {
                    let _ = std::fs::remove_file(&probe);
                    Check::ok("config_dir")
                }
                Err(e) => Check::fail(
                    "config_dir",
                    format!("{} tidak bisa ditulis: {}", dir.display(), e),
                    "Periksa izin folder konfigurasi; tanpa itu pengaturan tidak akan tersimpan.",
                ),
            }
        }
        Err(e) => Check::fail(
            "config_dir",
            format!("tidak bisa membuat {}: {}", dir.display(), e),
            "Periksa izin folder induknya.",
        ),
    }
}

/// At least one input device must be enumerable, or a recording captures
/// silence with no visible error — the failure mode the capture-health
/// work in Sprint 1 was built around.
fn check_audio_input() -> Check {
    match crate::audio::device::list_input_devices() {
        Ok(devices) if !devices.is_empty() => Check::ok("audio_input"),
        Ok(_) => Check::fail(
            "audio_input",
            "Tidak ada perangkat masukan audio yang terdeteksi.",
            "Colokkan mikrofon, lalu beri Trareon izin mikrofon di pengaturan sistem.",
        ),
        Err(e) => Check::fail(
            "audio_input",
            format!("Daftar perangkat audio gagal dibaca: {e}"),
            "Pastikan layanan audio sistem (PipeWire/PulseAudio/CoreAudio/WASAPI) berjalan.",
        ),
    }
}

/// Free space on the library volume. Three hours of "Rapat Online" is
/// about 1,4 GB of WAV, and a full disk used to surface as a failed save
/// at the end of the meeting instead of a warning before it.
fn check_free_space(settings: &AppSettings) -> Check {
    let status = crate::disk::status_for(std::path::Path::new(&settings.library_path));
    match status.level {
        crate::disk::DiskSpaceLevel::Ok => Check::ok("disk_space"),
        crate::disk::DiskSpaceLevel::Low => Check::warn("disk_space", status.message),
        crate::disk::DiskSpaceLevel::Critical => Check::fail(
            "disk_space",
            status.message,
            "Kosongkan ruang disk, atau pindahkan folder output ke volume lain di Pengaturan.",
        ),
    }
}

/// Format checks for human-readable output (used by CLI and setup wizard).
pub fn format_checks(checks: &[Check]) -> String {
    let mut out = String::new();
    for c in checks {
        let mark = match c.status {
            CheckStatus::Ok => "✓",
            CheckStatus::Warn(_) => "!",
            CheckStatus::Fail(_) => "✗",
        };
        out.push_str(&format!("{} {}\n", mark, c.name));
        if let Some(ref fix) = c.remediation {
            out.push_str(&format!("    → {}\n", fix));
        }
    }
    out
}

/// Return true if all checks passed (no failures; warnings are OK).
pub fn all_ok(checks: &[Check]) -> bool {
    checks
        .iter()
        .all(|c| !matches!(c.status, CheckStatus::Fail(_)))
}

#[cfg(test)]
mod doctor_tests {
    use super::*;

    #[test]
    fn run_checks_covers_every_startup_dependency() {
        let settings = AppSettings::default();
        let checks = run_checks(&settings);
        let names: Vec<&str> = checks.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(
            names,
            [
                "library_path",
                "model",
                "config_dir",
                "audio_input",
                "disk_space"
            ]
        );
    }

    /// These strings are shown verbatim in the app, which is
    /// Indonesian-first. A regression here is an English sentence in front
    /// of the user, which is exactly what the audit catalogued.
    #[test]
    fn every_remediation_is_in_indonesian() {
        let settings = AppSettings::default();
        for check in run_checks(&settings) {
            if let Some(fix) = check.remediation {
                assert!(
                    !fix.is_empty() && fix.chars().next().unwrap().is_uppercase(),
                    "remediation for {} should be a sentence: {fix}",
                    check.name
                );
                for english in ["check ", "permissions", "directory", "try again"] {
                    assert!(
                        !fix.to_lowercase().contains(english),
                        "remediation for {} still reads as English: {fix}",
                        check.name
                    );
                }
            }
        }
    }

    #[test]
    fn format_checks_includes_marks() {
        let checks = vec![
            Check::ok("test"),
            Check::warn("test2", "be careful"),
            Check::fail("test3", "broken", "fix it"),
        ];
        let formatted = format_checks(&checks);
        assert!(formatted.contains("✓ test"));
        assert!(formatted.contains("! test2"));
        assert!(formatted.contains("✗ test3"));
        assert!(formatted.contains("→ fix it"));
    }

    #[test]
    fn all_ok_passes_with_warnings() {
        let checks = vec![Check::warn("test", "meh")];
        assert!(all_ok(&checks));
    }

    #[test]
    fn all_ok_fails_on_failure() {
        let checks = vec![Check::fail("test", "broken", "fix")];
        assert!(!all_ok(&checks));
    }
}
