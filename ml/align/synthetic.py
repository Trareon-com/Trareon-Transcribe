"""A hearing whose correct alignment is already known.

The MK and DPR risalah are not obtainable from this machine (see
`collect/access.py` and the sprint report), so the alignment pipeline
cannot be validated on the data it is built for yet. Validating it on
*nothing* was the other option.

So this builds a stand-in: concatenate N FLEURS `id_id` clips into one
long "hearing" WAV, remembering the exact start and end of each, and
write a risalah-shaped document whose turns carry those clips'
transcripts. The ground-truth alignment is therefore known exactly, and
`tests/test_pipeline.py` can assert that the pipeline recovers it rather
than merely that it produced output.

The document is deliberately made *difficult* in the ways a real risalah
is, because a fixture that is easier than reality validates nothing:

* A cover page and an attendance list that were never spoken.
* A repeated page header.
* Speaker turns with names and roles.
* Near-verbatim, not verbatim: a configurable fraction of words are
  paraphrased, dropped or reordered, which is what "risalah" means in
  practice.
* Numbers written as digits where the speaker said words.
* Closing formulae and a gavel marker with no audio behind them.

What it still does **not** reproduce, and so cannot validate: crosstalk,
overlapping speakers, far-field microphones, and spontaneous
disfluency. FLEURS is read speech. The keep-rate this fixture produces
is therefore an **upper bound** on the real one.
"""

from __future__ import annotations

import random
import re
import subprocess
import wave
from dataclasses import dataclass, field
from pathlib import Path

from common.atomic import write_json, write_text
from common.audio import duration as audio_duration
from eval.runners import parse_manifest_tsv

#: Silence between utterances, as a hearing has between turns.
GAP_SECS = 0.6

SPEAKERS = (
    ("ketua rapat", "H. ASHABUL KAHFI"),
    ("f-pkb", "H. MARWAN DASOPANG"),
    ("menteri agama", "NASARUDDIN UMAR"),
    ("f-pdip", "SELLY GANTINA"),
)


@dataclass
class TrueUtterance:
    """Ground truth for one concatenated clip."""

    clip: str
    text: str
    start: float
    end: float
    speaker: str
    role: str

    @property
    def duration(self) -> float:
        return self.end - self.start


@dataclass
class SyntheticHearing:
    audio: Path
    risalah: Path
    truth: list[TrueUtterance] = field(default_factory=list)

    @property
    def total_seconds(self) -> float:
        return max((item.end for item in self.truth), default=0.0)


def _write_silence(path: Path, seconds: float, sample_rate: int) -> None:
    frames = int(seconds * sample_rate)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(b"\x00\x00" * frames)


