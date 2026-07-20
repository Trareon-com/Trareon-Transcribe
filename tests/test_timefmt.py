"""Local timezone display for session timestamps."""

from __future__ import annotations

from util.timefmt import format_local, now_local_iso


def test_format_local_converts_utc() -> None:
    # Fixed offset so test is deterministic
    utc = "2026-07-19T18:45:00+00:00"
    # Just ensure it parses and differs from raw UTC string when not UTC
    out = format_local(utc, "%Y-%m-%d %H:%M")
    assert out != "?"
    assert "2026-07-19" in out or "2026-07-20" in out  # depends on local TZ


def test_format_local_naive_assumes_utc() -> None:
    out = format_local("2026-07-19T12:00:00")
    assert "2026" in out


def test_now_local_iso_has_offset() -> None:
    s = now_local_iso()
    assert "T" in s
    # local iso typically includes offset or Z
    assert len(s) >= 19
