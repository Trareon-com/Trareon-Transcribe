"""Anchoring and time mapping.

The hypothesis is synthesised with known word times, so every assertion
here is against ground truth rather than against whatever the aligner
happened to produce.
"""

from __future__ import annotations

from itertools import pairwise

from align.hypothesis import HypWord, Segment, words_from_segments
from align.textalign import (
    MIN_ANCHOR_TOKENS,
    align_tokens,
    alignment_report,
    find_anchors,
)
from eval.normalize import tokenize


def hyp_from_text(text: str, *, wps: float = 3.0, start: float = 0.0) -> list[HypWord]:
    """Hypothesis words at a fixed rate, so times are known exactly."""
    words = text.split()
    step = 1.0 / wps
    return [
        HypWord(
            text=word,
            start=start + index * step,
            end=start + (index + 1) * step,
            segment_index=0,
        )
        for index, word in enumerate(words)
    ]


# -- word times from segments ------------------------------------------


def test_words_are_interpolated_across_a_segment() -> None:
    segments = [Segment(text="satu dua tiga", start=10.0, end=13.0)]
    words = words_from_segments(segments)
    assert [word.text for word in words] == ["satu", "dua", "tiga"]
    assert words[0].start == 10.0
    assert abs(words[-1].end - 13.0) < 1e-9
    # Monotonic and contiguous.
    for earlier, later in pairwise(words):
        assert abs(earlier.end - later.start) < 1e-9


def test_interpolation_is_by_character_length_not_word_count() -> None:
    """`di` and `mempertanggungjawabkan` are not the same duration."""
    words = words_from_segments([Segment(text="di mempertanggungjawabkan", start=0.0, end=10.0)])
    short, long = words
    assert short.end - short.start < long.end - long.start


def test_zero_duration_segment_contributes_nothing() -> None:
    assert words_from_segments([Segment(text="satu dua", start=5.0, end=5.0)]) == []


def test_empty_segment_contributes_nothing() -> None:
    assert words_from_segments([Segment(text="   ", start=0.0, end=3.0)]) == []


# -- anchors -----------------------------------------------------------


def test_identical_streams_anchor_completely() -> None:
    tokens = ["satu", "dua", "tiga", "empat", "lima", "enam"]
    anchors = find_anchors(tokens, tokens)
    assert len(anchors) == 1
    assert anchors[0].length == len(tokens)


def test_short_coincidental_match_is_not_an_anchor() -> None:
    reference = ["yang", "dan", "itu"]
    hypothesis = ["yang", "dan", "itu"]
    assert find_anchors(reference, hypothesis, min_length=MIN_ANCHOR_TOKENS) == []


def test_anchors_are_monotonic_and_non_overlapping() -> None:
    reference = ["aaa", "bbb", "ccc", "ddd", "eee", "fff", "ggg", "hhh", "iii", "jjj", "kkk", "lll"]
    hypothesis = [
        "aaa",
        "bbb",
        "ccc",
        "ddd",
        "xxx",
        "yyy",
        "ggg",
        "hhh",
        "iii",
        "jjj",
        "kkk",
        "lll",
    ]
    anchors = find_anchors(reference, hypothesis)
    assert len(anchors) >= 2
    for earlier, later in pairwise(anchors):
        assert earlier.ref_end <= later.ref_index
        assert earlier.hyp_end <= later.hyp_index


def test_common_function_words_are_not_junked_on_a_long_document() -> None:
    """The `autojunk=False` guard.

    SequenceMatcher's default junk heuristic discards any element in
    more than 1% of a sequence longer than 200 items. On a hearing that
    is `yang`, `dan`, `itu`, `tidak` — most of the matchable material —
    and anchoring silently collapses to almost nothing. This test fails
    loudly if the flag is ever dropped.
    """
    sentence = "anggaran yang diajukan itu tidak dapat kami setujui begitu saja"
    reference = (sentence + " ").strip().split() * 40  # 440 tokens
    hypothesis = list(reference)

    anchors = find_anchors(reference, hypothesis)
    assert anchors, "tidak ada anchor sama sekali - autojunk kemungkinan aktif"
    anchored = sum(anchor.length for anchor in anchors)
    # Identical streams: essentially everything should anchor.
    assert anchored / len(reference) > 0.95


def test_no_anchors_when_the_documents_are_unrelated() -> None:
    reference = ["sidang", "perkara", "pengujian", "undang", "undang", "pemilihan", "umum"]
    hypothesis = ["resep", "rendang", "daging", "sapi", "khas", "padang", "yang", "pedas"]
    assert find_anchors(reference, hypothesis) == []


def test_empty_input_yields_no_anchors() -> None:
    assert find_anchors([], ["satu"]) == []
    assert find_anchors(["satu"], []) == []


# -- time mapping ------------------------------------------------------


def test_anchored_tokens_take_their_time_from_the_hypothesis() -> None:
    text = "rapat komisi delapan dengan menteri agama tentang kuota haji nasional"
    reference = tokenize(text)
    hypothesis = hyp_from_text(text, wps=2.0)
    aligned = align_tokens(reference, hypothesis)

    assert aligned.anchor_rate > 0.9
    first = aligned.times[0]
    assert first is not None and first.anchored
    assert abs(first.start - 0.0) < 1e-6
    # 2 words per second, so the Nth word starts at N/2.
    third = aligned.times[2]
    assert third is not None and abs(third.start - 1.0) < 1e-6


