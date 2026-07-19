"""Dual VAD: WebRTC (fast gate) + Silero (accuracy) when available."""

from __future__ import annotations

import logging
from typing import Protocol

import numpy as np

log = logging.getLogger("trareon.vad")


class VadGate(Protocol):
    def is_speech(self, pcm16: bytes, sample_rate: int = 16000) -> bool: ...


class WebRtcVad:
    def __init__(self, aggressiveness: int = 2) -> None:
        self._vad = None
        try:
            import webrtcvad

            self._vad = webrtcvad.Vad(aggressiveness)
        except Exception as e:
            log.warning("webrtcvad unavailable: %s", e)

    def is_speech(self, pcm16: bytes, sample_rate: int = 16000) -> bool:
        if self._vad is None:
            # Fail open: treat as speech so we don't drop everything
            return _energy_speech(pcm16)
        # WebRTC wants 10/20/30ms frames
        frame_len = int(sample_rate * 0.02) * 2  # 20ms 16-bit
        if len(pcm16) < frame_len:
            return _energy_speech(pcm16)
        speech = 0
        total = 0
        for i in range(0, len(pcm16) - frame_len + 1, frame_len):
            frame = pcm16[i : i + frame_len]
            total += 1
            try:
                if self._vad.is_speech(frame, sample_rate):
                    speech += 1
            except Exception:
                continue
        if total == 0:
            return _energy_speech(pcm16)
        return (speech / total) >= 0.3


class SileroVad:
    def __init__(self) -> None:
        self._model = None
        try:
            import torch

            model, _ = torch.hub.load(
                repo_or_dir="snakers4/silero-vad",
                model="silero_vad",
                trust_repo=True,
                verbose=False,
            )
            self._model = model
            self._torch = torch
        except Exception as e:
            log.info("Silero VAD unavailable, using WebRTC/energy only: %s", e)

    def is_speech(self, pcm16: bytes, sample_rate: int = 16000) -> bool:
        if self._model is None:
            return True
        audio = np.frombuffer(pcm16, dtype=np.int16).astype(np.float32) / 32768.0
        if audio.size < 512:
            return _energy_speech(pcm16)
        try:
            tensor = self._torch.from_numpy(audio)
            prob = self._model(tensor, sample_rate).item()
            return prob >= 0.45
        except Exception:
            return _energy_speech(pcm16)


class DualVad:
    def __init__(self) -> None:
        self.webrtc = WebRtcVad()
        self.silero = SileroVad()

    def is_speech(self, pcm16: bytes, sample_rate: int = 16000) -> bool:
        if not self.webrtc.is_speech(pcm16, sample_rate):
            return False
        return self.silero.is_speech(pcm16, sample_rate)


def _energy_speech(pcm16: bytes, threshold: float = 500.0) -> bool:
    if not pcm16:
        return False
    arr = np.frombuffer(pcm16, dtype=np.int16)
    if arr.size == 0:
        return False
    return float(np.abs(arr).mean()) >= threshold
