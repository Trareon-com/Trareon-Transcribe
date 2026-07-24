import os

import pytest

from config import instance_lock


def test_stale_pid_lock_is_reclaimed(monkeypatch, tmp_path):
    lock = tmp_path / "instance.lock"
    lock.write_text("99999999", encoding="utf-8")  # unlikely live pid
    monkeypatch.setattr(instance_lock, "instance_lock_file", lambda: lock)
    assert instance_lock.acquire_instance_lock() is True
    try:
        # Read back through the SAME handle acquire_instance_lock opened,
        # not a fresh Path.read_text() (which opens its own handle):
        # msvcrt.locking() on Windows enforces mandatory locking on the
        # locked byte range, so a second handle to that file gets
        # PermissionError while the original is still open — fcntl.flock on
        # POSIX is advisory only and never hit this.
        instance_lock._lock_fh.seek(0)
        assert instance_lock._lock_fh.read().strip() == str(os.getpid())
    finally:
        instance_lock.release_instance_lock()


@pytest.mark.parametrize("exc", [ProcessLookupError, PermissionError])
def test_pid_alive_specific_exceptions(monkeypatch, exc):
    def fake_kill(_pid, _sig):
        raise exc()

    monkeypatch.setattr(instance_lock.os, "kill", fake_kill)
    expected = exc is PermissionError  # ProcessLookupError => dead, PermissionError => alive
    assert instance_lock._pid_alive(123) is expected


def test_pid_alive_generic_oserror_does_not_crash(monkeypatch):
    """On Windows, os.kill(pid, 0) for a dead PID isn't reliably raised as
    ProcessLookupError (Win32 failures routed through PyErr_SetFromWindowsErr
    aren't errno-subclassed the way POSIX failures are) — a plain OSError
    must degrade to "assume alive", not propagate and crash the caller."""

    def fake_kill(_pid, _sig):
        raise OSError("some windows-specific failure")

    monkeypatch.setattr(instance_lock.os, "kill", fake_kill)
    assert instance_lock._pid_alive(123) is True
