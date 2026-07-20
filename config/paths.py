"""OS-standard paths: app data vs user library content."""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

APP_NAME = "TrareonTranscribe"
APP_DISPLAY = "Trareon Transcribe"

log = logging.getLogger("trareon.paths")


def _home() -> Path:
    return Path.home()


def ensure_dir(path: Path) -> Path:
    """Create directory; never raise — fall back to app_support Sessions if needed."""
    try:
        path.mkdir(parents=True, exist_ok=True)
        return path
    except OSError as e:
        log.warning("mkdir failed for %s: %s", path, e)
        fallback = app_support_dir() / "Sessions"
        try:
            fallback.mkdir(parents=True, exist_ok=True)
        except OSError:
            # Last resort: temp under app support
            fallback = app_support_dir() / "Sessions"
            fallback.mkdir(parents=True, exist_ok=True)
        return fallback


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


def control_socket_path() -> Path:
    """Unix domain socket for local automation (`--control` / trareon_ctl)."""
    return app_support_dir() / "control.sock"


def library_index_file() -> Path:
    return app_support_dir() / "library-index.json"


def default_library_root() -> Path:
    # Windows: LocalAppData avoids Controlled Folder Access on Documents.
    # macOS/Linux: Documents is natural; fallback via ensure_dir if it fails.
    if sys.platform == "win32":
        p = app_support_dir() / "Sessions"
    else:
        p = _home() / "Documents" / APP_DISPLAY / "Sessions"
    return ensure_dir(p)


def is_documents_library(path: str | Path) -> bool:
    """True if path looks like the legacy Documents library root."""
    try:
        s = str(Path(path).resolve()).lower()
    except OSError:
        s = str(path).lower()
    return "documents" in s and ("trareon transcribe" in s or "trareontranscribe" in s)


def ensure_under_root(path: Path, root: Path) -> Path:
    """Resolve path and ensure it stays under root (anti path-traversal)."""
    resolved = path.resolve()
    root_resolved = root.resolve()
    if root_resolved == resolved or root_resolved in resolved.parents:
        return resolved
    raise ValueError(f"Path escapes library root: {path}")
