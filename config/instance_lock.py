"""Single-instance lock via exclusive file lock."""

from __future__ import annotations

import atexit
import os
import sys

from config.paths import instance_lock_file

_lock_fh = None


def acquire_instance_lock() -> bool:
    """Return True if this process owns the lock; False if another instance runs."""
    global _lock_fh
    path = instance_lock_file()
    path.parent.mkdir(parents=True, exist_ok=True)
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
        fh.close()
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
