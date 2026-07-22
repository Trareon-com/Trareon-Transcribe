import numpy as np

from engine.vad import DualVad, WebRtcVad, _energy_speech


def _tone(freq: float = 440.0, ms: int = 300, amp: float = 12000, rate: int = 16000) -> bytes:
    n = int(rate * ms / 1000)
    t = np.arange(n) / rate
    wave = (amp * np.sin(2 * np.pi * freq * t)).astype(np.int16)
    return wave.tobytes()


def _silence(ms: int = 300, rate: int = 16000) -> bytes:
    return np.zeros(int(rate * ms / 1000), dtype=np.int16).tobytes()


def test_energy_speech_detects_loud_tone():
    assert _energy_speech(_tone()) is True


def test_energy_speech_rejects_silence():
    assert _energy_speech(_silence()) is False


def test_energy_speech_empty_bytes():
    assert _energy_speech(b"") is False


def test_webrtc_vad_falls_back_on_short_frame():
    vad = WebRtcVad()
    short = _tone(ms=5)
    # Too short for a 20ms frame — must fall back to energy heuristic, not crash.
    assert vad.is_speech(short) is True


def test_dual_vad_rejects_silence():
    vad = DualVad()
    assert vad.is_speech(_silence()) is False


def test_dual_vad_accepts_loud_tone():
    vad = DualVad()
    assert vad.is_speech(_tone()) is True
