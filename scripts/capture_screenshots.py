#!/usr/bin/env python3
"""Capture UI screenshots for README (macOS/Windows)."""

from __future__ import annotations

import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

OUT = ROOT / "docs" / "screenshots"
OUT.mkdir(parents=True, exist_ok=True)


def grab(path: Path, widget) -> None:
    widget.update_idletasks()
    widget.update()
    time.sleep(0.4)
    try:
        from PIL import ImageGrab
    except ImportError:
        print("Pillow required")
        return
    widget.lift()
    widget.focus_force()
    widget.update()
    x = widget.winfo_rootx()
    y = widget.winfo_rooty()
    w = widget.winfo_width()
    h = widget.winfo_height()
    # fallback size if not mapped yet
    if w < 50:
        w, h = 920, 640
    img = ImageGrab.grab(bbox=(x, y, x + w, y + h))
    img.save(path)
    print("saved", path)


def main() -> None:
    from config.settings import Settings
    from engine.session_store import Session, SessionMeta, TranscriptSegment
    from ui.export_dialog import ExportDialog
    from ui.library import LibraryWindow
    from ui.main_window import MainWindow
    from ui.settings_window import SettingsWindow
    from ui.theme import apply_theme
    from ui.wizard import SetupWizard

    settings = Settings.load()
    settings.setup_complete = True
    settings.theme = "light"
    settings.tone_test_ok = True
    settings.last_meeting_title = "Weekly Product Sync"
    apply_theme("light")

    app = MainWindow(settings)
    app.title_var.set("Weekly Product Sync")
    app.caption.delete("1.0", "end")
    demo = [
        ("MIC", "ID", "Ini projectnya, please review ya"),
        ("SPK", "EN", "Sure, I will check tomorrow"),
        ("MIC", "ID", "Besok kita bahas di meeting"),
        ("SPK", "ID", "Oke, kirim file-nya"),
    ]
    for src, lang, text in demo:
        app.caption.insert("end", f"{src} [{lang}]: {text}\n", "final")
    app.rec_label.configure(text="● REC")
    app.timer_var.set("00:14:32")
    app.status_var.set("Listening")
    app.res_var.set("CPU 12%  RAM 1.8G")
    app.update()
    grab(OUT / "01-main-light.png", app)

    settings.theme = "dark"
    apply_theme("dark")
    app._toggle_theme()  # noqa: SLF001 — flip back? already dark from apply
    # force dark captions refresh
    apply_theme("dark")
    app.settings.theme = "dark"
    app.update()
    grab(OUT / "02-main-dark.png", app)

    # back to light for other windows
    apply_theme("light")
    app.settings.theme = "light"

    wiz = SetupWizard(app, settings, on_done=lambda: None)
    wiz.update()
    grab(OUT / "03-setup-wizard.png", wiz)
    wiz.destroy()

    lib = LibraryWindow(app, settings.library_path())
    lib.update()
    grab(OUT / "04-library.png", lib)
    lib.destroy()

    sett = SettingsWindow(app, settings)
    sett.update()
    grab(OUT / "05-settings.png", sett)
    sett.destroy()

    meta = SessionMeta(
        title="Weekly Product Sync",
        mode="rapat_online",
        created_at="2026-07-19T10:00:00+00:00",
        session_id="demo0001",
        folder_name="demo",
    )
    sess = Session(
        root=OUT,
        meta=meta,
        segments=[
            TranscriptSegment(0, 1000, "halo", "MIC", "id", 0.9, True),
        ],
    )
    exp = ExportDialog(app, sess, meta.title, settings)
    exp.update()
    grab(OUT / "06-export.png", exp)
    exp.destroy()

    app.destroy()
    print("done")


if __name__ == "__main__":
    main()
