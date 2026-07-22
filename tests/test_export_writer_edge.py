"""Tests for export writer edge cases — empty sessions, unicode, captions."""

from __future__ import annotations

from pathlib import Path

from engine.session_store import Session, SessionMeta, TranscriptSegment
from export.writer import (
    export_formats,
    write_markdown,
    write_srt,
    write_txt,
    write_vtt,
)


def test_export_empty_session(tmp_path: Path) -> None:
    """Empty segments still produce files with at least a header."""
    meta = SessionMeta(
        title="Empty", mode="webinar", created_at="2026-07-19T00:00:00+00:00", session_id="empty"
    )
    sess = Session(root=tmp_path, meta=meta, segments=[])

    paths = export_formats(sess, md=True, txt=True, json_out=True, srt=False, vtt=False)

    md_body = paths[1].read_text(encoding="utf-8")
    assert "# Empty" in md_body

    txt_body = paths[2].read_text(encoding="utf-8")
    assert txt_body.strip() == ""

    json_body = paths[0].read_text(encoding="utf-8")
    assert '"segments": []' in json_body


def test_export_single_segment(tmp_path: Path) -> None:
    """A single segment appears in markdown, txt, and srt output."""
    meta = SessionMeta(
        title="Single", mode="rapat", created_at="2026-07-19T00:00:00+00:00", session_id="one"
    )
    sess = Session(
        root=tmp_path,
        meta=meta,
        segments=[
            TranscriptSegment(0, 2000, "Halo selamat siang", "MIC", "id", 0.95, True),
        ],
    )

    paths = export_formats(sess, md=True, txt=True, json_out=False, srt=True, vtt=False)

    md_body = paths[0].read_text(encoding="utf-8")
    assert "Halo selamat siang" in md_body

    txt_body = paths[1].read_text(encoding="utf-8")
    assert "Halo selamat siang" in txt_body

    srt_body = paths[2].read_text(encoding="utf-8")
    assert "Halo selamat siang" in srt_body


def test_export_unicode_text(tmp_path: Path) -> None:
    """Indonesian text with diacritics must survive round-trip."""

    meta = SessionMeta(
        title="Unicode", mode="rapat", created_at="2026-07-19T00:00:00+00:00", session_id="uni"
    )
    sess = Session(
        root=tmp_path,
        meta=meta,
        segments=[
            TranscriptSegment(0, 1500, "Beberapa menit yang lalu", "MIC", "id", 0.9, True),
            TranscriptSegment(1500, 3000, "Jangan lupa membayar pajak", "SPEAKER_01", "id", 0.88, True),
        ],
    )

    md_path = write_markdown(sess)
    md_body = md_path.read_text(encoding="utf-8")
    assert "menit" in md_body
    assert "yang" in md_body
    assert "pajak" in md_body

    txt_path = write_txt(sess)
    txt_body = txt_path.read_text(encoding="utf-8")
    assert "menit" in txt_body


def test_export_srt_format(tmp_path: Path) -> None:
    """SRT output uses correct sequence numbering and HH:MM:SS,mmm timestamps."""
    meta = SessionMeta(
        title="SRT Test",
        mode="rapat",
        created_at="2026-07-19T00:00:00+00:00",
        session_id="srt",
    )
    sess = Session(
        root=tmp_path,
        meta=meta,
        segments=[
            TranscriptSegment(0, 1500, "one", "MIC", "id", 0.9, True),
            TranscriptSegment(2000, 4500, "two", "SPEAKER_01", "id", 0.85, True),
            TranscriptSegment(60000, 65000, "three", "MIC", "id", 0.9, True),
        ],
    )

    srt_path = write_srt(sess)
    body = srt_path.read_text(encoding="utf-8")

    lines = body.strip().split("\n")
    # SRT blocks: seq → timestamp → text, separated by blank lines
    assert "1" in lines[0]
    assert "-->" in lines[1]
    assert "," in lines[1], "SRT must use comma as millisecond separator"
    assert lines[1] == "00:00:00,000 --> 00:00:01,500"

    # Block 1 → blank → Block 2 starts
    assert "2" in lines[4]
    assert "00:00:02,000 --> 00:00:04,500" in lines[5]

    assert "3" in lines[8]
    assert "00:01:00,000 --> 00:01:05,000" in lines[9]
    assert "three" in lines[10]


def test_export_vtt_format(tmp_path: Path) -> None:
    """VTT output includes WEBVTT header and HH:MM:SS.mmm timestamps."""
    meta = SessionMeta(
        title="VTT Test",
        mode="webinar",
        created_at="2026-07-19T00:00:00+00:00",
        session_id="vtt",
    )
    sess = Session(
        root=tmp_path,
        meta=meta,
        segments=[
            TranscriptSegment(0, 1500, "satu", "MIC", "id", 0.9, True),
            TranscriptSegment(5000, 7500, "dua", "SPEAKER_02", "id", 0.92, True),
        ],
    )

    vtt_path = write_vtt(sess)
    body = vtt_path.read_text(encoding="utf-8")

    assert body.startswith("WEBVTT")
    assert "--> 00:00:01.500" in body, "VTT must use dot as millisecond separator"
    assert "--> 00:00:07.500" in body
    assert "satu" in body
    assert "dua" in body
