"""Atomic writes.

Every file this package persists goes through here. A dataset manifest
that was half-written when the process died is worse than no manifest:
the next run resumes from it and silently drops whatever was missing.

Temp file in the *same directory* as the target, then `os.replace`.
Same directory because `rename` is only atomic within a filesystem, and
`/tmp` is routinely a different one.
"""

from __future__ import annotations

import contextlib
import json
import os
import tempfile
from collections.abc import Iterable
from pathlib import Path
from typing import Any


def write_bytes(path: str | Path, payload: bytes) -> Path:
    """Write `payload` to `path` atomically. Returns the path."""
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(target.parent), prefix=f".{target.name}.", suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, target)
    except BaseException:
        with contextlib.suppress(OSError):
            os.unlink(tmp)
        raise
    return target


def write_text(path: str | Path, text: str) -> Path:
    return write_bytes(path, text.encode("utf-8"))


def write_json(path: str | Path, obj: Any, *, indent: int = 2) -> Path:
    payload = json.dumps(obj, ensure_ascii=False, indent=indent, sort_keys=True)
    return write_text(path, payload + "\n")


def write_jsonl(path: str | Path, rows: Iterable[Any]) -> Path:
    body = "".join(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n" for row in rows)
    return write_text(path, body)
