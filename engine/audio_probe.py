"""Friendly PortAudio / sounddevice readiness check."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class AudioProbeResult:
    ok: bool
    message: str
    device_count: int = 0


def probe_audio() -> AudioProbeResult:
    """Import sounddevice and list devices without raising OS dialogs when possible."""
    try:
        import sounddevice as sd
    except Exception as e:
        return AudioProbeResult(
            False,
            "Audio engine gagal dimuat (PortAudio). "
            "Unduh ulang build terbaru dari GitHub Releases "
            f"(bukan exe lama). Detail: {e}",
            0,
        )
    try:
        devices = list(sd.query_devices())
        n = len(devices)
        # Empty device list is an environment issue (CI/sandbox), not a PortAudio load failure.
        if n == 0:
            return AudioProbeResult(
                True,
                "Audio engine loaded · 0 perangkat (cek Sound settings jika di desktop)",
                0,
            )
        return AudioProbeResult(True, f"Audio OK · {n} perangkat", n)
    except Exception as e:
        msg = str(e)
        if "0x57" in msg or "portaudio" in msg.lower() or "cannot load library" in msg.lower():
            return AudioProbeResult(
                False,
                "PortAudio DLL gagal load. Ini bug build lama (onefile). "
                "Unduh ulang portable/Setup terbaru dari GitHub Releases.",
                0,
            )
        return AudioProbeResult(False, f"Audio tidak bisa diakses: {e}", 0)
