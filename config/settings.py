"""Persisted user settings."""

from __future__ import annotations

import json
import logging
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from config.paths import (
    config_file,
    default_library_root,
    ensure_dir,
    is_documents_library,
)

log = logging.getLogger("trareon.settings")

_DEFAULT_GEO = "1000x740"
_MIN_W, _MIN_H = 880, 600


def sanitize_geometry(geo: str) -> str:
    """Reject tiny or malformed geometries; return a safe WxH string."""
    raw = (geo or "").strip().split("+")[0]
    try:
        w_s, h_s = raw.lower().split("x", 1)
        w, h = int(w_s), int(h_s)
    except (ValueError, AttributeError):
        return _DEFAULT_GEO
    if w < _MIN_W or h < _MIN_H or w > 5000 or h > 4000:
        return _DEFAULT_GEO
    return f"{w}x{h}"


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
    window_geometry: str = _DEFAULT_GEO
    window_x: int | None = None
    window_y: int | None = None
    reduced_motion: bool = False
    mic_device: str = ""
    speaker_device: str = ""
    last_meeting_title: str = ""

    def library_path(self) -> Path:
        if self.library_root:
            p = ensure_dir(Path(self.library_root))
            # If ensure_dir fell back, persist the working path.
            if str(p) != self.library_root:
                self.library_root = str(p)
                try:
                    self.save()
                except OSError:
                    pass
            return p
        return default_library_root()

    def save(self) -> None:
        path = config_file()
        self.window_geometry = sanitize_geometry(self.window_geometry)
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
            s.window_geometry = sanitize_geometry(s.window_geometry)
            return s
        try:
            data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return cls()
        known = {f.name for f in cls.__dataclass_fields__.values()}  # type: ignore[attr-defined]
        filtered = {k: v for k, v in data.items() if k in known}
        s = cls(**filtered)
        s.window_geometry = sanitize_geometry(s.window_geometry)
        if s.window_x is not None and s.window_x < -50:
            s.window_x = None
        if s.window_y is not None and s.window_y < -50:
            s.window_y = None

        # Migrate broken / legacy Documents paths (esp. Windows CFA).
        need_migrate = False
        if not s.library_root:
            need_migrate = True
        elif sys.platform == "win32" and is_documents_library(s.library_root):
            need_migrate = True
        else:
            probe = Path(s.library_root)
            try:
                probe.mkdir(parents=True, exist_ok=True)
                test = probe / ".trareon-write-test"
                test.write_text("ok", encoding="utf-8")
                test.unlink(missing_ok=True)
            except OSError:
                need_migrate = True

        if need_migrate:
            new_root = default_library_root()
            log.warning("Migrating library_root to %s", new_root)
            s.library_root = str(new_root)
            try:
                s.save()
            except OSError:
                pass
        return s
