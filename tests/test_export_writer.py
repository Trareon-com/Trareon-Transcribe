from pathlib import Path

from engine.session_store import Session, SessionMeta, TranscriptSegment
from export.writer import write_markdown, write_srt, write_txt


def test_export_formats(tmp_path: Path):
    meta = SessionMeta(title="T", mode="webinar", created_at="2026-07-19T00:00:00+00:00", session_id="abc")
    sess = Session(root=tmp_path, meta=meta, segments=[
        TranscriptSegment(0, 1000, "halo", "MIC", "id", 0.9, True),
    ])
    md = write_markdown(sess)
    txt = write_txt(sess)
    srt = write_srt(sess)
    assert md.exists() and "halo" in md.read_text()
    assert "halo" in txt.read_text()
    assert "-->" in srt.read_text()
