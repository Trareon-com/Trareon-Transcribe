"""Meeting title detection + filename helpers."""

from __future__ import annotations

import re
import subprocess
import sys


def slugify(title: str, max_len: int = 40) -> str:
    s = title.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    s = re.sub(r"[-\s]+", "-", s).strip("-")
    return (s or "rapat")[:max_len]


def detect_meeting_title() -> str | None:
    """Best-effort Zoom/Meet/Teams window title."""
    if sys.platform == "darwin":
        return _detect_macos()
    if sys.platform == "win32":
        return _detect_windows()
    return None


def _detect_macos() -> str | None:
    script = """
tell application "System Events"
  set procs to {"zoom.us", "Google Chrome", "Microsoft Edge", "Microsoft Teams", "Safari"}
  repeat with p in procs
    try
      if exists process p then
        tell process p
          repeat with w in windows
            set t to name of w as string
            if t contains "Zoom" or t contains "Meet" or t contains "Teams" then
              return t
            end if
          end repeat
        end tell
      end if
    end try
  end repeat
end tell
return ""
"""
    try:
        r = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        title = (r.stdout or "").strip()
        return _clean_title(title) if title else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def _detect_windows() -> str | None:
    try:
        import win32gui  # type: ignore
    except ImportError:
        return None
    found: list[str] = []

    def enum_handler(hwnd: int, _: object) -> None:
        if not win32gui.IsWindowVisible(hwnd):
            return
        t = win32gui.GetWindowText(hwnd)
        if not t:
            return
        low = t.lower()
        if any(k in low for k in ("zoom", "meet", "teams", "webex")):
            found.append(t)

    try:
        win32gui.EnumWindows(enum_handler, None)
    except Exception:
        return None
    return _clean_title(found[0]) if found else None


def _clean_title(title: str) -> str | None:
    t = title.strip()
    for noise in (
        " - Zoom Meeting",
        " – Zoom",
        " | Microsoft Teams",
        " - Google Meet",
        "Meet - ",
    ):
        t = t.replace(noise, "")
    t = t.strip(" -–|")
    return t or None


def meeting_apps_active() -> bool:
    """True if Zoom/Meet/Teams appears to be running (for auto-pause)."""
    title = detect_meeting_title()
    if title:
        return True
    if sys.platform == "darwin":
        try:
            r = subprocess.run(
                ["pgrep", "-if", "zoom.us|Microsoft Teams|Google Chrome"],
                capture_output=True,
                timeout=2,
                check=False,
            )
            return r.returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            return False
    return False
