"""Minimize to system tray; transcription continues."""

from __future__ import annotations

import logging
import sys
import threading
from collections.abc import Callable
from typing import Any

log = logging.getLogger("trareon.tray")


class TrayController:
    def __init__(self, on_show: Callable[[], None], on_quit: Callable[[], None]) -> None:
        self.on_show = on_show
        self.on_quit = on_quit
        self._icon: Any = None
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        try:
            import pystray
            from PIL import Image, ImageDraw
        except ImportError:
            log.warning("pystray/PIL missing — tray disabled")
            return

        from config.branding import APP_NAME, icon_png

        png = icon_png()
        if png.exists():
            image = Image.open(png).resize((64, 64))
        else:
            image = Image.new("RGB", (64, 64), "#0B6E4F")
            d = ImageDraw.Draw(image)
            d.ellipse((12, 12, 52, 52), fill="#FFFFFF")

        menu = pystray.Menu(
            pystray.MenuItem(f"Show {APP_NAME}", lambda: self.on_show(), default=True),
            pystray.MenuItem("Quit", lambda: self.on_quit()),
        )
        self._icon = pystray.Icon("TrareonTranscribe", image, APP_NAME, menu)

        if sys.platform == "darwin":
            # pystray's macOS backend wraps AppKit/NSStatusBar, which asserts if
            # driven off the main thread (fatal EXC_BREAKPOINT — takes the whole
            # app down, not just the tray). Tk's Cocoa integration already pumps
            # the shared NSApplication run loop on the main thread, so we only
            # need to mark the status item ready here; call this from the Tk
            # callback (main thread), never from a background thread.
            try:
                self._icon.run_detached()
            except Exception:
                log.warning("tray run_detached failed — tray disabled", exc_info=True)
                self._icon = None
            return

        def run() -> None:
            assert self._icon is not None
            self._icon.run()

        self._thread = threading.Thread(target=run, name="tray", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        if self._icon is not None:
            try:
                self._icon.stop()
            except Exception:
                pass
            self._icon = None
