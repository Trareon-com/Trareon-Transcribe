"""The ASR hypothesis that alignment anchors against.

The hypothesis comes from the app's own CLI (`transcribe_cli`), so the
alignment is anchored against the same engine the product ships. Its
JSON export gives **segment**-level timing — `timestamp` and `duration`
per segment — and no word-level times, so word times here are
interpolated inside each segment.

That is honest about the resolution available, and it is enough: the
pipeline cuts utterances of 2–25 seconds, and a segment is a few
seconds, so a word-time error of a few hundred milliseconds moves a cut
boundary well inside the silence the VAD already found. Interpolation is
by cumulative **character** count rather than word count, because
Indonesian word lengths vary enormously — `di` and
`mempertanggungjawabkan` are not the same duration — and character count
is a better proxy for speaking time.
"""

from __future__ import annotations

import glob
import json
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

_RE_WORD_SPLIT = re.compile(r"\s+")


@dataclass
class Segment:
    """One ASR segment with its time span."""

    text: str
    start: float
    end: float

    @property
    def duration(self) -> float:
        return max(0.0, self.end - self.start)


@dataclass
class HypWord:
    """One hypothesis word with an interpolated time span."""

    text: str
    start: float
    end: float
    segment_index: int


class TranscribeFailed(RuntimeError):
    pass


def words_from_segments(segments: list[Segment]) -> list[HypWord]:
    """Interpolate per-word times inside each segment.

    Proportional to cumulative character length. A zero-length or
    zero-duration segment contributes nothing rather than dividing by
    zero.
    """
    words: list[HypWord] = []
    for index, segment in enumerate(segments):
        tokens = [token for token in _RE_WORD_SPLIT.split(segment.text.strip()) if token]
        if not tokens or segment.duration <= 0.0:
            continue
        lengths = [len(token) for token in tokens]
        total = sum(lengths)
        if total == 0:
            continue
        cursor = 0
        for token, length in zip(tokens, lengths, strict=True):
            start = segment.start + segment.duration * (cursor / total)
            cursor += length
            end = segment.start + segment.duration * (cursor / total)
            words.append(HypWord(text=token, start=start, end=end, segment_index=index))
    return words


def load_cli_json(path: str | Path) -> list[Segment]:
    """Read `transcribe_cli`'s JSON export.

    The export is a flat array of segment objects with `timestamp` and
    `duration`. Partial segments are dropped: they are live-preview
    artefacts and their text is superseded.
    """
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    if isinstance(payload, dict):
        payload = payload.get("segments", [])

    segments: list[Segment] = []
    for row in payload:
        if not isinstance(row, dict) or row.get("is_partial"):
            continue
        text = (row.get("text") or "").strip()
        if not text:
            continue
        start = float(row.get("timestamp") or 0.0)
        duration = float(row.get("duration") or 0.0)
        segments.append(Segment(text=text, start=start, end=start + duration))
    segments.sort(key=lambda segment: segment.start)
    return segments


def transcribe(
    audio: str | Path,
    model: str | Path,
    *,
    cli: str | Path,
    language: str = "id",
    gpu: bool = False,
    timeout: float = 36000.0,
) -> list[Segment]:
    """Transcribe `audio` with the app's CLI and return its segments.

    The CLI writes into an output directory of its own choosing, so this
    runs it in a temporary directory and reads whatever JSON appears.
    """
    audio_path = Path(audio).resolve()
    if not audio_path.exists():
        raise FileNotFoundError(audio_path)

    with tempfile.TemporaryDirectory(prefix="trareon-align-") as workdir:
        args = [
            str(cli),
            "--batch",
            str(audio_path),
            "--output",
            workdir,
            "--model",
            str(model),
            "--format",
            "json",
            "--language",
            language,
        ]
        if gpu:
            args.append("--gpu")
        completed = subprocess.run(
            args, capture_output=True, text=True, timeout=timeout, check=False
        )
        if completed.returncode != 0:
            raise TranscribeFailed(
                f"transcribe_cli gagal untuk {audio_path.name}: {completed.stderr.strip()[-600:]}"
            )
        produced = sorted(glob.glob(str(Path(workdir) / "**" / "*.json"), recursive=True))
        if not produced:
            raise TranscribeFailed(f"tidak ada JSON untuk {audio_path.name}")
        return load_cli_json(produced[0])
