"""Whisper binary URL selection."""

from setup.model_dl import WHISPER_CPP_TAG, WHISPER_WIN_ZIP


def test_windows_zip_points_at_live_tag() -> None:
    assert WHISPER_CPP_TAG == "v1.9.1"
    assert "whisper-bin-x64.zip" in WHISPER_WIN_ZIP
    assert "v1.7.5" not in WHISPER_WIN_ZIP
