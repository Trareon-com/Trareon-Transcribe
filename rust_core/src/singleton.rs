//! Singleton instance lock: PID file in the OS config dir, checked and
//! (re)claimed at startup so the app can't be launched twice at once.

use std::fs;
use std::path::PathBuf;

use crate::error::{TranscribeError, TranscribeResult};

fn lock_path() -> TranscribeResult<PathBuf> {
    let dir = dirs::config_dir()
        .ok_or_else(|| TranscribeError::InvalidInput("no config directory available".into()))?
        .join("TrareonTranscribe");
    Ok(dir.join("transcribe.lock"))
}

/// Returns true if another live instance already holds the lock (a PID
/// file exists and that PID is still running). A stale lock file (process
/// no longer alive) is treated as not-running and can be reclaimed.
pub fn is_another_instance_running() -> TranscribeResult<bool> {
    is_another_instance_running_at(&lock_path()?)
}

fn is_another_instance_running_at(path: &PathBuf) -> TranscribeResult<bool> {
    let Ok(content) = fs::read_to_string(path) else {
        return Ok(false);
    };
    let Ok(pid) = content.trim().parse::<u32>() else {
        return Ok(false);
    };
    Ok(pid_is_alive(pid))
}

/// Acquire the lock for the current process. Errors if another live
/// instance already holds it.
pub fn acquire_lock() -> TranscribeResult<()> {
    acquire_lock_at(&lock_path()?)
}

fn acquire_lock_at(path: &PathBuf) -> TranscribeResult<()> {
    if is_another_instance_running_at(path)? {
        return Err(TranscribeError::InvalidInput(
            "another instance of Trareon Transcribe is already running".into(),
        ));
    }
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(TranscribeError::from)?;
    }
    fs::write(path, std::process::id().to_string()).map_err(TranscribeError::from)
}

pub fn release_lock() -> TranscribeResult<()> {
    let path = lock_path()?;
    if path.exists() {
        fs::remove_file(path).map_err(TranscribeError::from)?;
    }
    Ok(())
}

#[cfg(unix)]
fn pid_is_alive(pid: u32) -> bool {
    // Signal 0 performs no-op existence/permission check without
    // sending an actual signal.
    unsafe { libc::kill(pid as libc::pid_t, 0) == 0 }
}

#[cfg(windows)]
fn pid_is_alive(pid: u32) -> bool {
    unsafe {
        let handle = windows_sys::Win32::System::Threading::OpenProcess(
            windows_sys::Win32::System::Threading::PROCESS_QUERY_LIMITED_INFORMATION,
            0,
            pid,
        );
        if handle == 0 {
            return false;
        }
        // A handle can still be opened for a process that has already
        // exited but hasn't been fully reaped yet (e.g. another handle
        // is still referencing it) — OpenProcess succeeding is NOT
        // sufficient proof of liveness on Windows. GetExitCodeProcess
        // + STILL_ACTIVE (259) is the correct liveness check; without
        // it, a lock file left behind by a killed/crashed process is
        // permanently treated as "still running" and the app can never
        // be relaunched until the user manually deletes the lock file.
        const STILL_ACTIVE: u32 = 259;
        let mut exit_code: u32 = 0;
        let ok = windows_sys::Win32::System::Threading::GetExitCodeProcess(
            handle,
            &mut exit_code as *mut u32,
        );
        windows_sys::Win32::Foundation::CloseHandle(handle);
        ok != 0 && exit_code == STILL_ACTIVE
    }
}

#[cfg(not(any(unix, windows)))]
fn pid_is_alive(_pid: u32) -> bool {
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_lock_path() -> PathBuf {
        std::env::temp_dir().join(format!(
            "transcribe_lock_test_{}.lock",
            uuid::Uuid::new_v4()
        ))
    }

    #[test]
    fn no_lock_file_means_not_running() {
        let path = temp_lock_path();
        assert!(!is_another_instance_running_at(&path).unwrap());
    }

    #[test]
    fn acquire_writes_current_pid() {
        let path = temp_lock_path();
        acquire_lock_at(&path).unwrap();
        let content = fs::read_to_string(&path).unwrap();
        assert_eq!(content.trim(), std::process::id().to_string());
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn stale_pid_is_reclaimable() {
        // PID 0 is never a real user process on any target platform we
        // support, so this simulates a stale lock file.
        let path = temp_lock_path();
        fs::write(&path, "999999999").unwrap();
        // An implausible PID should read as not alive (best-effort: this
        // assumes no process with that PID exists on the test machine).
        assert!(!is_another_instance_running_at(&path).unwrap());
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn corrupt_lock_file_treated_as_not_running() {
        let path = temp_lock_path();
        fs::write(&path, "not-a-pid").unwrap();
        assert!(!is_another_instance_running_at(&path).unwrap());
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn acquire_twice_second_call_detects_self_as_running() {
        let path = temp_lock_path();
        acquire_lock_at(&path).unwrap();
        // Our own PID is alive, so a second acquire attempt against the
        // same lock file must be rejected.
        assert!(is_another_instance_running_at(&path).unwrap());
        assert!(acquire_lock_at(&path).is_err());
        let _ = fs::remove_file(&path);
    }
}
