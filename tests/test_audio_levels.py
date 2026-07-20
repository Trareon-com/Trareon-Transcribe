"""AudioCapture levels for VU meters."""

from __future__ import annotations

from unittest.mock import patch

import numpy as np

from engine.audio_capture import AudioCapture, find_loopback_input_device, resolve_speaker_input_device


def test_note_level_updates_mic() -> None:
    cap = AudioCapture()
    # loud-ish tone (well above noise floor)
    samples = (np.sin(np.linspace(0, 40, 1600)) * 12000).astype(np.int16)
    cap._note_level(samples.tobytes(), "mic")  # noqa: SLF001
    mic, spk = cap.levels()
    assert mic > 0.05
    assert spk == 0.0


def test_quiet_room_noise_gated() -> None:
    """Fan/hush at ambient RMS must settle flat after the adaptive floor learns."""
    rng = np.random.default_rng(0)
    cap = AudioCapture()
    # ~RMS 0.05 ambient (typical laptop "quiet" room) — must not leave VU bouncing.
    for _ in range(24):
        hush = (rng.standard_normal(1600) * 1600).astype(np.int16)
        cap._note_level(hush.tobytes(), "mic")  # noqa: SLF001
        cap.decay_levels(0.88)
    assert cap.levels()[0] < 0.05


def test_speech_still_moves_vu() -> None:
    """Loud speech above learned ambient still lights the meter."""
    rng = np.random.default_rng(1)
    cap = AudioCapture()
    for _ in range(12):
        hush = (rng.standard_normal(1600) * 1600).astype(np.int16)
        cap._note_level(hush.tobytes(), "mic")  # noqa: SLF001
    speech = (np.sin(np.linspace(0, 80, 1600)) * 12000).astype(np.int16)
    cap._note_level(speech.tobytes(), "mic")  # noqa: SLF001
    assert cap.levels()[0] > 0.2


def test_mute_keeps_vu_level() -> None:
    """Mute is for record/STT only — VU indicators stay live."""
    cap = AudioCapture()
    samples = (np.ones(800) * 8000).astype(np.int16)
    cap._note_level(samples.tobytes(), "spk")  # noqa: SLF001
    assert cap.levels()[1] > 0
    cap.set_speaker_enabled(False)
    assert cap.levels()[1] > 0


def test_resolve_speaker_never_defaults_to_mic() -> None:
    """Without BlackHole/VB-Cable, speaker device must be None (not default mic)."""
    with patch("engine.audio_capture.find_loopback_input_device", return_value=None):
        assert resolve_speaker_input_device(None) is None
        assert resolve_speaker_input_device("") is None
    assert resolve_speaker_input_device(3) == 3


def test_find_loopback_matches_blackhole_name() -> None:
    fake = [
        {"name": "MacBook Pro Microphone", "max_input_channels": 1, "max_output_channels": 0},
        {"name": "BlackHole 2ch", "max_input_channels": 2, "max_output_channels": 2},
    ]
    with patch("sounddevice.query_devices", return_value=fake):
        assert find_loopback_input_device() == 1
