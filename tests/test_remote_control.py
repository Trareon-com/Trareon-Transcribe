"""Remote control client + socket path (no GUI)."""

from __future__ import annotations

from config.paths import control_socket_path
from util.remote_control import send_command


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
