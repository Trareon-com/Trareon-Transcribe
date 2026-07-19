"""WCAG-ish contrast checks for the shared palette."""

from __future__ import annotations

from ui.theme import COLORS


def _channel(c: float) -> float:
    c = c / 255.0
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def _luminance(hex_color: str) -> float:
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b)


def contrast_ratio(fg: str, bg: str) -> float:
    l1, l2 = _luminance(fg), _luminance(bg)
    lighter, darker = max(l1, l2), min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def test_light_text_contrast_aa() -> None:
    c = COLORS["light"]
    assert contrast_ratio(c["text"], c["panel"]) >= 7.0
    assert contrast_ratio(c["muted"], c["panel"]) >= 4.5
    assert contrast_ratio(c["label"], c["panel"]) >= 4.5
    assert contrast_ratio(c["on_accent"], c["accent"]) >= 4.5
    assert contrast_ratio(c["mic"], c["panel"]) >= 4.5
    assert contrast_ratio(c["hud_fg"], c["accent_soft"]) >= 4.5


def test_dark_text_contrast_aa() -> None:
    c = COLORS["dark"]
    assert contrast_ratio(c["text"], c["panel"]) >= 7.0
    assert contrast_ratio(c["muted"], c["panel"]) >= 4.5
    assert contrast_ratio(c["on_accent"], c["accent"]) >= 4.5
    assert contrast_ratio(c["mic"], c["panel"]) >= 4.5
    assert contrast_ratio(c["hud_fg"], c["accent_soft"]) >= 4.5
