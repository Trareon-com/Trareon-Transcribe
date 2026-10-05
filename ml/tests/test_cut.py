"""Cutting utterances, and refusing to.

Every gate in `CutConfig` has a test that it actually rejects, because
each one exists to keep a specific kind of confidently-wrong training
example out of the dataset.
"""

from __future__ import annotations

from align.cut import CutConfig, cut_risalah
from collect.risalah import Risalah, Turn
from tests.test_textalign import hyp_from_text


def _risalah(*turns: tuple[str, str | None, str]) -> Risalah:
    return Risalah(
        turns=[
            Turn(label=role.upper(), role=role, speaker=speaker, text=text, index=index + 1)
            for index, (role, speaker, text) in enumerate(turns)
        ],
        source="uji",
    )


# Ten words at 2 wps = 5 s, comfortably inside the 2–25 s window.
SENTENCE = "kuota haji tahun ini berjumlah dua ratus ribu jemaah nasional"


def test_a_clean_turn_is_cut_and_labelled_with_the_risalah_text() -> None:
    risalah = _risalah(("ketua rapat", "ASHABUL KAHFI", SENTENCE + "."))
    result = cut_risalah(risalah, hyp_from_text(SENTENCE, wps=2.0))

    assert result.stats.kept == 1
    utterance = result.utterances[0]
    # The label is the risalah's words, not the model's.
    assert utterance.text.startswith("kuota haji")
    assert utterance.speaker == "ASHABUL KAHFI"
    assert utterance.role == "ketua rapat"
    assert 2.0 <= utterance.duration <= 25.0
    assert utterance.anchor_rate > 0.9


def test_the_label_is_the_risalah_not_the_hypothesis() -> None:
    """The entire point of the pipeline.

    The model mishears a word; the label must still be the official
    record's word.
    """
    risalah = _risalah(("ketua", None, SENTENCE + "."))
    misheard = SENTENCE.replace("berjumlah", "berjumpa")
    result = cut_risalah(risalah, hyp_from_text(misheard, wps=2.0))
    assert result.stats.kept == 1
    assert "berjumlah" in result.utterances[0].text
    assert "berjumpa" not in result.utterances[0].text


def test_an_utterance_shorter_than_two_seconds_is_dropped() -> None:
    short = "baik terima kasih pak"
    risalah = _risalah(("ketua", None, short + "."))
    # 20 words per second: four words in 0.2 s.
    result = cut_risalah(risalah, hyp_from_text(short, wps=20.0))
    assert result.stats.kept == 0
    assert result.stats.dropped_too_short == 1


def test_an_utterance_longer_than_the_ceiling_is_split_not_dropped() -> None:
    """The longest fluent stretches are the most valuable material."""
    long_sentence = " ".join([SENTENCE] * 6)  # 60 words
    risalah = _risalah(("ketua", None, long_sentence))
    result = cut_risalah(risalah, hyp_from_text(long_sentence, wps=2.0))

    assert result.stats.kept >= 2
    assert all(utterance.duration <= 25.0 for utterance in result.utterances)
    assert result.stats.dropped_too_long == 0


def test_low_anchor_rate_is_dropped_rather_than_labelled() -> None:
    """The gate that keeps mislabelled audio out.

    The risalah says one thing, the audio says another; the span has a
    plausible duration and would otherwise pass.
    """
    risalah = _risalah(("ketua", None, SENTENCE + "."))
    unrelated = "resep rendang daging sapi khas padang yang pedas sekali nian"
    result = cut_risalah(risalah, hyp_from_text(unrelated, wps=2.0))
    assert result.stats.kept == 0


def test_an_implausible_speaking_rate_is_dropped() -> None:
    """A duration check alone would pass this.

    Forty words inside three seconds is an alignment failure wearing a
    legal duration.
    """
    words = " ".join(f"kata{chr(ord('a') + index)}" for index in range(40))
    risalah = _risalah(("ketua", None, words))
    # Anchors everywhere, but the clock says 3 s for 40 words.
    hypothesis = hyp_from_text(words, wps=40.0 / 3.0)
    result = cut_risalah(risalah, hyp_from_text(words, wps=40.0 / 3.0))
    assert hypothesis  # the fixture really does cover the words
    assert result.stats.kept == 0
    assert result.stats.dropped_bad_rate >= 1


def test_text_with_no_matching_audio_is_dropped_for_lack_of_time() -> None:
    risalah = _risalah(("ketua", None, SENTENCE + "."))
    result = cut_risalah(risalah, [])
    assert result.stats.kept == 0
    assert result.stats.dropped_no_time >= 1


