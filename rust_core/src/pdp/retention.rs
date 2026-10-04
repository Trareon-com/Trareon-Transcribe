//! Retention policy (F13): delete what is older than the organisation
//! says it may keep.
//!
//! Audio and transcript have separate clocks on purpose. The recording is
//! the sensitive artifact — it carries voices, background conversation,
//! and whatever someone said before realising they were being recorded —
//! and most retention rules want it gone long before the minutes are. A
//! single "delete sessions after N days" switch forces the user to choose
//! between keeping the minutes and keeping the recording, which is not a
//! choice the law asks them to make.
//!
//! Everything here is a *plan*. Nothing in this module deletes anything:
//! [`plan`] is pure, the caller shows it to the user, and only an explicit
//! confirmation runs [`apply`]. Automatic deletion that the user finds out
//! about afterwards is indistinguishable from data loss.

use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::error::TranscribeError;

/// Seconds in a day.
const DAY_SECS: u64 = 86_400;

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
pub struct RetentionPolicy {
    /// Delete captured audio older than this many days. `0` = keep
    /// forever, which is the default and must stay the default.
    pub audio_days: u32,
    /// Delete the transcript (and the whole session folder with it) older
    /// than this many days. `0` = keep forever.
    pub transcript_days: u32,
}

impl RetentionPolicy {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn is_noop(&self) -> bool {
        self.audio_days == 0 && self.transcript_days == 0
    }
}

/// One session as the planner sees it. Deliberately not a `SessionRecord`:
/// the planner must be testable without a library on disk.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionAge {
    pub dir_path: String,
    pub title: String,
    /// When the session was recorded, in milliseconds since the epoch.
    pub recorded_at_unix_ms: u64,
    /// Captured audio files inside the session folder.
    pub audio_paths: Vec<String>,
    pub audio_bytes: u64,
}

/// What would be deleted, and why.
#[derive(Debug, Clone, Default, Serialize)]
pub struct RetentionPlan {
    /// Audio files to delete, leaving the transcript behind.
    pub audio_to_delete: Vec<RetentionItem>,
    /// Whole session folders to delete.
    pub sessions_to_delete: Vec<RetentionItem>,
    /// Bytes the audio deletions would free.
    pub audio_bytes_freed: u64,
}

impl RetentionPlan {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn is_empty(&self) -> bool {
        self.audio_to_delete.is_empty() && self.sessions_to_delete.is_empty()
    }

