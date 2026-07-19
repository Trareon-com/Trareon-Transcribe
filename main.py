#!/usr/bin/env python3
"""Trareon Transcribe entrypoint."""

from __future__ import annotations

import sys
import tkinter as tk
import tkinter.messagebox as messagebox

from config.instance_lock import acquire_instance_lock
from config.settings import Settings
from util.logging import setup_logging


def main() -> int:
    log = setup_logging()
    if not acquire_instance_lock():
        root = tk.Tk()
        root.withdraw()
        messagebox.showinfo(
            "Trareon Transcribe",
            "Aplikasi sudah berjalan. Tutup instance lain atau gunakan dari system tray.",
        )
        root.destroy()
        return 1

    settings = Settings.load()
    log.info("Starting Trareon Transcribe (setup_complete=%s)", settings.setup_complete)

    # Import UI after logging/lock

    from ui.main_window import MainWindow
    from ui.theme import apply_theme
    from ui.wizard import SetupWizard

    apply_theme(settings.theme)
    app = MainWindow(settings)

    def after_wizard() -> None:
        settings.setup_complete = True
        settings.save()
        app.deiconify()
        app._update_tone_banner()  # noqa: SLF001

    if not settings.setup_complete:
        app.withdraw()
        SetupWizard(app, settings, on_done=after_wizard)
    else:
        app.deiconify()

    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
