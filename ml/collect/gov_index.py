"""Matching a risalah to the recording of the same session.

A risalah (official near-verbatim minutes) and the video of the session
it minutes are published by different parts of the same institution, in
different systems, with no shared identifier. Joining them is the whole
problem of collecting Indonesian parliamentary and constitutional-court
speech, and getting it wrong is worse than collecting nothing: a
recording aligned against the *wrong* session's risalah produces
confidently mislabelled training data that no spot-check of the
alignment step would catch, because the alignment step would correctly
report that the two texts do not match and simply drop everything.

So the join is conservative by construction:

* **Mahkamah Konstitusi** joins on perkara number *and* date. The
  perkara number (``90/PUU-XXI/2023``) is a strong key; the date
  disambiguates the several hearings one perkara gets.
* **DPR** has no perkara number, so it joins on komisi *and* date, and
  — because one komisi can hold two rapat in a day — requires an agenda
  similarity check on top.

Anything that does not meet the bar is reported as unmatched rather than
guessed. `match_report` exists so that the pilot can state how many
items failed to join and why, which is the number that tells you whether
a source is usable at all.
"""

from __future__ import annotations

import difflib
import re
import unicodedata
from dataclasses import dataclass, field
from datetime import date

MONTHS_ID = {
    "januari": 1,
    "februari": 2,
    "pebruari": 2,
    "maret": 3,
    "april": 4,
    "mei": 5,
    "juni": 6,
    "juli": 7,
    "agustus": 8,
    "september": 9,
    "oktober": 10,
    "november": 11,
    "nopember": 11,
    "desember": 12,
}

MONTHS_EN = {
    "january": 1,
    "february": 2,
    "march": 3,
    "april": 4,
    "may": 5,
    "june": 6,
    "july": 7,
    "august": 8,
    "september": 9,
    "october": 10,
    "november": 11,
    "december": 12,
}

_MONTHS = {**MONTHS_ID, **MONTHS_EN}

#: ``90/PUU-XXI/2023``, ``1/PHPU.PRES/XXII/2024``, ``006/SKLN-IV/2006``.
#: The register (PUU, PHPU, SKLN, PUU-MK...) may carry dots; the middle
#: group is a Roman numeral for the court year.
_RE_PERKARA = re.compile(
    r"\b(\d{1,3})\s*/\s*([A-Z][A-Z.\-]{1,12}?)\s*[-/]\s*([IVXLC]{1,7})\s*/\s*(\d{4})\b"
)

#: ``2 Oktober 2026``, ``17 Agustus 2024``.
_RE_DATE_ID = re.compile(r"\b(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})\b")
#: ``October 1, 2026``.
_RE_DATE_EN = re.compile(r"\b([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})\b")
#: ``2026-10-02``, ``02/10/2026``.
_RE_DATE_ISO = re.compile(r"\b(\d{4})-(\d{1,2})-(\d{1,2})\b")
_RE_DATE_DMY = re.compile(r"\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b")

#: ``Komisi I``..``Komisi XIII``, plus the named bodies that behave like
#: one for matching purposes.
_RE_KOMISI = re.compile(
    r"\b(?:komisi\s+([IVX]{1,4})\b|(badan\s+legislasi|baleg|banggar|"
    r"badan\s+anggaran|bakn|bksap|mkd|panja|pansus|paripurna))",
    re.IGNORECASE,
)

ROMAN = {
    "I": 1,
    "II": 2,
    "III": 3,
    "IV": 4,
    "V": 5,
    "VI": 6,
    "VII": 7,
    "VIII": 8,
    "IX": 9,
    "X": 10,
    "XI": 11,
    "XII": 12,
    "XIII": 13,
}


@dataclass
class GovItem:
    """One session, as known from one side of the join.

    A risalah-side item has `transcript_url` and no `media_id`; a
    recording-side item is the other way round. `match_sessions` pairs
    them.
    """

    source: str
    title: str
    session_date: date | None = None
    perkara: str | None = None
    komisi: str | None = None
    transcript_url: str | None = None
    media_id: str | None = None
    media_url: str | None = None
    duration: float | None = None
    extra: dict = field(default_factory=dict)

    @property
    def key(self) -> str:
        """A stable id for the manifest."""
        stamp = self.session_date.isoformat() if self.session_date else "tanpa-tanggal"
        subject = self.perkara or self.komisi or _slug(self.title)[:40] or "tanpa-subjek"
        return f"{self.source}:{stamp}:{_slug(subject)}"


@dataclass
class Match:
    risalah: GovItem
    recording: GovItem
    #: Why this pair was accepted, for the audit trail.
    basis: str
    #: 0..1. Agenda/title similarity; 1.0 when a perkara number matched.
    confidence: float