    /// One Indonesian line for the confirmation dialog.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn summary(&self) -> String {
        if self.is_empty() {
            return "Tidak ada yang melewati batas retensi.".to_string();
        }
        let mut parts = Vec::new();
        if !self.sessions_to_delete.is_empty() {
            parts.push(format!(
                "{} sesi akan dihapus seluruhnya",
                self.sessions_to_delete.len()
            ));
        }
        if !self.audio_to_delete.is_empty() {
            parts.push(format!(
                "{} berkas audio akan dihapus ({})",
                self.audio_to_delete.len(),
                human_bytes(self.audio_bytes_freed)
            ));
        }
        format!(
            "{}. Transkrip yang tidak disebut tetap disimpan.",
            parts.join("; ")
        )
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct RetentionItem {
    pub path: String,
    pub title: String,
    /// How many days past the limit it is, for the preview.
    pub age_days: u32,
    pub bytes: u64,
}

/// What `policy` would delete from `sessions` at `now_unix_ms`.
///
/// A session whose whole folder goes is not also listed under audio: the
/// preview has to say what will happen once, in the terms the user chose
/// it in.
pub fn plan(sessions: &[SessionAge], policy: RetentionPolicy, now_unix_ms: u64) -> RetentionPlan {
    let mut out = RetentionPlan::default();
    if policy.is_noop() {
        return out;
    }
    for session in sessions {
        let age = age_days(session.recorded_at_unix_ms, now_unix_ms);
        let transcript_expired = policy.transcript_days > 0 && age >= policy.transcript_days;
        if transcript_expired {
            out.sessions_to_delete.push(RetentionItem {
                path: session.dir_path.clone(),
                title: session.title.clone(),
                age_days: age,
                bytes: session.audio_bytes,
            });
            continue;
        }
        if policy.audio_days > 0 && age >= policy.audio_days && !session.audio_paths.is_empty() {
            for path in &session.audio_paths {
                out.audio_to_delete.push(RetentionItem {
                    path: path.clone(),
                    title: session.title.clone(),
                    age_days: age,
                    bytes: 0,
                });
            }
            out.audio_bytes_freed = out.audio_bytes_freed.saturating_add(session.audio_bytes);
        }
    }
    out
}

/// Whole days between two instants. A session recorded this morning is 0
/// days old, not 1 — "hapus setelah 30 hari" must not fire on day 29.
pub fn age_days(recorded_at_unix_ms: u64, now_unix_ms: u64) -> u32 {
    let elapsed_ms = now_unix_ms.saturating_sub(recorded_at_unix_ms);
    (elapsed_ms / 1000 / DAY_SECS) as u32
}

/// Carries out a plan the user has confirmed, and writes one audit entry
/// per deletion.
///
/// Returns the paths actually removed. A path that is already gone counts
/// as success; a path that cannot be removed is reported and the rest
/// still run, because a single locked file must not abandon the policy.
pub fn apply(plan: &RetentionPlan) -> Result<RetentionOutcome, TranscribeError> {
    let mut outcome = RetentionOutcome::default();
    for item in &plan.audio_to_delete {
        match remove_file(Path::new(&item.path)) {
            Ok(()) => {
                outcome.deleted.push(item.path.clone());
                super::audit::record(
                    super::audit::AuditEntry::new(
                        super::audit::AuditAction::AudioDeleted,
                        item.title.clone(),
                    )
                    .with_detail(format!("retensi, umur {} hari", item.age_days)),
                );
            }
            Err(e) => outcome.failed.push(format!("{}: {e}", item.path)),
        }
    }
    for item in &plan.sessions_to_delete {
        match remove_dir(Path::new(&item.path)) {
            Ok(()) => {
                outcome.deleted.push(item.path.clone());
                super::audit::record(
                    super::audit::AuditEntry::new(
                        super::audit::AuditAction::SessionDeleted,
                        item.title.clone(),
                    )
                    .with_detail(format!("retensi, umur {} hari", item.age_days)),
                );
            }
            Err(e) => outcome.failed.push(format!("{}: {e}", item.path)),
        }
    }
    super::audit::record(
        super::audit::AuditEntry::new(super::audit::AuditAction::RetentionApplied, "perpustakaan")
            .with_detail(format!(
                "{} dihapus, {} gagal",
                outcome.deleted.len(),
                outcome.failed.len()
            )),
    );
    Ok(outcome)
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct RetentionOutcome {
    pub deleted: Vec<String>,
    pub failed: Vec<String>,
}

fn remove_file(path: &Path) -> std::io::Result<()> {
    match std::fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e),
    }
}

fn remove_dir(path: &Path) -> std::io::Result<()> {
    match std::fs::remove_dir_all(path) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e),
    }
}

/// Scans a library directory into the planner's input.
///
/// `recorded_at` comes from the `YYYYMMDD-` prefix the exporter writes,
/// falling back to the directory mtime. The mtime alone is wrong: saving
/// a summary or re-transcribing writes inside the folder, which would
/// make an old meeting look like today's and exempt it from the policy
/// forever.
pub fn scan_library(library_path: &Path) -> Vec<SessionAge> {
    let Ok(entries) = std::fs::read_dir(library_path) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        let name = path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        let recorded_at_unix_ms =
            date_prefix_unix_ms(&name).unwrap_or_else(|| dir_modified_ms(&path));
        let mut audio_paths = Vec::new();
        let mut audio_bytes = 0u64;
        if let Ok(files) = std::fs::read_dir(&path) {
            for file in files.flatten() {
                let file_path = file.path();
                let is_audio = file_path
                    .extension()
                    .and_then(|e| e.to_str())
                    .map(|ext| {
                        matches!(
                            ext.to_ascii_lowercase().as_str(),
                            "wav" | "mp3" | "m4a" | "aac" | "ogg" | "flac" | "opus"
                        )
                    })
                    .unwrap_or(false);
                if !is_audio {
                    continue;
                }
                audio_bytes += file.metadata().map(|m| m.len()).unwrap_or(0);
                audio_paths.push(file_path.to_string_lossy().to_string());
            }
        }
        out.push(SessionAge {
            dir_path: path.to_string_lossy().to_string(),
            title: strip_date_prefix(&name),
            recorded_at_unix_ms,
            audio_paths,
            audio_bytes,
        });
    }
    out
}

fn strip_date_prefix(name: &str) -> String {
    match name.split_once('-') {
        Some((prefix, rest)) if prefix.len() == 8 && prefix.bytes().all(|b| b.is_ascii_digit()) => {
            rest.to_string()
        }
        _ => name.to_string(),
    }
}

