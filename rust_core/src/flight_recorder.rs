// Copyright 2026 YSF Studio. Licensed under Privacy-Preserving Software License v1.0.
// SPDX-License-Identifier: PPSL
//
// Flight recorder — a privacy-conscious event logger for diagnosing
// session lifecycle issues WITHOUT recording audio or transcript content.
//
// Events recorded (metadata only):
//   - lifecycle transitions (start/pause/resume/stop)
//   - segment arrival rate (count + timing, NOT text)
//   - errors from the Rust bridge
//   - auto-stop triggers
//
// Explicitly NOT recorded:
//   - transcript text / segment content
//   - audio bytes
//   - window titles or app names
//   - any PII
//
// Logs are written as JSONL to a single rotating file under the app
// config directory. Old entries beyond [max_entries] are trimmed on write.
//
// The recorder is a process-wide singleton. Call `init(dir)` once at
// startup with the app-support directory; every event API is then a
// fire-and-forget metadata append that never blocks, never panics and
// never crashes the host application (all I/O errors are swallowed).

use std::fs::{self, File, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

use chrono::Utc;
use serde_json::{json, Value};

/// Maximum number of JSONL entries retained. Older entries are trimmed
/// on write (same contract as the Dart implementation).
pub const DEFAULT_MAX_ENTRIES: usize = 5000;

/// Trim the file every N writes instead of every write (amortized cost).
const TRIM_EVERY: usize = 256;

/// Error messages are capped so a pathological bridge error can never
/// blow up the log file.
const MESSAGE_CAP: usize = 500;

/// Default file name inside the app-support / config directory.
pub const FILE_NAME: &str = "flight_recorder.jsonl";

/// Fallback location used when `init` was never called (defense in
/// depth): `$XDG_CONFIG_HOME/trareon-transcribe/` on Linux/macOS.
pub const FALLBACK_SUBDIR: &str = "trareon-transcribe";

struct Inner {
    path: Option<PathBuf>,
    enabled: bool,
    write_count: usize,
    max_entries: usize,
}

impl Default for Inner {
    fn default() -> Self {
        Self {
            path: None,
            enabled: true,
            write_count: 0,
            max_entries: DEFAULT_MAX_ENTRIES,
        }
    }
}

static RECORDER: OnceLock<Mutex<Inner>> = OnceLock::new();

fn state() -> &'static Mutex<Inner> {
    RECORDER.get_or_init(|| Mutex::new(Inner::default()))
}

/// Poison-tolerant lock: the recorder must never crash the host app, so a
/// poisoned mutex (e.g. after a panic in another thread) is recovered
/// rather than propagated.
fn lock() -> std::sync::MutexGuard<'static, Inner> {
    state().lock().unwrap_or_else(|e| e.into_inner())
}

/// Resolves the log file path, falling back to the OS config directory
/// when `init` was never called. Returns `None` only if no config dir
/// can be determined at all.
fn resolve_path() -> Option<PathBuf> {
    let guard = lock();
    if let Some(p) = &guard.path {
        return Some(p.clone());
    }
    let base = dirs::config_dir()?;
    Some(base.join(FALLBACK_SUBDIR).join(FILE_NAME))
}

/// Initializes the recorder with an explicit app-support directory.
/// Idempotent — calling it again simply re-points the log file.
/// Creates the parent directory if it does not exist.
pub fn init(dir: &str) -> std::io::Result<()> {
    let path = Path::new(dir).join(FILE_NAME);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    lock().path = Some(path);
    Ok(())
}

/// Master switch — set false to disable all recording (defense in depth).
pub fn set_enabled(enabled: bool) {
    lock().enabled = enabled;
}

pub fn enabled() -> bool {
    lock().enabled
}

/// Test hook — re-point the log file without touching the filesystem.
pub fn set_path(path: PathBuf) {
    lock().path = Some(path);
}