@dataclass
class MatchReport:
    matches: list[Match] = field(default_factory=list)
    unmatched_risalah: list[GovItem] = field(default_factory=list)
    unmatched_recordings: list[GovItem] = field(default_factory=list)
    #: Pairs rejected after a date match, with the reason. The useful
    #: diagnostic: a long list here means the join key is too weak.
    rejected: list[tuple[GovItem, GovItem, str]] = field(default_factory=list)

    def summary(self) -> str:
        return (
            f"{len(self.matches)} cocok, "
            f"{len(self.unmatched_risalah)} risalah tanpa rekaman, "
            f"{len(self.unmatched_recordings)} rekaman tanpa risalah, "
            f"{len(self.rejected)} pasangan ditolak"
        )


def _slug(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = "".join(char for char in text if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", "-", text.casefold()).strip("-")


def parse_perkara(text: str) -> str | None:
    """Extract a normalised perkara number, or None.

    Normalised so that ``90/PUU-XXI/2023`` and ``90 / PUU - XXI / 2023``
    are the same key — whitespace around the separators varies between
    the risalah header and the video title.
    """
    match = _RE_PERKARA.search(text.upper())
    if not match:
        return None
    number, register, roman, year = match.groups()
    register = register.strip(".-")
    return f"{int(number)}/{register}-{roman}/{year}"


def parse_date(text: str) -> date | None:
    """Extract a session date from a title or risalah header.

    Tries Indonesian, English, ISO and d/m/Y forms. Returns None rather
    than guessing: an item with no date cannot be joined, and inventing
    one would pair it with an arbitrary session.
    """
    iso = _RE_DATE_ISO.search(text)
    if iso:
        year, month, day = (int(group) for group in iso.groups())
        return _safe_date(year, month, day)

    for match in _RE_DATE_ID.finditer(text):
        day_text, month_text, year_text = match.groups()
        month = _MONTHS.get(month_text.casefold())
        if month:
            return _safe_date(int(year_text), month, int(day_text))

    for match in _RE_DATE_EN.finditer(text):
        month_text, day_text, year_text = match.groups()
        month = _MONTHS.get(month_text.casefold())
        if month:
            return _safe_date(int(year_text), month, int(day_text))

    dmy = _RE_DATE_DMY.search(text)
    if dmy:
        day, month, year = (int(group) for group in dmy.groups())
        # Indonesian convention is day-first. A value above 12 in the
        # first position confirms it; below, there is nothing to confirm
        # and day-first is the documented assumption.
        return _safe_date(year, month, day)
    return None


def _safe_date(year: int, month: int, day: int) -> date | None:
    try:
        return date(year, month, day)
    except ValueError:
        return None


def parse_komisi(text: str) -> str | None:
    """Extract a normalised komisi / AKD name, or None."""
    match = _RE_KOMISI.search(text)
    if not match:
        return None
    roman, named = match.groups()
    if roman:
        number = ROMAN.get(roman.upper())
        return f"komisi-{number}" if number else None
    collapsed = re.sub(r"\s+", "-", named.casefold())
    aliases = {
        "badan-legislasi": "baleg",
        "badan-anggaran": "banggar",
    }
    return aliases.get(collapsed, collapsed)


#: Words that appear in nearly every session title and therefore carry
#: no information about *which* session it is. Without this list two
#: unrelated rapat score 0.5 on shared boilerplate alone — "Rapat Komisi
#: VIII dengan Menteri Agama tentang haji" against "Rapat Komisi I
#: dengan Panglima TNI tentang alutsista" — which is above any threshold
#: loose enough to accept a genuine pair. Meeting-type abbreviations are
#: in here too, so that "RDP" and "rapat dengar pendapat" neither match
#: on nor are penalised for their surface form.
TITLE_BOILERPLATE = frozenset(
    {
        "rapat",
        "raker",
        "rdp",
        "rdpu",
        "dengar",
        "pendapat",
        "umum",
        "kerja",
        "sidang",
        "persidangan",
        "komisi",
        "dpr",
        "ri",
        "mk",
        "mahkamah",
        "konstitusi",
        "dengan",
        "tentang",
        "soal",
        "mengenai",
        "terkait",
        "dan",
        "atau",
        "di",
        "ke",
        "dari",
        "pada",
        "untuk",
        "yang",
        "dalam",
        "oleh",
        "para",
        "masa",
        "tahun",
        "hari",
        "tanggal",
        "acara",
        "agenda",
        "lanjutan",
        "pembukaan",
        "penutupan",
        "video",
        "berita",
        "news",
        "live",
        "streaming",
        "ulang",
        "siaran",
        "bagian",
        "sesi",
    }
)


def content_words(title: str) -> list[str]:
    """The words in `title` that say which session it is."""
    return [
        word
        for word in re.findall(r"\w+", title.casefold())
        if word not in TITLE_BOILERPLATE and len(word) > 1
    ]


def agenda_similarity(left: str, right: str) -> float:
    """0..1 similarity of two session titles.

    Jaccard overlap of *content* words, not a sequence ratio over all
    words. Two reasons:

    * Boilerplate has to go first (see `TITLE_BOILERPLATE`), or the
      measure reports shared ceremony rather than shared subject.
    * Order is not comparable. A risalah title and a video title for the
      same rapat name the same participants and topic in different
      orders, so a sequence measure penalises a correct pair for word
      order it has no reason to share.

    Falls back to a sequence ratio over all words when one side has no
    content words at all, which is better than returning 0.0 for a pair
    of titles that are literally identical boilerplate.
    """
    left_content = set(content_words(left))
    right_content = set(content_words(right))
    if not left_content or not right_content:
        left_words = re.findall(r"\w+", left.casefold())
        right_words = re.findall(r"\w+", right.casefold())
        if not left_words or not right_words:
            return 0.0
        return difflib.SequenceMatcher(None, left_words, right_words).ratio()
    overlap = left_content & right_content
    union = left_content | right_content
    return len(overlap) / len(union)


def match_sessions(
    risalah: list[GovItem],
    recordings: list[GovItem],
    *,
    date_tolerance_days: int = 1,
    min_agenda_similarity: float = 0.35,
) -> MatchReport:
    """Join risalah to recordings. Conservative; reports what it refused.

    `date_tolerance_days` allows one day of slack because a hearing that
    runs past midnight is minuted under the starting date but uploaded
    under the next. Widening it further would start pairing different
    sessions of the same komisi.
    """
    report = MatchReport()
    available = list(recordings)
    used: set[int] = set()

    for item in risalah:
        best: tuple[float, int, str] | None = None
        for index, candidate in enumerate(available):
            if index in used:
                continue
            verdict = _score_pair(
                item,
                candidate,
                date_tolerance_days=date_tolerance_days,
                min_agenda_similarity=min_agenda_similarity,
            )
            if verdict.reason:
                # Only worth reporting as "rejected" when the date lined
                # up; every other pair in the cross product is noise.
                if verdict.same_date:
                    report.rejected.append((item, candidate, verdict.reason))
                continue
            if best is None or verdict.confidence > best[0]:
                best = (verdict.confidence, index, verdict.basis)

        if best is None:
            report.unmatched_risalah.append(item)
            continue
        confidence, index, basis = best
        used.add(index)
        report.matches.append(
            Match(risalah=item, recording=available[index], basis=basis, confidence=confidence)
        )

    report.unmatched_recordings = [
        candidate for index, candidate in enumerate(available) if index not in used
    ]
    return report


@dataclass
class _Verdict:
    confidence: float = 0.0
    basis: str = ""
    reason: str = ""
    same_date: bool = False


def _score_pair(
    risalah: GovItem,
    recording: GovItem,
    *,
    date_tolerance_days: int,
    min_agenda_similarity: float,
) -> _Verdict:
    if risalah.source != recording.source:
        return _Verdict(reason="sumber berbeda")

    # Perkara number is a strong key and beats everything else. A
    # perkara match with a wildly different date is still a match: MK
    # publishes a hearing's video days after the session.
    both_perkara = risalah.perkara and recording.perkara
    if both_perkara and risalah.perkara == recording.perkara:
        return _Verdict(confidence=1.0, basis="perkara", same_date=True)
    if both_perkara:
        return _Verdict(
            reason="nomor perkara berbeda", same_date=_dates_close(risalah, recording, 0)
        )

    if risalah.session_date is None or recording.session_date is None:
        return _Verdict(reason="tanggal tidak diketahui")
    if not _dates_close(risalah, recording, date_tolerance_days):
        return _Verdict(reason="tanggal terlalu jauh")

    # Date lines up. From here on a rejection is informative.
    if risalah.komisi and recording.komisi and risalah.komisi != recording.komisi:
        return _Verdict(reason="komisi berbeda", same_date=True)

    similarity = agenda_similarity(risalah.title, recording.title)
    if similarity < min_agenda_similarity:
        return _Verdict(
            reason=f"agenda terlalu berbeda ({similarity:.2f} < {min_agenda_similarity:.2f})",
            same_date=True,
        )
    basis = "komisi+tanggal+agenda" if risalah.komisi else "tanggal+agenda"
    return _Verdict(confidence=similarity, basis=basis, same_date=True)


def _dates_close(left: GovItem, right: GovItem, tolerance: int) -> bool:
    if left.session_date is None or right.session_date is None:
        return False
    return abs((left.session_date - right.session_date).days) <= tolerance


def match_report_rows(report: MatchReport) -> list[dict]:
    """Flatten a report for a JSON audit file."""
    rows: list[dict] = []
    for match in report.matches:
        rows.append(
            {
                "status": "matched",
                "id": match.risalah.key,
                "basis": match.basis,
                "confidence": round(match.confidence, 4),
                "risalah_url": match.risalah.transcript_url,
                "media_id": match.recording.media_id,
                "risalah_title": match.risalah.title,
                "recording_title": match.recording.title,
            }
        )
    for item in report.unmatched_risalah:
        rows.append({"status": "risalah_tanpa_rekaman", "id": item.key, "title": item.title})
    for item in report.unmatched_recordings:
        rows.append({"status": "rekaman_tanpa_risalah", "id": item.key, "title": item.title})
    for left, right, reason in report.rejected:
        rows.append(
            {
                "status": "ditolak",
                "id": left.key,
                "candidate": right.key,
                "reason": reason,
            }
        )
    return rows
