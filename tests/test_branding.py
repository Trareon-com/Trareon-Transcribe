"""macOS branding: transparent icon + menu rename after Tk."""

from __future__ import annotations

import sys

import pytest
from PIL import Image

from config.branding import (
    APP_NAME,
    apply_macos_menu_name,
    icon_png,
    running_from_app_bundle,
)


def test_icon_has_transparent_corners() -> None:
    png = icon_png()
    assert png.exists()
    img = Image.open(png)
    assert img.mode == "RGBA"
    assert img.getpixel((0, 0))[3] == 0
    assert img.getpixel((img.width - 1, 0))[3] == 0


def test_app_bundle_env_flag(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("TRAREON_APP_BUNDLE", raising=False)
    monkeypatch.setattr(sys, "frozen", False, raising=False)
    assert running_from_app_bundle() is False
    monkeypatch.setenv("TRAREON_APP_BUNDLE", "1")
    assert running_from_app_bundle() is True


@pytest.mark.skipif(sys.platform != "darwin", reason="macOS only")
def test_macos_menu_rename_after_tk() -> None:
    import tkinter as tk

    root = tk.Tk()
    root.withdraw()
    root.update_idletasks()
    apply_macos_menu_name(APP_NAME)
    root.update_idletasks()

    from AppKit import NSApp
    from Foundation import NSBundle

    assert NSBundle.mainBundle().infoDictionary().get("CFBundleName") == APP_NAME
    menu = NSApp.mainMenu()
    assert menu is not None
    assert str(menu.itemAtIndex_(0).title()) == APP_NAME
    root.destroy()
