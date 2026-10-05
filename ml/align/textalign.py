"""Anchoring a risalah to an ASR hypothesis.

The problem: a risalah is near-verbatim but carries **no timestamps**,
and the ASR hypothesis has timestamps but the wrong words. Neither alone
is a training label. Together they are: take the risalah's words and the
hypothesis's clock.

The method is anchor-based, as the sprint brief specifies. Both token
streams are normalised through `eval/normalize.py` — so `Pasal 42` in the
risalah and `pasal empat puluh dua` from the model are the same tokens —
and `difflib.SequenceMatcher` finds the long exact matching runs between
them. Those runs are **anchors**: places where the model and the
official record agree word-for-word, which is strong evidence that the
clock and the text line up there. Reference words inside an anchor take
their time directly from the matched hypothesis word. Reference words
*between* anchors are interpolated between the surrounding anchors and
marked unanchored, and a stretch with too few anchors is dropped rather
than labelled.

Two decisions that matter more than they look:

* `autojunk=False`. `SequenceMatcher`'s default heuristic treats any
  element appearing in more than 1% of a sequence over 200 items long as
  junk. On a 10 000-token hearing that junks `yang`, `dan`, `itu`,
  `tidak` — the Indonesian function words that make up most of the
  matchable material — and anchoring quietly collapses. This is the
  single easiest way to get a pipeline that silently produces almost no
  data, so there is a test for it.
* Dropping beats guessing. An unanchored stretch is audio whose words we
  do not actually know the timing of; labelling it anyway produces
  training data that is confidently wrong, and no spot-check of the
  *alignment* would catch it because the alignment never claimed to be
  right there.
"""

from __future__ import annotations

import difflib
from dataclasses import dataclass
from itertools import pairwise

from align.hypothesis import HypWord
from eval.normalize import ID_MEETING, NormalizerConfig, tokenize

#: Shortest matching run accepted as an anchor. Three tokens of
#: Indonesian function words match by chance across a long document;
#: four content-bearing tokens in a row do not.
MIN_ANCHOR_TOKENS = 4


@dataclass(frozen=True)
class Anchor:
    """A run where reference and hypothesis agree exactly."""

    ref_index: int
    hyp_index: int
    length: int

    @property
    def ref_end(self) -> int:
        return self.ref_index + self.length

    @property
    def hyp_end(self) -> int:
        return self.hyp_index + self.length


@dataclass
class TokenTime:
    """When a reference token was (probably) spoken."""

    start: float
    end: float
    #: True when the token sat inside an anchor, so the time came
    #: straight from a word the model and the risalah agreed on.
    anchored: bool


@dataclass
class AlignedTokens:
    """A reference token stream with times attached."""

    tokens: list[str]
    times: list[TokenTime | None]
    anchors: list[Anchor]

    @property
    def anchored_count(self) -> int:
        return sum(1 for time in self.times if time is not None and time.anchored)

    @property
    def anchor_rate(self) -> float:
        """Fraction of reference tokens inside an anchor.

        The headline quality number for one document. A low rate means
        the hypothesis and the risalah are not the same session, or the
        audio is much shorter than the document.
        """
        return self.anchored_count / len(self.tokens) if self.tokens else 0.0

    def span(self, start: int, end: int) -> tuple[float, float, float] | None:
        """Time span and anchor rate for reference tokens `[start, end)`.

        Returns None when nothing in the range has a time at all.
        """
        times = [time for time in self.times[start:end] if time is not None]
        if not times:
            return None
        anchored = sum(1 for time in self.times[start:end] if time and time.anchored)
        total = max(1, end - start)
        return (
            min(time.start for time in times),
            max(time.end for time in times),
            anchored / total,
        )


def normalised_tokens(text: str, config: NormalizerConfig = ID_MEETING) -> list[str]:
    return tokenize(text, config)


