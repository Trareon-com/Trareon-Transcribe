"""Parsing a risalah into speaker turns.

A risalah is a near-verbatim record, but it is a *document*: it opens
with a cover page, a bench list and an attendance list, it repeats a
header and a page number on every page, and the speech itself is broken
into attributed turns. Feeding the raw PDF text to an aligner would
align the hypothesis against the cover page.

The two institutions format turns differently, and both are handled:

* **Mahkamah Konstitusi** numbers every turn and names the role in
  capitals — ``14. KETUA: ANWAR USMAN`` — followed by the speech.
* **DPR** does not number them and puts the faction in the label —
  ``F-PKB (H. MARWAN DASOPANG):`` or ``KETUA RAPAT:``.

Text extraction is kept separate from parsing so that the parsing — the
part with the judgement calls in it — is testable on text fixtures
without a PDF toolchain in the loop.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

#: ``14. KETUA: ANWAR USMAN`` — MK. The role may carry a faction or
#: party in brackets, and the name may be absent.
_RE_TURN_NUMBERED = re.compile(
    r"^\s*(\d{1,4})[.)]\s+([A-Z][A-Z0-9 ./()\-]{2,70}?)\s*:\s*(.*)$",
)

#: ``KETUA RAPAT:`` / ``F-PKB (H. MARWAN DASOPANG):`` — DPR.
_RE_TURN_LABELLED = re.compile(
    r"^\s*([A-Z][A-Z0-9 ./()\-]{2,70}?)\s*:\s*(.*)$",
)

#: Lines that are document furniture, not speech.
_RE_PAGE_NUMBER = re.compile(r"^\s*\d{1,4}\s*$")
_RE_PAGE_MARKER = re.compile(r"^\s*(?:hal(?:aman)?\.?\s*\d+|-\s*\d+\s*-)\s*$", re.IGNORECASE)

#: Stage directions and the sitting's opening/closing formulae. Kept out
#: of the label text because an ASR will never produce them, so leaving
#: them in would charge the model for text that was never spoken.
_RE_STAGE = re.compile(
    r"\((?:ketuk|mengetuk|tertawa|hening|rekaman|suara|tidak\s+jelas|"
    r"terdengar|diam|riuh)[^)]{0,60}\)",
    re.IGNORECASE,
)
_RE_GAVEL = re.compile(r"^\s*(?:KETUK\s+PALU|PALU\s+DIKETUK)[^\n]{0,40}$", re.IGNORECASE)
_RE_SITTING = re.compile(
    r"^\s*SIDANG\s+(?:DIBUKA|DITUTUP|DISKORS|DIMULAI)[^\n]{0,60}$|"
    r"^\s*RAPAT\s+(?:DIBUKA|DITUTUP|DISKORS|DIMULAI)[^\n]{0,60}$",
    re.IGNORECASE,
)

#: Where the front matter ends. The first of these that appears marks the
#: start of actual speech; before it lies the cover page, the bench list
#: and the attendance list, none of which was spoken aloud.
_FRONT_MATTER_END = (
    re.compile(r"SIDANG\s+DIBUKA\s+PUKUL", re.IGNORECASE),
    re.compile(r"RAPAT\s+DIBUKA\s+PUKUL", re.IGNORECASE),
    re.compile(r"^\s*1[.)]\s+[A-Z]", re.MULTILINE),
    re.compile(r"^\s*KETUA\s+RAPAT\s*:", re.IGNORECASE | re.MULTILINE),
)

#: Role labels that are not a person — used to decide whether the label
#: names a speaker whose identity should be recorded.
GENERIC_ROLES = frozenset(
    {
        "ketua",
        "ketua rapat",
        "ketua sidang",
        "wakil ketua",
        "anggota",
        "pemohon",
        "kuasa hukum pemohon",
        "termohon",
        "pihak terkait",
        "pemerintah",
        "dpr",
        "saksi",
        "ahli",
        "interupsi",
        "sekretariat",
        "pimpinan",
    }
)


@dataclass
class Turn:
    """One attributed stretch of speech."""

    #: The label exactly as printed, e.g. ``F-PKB (H. MARWAN DASOPANG)``.
    label: str
    #: The role part, lowercased: ``ketua``, ``f-pkb``, ``pemohon``.
    role: str
    #: The person's name when the label carries one, else None. Only
    #: ever used as a diarization label *inside* the dataset, never as a
    #: voice profile — see ml/DATA_CARD.md on UU PDP.
    speaker: str | None
    text: str
    #: Turn number as printed (MK numbers them), else None.
    index: int | None = None

    @property
    def words(self) -> int:
        return len(self.text.split())


@dataclass
class Risalah:
    turns: list[Turn] = field(default_factory=list)
    #: Everything before the first turn, kept for provenance rather than
    #: for alignment.
    front_matter: str = ""
    source: str = ""

    @property
    def text(self) -> str:
        """Speech only, turns joined — what the aligner matches against."""
        return "\n".join(turn.text for turn in self.turns if turn.text)

    @property
    def words(self) -> int:
        return sum(turn.words for turn in self.turns)

    @property
    def speakers(self) -> list[str]:
        seen: dict[str, None] = {}
        for turn in self.turns:
            if turn.speaker:
                seen.setdefault(turn.speaker, None)
        return list(seen)


def _split_label(label: str) -> tuple[str, str | None]:
    """Split ``F-PKB (H. MARWAN DASOPANG)`` into role and name.

    MK writes ``KETUA: ANWAR USMAN`` — the name follows the colon rather
    than sitting in brackets — so that case is handled by the caller,
    which has the text after the colon available.
    """
    label = re.sub(r"\s+", " ", label).strip()
    bracketed = re.match(r"^(.*?)\s*\(([^)]+)\)\s*$", label)
    if bracketed:
        role, name = bracketed.groups()
        return role.strip().casefold(), name.strip()
    return label.casefold(), None


def _clean_speech(text: str) -> str:
    """Remove document furniture from a turn's text."""
    text = _RE_STAGE.sub(" ", text)
    lines = []
    for line in text.splitlines():
        if _RE_PAGE_NUMBER.match(line) or _RE_PAGE_MARKER.match(line):
            continue
        if _RE_GAVEL.match(line) or _RE_SITTING.match(line):
            continue
        lines.append(line.strip())
    return re.sub(r"\s+", " ", " ".join(lines)).strip()


