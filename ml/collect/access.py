"""Recording *why* a source could not be collected.

The two government sources this sprint targets both refuse automated
access, in two different ways, and the useful deliverable is a precise,
dated diagnosis rather than a stack trace — the owner has to take it to
DPR/MK (or PPID) to ask for a proper data route.

So discovery returns a `Probe` instead of raising: "blocked, Cloudflare
interstitial on HTTP 403, checked 2026-10-05" is actionable, and
"RequestException" is not.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, datetime
from enum import StrEnum


class Access(StrEnum):
    OK = "ok"
    #: Anti-bot interstitial. Not worked around by design.
    CHALLENGE = "challenge"
    #: robots.txt forbids the path that holds the data.
    ROBOTS = "robots"
    #: Reachable, but the document index is rendered client-side and the
    #: data endpoint is not public.
    NO_PUBLIC_INDEX = "no_public_index"
    HTTP_ERROR = "http_error"
    NETWORK = "network"


@dataclass
class Probe:
    """What one source did when asked for its document index."""

    source: str
    url: str
    access: Access
    detail: str
    checked_at: str = field(default_factory=lambda: datetime.now(UTC).isoformat(timespec="seconds"))
    #: What the owner has to do to unblock it, in Indonesian.
    remedy: str = ""
    http_status: int | None = None

    @property
    def usable(self) -> bool:
        return self.access is Access.OK

    def as_dict(self) -> dict:
        return {
            "source": self.source,
            "url": self.url,
            "access": self.access.value,
            "detail": self.detail,
            "http_status": self.http_status,
            "remedy": self.remedy,
            "checked_at": self.checked_at,
        }

    def __str__(self) -> str:
        return f"[{self.source}] {self.access.value}: {self.detail}"


#: The standard remedy text, so both collectors say the same thing.
REMEDY_OFFICIAL_REQUEST = (
    "Ajukan permintaan data resmi melalui PPID lembaga (atau kerja sama "
    "via Komdigi) untuk memperoleh risalah + rekaman dalam bentuk yang "
    "boleh diunduh otomatis. Setelah data diterima, muat lewat "
    "`--index` (CSV/JSONL) — separuh unduh/cocok/manifest dari kolektor "
    "ini sudah siap dan teruji."
)
