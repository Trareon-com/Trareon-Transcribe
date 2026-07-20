"""Setup wizard gate — when to block the main window."""

from __future__ import annotations

from unittest.mock import patch

from config.settings import Settings
from setup.gate import clear_false_tone_ok, needs_setup_wizard


def test_demo_never_needs_wizard() -> None:
    s = Settings(setup_complete=False)
    assert needs_setup_wizard(s, demo=True) is False


def test_incomplete_setup_needs_wizard() -> None:
    s = Settings(setup_complete=False)
    assert needs_setup_wizard(s, demo=False) is True


def test_no_loopback_forces_wizard_until_skip_or_ok() -> None:
    s = Settings(setup_complete=True, tone_test_ok=False, tone_test_skipped=False, model="tiny")
    with (
        patch("engine.stt.WhisperCppStt.available", return_value=True),
        patch("engine.audio_capture.find_loopback_input_device", return_value=None),
    ):
        assert needs_setup_wizard(s, demo=False) is True
        s.tone_test_skipped = True
        assert needs_setup_wizard(s, demo=False) is False


def test_clear_false_tone_ok() -> None:
    s = Settings(tone_test_ok=True)
    with patch("engine.audio_capture.find_loopback_input_device", return_value=None):
        with patch.object(Settings, "save", lambda self: None):
            clear_false_tone_ok(s)
    assert s.tone_test_ok is False
