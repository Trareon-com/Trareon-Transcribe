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
        if not shutil.which("whisper-cli"):
            cmds.append(["brew", "install", "whisper-cpp"])
    return DepPlan(
        description="Install BlackHole 2ch + ffmpeg + whisper-cpp via Homebrew",
        commands=cmds,
    )


def windows_dep_plan() -> DepPlan:
    cmds: list[list[str]] = []
    # Chocolatey optional
    if shutil.which("choco"):
        cmds.append(["choco", "install", "ffmpeg", "-y"])
    return DepPlan(
        description="Install ffmpeg (Chocolatey if available). VB-Audio Virtual Cable: install manually from https://vb-audio.com/Cable/",
        commands=cmds,
    )


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
