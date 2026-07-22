from pathlib import Path

import pytest

from engine.session_store import Session, SessionMeta, TranscriptSegment
from export.writer import export_formats, format_caption_line, write_markdown, write_srt, write_txt


def test_export_formats(tmp_path: Path):
    meta = SessionMeta(title="T", mode="webinar", created_at="2026-07-19T00:00:00+00:00", session_id="abc")
    sess = Session(root=tmp_path, meta=meta, segments=[
        TranscriptSegment(0, 1000, "halo", "MIC", "id", 0.9, True),
    ])
    md = write_markdown(sess)
    txt = write_txt(sess)
    srt = write_srt(sess)
    body = md.read_text()
    assert md.exists() and "halo" in body
    assert "[ID]" not in body and "[EN]" not in body
    assert "halo" in txt.read_text()
    assert "-->" in srt.read_text()


def test_export_formats_propagates_oserror(tmp_path: Path, monkeypatch):
    """A disk-full/permission-denied write must not be silently swallowed —
    ui/export_dialog.py relies on this propagating so it can show an error
    instead of hanging on 'Mengekspor…' forever."""
    meta = SessionMeta(title="T", mode="webinar", created_at="2026-07-19T00:00:00+00:00", session_id="abc")
    sess = Session(root=tmp_path, meta=meta, segments=[
        TranscriptSegment(0, 1000, "halo", "MIC", "id", 0.9, True),
    ])

    def _boom(self, *a, **k):
        raise OSError("disk full")

    monkeypatch.setattr(Path, "write_text", _boom)
    with pytest.raises(OSError):
        export_formats(sess, md=True, txt=False, json_out=False, srt=False, vtt=False)


def test_format_caption_line_no_lang_tag():
    seg = TranscriptSegment(0, 500, "please review ya", "MIC", "id", 0.8, True)
    line = format_caption_line(seg)
    assert line == "MIC  please review ya"
    assert "[" not in line
    spk = TranscriptSegment(0, 500, "Sure", "SPEAKER_1", "en", 0.7, True)
    assert format_caption_line(spk) == "SPK  Sure"
