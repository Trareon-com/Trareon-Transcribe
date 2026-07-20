"""Play a short tone and verify speaker/loopback capture hears it."""

from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass

import numpy as np

log = logging.getLogger("trareon.tone_test")

_TIMEOUT_S = 10.0


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
    """Play tone to output; capture from input (loopback). Hard timeout ~10s."""
    try:
        import sounddevice as sd
    except Exception as e:
        return ToneTestResult(
            False,
            0.0,
            f"Audio engine gagal load ({e}). Unduh ulang build terbaru dari GitHub Releases.",
        )

    from engine.audio_capture import resolve_speaker_input_device

    capture_dev = resolve_speaker_input_device(speaker_device)
    if capture_dev is None:
        return ToneTestResult(
            False,
            0.0,
            "Tidak ada virtual loopback. macOS: brew install --cask blackhole-2ch. "
            "Windows: pasang VB-Cable. Jangan pakai mic bawaan sebagai speaker.",
        )

    sr = 16000
    tone = _tone_pcm(sr=sr)
    result_box: list[ToneTestResult] = []

    def work() -> None:
        try:
            captured = np.zeros(int(sr * 1.2), dtype=np.int16)
            rec = sd.rec(
                len(captured),
                samplerate=sr,
                channels=1,
                dtype="int16",
                device=capture_dev,
            )
            sd.play(tone, samplerate=sr, device=output_device)
            sd.wait()
            time.sleep(0.15)
            sd.stop()
            captured = np.squeeze(rec).astype(np.int16)
            mid = captured[int(0.2 * sr) : int(0.9 * sr)]
            rms = float(np.sqrt(np.mean(mid.astype(np.float64) ** 2))) if mid.size else 0.0
            if rms >= threshold_rms:
                result_box.append(ToneTestResult(True, rms, "Speaker capture terhubung."))
            else:
                result_box.append(
                    ToneTestResult(
                        False,
                        rms,
                        "Tidak terdengar nada di speaker capture. "
                        "macOS: set Multi-Output Device (Speaker + BlackHole). "
                        "Windows: arahkan output ke VB-Cable / WASAPI loopback.",
                    )
                )
        except Exception as e:
            log.exception("tone test failed")
            result_box.append(
                ToneTestResult(
                    False,
                    0.0,
                    f"Gagal tone test: {e}. Pastikan BlackHole/VB-Cable terpasang "
                    "dan output diarahkan ke virtual cable.",
                )
            )

    t = threading.Thread(target=work, daemon=True)
    t.start()
    t.join(timeout=_TIMEOUT_S)
    if t.is_alive():
        try:
            import sounddevice as sd

            sd.stop()
        except Exception:
            pass
        return ToneTestResult(
            False,
            0.0,
            f"Tone test timeout ({int(_TIMEOUT_S)}s). Lewati Tone dan cek device di Settings.",
        )
    if result_box:
        return result_box[0]
    return ToneTestResult(False, 0.0, "Tone test tidak menghasilkan hasil.")
