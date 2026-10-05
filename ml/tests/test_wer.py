"""WER/CER arithmetic, including the cases that make a harness lie."""

from __future__ import annotations

from eval.normalize import MINIMAL
from eval.wer import ClipScore, Errors, SetScore, char_errors, edit_counts, pooled, word_errors


def test_identical_sequences_have_no_errors() -> None:
    counts = edit_counts(["a", "b", "c"], ["a", "b", "c"])
    assert counts.total == 0
    assert counts.rate == 0.0


def test_one_substitution() -> None:
    counts = edit_counts(["a", "b"], ["a", "x"])
    assert (counts.substitutions, counts.deletions, counts.insertions) == (1, 0, 0)


def test_mishearing_is_one_substitution_not_a_delete_plus_insert() -> None:
    """The tie-break that keeps the count honest.

    Levenshtein cost is 1 either way, so the backtrace must prefer
    substitution; reporting a delete *and* an insert would double the
    error count for a single mishearing.
    """
    counts = edit_counts(["rapat", "komisi"], ["rapat", "komisih"])
    assert counts.total == 1
    assert counts.substitutions == 1


def test_deletion_and_insertion_are_distinguished() -> None:
    assert edit_counts(["a", "b", "c"], ["a", "c"]).deletions == 1
    assert edit_counts(["a", "c"], ["a", "b", "c"]).insertions == 1


def test_empty_hypothesis_deletes_every_reference_token() -> None:
    counts = edit_counts(["a", "b", "c"], [])
    assert counts.deletions == 3
    assert counts.rate == 1.0


def test_empty_reference_with_output_is_rate_one_per_token_not_a_crash() -> None:
    counts = edit_counts([], ["halo", "halo"])
    assert counts.insertions == 2
    assert counts.rate == 1.0


def test_silence_transcribed_as_silence_scores_zero_not_nan() -> None:
    """A silent clip must not poison the pooled rate.

    This is the hallucination test set's whole premise: an empty
    reference with an empty hypothesis is a pass.
    """
    counts = edit_counts([], [])
    assert counts.rate == 0.0
    assert counts.total == 0


def test_errors_add_componentwise() -> None:
    total = Errors(1, 2, 3, 10) + Errors(1, 1, 1, 5)
    assert (total.substitutions, total.deletions, total.insertions) == (2, 3, 4)
    assert total.reference_length == 15
    assert total.rate == 9 / 15


def test_word_errors_applies_the_normaliser_to_both_sides() -> None:
    # Digits on one side, words on the other: zero errors under the
    # meeting preset, errors under the minimal one.
    assert word_errors("kuartal 4", "kuartal empat").total == 0
    assert word_errors("kuartal 4", "kuartal empat", MINIMAL).total == 1


def test_char_errors_are_finer_than_word_errors() -> None:
    """Indonesian affixation makes WER brutal; CER says how near."""
    words = word_errors("mempertanggungjawabkan", "mempertanggungjawabhan")
    chars = char_errors("mempertanggungjawabkan", "mempertanggungjawabhan")
    assert words.rate == 1.0  # one word, entirely wrong
    assert 0.0 < chars.rate < 0.1  # one character out of twenty-two


def _clip(reference: str, hypothesis: str, *, audio: float, elapsed: float) -> ClipScore:
    return ClipScore(
        clip=reference[:8],
        reference=reference,
        hypothesis=hypothesis,
        words=word_errors(reference, hypothesis),
        chars=char_errors(reference, hypothesis),
        audio_secs=audio,
        elapsed_secs=elapsed,
    )


def test_set_rate_is_pooled_not_averaged() -> None:
    """The bug this guards against reports the worse model as better.

    A four-word clip with one error (25%) and a forty-word clip with
    four (10%): the mean of the rates is 17.5%, but 5 errors over 44
    reference words is 11.4%. Averaging rates would weight the short
    clip ten times too heavily.
    """
    short = _clip("satu dua tiga empat", "satu dua tiga lima", audio=2.0, elapsed=1.0)
    # Alphabetic filler only: a digit inside a token would be spelled
    # out and the token count would stop being the one under test.
    stems = [f"kata{chr(ord('a') + index)}" for index in range(40)]
    long_reference = " ".join(stems)
    long_hypothesis = " ".join(
        ("salah" + stem if index < 4 else stem) for index, stem in enumerate(stems)
    )
    long = _clip(long_reference, long_hypothesis, audio=20.0, elapsed=10.0)

    score = SetScore(model="m", test_set="t", policy="id-norm-1", clips=[short, long])
    assert score.words.reference_length == 44
    assert score.words.total == 5
    assert abs(score.words.rate - 5 / 44) < 1e-9

    mean_of_rates = (short.words.rate + long.words.rate) / 2
    assert abs(mean_of_rates - 0.175) < 1e-9
    assert score.words.rate < mean_of_rates


def test_failed_clip_counts_as_a_total_loss_not_a_skip() -> None:
    """A model that cannot decode a file has not scored 0% on it."""
    good = _clip("satu dua", "satu dua", audio=2.0, elapsed=1.0)
    broken = ClipScore(
        clip="broken.wav",
        reference="tiga empat",
        hypothesis="",
        words=word_errors("tiga empat", ""),
        chars=char_errors("tiga empat", ""),
        audio_secs=0.0,
        elapsed_secs=0.5,
        failed=True,
    )
    score = SetScore(model="m", test_set="t", policy="p", clips=[good, broken])
    assert score.failures == 1
    assert score.words.total == 2
    assert abs(score.words.rate - 0.5) < 1e-9


def test_rtf_is_audio_over_wall_clock() -> None:
    clip = _clip("satu", "satu", audio=30.0, elapsed=10.0)
    assert clip.rtf == 3.0
    score = SetScore(model="m", test_set="t", policy="p", clips=[clip])
    assert score.rtf == 3.0


def test_rtf_of_a_zero_length_run_is_zero_not_a_division_by_zero() -> None:
    clip = _clip("satu", "satu", audio=0.0, elapsed=0.0)
    assert clip.rtf == 0.0


def test_set_score_dict_carries_the_policy_for_reproducibility() -> None:
    score = SetScore(
        model="ggml-tiny",
        test_set="fleurs-id",
        policy="id-norm-1",
        clips=[_clip("satu dua", "satu dua", audio=2.0, elapsed=1.0)],
    )
    payload = score.as_dict()
    assert payload["policy"] == "id-norm-1"
    assert payload["model"] == "ggml-tiny"
    assert payload["clips"] == 1
    assert payload["wer"] == 0.0


def test_pooled_sums_across_sets() -> None:
    first = SetScore(
        model="m",
        test_set="a",
        policy="p",
        clips=[_clip("satu dua", "satu tiga", audio=2.0, elapsed=1.0)],
    )
    second = SetScore(
        model="m",
        test_set="b",
        policy="p",
        clips=[_clip("empat lima", "empat lima", audio=2.0, elapsed=1.0)],
    )
    total = pooled([first, second])
    assert total.reference_length == 4
    assert total.total == 1