fn append(event: Value) {
    let (path, enabled, max_entries) = {
        let mut guard = lock();
        if !guard.enabled {
            return;
        }
        guard.write_count += 1;
        (guard.path.clone(), true, guard.max_entries)
    };
    let _ = enabled;

    // Never crash the host: every I/O failure here is swallowed.
    let path = path.or_else(resolve_path).unwrap_or_default();
    if path.as_os_str().is_empty() {
        return;
    }
    let mut event = event;
    event["ts"] = json!(Utc::now().to_rfc3339());
    let line = format!("{event}\n");

    if OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .and_then(|mut f| f.write_all(line.as_bytes()).and_then(|_| f.flush()))
        .is_err()
    {
        return;
    }

    let should_trim = {
        let mut guard = lock();
        if guard.write_count >= TRIM_EVERY {
            guard.write_count = 0;
            true
        } else {
            false
        }
    };
    if should_trim {
        trim(&path, max_entries);
    }
}

fn trim(path: &Path, max_entries: usize) {
    // Read all lines, keep only the most recent `max_entries`, rewrite.
    let res = (|| -> std::io::Result<()> {
        let file = File::open(path)?;
        let lines: Vec<String> = BufReader::new(file).lines().collect::<Result<_, _>>()?;
        if lines.len() <= max_entries {
            return Ok(());
        }
        let keep = &lines[lines.len() - max_entries..];
        let mut out = OpenOptions::new().write(true).truncate(true).open(path)?;
        for line in keep {
            writeln!(out, "{line}")?;
        }
        out.flush()
    })();
    let _ = res;
}

// ── Event API (metadata only — never audio, never transcript text) ─────

pub fn log_lifecycle(session_id: &str, from: &str, to: &str) {
    append(json!({
        "type": "lifecycle",
        "session": session_id,
        "from": from,
        "to": to,
    }));
}

pub fn log_segment_batch(
    session_id: &str,
    batch_size: usize,
    total_segments: usize,
    queue_depth: usize,
) {
    append(json!({
        "type": "segments",
        "session": session_id,
        "batch": batch_size,
        "total": total_segments,
        "queue": queue_depth,
    }));
}

pub fn log_error(session_id: &str, source: &str, message: &str) {
    let capped: String = message.chars().take(MESSAGE_CAP).collect();
    append(json!({
        "type": "error",
        "session": session_id,
        "source": source,
        "message": capped,
    }));
}

pub fn log_auto_stop(session_id: &str, minutes: u64) {
    append(json!({
        "type": "autostop",
        "session": session_id,
        "minutes": minutes,
    }));
}

pub fn log_system(event: &str, details: Option<Vec<(String, String)>>) {
    let mut value = json!({ "type": "system", "event": event });
    if let Some(pairs) = details {
        if let Some(obj) = value.as_object_mut() {
            for (k, v) in pairs {
                obj.insert(k, json!(v));
            }
        }
    }
    append(value);
}

// ── Diagnostics API ────────────────────────────────────────────────────

/// Reads the current flight-recorder contents for diagnostics.
/// Returns raw JSONL text (empty string when unavailable).
pub fn read_log() -> String {
    let path = resolve_path().unwrap_or_default();
    if path.as_os_str().is_empty() {
        return String::new();
    }
    fs::read_to_string(path).unwrap_or_default()
}

/// Clears the log. Used after a successful diagnostic session.
pub fn clear_log() {
    let path = resolve_path().unwrap_or_default();
    if path.as_os_str().is_empty() {
        return;
    }
    let _ = fs::write(path, "");
}

