#!/usr/bin/env python3
"""Trareon Transcribe entrypoint."""

from __future__ import annotations

import os
import sys
import traceback


def _relaunch_via_mac_app(argv: list[str]) -> bool:
    """Leave Cursor's process tree — Tk RegisterApplication often aborts there."""
    from config.branding import project_root

    script = project_root() / "scripts" / "run_mac_app.sh"
    if not script.is_file():
        return False
    try:
        # Drop the python entry so the .app runs main.py with the same flags.
        os.execv("/bin/bash", ["bash", str(script), *argv[1:]])
    except OSError:
        return False
    return True  # unreachable on success


def main() -> int:
    from util.logging import setup_logging

    log = setup_logging()
    demo = "--demo" in sys.argv

    from config.branding import (
        APP_NAME,
        ensure_tk_registered,
        launched_from_ide_terminal,
        running_from_app_bundle,
        set_window_icon,
    )
    from config.instance_lock import acquire_instance_lock
    from config.settings import Settings

    # Before instance lock / UI: IDE terminals crash Tk; open as a real .app instead.
    if (
        sys.platform == "darwin"
        and launched_from_ide_terminal()
        and not running_from_app_bundle()
        and os.environ.get("TRAREON_NO_RELAUNCH") != "1"
    ):
        log.warning("IDE terminal detected — relaunching via ./scripts/run_mac_app.sh")
        if not _relaunch_via_mac_app(sys.argv):
            log.error(
                "Could not relaunch. Run: ./scripts/run_mac_app.sh%s",
                " --demo" if demo else "",
            )
            return 1

    if not acquire_instance_lock():
        ensure_tk_registered()
        import tkinter as tk
        import tkinter.messagebox as messagebox

        from config.paths import instance_lock_file

        lock = instance_lock_file()
        if sys.platform == "win32":
            hint = f"Jika macet, hapus file:\n{lock}"
        else:
            hint = (
                f"Jika macet:\nrm -f \"{lock}\"\n"
                f"(atau: rm -f ~/Library/Application\\ Support/TrareonTranscribe/instance.lock)"
            )
        root = tk.Tk()
        root.withdraw()
        root.title(APP_NAME)
        messagebox.showinfo(
            APP_NAME,
            f"{APP_NAME} sudah berjalan.\n"
            "Cek Dock / system tray, atau tutup instance lama lalu coba lagi.\n\n"
            f"{hint}",
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

    # customtkinter → darkdetect imports AppKit; register Tk first on macOS.
    ensure_tk_registered()

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

    def _deferred_update_check() -> None:
        if demo:
            return
        from update.check import check_for_update, open_download

        def work() -> None:
            info = check_for_update()
            if info is None or not info.update_available:
                return

            def ask() -> None:
                import tkinter.messagebox as messagebox

                if messagebox.askyesno(
                    "Update tersedia",
                    f"Versi baru {info.latest} tersedia (sekarang {info.current}).\n"
                    "Buka halaman unduhan?",
                ):
                    open_download(info)

            app.after(0, ask)

        from util.threading_helpers import run_in_thread

        run_in_thread(work)

    app.after(2500, _deferred_update_check)

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


def _fatal(exc: BaseException) -> int:
    """Log + show a dialog so double-click launches don't silently vanish."""
    try:
        from util.logging import setup_logging

        setup_logging().exception("Fatal: %s", exc)
    except Exception:
        traceback.print_exc()
    try:
        import tkinter as tk
        import tkinter.messagebox as messagebox

        from config.branding import APP_NAME, ensure_tk_registered

        ensure_tk_registered()
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror(
            APP_NAME,
            f"Gagal memulai {APP_NAME}:\n\n{exc}\n\n"
            "Cek log di Application Support / AppData, atau jalankan dari Terminal.",
        )
        root.destroy()
    except Exception:
        pass
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except BaseException as exc:  # noqa: BLE001 — last-resort UI for packaged app
        sys.exit(_fatal(exc))
