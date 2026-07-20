"""Display timestamps in the user's local timezone."""

from __future__ import annotations

from datetime import UTC, datetime


def format_local(iso: str | None, fmt: str = "%Y-%m-%d %H:%M") -> str:
    """Parse ISO timestamp (UTC or offset) → local wall clock for UI."""
    if not iso:
        return "?"
    try:
        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except ValueError:
        return iso[:19].replace("T", " ")
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone().strftime(fmt)


def now_local_iso() -> str:
    return datetime.now().astimezone().isoformat()
