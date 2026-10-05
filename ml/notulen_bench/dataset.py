"""The benchmark cases: transcript, reference notulen, and gold answers.

One file per meeting under ``data/``, in a format built to be *written and
read by a person* — a transcript is prose and a reference notulen is a
document, and putting either inside JSON means escaped newlines nobody
can proofread.

::

    # kasus
    id: 01-rakor-pagu
    judul: Rapat Koordinasi Penyusunan Pagu Indikatif 2027
    templat: notulen_dinas
    jenis: rapat koordinasi
    sumber: sintetis
    menit: 12
    ciri: code-switching ringan

    # transkrip
    [00:00] Pimpinan Rapat: selamat pagi, rapat kita mulai
    [00:14] Kepala Bagian Perencanaan: terima kasih, Pak

    # referensi
    ## Pembahasan
    ...

    # emas
    ## peserta
    - Pimpinan Rapat
    ## keputusan
    - Pagu indikatif 2027 disetujui.
    ## tindak_lanjut
    - Susun draf RKA-KL | Kepala Bagian Perencanaan | 10 Oktober 2026

Every case in ``data/`` is **synthetic** — written for this benchmark,
not transcribed from a real meeting. Nothing in the app's session store
or in ``ml/`` held a transcript-plus-minutes pair when this was built, and
the MK/DPR risalah are not reachable from the build machine (see
``collect/access.py``). ``sumber:`` records that per case so no reader
mistakes it for field data.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent / "data"

_LINE = re.compile(r"^\[(\d+):(\d\d)\]\s*([^:]{1,60}?)\s*:\s*(.*)$")


@dataclass
class Segment:
    """One transcript line, numbered the way the model will cite it."""

    id: int
    start: float
    speaker: str
    text: str


@dataclass
class Case:
    """One benchmark meeting."""

    id: str
    judul: str
    templat: str
    jenis: str
    sumber: str
    menit: int
    ciri: str
    segments: list[Segment] = field(default_factory=list)
    referensi: str = ""
    peserta: list[str] = field(default_factory=list)
    keputusan: list[str] = field(default_factory=list)
    tindak_lanjut: list[tuple[str, str, str]] = field(default_factory=list)
    path: Path | None = None

    @property
    def transcript_text(self) -> str:
        """``[mm:ss] Speaker: text`` lines, as the app renders a transcript."""
        return "\n".join(f"[{_clock(s.start)}] {s.speaker}: {s.text}" for s in self.segments)

    @property
    def numbered_transcript(self) -> str:
        """The numbered rendering the ``segmen`` field cites into.

        Byte-identical to ``crate::provenance::numbered_transcript`` — the
        model is asked for segment numbers and has to see the same ones
        the app's fact check will resolve.
        """
        return "".join(
            f"[{s.id}] {_clock(s.start)} ({s.speaker}): {s.text}\n" for s in self.segments
        )


def _clock(seconds: float) -> str:
    total = int(max(seconds, 0.0))
    return f"{total // 60:02d}:{total % 60:02d}"


def parse_case(text: str, path: Path | None = None) -> Case:
    """Parse one case file."""
    blocks = _split_blocks(text)
    missing = {"kasus", "transkrip", "referensi", "emas"} - blocks.keys()
    if missing:
        raise ValueError(f"{path or '<text>'}: bagian hilang: {sorted(missing)}")

    meta = _parse_meta(blocks["kasus"])
    for key in ("id", "judul", "templat", "sumber"):
        if not meta.get(key):
            raise ValueError(f"{path or '<text>'}: metadata '{key}' kosong")

    segments = _parse_segments(blocks["transkrip"], path)
    gold = _split_subblocks(blocks["emas"])
    case = Case(
        id=meta["id"],
        judul=meta["judul"],
        templat=meta["templat"],
        jenis=meta.get("jenis", ""),
        sumber=meta["sumber"],
        menit=int(meta.get("menit", "0") or 0),
        ciri=meta.get("ciri", ""),
        segments=segments,
        referensi=blocks["referensi"].strip(),
        peserta=_bullets(gold.get("peserta", "")),
        keputusan=_bullets(gold.get("keputusan", "")),
        tindak_lanjut=[_follow_up(line) for line in _bullets(gold.get("tindak_lanjut", ""))],
        path=path,
    )
    if not case.segments:
        raise ValueError(f"{path or '<text>'}: transkrip kosong")
    # A meeting that decided nothing is a legitimate — and valuable —
    # case, but it has to say so rather than be an authoring slip.
    if not case.keputusan and not case.tindak_lanjut and "tanpa keputusan" not in case.ciri:
        raise ValueError(
            f"{path or '<text>'}: tidak ada keputusan atau tindak lanjut emas; "
            "tandai 'tanpa keputusan' di ciri bila memang begitu"
        )
    return case


def _split_blocks(text: str) -> dict[str, str]:
    blocks: dict[str, list[str]] = {}
    current: str | None = None
    for raw in text.splitlines():
        if raw.startswith("# ") and not raw.startswith("## "):
            current = raw[2:].strip().lower()
            blocks[current] = []
            continue
        if current is not None:
            blocks[current].append(raw)
    return {name: "\n".join(lines) for name, lines in blocks.items()}


def _split_subblocks(text: str) -> dict[str, str]:
    blocks: dict[str, list[str]] = {}
    current: str | None = None
    for raw in text.splitlines():
        if raw.startswith("## "):
            current = raw[3:].strip().lower()
            blocks[current] = []
            continue
        if current is not None:
            blocks[current].append(raw)
    return {name: "\n".join(lines) for name, lines in blocks.items()}


def _parse_meta(text: str) -> dict[str, str]:
    meta: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        key, _, value = line.partition(":")
        meta[key.strip().lower()] = value.strip()
    return meta


def _parse_segments(text: str, path: Path | None) -> list[Segment]:
    segments: list[Segment] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        match = _LINE.match(line)
        if not match:
            raise ValueError(f"{path or '<text>'}: baris transkrip tidak dikenali: {line!r}")
        minutes, seconds, speaker, body = match.groups()
        segments.append(
            Segment(
                id=len(segments) + 1,
                start=int(minutes) * 60 + int(seconds),
                speaker=speaker.strip(),
                text=body.strip(),
            )
        )
    return segments


def _bullets(text: str) -> list[str]:
    out: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("- "):
            out.append(line[2:].strip())
        elif line and out:
            # A wrapped continuation line belongs to the previous bullet.
            out[-1] = f"{out[-1]} {line}"
    return out


def _follow_up(line: str) -> tuple[str, str, str]:
    parts = [p.strip() for p in line.split("|")]
    while len(parts) < 3:
        parts.append("")
    return parts[0], parts[1], parts[2]


def load_cases(directory: Path | None = None) -> list[Case]:
    """Every case under ``directory``, sorted by filename."""
    base = directory or DATA_DIR
    cases = [
        parse_case(path.read_text(encoding="utf-8"), path) for path in sorted(base.glob("*.md"))
    ]
    seen: set[str] = set()
    for case in cases:
        if case.id in seen:
            raise ValueError(f"id kasus ganda: {case.id}")
        seen.add(case.id)
    return cases
