"""Toplevel helpers — one window per role, raise if already open."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any


def focus_existing(win: Any | None) -> bool:
    if win is None:
        return False
    try:
        if not win.winfo_exists():
            return False
        win.deiconify()
        win.lift()
        win.focus_force()
        return True
    except Exception:
        return False


def track_destroy(owner: Any, attr: str, win: Any) -> None:
    """Clear owner.attr when win is destroyed (ignore child Destroy events)."""

    def _on_destroy(event: Any) -> None:
        if event.widget is win and getattr(owner, attr, None) is win:
            setattr(owner, attr, None)

    win.bind("<Destroy>", _on_destroy, add="+")


def open_singleton(
    owner: Any,
    attr: str,
    factory: Callable[[], Any],
    *,
    on_reuse: Callable[[Any], None] | None = None,
) -> Any:
    win = getattr(owner, attr, None)
    if focus_existing(win):
        if on_reuse is not None and win is not None:
            try:
                on_reuse(win)
            except Exception:
                pass
        return win
    win = factory()
    setattr(owner, attr, win)
    track_destroy(owner, attr, win)
    return win
