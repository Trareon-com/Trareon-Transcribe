"""UI-safe callbacks: workers never touch Tk directly."""

from __future__ import annotations

import queue
import threading
from collections.abc import Callable
from typing import Any


class UiEventQueue:
    """Thread-safe queue drained on the UI thread via widget.after()."""

    def __init__(self) -> None:
        self._q: queue.Queue[tuple[Callable[..., None], tuple[Any, ...]]] = queue.Queue()

    def post(self, fn: Callable[..., None], *args: Any) -> None:
        self._q.put((fn, args))

    def drain(self, max_items: int = 64) -> None:
        for _ in range(max_items):
            try:
                fn, args = self._q.get_nowait()
            except queue.Empty:
                break
            fn(*args)


def run_in_thread(target: Callable[..., None], *args: Any, name: str | None = None) -> threading.Thread:
    t = threading.Thread(target=target, args=args, name=name, daemon=True)
    t.start()
    return t


def ui_after(widget: Any, fn: Callable[[], None], delay_ms: int = 0) -> None:
    """Schedule on Tk main loop; no-op if widget already destroyed / no mainloop."""
    try:
        widget.after(delay_ms, fn)
    except RuntimeError:
        pass
