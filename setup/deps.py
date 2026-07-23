"""Install system deps with explicit user consent (commands shown first)."""

from __future__ import annotations

import logging
import platform
import shutil
import subprocess
import sys
from dataclasses import dataclass

log = logging.getLogger("trareon.deps")


@dataclass
class DepPlan:
    description: str
    commands: list[list[str]]


def detect_spec() -> dict:
    import psutil

    from util.resources import gpu_name

    ram_gb = psutil.virtual_memory().total / (1024**3)
    cpu = platform.processor() or platform.machine()
    is_apple = sys.platform == "darwin" and platform.machine().lower() in ("arm64", "aarch64")
    return {
        "os": platform.system(),
        "machine": platform.machine(),
        "cpu": cpu,
        "ram_gb": ram_gb,
        "gpu": gpu_name(),
        "is_apple_silicon": is_apple,
        "has_brew": shutil.which("brew") is not None,
        "has_ffmpeg": shutil.which("ffmpeg") is not None,
    }


def macos_dep_plan() -> DepPlan:
    cmds: list[list[str]] = []
    if shutil.which("brew"):
        cmds.append(["brew", "install", "--cask", "blackhole-2ch"])
        cmds.append(["brew", "install", "ffmpeg"])
        if not shutil.which("whisper-whisper-cli") and not shutil.which("whisper-cli"):
            cmds.append(["brew", "install", "whisper-cpp"])
    return DepPlan(
        description="Install BlackHole 2ch + ffmpeg + whisper-cpp via Homebrew",
        commands=cmds,
    )


def setup_audio_routing() -> tuple[bool, str]:
    """Safe audio routing check — does NOT change system audio.

    Detects if BlackHole is installed and if Multi-Output routing is active.
    Opens Audio MIDI Setup with instructions if BlackHole is installed but not routed.
    Does NOT modify system output device or spawn background processes.
    """
    if sys.platform != "darwin":
        return True, "Audio routing only needed on macOS."

    # Check if BlackHole is installed
    try:
        from engine.audio_capture import find_loopback_input_device
        if find_loopback_input_device() is None:
            return True, "BlackHole belum terinstall — SPK capture hanya via MIC."
    except Exception:
        pass

    # Check if Multi-Output routing is already active
    try:
        import sounddevice as sd
        for d in sd.query_devices():
            name = str(d.get("name", ""))
            if "ulti-Output" in name or "Aggregate" in name:
                if int(d.get("max_output_channels", 0)) >= 2:
                    return True, "Multi-Output Device sudah aktif ✓"
    except Exception:
        pass

    # BlackHole present but no routing — show instructions
    from pathlib import Path
    tool = Path(__file__).resolve().parent / "create_multi_output"
    if tool.exists():
        try:
            subprocess.run([str(tool)], capture_output=True, timeout=15)
        except Exception:
            pass

    return True, "Panduan routing dibuka — ikuti langkah di Audio MIDI Setup."


def windows_dep_plan() -> DepPlan:
    cmds: list[list[str]] = []
    manual_note = ""
    if shutil.which("choco"):
        cmds.append(["choco", "install", "ffmpeg", "-y"])
        cmds.append(["choco", "install", "vb-cable", "-y"])
    else:
        manual_note = (
            " Chocolatey tidak ditemukan — install ffmpeg dan VB-Audio Cable manual: "
            "https://www.gyan.dev/ffmpeg/builds/ dan https://vb-audio.com/Cable/"
        )
    return DepPlan(
        description="Install ffmpeg + VB-Audio Virtual Cable via Chocolatey." + manual_note,
        commands=cmds,
    )


def loopback_routing_message(*, device_name: str, detected: bool, is_windows: bool, deps_installed: bool) -> str:
    """Post-install routing status text, shared by the setup wizard.

    VB-Cable's driver commonly needs a logoff/reboot before Windows
    enumerates the new audio endpoint — `choco install` reporting success
    doesn't mean the device is usable yet, so a Windows-specific restart
    hint is shown when it's still not detected right after install.
    """
    if detected:
        return f"{device_name} terdeteksi ✓ — routing dapat diatur nanti"
    if is_windows and deps_installed:
        return (
            f"{device_name} terinstall tapi belum terdeteksi Windows — "
            "restart komputer lalu buka app lagi agar SPK capture aktif."
        )
    return f"{device_name} tidak terdeteksi — SPK capture hanya via MIC"


def run_plan(plan: DepPlan) -> tuple[bool, str]:
    if not plan.commands:
        return True, plan.description + " (no auto commands; follow manual steps)"
    logs: list[str] = []
    for cmd in plan.commands:
        logs.append("$ " + " ".join(cmd))
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=600, check=False)
            logs.append(r.stdout or "")
            logs.append(r.stderr or "")
            if r.returncode != 0:
                return False, "\n".join(logs)
        except Exception as e:
            return False, "\n".join(logs + [str(e)])
    return True, "\n".join(logs)
