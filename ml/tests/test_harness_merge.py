"""Merging benchmark reports.

This exists because the first version of `merge_reports` silently
produced a table of zeros: it rebuilt every score from per-clip detail,
and the files being merged had been written before that detail was
emitted. A merge that loses the numbers it was given is worse than no
merge, because the output looks like a real table.
"""

from __future__ import annotations

import json

from eval.harness import BenchmarkResult, merge_reports, render_markdown, write_report
from eval.wer import ClipScore, SetScore, char_errors, word_errors


def _clip(reference: str, hypothesis: str, *, audio: float, elapsed: float) -> ClipScore:
    return ClipScore(
        clip=f"{reference[:6]}.wav",
        reference=reference,
        hypothesis=hypothesis,
        words=word_errors(reference, hypothesis),
        chars=char_errors(reference, hypothesis),
        audio_secs=audio,
        elapsed_secs=elapsed,
    )


def _report(tmp_path, name: str, scores: list[SetScore], **extra) -> str:
    result = BenchmarkResult(
        scores=scores,
        machine="mesin uji",
        commit="abc1234",
        created_at="2026-10-05T00:00:00+00:00",
        policy="id_meeting/id-norm-1",
        **extra,
    )
    path = tmp_path / name
    path.write_text(json.dumps(result.as_dict(), ensure_ascii=False), encoding="utf-8")
    return str(path)


def _score(model: str, test_set: str, clips: list[ClipScore]) -> SetScore:
    return SetScore(model=model, test_set=test_set, policy="id_meeting/id-norm-1", clips=clips)


def test_merging_preserves_the_numbers(tmp_path) -> None:
    original = _score(
        "tiny",
        "fleurs-id",
        [_clip("satu dua tiga", "satu dua empat", audio=10.0, elapsed=5.0)],
    )
    path = _report(tmp_path, "a.json", [original])

    merged = merge_reports([path])
    assert len(merged.scores) == 1
    recovered = merged.scores[0]
    assert recovered.words.total == original.words.total
    assert recovered.words.reference_length == original.words.reference_length
    assert abs(recovered.rtf - original.rtf) < 1e-6
    assert recovered.clip_count == 1


def test_a_report_without_clip_detail_still_merges(tmp_path) -> None:
    """The failure this module exists for.

    A file written before `clip_detail` was emitted has only aggregates,
    and a merge that rebuilds solely from per-clip data turns it into a
    table of zeros.
    """
    original = _score(
        "small",
        "fleurs-id",
        [_clip("satu dua tiga empat", "satu dua tiga lima", audio=20.0, elapsed=10.0)],
    )
    payload = BenchmarkResult(scores=[original], machine="m", policy="p").as_dict()
    for score in payload["scores"]:
        del score["clip_detail"]  # as an older file would be
    path = tmp_path / "old.json"
    path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

    merged = merge_reports([str(path)])
    recovered = merged.scores[0]
    assert recovered.from_report
    assert recovered.words.total == original.words.total
    assert recovered.words.reference_length == original.words.reference_length
    assert recovered.clip_count == 1
    assert abs(recovered.rtf - 2.0) < 1e-6
    assert recovered.words.rate > 0.0


def test_two_sets_from_two_runs_end_up_in_one_table(tmp_path) -> None:
    first = _report(
        tmp_path,
        "first.json",
        [_score("tiny", "fleurs-id", [_clip("satu dua", "satu dua", audio=4.0, elapsed=2.0)])],
    )
    second = _report(
        tmp_path,
        "second.json",
        [_score("tiny", "silence", [_clip("", "", audio=30.0, elapsed=1.0)])],
    )
    merged = merge_reports([first, second])
    assert {score.test_set for score in merged.scores} == {"fleurs-id", "silence"}


def test_a_later_file_replaces_rather_than_duplicates(tmp_path) -> None:
    old = _report(
        tmp_path,
        "old.json",
        [_score("tiny", "fleurs-id", [_clip("satu dua", "salah salah", audio=4.0, elapsed=2.0)])],
    )
    new = _report(
        tmp_path,
        "new.json",
        [_score("tiny", "fleurs-id", [_clip("satu dua", "satu dua", audio=4.0, elapsed=2.0)])],
    )
    merged = merge_reports([old, new])
    assert len(merged.scores) == 1
    assert merged.scores[0].words.total == 0  # the re-measurement won


def test_an_error_is_dropped_once_the_pair_has_a_score(tmp_path) -> None:
    failed = _report(
        tmp_path,
        "failed.json",
        [],
        errors=[{"test_set": "silence", "model": "tiny", "error": "manifes tidak sah"}],
    )
    fixed = _report(
        tmp_path,
        "fixed.json",
        [_score("tiny", "silence", [_clip("", "", audio=30.0, elapsed=1.0)])],
    )
    merged = merge_reports([failed, fixed])
    assert merged.errors == []
    assert len(merged.scores) == 1


def test_an_unfixed_error_is_carried_through(tmp_path) -> None:
    failed = _report(
        tmp_path,
        "failed.json",
        [],
        errors=[{"test_set": "gs2-id-test", "model": "tiny", "error": "terkunci"}],
    )
    merged = merge_reports([failed])
    assert len(merged.errors) == 1
    assert merged.errors[0]["error"] == "terkunci"


def test_provenance_comes_from_the_merged_files(tmp_path) -> None:
    path = _report(
        tmp_path,
        "a.json",
        [_score("tiny", "fleurs-id", [_clip("satu dua", "satu dua", audio=4.0, elapsed=2.0)])],
    )
    merged = merge_reports([path])
    assert merged.machine == "mesin uji"
    assert merged.commit == "abc1234"
    assert merged.policy == "id_meeting/id-norm-1"


def test_a_merged_report_renders_and_round_trips(tmp_path) -> None:
    from eval.harness import TestSet

    path = _report(
        tmp_path,
        "a.json",
        [
            _score(
                "tiny",
                "fleurs-id",
                [_clip("satu dua tiga", "satu dua empat", audio=10.0, elapsed=5.0)],
            )
        ],
    )
    merged = merge_reports([path])
    test_sets = [
        TestSet(
            name="fleurs-id",
            manifest=tmp_path / "manifest.tsv",
            domain="ucapan baca",
            speech_kind="baca",
        )
    ]
    markdown = render_markdown(merged, test_sets)
    assert "fleurs-id" in markdown
    assert "| tiny |" in markdown
    # The number must survive into the rendered table, not read 0.0%.
    assert "0.0%" not in markdown.split("| tiny |")[1].split("|")[1]

    write_report(
        merged,
        test_sets,
        markdown_path=tmp_path / "out.md",
        json_path=tmp_path / "out.json",
    )
    again = merge_reports([str(tmp_path / "out.json")])
    assert again.scores[0].words.total == merged.scores[0].words.total
