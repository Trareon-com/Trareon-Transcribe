"""Session folder layout under library root."""

from __future__ import annotations

import json
import re
import shutil
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

from config.paths import ensure_under_root

INPROGRESS = ".inprogress"


def _slug(title: str, max_len: int = 40) -> str:
    s = title.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    s = re.sub(r"[-\s]+", "-", s).strip("-")
    return (s or "rapat")[:max_len]


@dataclass
class TranscriptSegment:
    start_ms: int
    end_ms: int
    text: str
    speaker: str  # MIC | SPEAKER | Speaker N
    language: str  # id | en | auto
    confidence: float = 0.0
    is_final: bool = True
    source: str = "MIC"


@dataclass
class SessionMeta:
    title: str
    mode: str
    created_at: str
    ended_at: str | None = None
    duration_sec: float = 0.0
    mic_device: str = ""
    speaker_device: str = ""
    session_id: str = ""
    folder_name: str = ""


@dataclass
class Session:
    root: Path
    meta: SessionMeta
    segments: list[TranscriptSegment] = field(default_factory=list)

    @property
    def meta_path(self) -> Path:
        return self.root / "meta.json"

    @property
    def transcript_path(self) -> Path:
        return self.root / "transcript.json"

    @property
    def mic_wav(self) -> Path:
        return self.root / "mic.wav"

    @property
    def speaker_wav(self) -> Path:
        return self.root / "speaker.wav"

    @property
    def inprogress_path(self) -> Path:
        return self.root / INPROGRESS

    def mark_inprogress(self) -> None:
        self.inprogress_path.write_text("1", encoding="utf-8")

    def clear_inprogress(self) -> None:
        if self.inprogress_path.exists():
            self.inprogress_path.unlink()

    def save_meta(self) -> None:
        _atomic_json(self.meta_path, asdict(self.meta))

    def save_transcript(self) -> None:
        data = [asdict(s) for s in self.segments]
        _atomic_json(self.transcript_path, {"segments": data})

    def load_transcript(self) -> None:
        if not self.transcript_path.exists():
            self.segments = []
            return
        raw = json.loads(self.transcript_path.read_text(encoding="utf-8"))
        self.segments = [TranscriptSegment(**s) for s in raw.get("segments", [])]


def _atomic_json(path: Path, data: Any) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    tmp.replace(path)


def create_session(library_root: Path, title: str, mode: str) -> Session:
    library_root.mkdir(parents=True, exist_ok=True)
    local = datetime.now().astimezone()
    day = local.strftime("%Y%m%d")
    sid = uuid.uuid4().hex[:8]
    folder_name = f"{day}-{_slug(title)}-{sid}"
    root = library_root / folder_name
    root.mkdir(parents=True, exist_ok=False)
    meta = SessionMeta(
        title=title or "Rapat tanpa judul",
        mode=mode,
        created_at=local.isoformat(),
        session_id=sid,
        folder_name=folder_name,
    )
    session = Session(root=root, meta=meta)
    session.save_meta()
    session.save_transcript()
    session.mark_inprogress()
    return session


def update_title(session: Session, title: str) -> None:
    session.meta.title = title or "Rapat tanpa judul"
    session.save_meta()


def finalize_session(session: Session, rename_for_title: bool = True) -> Session:
    session.meta.ended_at = datetime.now().astimezone().isoformat()
    # Keep duration already set from capture / demo WAV; only fall back to wall clock.
    if session.meta.duration_sec <= 0 and session.meta.created_at:
        try:
            started = datetime.fromisoformat(session.meta.created_at.replace("Z", "+00:00"))
            ended = datetime.fromisoformat(session.meta.ended_at.replace("Z", "+00:00"))
            if started.tzinfo is None:
                started = started.astimezone()  # treat naive as local
            if ended.tzinfo is None:
                ended = ended.astimezone()
            session.meta.duration_sec = max(0.0, (ended - started).total_seconds())
        except (ValueError, TypeError):
            pass
    session.save_meta()
    session.save_transcript()
    session.clear_inprogress()
    if rename_for_title:
        session = rename_session_folder(session)
    return session


def rename_session_folder(session: Session) -> Session:
    parent = session.root.parent
    day = session.meta.created_at[:10].replace("-", "") if session.meta.created_at else datetime.now().strftime("%Y%m%d")
    if len(day) != 8:
        day = datetime.now().strftime("%Y%m%d")
    new_name = f"{day}-{_slug(session.meta.title)}-{session.meta.session_id or uuid.uuid4().hex[:8]}"
    if new_name == session.root.name:
        return session
    dest = parent / new_name
    if dest.exists():
        return session
    ensure_under_root(session.root, parent)
    session.root.rename(dest)
    session.root = dest
    session.meta.folder_name = new_name
    session.save_meta()
    return session


def list_sessions(library_root: Path) -> list[SessionMeta]:
    if not library_root.exists():
        return []
    out: list[SessionMeta] = []
    for child in library_root.iterdir():
        if not child.is_dir():
            continue
        meta_path = child / "meta.json"
        if not meta_path.exists():
            continue
        try:
            data = json.loads(meta_path.read_text(encoding="utf-8"))
            data.setdefault("folder_name", child.name)
            data.setdefault("session_id", child.name.split("-")[-1])
            fields = {k: data.get(k) for k in SessionMeta.__dataclass_fields__}
            if not fields.get("title") or not fields.get("mode") or not fields.get("created_at"):
                continue
            out.append(SessionMeta(**fields))  # type: ignore[arg-type]
        except (json.JSONDecodeError, TypeError, OSError):
            continue
    out.sort(key=lambda m: m.created_at or "", reverse=True)
    return out


def find_inprogress(library_root: Path) -> Path | None:
    if not library_root.exists():
        return None
    for child in library_root.iterdir():
        if child.is_dir() and (child / INPROGRESS).exists():
            return child
    return None


def load_session(root: Path) -> Session:
    data = json.loads((root / "meta.json").read_text(encoding="utf-8"))
    meta = SessionMeta(**{k: data.get(k) for k in SessionMeta.__dataclass_fields__})
    session = Session(root=root, meta=meta)
    session.load_transcript()
    return session


def delete_session(root: Path, library_root: Path) -> None:
    ensure_under_root(root, library_root)
    if root.exists() and root.is_dir():
        shutil.rmtree(root)


def session_disk_bytes(root: Path) -> int:
    total = 0
    if not root.exists():
        return 0
    for p in root.rglob("*"):
        if p.is_file():
            total += p.stat().st_size
    return total
