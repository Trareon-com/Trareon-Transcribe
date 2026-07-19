"""App display name + icon paths.

Important (macOS): never import AppKit/PyObjC before Tk creates the root window.
Doing so makes Tk abort inside RegisterApplication (SIGABRT).
After Tk exists, patch CFBundleName + the Apple menu so the bar is not "Python".

Mic permission dialogs use the .app bundle name only when the running Mach-O
lives inside that bundle — use scripts/run_mac_app.sh (not bare `python main.py`).
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

APP_NAME = "Trareon Transcribe"
APP_ID = "com.trareon.transcribe"

_PYTHON_TITLE_RE = re.compile(r"Python(?:\s+[\d.]+)?", re.IGNORECASE)


def project_root() -> Path:
    if getattr(sys, "frozen", False):
        return Path(getattr(sys, "_MEIPASS", Path(sys.executable).resolve().parent))
    return Path(__file__).resolve().parents[1]


def icon_png() -> Path:
    return project_root() / "assets" / "trareon-transcribe-icon.png"


def icon_icns() -> Path:
    return project_root() / "assets" / "trareon-transcribe-icon.icns"


def running_from_app_bundle() -> bool:
    """True when launched via our .app (or frozen PyInstaller) so TCC uses our name."""
    if getattr(sys, "frozen", False):
        return True
    if os.environ.get("TRAREON_APP_BUNDLE") == "1":
        return True
    exe = Path(sys.executable).resolve()
    return any(p.name.endswith(".app") for p in exe.parents)


def apply_macos_menu_name(name: str = APP_NAME) -> None:
    """Rename menu-bar app title away from Homebrew 'Python' (call after Tk())."""
    if sys.platform != "darwin":
        return
    try:
        from AppKit import NSApp, NSImage
        from Foundation import NSBundle, NSProcessInfo
    except ImportError:
        return

    try:
        info = NSBundle.mainBundle().infoDictionary()
        if info is not None:
            info["CFBundleName"] = name
            info["CFBundleDisplayName"] = name
            info["CFBundleIdentifier"] = APP_ID
        NSProcessInfo.processInfo().setProcessName_(name)
    except Exception:
        pass

    try:
        menu = NSApp.mainMenu()
        if menu is not None and menu.numberOfItems() > 0:
            item = menu.itemAtIndex_(0)
            item.setTitle_(name)
            sub = item.submenu()
            if sub is not None:
                sub.setTitle_(name)
                for i in range(sub.numberOfItems()):
                    it = sub.itemAtIndex_(i)
                    if it is None or it.isSeparatorItem():
                        continue
                    title = str(it.title())
                    if _PYTHON_TITLE_RE.search(title):
                        it.setTitle_(_PYTHON_TITLE_RE.sub(name, title))
    except Exception:
        pass

    png = icon_png()
    if png.exists():
        try:
            image = NSImage.alloc().initWithContentsOfFile_(str(png.resolve()))
            if image is not None:
                NSApp.setApplicationIconImage_(image)
        except Exception:
            pass


def set_window_icon(window) -> None:  # noqa: ANN001
    """Set window + Dock icon after the Tk root exists (safe)."""
    if sys.platform == "darwin":
        apply_macos_menu_name(APP_NAME)
        try:
            window.after(200, lambda: apply_macos_menu_name(APP_NAME))
            window.after(800, lambda: apply_macos_menu_name(APP_NAME))
        except Exception:
            pass

    png = icon_png()
    if not png.exists():
        return
    try:
        from PIL import Image, ImageTk

        img = Image.open(png).convert("RGBA")
        img = img.resize((128, 128), Image.Resampling.LANCZOS)
        photo = ImageTk.PhotoImage(img)
        window.iconphoto(True, photo)
        window._app_icon_ref = photo  # prevent GC  # noqa: SLF001
    except Exception:
        pass
