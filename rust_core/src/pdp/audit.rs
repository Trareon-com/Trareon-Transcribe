//! Local append-only audit log (F13).
//!
//! UU 27/2022 asks a controller to be able to say what happened to
//! personal data. For a desktop app with one user that means a record of
//! the acts that move data: a session created, a transcript exported, a
//! summary sent to an endpoint, something deleted, a consent notice
//! acknowledged.
//!
//! Three properties make it worth having:
//!
//! * **Append-only.** Entries are appended and fsynced; nothing in the
//!   API rewrites or removes one. A log that can be edited answers no
//!   question that matters.
//! * **Local.** It lives next to the recovery directory, under the user's
//!   config dir. It is never uploaded, and `privacy` enforces that.
//! * **No content.** It records *that* a transcript was exported and
//!   where to, never what it said. An audit log that quoted the meeting
//!   would be a second copy of the data it exists to govern.

use std::fs::{File, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::error::TranscribeError;

const LOG_FILE: &str = "audit.jsonl";

// The log is never rotated. A three-hour meeting produces a handful of
// entries, so the file grows by kilobytes a year, and rotation would mean
// deleting audit history — the one thing an audit log must not do on its
// own.

/// One kind of act worth recording.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AuditAction {
    SessionCreated,
    SessionExported,
    SummarySent,
    SessionDeleted,
    AudioDeleted,
    TranscriptDeleted,
    ConsentAcknowledged,
    RedactionApplied,
    RetentionApplied,
    AuditExported,
}

impl AuditAction {
    /// Indonesian label for the viewer.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            AuditAction::SessionCreated => "Sesi dibuat",
            AuditAction::SessionExported => "Transkrip diekspor",
            AuditAction::SummarySent => "Ringkasan dikirim ke endpoint",
            AuditAction::SessionDeleted => "Sesi dihapus",
            AuditAction::AudioDeleted => "Audio dihapus",
            AuditAction::TranscriptDeleted => "Transkrip dihapus",
            AuditAction::ConsentAcknowledged => "Pemberitahuan perekaman disampaikan",
            AuditAction::RedactionApplied => "Penyamaran data pribadi diterapkan",
            AuditAction::RetentionApplied => "Kebijakan retensi dijalankan",
            AuditAction::AuditExported => "Log audit diekspor",
        }
    }
}

/// One line of the log.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEntry {
    pub at_unix_ms: u64,
    pub action: AuditAction,
    /// Who: the OS account the app ran as. There is no other actor on a
    /// desktop app, and inventing one would be theatre.
    pub actor: String,
    /// What it was about — a session title or directory name. Never
    /// transcript text.
    pub subject: String,
    /// Where it went, for the acts that move data: an output directory, a
    /// summary endpoint host. Never a full URL with a query string.
    #[serde(default)]
    pub destination: String,
    /// One short free-text note, e.g. "3 NIK, 1 email".
    #[serde(default)]
    pub detail: String,
}

