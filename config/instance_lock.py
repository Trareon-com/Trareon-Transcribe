"""Single-instance lock via exclusive file lock + stale PID recovery."""

from __future__ import annotations

import atexit
import os
import sys

from config.paths import instance_lock_file

_lock_fh = None


def _pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except OSError:
        # Windows' os.kill(pid, 0) failure for a dead PID isn't reliably a
        # ProcessLookupError (Win32 errors routed through
        # PyErr_SetFromWindowsErr aren't errno-subclassed the way POSIX
        # failures are) — treat "can't determine" as "assume alive" so we
        # never crash, just skip clearing a lock we're unsure about.
        return True
    return True


def _read_lock_pid() -> int | None:
    path = instance_lock_file()
    try:
        text = path.read_text(encoding="utf-8").strip()
        return int(text) if text else None
    except (OSError, ValueError):
        return None


def acquire_instance_lock() -> bool:
    """Return True if this process owns the lock; False if another live instance runs."""
    global _lock_fh
    path = instance_lock_file()
    path.parent.mkdir(parents=True, exist_ok=True)

    # Clear stale lock from crashed process
    existing = _read_lock_pid()
    if existing is not None and existing != os.getpid() and not _pid_alive(existing):
        try:
            path.unlink(missing_ok=True)
        except OSError:
            pass

    fh = open(path, "a+", encoding="utf-8")
    try:
        if sys.platform == "win32":
            import msvcrt

            fh.seek(0)
            msvcrt.locking(fh.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl

            fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        # Another process holds flock — verify PID still alive
        fh.close()
        other = _read_lock_pid()
        if other is not None and not _pid_alive(other):
            try:
                path.unlink(missing_ok=True)
            except OSError:
                pass
            return acquire_instance_lock()
        return False

    fh.seek(0)
    fh.truncate()
    fh.write(str(os.getpid()))
    fh.flush()
    _lock_fh = fh
    atexit.register(release_instance_lock)
    return True


def release_instance_lock() -> None:
    global _lock_fh
    if _lock_fh is None:
        return
    try:
        if sys.platform == "win32":
            import msvcrt

            _lock_fh.seek(0)
            msvcrt.locking(_lock_fh.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl

            fcntl.flock(_lock_fh.fileno(), fcntl.LOCK_UN)
    except OSError:
        pass
    try:
        _lock_fh.close()
    except OSError:
        pass
    _lock_fh = None
    try:
        instance_lock_file().unlink(missing_ok=True)
    except OSError:
        pass
