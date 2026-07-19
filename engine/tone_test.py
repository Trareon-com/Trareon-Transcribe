"""Play a short tone and verify speaker/loopback capture hears it."""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass

import numpy as np

log = logging.getLogger("trareon.tone_test")


@dataclass
class ToneTestResult:
    ok: bool
    rms: float
    message: str


def _tone_pcm(freq: float = 440.0, duration: float = 0.7, sr: int = 16000) -> np.ndarray:
    t = np.linspace(0, duration, int(sr * duration), endpoint=False)
    wave = 0.35 * np.sin(2 * np.pi * freq * t)
    return (wave * 32767).astype(np.int16)


def run_tone_test(
    speaker_device: str | int | None = None,
    output_device: str | int | None = None,
    threshold_rms: float = 400.0,
) -> ToneTestResult:
    """Play tone to output; capture from input (loopback). Best-effort with sounddevice."""
    try:
        import sounddevice as sd
    except ImportError:
        return ToneTestResult(False, 0.0, "sounddevice belum terpasang")

    sr = 16000
    tone = _tone_pcm(sr=sr)
    captured = np.zeros(int(sr * 1.2), dtype=np.int16)

    try:
        # Record while playing
        rec = sd.rec(
            len(captured),
            samplerate=sr,
            channels=1,
            dtype="int16",
            device=speaker_device,
        )
        sd.play(tone, samplerate=sr, device=output_device)
        sd.wait()
        time.sleep(0.15)
        sd.stop()
        captured = np.squeeze(rec).astype(np.int16)
    except Exception as e:
        log.exception("tone test failed")
        return ToneTestResult(
            False,
            0.0,
            f"Gagal tone test: {e}. Pastikan BlackHole/VB-Cable terpasang dan output diarahkan ke virtual cable.",
        )

    # Measure middle window (skip attack)
    mid = captured[int(0.2 * sr) : int(0.9 * sr)]
    rms = float(np.sqrt(np.mean(mid.astype(np.float64) ** 2))) if mid.size else 0.0
    if rms >= threshold_rms:
        return ToneTestResult(True, rms, "Speaker capture terhubung.")
    return ToneTestResult(
        False,
        rms,
        "Tidak terdengar nada di speaker capture. "
        "macOS: set Multi-Output Device (Speaker + BlackHole). "
        "Windows: arahkan output ke VB-Cable / gunakan WASAPI loopback.",
    )
