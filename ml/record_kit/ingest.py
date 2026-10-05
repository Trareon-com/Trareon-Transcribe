"""A recorded session plus its corrected transcript → dataset shard.

    uv run python -m record_kit.ingest \
        --audio sesi-01-dekat.wav \
        --transcript sesi-01-dekat.txt \
        --session-id sesi-01-dekat \
        --out ../data/shards/codeswitch

This reuses the alignment pipeline rather than reimplementing it: a
hand-corrected transcript is in exactly the same position as a risalah —
the right words, no timestamps — so the same anchoring gives it the
clock. The only differences are the transcript's format (`PENUTUR A:`
turns, per `TRANSCRIPTION_GUIDE.md`) and one extra, non-negotiable step.

**The extra step: `[potong]`.** A participant can ask during the session
for something to be removed, and the transcriber marks it. Any utterance
overlapping such a turn is dropped before anything is written to disk.
That is a consent obligation (`CONSENT.md` §10), not a quality filter,
so it is applied first and the count is reported — a removal that
happened silently cannot be shown to have happened at all.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from align.cut import CutConfig, cut_risalah
from align.hypothesis import transcribe, words_from_segments
from align.review_sheet import build_rows, write_markdown, write_tsv
from align.shards import write_shard
from collect.risalah import Risalah, Turn
from common.atomic import write_json
from common.audio import duration as audio_duration

#: `PENUTUR A: ...` — the format TRANSCRIPTION_GUIDE.md asks for.
_RE_SPEAKER_LINE = re.compile(r"^\s*(PENUTUR\s+[A-Z0-9]+|[A-Z][A-Z0-9 ._-]{1,30})\s*:\s*(.*)$")

#: Participant asked for this to be removed. Honoured, not filtered.
REDACT_MARKER = "[potong]"

#: Non-speech and uncertainty markers from the guide. Removed from the
#: label because an ASR will never produce them, so leaving them in
#: would teach the model to emit brackets.
_RE_MARKERS = re.compile(
    r"\[(?:tak\s+jelas(?::[^\]]*)?|tumpang\s+tindih|tawa|batuk|derau|nama)\]",
    re.IGNORECASE,
)


def parse_transcript(text: str) -> tuple[Risalah, list[int]]:
    """Parse a corrected transcript into turns.

    Returns the turns and the indices of those carrying `[potong]`.
    """
    turns: list[Turn] = []
    redacted: list[int] = []

    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        match = _RE_SPEAKER_LINE.match(stripped)
        if match:
            label, body = match.groups()
        elif turns:
            # A continuation line belongs to the open turn.
            turns[-1].text = f"{turns[-1].text} {stripped}".strip()
            if REDACT_MARKER.casefold() in stripped.casefold() and (len(turns) - 1 not in redacted):
                redacted.append(len(turns) - 1)
            continue
        else:
            continue

        if REDACT_MARKER.casefold() in body.casefold():
            redacted.append(len(turns))
        turns.append(
            Turn(
                label=label.strip(),
                role=label.strip().casefold(),
                speaker=label.strip(),
                text=body.strip(),
                index=len(turns) + 1,
            )
        )

    return Risalah(turns=turns, source="rekaman-sendiri"), redacted


def clean_label(text: str) -> str:
    """Strip the guide's markers from a training label."""
    text = _RE_MARKERS.sub(" ", text)
    text = re.sub(re.escape(REDACT_MARKER), " ", text, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", text).strip()


def ingest(
    audio: str | Path,
    transcript: str | Path,
    out_dir: str | Path,
    *,
    session_id: str,
    model: str | Path,
    cli: str | Path,
    licence_note: str = "Rekaman sendiri, consent UU PDP (ml/record_kit/CONSENT.md)",
    cut_config: CutConfig | None = None,
    language: str = "id",
    review_sample: int = 30,
) -> dict:
    """Turn one recorded session into a dataset shard."""
    raw = Path(transcript).read_text(encoding="utf-8")
    parsed, redacted_indices = parse_transcript(raw)
    if not parsed.turns:
        raise ValueError(
            f"{transcript}: tidak ada giliran bicara terbaca. "
            "Format yang diharapkan: 'PENUTUR A: ...' (lihat TRANSCRIPTION_GUIDE.md)"
        )

    # Consent first: drop redacted turns before alignment, so no clip of
    # them is ever written, not even temporarily.
    redacted_set = set(redacted_indices)
    kept_turns = [
        Turn(
            label=turn.label,
            role=turn.role,
            speaker=turn.speaker,
            text=clean_label(turn.text),
            index=turn.index,
        )
        for index, turn in enumerate(parsed.turns)
        if index not in redacted_set
    ]
    kept_turns = [turn for turn in kept_turns if turn.text]
    usable = Risalah(turns=kept_turns, source=parsed.source)

    segments = transcribe(audio, model, cli=cli, language=language)
    hyp_words = words_from_segments(segments)
    result = cut_risalah(usable, hyp_words, config=cut_config)

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    if result.utterances:
        write_shard(
            result.utterances,
            audio,
            out,
            document_id=session_id,
            source="codeswitch-rekaman-sendiri",
            licence_note=licence_note,
            extra={"consent_version": "1.0", "synthetic": False},
        )

    rows = build_rows(result.utterances, hyp_words, document_id=session_id, sample=review_sample)
    if rows:
        write_tsv(rows, out / f"review-{session_id}.tsv")
        write_markdown(rows, out / f"review-{session_id}.md", document_id=session_id)

    report = {
        "session_id": session_id,
        "audio": str(audio),
        "audio_seconds": round(audio_duration(audio), 2),
        "turns_in_transcript": len(parsed.turns),
        "turns_redacted_by_request": len(redacted_indices),
        "turns_used": len(kept_turns),
        "speakers": sorted({turn.speaker for turn in kept_turns if turn.speaker}),
        "cut": result.stats.as_dict(),
        "consent": {
            "form": "ml/record_kit/CONSENT.md",
            "version": "1.0",
            "redaction_marker": REDACT_MARKER,
            "redacted_turns_dropped_before_cutting": len(redacted_indices),
        },
    }
    write_json(out / f"ingest-{session_id}.json", report)
    return report


def main(argv: list[str] | None = None) -> int:
    repo = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(prog="record_kit.ingest")
    parser.add_argument("--audio", required=True)
    parser.add_argument("--transcript", required=True)
    parser.add_argument("--session-id", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--model",
        default=str(Path.home() / "Library/Caches/TrareonTranscribe/models/ggml-base.bin"),
    )
    parser.add_argument("--cli", default=str(repo / "rust_core/target/release/transcribe_cli"))
    parser.add_argument("--language", default="id")
    parser.add_argument("--min-anchor-rate", type=float, default=0.6)
    parser.add_argument("--review-sample", type=int, default=30)
    args = parser.parse_args(argv)

    if not Path(args.cli).exists():
        print(
            f"transcribe_cli tidak ada di {args.cli}\n"
            "  bangun dulu: cd rust_core && cargo build --release --bin transcribe_cli",
            file=sys.stderr,
        )
        return 2

    report = ingest(
        args.audio,
        args.transcript,
        args.out,
        session_id=args.session_id,
        model=args.model,
        cli=args.cli,
        cut_config=CutConfig(min_anchor_rate=args.min_anchor_rate),
        language=args.language,
        review_sample=args.review_sample,
    )

    cut = report["cut"]
    print(
        f"{report['session_id']}: {report['audio_seconds'] / 3600:.3f} jam masuk -> "
        f"{cut['hours_kept']:.3f} jam disimpan, {cut['kept']} ujaran, "
        f"{len(report['speakers'])} penutur"
    )
    if report["turns_redacted_by_request"]:
        print(
            f"  {report['turns_redacted_by_request']} giliran dibuang atas permintaan "
            f"peserta ({REDACT_MARKER}) sebelum pemotongan"
        )
    for reason, count in cut.get("dropped", {}).items():
        if count:
            print(f"  dibuang {reason}: {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
