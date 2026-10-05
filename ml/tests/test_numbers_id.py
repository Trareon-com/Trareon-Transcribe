"""Indonesian number spelling.

The irregular forms get their own assertions, because they are what a
rewrite would break and a WER harness would then silently absorb.
"""

from __future__ import annotations

import pytest

from eval.numbers_id import (
    spell_decimal,
    spell_digit_string,
    spell_integer,
    spell_ordinal,
    spell_year,
)


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (0, "nol"),
        (1, "satu"),
        (4, "empat"),
        (9, "sembilan"),
        (10, "sepuluh"),
        # 11 is "sebelas", never "satu belas".
        (11, "sebelas"),
        (12, "dua belas"),
        (17, "tujuh belas"),
        (19, "sembilan belas"),
        (20, "dua puluh"),
        (21, "dua puluh satu"),
        (42, "empat puluh dua"),
        (90, "sembilan puluh"),
        (99, "sembilan puluh sembilan"),
        # "se-" replaces "satu" at hundreds and thousands.
        (100, "seratus"),
        (101, "seratus satu"),
        (115, "seratus lima belas"),
        (200, "dua ratus"),
        (250, "dua ratus lima puluh"),
        (999, "sembilan ratus sembilan puluh sembilan"),
        (1000, "seribu"),
        (1001, "seribu satu"),
        (1500, "seribu lima ratus"),
        (2000, "dua ribu"),
        (10000, "sepuluh ribu"),
        (11000, "sebelas ribu"),
        (100000, "seratus ribu"),
        # ...but not at millions: "satu juta", not "sejuta".
        (1_000_000, "satu juta"),
        (2_500_000, "dua juta lima ratus ribu"),
        (1_000_000_000, "satu miliar"),
        (1_500_000_000, "satu miliar lima ratus juta"),
        (1_000_000_000_000, "satu triliun"),
        # A zero group is skipped, not spelled.
        (1_000_005, "satu juta lima"),
        (2_000_300, "dua juta tiga ratus"),
    ],
)
def test_spell_integer(value: int, expected: str) -> None:
    assert spell_integer(value) == expected


def test_spell_integer_rejects_negative() -> None:
    with pytest.raises(ValueError, match="non-negatif"):
        spell_integer(-1)


def test_spell_integer_rejects_beyond_known_scales() -> None:
    with pytest.raises(ValueError, match="melampaui skala"):
        spell_integer(10**21)


@pytest.mark.parametrize(
    ("digits", "fraction", "expected"),
    [
        # Decimals read digit by digit after "koma" — not "empat belas".
        ("3", "14", "tiga koma satu empat"),
        ("0", "5", "nol koma lima"),
        ("12", "75", "dua belas koma tujuh lima"),
        ("100", "0", "seratus koma nol"),
    ],
)
def test_spell_decimal(digits: str, fraction: str, expected: str) -> None:
    assert spell_decimal(digits, fraction) == expected


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (1, "pertama"),
        (2, "kedua"),
        (3, "ketiga"),
        (4, "keempat"),
        (11, "kesebelas"),
        (21, "kedua puluh satu"),
    ],
)
def test_spell_ordinal(value: int, expected: str) -> None:
    assert spell_ordinal(value) == expected


def test_years_read_as_cardinals_not_digit_pairs() -> None:
    # English says "nineteen forty-five"; Indonesian does not.
    assert spell_year(1945) == "seribu sembilan ratus empat puluh lima"
    assert spell_year(2024) == "dua ribu dua puluh empat"


def test_spell_digit_string_reads_one_at_a_time() -> None:
    assert spell_digit_string("0812") == "nol delapan satu dua"
