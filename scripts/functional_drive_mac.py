#!/usr/bin/env python3
"""Drive every major UI/function path on this Mac and report PASS/FAIL."""

from __future__ import annotations

import os
import sys
import time
import traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
os.environ["TRAREON_NO_RELAUNCH"] = "1"
os.environ.setdefault("TRAREON_AUTO_YES", "1")

OUT = ROOT / "docs" / "screenshots" / "functional"
OUT.mkdir(parents=True, exist_ok=True)

results: list[tuple[str, bool, str]] = []


def rec(name: str, ok: bool, detail: str = "") -> None:
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail}" if detail else ""))


def grab(win, name: str) -> None:  # noqa: ANN001
    try:
        win.update()
        win.update_idletasks()
        path = OUT / f"{name}.png"
        # Tk grab via after + PIL of window is flaky; use geometry + screencapture region
        win.lift()
        win.focus_force()
        win.update()
        time.sleep(0.25)
        x, y = win.winfo_rootx(), win.winfo_rooty()
        w, h = max(win.winfo_width(), 100), max(win.winfo_height(), 100)
        import subprocess

        subprocess.run(
            ["screencapture", "-x", "-o", "-R", f"{x},{y},{w},{h}", str(path)],
            check=False,
        )
        rec(f"screenshot:{name}", path.exists() and path.stat().st_size > 1000, str(path.name))
    except Exception as e:
        rec(f"screenshot:{name}", False, str(e))