def _ffmpeg_concat(parts: list[Path], dest: Path, sample_rate: int) -> None:
    listing = dest.with_suffix(".concat.txt")
    listing.write_text(
        "\n".join(f"file '{part.resolve()}'" for part in parts) + "\n", encoding="utf-8"
    )
    completed = subprocess.run(
        [
            "ffmpeg",
            "-v",
            "error",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(listing),
            "-ac",
            "1",
            "-ar",
            str(sample_rate),
            str(dest),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    listing.unlink(missing_ok=True)
    if completed.returncode != 0:
        raise RuntimeError(f"ffmpeg concat gagal: {completed.stderr.strip()[-400:]}")


#: Paraphrases a risalah editor plausibly makes. Applied to the
#: *document*, never to the ground truth.
_PARAPHRASE = (
    (r"\bkemudian\b", "lalu"),
    (r"\btersebut\b", "itu"),
    (r"\bsangat\b", "amat"),
    (r"\bjuga\b", "pula"),
    (r"\byaitu\b", "yakni"),
)


def _near_verbatim(text: str, rng: random.Random, *, noise: float) -> str:
    """Make `text` near-verbatim rather than verbatim.

    `noise` is roughly the fraction of words touched. Paraphrase first,
    then drop the occasional short filler word — which is exactly the
    tidying a human minute-taker does.
    """
    for pattern, replacement in _PARAPHRASE:
        if rng.random() < noise * 3:
            text = re.sub(pattern, replacement, text, count=1)

    words = text.split()
    kept = [
        word
        for word in words
        # Only short words are ever dropped: a minute-taker tidies
        # particles, not content.
        if not (len(word) <= 4 and rng.random() < noise)
    ]
    return " ".join(kept) if len(kept) >= max(3, len(words) // 2) else text


def _digitise_numbers(text: str) -> str:
    """Write a few spelled-out numbers as digits, as a risalah does."""
    replacements = {
        "empat": "4",
        "lima": "5",
        "sepuluh": "10",
        "dua belas": "12",
        "seratus": "100",
        "dua ribu": "2000",
    }
    for words, digits in replacements.items():
        text = re.sub(rf"\b{words}\b", digits, text, count=1)
    return text


def build(
    fleurs_dir: str | Path,
    target_dir: str | Path,
    *,
    clips: int = 24,
    seed: int = 20261005,
    sample_rate: int = 16000,
    noise: float = 0.06,
    document_id: str = "sintetis-0001",
) -> SyntheticHearing:
    """Build one synthetic hearing and its risalah."""
    source = Path(fleurs_dir)
    target = Path(target_dir)
    target.mkdir(parents=True, exist_ok=True)

    entries = parse_manifest_tsv(source / "manifest.tsv")
    if not entries:
        raise RuntimeError(f"{source}: manifes FLEURS kosong")
    rng = random.Random(seed)
    chosen = entries[: min(clips, len(entries))]

    gap = target / "_gap.wav"
    _write_silence(gap, GAP_SECS, sample_rate)

    parts: list[Path] = []
    truth: list[TrueUtterance] = []
    cursor = 0.0
    for index, (relative, text) in enumerate(chosen):
        clip_path = source / relative
        if not clip_path.exists():
            continue
        duration = audio_duration(clip_path)
        if duration <= 0:
            continue
        role, speaker = SPEAKERS[index % len(SPEAKERS)]
        truth.append(
            TrueUtterance(
                clip=relative,
                text=text,
                start=cursor,
                end=cursor + duration,
                speaker=speaker,
                role=role,
            )
        )
        parts.append(clip_path)
        cursor += duration
        if index < len(chosen) - 1:
            parts.append(gap)
            cursor += GAP_SECS

    if not truth:
        raise RuntimeError("tidak ada klip FLEURS yang bisa dipakai")

    audio = target / f"{document_id}.wav"
    _ffmpeg_concat(parts, audio, sample_rate)
    gap.unlink(missing_ok=True)

    risalah_path = target / f"{document_id}.txt"
    write_text(risalah_path, _render_risalah(truth, rng, noise=noise, document_id=document_id))
    write_json(
        target / f"{document_id}.truth.json",
        {
            "document_id": document_id,
            "sample_rate": sample_rate,
            "gap_secs": GAP_SECS,
            "noise": noise,
            "seed": seed,
            "total_seconds": round(cursor, 3),
            "utterances": [
                {
                    "clip": item.clip,
                    "text": item.text,
                    "start": round(item.start, 3),
                    "end": round(item.end, 3),
                    "speaker": item.speaker,
                    "role": item.role,
                }
                for item in truth
            ],
        },
    )
    return SyntheticHearing(audio=audio, risalah=risalah_path, truth=truth)


def _render_risalah(
    truth: list[TrueUtterance], rng: random.Random, *, noise: float, document_id: str
) -> str:
    """Write the ground truth out as a risalah-shaped document."""
    header = f"RISALAH RAPAT SINTETIS {document_id.upper()}"
    lines = [
        "DEWAN PERWAKILAN RAKYAT",
        "REPUBLIK INDONESIA",
        "-------------------------",
        header,
        "",
        "PERIHAL",
        "DOKUMEN UJI UNTUK PIPELINE PENYELARASAN TRAREON",
        "",
        "ACARA",
        "RAPAT DENGAR PENDAPAT (UJI)",
        "",
        "J A K A R T A",
        "SENIN, 5 OKTOBER 2026",
        "",
        "SUSUNAN PERSIDANGAN",
    ]
    for index, (role, speaker) in enumerate(SPEAKERS, start=1):
        lines.append(f"{index}) {speaker} ({role})")
    lines += [
        "",
        "Pihak yang Hadir:",
        "Perwakilan kementerian dan anggota dewan.",
        "",
        "RAPAT DIBUKA PUKUL 09.30 WIB",
        "",
    ]

    # Group consecutive utterances by the same speaker into one turn, as
    # a risalah does.
    groups: list[tuple[str, str, list[str]]] = []
    for item in truth:
        text = _digitise_numbers(_near_verbatim(item.text, rng, noise=noise))
        if groups and groups[-1][1] == item.speaker:
            groups[-1][2].append(text)
        else:
            groups.append((item.role, item.speaker, [text]))

    for index, (role, speaker, texts) in enumerate(groups, start=1):
        lines.append(f"{index}. {role.upper()}: {speaker}")
        lines.append("")
        body = ". ".join(part.rstrip(".") for part in texts) + "."
        lines.append(body)
        lines.append("")
        if index % 3 == 0:
            # A repeated page header, as a PDF extraction leaves behind.
            lines += [header, f"{index}", ""]
        if index % 4 == 0:
            lines += ["(KETUK PALU 1X)", ""]

    lines += ["RAPAT DITUTUP PUKUL 12.00 WIB", ""]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    import argparse

    root = Path(__file__).resolve().parents[1] / "data"
    parser = argparse.ArgumentParser(prog="align.synthetic")
    parser.add_argument("--fleurs", default=str(root / "fleurs-id"))
    parser.add_argument("--out", default=str(root / "synthetic-hearing"))
    parser.add_argument("--clips", type=int, default=24)
    parser.add_argument("--noise", type=float, default=0.06)
    parser.add_argument("--id", dest="document_id", default="sintetis-0001")
    args = parser.parse_args(argv)

    hearing = build(
        args.fleurs,
        args.out,
        clips=args.clips,
        noise=args.noise,
        document_id=args.document_id,
    )
    print(
        f"{hearing.audio} ({hearing.total_seconds:.1f}s, "
        f"{len(hearing.truth)} ujaran)\n{hearing.risalah}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
