# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec — macOS .app (onedir) + Windows onefile .exe."""

from __future__ import annotations

import sys
from pathlib import Path

from PyInstaller.utils.hooks import collect_all

datas: list = []
binaries: list = []
hiddenimports = [
    "customtkinter",
    "sounddevice",
    "pystray",
    "PIL",
    "PIL._tkinter_finder",
    "config.version",
]

tmp_ret = collect_all("customtkinter")
datas += tmp_ret[0]
binaries += tmp_ret[1]
hiddenimports += tmp_ret[2]

if sys.platform == "darwin":
    hiddenimports += ["AppKit", "Foundation", "objc"]

root = Path(SPECPATH).resolve().parent
icon_png = root / "assets" / "trareon-transcribe-icon.png"
icon_icns = root / "assets" / "trareon-transcribe-icon.icns"
if icon_png.exists():
    datas += [(str(icon_png), "assets")]
if icon_icns.exists():
    datas += [(str(icon_icns), "assets")]

icon = str(icon_icns if icon_icns.exists() else icon_png) if (icon_icns.exists() or icon_png.exists()) else None

a = Analysis(
    [str(root / "main.py")],
    pathex=[str(root)],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)
pyz = PYZ(a.pure)

if sys.platform == "darwin":
    exe = EXE(
        pyz,
        a.scripts,
        [],
        exclude_binaries=True,
        name="Trareon Transcribe",
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
        upx=False,
        console=False,
        disable_windowed_traceback=False,
        icon=icon,
    )
    coll = COLLECT(
        exe,
        a.binaries,
        a.datas,
        strip=False,
        upx=False,
        name="Trareon Transcribe",
    )
    app = BUNDLE(
        coll,
        name="Trareon Transcribe.app",
        icon=str(icon_icns) if icon_icns.exists() else None,
        bundle_identifier="com.trareon.transcribe",
        info_plist={
            "CFBundleName": "Trareon Transcribe",
            "CFBundleDisplayName": "Trareon Transcribe",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "0.1.0",
            "LSMinimumSystemVersion": "12.0",
            "NSHighResolutionCapable": True,
            "NSMicrophoneUsageDescription": (
                "Trareon Transcribe needs the microphone to record meeting audio "
                "for offline transcription."
            ),
            "NSPrincipalClass": "NSApplication",
        },
    )
else:
    exe = EXE(
        pyz,
        a.scripts,
        a.binaries,
        a.datas,
        [],
        name="TrareonTranscribe",
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
        upx=True,
        console=False,
        disable_windowed_traceback=False,
        icon=icon,
    )
