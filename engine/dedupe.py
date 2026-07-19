"""Echo-dedupe: drop SPEAKER segments that duplicate recent MIC text (Rapat Online)."""

from __future__ import annotations

import re
from dataclasses import dataclass

from engine.session_store import TranscriptSegment


def _norm(text: str) -> str:
    t = text.lower().strip()
    t = re.sub(r"[^\w\s]", "", t, flags=re.UNICODE)
    t = re.sub(r"\s+", " ", t)
    return t


def _similar(a: str, b: str) -> bool:
    na, nb = _norm(a), _norm(b)
    if not na or not nb:
        return False
    if na == nb:
        return True
    # containment for short echo fragments
    if len(na) >= 8 and (na in nb or nb in na):
        return True
    # token Jaccard
    ta, tb = set(na.split()), set(nb.split())
    if not ta or not tb:
        return False
    j = len(ta & tb) / len(ta | tb)
    return j >= 0.85


@dataclass
class EchoDedupe:
    window_ms: int = 8000

    def filter_segment(
        self, candidate: TranscriptSegment, history: list[TranscriptSegment]
    ) -> TranscriptSegment | None:
        """Return None if candidate should be dropped as echo."""
        if candidate.speaker.upper() not in ("SPEAKER", "SPK"):
            return candidate
        start = candidate.start_ms
        for prev in reversed(history):
            if prev.start_ms < start - self.window_ms:
                break
            if prev.speaker.upper() not in ("MIC",):
                continue
            if not prev.is_final:
                continue
            if _similar(prev.text, candidate.text):
                return None
        return candidate
