"""Per-source labels by default; optional pyannote Speaker 1..N on Export."""

from __future__ import annotations

import logging
import os
from pathlib import Path

log = logging.getLogger("trareon.diarization")


def per_source_label(source: str) -> str:
    s = source.upper()
    if s in ("MIC", "MICROPHONE"):
        return "MIC"
    return "SPEAKER"


def pyannote_status(hf_token: str | None) -> str:
    """Short UI status for Settings / Export (never includes the token)."""
    if not hf_token:
        return "Token HF belum disimpan."
    try:
        import pyannote.audio  # noqa: F401
    except ImportError:
        return (
            "Token tersimpan, tapi pyannote/torch belum terpasang. "
            "Jalankan: pip install '.[diarization]' lalu centang Enable pyannote."
        )
    try:
        import torch  # noqa: F401
    except ImportError:
        return "Token tersimpan, tapi torch belum terpasang (butuh untuk pyannote)."
    return "Token + pyannote siap. Centang Enable pyannote di Settings, lalu Export."


class PyannoteDiarizer:
    def __init__(self, hf_token: str | None) -> None:
        self.hf_token = (hf_token or "").strip() or None
        self._pipeline = None
        self.last_error = ""

    def load(self) -> bool:
        if not self.hf_token:
            self.last_error = "Hugging Face token kosong."
            return False
        try:
            from pyannote.audio import Pipeline
        except ImportError as e:
            self.last_error = (
                f"pyannote tidak terpasang ({e}). pip install '.[diarization]'"
            )
            log.warning("%s", self.last_error)
            return False
        prev_hf = os.environ.get("HF_TOKEN")
        prev_hub = os.environ.get("HUGGING_FACE_HUB_TOKEN")
        try:
            # Newer huggingface_hub uses token=; env helps nested downloads only during load.
            os.environ["HF_TOKEN"] = self.hf_token
            os.environ["HUGGING_FACE_HUB_TOKEN"] = self.hf_token
            try:
                self._pipeline = Pipeline.from_pretrained(
                    "pyannote/speaker-diarization-3.1",
                    token=self.hf_token,
                )
            except TypeError:
                self._pipeline = Pipeline.from_pretrained(
                    "pyannote/speaker-diarization-3.1",
                    use_auth_token=self.hf_token,
                )
            return True
        except Exception as e:
            self.last_error = str(e)
            log.warning("pyannote load failed: %s", e)
            self._pipeline = None
            return False
        finally:
            if prev_hf is None:
                os.environ.pop("HF_TOKEN", None)
            else:
                os.environ["HF_TOKEN"] = prev_hf
            if prev_hub is None:
                os.environ.pop("HUGGING_FACE_HUB_TOKEN", None)
            else:
                os.environ["HUGGING_FACE_HUB_TOKEN"] = prev_hub

    def diarize_file(self, wav_path: Path) -> list[tuple[float, float, str]]:
        """Return list of (start_sec, end_sec, speaker_label)."""
        if self._pipeline is None:
            return []
        try:
            diar = self._pipeline(str(wav_path))
            out: list[tuple[float, float, str]] = []
            for turn, _, speaker in diar.itertracks(yield_label=True):
                out.append((turn.start, turn.end, str(speaker)))
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
            self.last_error = str(e)
            log.warning("diarize failed: %s", e)
            return []
