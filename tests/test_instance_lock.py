import os

import pytest

from config import instance_lock


def test_stale_pid_lock_is_reclaimed(monkeypatch, tmp_path):
    lock = tmp_path / "instance.lock"
    lock.write_text("99999999", encoding="utf-8")  # unlikely live pid
    monkeypatch.setattr(instance_lock, "instance_lock_file", lambda: lock)
    assert instance_lock.acquire_instance_lock() is True
    assert lock.read_text(encoding="utf-8").strip() == str(os.getpid())
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