def test_a_cut_never_crosses_a_speaker_turn() -> None:
    """Otherwise the utterance would carry the wrong speaker label."""
    first = "kuota haji tahun ini berjumlah dua ratus ribu jemaah nasional"
    second = "terima kasih pimpinan atas penjelasan yang sangat lengkap tadi"
    risalah = _risalah(
        ("ketua rapat", "KETUA", first + "."),
        ("f-pkb", "ANGGOTA", second + "."),
    )
    result = cut_risalah(risalah, hyp_from_text(f"{first} {second}", wps=2.0))

    assert result.stats.kept == 2
    speakers = {utterance.speaker for utterance in result.utterances}
    assert speakers == {"KETUA", "ANGGOTA"}
    for utterance in result.utterances:
        if utterance.speaker == "KETUA":
            assert "terima kasih pimpinan" not in utterance.text
        else:
            assert "kuota haji" not in utterance.text


def test_utterances_come_back_in_time_order() -> None:
    first = "kuota haji tahun ini berjumlah dua ratus ribu jemaah nasional"
    second = "terima kasih pimpinan atas penjelasan yang sangat lengkap tadi"
    risalah = _risalah(("a", None, first + "."), ("b", None, second + "."))
    result = cut_risalah(risalah, hyp_from_text(f"{first} {second}", wps=2.0))
    starts = [utterance.start for utterance in result.utterances]
    assert starts == sorted(starts)


def test_sentences_are_packed_up_to_the_ceiling() -> None:
    """An utterance should be whole sentences where the turn allows."""
    sentences = ". ".join([SENTENCE] * 3) + "."
    risalah = _risalah(("ketua", None, sentences))
    result = cut_risalah(risalah, hyp_from_text(" ".join([SENTENCE] * 3), wps=2.0))
    assert result.stats.kept >= 1
    # 3 x 5 s = 15 s fits under 25 s, so it should be one utterance.
    assert result.stats.kept == 1
    assert result.utterances[0].duration <= 25.0


def test_too_few_tokens_is_dropped_even_with_a_good_duration() -> None:
    # Five tokens: enough to anchor (so it has a time and a legal
    # duration) but below this config's floor for a useful example.
    config = CutConfig(min_tokens=6)
    short = "kuota haji tahun ini berjumlah"
    risalah = _risalah(("ketua", None, short + "."))
    result = cut_risalah(risalah, hyp_from_text(short, wps=1.0), config=config)
    assert result.stats.kept == 0
    assert result.stats.dropped_few_tokens >= 1


def test_a_turn_too_short_to_anchor_is_dropped_for_lack_of_time() -> None:
    """Below the anchor minimum there is no clock at all.

    Two tokens cannot form an anchor, so the span has no time and is
    rejected before any duration or token gate is consulted.
    """
    risalah = _risalah(("ketua", None, "baik lanjut."))
    result = cut_risalah(risalah, hyp_from_text("baik lanjut", wps=0.5))
    assert result.stats.kept == 0
    assert result.stats.dropped_no_time == 1


def test_stats_account_for_every_candidate() -> None:
    """A dataset's hours have to be explainable.

    kept + dropped must equal candidates, or the report's "hours in ->
    hours kept" is not a real accounting.
    """
    risalah = _risalah(
        ("a", None, SENTENCE + "."),
        ("b", None, "baik."),
        ("c", None, "resep rendang daging sapi khas padang yang pedas sekali nian."),
    )
    result = cut_risalah(risalah, hyp_from_text(SENTENCE, wps=2.0))
    stats = result.stats
    dropped = (
        stats.dropped_too_short
        + stats.dropped_too_long
        + stats.dropped_low_anchor
        + stats.dropped_bad_rate
        + stats.dropped_no_time
        + stats.dropped_few_tokens
    )
    assert stats.kept + dropped == stats.candidates


def test_stats_hours_kept_matches_the_utterances() -> None:
    risalah = _risalah(("ketua", None, SENTENCE + "."))
    result = cut_risalah(risalah, hyp_from_text(SENTENCE, wps=2.0))
    total = sum(utterance.duration for utterance in result.utterances)
    assert abs(result.stats.seconds_kept - total) < 1e-6
    assert result.stats.as_dict()["hours_kept"] == round(total / 3600.0, 4)


def test_an_empty_risalah_yields_nothing_and_does_not_crash() -> None:
    result = cut_risalah(Risalah(), hyp_from_text(SENTENCE))
    assert result.utterances == []
    assert result.stats.kept == 0


def test_turn_reports_cover_every_turn_with_text() -> None:
    risalah = _risalah(("a", None, SENTENCE + "."), ("b", None, "baik lanjutkan saja."))
    result = cut_risalah(risalah, hyp_from_text(SENTENCE, wps=2.0))
    assert len(result.turn_reports) == 2
    assert all("anchor_rate" in report for report in result.turn_reports)