def find_anchors(
    ref_tokens: list[str],
    hyp_tokens: list[str],
    *,
    min_length: int = MIN_ANCHOR_TOKENS,
) -> list[Anchor]:
    """Find monotonic, non-overlapping agreement runs.

    `autojunk=False` is load-bearing — see the module docstring.
    """
    if not ref_tokens or not hyp_tokens:
        return []
    matcher = difflib.SequenceMatcher(a=ref_tokens, b=hyp_tokens, autojunk=False)
    return [
        Anchor(ref_index=block.a, hyp_index=block.b, length=block.size)
        for block in matcher.get_matching_blocks()
        if block.size >= min_length
    ]


def align_tokens(
    ref_tokens: list[str],
    hyp_words: list[HypWord],
    *,
    min_anchor: int = MIN_ANCHOR_TOKENS,
    config: NormalizerConfig = ID_MEETING,
) -> AlignedTokens:
    """Attach times to `ref_tokens` using `hyp_words` as the clock.

    `hyp_words` carry the raw hypothesis text; they are normalised here
    so that the token streams being matched are directly comparable.
    One hypothesis word can normalise to several tokens (`Pasal 42` ->
    `pasal empat puluh dua`), so the mapping from normalised token index
    back to a time is kept explicitly rather than assumed to be 1:1.
    """
    hyp_tokens: list[str] = []
    hyp_times: list[tuple[float, float]] = []
    for word in hyp_words:
        pieces = tokenize(word.text, config)
        if not pieces:
            continue
        # Split the word's span evenly across the tokens it produced.
        count = len(pieces)
        step = (word.end - word.start) / count if count else 0.0
        for offset, piece in enumerate(pieces):
            hyp_tokens.append(piece)
            hyp_times.append((word.start + step * offset, word.start + step * (offset + 1)))

    anchors = find_anchors(ref_tokens, hyp_tokens, min_length=min_anchor)
    times: list[TokenTime | None] = [None] * len(ref_tokens)

    for anchor in anchors:
        for offset in range(anchor.length):
            start, end = hyp_times[anchor.hyp_index + offset]
            times[anchor.ref_index + offset] = TokenTime(start=start, end=end, anchored=True)

    _interpolate_gaps(times, anchors, ref_count=len(ref_tokens))
    return AlignedTokens(tokens=ref_tokens, times=times, anchors=anchors)


def _interpolate_gaps(
    times: list[TokenTime | None], anchors: list[Anchor], *, ref_count: int
) -> None:
    """Fill unanchored reference tokens by linear interpolation.

    Only *between* two anchors. Tokens before the first anchor or after
    the last are left without a time: there is no second point to
    interpolate towards, and extrapolating would invent timing for the
    document's opening and closing formulae — exactly the stretches a
    risalah carries and the audio often does not.
    """
    if not anchors:
        return
    for previous, following in pairwise(anchors):
        gap_start, gap_end = previous.ref_end, following.ref_index
        if gap_end <= gap_start:
            continue
        before = times[previous.ref_end - 1]
        after = times[following.ref_index]
        if before is None or after is None:
            continue
        span = after.start - before.end
        count = gap_end - gap_start
        if span <= 0 or count <= 0:
            # Non-monotonic or coincident anchors: leave the gap
            # untimed rather than emit a negative-length utterance.
            continue
        step = span / count
        for offset in range(count):
            start = before.end + step * offset
            times[gap_start + offset] = TokenTime(start=start, end=start + step, anchored=False)
    _ = ref_count  # kept for a clear signature; bounds come from `times`


def alignment_report(aligned: AlignedTokens) -> dict:
    """Numbers worth printing for one aligned document."""
    timed = sum(1 for time in aligned.times if time is not None)
    return {
        "ref_tokens": len(aligned.tokens),
        "anchors": len(aligned.anchors),
        "anchored_tokens": aligned.anchored_count,
        "anchor_rate": round(aligned.anchor_rate, 4),
        "timed_tokens": timed,
        "timed_rate": round(timed / len(aligned.tokens), 4) if aligned.tokens else 0.0,
        "longest_anchor": max((anchor.length for anchor in aligned.anchors), default=0),
    }
