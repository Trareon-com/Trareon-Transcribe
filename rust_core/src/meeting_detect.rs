//! F16 bagian A: deteksi window rapat video aktif (Zoom / Google Meet /
//! Microsoft Teams) agar aplikasi bisa menawarkan "Mulai rekam?" tanpa
//! pengguna harus membuka Trareon secara manual.
//!
//! Linux adalah satu-satunya platform dengan implementasi nyata di sprint
//! ini: `xdotool` sudah tersedia di sandbox pengembangan dan tidak butuh
//! permission OS tambahan. macOS dan Windows butuh API native
//! (Accessibility API / `NSWorkspace` di macOS, `EnumWindows` di Windows)
//! yang belum sempat diimplementasikan — lihat [`detect_active_meeting_window`]
//! untuk status per platform.

#[cfg(target_os = "linux")]
use std::process::Command;

/// Satu window rapat yang terdeteksi aktif (foreground) di OS.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DetectedMeeting {
    /// Nama aplikasi rapat yang cocok, mis. "Zoom", "Google Meet".
    pub app: String,
    /// Identifier window pada OS (di Linux: id window X11 sebagai string).
    /// Dipakai pemanggil untuk tidak menanyakan ulang untuk window yang
    /// sama selama window itu belum ditutup.
    pub window_id: String,
}

/// Mengembalikan rapat yang terdeteksi dari window yang sedang aktif
/// (foreground), atau `None` kalau tidak ada window rapat aktif.
///
/// Status per platform:
/// - **Linux**: nyata, lewat `xdotool` (lihat [`detect_linux`]).
/// - **macOS / Windows**: belum diimplementasikan. Selalu mengembalikan
///   `None`. TODO: macOS via Accessibility API/`NSWorkspace` (butuh izin
///   Accessibility dari pengguna — harus didokumentasikan di
///   `docs/PRIVACY-REPORT.md` sebelum diaktifkan); Windows via
///   `EnumWindows`+`GetWindowTextW` (`windows-rs`).
pub fn detect_active_meeting_window() -> Option<DetectedMeeting> {
    #[cfg(target_os = "linux")]
    {
        detect_linux()
    }
    #[cfg(not(target_os = "linux"))]
    {
        None
    }
}

#[cfg(target_os = "linux")]
fn detect_linux() -> Option<DetectedMeeting> {
    let window_id = run_xdotool(&["getactivewindow"])?;
    let title = run_xdotool(&["getactivewindow", "getwindowname"])?;
    classify_title(&title).map(|app| DetectedMeeting {
        app: app.to_string(),
        window_id,
    })
}

#[cfg(target_os = "linux")]
fn run_xdotool(args: &[&str]) -> Option<String> {
    let output = Command::new("xdotool").args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if text.is_empty() {
        None
    } else {
        Some(text)
    }
}

/// Klasifikasi judul window menjadi nama aplikasi rapat, atau `None` kalau
/// judulnya tidak cocok dengan pola rapat yang dikenal. Dipisah dari
/// pemanggilan `xdotool` agar bisa diuji tanpa X server.
///
/// Hanya dipanggil dari [`detect_linux`] (satu-satunya implementasi nyata
/// saat ini); di-cfg-gate sama seperti pemanggilnya supaya build macOS/
/// Windows tidak memunculkan warning "function is never used" untuk kode
/// yang memang sengaja belum aktif di platform itu.
#[cfg(target_os = "linux")]
fn classify_title(title: &str) -> Option<&'static str> {
    let lower = title.to_lowercase();
    if lower.contains("zoom meeting") {
        Some("Zoom")
    } else if lower.contains("google meet") || lower.contains("meet.google.com") {
        Some("Google Meet")
    } else if lower.contains("microsoft teams") {
        Some("Microsoft Teams")
    } else {
        None
    }
}

// Semua test di modul ini memanggil `classify_title`, yang hanya ada di
// build Linux (lihat cfg-gate di atas) — modul test ikut di-gate supaya
// `cargo test` di macOS/Windows tidak gagal compile karena simbol hilang.
#[cfg(all(test, target_os = "linux"))]
mod tests {
    use super::*;

    #[test]
    fn classifies_zoom_window_title() {
        assert_eq!(classify_title("Zoom Meeting"), Some("Zoom"));
        assert_eq!(classify_title("zoom meeting - 15:30"), Some("Zoom"));
    }

    #[test]
    fn classifies_google_meet_tab_title() {
        assert_eq!(
            classify_title("Rapat Sprint 17 - Google Meet - Chromium"),
            Some("Google Meet")
        );
        assert_eq!(
            classify_title("meet.google.com/abc-defg-hij - Firefox"),
            Some("Google Meet")
        );
    }

    #[test]
    fn classifies_teams_window_title() {
        assert_eq!(
            classify_title("Rapat Tim | Microsoft Teams"),
            Some("Microsoft Teams")
        );
    }

    #[test]
    fn unrelated_window_titles_do_not_match() {
        assert_eq!(classify_title("Visual Studio Code"), None);
        assert_eq!(classify_title("Trareon Transcribe"), None);
        assert_eq!(classify_title(""), None);
    }

    #[test]
    fn classification_is_case_insensitive() {
        assert_eq!(classify_title("ZOOM MEETING"), Some("Zoom"));
    }
}
