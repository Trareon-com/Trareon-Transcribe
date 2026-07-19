"""Persisted user settings."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from config.paths import config_file, default_library_root


@dataclass
class Settings:
    theme: str = "light"  # light | dark
    model: str = "medium"
    meeting_mode: str = "rapat_online"  # webinar | rapat_online | rapat_offline
    mic_enabled: bool = True
    speaker_enabled: bool = True
    always_on_top: bool = False
    library_root: str = ""
    diarization_enabled: bool = False
    setup_complete: bool = False
    tone_test_ok: bool = False
    tone_test_skipped: bool = False
    window_geometry: str = "960x720"
    window_x: int | None = None
    window_y: int | None = None
    reduced_motion: bool = False
    mic_device: str = ""
    speaker_device: str = ""
    last_meeting_title: str = ""

    def library_path(self) -> Path:
        if self.library_root:
            p = Path(self.library_root)
            p.mkdir(parents=True, exist_ok=True)
            return p
        return default_library_root()

    def save(self) -> None:
        path = config_file()
        data = asdict(self)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
        tmp.replace(path)

    @classmethod
    def load(cls) -> Settings:
        path = config_file()
        if not path.exists():
            s = cls()
            s.library_root = str(default_library_root())
            return s
        try:
            data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return cls()
        known = {f.name for f in cls.__dataclass_fields__.values()}  # type: ignore[attr-defined]
        filtered = {k: v for k, v in data.items() if k in known}
        s = cls(**filtered)
        if not s.library_root:
            s.library_root = str(default_library_root())
        return s
