"""One recording plus its risalah in, dataset shard out.

    uv run python -m align.pipeline \
        --audio data/pilot/mk-0001.wav \
        --risalah data/pilot/mk-0001.pdf \
        --model ~/Library/Caches/TrareonTranscribe/models/ggml-base.bin \
        --out data/shards/mk

Stages, in order: parse the risalah → transcribe the audio with the
app's own CLI → anchor the risalah to the hypothesis → cut utterances
that pass every gate → write an audiofolder shard and a review sheet.

The report it prints is the deliverable, not the shard: **hours in,
hours kept, and why the rest went**. A pipeline that silently keeps 4%
of a corpus looks identical to one that keeps 80% unless it says so.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

from align.cut import CutConfig, CutResult, cut_risalah
from align.hypothesis import HypWord, Segment, transcribe, words_from_segments
from align.review_sheet import build_rows, write_markdown, write_tsv
from align.shards import write_manifest_summary, write_shard
from align.textalign import align_tokens, alignment_report
from collect.risalah import Risalah, parse_risalah, parse_risalah_pdf
from common.atomic import write_json
from common.audio import duration as audio_duration
from eval.normalize import ID_MEETING, tokenize


@dataclass
class PipelineReport:
    document_id: str
    audio_seconds_in: float
    risalah_words: int
    risalah_turns: int
    alignment: dict
    cut: dict
    speakers: list[str]
    shard: str | None = None

    @property
    def hours_in(self) -> float:
        return self.audio_seconds_in / 3600.0

    @property
    def hours_kept(self) -> float:
        return float(self.cut.get("hours_kept", 0.0))

    @property
    def keep_rate(self) -> float:
        return self.hours_kept / self.hours_in if self.hours_in > 0 else 0.0

    def as_dict(self) -> dict:
        return {
            "document_id": self.document_id,
            "hours_in": round(self.hours_in, 4),
            "hours_kept": round(self.hours_kept, 4),
            "keep_rate": round(self.keep_rate, 4),
            "risalah_words": self.risalah_words,
            "risalah_turns": self.risalah_turns,
            "speakers": self.speakers,
            "alignment": self.alignment,
            "cut": self.cut,
            "shard": self.shard,
        }

    def summary(self) -> str:
        return (
            f"{self.document_id}: {self.hours_in:.3f} jam masuk -> "
            f"{self.hours_kept:.3f} jam disimpan ({self.keep_rate * 100:.1f}%), "
            f"anchor {self.alignment.get('anchor_rate', 0) * 100:.1f}%, "
            f"{self.cut.get('kept', 0)} ujaran"
        )


def load_risalah(path: str | Path, *, source: str) -> Risalah:
    target = Path(path)
    if target.suffix.casefold() == ".pdf":
        return parse_risalah_pdf(target, source=source)
    return parse_risalah(target.read_text(encoding="utf-8"), source=source)


def run_one(
    audio: str | Path,
    risalah_path: str | Path,
    *,
    model: str | Path,
    cli: str | Path,
    out_dir: str | Path,
    document_id: str,
    source: str = "mk",
    licence_note: str = "",
    cut_config: CutConfig | None = None,
    language: str = "id",
    gpu: bool = False,
    review_sample: int = 30,
    segments: list[Segment] | None = None,
    write_clips: bool = True,
) -> tuple[PipelineReport, CutResult, list[HypWord]]:
    """Run the whole pipeline for one document.

    `segments` lets a caller supply a hypothesis instead of transcribing
    — used by the validation fixture, which already knows the audio.
    """
    risalah = load_risalah(risalah_path, source=source)
    if not risalah.turns:
        raise ValueError(f"{risalah_path}: tidak ada giliran bicara yang terbaca")

    if segments is None:
        segments = transcribe(audio, model, cli=cli, language=language, gpu=gpu)
    hyp_words = words_from_segments(segments)

    result = cut_risalah(risalah, hyp_words, config=cut_config)

    # Alignment numbers for the whole document, for the report.
    all_tokens: list[str] = []
    for turn in risalah.turns:
        all_tokens.extend(tokenize(turn.text, ID_MEETING))
    aligned = align_tokens(all_tokens, hyp_words, config=ID_MEETING)

    report = PipelineReport(
        document_id=document_id,
        audio_seconds_in=audio_duration(audio),
        risalah_words=risalah.words,
        risalah_turns=len(risalah.turns),
        alignment=alignment_report(aligned),
        cut=result.stats.as_dict(),
        speakers=risalah.speakers,
    )

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    if write_clips and result.utterances:
        write_shard(
            result.utterances,
            audio,
            out,
            document_id=document_id,
            source=source,
            licence_note=licence_note,
        )
        report.shard = str(out)

    rows = build_rows(result.utterances, hyp_words, document_id=document_id, sample=review_sample)
    if rows:
        write_tsv(rows, out / f"review-{document_id}.tsv")
        write_markdown(rows, out / f"review-{document_id}.md", document_id=document_id)

    write_json(out / f"report-{document_id}.json", report.as_dict())
    write_manifest_summary(out, report.as_dict())
    return report, result, hyp_words


def main(argv: list[str] | None = None) -> int:
    repo = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(prog="align.pipeline")
    parser.add_argument("--audio", required=True)
    parser.add_argument("--risalah", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--cli", default=str(repo / "rust_core/target/release/transcribe_cli"))
    parser.add_argument("--id", dest="document_id", default=None)
    parser.add_argument("--source", default="mk")
    parser.add_argument("--licence-note", default="")
    parser.add_argument("--language", default="id")
    parser.add_argument("--gpu", action="store_true")
    parser.add_argument("--min-anchor-rate", type=float, default=0.6)
    parser.add_argument("--review-sample", type=int, default=30)
    parser.add_argument("--no-clips", action="store_true", help="hitung saja, jangan potong audio")
    args = parser.parse_args(argv)

    cli = Path(args.cli)
    if not cli.exists():
        print(
            f"transcribe_cli tidak ada di {cli}\n"
            "  bangun dulu: cd rust_core && cargo build --release --bin transcribe_cli",
            file=sys.stderr,
        )
        return 2

    document_id = args.document_id or Path(args.audio).stem
    report, _, _ = run_one(
        args.audio,
        args.risalah,
        model=args.model,
        cli=cli,
        out_dir=args.out,
        document_id=document_id,
        source=args.source,
        licence_note=args.licence_note,
        cut_config=CutConfig(min_anchor_rate=args.min_anchor_rate),
        language=args.language,
        gpu=args.gpu,
        review_sample=args.review_sample,
        write_clips=not args.no_clips,
    )
    print(report.summary())
    for reason, count in report.cut.get("dropped", {}).items():
        if count:
            print(f"  dibuang {reason}: {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
