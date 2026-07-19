"""Lightweight CPU / RAM / GPU sampling for the main-window HUD."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys

import psutil

_GPU_UTIL_RE = re.compile(r'"Device Utilization %"\s*=\s*(\d+)')
_GPU_MODEL_RE = re.compile(r'"model"\s*=\s*"([^"]+)"')


def gpu_name() -> str:
    """Best-effort GPU / chip name for wizard Spec line."""
    if sys.platform == "darwin":
        try:
            out = subprocess.check_output(
                ["ioreg", "-r", "-d", "1", "-w", "0", "-c", "IOAccelerator"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=2,
            )
            m = _GPU_MODEL_RE.search(out)
            if m:
                return m.group(1)
        except Exception:
            pass
        try:
            out = subprocess.check_output(
                ["system_profiler", "SPDisplaysDataType", "-detailLevel", "mini"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=4,
            )
            for line in out.splitlines():
                if "Chipset Model:" in line:
                    return line.split(":", 1)[1].strip() or "GPU"
        except Exception:
            pass
        return "GPU"
    _util, name = _gpu_util_nvidia()
    if name and name != "GPU":
        return name
    return "GPU"


def _gpu_util_mac() -> int | None:
    try:
        out = subprocess.check_output(
            ["ioreg", "-r", "-d", "1", "-w", "0", "-c", "IOAccelerator"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2,
        )
    except Exception:
        return None
    m = _GPU_UTIL_RE.search(out)
    if not m:
        return None
    return int(m.group(1))


def _gpu_util_nvidia() -> tuple[int | None, str]:
    if not shutil.which("nvidia-smi"):
        return None, "GPU"
    try:
        out = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=utilization.gpu,name",
                "--format=csv,noheader,nounits",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2,
        ).strip()
    except Exception:
        return None, "GPU"
    if not out:
        return None, "GPU"
    # first GPU only
    line = out.splitlines()[0]
    parts = [p.strip() for p in line.split(",")]
    util = int(parts[0]) if parts and parts[0].isdigit() else None
    name = parts[1] if len(parts) > 1 else "GPU"
    # shorten long NVIDIA names
    if len(name) > 22:
        name = name[:20] + "…"
    return util, name


def sample_resources() -> str:
    """Return a short HUD string, e.g. 'CPU 12%  RAM 7.7G  GPU 3%'."""
    cpu = psutil.cpu_percent(interval=None)
    ram = psutil.virtual_memory().used / (1024**3)
    gpu_part = _gpu_part()
    return f"CPU {cpu:.0f}%  ·  RAM {ram:.1f}G  ·  {gpu_part}"


def _gpu_part() -> str:
    if sys.platform == "darwin":
        util = _gpu_util_mac()
        if util is None:
            return "GPU —"
        return f"GPU {util}%"
    util, name = _gpu_util_nvidia()
    if util is not None:
        return f"GPU {util}%"
    # Windows/Linux without NVIDIA: hide noisy name, show dash
    if sys.platform == "win32":
        return "GPU —"
    return "GPU —" if not name else "GPU —"
