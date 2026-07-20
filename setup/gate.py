"""Decide whether the first-run Setup wizard must block the main window."""

from __future__ import annotations

from config.settings import Settings


def needs_setup_wizard(settings: Settings, *, demo: bool = False) -> bool:
    """True → show Setup before main (unless --demo)."""
    if demo:
        return False
    if not settings.setup_complete:
        return True

    from engine.stt import WhisperCppStt

    if not WhisperCppStt(settings.model).available():
        return True

    # Speaker path: without BlackHole/VB-Cable, force Setup until user verifies or skips tone.
    from engine.audio_capture import find_loopback_input_device

    if find_loopback_input_device() is None and not settings.tone_test_ok and not settings.tone_test_skipped:
        return True
    return False


def clear_false_tone_ok(settings: Settings) -> Settings:
    """Old tone tests could pass via mic bleed — invalidate if no loopback device."""
    from engine.audio_capture import find_loopback_input_device

    if find_loopback_input_device() is None and settings.tone_test_ok:
        settings.tone_test_ok = False
        try:
            settings.save()
        except OSError:
            pass
    return settings
