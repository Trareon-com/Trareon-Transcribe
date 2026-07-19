"""Minimize to system tray; transcription continues."""

from __future__ import annotations

import logging
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

        image = Image.new("RGB", (64, 64), "#0B6E4F")
        d = ImageDraw.Draw(image)
        d.ellipse((12, 12, 52, 52), fill="#FFFFFF")

        menu = pystray.Menu(
            pystray.MenuItem("Show", lambda: self.on_show()),
            pystray.MenuItem("Quit", lambda: self.on_quit()),
        )
        self._icon = pystray.Icon("TrareonTranscribe", image, "Trareon Transcribe", menu)

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