/// `20261004-Rapat` → the epoch millis of 2026-10-04 local midnight.
fn date_prefix_unix_ms(name: &str) -> Option<u64> {
    use chrono::{Local, NaiveDate, TimeZone};
    let prefix = name.get(..8)?;
    if !prefix.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    let year: i32 = prefix[..4].parse().ok()?;
    let month: u32 = prefix[4..6].parse().ok()?;
    let day: u32 = prefix[6..8].parse().ok()?;
    let date = NaiveDate::from_ymd_opt(year, month, day)?.and_hms_opt(0, 0, 0)?;
    match Local.from_local_datetime(&date) {
        chrono::offset::LocalResult::Single(time) => Some(time.timestamp_millis() as u64),
        chrono::offset::LocalResult::Ambiguous(time, _) => Some(time.timestamp_millis() as u64),
        chrono::offset::LocalResult::None => None,
    }
}

fn dir_modified_ms(path: &Path) -> u64 {
    std::fs::metadata(path)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|time| time.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

#[flutter_rust_bridge::frb(ignore)]
pub fn human_bytes(bytes: u64) -> String {
    const UNITS: [&str; 4] = ["B", "KB", "MB", "GB"];
    let mut value = bytes as f64;
    let mut unit = 0;
    while value >= 1024.0 && unit < UNITS.len() - 1 {
        value /= 1024.0;
        unit += 1;
    }
    if unit == 0 {
        format!("{bytes} B")
    } else {
        format!("{value:.1} {}", UNITS[unit])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const NOW: u64 = 1_800_000_000_000;

    fn days_ago(days: u64) -> u64 {
        NOW - days * DAY_SECS * 1000
    }

    fn session(title: &str, days: u64, with_audio: bool) -> SessionAge {
        SessionAge {
            dir_path: format!("/lib/{title}"),
            title: title.to_string(),
            recorded_at_unix_ms: days_ago(days),
            audio_paths: if with_audio {
                vec![format!("/lib/{title}/mic.wav")]
            } else {
                Vec::new()
            },
            audio_bytes: if with_audio { 10 * 1024 * 1024 } else { 0 },
        }
    }

    #[test]
    fn keeping_forever_is_the_default_and_deletes_nothing() {
        let policy = RetentionPolicy::default();
        assert!(policy.is_noop());
        let plan = plan(&[session("lama", 3650, true)], policy, NOW);
        assert!(plan.is_empty());
    }

    #[test]
    fn audio_can_expire_while_the_transcript_stays() {
        // The rule most organisations actually have.
        let policy = RetentionPolicy {
            audio_days: 30,
            transcript_days: 0,
        };
        let plan = plan(&[session("rapat", 40, true)], policy, NOW);
        assert_eq!(plan.audio_to_delete.len(), 1);
        assert!(plan.sessions_to_delete.is_empty());
        assert_eq!(plan.audio_bytes_freed, 10 * 1024 * 1024);
    }

    #[test]
    fn a_session_past_the_transcript_limit_goes_whole() {
        let policy = RetentionPolicy {
            audio_days: 30,
            transcript_days: 365,
        };
        let plan = plan(&[session("rapat", 400, true)], policy, NOW);
        assert_eq!(plan.sessions_to_delete.len(), 1);
        assert!(
            plan.audio_to_delete.is_empty(),
            "the folder goes; listing its audio separately says it twice"
        );
    }

    #[test]
    fn the_limit_is_inclusive_but_not_early() {
        let policy = RetentionPolicy {
            audio_days: 30,
            transcript_days: 0,
        };
        assert!(plan(&[session("a", 29, true)], policy, NOW).is_empty());
        assert!(!plan(&[session("b", 30, true)], policy, NOW).is_empty());
    }

    #[test]
    fn a_session_recorded_today_is_zero_days_old() {
        assert_eq!(age_days(NOW, NOW), 0);
        assert_eq!(age_days(NOW - 1000, NOW), 0);
        assert_eq!(age_days(days_ago(1), NOW), 1);
        // A clock that went backwards must not make a session infinitely
        // old and delete the library.
        assert_eq!(age_days(NOW + 86_400_000, NOW), 0);
    }

    #[test]
    fn a_session_with_no_audio_is_not_listed_for_audio_deletion() {
        let policy = RetentionPolicy {
            audio_days: 1,
            transcript_days: 0,
        };
        assert!(plan(&[session("teks saja", 100, false)], policy, NOW).is_empty());
    }

    #[test]
    fn the_preview_says_what_will_happen_in_indonesian() {
        let policy = RetentionPolicy {
            audio_days: 30,
            transcript_days: 365,
        };
        let plan = plan(
            &[
                session("audio lama", 40, true),
                session("sesi sangat lama", 400, true),
            ],
            policy,
            NOW,
        );
        let summary = plan.summary();
        assert!(
            summary.contains("1 sesi akan dihapus seluruhnya"),
            "{summary}"
        );
        assert!(summary.contains("1 berkas audio"), "{summary}");
        assert!(summary.contains("Transkrip yang tidak disebut tetap disimpan"));
    }

    #[test]
    fn an_empty_plan_says_so_rather_than_nothing() {
        assert_eq!(
            RetentionPlan::default().summary(),
            "Tidak ada yang melewati batas retensi."
        );
    }

    #[test]
    fn the_date_prefix_decides_the_age_not_the_mtime() {
        // Saving a summary into an old session's folder must not exempt it.
        let millis = date_prefix_unix_ms("20260104-Rapat Awal Tahun").expect("parses");
        assert!(millis > 1_750_000_000_000, "got {millis}");
        assert_eq!(date_prefix_unix_ms("Rapat tanpa tanggal"), None);
        assert_eq!(date_prefix_unix_ms("2026010-pendek"), None);
    }

    #[test]
    fn the_title_loses_the_date_prefix() {
        assert_eq!(
            strip_date_prefix("20261004-Rapat Anggaran"),
            "Rapat Anggaran"
        );
        assert_eq!(strip_date_prefix("Rapat Anggaran"), "Rapat Anggaran");
    }

    #[test]
    fn scanning_finds_audio_and_ignores_everything_else() {
        let dir = std::env::temp_dir().join(format!("trareon_ret_{}", uuid::Uuid::new_v4()));
        let session_dir = dir.join("20260104-Rapat");
        std::fs::create_dir_all(&session_dir).unwrap();
        std::fs::write(session_dir.join("mic.wav"), vec![0u8; 1024]).unwrap();
        std::fs::write(session_dir.join("Rapat.json"), "[]").unwrap();
        let sessions = scan_library(&dir);
        assert_eq!(sessions.len(), 1);
        assert_eq!(sessions[0].title, "Rapat");
        assert_eq!(sessions[0].audio_paths.len(), 1);
        assert_eq!(sessions[0].audio_bytes, 1024);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn scanning_a_missing_library_is_empty_not_a_panic() {
        assert!(scan_library(Path::new("/nonexistent/library")).is_empty());
    }

    #[test]
    fn applying_a_plan_deletes_only_what_it_listed() {
        // The audit log's redirect is one process-wide slot; see
        // `audit::LOG_DIR_LOCK`.
        let _guard = match super::super::audit::LOG_DIR_LOCK.lock() {
            Ok(g) => g,
            Err(poisoned) => poisoned.into_inner(),
        };
        let dir = std::env::temp_dir().join(format!("trareon_ret_{}", uuid::Uuid::new_v4()));
        let keep = dir.join("20261001-Baru");
        let drop_audio = dir.join("20260101-Lama");
        std::fs::create_dir_all(&keep).unwrap();
        std::fs::create_dir_all(&drop_audio).unwrap();
        std::fs::write(keep.join("mic.wav"), [0u8]).unwrap();
        std::fs::write(drop_audio.join("mic.wav"), [0u8]).unwrap();
        std::fs::write(drop_audio.join("Lama.json"), "[]").unwrap();

        super::super::audit::set_log_dir(Some(dir.clone()));
        let plan = RetentionPlan {
            audio_to_delete: vec![RetentionItem {
                path: drop_audio.join("mic.wav").to_string_lossy().to_string(),
                title: "Lama".into(),
                age_days: 300,
                bytes: 1,
            }],
            sessions_to_delete: Vec::new(),
            audio_bytes_freed: 1,
        };
        let outcome = apply(&plan).unwrap();
        super::super::audit::set_log_dir(None);

        assert_eq!(outcome.deleted.len(), 1);
        assert!(outcome.failed.is_empty());
        assert!(!drop_audio.join("mic.wav").exists());
        assert!(
            drop_audio.join("Lama.json").exists(),
            "the transcript must survive an audio-only policy"
        );
        assert!(
            keep.join("mic.wav").exists(),
            "a newer session is untouched"
        );
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn deleting_something_already_gone_is_not_a_failure() {
        let plan = RetentionPlan {
            audio_to_delete: vec![RetentionItem {
                path: "/nonexistent/mic.wav".into(),
                title: "hilang".into(),
                age_days: 1,
                bytes: 0,
            }],
            ..RetentionPlan::default()
        };
        let outcome = apply(&plan).unwrap();
        assert!(outcome.failed.is_empty());
    }

    #[test]
    fn bytes_read_as_something_a_person_understands() {
        assert_eq!(human_bytes(512), "512 B");
        assert_eq!(human_bytes(2048), "2.0 KB");
        assert_eq!(human_bytes(10 * 1024 * 1024), "10.0 MB");
        assert_eq!(human_bytes(3 * 1024 * 1024 * 1024), "3.0 GB");
    }
}