def test_a_mishearing_between_anchors_is_interpolated_not_anchored() -> None:
    # Both ends must be at least MIN_ANCHOR_TOKENS long or there is no
    # second anchor to interpolate towards.
    reference = tokenize(
        "kuota haji tahun ini berjumlah jemaah dari seluruh indonesia bagian timur"
    )
    # The model mishears one word in the middle but gets both ends right.
    hypothesis = hyp_from_text(
        "kuota haji tahun ini berjumlah JEMAAHX dari seluruh indonesia bagian timur",
        wps=2.0,
    )
    aligned = align_tokens(reference, hypothesis)

    unanchored = [
        index for index, time in enumerate(aligned.times) if time is not None and not time.anchored
    ]
    assert unanchored, "token yang salah dengar seharusnya ter-interpolasi"
    # Interpolated times still sit between their neighbours.
    for index in unanchored:
        before, after = aligned.times[index - 1], aligned.times[index + 1]
        assert before is not None and after is not None
        assert before.end <= aligned.times[index].start + 1e-6  # type: ignore[union-attr]
        assert aligned.times[index].end <= after.start + 1e-6  # type: ignore[union-attr]


def test_text_before_the_first_anchor_gets_no_time() -> None:
    """The opening formula a risalah has and the audio does not.

    Extrapolating would invent timing for it, and that invented span
    would then be cut and labelled.
    """
    reference = tokenize(
        "assalamualaikum warahmatullahi wabarakatuh hadirin yang kami hormati "
        "kuota haji tahun ini berjumlah dua ratus ribu jemaah"
    )
    hypothesis = hyp_from_text("kuota haji tahun ini berjumlah dua ratus ribu jemaah", wps=2.0)
    aligned = align_tokens(reference, hypothesis)

    assert aligned.times[0] is None
    assert aligned.times[1] is None
    # ...and the part that does appear in the audio is anchored.
    assert any(time is not None and time.anchored for time in aligned.times)


def test_unrelated_documents_produce_no_times_at_all() -> None:
    """The wrong-session case.

    Alignment must not quietly produce a dataset from a recording joined
    to the wrong risalah.
    """
    reference = tokenize("sidang perkara pengujian undang undang pemilihan umum")
    hypothesis = hyp_from_text("resep rendang daging sapi khas padang yang pedas")
    aligned = align_tokens(reference, hypothesis)
    assert aligned.anchor_rate == 0.0
    assert all(time is None for time in aligned.times)


def test_number_conventions_do_not_break_anchoring() -> None:
    """The risalah writes digits; the model says words.

    Without normalisation on both sides this anchor would not exist.
    """
    reference = tokenize("sesuai dengan pasal 42 undang undang nomor 28 tahun 2014")
    hypothesis = hyp_from_text(
        "sesuai dengan pasal empat puluh dua undang undang nomor dua puluh delapan "
        "tahun dua ribu empat belas",
        wps=3.0,
    )
    aligned = align_tokens(reference, hypothesis)
    assert aligned.anchor_rate > 0.8


def test_one_hypothesis_word_expanding_to_several_tokens_keeps_time_order() -> None:
    # "42" normalises to three tokens; their times must stay inside the
    # original word's span and in order.
    reference = tokenize("pasal 42 berlaku")
    hypothesis = [
        HypWord(text="pasal", start=0.0, end=1.0, segment_index=0),
        HypWord(text="42", start=1.0, end=2.0, segment_index=0),
        HypWord(text="berlaku", start=2.0, end=3.0, segment_index=0),
    ]
    aligned = align_tokens(reference, hypothesis, min_anchor=2)
    times = [time for time in aligned.times if time is not None]
    assert times
    for earlier, later in pairwise(times):
        assert earlier.start <= later.start + 1e-9


# -- reporting ---------------------------------------------------------


def test_alignment_report_counts_what_it_says() -> None:
    text = "rapat komisi delapan dengan menteri agama tentang kuota haji nasional"
    aligned = align_tokens(tokenize(text), hyp_from_text(text))
    report = alignment_report(aligned)
    assert report["ref_tokens"] == len(aligned.tokens)
    assert report["anchored_tokens"] == aligned.anchored_count
    assert 0.0 <= report["anchor_rate"] <= 1.0
    assert report["longest_anchor"] >= MIN_ANCHOR_TOKENS


def test_span_returns_none_when_nothing_is_timed() -> None:
    aligned = align_tokens(tokenize("satu dua tiga empat"), [])
    assert aligned.span(0, 4) is None


def test_span_reports_the_enclosing_time_and_anchor_rate() -> None:
    text = "satu dua tiga empat lima enam tujuh delapan"
    aligned = align_tokens(tokenize(text), hyp_from_text(text, wps=1.0))
    span = aligned.span(0, 4)
    assert span is not None
    begin, finish, rate = span
    assert begin == 0.0
    assert abs(finish - 4.0) < 1e-6
    assert rate == 1.0