impl AuditEntry {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn new(action: AuditAction, subject: impl Into<String>) -> Self {
        Self {
            at_unix_ms: now_ms(),
            action,
            actor: current_actor(),
            subject: subject.into(),
            destination: String::new(),
            detail: String::new(),
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn to(mut self, destination: impl Into<String>) -> Self {
        self.destination = destination.into();
        self
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn with_detail(mut self, detail: impl Into<String>) -> Self {
        self.detail = detail.into();
        self
    }
}

fn now_ms() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

fn current_actor() -> String {
    std::env::var("USER")
        .or_else(|_| std::env::var("USERNAME"))
        .unwrap_or_else(|_| "pengguna".to_string())
}

#[cfg(test)]
thread_local! {
    /// Test hook: redirects the log so a test never appends to the real
    /// one.
    ///
    /// Deliberately per-thread rather than process-wide. `cargo test`
    /// runs every test on its own thread, and a single shared slot meant
    /// one test redirecting the log pulled every *other* thread's
    /// entries into its directory with it — including entries a sibling
    /// module's test wrote only indirectly, by calling
    /// [`crate::pdp::retention::apply`]. That cross-talk is invisible
    /// when a test runs alone and fails in the full suite. Production
    /// never sets this, so a per-thread slot costs nothing there.
    static DIR_OVERRIDE: std::cell::RefCell<Option<PathBuf>> =
        const { std::cell::RefCell::new(None) };
}

#[cfg(test)]
fn set_log_dir(path: Option<PathBuf>) {
    DIR_OVERRIDE.with(|slot| *slot.borrow_mut() = path);
}

#[cfg(test)]
fn override_dir() -> Option<PathBuf> {
    DIR_OVERRIDE.with(|slot| slot.borrow().clone())
}

#[cfg(not(test))]
fn override_dir() -> Option<PathBuf> {
    None
}

/// The directory the log lives in when nothing has redirected it:
/// alongside the recovery directory, under the OS config dir. Not `/tmp`,
/// which is world-readable.
///
/// A test build has no such default. The real log belongs to whoever is
/// running the suite, and a test that appends to it would both corrupt
/// their history and read entries it did not write — so a test that
/// audits anything must install a [`TestLogDir`] first, and one that
/// forgets gets an error it can see rather than somebody else's file.
fn default_log_dir() -> Result<PathBuf, TranscribeError> {
    #[cfg(test)]
    {
        Err(TranscribeError::InvalidInput(
            "the audit log was not redirected for this test".into(),
        ))
    }
    #[cfg(not(test))]
    {
        dirs::config_dir()
            .ok_or_else(|| TranscribeError::InvalidInput("no config dir".into()))
            .map(|dir| dir.join("TrareonTranscribe"))
    }
}

/// Where the log lives.
pub fn log_path() -> Result<PathBuf, TranscribeError> {
    match override_dir() {
        Some(dir) => Ok(dir.join(LOG_FILE)),
        None => Ok(default_log_dir()?.join(LOG_FILE)),
    }
}

/// A log of its own for the duration of one test.
///
/// The redirect it installs is private to the calling thread, so two
/// tests can each hold one without seeing the other's entries. Cleanup
/// runs in `Drop`, so a failing assertion cannot leave the redirect
/// pointing at a directory that has already been removed.
#[cfg(test)]
pub(crate) struct TestLogDir {
    dir: PathBuf,
}

#[cfg(test)]
impl TestLogDir {
    pub(crate) fn new() -> Self {
        let dir = std::env::temp_dir().join(format!("trareon_audit_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).expect("a temporary audit directory");
        set_log_dir(Some(dir.clone()));
        Self { dir }
    }

    pub(crate) fn path(&self) -> &Path {
        &self.dir
    }
}

#[cfg(test)]
impl Drop for TestLogDir {
    fn drop(&mut self) {
        set_log_dir(None);
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

/// Appends one entry and flushes it to the platter.
///
/// Fsyncing every entry is deliberate: the events worth auditing are the
/// ones that happen just before something goes wrong, and a log that
/// loses its last page in a crash loses exactly those.
pub fn append(entry: &AuditEntry) -> Result<(), TranscribeError> {
    let path = log_path()?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(TranscribeError::from)?;
    }
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(TranscribeError::from)?;
    let line =
        serde_json::to_string(entry).map_err(|e| TranscribeError::InvalidInput(e.to_string()))?;
    file.write_all(line.as_bytes())
        .map_err(TranscribeError::from)?;
    file.write_all(b"\n").map_err(TranscribeError::from)?;
    file.sync_data().map_err(TranscribeError::from)?;
    Ok(())
}

/// Appends without propagating a failure.
///
/// For call sites where the audited act has already happened: refusing to
/// export a transcript because the log could not be written would be the
/// compliance feature breaking the product.
#[flutter_rust_bridge::frb(ignore)]
pub fn record(entry: AuditEntry) {
    if let Err(e) = append(&entry) {
        tracing::warn!(%e, "audit entry could not be written");
    }
}

/// The whole log, newest first, capped at `limit` (0 = everything).
///
/// A line that does not parse is skipped rather than failing the read: a
/// log truncated by a power cut must still show what came before.
pub fn read(limit: u32) -> Vec<AuditEntry> {
    let Ok(path) = log_path() else {
        return Vec::new();
    };
    let Ok(file) = File::open(&path) else {
        return Vec::new();
    };
    let mut entries: Vec<AuditEntry> = BufReader::new(file)
        .lines()
        .map_while(Result::ok)
        .filter_map(|line| serde_json::from_str(&line).ok())
        .collect();
    entries.reverse();
    if limit > 0 && entries.len() > limit as usize {
        entries.truncate(limit as usize);
    }
    entries
}

pub fn entry_count() -> u32 {
    read(0).len() as u32
}

/// Writes a copy of the log to `destination` (a CSV the user can hand to
/// an auditor), and records that it did.
pub fn export_csv(destination: &Path) -> Result<PathBuf, TranscribeError> {
    let entries = read(0);
    let mut csv = String::from("waktu,aksi,pelaku,objek,tujuan,keterangan\n");
    // Oldest first in the export: an audit trail reads forwards.
    for entry in entries.iter().rev() {
        csv.push_str(&format!(
            "{},{},{},{},{},{}\n",
            csv_field(&format_time(entry.at_unix_ms)),
            csv_field(entry.action.label()),
            csv_field(&entry.actor),
            csv_field(&entry.subject),
            csv_field(&entry.destination),
            csv_field(&entry.detail),
        ));
    }
    if let Some(parent) = destination.parent() {
        std::fs::create_dir_all(parent).map_err(TranscribeError::from)?;
    }
    crate::export::atomic_write(destination, csv.as_bytes())?;
    record(
        AuditEntry::new(AuditAction::AuditExported, "log audit")
            .to(destination.to_string_lossy().to_string()),
    );
    Ok(destination.to_path_buf())
}

/// RFC3339-ish local timestamp. `chrono` is already a dependency.
#[flutter_rust_bridge::frb(ignore)]
pub fn format_time(unix_ms: u64) -> String {
    use chrono::{Local, TimeZone};
    match Local.timestamp_millis_opt(unix_ms as i64) {
        chrono::offset::LocalResult::Single(time) => time.format("%Y-%m-%d %H:%M:%S").to_string(),
        _ => String::new(),
    }
}

/// Quotes a CSV field. A session title can contain a comma, a quote and a
/// newline, and all three have been seen in meeting names.
fn csv_field(value: &str) -> String {
    let cleaned = value.replace(['\r', '\n'], " ");
    if cleaned.contains(',') || cleaned.contains('"') {
        format!("\"{}\"", cleaned.replace('"', "\"\""))
    } else {
        cleaned
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn with_temp_log<T>(body: impl FnOnce(&Path) -> T) -> T {
        let log = TestLogDir::new();
        body(log.path())
    }

    #[test]
    fn an_entry_round_trips() {
        with_temp_log(|_| {
            append(
                &AuditEntry::new(AuditAction::SessionExported, "Rapat Anggaran")
                    .to("/home/budi/Documents")
                    .with_detail("3 format"),
            )
            .unwrap();
            let entries = read(0);
            assert_eq!(entries.len(), 1);
            assert_eq!(entries[0].action, AuditAction::SessionExported);
            assert_eq!(entries[0].subject, "Rapat Anggaran");
            assert_eq!(entries[0].destination, "/home/budi/Documents");
            assert_eq!(entries[0].detail, "3 format");
            assert!(entries[0].at_unix_ms > 0);
            assert!(!entries[0].actor.is_empty());
        });
    }

    #[test]
    fn the_log_is_append_only_and_newest_first() {
        with_temp_log(|_| {
            for name in ["satu", "dua", "tiga"] {
                append(&AuditEntry::new(AuditAction::SessionCreated, name)).unwrap();
            }
            let entries = read(0);
            assert_eq!(
                entries
                    .iter()
                    .map(|e| e.subject.as_str())
                    .collect::<Vec<_>>(),
                vec!["tiga", "dua", "satu"],
                "the viewer shows the most recent act first"
            );
            assert_eq!(entry_count(), 3);
        });
    }

    #[test]
    fn a_limit_takes_the_most_recent() {
        with_temp_log(|_| {
            for i in 0..10 {
                append(&AuditEntry::new(
                    AuditAction::SessionCreated,
                    format!("sesi {i}"),
                ))
                .unwrap();
            }
            let entries = read(3);
            assert_eq!(entries.len(), 3);
            assert_eq!(entries[0].subject, "sesi 9");
        });
    }

    #[test]
    fn a_truncated_line_does_not_hide_the_rest() {
        with_temp_log(|dir| {
            append(&AuditEntry::new(AuditAction::SessionCreated, "utuh")).unwrap();
            // A power cut mid-write.
            let mut file = OpenOptions::new()
                .append(true)
                .open(dir.join(LOG_FILE))
                .unwrap();
            file.write_all(b"{\"at_unix_ms\":1,\"acti").unwrap();
            drop(file);
            let entries = read(0);
            assert_eq!(entries.len(), 1);
            assert_eq!(entries[0].subject, "utuh");
        });
    }

    #[test]
    fn reading_a_log_that_does_not_exist_yet_is_empty_not_an_error() {
        with_temp_log(|_| {
            assert!(read(0).is_empty());
            assert_eq!(entry_count(), 0);
        });
    }

    #[test]
    fn the_export_is_csv_oldest_first_and_records_itself() {
        with_temp_log(|dir| {
            append(&AuditEntry::new(AuditAction::SessionCreated, "pertama")).unwrap();
            append(&AuditEntry::new(AuditAction::SessionDeleted, "kedua")).unwrap();
            let out = dir.join("audit.csv");
            export_csv(&out).unwrap();
            let csv = std::fs::read_to_string(&out).unwrap();
            let lines: Vec<&str> = csv.lines().collect();
            assert_eq!(lines[0], "waktu,aksi,pelaku,objek,tujuan,keterangan");
            assert!(lines[1].contains("pertama"), "oldest first: {csv}");
            assert!(lines[2].contains("kedua"));
            // The export is itself an act worth auditing.
            assert_eq!(read(1)[0].action, AuditAction::AuditExported);
        });
    }

    #[test]
    fn a_title_with_a_comma_or_quote_does_not_break_the_csv() {
        assert_eq!(csv_field("Rapat, Anggaran"), "\"Rapat, Anggaran\"");
        assert_eq!(csv_field("Rapat \"Khusus\""), "\"Rapat \"\"Khusus\"\"\"");
        assert_eq!(csv_field("Rapat\nbaris dua"), "Rapat baris dua");
        assert_eq!(csv_field("biasa"), "biasa");
    }

    #[test]
    fn every_action_has_an_indonesian_label() {
        for action in [
            AuditAction::SessionCreated,
            AuditAction::SessionExported,
            AuditAction::SummarySent,
            AuditAction::SessionDeleted,
            AuditAction::AudioDeleted,
            AuditAction::TranscriptDeleted,
            AuditAction::ConsentAcknowledged,
            AuditAction::RedactionApplied,
            AuditAction::RetentionApplied,
            AuditAction::AuditExported,
        ] {
            assert!(!action.label().is_empty());
            assert!(
                action.label().is_ascii() || action.label().chars().any(|c| c.is_alphabetic()),
                "{action:?}"
            );
        }
    }

    #[test]
    fn another_thread_writing_its_own_log_cannot_reach_this_one() {
        let _log = TestLogDir::new();
        append(&AuditEntry::new(AuditAction::SessionCreated, "milik_saya")).unwrap();
        // The regression: with one process-wide redirect, the entry
        // below landed in whichever directory the other thread had
        // installed last — so the full suite saw a retention test's
        // entries appear inside an audit test's log.
        std::thread::spawn(|| {
            let _other = TestLogDir::new();
            append(&AuditEntry::new(
                AuditAction::SessionCreated,
                "milik_orang_lain",
            ))
            .unwrap();
        })
        .join()
        .unwrap();
        assert_eq!(
            read(0)
                .iter()
                .map(|e| e.subject.as_str())
                .collect::<Vec<_>>(),
            vec!["milik_saya"],
            "a redirected log holds only what its own thread wrote"
        );
    }

    #[test]
    fn a_test_that_forgets_to_redirect_cannot_touch_the_real_log() {
        // No `TestLogDir` here on purpose. In a test build there is no
        // default directory, so the developer's own audit history is out
        // of reach whatever a test does.
        assert!(log_path().is_err(), "a test build has no default log dir");
        assert!(
            append(&AuditEntry::new(AuditAction::SessionCreated, "bocor")).is_err(),
            "an unredirected append must fail rather than find a file"
        );
        assert!(read(0).is_empty());
    }

    #[test]
    fn a_timestamp_formats_to_something_a_person_can_read() {
        let formatted = format_time(1_767_225_600_000);
        assert!(formatted.starts_with("20"), "got {formatted}");
        assert_eq!(formatted.len(), 19);
    }
}
