"""Singleton toplevel helpers."""

from __future__ import annotations

from ui.window_util import focus_existing, open_singleton


class _Alive:
    def __init__(self) -> None:
        self.lifted = False

    def winfo_exists(self) -> bool:
        return True

    def deiconify(self) -> None:
        pass

    def lift(self) -> None:
        self.lifted = True

    def focus_force(self) -> None:
        pass

    def bind(self, *_a, **_k) -> None:  # noqa: ANN002, ANN003
        pass


class _Dead:
    def winfo_exists(self) -> bool:
        return False


def test_focus_existing_none() -> None:
    assert focus_existing(None) is False


def test_focus_existing_dead() -> None:
    assert focus_existing(_Dead()) is False


def test_focus_existing_alive() -> None:
    w = _Alive()
    assert focus_existing(w) is True
    assert w.lifted is True


def test_open_singleton_reuses() -> None:
    owner = type("O", (), {})()
    created: list[int] = []

    def factory() -> _Alive:
        created.append(1)
        return _Alive()

    a = open_singleton(owner, "win", factory)
    b = open_singleton(owner, "win", factory)
    assert a is b
    assert len(created) == 1