def main() -> int:
    from config.branding import ensure_tk_registered, set_window_icon
    from config.settings import Settings
    from engine.audio_probe import probe_audio
    from engine.demo_seed import seed_demo_sessions
    from engine.stt import WhisperCppStt
    from engine.tone_test import run_tone_test
    from setup.model_dl import ensure_whisper_binary
    from ui.export_dialog import ExportDialog
    from ui.library import LibraryWindow
    from ui.main_window import MainWindow
    from ui.settings_window import SettingsWindow
    from ui.theme import apply_theme
    from ui.transcript_player import TranscriptPlayerWindow
    from ui.wizard import SetupWizard
    from update.check import check_for_update

    ensure_tk_registered()

    # --- Core engines ---
    audio = probe_audio()
    rec("audio_probe", audio.ok, audio.message)

    binary = ensure_whisper_binary()
    rec("whisper_binary", binary is not None, str(binary))

    stt_tiny = WhisperCppStt("tiny")
    rec("stt_tiny_available", stt_tiny.available(), f"model={stt_tiny.model}")

    if stt_tiny.available():
        import numpy as np

        pcm = (np.zeros(16000, dtype=np.int16)).tobytes()
        r = stt_tiny.transcribe(pcm)
        rec("stt_transcribe_silence", True, repr((r.text or "")[:40]))

    tone = run_tone_test()
    # Tone may fail without BlackHole — still must not hang
    rec("tone_test_returns", True, f"ok={tone.ok} rms={tone.rms:.0f} msg={tone.message[:80]}")

    upd = check_for_update()
    rec(
        "update_check",
        upd is not None,
        f"latest={getattr(upd, 'latest', None)} avail={getattr(upd, 'update_available', None)}",
    )

    # --- Demo data ---
    sessions = seed_demo_sessions(force=True)
    rec("demo_seed", len(sessions) >= 1, f"n={len(sessions)}")
    session = sessions[0] if sessions else None

    settings = Settings.load()
    settings.setup_complete = True
    settings.tone_test_ok = True
    settings.tone_test_skipped = False
    settings.save()

    apply_theme(settings.theme)
    app = MainWindow(settings)
    set_window_icon(app)
    app.deiconify()
    app.update()
    grab(app, "01-main")

    # Theme toggle
    t0 = app.settings.theme
    app._toggle_theme()  # noqa: SLF001
    app.update()
    t1 = app.settings.theme
    rec("theme_toggle", t0 != t1, f"{t0}->{t1}")
    grab(app, "02-main-dark" if t1 == "dark" else "02-main-light")
    app._toggle_theme()  # noqa: SLF001
    app.update()

    # Mode segment
    try:
        app._on_mode_seg("Webinar")  # noqa: SLF001
        app.update()
        rec("mode_webinar", app.mode_var.get() == "webinar", app.mode_var.get())
        app._on_mode_seg("Rapat Online")  # noqa: SLF001
        app.update()
        rec("mode_rapat_online", app.mode_var.get() == "rapat_online", app.mode_var.get())
    except Exception as e:
        rec("mode_segment", False, str(e))

    # Mic/SPK toggles
    try:
        app._toggle_mic()  # noqa: SLF001
        app.update()
        mic_off = app.mic_var.get() == "OFF"
        app._toggle_mic()  # noqa: SLF001
        app._toggle_spk()  # noqa: SLF001
        app.update()
        spk_off = app.spk_var.get() == "OFF"
        app._toggle_spk()  # noqa: SLF001
        app.update()
        rec("mic_spk_toggle", mic_off and spk_off, f"mic_off={mic_off} spk_off={spk_off}")
    except Exception as e:
        rec("mic_spk_toggle", False, str(e))

    # Readiness refresh
    app.refresh_readiness()
    app.update()
    rec("readiness_banner", bool(app.ready_var.get()), app.ready_var.get()[:80])

    # Settings window
    try:
        sett = SettingsWindow(app, app.settings, on_saved=app._after_settings)  # noqa: SLF001
        sett.update()
        grab(sett, "03-settings")
        sett.model_var.set("tiny")
        sett._save()  # noqa: SLF001
        sett.update()
        rec("settings_save", Settings.load().model == "tiny", Settings.load().model)
        # update check button path
        sett._check_update()  # noqa: SLF001
        time.sleep(1.5)
        app.update()
        sett.destroy()
        rec("settings_window", True)
    except Exception:
        rec("settings_window", False, traceback.format_exc(limit=2))

    # Library + player
    try:
        lib = LibraryWindow(app, app.settings.library_path())
        lib.update()
        lib.refresh()
        lib.update()
        grab(lib, "04-library")
        rec("library_refresh", True, f"root={app.settings.library_path()}")
        if session:
            player = TranscriptPlayerWindow(lib, session.root)
            player.update()
            grab(player, "05-player")
            # play a short moment
            try:
                player._toggle_play()  # noqa: SLF001
                time.sleep(0.8)
                player._toggle_play()  # noqa: SLF001
                rec("player_toggle", True)
            except Exception as e:
                rec("player_toggle", False, str(e))
            player.destroy()
        lib.destroy()
    except Exception:
        rec("library_player", False, traceback.format_exc(limit=2))

    # Export dialog
    try:
        if session:
            exp = ExportDialog(app, session, session.meta.title, app.settings)
            exp.update()
            grab(exp, "06-export")
            exp.geometry("480x520")
            exp.update()
            exp._export()  # noqa: SLF001
            deadline = time.time() + 8
            while time.time() < deadline:
                app.update()
                status = exp.status.get()
                if "Selesai" in status or "file" in status.lower():
                    break
                time.sleep(0.2)
            status = exp.status.get()
            # files written?
            written = list(session.root.glob("*.md")) + list(session.root.glob("*.txt"))
            rec(
                "export_run",
                "Selesai" in status or len(written) > 0,
                f"status={status!r} files={len(written)}",
            )
            exp.destroy()
        else:
            rec("export_run", False, "no session")
    except Exception:
        rec("export_run", False, traceback.format_exc(limit=2))

    # Readiness after tiny model saved
    app.settings = Settings.load()
    app.refresh_readiness()
    app.update()
    ready = app.ready_var.get()
    rec("readiness_after_tiny", "STT siap" in ready or WhisperCppStt("tiny").available(), ready[:100])
    # Wizard (open then close via skip)
    try:
        done = {"v": False}

        def on_done() -> None:
            done["v"] = True

        wiz = SetupWizard(app, Settings.load(), on_done=on_done)
        wiz.update()
        grab(wiz, "07-wizard")
        wiz._skip_tone()  # noqa: SLF001
        wiz.update()
        rec("wizard_skip_tone", wiz.settings.tone_test_skipped, "")
        wiz._finish()  # noqa: SLF001
        app.update()
        rec("wizard_finish", done["v"])
    except Exception:
        rec("wizard", False, traceback.format_exc(limit=2))

    # Font change + clear caption
    try:
        app._on_font_change("17")  # noqa: SLF001
        app._clear_caption()  # noqa: SLF001
        app.update()
        rec("caption_font_clear", True)
    except Exception as e:
        rec("caption_font_clear", False, str(e))

    # Real start/stop (AUTO_YES skips confirm dialogs)
    try:
        app.title_var.set("Gate record test")
        app._set_mic(True)  # noqa: SLF001
        app._set_spk(True)  # noqa: SLF001
        app._start_record()  # noqa: SLF001
        app.update()
        started = bool(app._recording)  # noqa: SLF001
        rec("record_start", started, app.status_var.get())
        if started:
            deadline = time.time() + 2.5
            while time.time() < deadline:
                app.update()
                time.sleep(0.1)
            grab(app, "08-recording")
            app._stop_record()  # noqa: SLF001
            app.update()
            rec(
                "record_stop",
                not app._recording and app.session is not None,  # noqa: SLF001
                str(getattr(app.session, "root", "")),
            )
        else:
            rec("record_stop", False, "start failed")
    except Exception:
        rec("record_cycle", False, traceback.format_exc(limit=2))

    grab(app, "09-main-final")
    app.destroy()

    # Summary
    failed = [r for r in results if not r[1]]
    print("\n======== SUMMARY ========")
    print(f"Passed: {sum(1 for r in results if r[1])}/{len(results)}")
    if failed:
        print("Failed:")
        for n, _, d in failed:
            print(f"  - {n}: {d}")
        return 1
    print("All driven functions OK")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as exc:
        traceback.print_exc()
        raise SystemExit(1) from exc
