"""Spelling Indonesian numbers out in words.

The WER normaliser canonicalises digits *into words* rather than words
into digits, and this module is that direction. Generating is
deterministic; parsing "dua ribu dua puluh empat" back into 2024 needs a
grammar, and every bug in that grammar becomes a silent error in a
published WER figure.

Indonesian number words are regular with four irregularities worth
naming, because they are where a naive implementation goes wrong:

* 11 is ``sebelas``, not ``satu belas``; 12-19 are ``<n> belas``.
* 100 is ``seratus`` and 1000 ``seribu`` — ``se-`` replaces ``satu``.
  But 1 000 000 is ``satu juta``, *not* ``sejuta``, as the canonical
  form here (``sejuta`` is accepted and rewritten on input).
* Scale words are long-scale-free: ribu 10^3, juta 10^6, miliar 10^9,
  triliun 10^12. ``milyar`` and ``bilyun`` are accepted spellings.
* The decimal separator is a comma and reads as ``koma``, after which
  digits are read one at a time: 3,14 → ``tiga koma satu empat``.
"""

from __future__ import annotations

UNITS = (
    "nol",
    "satu",
    "dua",
    "tiga",
    "empat",
    "lima",
    "enam",
    "tujuh",
    "delapan",
    "sembilan",
)

#: 10^3k scale names, index = k.
SCALES = ("", "ribu", "juta", "miliar", "triliun", "kuadriliun")

#: Ordinals that are not ``ke`` + the cardinal.
IRREGULAR_ORDINALS = {1: "pertama"}


def spell_integer(value: int) -> str:
    """Spell a non-negative integer in Indonesian.

    Raises ValueError for negatives (the caller handles the sign, which
    in transcripts is a word like ``minus`` rather than ``-``) and for
    values past the largest scale name this module knows.
    """
    if value < 0:
        raise ValueError("spell_integer hanya untuk bilangan non-negatif")
    if value < 10:
        return UNITS[value]
    if value == 10:
        return "sepuluh"
    if value == 11:
        return "sebelas"
    if value < 20:
        return f"{UNITS[value % 10]} belas"
    if value < 100:
        tens, ones = divmod(value, 10)
        head = f"{UNITS[tens]} puluh"
        return head if ones == 0 else f"{head} {UNITS[ones]}"
    if value < 1000:
        hundreds, rest = divmod(value, 100)
        head = "seratus" if hundreds == 1 else f"{UNITS[hundreds]} ratus"
        return head if rest == 0 else f"{head} {spell_integer(rest)}"

    # Split into 10^3 groups and name each with its scale.
    groups: list[int] = []
    remaining = value
    while remaining > 0:
        remaining, group = divmod(remaining, 1000)
        groups.append(group)
    if len(groups) > len(SCALES):
        raise ValueError(f"bilangan {value} melampaui skala yang dikenal")

    parts: list[str] = []
    for index in range(len(groups) - 1, -1, -1):
        group = groups[index]
        if group == 0:
            continue
        scale = SCALES[index]
        if index == 1 and group == 1:
            parts.append("seribu")  # 1000, not "satu ribu"
        elif scale:
            parts.append(f"{spell_integer(group)} {scale}")
        else:
            parts.append(spell_integer(group))
    return " ".join(parts)


def spell_decimal(digits: str, fraction: str) -> str:
    """Spell ``<digits>,<fraction>`` — fraction read digit by digit."""
    head = spell_integer(int(digits)) if digits else "nol"
    tail = " ".join(UNITS[int(char)] for char in fraction if char.isdigit())
    return f"{head} koma {tail}" if tail else head


def spell_ordinal(value: int) -> str:
    """Spell ``ke-N``.

    ``ke-1`` becomes ``pertama``; everything else is ``ke`` prefixed to
    the cardinal with no space, as Indonesian writes it (``keempat``).
    """
    if value in IRREGULAR_ORDINALS:
        return IRREGULAR_ORDINALS[value]
    cardinal = spell_integer(value)
    # Multi-word cardinals keep their internal spaces: ke-21 is
    # "kedua puluh satu".
    return "ke" + cardinal


def spell_year(value: int) -> str:
    """Spell a year.

    Years are read as plain cardinals in Indonesian — 1945 is ``seribu
    sembilan ratus empat puluh lima``, not digit-pairs as in English.
    A separate function because that is a fact worth asserting in a test
    rather than an accident of `spell_integer`.
    """
    return spell_integer(value)


def spell_digit_string(text: str) -> str:
    """Read a digit run one digit at a time (phone numbers, codes)."""
    return " ".join(UNITS[int(char)] for char in text if char.isdigit())
