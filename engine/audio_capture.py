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

# Virtual loopback inputs only — never treat the built-in mic as "speaker".
_LOOPBACK_HINTS = (
    "blackhole",
    "vb-audio",
    "vb cable",
    "cable output",
    "cable input",
    "voicemeeter",
    "soundflower",
    "loopback",
    "virtual cable",
)


def find_loopback_input_device() -> int | None:
    """Index of a virtual cable / BlackHole input, or None if not installed."""
    try:
        import sounddevice as sd
    except Exception:
        return None
    try:
        devices = list(sd.query_devices())
    except Exception:
        return None
    for i, d in enumerate(devices):
        if int(d.get("max_input_channels") or 0) < 1:
            continue
        name = str(d.get("name") or "").lower()
        if any(h in name for h in _LOOPBACK_HINTS):
            return i
    return None


def resolve_speaker_input_device(explicit: Any = None) -> Any:
    """Use explicit device, else a real loopback — never default mic."""
    if explicit is not None and explicit != "":
        return explicit
    return find_loopback_input_device()


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
        self._mic_level = 0.0
        self._spk_level = 0.0
        # Adaptive ambient estimate — quiet room (fan/AC) should read flat on VU.
        self._noise_mic = 0.045
        self._noise_spk = 0.045
        self.speaker_ok = True  # False when no loopback device; mic-only degrade
        self.speaker_device_resolved: Any = None
        self._mic_cb: Callable[..., None] | None = None
        self._spk_cb: Callable[..., None] | None = None
        self._watch_thread: threading.Thread | None = None
        self._watch_stop = threading.Event()

    def set_mic_enabled(self, enabled: bool) -> None:
        with self._lock:
            self.state.mic_enabled = enabled
            # Do not zero VU — mute is for record/STT only; meters stay live.

    def set_speaker_enabled(self, enabled: bool) -> None:
        with self._lock:
            self.state.speaker_enabled = enabled

    def levels(self) -> tuple[float, float]:
        """Return (mic, speaker) peak levels in 0.0–1.0 for VU meters."""
        with self._lock:
            return self._mic_level, self._spk_level

    # Speech headroom above adaptive floor → full-scale VU.
    _SPEECH_SPAN = 0.22

    def _note_level(self, pcm: bytes, which: str) -> None:
        if not pcm:
            return
        arr = np.frombuffer(pcm, dtype=np.int16)
        if arr.size == 0:
            return
        rms = float(np.sqrt(np.mean(arr.astype(np.float32) ** 2))) / 32768.0
        with self._lock:
            est = self._noise_mic if which == "mic" else self._noise_spk
            # Track ambient only when frame looks like room noise, not speech.
            if rms < max(est * 2.4, 0.14):
                est = min(0.14, 0.90 * est + 0.10 * rms)
                if which == "mic":
                    self._noise_mic = est
                else:
                    self._noise_spk = est
            floor = max(0.035, est * 1.7)
            if rms < floor:
                level = 0.0
            else:
                level = min(1.0, (rms - floor) / self._SPEECH_SPAN)
            if which == "mic":
                if level <= 0:
                    self._mic_level *= 0.30
                    if self._mic_level < 0.04:
                        self._mic_level = 0.0
                else:
                    self._mic_level = max(level, self._mic_level * 0.55)
            else:
                if level <= 0:
                    self._spk_level *= 0.30
                    if self._spk_level < 0.04:
                        self._spk_level = 0.0
                else:
                    self._spk_level = max(level, self._spk_level * 0.55)

    def decay_levels(self, factor: float = 0.82) -> None:
        """Idle decay so meters fall when the room is quiet."""
        with self._lock:
            self._mic_level *= factor
            self._spk_level *= factor
            if self._mic_level < 0.04:
                self._mic_level = 0.0
            if self._spk_level < 0.04:
                self._spk_level = 0.0

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
        self.speaker_ok = True

        def mic_cb(indata, frames, time_info, status) -> None:  # noqa: ANN001
            if status:
                log.debug("mic status: %s", status)
            pcm = indata.tobytes() if hasattr(indata, "tobytes") else bytes(indata)
            # VU always tracks hardware; mute only skips WAV / STT.
            self._note_level(pcm, "mic")
            with self._lock:
                enabled = self.state.mic_enabled
            if not enabled:
                return
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
            pcm = indata.tobytes() if hasattr(indata, "tobytes") else bytes(indata)
            self._note_level(pcm, "spk")
            with self._lock:
                enabled = self.state.speaker_enabled
            if not enabled:
                return
            if self._spk_wav:
                try:
                    self._spk_wav.writeframes(pcm)
                except Exception:
                    pass
            if self.on_speaker_chunk:
                self.on_speaker_chunk(pcm)

        self._mic_cb = mic_cb
        self._spk_cb = spk_cb
        self._block = int(SAMPLE_RATE * 0.1)
        self._open_mic_stream()
        self._open_spk_stream()

        self._watch_stop.clear()
        self._watch_thread = threading.Thread(
            target=self._watchdog_loop, name="audio-watchdog", daemon=True
        )
        self._watch_thread.start()

    def _open_mic_stream(self) -> None:
        try:
            self._mic_stream = self._sd.InputStream(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype=DTYPE,
                blocksize=self._block,
                device=self.mic_device,
                callback=self._mic_cb,
            )
            self._mic_stream.start()
        except Exception as e:
            log.error("mic start failed: %s", e)
            self._mic_stream = None
            raise

    def _open_spk_stream(self) -> None:
        # SPK must be a virtual loopback. Default input is the mic — using it
        # makes MIC and SPK VU rise together and records the wrong source.
        spk_dev = resolve_speaker_input_device(self.speaker_device)
        self.speaker_device_resolved = spk_dev
        if spk_dev is None:
            log.info(
                "No virtual loopback (BlackHole / VB-Cable) — speaker capture disabled"
            )
            self._spk_stream = None
            self.speaker_ok = False
            with self._lock:
                self._spk_level = 0.0
            return
        try:
            self._spk_stream = self._sd.InputStream(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype=DTYPE,
                blocksize=self._block,
                device=spk_dev,
                callback=self._spk_cb,
            )
            self._spk_stream.start()
            self.speaker_ok = True
            log.info("Speaker loopback device: %s", spk_dev)
        except Exception as e:
            log.warning("speaker stream failed (virtual cable?): %s", e)
            self._spk_stream = None
            self.speaker_ok = False
            with self._lock:
                self._spk_level = 0.0

    def _watchdog_loop(self) -> None:
        """Detect device disconnects (sleep/wake, USB unplug) and reopen streams."""
        while not self._watch_stop.wait(2.0):
            if not self.state.running:
                return
            if self._mic_stream is not None and not self._mic_stream.active:
                log.warning("mic stream inactive — attempting reconnect")
                try:
                    self._mic_stream.close()
                except Exception:
                    pass
                try:
                    self._open_mic_stream()
                    log.info("mic stream reconnected")
                except Exception as e:
                    log.error("mic reconnect failed: %s", e)
            if self.speaker_device is not None or self.speaker_ok:
                if self._spk_stream is not None and not self._spk_stream.active:
                    log.warning("speaker stream inactive — attempting reconnect")
                    try:
                        self._spk_stream.close()
                    except Exception:
                        pass
                    try:
                        self._open_spk_stream()
                        log.info("speaker stream reconnected")
                    except Exception as e:
                        log.error("speaker reconnect failed: %s", e)
                elif self._spk_stream is None and find_loopback_input_device() is not None:
                    # Loopback device appeared after startup (e.g. driver install) or
                    # came back after being unplugged — pick it back up.
                    log.info("loopback device now available — opening speaker stream")
                    try:
                        self._open_spk_stream()
                    except Exception as e:
                        log.debug("speaker stream retry failed: %s", e)

    def stop(self) -> None:
        self.state.running = False
        self._watch_stop.set()
        if self._watch_thread is not None:
            self._watch_thread.join(timeout=3.0)
        self._watch_thread = None
        for s in (self._mic_stream, self._spk_stream):
            if s is not None:
                try:
                    s.stop()
                    s.close()
                except Exception:
                    pass
        self._mic_stream = None
        self._spk_stream = None
        with self._lock:
            self._mic_level = 0.0
            self._spk_level = 0.0
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