/// Number of entries currently in the log file (0 if unavailable).
pub fn entry_count() -> usize {
    let path = resolve_path().unwrap_or_default();
    if path.as_os_str().is_empty() {
        return 0;
    }
    let Ok(file) = File::open(path) else {
        return 0;
    };
    BufReader::new(file).lines().count()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The recorder singleton is process-global, so tests that touch it must
    /// run one-at-a-time. Grab this guard as the first line of any test that
    /// calls `init`/`set_path`/event APIs/`read_log`/`clear_log`.
    /// Poison-tolerant: a panic in one test must not cascade into the rest.
    fn serial() -> std::sync::MutexGuard<'static, ()> {
        static TEST_LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        TEST_LOCK
            .get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(|e| e.into_inner())
    }

    fn temp_dir(tag: &str) -> PathBuf {
        let base = std::env::temp_dir().join(format!(
            "trareon-flight-{tag}-{}-{}",
            std::process::id(),
            Utc::now().timestamp_nanos_opt().unwrap_or(0)
        ));
        fs::create_dir_all(&base).unwrap();
        base
    }

    fn init_temp(tag: &str) -> PathBuf {
        let dir = temp_dir(tag);
        init(dir.to_str().unwrap()).unwrap();
        dir.join(FILE_NAME)
    }

    #[test]
    fn init_creates_parent_dir() {
        let _g = serial();
        let dir = temp_dir("parent");
        let nested = dir.join("a").join("b").join("c");
        init(nested.to_str().unwrap()).unwrap();
        assert!(nested.join(FILE_NAME).parent().unwrap().exists());
        assert_eq!(
            lock().path.as_deref(),
            Some(nested.join(FILE_NAME).as_path())
        );
    }

    #[test]
    fn init_is_idempotent_and_repoints() {
        let _g = serial();
        let dir_a = temp_dir("repoint-a");
        let dir_b = temp_dir("repoint-b");
        init(dir_a.to_str().unwrap()).unwrap();
        init(dir_b.to_str().unwrap()).unwrap();
        assert_eq!(
            lock().path.as_deref(),
            Some(dir_b.join(FILE_NAME).as_path())
        );
    }

    #[test]
    fn lifecycle_event_written_as_jsonl() {
        let _g = serial();
        let file = init_temp("lifecycle");
        log_lifecycle("s1", "started", "stopped");
        let raw = read_log();
        assert!(raw.ends_with('\n'));
        let line: Value = serde_json::from_str(raw.trim_end()).unwrap();
        assert_eq!(line["type"], "lifecycle");
        assert_eq!(line["session"], "s1");
        assert_eq!(line["from"], "started");
        assert_eq!(line["to"], "stopped");
        assert!(line["ts"].as_str().unwrap().contains('T'));
        assert!(file.exists());
    }

    #[test]
    fn segment_batch_event_has_metadata_only() {
        let _g = serial();
        init_temp("segments");
        log_segment_batch("s2", 12, 340, 3);
        let line: Value = serde_json::from_str(read_log().trim_end()).unwrap();
        assert_eq!(line["type"], "segments");
        assert_eq!(line["batch"], 12);
        assert_eq!(line["total"], 340);
        assert_eq!(line["queue"], 3);
        assert!(line.get("text").is_none(), "must never record content");
    }

    #[test]
    fn error_message_is_capped() {
        let _g = serial();
        init_temp("error-cap");
        log_error("s3", "bridge", &"x".repeat(10_000));
        let line: Value = serde_json::from_str(read_log().trim_end()).unwrap();
        let msg = line["message"].as_str().unwrap();
        assert_eq!(msg.len(), MESSAGE_CAP);
        assert_eq!(line["source"], "bridge");
    }

    #[test]
    fn autostop_event() {
        let _g = serial();
        init_temp("autostop");
        log_auto_stop("s4", 5);
        let line: Value = serde_json::from_str(read_log().trim_end()).unwrap();
        assert_eq!(line["type"], "autostop");
        assert_eq!(line["minutes"], 5);
    }

    #[test]
    fn system_event_with_and_without_details() {
        let _g = serial();
        init_temp("system");
        log_system("boot", None);
        log_system("config", Some(vec![("theme".into(), "dark".into())]));
        let lines: Vec<Value> = read_log()
            .lines()
            .map(|l| serde_json::from_str(l).unwrap())
            .collect();
        assert_eq!(lines.len(), 2);
        assert_eq!(lines[0]["event"], "boot");
        assert!(lines[0].get("theme").is_none());
        assert_eq!(lines[1]["event"], "config");
        assert_eq!(lines[1]["theme"], "dark");
    }

    #[test]
    fn append_is_sequential_and_timestamped() {
        let _g = serial();
        init_temp("seq");
        log_lifecycle("a", "x", "y");
        log_lifecycle("b", "x", "y");
        let lines: Vec<Value> = read_log()
            .lines()
            .map(|l| serde_json::from_str(l).unwrap())
            .collect();
        assert_eq!(lines.len(), 2);
        assert_eq!(lines[0]["session"], "a");
        assert_eq!(lines[1]["session"], "b");
        let t0 = lines[0]["ts"].as_str().unwrap();
        let t1 = lines[1]["ts"].as_str().unwrap();
        assert!(t0 <= t1);
    }

    #[test]
    fn disabled_recorder_writes_nothing() {
        let _g = serial();
        let file = init_temp("disabled");
        set_enabled(false);
        log_lifecycle("s5", "a", "b");
        set_enabled(true);
        log_lifecycle("s6", "a", "b");
        let lines: Vec<Value> = read_log()
            .lines()
            .map(|l| serde_json::from_str(l).unwrap())
            .collect();
        assert_eq!(lines.len(), 1);
        assert_eq!(lines[0]["session"], "s6");
        assert!(!file.exists() || fs::read_to_string(&file).unwrap().lines().count() == 1);
    }

    #[test]
    fn trim_keeps_most_recent_entries() {
        let _g = serial();
        let dir = temp_dir("trim");
        init(dir.to_str().unwrap()).unwrap();
        {
            let mut guard = lock();
            guard.max_entries = 10;
        }
        // 20 entries, no trim yet (write_count below threshold).
        for i in 0..20 {
            log_lifecycle(&format!("s{i}"), "a", "b");
        }
        // Force the NEXT write to cross the trim threshold.
        {
            let mut guard = lock();
            guard.write_count = TRIM_EVERY - 1;
        }
        // 5 more entries: the first one is written, THEN trim kicks in
        // (21 -> keep last 10), the remaining 4 are appended.
        for i in 20..25 {
            log_lifecycle(&format!("s{i}"), "a", "b");
        }
        let lines: Vec<Value> = read_log()
            .lines()
            .map(|l| serde_json::from_str(l).unwrap())
            .collect();
        assert_eq!(lines.len(), 14, "10 kept after trim + 4 appended");
        assert_eq!(lines.first().unwrap()["session"], "s11");
        assert_eq!(lines.last().unwrap()["session"], "s24");
    }

    #[test]
    fn trim_noop_when_under_limit() {
        let _g = serial();
        let dir = temp_dir("trim-noop");
        init(dir.to_str().unwrap()).unwrap();
        {
            let mut guard = lock();
            guard.max_entries = 100;
        }
        for i in 0..5 {
            log_lifecycle(&format!("s{i}"), "a", "b");
        }
        {
            let mut guard = lock();
            guard.write_count = TRIM_EVERY - 1;
        }
        log_lifecycle("s5", "a", "b"); // crosses threshold, but 6 <= 100 -> no-op
        assert_eq!(entry_count(), 6);
    }

    #[test]
    fn read_log_empty_when_no_file() {
        let _g = serial();
        // Fresh process state path never resolved yet — read_log must not panic.
        lock().path = None;
        assert_eq!(read_log(), "");
    }

    #[test]
    fn clear_log_truncates() {
        let _g = serial();
        init_temp("clear");
        log_lifecycle("s1", "a", "b");
        log_error("s1", "src", "boom");
        assert!(entry_count() >= 2);
        clear_log();
        assert_eq!(entry_count(), 0);
        assert_eq!(read_log(), "");
    }

    #[test]
    fn entry_count_counts_lines() {
        let _g = serial();
        let file = init_temp("count");
        assert_eq!(entry_count(), 0);
        log_lifecycle("s1", "a", "b");
        log_auto_stop("s1", 3);
        log_system("x", None);
        assert_eq!(entry_count(), 3);
        assert!(file.exists());
    }

    #[test]
    fn fallback_path_is_config_dir_based() {
        let _g = serial();
        lock().path = None;
        let p = resolve_path().unwrap();
        let name = p.file_name().unwrap().to_str().unwrap();
        assert_eq!(name, FILE_NAME);
        assert!(p.to_string_lossy().contains(FALLBACK_SUBDIR));
    }

    #[test]
    fn never_panics_on_unwritable_path() {
        let _g = serial();
        let dir = temp_dir("ro");
        let file = dir.join(FILE_NAME);
        fs::write(&file, "").unwrap();
        #[allow(unused_mut)]
        let mut perms = fs::metadata(&file).unwrap().permissions();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            perms.set_mode(0o444);
        }
        fs::set_permissions(&file, perms).unwrap();
        set_path(file.clone());
        // These must not panic — errors are swallowed by design.
        log_lifecycle("s1", "a", "b");
        log_error("s2", "src", "x");
        set_enabled(false);
        set_enabled(true);
    }
}