def strip_repeated_headers(pages: list[str]) -> list[str]:
    """Drop the lines a PDF repeats on every page.

    A risalah repeats its perkara number and a page number in the
    margin. Any line appearing on more than half the pages is furniture;
    on a two-page document nothing is dropped, which is the safe failure.
    """
    if len(pages) < 3:
        return pages
    counts: dict[str, int] = {}
    for page in pages:
        for line in {line.strip() for line in page.splitlines() if line.strip()}:
            counts[line] = counts.get(line, 0) + 1
    threshold = len(pages) / 2
    furniture = {line for line, count in counts.items() if count > threshold}
    return [
        "\n".join(line for line in page.splitlines() if line.strip() not in furniture)
        for page in pages
    ]


def find_front_matter_end(text: str) -> int:
    """Index where speech starts, or 0 when no marker is found.

    Returning 0 rather than guessing means a document in an unexpected
    layout keeps all its text; the aligner will then discard the cover
    page for lack of matching audio, which loses a little data instead of
    mislabelling it.
    """
    positions = [match.start() for pattern in _FRONT_MATTER_END if (match := pattern.search(text))]
    return min(positions) if positions else 0


def parse_risalah(text: str, *, source: str = "") -> Risalah:
    """Parse extracted risalah text into speaker turns."""
    start = find_front_matter_end(text)
    front_matter = text[:start]
    body = text[start:]

    turns: list[Turn] = []
    pending: Turn | None = None
    buffer: list[str] = []

    def flush() -> None:
        nonlocal pending, buffer
        if pending is not None:
            pending.text = _clean_speech("\n".join(buffer))
            turns.append(pending)
        pending, buffer = None, []

    for line in body.splitlines():
        numbered = _RE_TURN_NUMBERED.match(line)
        labelled = None if numbered else _RE_TURN_LABELLED.match(line)

        if numbered:
            flush()
            index, label, rest = numbered.groups()
            role, name = _split_label(label)
            # MK puts the name after the colon on the same line when the
            # rest of the line is all-caps and short: "KETUA: ANWAR USMAN".
            if name is None and _looks_like_a_name(rest):
                name, rest = rest.strip(), ""
            pending = Turn(
                label=label.strip(),
                role=role,
                speaker=name,
                text="",
                index=int(index),
            )
            buffer = [rest]
            continue

        if labelled and _plausible_label(labelled.group(1)):
            flush()
            label, rest = labelled.groups()
            role, name = _split_label(label)
            if name is None and _looks_like_a_name(rest):
                name, rest = rest.strip(), ""
            pending = Turn(label=label.strip(), role=role, speaker=name, text="")
            buffer = [rest]
            continue

        if pending is not None:
            buffer.append(line)

    flush()
    return Risalah(
        turns=[turn for turn in turns if turn.text or turn.speaker],
        front_matter=front_matter.strip(),
        source=source,
    )


