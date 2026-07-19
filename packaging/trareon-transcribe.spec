# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec — macOS .app (onedir) + Windows onedir (PortAudio-safe)."""

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

for pkg in ("customtkinter", "sounddevice"):
    tmp_ret = collect_all(pkg)
    datas += tmp_ret[0]
    binaries += tmp_ret[1]
    hiddenimports += tmp_ret[2]

if sys.platform == "darwin":
    hiddenimports += ["AppKit", "Foundation", "objc"]

root = Path(SPECPATH).resolve().parent
icon_png = root / "assets" / "trareon-transcribe-icon.png"
icon_icns = root / "assets" / "trareon-transcribe-icon.icns"
icon_ico = root / "assets" / "trareon-transcribe-icon.ico"
for p, dest in ((icon_png, "assets"), (icon_icns, "assets"), (icon_ico, "assets")):
    if p.exists():
        datas += [(str(p), dest)]

if sys.platform == "win32" and icon_ico.exists():
    icon = str(icon_ico)
elif icon_icns.exists():
    icon = str(icon_icns)
elif icon_png.exists():
    icon = str(icon_png)
else:
    icon = None

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
            "CFBundleShortVersionString": "0.1.2",
            "CFBundleVersion": "0.1.2",
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
    # onedir — PortAudio DLLs break under onefile (_MEI) + UPX on Windows.
    exe = EXE(
        pyz,
        a.scripts,
        [],
        exclude_binaries=True,
        name="TrareonTranscribe",
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
        name="TrareonTranscribe",
    )
