"""AudioCapture levels for VU meters."""

from __future__ import annotations

import numpy as np

from engine.audio_capture import AudioCapture


def test_note_level_updates_mic() -> None:
    cap = AudioCapture()
    # loud-ish tone
    samples = (np.sin(np.linspace(0, 40, 1600)) * 12000).astype(np.int16)
    cap._note_level(samples.tobytes(), "mic")  # noqa: SLF001
    mic, spk = cap.levels()
    assert mic > 0.05
    assert spk == 0.0


def test_mute_zeros_level() -> None:
    cap = AudioCapture()
    samples = (np.ones(800) * 8000).astype(np.int16)
    cap._note_level(samples.tobytes(), "spk")  # noqa: SLF001
    assert cap.levels()[1] > 0
    cap.set_speaker_enabled(False)
    assert cap.levels()[1] == 0.0
