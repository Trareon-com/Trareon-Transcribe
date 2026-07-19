"""OS-standard paths: app data vs user library content."""

from __future__ import annotations

import os
import sys
from pathlib import Path

APP_NAME = "TrareonTranscribe"
APP_DISPLAY = "Trareon Transcribe"


def _home() -> Path:
    return Path.home()


def app_support_dir() -> Path:
    if sys.platform == "darwin":
        p = _home() / "Library" / "Application Support" / APP_NAME
    elif sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or str(_home() / "AppData" / "Local")
        p = Path(base) / APP_NAME
    else:
        p = _home() / ".local" / "share" / APP_NAME
    p.mkdir(parents=True, exist_ok=True)
    return p


def cache_dir() -> Path:
    if sys.platform == "darwin":
        p = _home() / "Library" / "Caches" / APP_NAME
    elif sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or str(_home() / "AppData" / "Local")
        p = Path(base) / APP_NAME / "Cache"
    else:
        p = _home() / ".cache" / APP_NAME
    p.mkdir(parents=True, exist_ok=True)
    return p


def models_dir() -> Path:
    p = cache_dir() / "models"
    p.mkdir(parents=True, exist_ok=True)
    return p


def logs_dir() -> Path:
    p = app_support_dir() / "logs"
    p.mkdir(parents=True, exist_ok=True)
    return p


def config_file() -> Path:
    return app_support_dir() / "config.json"


def instance_lock_file() -> Path:
    return app_support_dir() / "instance.lock"


def library_index_file() -> Path:
    return app_support_dir() / "library-index.json"


def default_library_root() -> Path:
    p = _home() / "Documents" / APP_DISPLAY / "Sessions"
    p.mkdir(parents=True, exist_ok=True)
    return p


def ensure_under_root(path: Path, root: Path) -> Path:
    """Resolve path and ensure it stays under root (anti path-traversal)."""
    resolved = path.resolve()
    root_resolved = root.resolve()
    if root_resolved == resolved or root_resolved in resolved.parents:
        return resolved
    raise ValueError(f"Path escapes library root: {path}")
