"""Per-source labels by default; optional pyannote Speaker 1..N."""

from __future__ import annotations

import logging
from pathlib import Path

log = logging.getLogger("trareon.diarization")


def per_source_label(source: str) -> str:
    s = source.upper()
    if s in ("MIC", "MICROPHONE"):
        return "MIC"
    return "SPEAKER"


class PyannoteDiarizer:
    def __init__(self, hf_token: str | None) -> None:
        self.hf_token = hf_token
        self._pipeline = None

    def load(self) -> bool:
        if not self.hf_token:
            return False
        try:
            from pyannote.audio import Pipeline

            self._pipeline = Pipeline.from_pretrained(
                "pyannote/speaker-diarization-3.1",
                use_auth_token=self.hf_token,
            )
            return True
        except Exception as e:
            log.warning("pyannote load failed: %s", e)
            self._pipeline = None
            return False

    def diarize_file(self, wav_path: Path) -> list[tuple[float, float, str]]:
        """Return list of (start_sec, end_sec, speaker_label)."""
        if self._pipeline is None:
            return []
        try:
            diar = self._pipeline(str(wav_path))
            out: list[tuple[float, float, str]] = []
            for turn, _, speaker in diar.itertracks(yield_label=True):
                out.append((turn.start, turn.end, str(speaker)))
            # remap to Speaker 1..N
            mapping: dict[str, str] = {}
            n = 1
            remapped = []
            for start, end, spk in out:
                if spk not in mapping:
                    mapping[spk] = f"Speaker {n}"
                    n += 1
                remapped.append((start, end, mapping[spk]))
            return remapped
        except Exception as e:
            log.warning("diarize failed: %s", e)
            return []
