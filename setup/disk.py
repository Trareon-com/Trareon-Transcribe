"""Free disk space checks before downloads / long sessions."""

from __future__ import annotations

import shutil
from pathlib import Path


def free_bytes(path: Path | None = None) -> int:
    p = path or Path.home()
    usage = shutil.disk_usage(p)
    return int(usage.free)


def human_gb(n: int) -> str:
    return f"{n / (1024**3):.1f} GB"


def ensure_space(required_bytes: int, path: Path | None = None, buffer_ratio: float = 1.2) -> tuple[bool, str]:
    need = int(required_bytes * buffer_ratio)
    free = free_bytes(path)
    if free >= need:
        return True, f"OK — butuh ~{human_gb(need)}, tersedia {human_gb(free)}"
    return False, f"Ruang disk kurang — butuh ~{human_gb(need)}, tersedia {human_gb(free)}"


# Approximate model sizes
MODEL_BYTES = {
    "tiny": 75 * 1024**2,
    "medium": int(1.5 * 1024**3),
    "large-v3-turbo": 3 * 1024**3,
}

WHISPER_BIN_BYTES = 50 * 1024**2
MIN_SESSION_FREE = 1 * 1024**3
