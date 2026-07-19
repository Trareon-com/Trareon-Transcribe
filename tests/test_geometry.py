"""Window geometry sanitization."""

from config.settings import sanitize_geometry


def test_sanitize_rejects_tiny() -> None:
    assert sanitize_geometry("400x300") == "1000x740"


def test_sanitize_keeps_ok() -> None:
    assert sanitize_geometry("1000x740") == "1000x740"
    assert sanitize_geometry("1200x800+10+10") == "1200x800"


def test_sanitize_malformed() -> None:
    assert sanitize_geometry("nope") == "1000x740"
