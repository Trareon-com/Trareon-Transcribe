# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_all

from pathlib import Path

datas = []
binaries = []
hiddenimports = ["customtkinter", "sounddevice", "pystray", "PIL"]

tmp_ret = collect_all("customtkinter")
datas += tmp_ret[0]
binaries += tmp_ret[1]
hiddenimports += tmp_ret[2]

root = Path(SPECPATH).resolve().parent
icon_png = root / "assets" / "trareon-transcribe-icon.png"
icon_icns = root / "assets" / "trareon-transcribe-icon.icns"
if icon_png.exists():
    datas += [(str(icon_png), "assets")]
if icon_icns.exists():
    datas += [(str(icon_icns), "assets")]

a = Analysis(
    ["../main.py"],
    pathex=[".."],
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

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="Trareon Transcribe",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    icon=str(icon_icns if icon_icns.exists() else icon_png) if (icon_icns.exists() or icon_png.exists()) else None,
)

# macOS .app: Dock + TCC mic dialog use CFBundleDisplayName (not "Python")
app = BUNDLE(
    exe,
    name="Trareon Transcribe.app",
    icon=str(icon_icns) if icon_icns.exists() else None,
    bundle_identifier="com.trareon.transcribe",
    info_plist={
        "CFBundleName": "Trareon Transcribe",
        "CFBundleDisplayName": "Trareon Transcribe",
        "NSHighResolutionCapable": True,
        "NSMicrophoneUsageDescription": (
            "Trareon Transcribe needs the microphone to record meeting audio "
            "for offline transcription."
        ),
        "NSPrincipalClass": "NSApplication",
    },
)
