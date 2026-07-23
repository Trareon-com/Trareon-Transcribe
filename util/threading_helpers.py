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


def ensure_ui_after_pump(widget: Any) -> None:
    """Call once from widget's __init__ (guaranteed main-thread context)
    before any background thread calls ui_after(widget, ...).

    Calling widget.after() directly from a non-main thread does not reliably
    wake Tcl's event loop — Tcl/Tk's cross-thread `after` scheduling isn't
    guaranteed thread-safe, and in practice a callback queued that way can
    simply never fire, silently hanging whatever was waiting on it
    (confirmed: this is exactly what caused Export/model-download/
    update-check to hang forever with no error, every time). The reliable
    pattern already used for live transcription segments is a
    background-safe queue drained by a main-thread-owned recurring
    self.after() poll — this sets up that same pump for any widget that
    wants to use ui_after(). Idempotent; safe to call more than once.
    """
    if getattr(widget, "_trareon_ui_after_queue", None) is not None:
        return
    q: queue.Queue[Callable[[], None]] = queue.Queue()
    widget._trareon_ui_after_queue = q

    def _drain() -> None:
        for _ in range(64):
            try:
                cb = q.get_nowait()
            except queue.Empty:
                break
            try:
                cb()
            except Exception:
                pass
        try:
            widget.after(25, _drain)
        except Exception:
            pass

    widget.after(25, _drain)


def ui_after(widget: Any, fn: Callable[[], None], delay_ms: int = 0) -> None:
    """Queue fn to run on the Tk main loop — thread-safe, never calls
    widget.after() directly (see ensure_ui_after_pump for why). Requires
    ensure_ui_after_pump(widget) to have been called from __init__; falls
    back to a direct (unreliable cross-thread) widget.after() call if not,
    rather than silently dropping fn."""
    q = getattr(widget, "_trareon_ui_after_queue", None)
    if q is None:
        try:
            widget.after(delay_ms, fn)
        except Exception:
            pass
        return
    if delay_ms <= 0:
        q.put(fn)
    else:
        threading.Timer(delay_ms / 1000, lambda: q.put(fn)).start()
