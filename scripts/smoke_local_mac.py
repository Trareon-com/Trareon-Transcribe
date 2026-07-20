#!/usr/bin/env python3
"""Live smoke checks on this Mac (no commit — local verification)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def ok(label: str, cond: bool, detail: str = "") -> None:
    mark = "PASS" if cond else "FAIL"
    print(f"[{mark}] {label}" + (f" — {detail}" if detail else ""))
    if not cond:
        raise SystemExit(1)


def main() -> int:
    from config.settings import Settings, sanitize_geometry
    from config.version import __version__
    from engine.audio_probe import probe_audio
    from engine.stt import WhisperCppStt, find_whisper_binary
    from ui.theme import apply_theme, colors_for

    print(f"== Trareon local Mac smoke (v{__version__}) ==")

    audio = probe_audio()
    ok("PortAudio / sounddevice", audio.ok, audio.message)
    ok("Audio devices present", audio.device_count > 0, f"n={audio.device_count}")

    geo = sanitize_geometry("200x100")
    ok("Geometry sanitize rejects tiny", geo == "1000x740", geo)

    apply_theme("dark")
    c = colors_for("dark")
    ok("Dark theme palette", c["bg"].startswith("#") and c["text"].startswith("#"), c["bg"])
    apply_theme("light")

    s = Settings.load()
    lib = s.library_path()
    ok("Library path writable", lib.is_dir(), str(lib))
    probe = lib / ".trareon-smoke"
    probe.write_text("ok", encoding="utf-8")
    probe.unlink()
    ok("Library write/delete", True)

    binary = find_whisper_binary()
    stt = WhisperCppStt(s.model)
    print(f"[INFO] whisper binary: {binary}")
    print(f"[INFO] STT available: {stt.available()} (model={s.model})")
    # Binary optional if brew not installed — warn only
    if not stt.available():
        print("[WARN] STT not fully ready — brew install whisper-cpp + unduh model di Setup")

    # Mic permission probe (short)
    from engine.audio_capture import AudioCapture

    mic_ok, mic_msg = AudioCapture.check_mic_permission()
    ok("Mic permission probe", mic_ok, mic_msg)

    # Theme toggle rebuild path: import MainWindow without mainloop for construction
    import os

    os.environ.setdefault("TRAREON_NO_RELAUNCH", "1")
    from config.branding import ensure_tk_registered

    ensure_tk_registered()
    from ui.main_window import MainWindow

    app = MainWindow(Settings.load())
    app.update_idletasks()
    w, h = app.winfo_width(), app.winfo_height()
    ok("Main window created", w >= 800 or app.winfo_reqwidth() >= 800, f"{w}x{h}")
    before = app.settings.theme
    app._toggle_theme()  # noqa: SLF001
    app.update_idletasks()
    after = app.settings.theme
    ok("Theme toggle flips mode", before != after, f"{before} → {after}")
    app._toggle_theme()  # restore
    app.destroy()

    print("== All local Mac smoke checks passed ==")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
