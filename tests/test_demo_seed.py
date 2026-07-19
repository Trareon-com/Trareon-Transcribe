"""Dummy session seed must produce playable Library content."""

from __future__ import annotations

from pathlib import Path

from engine.demo_seed import seed_demo_sessions, verify_demo
from engine.session_store import list_sessions
from export.writer import write_srt


def test_seed_demo_sessions(tmp_path: Path) -> None:
    sessions = seed_demo_sessions(tmp_path, force=True)
    assert len(sessions) >= 2
    checks = verify_demo(sessions[0])
    assert "transcript.json" in checks
    assert any("mic.wav" in c for c in checks)
    assert list_sessions(tmp_path)
    srt = write_srt(sessions[0])
    assert srt.exists() and "Selamat pagi" in srt.read_text(encoding="utf-8")
