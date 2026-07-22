"""Integration: capture chunk -> VAD -> STT -> dedupe -> export, with fixture audio."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest

from engine.pipeline import Pipeline
from engine.session_store import create_session
from export.writer import write_markdown, write_txt
from util.threading_helpers import UiEventQueue


def _speech_pcm(ms: int = 400, rate: int = 16000) -> bytes:
    n = int(rate * ms / 1000)
    t = np.arange(n) / rate
    tone = (12000 * np.sin(2 * np.pi * 220 * t)).astype(np.int16)
    return tone.tobytes()


def _silence_pcm(ms: int = 400, rate: int = 16000) -> bytes:
    return np.zeros(int(rate * ms / 1000), dtype=np.int16).tobytes()


class StubStt:
    """Deterministic STT stub — avoids depending on a real whisper.cpp binary."""

    def __init__(self, text: str, language: str = "id") -> None:
        self._text = text
        self._language = language

    def transcribe(self, pcm: bytes, sample_rate: int):  # noqa: ANN001
        from engine.stt import SttResult

        return SttResult(text=self._text, language=self._language, confidence=0.9)


class _EnergyVad:
    """Simple energy-gate stand-in — VAD correctness itself is covered by test_vad.py."""

    def is_speech(self, pcm16: bytes, sample_rate: int = 16000) -> bool:
        arr = np.frombuffer(pcm16, dtype=np.int16)
        return arr.size > 0 and float(np.abs(arr).mean()) >= 500.0


@pytest.fixture
def pipeline(tmp_path: Path) -> Pipeline:
    p = Pipeline(
        settings_mode="rapat_online",
        model_name="tiny",
        library_root=str(tmp_path),
        events=UiEventQueue(),
    )
    p.session = create_session(tmp_path, "Fixture Meeting", "rapat_online")
    p._start_mono = 0.0
    p._vad = _EnergyVad()
    return p


def test_silence_chunk_is_dropped_by_vad(pipeline: Pipeline):
    pipeline._stt = StubStt("should not appear")
    pipeline._process_chunk("MIC", _silence_pcm())
    assert pipeline.session.segments == []


def test_speech_chunk_flows_to_session_and_export(pipeline: Pipeline, tmp_path: Path):
    pipeline._stt = StubStt("halo semua, ini rapat")
    pipeline._process_chunk("MIC", _speech_pcm())
    assert len(pipeline.session.segments) == 1
    seg = pipeline.session.segments[0]
    assert seg.text == "halo semua, ini rapat"
    assert seg.is_final is True

    md = write_markdown(pipeline.session)
    txt = write_txt(pipeline.session)
    assert "halo semua, ini rapat" in md.read_text()
    assert "halo semua, ini rapat" in txt.read_text()


def test_echo_dedupe_drops_speaker_repeat_in_rapat_online(pipeline: Pipeline):
    pipeline._stt = StubStt("mohon maaf saya terlambat")
    pipeline._process_chunk("MIC", _speech_pcm())
    assert len(pipeline.session.segments) == 1

    # SPEAKER produces the same sentence shortly after (loopback echo of our own mic) —
    # rapat_online dedupe should drop it.
    pipeline._process_chunk("SPEAKER", _speech_pcm())
    assert len(pipeline.session.segments) == 1
