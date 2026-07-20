"""Pure helpers for window-edge text wrapping."""

from ui.theme import wrap_width_for


def test_wrap_prefers_widget_width() -> None:
    assert wrap_width_for(320, 100, 200) == 312


def test_wrap_falls_back_to_master() -> None:
    assert wrap_width_for(0, 400, 200) == 376


def test_wrap_falls_back_to_window() -> None:
    assert wrap_width_for(0, 0, 500) == 500
