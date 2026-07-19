"""Check GitHub Releases for a newer version (notify + open download)."""

from __future__ import annotations

import json
import logging
import platform
import sys
import urllib.request
import webbrowser
from dataclasses import dataclass

from config.version import __version__

log = logging.getLogger("trareon.update")

REPO = "Trareon-com/Trareon-Transcribe"
API = f"https://api.github.com/repos/{REPO}/releases/latest"


@dataclass
class UpdateInfo:
    current: str
    latest: str
    update_available: bool
    release_url: str
    asset_url: str = ""
    asset_name: str = ""


def _parse_ver(tag: str) -> tuple[int, ...]:
    s = tag.lstrip("vV").strip()
    parts: list[int] = []
    for p in s.split("."):
        num = ""
        for ch in p:
            if ch.isdigit():
                num += ch
            else:
                break
        parts.append(int(num) if num else 0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])


def is_newer(latest: str, current: str) -> bool:
    return _parse_ver(latest) > _parse_ver(current)


def _prefer_asset(assets: list[dict], os_key: str) -> tuple[str, str]:
    """Return (url, name) for best matching release asset."""
    names = [(a.get("name") or "", a.get("browser_download_url") or "") for a in assets]
    prefer: list[str] = []
    if os_key == "windows":
        prefer = ["Setup.exe", "portable.zip", "windows", ".zip"]
    elif os_key == "macos-arm64":
        prefer = ["macos-arm64.dmg", "macos-arm64.zip", "arm64.dmg", "arm64.zip"]
    elif os_key == "macos-x64":
        prefer = ["macos-x64.dmg", "macos-x64.zip", "x64.dmg", "x64.zip"]
    else:
        prefer = [".zip", ".dmg"]

    for needle in prefer:
        for name, url in names:
            if needle.lower() in name.lower() and url:
                return url, name
    for name, url in names:
        if url and not name.endswith(".json"):
            return url, name
    return "", ""


def platform_key() -> str:
    if sys.platform == "win32":
        return "windows"
    if sys.platform == "darwin":
        machine = platform.machine().lower()
        if "arm" in machine or machine == "aarch64":
            return "macos-arm64"
        return "macos-x64"
    return "other"


def check_for_update(timeout: float = 8.0) -> UpdateInfo | None:
    try:
        req = urllib.request.Request(
            API,
            headers={"Accept": "application/vnd.github+json", "User-Agent": "Trareon-Transcribe"},
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        log.info("update check failed: %s", e)
        return None

    tag = str(data.get("tag_name") or "")
    html = str(data.get("html_url") or f"https://github.com/{REPO}/releases")
    assets = list(data.get("assets") or [])
    url, name = _prefer_asset(assets, platform_key())
    latest = tag.lstrip("vV") or tag
    current = __version__
    return UpdateInfo(
        current=current,
        latest=latest,
        update_available=is_newer(tag, current),
        release_url=html,
        asset_url=url,
        asset_name=name,
    )


def open_download(info: UpdateInfo) -> None:
    webbrowser.open(info.asset_url or info.release_url)
