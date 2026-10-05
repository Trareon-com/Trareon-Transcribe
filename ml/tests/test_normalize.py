"""Normalisation policy.

Each test names the convention difference it is there to absorb. A test
that only asserts the current output would let a policy change through
silently, which is the one thing a WER normaliser must not allow.
"""

from __future__ import annotations

import pytest

from eval.normalize import (
    ID_MEETING,
    MINIMAL,
    POLICY_VERSION,
    characters,
    normalize,
    preset,
    tokenize,
    with_glossary,
)

# -- MINIMAL: must keep matching rust_core's wer_bench ------------------


def test_minimal_casefolds_and_strips_punctuation() -> None:
    assert normalize("Rapat, Pasal 42.", MINIMAL) == "rapat pasal 42"


def test_minimal_keeps_intra_word_hyphen_as_one_word() -> None:
    # "undang-undang" is one Indonesian word; splitting it would invent
    # two errors out of one.
    assert tokenize("Undang-Undang", MINIMAL) == ["undang-undang"]


def test_minimal_keeps_intra_word_apostrophe() -> None:
    assert tokenize("do'a", MINIMAL) == ["do'a"]


def test_minimal_does_not_spell_numbers() -> None:
    # The whole point of the preset: comparable with already-published
    # figures, which left numbers alone.
    assert normalize("kuartal 4", MINIMAL) == "kuartal 4"


def test_minimal_drops_dash_that_is_not_inside_a_word() -> None:
    assert tokenize("rapat - selesai", MINIMAL) == ["rapat", "selesai"]


def test_minimal_collapses_whitespace() -> None:
    assert normalize("  rapat \t\n  komisi  ", MINIMAL) == "rapat komisi"


# -- ID_MEETING: numbers ------------------------------------------------


@pytest.mark.parametrize(
    ("written", "spoken"),
    [
        ("kuartal 4", "kuartal empat"),
        ("Pasal 42", "pasal empat puluh dua"),
        ("tahun 2024", "tahun dua ribu dua puluh empat"),
        ("ada 11 anggota", "ada sebelas anggota"),
        ("Rp 1.500", "rupiah seribu lima ratus"),
        ("naik 3,5 persen", "naik tiga koma lima persen"),
        ("rapat ke-4", "rapat keempat"),
    ],
)
def test_number_conventions_converge(written: str, spoken: str) -> None:
    """A risalah writes digits, an ASR says words. Both must agree."""
    assert normalize(written) == normalize(spoken)


def test_thousands_separator_is_not_a_sentence_dot() -> None:
    assert normalize("anggaran 1.500 miliar") == "anggaran seribu lima ratus miliar"


def test_sentence_dot_after_a_number_is_still_punctuation() -> None:
    assert normalize("lihat Pasal 42. Berikutnya") == "lihat pasal empat puluh dua berikutnya"


def test_percent_symbol_becomes_a_word() -> None:
    assert normalize("naik 5%") == normalize("naik lima persen")


def test_rupiah_symbol_glued_to_digits_is_separated() -> None:
    assert normalize("Rp5 miliar") == "rupiah lima miliar"


def test_long_digit_run_is_read_digit_by_digit() -> None:
    # A phone number is an identifier, not a quantity.
    assert normalize("telepon 081234567890") == (
        "telepon nol delapan satu dua tiga empat lima enam tujuh delapan sembilan nol"
    )


def test_leading_zero_marks_an_identifier() -> None:
    assert normalize("nomor 007") == "nomor nol nol tujuh"


def test_digits_glued_inside_a_token_are_still_spelled() -> None:
    # "covid-19" and "covid sembilan belas" must agree; the cost is that
    # an alphanumeric code splits into several tokens, which the WER
    # tests' fixtures have to account for.
    assert normalize("COVID-19") == normalize("covid sembilan belas")
    assert tokenize("P3K") == ["p", "tiga", "k"]


def test_number_word_variants_are_canonicalised() -> None:
    assert normalize("sejuta rupiah") == normalize("1 juta rupiah")
    assert normalize("5 milyar") == normalize("lima miliar")


# -- ID_MEETING: dates --------------------------------------------------


@pytest.mark.parametrize(
    ("written", "spoken"),
    [
        ("17/08/2024", "17 Agustus 2024"),
        ("17-08-2024", "tujuh belas agustus dua ribu dua puluh empat"),
        ("2024-08-17", "17 Agustus 2024"),
    ],
)
def test_numeric_dates_converge_on_the_spoken_form(written: str, spoken: str) -> None:
    assert normalize(written) == normalize(spoken)


