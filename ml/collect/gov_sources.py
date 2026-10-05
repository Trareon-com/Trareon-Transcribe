"""The MK and DPR risalah collectors.

Each source has three entry points:

* `probe()` — ask the site for its document index and report precisely
  what happened. Run this first; both sources currently refuse
  automated access and the diagnosis is what the owner takes to the
  institution.
* `discover()` — parse the index into `GovItem`s when `probe()` says the
  site is usable.
* `load_index()` — read the same `GovItem`s from a local CSV/JSONL.
  This is the path that works today: once a risalah set arrives through
  an official data request, the download/join/manifest half of the
  pipeline runs unchanged.

`load_index` is not a fallback bolted on after the blocks were found. A
scraper is the *least* durable way to obtain these documents — the DPR
portal was rebuilt in Next.js between this project's research round and
this sprint — and an index file is also how a one-off export, a
colleague's spreadsheet or a PPID response arrives.
"""

from __future__ import annotations

import csv
import json
import re
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from urllib.parse import urljoin

import requests

from collect.access import REMEDY_OFFICIAL_REQUEST, Access, Probe
from collect.gov_index import GovItem, parse_date, parse_komisi, parse_perkara
from common.fetch import ChallengeDetected, HttpError, PoliteSession, RobotsDisallowed


@dataclass(frozen=True)
class GovSource:
    """Where one institution publishes its risalah."""

    name: str
    index_url: str
    #: Where the Next.js front end gets its list. Probed only to report
    #: *that* it is robots-disallowed, never fetched.
    data_path_hint: str
    licence_note: str


MK = GovSource(
    name="mk",
    index_url="https://www.mkri.id/index.php?page=web.RisalahSidang&menu=16",
    data_path_hint="https://www.mkri.id/api/",
    licence_note=(
        "Teks risalah: tanpa hak cipta (UU 28/2014 Pasal 42 huruf a/d). "
        "Rekaman siaran kanal resmi: hak terkait lembaga penyiaran - perlu izin."
    ),
)

DPR = GovSource(
    name="dpr",
    index_url="https://www.dpr.go.id/dokumen/persidangan-paripurna/risalah-rapat",
    data_path_hint="https://www.dpr.go.id/api/",
    licence_note=(
        "Teks risalah rapat terbuka: tanpa hak cipta (UU 28/2014 Pasal 42 huruf a). "
        "Rekaman TV Parlemen: hak terkait lembaga penyiaran - perlu izin."
    ),
)

SOURCES = {source.name: source for source in (MK, DPR)}

_RE_PDF_LINK = re.compile(r'href="([^"]+\.pdf(?:\?[^"]*)?)"', re.IGNORECASE)


def probe(source: GovSource, session: PoliteSession | None = None) -> Probe:
    """Ask `source` for its risalah index and report what happened."""
    session = session or PoliteSession()
    try:
        response = session.get(source.index_url)
    except ChallengeDetected as error:
        return Probe(
            source=source.name,
            url=source.index_url,
            access=Access.CHALLENGE,
            detail=str(error),
            remedy=REMEDY_OFFICIAL_REQUEST,
        )
    except RobotsDisallowed as error:
        return Probe(
            source=source.name,
            url=source.index_url,
            access=Access.ROBOTS,
            detail=str(error),
            remedy=REMEDY_OFFICIAL_REQUEST,
        )
    except HttpError as error:
        return Probe(
            source=source.name,
            url=source.index_url,
            access=Access.HTTP_ERROR,
            detail=str(error),
            http_status=error.status,
            remedy=REMEDY_OFFICIAL_REQUEST,
        )
    except requests.RequestException as error:
        return Probe(
            source=source.name,
            url=source.index_url,
            access=Access.NETWORK,
            detail=f"{type(error).__name__}: {error}",
            remedy="Periksa koneksi jaringan.",
        )

    links = _RE_PDF_LINK.findall(response.text)
    if links:
        return Probe(
            source=source.name,
            url=source.index_url,
            access=Access.OK,
            detail=f"{len(links)} tautan PDF ditemukan di indeks",
            http_status=response.status_code,
        )

    # The page loads but holds no documents: the list is rendered
    # client-side. Say whether the endpoint it would use is one robots
    # .txt puts out of bounds, because that decides whether this is
    # "needs a browser" or "we are not allowed".
    robots_blocked = not session.allowed(source.data_path_hint)
    detail = (
        f"HTTP {response.status_code}, {len(response.text)} bait, tetapi tidak ada tautan "
        "PDF: daftar dirender di sisi klien."
    )
    if robots_blocked:
        detail += f" Endpoint data ({source.data_path_hint}) dilarang oleh robots.txt."
    return Probe(
        source=source.name,
        url=source.index_url,
        access=Access.ROBOTS if robots_blocked else Access.NO_PUBLIC_INDEX,
        detail=detail,
        http_status=response.status_code,
        remedy=REMEDY_OFFICIAL_REQUEST,
    )


