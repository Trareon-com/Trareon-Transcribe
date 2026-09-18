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
pub fn run_checks(settings: &AppSettings) -> Vec<Check> {
    vec![
        check_library_path(settings),
        check_model_available(settings),
        check_config_dir_writable(),
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
                format!("cannot create {}: {}", path.display(), e),
                "check parent directory permissions",
            ),
        }
    } else if !path.is_dir() {
        Check::fail(
            "library_path",
            format!("{} exists but is not a directory", path.display()),
            "remove or rename the file and try again",
        )
    } else {
        // Writable check: try to create a temp file
        let probe = path.join(".traeon_write_probe");
        match std::fs::write(&probe, b"") {
            Ok(()) => {
                let _ = std::fs::remove_file(&probe);
                Check::ok("library_path")
            }
            Err(e) => Check::fail(
                "library_path",
                format!("{} is not writable: {}", path.display(), e),
                "check directory permissions",
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
                "model \"{}\" not found at {}",
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
                "no config directory available (dirs crate returned None)",
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
                    format!("{} is not writable: {}", dir.display(), e),
                    "check directory permissions",
                ),
            }
        }
        Err(e) => Check::fail(
            "config_dir",
            format!("cannot create {}: {}", dir.display(), e),
            "check parent directory permissions",
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
    fn run_checks_returns_three_checks() {
        let settings = AppSettings::default();
        let checks = run_checks(&settings);
        assert_eq!(checks.len(), 3);
        let names: Vec<&str> = checks.iter().map(|c| c.name.as_str()).collect();
        assert!(names.contains(&"library_path"));
        assert!(names.contains(&"model"));
        assert!(names.contains(&"config_dir"));
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
