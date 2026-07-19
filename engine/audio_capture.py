"""Dual mic + speaker capture with runtime mute toggles."""

from __future__ import annotations

import logging
import threading
import wave
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

log = logging.getLogger("trareon.audio")

SAMPLE_RATE = 16000
CHANNELS = 1
DTYPE = "int16"


@dataclass
class StreamState:
    mic_enabled: bool = True
    speaker_enabled: bool = True
    running: bool = False


class AudioCapture:
    """Captures mic and speaker in parallel; muted streams skip callbacks & WAV."""

    def __init__(
        self,
        on_mic_chunk: Callable[[bytes], None] | None = None,
        on_speaker_chunk: Callable[[bytes], None] | None = None,
        mic_device: Any = None,
        speaker_device: Any = None,
    ) -> None:
        self.on_mic_chunk = on_mic_chunk
        self.on_speaker_chunk = on_speaker_chunk
        self.mic_device = mic_device
        self.speaker_device = speaker_device
        self.state = StreamState()
        self._lock = threading.Lock()
        self._mic_stream = None
        self._spk_stream = None
        self._mic_wav: wave.Wave_write | None = None
        self._spk_wav: wave.Wave_write | None = None
        self._sd = None

    def set_mic_enabled(self, enabled: bool) -> None:
        with self._lock:
            self.state.mic_enabled = enabled

    def set_speaker_enabled(self, enabled: bool) -> None:
        with self._lock:
            self.state.speaker_enabled = enabled

    def open_wav_writers(self, mic_path: Path, speaker_path: Path) -> None:
        self.close_wav_writers()
        self._mic_wav = wave.open(str(mic_path), "wb")
        self._mic_wav.setnchannels(CHANNELS)
        self._mic_wav.setsampwidth(2)
        self._mic_wav.setframerate(SAMPLE_RATE)
        self._spk_wav = wave.open(str(speaker_path), "wb")
        self._spk_wav.setnchannels(CHANNELS)
        self._spk_wav.setsampwidth(2)
        self._spk_wav.setframerate(SAMPLE_RATE)

    def close_wav_writers(self) -> None:
        for w in (self._mic_wav, self._spk_wav):
            if w is not None:
                try:
                    w.close()
                except Exception:
                    pass
        self._mic_wav = None
        self._spk_wav = None

    def start(self) -> None:
        import sounddevice as sd

        self._sd = sd
        if self.state.running:
            return
        self.state.running = True

        def mic_cb(indata, frames, time_info, status) -> None:  # noqa: ANN001
            if status:
                log.debug("mic status: %s", status)
            with self._lock:
                if not self.state.mic_enabled:
                    return
            pcm = bytes(indata)
            if self._mic_wav:
                try:
                    self._mic_wav.writeframes(pcm)
                except Exception:
                    pass
            if self.on_mic_chunk:
                self.on_mic_chunk(pcm)

        def spk_cb(indata, frames, time_info, status) -> None:  # noqa: ANN001
            if status:
                log.debug("spk status: %s", status)
            with self._lock:
                if not self.state.speaker_enabled:
                    return
            pcm = bytes(indata)
            if self._spk_wav:
                try:
                    self._spk_wav.writeframes(pcm)
                except Exception:
                    pass
            if self.on_speaker_chunk:
                self.on_speaker_chunk(pcm)

        block = int(SAMPLE_RATE * 0.1)
        try:
            self._mic_stream = sd.InputStream(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype=DTYPE,
                blocksize=block,
                device=self.mic_device,
                callback=mic_cb,
            )
            self._mic_stream.start()
        except Exception as e:
            log.error("mic start failed: %s", e)
            raise

        try:
            # Prefer loopback on Windows if available
            kwargs: dict[str, Any] = dict(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype=DTYPE,
                blocksize=block,
                device=self.speaker_device,
                callback=spk_cb,
            )
            self._spk_stream = sd.InputStream(**kwargs)
            self._spk_stream.start()
        except Exception as e:
            log.warning("speaker stream failed (virtual cable?): %s", e)
            self._spk_stream = None

    def stop(self) -> None:
        self.state.running = False
        for s in (self._mic_stream, self._spk_stream):
            if s is not None:
                try:
                    s.stop()
                    s.close()
                except Exception:
                    pass
        self._mic_stream = None
        self._spk_stream = None
        self.close_wav_writers()

    @staticmethod
    def list_devices() -> list[dict[str, Any]]:
        try:
            import sounddevice as sd

            return list(sd.query_devices())
        except Exception:
            return []

    @staticmethod
    def check_mic_permission() -> tuple[bool, str]:
        """Best-effort mic permission probe."""
        try:
            import sounddevice as sd

            rec = sd.rec(int(0.05 * SAMPLE_RATE), samplerate=SAMPLE_RATE, channels=1, dtype=DTYPE)
            sd.wait()
            _ = np.asarray(rec)
            return True, "Mikrofon OK"
        except Exception as e:
            msg = str(e).lower()
            if "denied" in msg or "permission" in msg or "not authorized" in msg:
                return False, (
                    "Izin mikrofon ditolak untuk Trareon Transcribe. "
                    "macOS: System Settings → Privacy & Security → Microphone → "
                    "aktifkan «Trareon Transcribe» (bukan «Python»). "
                    "Jalankan via ./scripts/run_mac_app.sh agar dialog izin memakai nama app. "
                    "Windows: Settings → Privacy → Microphone."
                )
            return False, f"Mikrofon tidak bisa diakses: {e}"
