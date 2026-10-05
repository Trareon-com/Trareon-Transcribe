"""The one manifest format every collector in `ml/collect/` writes.

JSONL, one record per media item. Append-only and resumable: a collector
re-run reads the ids it already has and skips them, so an interrupted
pilot continues rather than re-downloading.

Why a flat record and not a nested one: the manifest is the join key
between collection, alignment and evaluation, and it gets read by `jq`
far more often than by Python.
"""

from __future__ import annotations

import json
from collections.abc import Iterable, Iterator
from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from pathlib import Path

MANIFEST_FIELDS = (
    "id",
    "source",
    "url",
    "audio_path",
    "transcript_path",
    "duration",
    "licence_note",
    "retrieved_at",
)


def utc_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


@dataclass
class Record:
    """One collected item.

    `audio_path` / `transcript_path` are relative to the manifest's own
    directory when they point inside it, so a corpus can be moved as a
    unit. `duration` is seconds of audio, `None` when not yet probed —
    a collector must not guess it.
    """

    id: str
    source: str
    url: str
    audio_path: str | None = None
    transcript_path: str | None = None
    duration: float | None = None
    licence_note: str = ""
    retrieved_at: str = field(default_factory=utc_now)
    # Free-form, source-specific: perkara number, komisi, date, speaker
    # list. Kept out of the fixed columns so that adding a source never
    # changes the schema everything else reads.
    extra: dict = field(default_factory=dict)

    def to_json(self) -> str:
        return json.dumps(asdict(self), ensure_ascii=False, sort_keys=True)


class ManifestWriter:
    """Append records to a JSONL manifest, skipping ids already present.

    Appends are line-at-a-time with an fsync, which is atomic enough for
    JSONL: a torn write loses at most the final line, and the reader
    tolerates it (see `read_manifest`). Rewriting the whole file
    atomically on every record would make a 10 000-item crawl O(n^2).
    """

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.seen: set[str] = {record.id for record in read_manifest(self.path)}

    def __contains__(self, item_id: str) -> bool:
        return item_id in self.seen

    def add(self, record: Record) -> bool:
        """Append `record`. Returns False if its id was already there."""
        if record.id in self.seen:
            return False
        with self.path.open("a", encoding="utf-8") as handle:
            handle.write(record.to_json() + "\n")
            handle.flush()
        self.seen.add(record.id)
        return True

    def extend(self, records: Iterable[Record]) -> int:
        return sum(1 for record in records if self.add(record))


def read_manifest(path: str | Path) -> Iterator[Record]:
    """Yield records from a JSONL manifest.

    A malformed final line is skipped (a crawl killed mid-append), but a
    malformed line anywhere else raises: silently reading fewer items
    than the file lists is how a corpus stops being reproducible.
    """
    target = Path(path)
    if not target.exists():
        return
    lines = target.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        if not line.strip():
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            if index == len(lines) - 1:
                return  # torn last append
            raise
        known = {key: payload.pop(key) for key in list(payload) if key in Record.__annotations__}
        extra = known.pop("extra", None) or {}
        extra.update(payload)
        yield Record(**known, extra=extra)


def total_hours(path: str | Path) -> float:
    """Hours of audio in a manifest. Items without a duration count 0."""
    return sum(r.duration or 0.0 for r in read_manifest(path)) / 3600.0