def discover(
    source: GovSource,
    *,
    limit: int = 10,
    session: PoliteSession | None = None,
) -> tuple[list[GovItem], Probe]:
    """Parse `source`'s published index into items.

    Returns the items *and* the probe, so a caller that gets an empty
    list always has the reason to hand.
    """
    session = session or PoliteSession()
    result = probe(source, session)
    if not result.usable:
        return [], result

    response = session.get(source.index_url)
    items: list[GovItem] = []
    for href in _RE_PDF_LINK.findall(response.text)[:limit]:
        url = urljoin(source.index_url, href)
        title = _title_from_url(url)
        items.append(
            GovItem(
                source=source.name,
                title=title,
                session_date=parse_date(title),
                perkara=parse_perkara(title),
                komisi=parse_komisi(title),
                transcript_url=url,
            )
        )
    return items, result


def _title_from_url(url: str) -> str:
    """A human-readable title from a PDF filename.

    Risalah filenames carry the perkara number and date, which is
    exactly what the matcher keys on.
    """
    name = Path(url.split("?", 1)[0]).stem
    return re.sub(r"[_\-]+", " ", name).strip()


def load_index(path: str | Path, source: str) -> list[GovItem]:
    """Read risalah items from a local CSV or JSONL index.

    Required column: `transcript_url` or `transcript_path`. Recognised
    optional columns: `title`, `date`, `perkara`, `komisi`. Anything
    missing is derived from `title` where possible, so a two-column
    export is enough to get started.
    """
    target = Path(path)
    rows: Iterable[dict]
    text = target.read_text(encoding="utf-8")
    if target.suffix.casefold() == ".jsonl":
        rows = [json.loads(line) for line in text.splitlines() if line.strip()]
    else:
        rows = list(csv.DictReader(text.splitlines()))

    items: list[GovItem] = []
    for index, row in enumerate(rows, start=1):
        row = {(key or "").strip(): (value or "").strip() for key, value in row.items()}
        url = row.get("transcript_url") or row.get("transcript_path") or ""
        if not url:
            raise ValueError(
                f"{target}: baris {index} tidak punya kolom transcript_url/transcript_path"
            )
        title = row.get("title") or _title_from_url(url)
        items.append(
            GovItem(
                source=source,
                title=title,
                session_date=_parse_index_date(row.get("date")) or parse_date(title),
                perkara=row.get("perkara") or parse_perkara(title),
                komisi=_normalise_komisi(row.get("komisi")) or parse_komisi(title),
                transcript_url=url if url.startswith("http") else None,
                extra={"transcript_path": None if url.startswith("http") else url},
            )
        )
    return items


def _parse_index_date(raw: str | None) -> date | None:
    return parse_date(raw) if raw else None


def _normalise_komisi(raw: str | None) -> str | None:
    if not raw:
        return None
    # Accept either the normalised form ("komisi-8") or the printed one
    # ("Komisi VIII"); an index written by hand will have both.
    if re.fullmatch(r"komisi-\d{1,2}", raw.casefold()):
        return raw.casefold()
    return parse_komisi(raw) or raw.casefold()
