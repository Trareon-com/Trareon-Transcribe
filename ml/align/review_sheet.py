"""The manual label-quality spot check.

The sprint requires a hand review of 30 random utterances, and this
writes the sheet for it. Two formats from the same data: a TSV to fill
in, and a Markdown rendering to read.

What makes the sheet worth filling in rather than nodding at:

* The sample is **random with a fixed seed**, so a second reviewer gets
  the same 30 utterances and two reviews are comparable.
* Each row shows the risalah label *and* the ASR hypothesis for the same
  span. Reading them side by side is what makes a bad alignment
  obvious — a label that has nothing to do with the hypothesis is a
  wrong-session join, and a label that is a sentence ahead of it is a
  drift.
* The verdict column is a closed vocabulary (`ok`, `geser`, `salah`,
  `potong`), because free-text verdicts cannot be counted.
* It records the anchor rate per row, so the review doubles as a check
  on whether `min_anchor_rate` is set anywhere near right.
"""

from __future__ import annotations

import random
from dataclasses import dataclass
from pathlib import Path

from align.cut import Utterance
from align.hypothesis import HypWord
from common.atomic import write_text

#: The closed verdict vocabulary, so a review can be tallied.
VERDICTS = {
    "ok": "label cocok dengan audio",
    "geser": "label benar tapi rentang waktu bergeser",
    "salah": "label tidak cocok dengan audio sama sekali",
    "potong": "ujaran terpotong di tengah kata",
    "ragu": "tidak bisa dinilai",
}


@dataclass
class ReviewRow:
    index: int
    document_id: str
    clip: str
    start: float
    end: float
    duration: float
    anchor_rate: float
    speaker: str
    label: str
    hypothesis: str


def hypothesis_in_span(hyp_words: list[HypWord], start: float, end: float) -> str:
    """The model's own words for a time span.

    Overlap rather than containment: a word straddling the boundary is
    part of what a reviewer will hear.
    """
    return " ".join(
        word.text for word in hyp_words if word.end > start and word.start < end
    ).strip()


def build_rows(
    utterances: list[Utterance],
    hyp_words: list[HypWord],
    *,
    document_id: str,
    sample: int = 30,
    seed: int = 20261005,
    clip_pattern: str = "{document_id}-{index:05d}.wav",
) -> list[ReviewRow]:
    """Sample `sample` utterances for review, deterministically."""
    indexed = list(enumerate(utterances))
    rng = random.Random(seed)
    chosen = indexed if len(indexed) <= sample else rng.sample(indexed, sample)
    chosen.sort(key=lambda pair: pair[0])

    return [
        ReviewRow(
            index=index,
            document_id=document_id,
            clip=clip_pattern.format(document_id=document_id, index=index),
            start=round(utterance.start, 3),
            end=round(utterance.end, 3),
            duration=round(utterance.duration, 3),
            anchor_rate=round(utterance.anchor_rate, 4),
            speaker=utterance.speaker or "",
            label=utterance.text,
            hypothesis=hypothesis_in_span(hyp_words, utterance.start, utterance.end),
        )
        for index, utterance in chosen
    ]


def write_tsv(rows: list[ReviewRow], path: str | Path) -> Path:
    """The sheet a reviewer fills in."""
    header = [
        "no",
        "klip",
        "mulai",
        "selesai",
        "durasi",
        "anchor_rate",
        "penutur",
        "label_risalah",
        "hipotesis_asr",
        "putusan",
        "catatan",
    ]
    lines = ["\t".join(header)]
    for row in rows:
        lines.append(
            "\t".join(
                [
                    str(row.index),
                    row.clip,
                    f"{row.start:.3f}",
                    f"{row.end:.3f}",
                    f"{row.duration:.3f}",
                    f"{row.anchor_rate:.4f}",
                    row.speaker,
                    _clean(row.label),
                    _clean(row.hypothesis),
                    "",  # putusan: ok / geser / salah / potong / ragu
                    "",
                ]
            )
        )
    return write_text(path, "\n".join(lines) + "\n")


def write_markdown(rows: list[ReviewRow], path: str | Path, *, document_id: str) -> Path:
    """A readable rendering of the same sheet."""
    lines = [
        f"# Lembar periksa label — {document_id}",
        "",
        f"{len(rows)} ujaran diambil acak (seed tetap, lihat `ml/align/review_sheet.py`).",
        "",
        "Isi kolom **putusan** dengan salah satu:",
        "",
    ]
    lines += [f"- `{key}` — {description}" for key, description in VERDICTS.items()]
    lines += [
        "",
        "Cara menilai: dengarkan klip, lalu bandingkan **label risalah** dengan "
        "**hipotesis ASR**. Label yang sama sekali tidak berhubungan dengan "
        "hipotesis berarti rekaman dijodohkan ke risalah yang salah; label yang "
        "selalu satu kalimat di depan hipotesis berarti penyelarasan bergeser.",
        "",
        "| No | Klip | Mulai | Durasi | Anchor | Penutur "
        "| Label risalah | Hipotesis ASR | Putusan |",
        "|---:|---|---:|---:|---:|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row.index} | `{row.clip}` | {row.start:.1f}s | {row.duration:.1f}s "
            f"| {row.anchor_rate:.2f} | {row.speaker or '—'} "
            f"| {_md(row.label)} | {_md(row.hypothesis)} |  |"
        )
    lines.append("")
    return write_text(path, "\n".join(lines))


def tally(verdicts: list[str]) -> dict:
    """Count a filled-in sheet.

    Unknown verdicts are counted separately rather than ignored: a
    review with ten typos is a review whose numbers are wrong.
    """
    counts = dict.fromkeys(VERDICTS, 0)
    unknown = 0
    for raw in verdicts:
        key = raw.strip().casefold()
        if key in counts:
            counts[key] += 1
        elif key:
            unknown += 1
    judged = sum(counts[key] for key in counts if key != "ragu")
    return {
        "counts": counts,
        "unknown": unknown,
        "judged": judged,
        "ok_rate": round(counts["ok"] / judged, 4) if judged else 0.0,
        # The number that decides whether the dataset is usable: a
        # "salah" is a confidently mislabelled training example.
        "wrong_rate": round(counts["salah"] / judged, 4) if judged else 0.0,
    }


def read_tsv_verdicts(path: str | Path) -> list[str]:
    """Pull the verdict column out of a filled-in sheet."""
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    if not lines:
        return []
    header = lines[0].split("\t")
    try:
        column = header.index("putusan")
    except ValueError:
        return []
    verdicts = []
    for line in lines[1:]:
        if not line.strip():
            continue
        fields = line.split("\t")
        verdicts.append(fields[column] if column < len(fields) else "")
    return verdicts


def _clean(text: str) -> str:
    return text.replace("\t", " ").replace("\n", " ").strip()


def _md(text: str) -> str:
    return _clean(text).replace("|", "\\|")[:160]
