"""Scoring the aligner against known ground truth.

`align/synthetic.py` builds a hearing whose correct alignment is known
exactly. This checks what the pipeline recovered, which is a stronger
statement than the manual review sheet can make: the review sheet asks a
human whether a label sounds right, this asks whether the label *is*
right.

Three numbers, because "the label is wrong" and "the label is in the
wrong place" are different faults with different fixes:

* **`text_wer`** — the label against the single truth utterance it
  overlaps most. This answers *is the text right*. The risalah is
  deliberately near-verbatim rather than verbatim, so a small value here
  is expected and correct: it is the risalah's own editing. A large
  value means the aligner attached unrelated text to the audio, which is
  the fault that poisons a dataset.
* **`label_wer`** — the label against *everything audible* in its span.
  This adds the cost of a cut boundary in the wrong place: an utterance
  whose audio contains one and a half truth utterances scores badly here
  even when its text is a perfect copy of one of them. The gap between
  `text_wer` and `label_wer` is therefore a direct measure of boundary
  slop.
* **Time IoU** — how well each span overlaps the truth utterance it came
  from. Correct text attached to the wrong seconds is still bad training
  data.

All are computed under the benchmark's normalisation policy and pooled
rather than averaged, so they are comparable with everything else this
project reports.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

from align.cut import Utterance
from common.atomic import write_json
from eval.normalize import ID_MEETING, NormalizerConfig
from eval.wer import word_errors


@dataclass
class TruthSpan:
    text: str
    start: float
    end: float
    speaker: str

    @property
    def duration(self) -> float:
        return self.end - self.start


def load_truth(path: str | Path) -> list[TruthSpan]:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    return [
        TruthSpan(
            text=row["text"],
            start=float(row["start"]),
            end=float(row["end"]),
            speaker=row.get("speaker", ""),
        )
        for row in payload["utterances"]
    ]


def overlap(start: float, end: float, other: TruthSpan) -> float:
    return max(0.0, min(end, other.end) - max(start, other.start))


def iou(start: float, end: float, other: TruthSpan) -> float:
    intersection = overlap(start, end, other)
    if intersection <= 0:
        return 0.0
    union = max(end, other.end) - min(start, other.start)
    return intersection / union if union > 0 else 0.0


def _best_span(truth: list[TruthSpan], start: float, end: float) -> TruthSpan | None:
    """The truth span this utterance overlaps most, or None."""
    overlapping = [(overlap(start, end, span), span) for span in truth]
    overlapping = [(amount, span) for amount, span in overlapping if amount > 0]
    if not overlapping:
        return None
    return max(overlapping, key=lambda pair: pair[0])[1]


#: A truth span counts as *audible* inside an utterance when at least
#: this fraction of it falls within the utterance's span. A span clipped
#: by 200 ms at the edge is not content the label was supposed to cover.
AUDIBLE_FRACTION = 0.5


@dataclass
class UtteranceVerdict:
    index: int
    start: float
    end: float
    label: str
    #: Concatenated truth text for every span audible in this utterance.
    truth: str
    iou: float
    #: WER of the label against everything audible in the span. Includes
    #: the cost of a cut boundary in the wrong place: an utterance whose
    #: audio contains one and a half truth utterances will score badly
    #: here even if its text is a perfect copy of one of them.
    label_wer: float
    #: WER against the single best-overlapping truth span alone. Isolates
    #: "is the text right" from "is the boundary right".
    text_wer: float
    speaker_correct: bool | None


@dataclass
class ValidationReport:
    document_id: str
    utterances: int
    mean_iou: float
    median_iou: float
    label_wer: float
    text_wer: float
    speaker_accuracy: float | None
    #: Utterances whose label bears no relation to the audio. The number
    #: that decides usability.
    grossly_wrong: int
    grossly_wrong_rate: float
    truth_seconds: float
    kept_seconds: float
    coverage: float
    verdicts: list[UtteranceVerdict]

    def as_dict(self) -> dict:
        return {
            "document_id": self.document_id,
            "utterances": self.utterances,
            "mean_iou": round(self.mean_iou, 4),
            "median_iou": round(self.median_iou, 4),
            "label_wer": round(self.label_wer, 4),
            "text_wer": round(self.text_wer, 4),
            "speaker_accuracy": (
                round(self.speaker_accuracy, 4) if self.speaker_accuracy is not None else None
            ),
            "grossly_wrong": self.grossly_wrong,
            "grossly_wrong_rate": round(self.grossly_wrong_rate, 4),
            "truth_seconds": round(self.truth_seconds, 2),
            "kept_seconds": round(self.kept_seconds, 2),
            "coverage": round(self.coverage, 4),
            "per_utterance": [
                {
                    "index": verdict.index,
                    "start": round(verdict.start, 2),
                    "end": round(verdict.end, 2),
                    "iou": round(verdict.iou, 4),
                    "label_wer": round(verdict.label_wer, 4),
                    "text_wer": round(verdict.text_wer, 4),
                    "speaker_correct": verdict.speaker_correct,
                    "label": verdict.label,
                    "truth": verdict.truth,
                }
                for verdict in self.verdicts
            ],
        }

    def summary(self) -> str:
        speaker = (
            f", penutur benar {self.speaker_accuracy * 100:.0f}%"
            if self.speaker_accuracy is not None
            else ""
        )
        return (
            f"{self.document_id}: {self.utterances} ujaran, "
            f"IoU waktu rata-rata {self.mean_iou:.2f}, "
            f"WER teks {self.text_wer * 100:.1f}%, "
            f"WER label+batas {self.label_wer * 100:.1f}%, "
            f"salah total {self.grossly_wrong} "
            f"({self.grossly_wrong_rate * 100:.1f}%){speaker}"
        )


#: Above this, the label is not describing the audio at all.
GROSSLY_WRONG_WER = 0.8


def validate(
    utterances: list[Utterance],
    truth: list[TruthSpan],
    *,
    document_id: str = "",
    config: NormalizerConfig = ID_MEETING,
) -> ValidationReport:
    """Score kept utterances against ground truth."""
    verdicts: list[UtteranceVerdict] = []
    # Pooled, not the mean of per-utterance rates - same rule as the
    # benchmark, so a short utterance does not outweigh a long one.
    pooled_errors = pooled_length = 0
    pooled_text_errors = pooled_text_length = 0

    for index, utterance in enumerate(utterances):
        audible = [
            span
            for span in truth
            if span.duration > 0
            and overlap(utterance.start, utterance.end, span) / span.duration >= AUDIBLE_FRACTION
        ]
        truth_text = " ".join(span.text for span in audible)

        # IoU and text WER both key on the single best-matching span, so
        # together they answer "did this utterance land on one real
        # utterance and copy its words", independently of boundary slop.
        best_span = _best_span(truth, utterance.start, utterance.end)
        best_iou = iou(utterance.start, utterance.end, best_span) if best_span else 0.0
        text_errors = word_errors(best_span.text if best_span else "", utterance.text, config)
        errors = word_errors(truth_text, utterance.text, config)
        pooled_errors += errors.total
        pooled_length += errors.reference_length
        pooled_text_errors += text_errors.total
        pooled_text_length += text_errors.reference_length

        speaker_correct: bool | None = None
        if audible and utterance.speaker:
            speaker_correct = utterance.speaker in {span.speaker for span in audible}

        verdicts.append(
            UtteranceVerdict(
                index=index,
                start=utterance.start,
                end=utterance.end,
                label=utterance.text,
                truth=truth_text,
                iou=best_iou,
                label_wer=errors.rate,
                text_wer=text_errors.rate,
                speaker_correct=speaker_correct,
            )
        )

    ious = sorted(verdict.iou for verdict in verdicts)
    judged_speakers = [v.speaker_correct for v in verdicts if v.speaker_correct is not None]
    # Keyed on text_wer: a label that copies a real utterance correctly
    # but sits in a slightly wrong window is a boundary problem, not a
    # mislabelled example.
    grossly = sum(1 for verdict in verdicts if verdict.text_wer > GROSSLY_WRONG_WER)
    truth_seconds = sum(span.duration for span in truth)
    kept_seconds = sum(utterance.duration for utterance in utterances)

    return ValidationReport(
        document_id=document_id,
        utterances=len(verdicts),
        mean_iou=(sum(ious) / len(ious)) if ious else 0.0,
        median_iou=(ious[len(ious) // 2] if ious else 0.0),
        label_wer=(pooled_errors / pooled_length) if pooled_length else 0.0,
        text_wer=(pooled_text_errors / pooled_text_length) if pooled_text_length else 0.0,
        speaker_accuracy=(sum(judged_speakers) / len(judged_speakers) if judged_speakers else None),
        grossly_wrong=grossly,
        grossly_wrong_rate=(grossly / len(verdicts)) if verdicts else 0.0,
        truth_seconds=truth_seconds,
        kept_seconds=kept_seconds,
        coverage=(kept_seconds / truth_seconds) if truth_seconds > 0 else 0.0,
        verdicts=verdicts,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="align.validate")
    parser.add_argument("--truth", required=True, help="berkas *.truth.json")
    parser.add_argument("--shard", required=True, help="direktori shard dengan metadata.jsonl")
    parser.add_argument("--document-id", default=None)
    parser.add_argument("--json", default=None)
    args = parser.parse_args(argv)

    truth = load_truth(args.truth)
    metadata = Path(args.shard) / "metadata.jsonl"
    rows = [
        json.loads(line)
        for line in metadata.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    document_id = args.document_id or (rows[0].get("document_id", "") if rows else "")
    rows = [row for row in rows if not document_id or row.get("document_id") == document_id]

    utterances = [
        Utterance(
            text=row["sentence"],
            start=float(row["start"]),
            end=float(row["end"]),
            speaker=row.get("speaker") or None,
            role=row.get("role", ""),
            anchor_rate=float(row.get("anchor_rate") or 0.0),
            turn_index=-1,
            tokens=0,
        )
        for row in rows
    ]

    report = validate(utterances, truth, document_id=document_id)
    print(json.dumps(report.as_dict(), ensure_ascii=False, indent=2)[:4000])
    print()
    print(report.summary())
    if args.json:
        write_json(args.json, report.as_dict())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
