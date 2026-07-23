"""Remote control client + socket path (no GUI)."""

from __future__ import annotations

import sys
import tempfile
import uuid
from pathlib import Path

import pytest

import util.remote_control as remote_control
from config.paths import control_socket_path
from util.remote_control import RemoteControl, send_command


def test_control_socket_path_under_app_support() -> None:
    p = control_socket_path()
    assert p.name == "control.sock"
    assert "TrareonTranscribe" in str(p)


def test_send_command_without_server() -> None:
    # Ensure stale socket does not exist
    path = control_socket_path()
    if path.exists():
        path.unlink()
    r = send_command("ping", timeout=1)
    assert r.get("ok") is False
    assert "socket missing" in r.get("error", "")


class _FakeApp:
    _quitting = False

    def after(self, _delay: int, fn) -> None:  # noqa: ANN001
        fn()


def _round_trip_ping(sock_path: Path, monkeypatch, *, windows: bool) -> None:
    monkeypatch.setattr(remote_control, "control_socket_path", lambda: sock_path)
    monkeypatch.setattr(remote_control, "_IS_WINDOWS", windows)
    rc = RemoteControl(_FakeApp(), {"ping": lambda _req: {"ok": True, "pong": True}})
    rc.start()
    try:
        resp = send_command("ping", timeout=2)
        assert resp == {"ok": True, "pong": True}
    finally:
        rc.stop()


@pytest.mark.skipif(sys.platform == "win32", reason="AF_UNIX branch is POSIX-only")
def test_round_trip_ping_posix(monkeypatch) -> None:
    """AF_UNIX branch — the default on macOS/Linux.

    Uses a short path directly under the OS temp root rather than pytest's
    tmp_path fixture: AF_UNIX enforces a ~104-byte sun_path limit, and
    tmp_path's nested per-test directories (.../pytest-of-user/pytest-NN/
    test_name0/...) routinely exceed it even though the real
    control_socket_path() (a flat path under app_support_dir()) never would.
    """
    sock_path = Path(tempfile.gettempdir()) / f"tt-{uuid.uuid4().hex[:8]}.sock"
    try:
        _round_trip_ping(sock_path, monkeypatch, windows=False)
    finally:
        sock_path.unlink(missing_ok=True)


def test_round_trip_ping_windows_fallback(tmp_path: Path, monkeypatch) -> None:
    """TCP-loopback branch — forced on regardless of host OS so it's actually
    exercised with real sockets, not just reviewed by eye (no Windows machine
    available to run this against a real Windows AF_UNIX gap)."""
    _round_trip_ping(tmp_path / "control.sock", monkeypatch, windows=True)


def test_send_command_windows_bad_port_file(tmp_path: Path, monkeypatch) -> None:
    sock_path = tmp_path / "control.sock"
    sock_path.write_text("not-a-port", encoding="utf-8")
    monkeypatch.setattr(remote_control, "control_socket_path", lambda: sock_path)
    monkeypatch.setattr(remote_control, "_IS_WINDOWS", True)
    r = send_command("ping", timeout=1)
    assert r.get("ok") is False
    assert "bad port file" in r.get("error", "")
