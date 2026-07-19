#!/usr/bin/env python3
"""Capture polished UI screenshots for README (uses demo seed data)."""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
os.environ.setdefault("TRAREON_NO_RELAUNCH", "1")

OUT = ROOT / "docs" / "screenshots"
OUT.mkdir(parents=True, exist_ok=True)


def grab(path: Path, widget) -> None:  # noqa: ANN001
    widget.update_idletasks()
    widget.update()
    time.sleep(0.5)
    from PIL import ImageGrab

    widget.lift()
    widget.focus_force()
    widget.update()
    x = widget.winfo_rootx()
    y = widget.winfo_rooty()
    w = max(widget.winfo_width(), 50)
    h = max(widget.winfo_height(), 50)
    if w < 200:
        w, h = 920, 640
    img = ImageGrab.grab(bbox=(x, y, x + w, y + h))
    # Keep README light: max width ~1400
    if img.width > 1400:
        ratio = 1400 / img.width
        img = img.resize((1400, int(img.height * ratio)))
    img.save(path, optimize=True)
    print("saved", path, f"({img.width}x{img.height})")


def main() -> int:
    from config.branding import APP_NAME, ensure_tk_registered, set_window_icon
    from config.settings import Settings
    from config.version import __version__
    from engine.demo_seed import seed_demo_sessions
    from export.writer import format_caption_line
    from ui.export_dialog import ExportDialog
    from ui.library import LibraryWindow
    from ui.main_window import MainWindow
    from ui.settings_window import SettingsWindow
    from ui.theme import apply_theme
    from ui.transcript_player import TranscriptPlayerWindow
    from ui.wizard import SetupWizard

    ensure_tk_registered()
    sessions = seed_demo_sessions(force=True)
    demo = sessions[0]

    settings = Settings.load()
    settings.setup_complete = True
    settings.theme = "light"
    settings.tone_test_ok = True
    settings.last_meeting_title = demo.meta.title
    settings.model = "small"
    apply_theme("light")

    app = MainWindow(settings)
    set_window_icon(app)
    app.title(f"{APP_NAME}  v{__version__}")
    app.geometry("920x680+80+60")
    app.title_var.set(demo.meta.title)
    app.mode_var.set("rapat_online")
    app._apply_mode_defaults()  # noqa: SLF001
    app.caption.delete("1.0", "end")
    confs: list[float] = []
    for seg in demo.segments:
        if seg.is_final and seg.text.strip():
            app.caption.insert("end", format_caption_line(seg) + "\n", "final")
            confs.append(seg.confidence)
    app.rec_label.configure(text="● REC")
    app.timer_var.set("00:00:42")
    app.status_var.set("Listening")
    if confs:
        app.conf_var.set(f"Conf {sum(confs) / len(confs):.0%}")
    app.res_var.set("CPU 14%  RAM 2.1G  GPU 3%")
    app.mic_vu.set(0.55)
    app.spk_vu.set(0.72)
    app.ready_var.set("Siap merekam · model small · tone-test OK")
    app.banner_var.set("")
    app.update()
    grab(OUT / "01-main-light.png", app)

    settings.theme = "dark"
    app.settings.theme = "dark"
    apply_theme("dark")
    app.colors = apply_theme("dark")
    app.update()
    grab(OUT / "02-main-dark.png", app)

    apply_theme("light")
    app.settings.theme = "light"
    app.colors = apply_theme("light")

    wiz = SetupWizard(app, settings, on_done=lambda: None)
    wiz.geometry("720x560+120+80")
    wiz.update()
    grab(OUT / "03-setup-wizard.png", wiz)
    wiz.destroy()

    lib = LibraryWindow(app, settings.library_path())
    lib.geometry("780x520+100+80")
    lib.update()
    grab(OUT / "04-library.png", lib)

    player = TranscriptPlayerWindow(lib, demo.root)
    player.geometry("860x600+140+90")
    player.update()
    grab(OUT / "05-transcript-player.png", player)
    player.destroy()
    lib.destroy()

    sett = SettingsWindow(app, settings)
    sett.geometry("540x640+120+70")
    sett.update()
    grab(OUT / "06-settings.png", sett)
    sett.destroy()

    exp = ExportDialog(app, demo, demo.meta.title, settings)
    exp.geometry("480x420+160+100")
    exp.update()
    grab(OUT / "07-export.png", exp)
    exp.destroy()

    app.destroy()
    print("done — screenshots in", OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
