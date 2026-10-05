"""Audio duration, reliably.

`wave` only reads PCM. FLEURS publishes IEEE-float WAVs (format tag 3),
which it rejects outright — so a duration helper built on `wave` alone
silently fails on the benchmark's own corpus. The fast path stays
because it needs no subprocess, but ffprobe is the fallback and it is
the one that decides the answer for anything unusual.
"""

from __future__ import annotations

import subprocess
import wave
from pathlib import Path


def duration(path: str | Path) -> float:
    """Seconds of audio in `path`, or 0.0 when it cannot be determined."""
    target = Path(path)
    if not target.exists():
        return 0.0
    if target.suffix.casefold() == ".wav":
        try:
            with wave.open(str(target), "rb") as handle:
                rate = handle.getframerate()
                if rate:
                    return handle.getnframes() / rate
        except (OSError, wave.Error):
            pass  # float WAV, or a header `wave` dislikes; ask ffprobe
    return ffprobe_duration(target)


def ffprobe_duration(path: str | Path) -> float:
    completed = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=nw=1:nk=1",
            str(path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        return float(completed.stdout.strip())
    except ValueError:
        return 0.0
