"""Writing aligned utterances as a Hugging Face dataset.

The output is an **audiofolder**: a directory of clips plus a
`metadata.jsonl` naming each one. `datasets.load_dataset("audiofolder",
data_dir=...)` reads it with no loader script, which matters because
script-based datasets stopped working in `datasets` 3.x — the reason
Common Voice and librivox-indonesia could not be read for this sprint's
benchmark at all. A format that depends on executable code is a format
that expires.

Clips are cut with ffmpeg at 16 kHz mono, which is what Whisper
consumes and what the training configs expect.

Speaker names: stored as a plain string label, nothing more. No speaker
embedding or voice profile is computed or persisted anywhere in this
pipeline. Under UU PDP a voice becomes biometric data when it is used to
identify someone, and an embedding is exactly that; a name attached to a
public hearing's turn is not. `ml/DATA_CARD.md` carries the full
reasoning and the removal procedure.
"""

from __future__ import annotations

import json
import subprocess
from dataclasses import asdict
from pathlib import Path

from align.cut import Utterance
from common.atomic import write_json, write_text

#: Clip format. 16 kHz mono is Whisper's input rate.
SAMPLE_RATE = 16000


class CutFailed(RuntimeError):
    pass


def _ffmpeg_cut(
    source: Path, dest: Path, start: float, end: float, *, sample_rate: int = SAMPLE_RATE
) -> None:
    duration = end - start
    if duration <= 0:
        raise CutFailed(f"durasi tidak sah untuk {dest.name}: {duration}")
    completed = subprocess.run(
        [
            "ffmpeg",
            "-v",
            "error",
            "-y",
            # -ss before -i seeks fast; re-encoding below keeps the cut
            # sample-accurate rather than snapping to a keyframe.
            "-ss",
            f"{start:.3f}",
            "-t",
            f"{duration:.3f}",
            "-i",
            str(source),
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
    if completed.returncode != 0:
        raise CutFailed(f"ffmpeg gagal memotong {dest.name}: {completed.stderr.strip()[-300:]}")


def write_shard(
    utterances: list[Utterance],
    source_audio: str | Path,
    target_dir: str | Path,
    *,
    document_id: str,
    source: str,
    licence_note: str,
    sample_rate: int = SAMPLE_RATE,
    extra: dict | None = None,
) -> Path:
    """Cut `utterances` out of `source_audio` into an audiofolder shard.

    Appends to `metadata.jsonl` if it already exists, so several
    documents can share one shard directory. Returns the metadata path.
    """
    audio_source = Path(source_audio)
    if not audio_source.exists():
        raise FileNotFoundError(audio_source)
    target = Path(target_dir)
    clips_dir = target / "data"
    clips_dir.mkdir(parents=True, exist_ok=True)

    rows: list[dict] = []
    for index, utterance in enumerate(utterances):
        name = f"{document_id}-{index:05d}.wav"
        _ffmpeg_cut(
            audio_source,
            clips_dir / name,
            utterance.start,
            utterance.end,
            sample_rate=sample_rate,
        )
        rows.append(
            {
                # audiofolder joins on this path, relative to data_dir.
                "file_name": f"data/{name}",
                "sentence": utterance.text,
                "speaker": utterance.speaker or "",
                "role": utterance.role,
                "start": round(utterance.start, 3),
                "end": round(utterance.end, 3),
                "duration": round(utterance.duration, 3),
                "anchor_rate": round(utterance.anchor_rate, 4),
                "document_id": document_id,
                "source": source,
                "licence_note": licence_note,
                **(extra or {}),
            }
        )

    metadata = target / "metadata.jsonl"
    with metadata.open("a", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
        handle.flush()

    write_text(
        target / "README.md",
        "# Shard dataset Trareon (audiofolder)\n\n"
        "Dimuat dengan:\n\n"
        "```python\n"
        "from datasets import load_dataset\n"
        f'ds = load_dataset("audiofolder", data_dir="{target}")\n'
        "```\n\n"
        "Kolom `sentence` adalah teks RISALAH (label), bukan keluaran model.\n"
        "`anchor_rate` adalah proporsi token yang benar-benar disepakati "
        "model dan risalah di rentang itu.\n\n"
        "Tidak ada embedding suara / voice profile yang disimpan di sini. "
        "Lihat ml/DATA_CARD.md.\n",
    )
    return metadata


def write_manifest_summary(target_dir: str | Path, summary: dict) -> Path:
    """Write the shard's own provenance and quality numbers."""
    return write_json(Path(target_dir) / "shard_report.json", summary)


def utterances_to_rows(utterances: list[Utterance]) -> list[dict]:
    return [asdict(utterance) for utterance in utterances]
