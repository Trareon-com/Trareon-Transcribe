"""Export transcript + optional subtitle formats into session folder."""

from __future__ import annotations

from pathlib import Path

from engine.session_store import Session, TranscriptSegment


def _fmt_ts(ms: int) -> str:
    s, ms = divmod(ms, 1000)
    h, rem = divmod(s, 3600)
    m, sec = divmod(rem, 60)
    return f"{h:02d}:{m:02d}:{sec:02d}.{ms:03d}"


def _srt_ts(ms: int) -> str:
    s, ms = divmod(ms, 1000)
    h, rem = divmod(s, 3600)
    m, sec = divmod(rem, 60)
    return f"{h:02d}:{m:02d}:{sec:02d},{ms:03d}"


def _lang_tag(lang: str) -> str:
    code = (lang or "auto").lower()
    if code.startswith("id") or code == "indonesian":
        return "ID"
    if code.startswith("en") or code == "english":
        return "EN"
    return code.upper()[:2] or "??"


def write_markdown(session: Session, path: Path | None = None) -> Path:
    path = path or (session.root / "transcript.md")
    lines = [f"# {session.meta.title}", "", f"Mode: {session.meta.mode}", ""]
    for seg in session.segments:
        if not seg.is_final or not seg.text.strip():
            continue
        lines.append(
            f"- **{_fmt_ts(seg.start_ms)}** [{seg.speaker}] [{_lang_tag(seg.language)}]: {seg.text.strip()}"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def write_txt(session: Session, path: Path | None = None) -> Path:
    path = path or (session.root / "transcript.txt")
    lines = []
    for seg in session.segments:
        if not seg.is_final or not seg.text.strip():
            continue
        lines.append(f"[{_fmt_ts(seg.start_ms)}] {seg.speaker}: {seg.text.strip()}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def write_json(session: Session) -> Path:
    session.save_transcript()
    return session.transcript_path


def write_srt(session: Session, path: Path | None = None) -> Path:
    path = path or (session.root / "transcript.srt")
    blocks: list[str] = []
    n = 1
    for seg in session.segments:
        if not seg.is_final or not seg.text.strip():
            continue
        end = seg.end_ms if seg.end_ms > seg.start_ms else seg.start_ms + 1000
        blocks.append(
            f"{n}\n{_srt_ts(seg.start_ms)} --> {_srt_ts(end)}\n{seg.speaker}: {seg.text.strip()}\n"
        )
        n += 1
    path.write_text("\n".join(blocks), encoding="utf-8")
    return path


def write_vtt(session: Session, path: Path | None = None) -> Path:
    path = path or (session.root / "transcript.vtt")
    lines = ["WEBVTT", ""]
    for seg in session.segments:
        if not seg.is_final or not seg.text.strip():
            continue
        end = seg.end_ms if seg.end_ms > seg.start_ms else seg.start_ms + 1000
        start = _fmt_ts(seg.start_ms).replace(".", ".")
        # VTT uses .
        lines.append(f"{start} --> {_fmt_ts(end)}")
        lines.append(f"{seg.speaker}: {seg.text.strip()}")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def export_formats(
    session: Session,
    *,
    md: bool = True,
    txt: bool = True,
    json_out: bool = True,
    srt: bool = False,
    vtt: bool = False,
) -> list[Path]:
    written: list[Path] = []
    if json_out:
        written.append(write_json(session))
    if md:
        written.append(write_markdown(session))
    if txt:
        written.append(write_txt(session))
    if srt:
        written.append(write_srt(session))
    if vtt:
        written.append(write_vtt(session))
    return written


def format_caption_line(seg: TranscriptSegment) -> str:
    icon = "MIC" if seg.speaker.upper().startswith("MIC") else "SPK"
    return f"{icon} [{_lang_tag(seg.language)}]: {seg.text}"
