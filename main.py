#!/usr/bin/env python3
"""Trareon Transcribe entrypoint."""

from __future__ import annotations

import os
import sys


def main() -> int:
    from util.logging import setup_logging

    log = setup_logging()
    demo = "--demo" in sys.argv

    from config.branding import APP_NAME, set_window_icon
    from config.instance_lock import acquire_instance_lock
    from config.settings import Settings

    if not acquire_instance_lock():
        import tkinter as tk
        import tkinter.messagebox as messagebox

        root = tk.Tk()
        root.withdraw()
        root.title(APP_NAME)
        messagebox.showinfo(
            APP_NAME,
            f"{APP_NAME} sudah berjalan.\n"
            "Cek Dock / system tray, atau tutup instance lama lalu coba lagi.\n\n"
            "Jika macet: rm -f ~/Library/Application\\ Support/TrareonTranscribe/instance.lock",
        )
        root.destroy()
        return 1

    settings = Settings.load()
    demo_sessions = []
    if demo:
        from engine.demo_seed import seed_demo_sessions

        demo_sessions = seed_demo_sessions(force="--force-demo" in sys.argv)
        settings = Settings.load()
        log.info("Demo mode: %d session(s) ready", len(demo_sessions))

    log.info("Starting %s (setup_complete=%s)", APP_NAME, settings.setup_complete)
    if os.environ.get("CURSOR_TRACE_ID") or "CURSOR" in os.environ.get("TERM_PROGRAM", "").upper():
        log.warning("Launched from IDE terminal — prefer: ./scripts/run_mac_app.sh")

    from ui.main_window import MainWindow
    from ui.theme import apply_theme
    from ui.wizard import SetupWizard

    apply_theme(settings.theme)
    app = MainWindow(settings)
    set_window_icon(app)
    app.title(APP_NAME)

    def show_main() -> None:
        app.deiconify()
        app.lift()
        app.focus_force()
        try:
            app.attributes("-topmost", True)
            app.after(350, lambda: app.attributes("-topmost", app.settings.always_on_top))
        except Exception:
            pass
        app.refresh_readiness()  # noqa: SLF001
        if demo and demo_sessions:
            app.after(500, lambda: _open_demo_ui(app, demo_sessions[0]))

    def after_wizard() -> None:
        app.settings = Settings.load()
        show_main()

    if not settings.setup_complete and not demo:
        # Do NOT withdraw the root on macOS — Toplevel children of a withdrawn
        # master often never appear. Keep root mapped but behind the wizard.
        app.geometry("920x640+120+80")
        app.deiconify()
        app.update_idletasks()
        wiz = SetupWizard(app, settings, on_done=after_wizard)
        set_window_icon(wiz)
        app.lower()
        wiz.lift()
        wiz.focus_force()
        app.after(100, wiz.lift)
    else:
        if settings.window_x is not None and settings.window_x < -50:
            app.geometry("920x640+120+80")
        show_main()

    app.mainloop()
    return 0


def _open_demo_ui(app, session) -> None:  # noqa: ANN001
    """Fill main captions + open Library player so dummy data is visible immediately."""
    from export.writer import format_caption_line
    from ui.library import LibraryWindow
    from ui.transcript_player import TranscriptPlayerWindow

    app.session = session
    app.title_var.set(session.meta.title)
    app.caption.delete("1.0", "end")
    for seg in session.segments:
        if seg.is_final and seg.text.strip():
            app.caption.insert("end", format_caption_line(seg) + "\n", "final")
    app.status_var.set("DEMO — data dummy (bukan rekaman live)")
    lib = LibraryWindow(app, app.settings.library_path())
    TranscriptPlayerWindow(lib, session.root)


if __name__ == "__main__":
    sys.exit(main())
