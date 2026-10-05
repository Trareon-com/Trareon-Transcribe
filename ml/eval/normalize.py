"""Text normalisation for Indonesian WER.

`docs/WER-BENCH.md` in this repository makes an argument worth repeating
before any of this code runs:

> Deliberately **not** normalised: numbers (`12` vs `dua belas`) and
> abbreviations. Both are judgement calls that would make the harness
> flatter whichever model happens to share its convention, and a harness
> with a built-in preference is worse than no harness.

That is right about a *hidden* preference. The answer is not to avoid
normalising — a risalah writes "Pasal 42" and Whisper says "pasal empat
puluh dua", and scoring that as two errors measures orthography, not
transcription — but to make the preference **explicit, named, versioned
and applied identically to both sides**. Hence two presets:

* `MINIMAL` reproduces what `rust_core`'s `wer_bench` already does:
  case-fold, drop punctuation, collapse whitespace, keep intra-word
  hyphens and apostrophes. Use it to compare against numbers this
  repository has already published.
* `ID_MEETING` is the benchmark's scoring preset: `MINIMAL` plus dates,
  digits spelled out, written shorthand expanded, hesitation sounds
  dropped, and reduplication hyphens split.

Every benchmark result records which preset and which `POLICY_VERSION`
produced it. A WER figure without both is not reproducible.

Deliberate non-goals, because each would flatter one convention:

* **Acronyms are not expanded.** "DPR" stays "dpr"; nobody reads it as
  "dewan perwakilan rakyat", so expanding it would invent four words.
  Only the dots come off, so "A.P.B.N." and "APBN" agree.
* **Word order is never changed.** "Rp5 miliar" becomes "rupiah lima
  miliar" although a speaker says "lima miliar rupiah". Reordering
  needs to parse the phrase, and a parser's bugs would land in the WER.
* **Synonyms are not merged.** "tidak" and "nggak" stay different words.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field, replace

from eval.numbers_id import spell_decimal, spell_digit_string, spell_integer, spell_ordinal

#: Bump when a rule changes a score. Published figures cite it.
POLICY_VERSION = "id-norm-1"

MONTHS_ID = (
    "januari",
    "februari",
    "maret",
    "april",
    "mei",
    "juni",
    "juli",
    "agustus",
    "september",
    "oktober",
    "november",
    "desember",
)

#: Written shorthand → spoken words. Only entries with exactly one
#: reading in a meeting context. Ambiguous ones are listed in the
#: comment and deliberately absent: `dr` (dokter / dari), `no` (nomor /
#: English "no"), `an` (atas nama / the word "an").
SHORTHAND = {
    "yg": "yang",
    "dgn": "dengan",
    "dng": "dengan",
    "tsb": "tersebut",
    "dll": "dan lain lain",
    "dsb": "dan sebagainya",
    "dst": "dan seterusnya",
    "sbb": "sebagai berikut",
    "spt": "seperti",
    "tdk": "tidak",
    "utk": "untuk",
    "krn": "karena",
    "hrs": "harus",
    "sdh": "sudah",
    "blm": "belum",
    "bbrp": "beberapa",
    "kpd": "kepada",
    "ttg": "tentang",
    "thd": "terhadap",
    "sdr": "saudara",
    "bpk": "bapak",
    "yth": "yang terhormat",
    "pak": "pak",
    "rp": "rupiah",
}

#: Spelling variants of number words, canonicalised so that a model
#: writing "sejuta" is not charged an error against "satu juta".
NUMBER_VARIANTS = {
    "sejuta": "satu juta",
    "semilyar": "satu miliar",
    "milyar": "miliar",
    "milyard": "miliar",
    "bilyun": "triliun",
    "trilyun": "triliun",
    "prosen": "persen",
}

#: Hesitation sounds. Kept tight on purpose: `ya` (yes), `oh`, `nah` and
#: `gitu` all carry meaning in a rapat and are not in this set.
FILLERS = frozenset(
    {
        "eh",
        "ehm",
        "em",
        "emm",
        "hm",
        "hmm",
        "hmmm",
        "mm",
        "mmm",
        "aa",
        "aaa",
        "ee",
        "eee",
        "uh",
        "uhm",
        "um",
        "er",
        "mhm",
    }
)

_CURLY = {
    "‘": "'",
    "’": "'",
    "“": '"',
    "”": '"',
    "–": "-",
    "—": "-",
    "−": "-",
    " ": " ",
}

_RE_SQUARE = re.compile(r"\[[^\]]{0,80}\]")
_RE_ANGLE = re.compile(r"<[^>]{0,40}>")
_RE_DMY = re.compile(r"\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b")
_RE_YMD = re.compile(r"\b(\d{4})-(\d{1,2})-(\d{1,2})\b")
_RE_THOUSANDS = re.compile(r"\b(\d{1,3})((?:\.\d{3})+)\b")
_RE_DECIMAL = re.compile(r"\b(\d+),(\d+)\b")
_RE_ORDINAL = re.compile(r"\bke\s*-\s*(\d+)\b")
_RE_INTEGER = re.compile(r"\d+")
_RE_WS = re.compile(r"\s+")


@dataclass(frozen=True)
class NormalizerConfig:
    """What to do, stated one rule per field.

    `name` appears in benchmark output next to every score.
    """

    name: str
    casefold: bool = True
    #: Drop `[Musik]`, `<unk>` and friends — ASR non-speech tags.
    drop_bracketed: bool = False
    #: Numeric dates to spoken Indonesian.
    spell_dates: bool = False
    #: Digits to words. The big one.
    spell_numbers: bool = False
    #: `SHORTHAND` expansion and acronym dot-stripping.
    expand_shorthand: bool = False
    #: Remove `FILLERS`. A risalah never writes them; an ASR always does.
    drop_fillers: bool = False
    #: Split `undang-undang` into two tokens so that a model writing it
    #: with a space agrees. Applied to both sides, so no error is
    #: invented either way; see the module docstring.
    split_hyphens: bool = False
    #: Keep `'` inside a word (`MINIMAL` does, to match `wer_bench`).
    keep_apostrophes: bool = True
    extra_shorthand: dict[str, str] = field(default_factory=dict)


#: Reproduces `rust_core/src/bin/wer_bench.rs`.
MINIMAL = NormalizerConfig(name="minimal")

#: The scoring preset for the Indonesian Meeting ASR benchmark.
ID_MEETING = NormalizerConfig(
    name="id_meeting",
    drop_bracketed=True,
    spell_dates=True,
    spell_numbers=True,
    expand_shorthand=True,
    drop_fillers=True,
    split_hyphens=True,
    keep_apostrophes=False,
)

PRESETS = {preset.name: preset for preset in (MINIMAL, ID_MEETING)}


def _spell_month(number: int) -> str | None:
    return MONTHS_ID[number - 1] if 1 <= number <= 12 else None


def _dates(text: str) -> str:
    def dmy(match: re.Match[str]) -> str:
        day, month, year = (int(group) for group in match.groups())
        name = _spell_month(month)
        if name is None or not 1 <= day <= 31:
            return match.group(0)
        return f" {spell_integer(day)} {name} {spell_integer(year)} "

    def ymd(match: re.Match[str]) -> str:
        year, month, day = (int(group) for group in match.groups())
        name = _spell_month(month)
        if name is None or not 1 <= day <= 31:
            return match.group(0)
        return f" {spell_integer(day)} {name} {spell_integer(year)} "

    return _RE_DMY.sub(dmy, _RE_YMD.sub(ymd, text))


def _numbers(text: str) -> str:
    # Thousands separators first: "1.500" is fifteen hundred, and the
    # dot must go before sentence punctuation stripping turns it into
    # "1 500".
    text = _RE_THOUSANDS.sub(lambda m: m.group(1) + m.group(2).replace(".", ""), text)
    text = _RE_DECIMAL.sub(lambda m: f" {spell_decimal(m.group(1), m.group(2))} ", text)
    text = _RE_ORDINAL.sub(lambda m: f" {spell_ordinal(int(m.group(1)))} ", text)

    def integer(match: re.Match[str]) -> str:
        raw = match.group(0)
        # A leading zero or a very long run is an identifier, not a
        # quantity: phone numbers and perkara numbers are read digit by
        # digit, and spelling 081234567890 as a quantity is nonsense.
        if (raw.startswith("0") and len(raw) > 1) or len(raw) > 12:
            return f" {spell_digit_string(raw)} "
        return f" {spell_integer(int(raw))} "

    return _RE_INTEGER.sub(integer, text)


def _strip_acronym_dots(text: str) -> str:
    """`A.P.B.N.` → `apbn`, leaving sentence dots alone.

    A dot is part of an acronym when it sits between two single
    characters, which is what the lookaround pair below says.
    """
    return re.sub(r"(?<=\b\w)\.(?=\w\b)", "", text)


def _punctuation(text: str, config: NormalizerConfig) -> str:
    keep = "'" if config.keep_apostrophes else ""
    if config.split_hyphens:
        text = text.replace("-", " ")
        hyphen = ""
    else:
        hyphen = "-"
    allowed = re.escape(keep + hyphen)
    text = re.sub(rf"[^\w\s{allowed}]" if allowed else r"[^\w\s]", " ", text, flags=re.UNICODE)
    if hyphen:
        # A hyphen that is not between two word characters is a dash,
        # not part of a word.
        text = re.sub(r"(?<!\w)-|-(?!\w)", " ", text)
    if keep:
        text = re.sub(r"(?<!\w)'|'(?!\w)", " ", text)
    elif not config.keep_apostrophes:
        text = text.replace("'", "")
    return text


def normalize(text: str, config: NormalizerConfig = ID_MEETING) -> str:
    """Normalise `text` under `config`. Returns a space-joined string."""
    return " ".join(tokenize(text, config))


def tokenize(text: str, config: NormalizerConfig = ID_MEETING) -> list[str]:
    """Normalise `text` and return its tokens — what WER aligns over."""
    if not text:
        return []

    text = unicodedata.normalize("NFKC", text)
    for source, target in _CURLY.items():
        text = text.replace(source, target)

    if config.drop_bracketed:
        # Square and angle brackets only. Round brackets in a risalah
        # hold real words ("(Ketua rapat)"), so only the parentheses go.
        text = _RE_SQUARE.sub(" ", text)
        text = _RE_ANGLE.sub(" ", text)
    text = text.replace("(", " ").replace(")", " ")

    if config.casefold:
        text = text.casefold()

    if config.expand_shorthand:
        text = _strip_acronym_dots(text)
        text = text.replace("%", " persen ").replace("&", " dan ")
        # "Rp5" has no space; give the symbol one before the token pass.
        text = re.sub(r"\brp\.?\s*(?=\d)", " rp ", text)

    if config.spell_dates:
        text = _dates(text)
    if config.spell_numbers:
        text = _numbers(text)

    text = _punctuation(text, config)

    tokens: list[str] = []
    shorthand = {**SHORTHAND, **config.extra_shorthand} if config.expand_shorthand else {}
    for token in _RE_WS.split(text.strip()):
        if not token:
            continue
        if shorthand:
            expansion = shorthand.get(token)
            if expansion is not None:
                tokens.extend(expansion.split())
                continue
            token = NUMBER_VARIANTS.get(token, token)
            if " " in token:
                tokens.extend(token.split())
                continue
        if config.drop_fillers and token in FILLERS:
            continue
        tokens.append(token)
    return tokens


def characters(text: str, config: NormalizerConfig = ID_MEETING) -> list[str]:
    """Characters for CER — normalised tokens joined without spaces.

    Spaces are excluded rather than kept: a model that merges two words
    is already charged for it by WER, and counting the missing space
    again in CER double-counts one mistake.
    """
    return list("".join(tokenize(text, config)))


def preset(name: str) -> NormalizerConfig:
    """Look up a preset by name, with a useful error for a typo."""
    try:
        return PRESETS[name]
    except KeyError:
        raise KeyError(f"preset tidak dikenal: {name!r}; pilihan: {sorted(PRESETS)}") from None


def with_glossary(config: NormalizerConfig, terms: dict[str, str]) -> NormalizerConfig:
    """A preset that also rewrites project-specific shorthand.

    Used by the meeting test sets, where an organisation's own
    abbreviations ("RKAKL") are neither universal nor ambiguous.
    """
    merged = {**config.extra_shorthand, **{k.casefold(): v.casefold() for k, v in terms.items()}}
    return replace(config, extra_shorthand=merged)