def test_date_pass_leaves_an_impossible_month_to_the_number_pass() -> None:
    # 13 is not a month; treating it as one would invent a word.
    assert "januari" not in normalize("13/13/2024")


# -- ID_MEETING: shorthand and acronyms ---------------------------------


def test_written_shorthand_is_expanded() -> None:
    assert normalize("yg dimaksud dgn hal tsb") == "yang dimaksud dengan hal tersebut"


def test_dll_expands_to_several_tokens() -> None:
    assert tokenize("rapat dll") == ["rapat", "dan", "lain", "lain"]


def test_acronyms_are_not_expanded() -> None:
    # Nobody reads "DPR" as "dewan perwakilan rakyat"; expanding it
    # would invent three words.
    assert tokenize("DPR RI") == ["dpr", "ri"]


def test_acronym_dots_come_off_so_spellings_agree() -> None:
    assert normalize("A.P.B.N.") == normalize("APBN")
    assert normalize("U.U. 28/2014").startswith("uu ")


def test_ambiguous_shorthand_is_left_alone() -> None:
    # "dr" is both "dokter" and "dari"; guessing would be worse than
    # leaving the token as the model wrote it.
    assert "dari" not in tokenize("dr Siti")
    assert "nomor" not in tokenize("no comment")


def test_glossary_adds_project_specific_shorthand() -> None:
    config = with_glossary(ID_MEETING, {"RKAKL": "rencana kerja anggaran"})
    assert tokenize("dokumen RKAKL", config) == [
        "dokumen",
        "rencana",
        "kerja",
        "anggaran",
    ]


# -- ID_MEETING: fillers and non-speech ---------------------------------


def test_hesitation_sounds_are_dropped() -> None:
    # A risalah never writes them; an ASR always does. Counting them
    # measures a transcription convention.
    assert normalize("eh ehm jadi hmm begitu") == "jadi begitu"


def test_meaningful_short_words_are_not_dropped_as_fillers() -> None:
    # "ya" is yes, "nah" and "oh" carry meaning in a rapat.
    assert tokenize("ya nah oh begitu") == ["ya", "nah", "oh", "begitu"]


def test_bracketed_non_speech_tags_are_dropped() -> None:
    assert normalize("[Musik] selamat pagi <unk>") == "selamat pagi"


def test_round_brackets_keep_their_words() -> None:
    # A risalah uses them for real speech attributions.
    assert normalize("(Ketua rapat) silakan") == "ketua rapat silakan"


def test_hallucinated_sentence_is_not_silently_removed() -> None:
    """Not the normaliser's job.

    Deleting Whisper's "terima kasih telah menonton" here would hide a
    real failure from the WER instead of reporting it.
    """
    assert "menonton" in tokenize("terima kasih telah menonton")


# -- ID_MEETING: reduplication -----------------------------------------


def test_reduplication_hyphen_is_split_so_both_conventions_agree() -> None:
    assert tokenize("undang-undang") == ["undang", "undang"]
    assert normalize("undang-undang") == normalize("undang undang")


# -- general -----------------------------------------------------------


def test_curly_quotes_and_dashes_are_folded() -> None:
    assert normalize("rapat — “selesai”") == "rapat selesai"


def test_empty_input_is_empty_output_not_a_crash() -> None:
    assert tokenize("") == []
    assert normalize("") == ""
    assert tokenize("   ...   ") == []


def test_normalisation_is_idempotent() -> None:
    """Running the normaliser twice must not change the answer.

    The aligner normalises risalah text once at ingest and the harness
    normalises again at scoring; if the two passes disagreed, every
    aligned label would be scored against a different string than the
    one it was cut from.
    """
    for raw in [
        "Pasal 42 ayat (1) UU 28/2014",
        "Rp1.500,50 naik 5% pada 17/08/2024",
        "yg tsb di atas, dll.",
        "eh undang-undang [Musik]",
    ]:
        once = normalize(raw)
        assert normalize(once) == once, raw


def test_characters_exclude_spaces() -> None:
    # A merged word is already charged by WER; counting the missing
    # space again in CER double-counts one mistake.
    assert characters("ada 4") == list("adaempat")


def test_preset_lookup_rejects_a_typo_with_the_options() -> None:
    assert preset("minimal") is MINIMAL
    assert preset("id_meeting") is ID_MEETING
    with pytest.raises(KeyError, match="id_meeting"):
        preset("id-meeting")


def test_policy_version_is_recorded() -> None:
    # Published figures cite it; an unversioned policy is an
    # unreproducible number.
    assert POLICY_VERSION
