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
    # Duration must match WAV (~44s / ~9s), not fake created_at skew (15m / 2h).
    assert 30 <= sessions[0].meta.duration_sec <= 60
    assert 5 <= sessions[1].meta.duration_sec <= 20


def test_finalize_keeps_explicit_duration(tmp_path: Path) -> None:
    from engine.session_store import create_session, finalize_session

    s = create_session(tmp_path, "Dur test", "rapat_online")
    s.meta.duration_sec = 12.5
    s.meta.created_at = "2020-01-01T00:00:00+00:00"
    s = finalize_session(s, rename_for_title=False)
    assert s.meta.duration_sec == 12.5


def test_finalize_naive_created_at_does_not_crash(tmp_path: Path) -> None:
    from engine.session_store import create_session, finalize_session

    s = create_session(tmp_path, "Naive", "rapat_online")
    s.meta.duration_sec = 0
    s.meta.created_at = "2026-07-19T12:00:00"  # naive
    s = finalize_session(s, rename_for_title=False)
    assert s.meta.duration_sec >= 0