def _looks_like_a_name(rest: str) -> bool:
    """True when the text after the colon is a name, not the speech.

    A name is short, all upper case and has no sentence punctuation. The
    risk this guards against is swallowing the first sentence of a turn
    as a speaker name, which would delete it from the label.
    """
    candidate = rest.strip()
    if not candidate or len(candidate) > 45:
        return False
    # Sentence punctuation means speech — except for the initials in a
    # name ("H. ASHABUL KAHFI"), which is why the pattern is allowed to
    # rescue the candidate.
    if any(mark in candidate for mark in ".,;?!") and not re.fullmatch(
        r"(?:[A-Z]{1,3}\.\s*)*[A-Z][A-Z\s.'-]+", candidate
    ):
        return False
    return candidate == candidate.upper() and len(candidate.split()) <= 6


def _plausible_label(label: str) -> bool:
    """Reject all-caps *speech* being read as an unnumbered turn label.

    A risalah sometimes sets an emphasised sentence in capitals, and a
    colon inside it would otherwise start a bogus turn. A label is short
    and has at most a few words.
    """
    collapsed = re.sub(r"\s+", " ", label).strip()
    if len(collapsed) > 60 or len(collapsed.split()) > 7:
        return False
    role, _ = _split_label(collapsed)
    bare = re.sub(r"\s*\([^)]*\)", "", role).strip()
    if bare in GENERIC_ROLES:
        return True
    # Faction labels (F-PKB, F-PDIP) and anything naming a known role
    # word count as labels.
    return bool(
        re.match(r"^f[-\s]", bare)
        or any(
            word in bare
            for word in (
                "ketua",
                "anggota",
                "pemohon",
                "termohon",
                "ahli",
                "saksi",
                "menteri",
                "dirjen",
                "pemerintah",
                "interupsi",
            )
        )
    )


def extract_pdf_pages(path: str | Path) -> list[str]:
    """Text of each page of a risalah PDF.

    `pypdf` is an optional dependency (`uv sync --extra pdf`): the
    benchmark and training halves of this package must install without
    a PDF toolchain.
    """
    try:
        from pypdf import PdfReader
    except ImportError as error:  # pragma: no cover - dependency guard
        raise ImportError("pypdf belum terpasang; jalankan `uv sync --extra pdf` di ml/") from error

    reader = PdfReader(str(path))
    return [page.extract_text() or "" for page in reader.pages]


def parse_risalah_pdf(path: str | Path, *, source: str = "") -> Risalah:
    """Read and parse a risalah PDF."""
    pages = strip_repeated_headers(extract_pdf_pages(path))
    return parse_risalah("\n".join(pages), source=source)
