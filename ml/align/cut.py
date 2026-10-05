"""Cutting aligned risalah text into training utterances.

Each utterance has to satisfy all of:

* **2–25 seconds.** Below two seconds a Whisper training example is
  mostly padding; above 25 the clip approaches the 30-second window and
  the sprint's training configs cap clips at 25 s.
* **Enough anchors.** `min_anchor_rate` of its reference tokens must sit
  inside an agreement run. This is the gate that keeps confidently
  mislabelled audio out of the dataset.
* **A plausible speaking rate.** Between `min_wps` and `max_wps` words
  per second. A span that claims 40 words in 3 seconds is an alignment
  failure wearing a plausible duration, and the duration check alone
  would pass it.
* **One speaker.** Cuts never cross a risalah turn boundary, so the
  speaker label is always the turn's own.

Cuts are made at sentence boundaries inside a turn, then greedily
packed up to the duration ceiling, so an utterance is a whole number of
sentences wherever the turn allows it. A single sentence longer than the
ceiling is split at token level rather than dropped.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from align.textalign import AlignedTokens, align_tokens
from collect.risalah import Risalah, Turn
from eval.normalize import ID_MEETING, NormalizerConfig, tokenize

_RE_SENTENCE = re.compile(r"(?<=[.!?])\s+")


@dataclass(frozen=True)
class CutConfig:
    min_secs: float = 2.0
    max_secs: float = 25.0
    #: Fraction of an utterance's tokens that must be anchored.
    min_anchor_rate: float = 0.6
    #: Words per second. Indonesian meeting speech sits around 2–4.
    min_wps: float = 1.0
    max_wps: float = 6.0
    #: Shortest utterance in tokens. A three-word label teaches little
    #: and its anchor rate is noise.
    min_tokens: int = 4


@dataclass
class Utterance:
    """One training example: audio span plus the risalah's own words."""

    #: Risalah text, verbatim — the label. Not the hypothesis.
    text: str
    start: float
    end: float
    speaker: str | None
    role: str
    anchor_rate: float
    turn_index: int
    #: Normalised token count, for the speaking-rate check and reporting.
    tokens: int

    @property
    def duration(self) -> float:
        return self.end - self.start

    @property
    def words_per_second(self) -> float:
        return self.tokens / self.duration if self.duration > 0 else 0.0


@dataclass
class CutStats:
    """Why utterances were dropped. The pipeline's quality report."""

    turns_seen: int = 0
    candidates: int = 0
    kept: int = 0
    dropped_too_short: int = 0
    dropped_too_long: int = 0
    dropped_low_anchor: int = 0
    dropped_bad_rate: int = 0
    dropped_no_time: int = 0
    dropped_few_tokens: int = 0
    seconds_kept: float = 0.0

    def as_dict(self) -> dict:
        return {
            "turns_seen": self.turns_seen,
            "candidates": self.candidates,
            "kept": self.kept,
            "hours_kept": round(self.seconds_kept / 3600.0, 4),
            "dropped": {
                "tanpa_waktu": self.dropped_no_time,
                "terlalu_pendek": self.dropped_too_short,
                "terlalu_panjang": self.dropped_too_long,
                "anchor_rendah": self.dropped_low_anchor,
                "laju_bicara_tak_wajar": self.dropped_bad_rate,
                "token_terlalu_sedikit": self.dropped_few_tokens,
            },
        }


@dataclass
class CutResult:
    utterances: list[Utterance] = field(default_factory=list)
    stats: CutStats = field(default_factory=CutStats)
    #: Per-turn alignment detail, for debugging a bad document.
    turn_reports: list[dict] = field(default_factory=list)


def _sentences(text: str) -> list[str]:
    parts = [part.strip() for part in _RE_SENTENCE.split(text) if part.strip()]
    return parts or ([text.strip()] if text.strip() else [])


def cut_turn(
    turn: Turn,
    turn_index: int,
    aligned: AlignedTokens,
    offset: int,
    config: CutConfig,
    stats: CutStats,
) -> list[Utterance]:
    """Cut one risalah turn into utterances.

    `offset` is where this turn's tokens start inside `aligned`, because
    the document is aligned as a whole — a turn aligned in isolation
    would have to guess which part of the audio it belongs to.
    """
    kept: list[Utterance] = []
    cursor = offset

    # Group the turn's sentences into candidate spans under the ceiling.
    pending: list[tuple[int, int, str]] = []  # (start, end, text)
    for sentence in _sentences(turn.text):
        length = len(tokenize(sentence))
        if length == 0:
            continue
        start, end = cursor, cursor + length
        cursor = end
        pending.append((start, end, sentence))

    groups = _pack(pending, aligned, config)
    for start, end, text in groups:
        stats.candidates += 1
        span = aligned.span(start, end)
        if span is None:
            stats.dropped_no_time += 1
            continue
        begin, finish, anchor_rate = span
        token_count = end - start

        if token_count < config.min_tokens:
            stats.dropped_few_tokens += 1
            continue
        duration = finish - begin
        if duration < config.min_secs:
            stats.dropped_too_short += 1
            continue
        if duration > config.max_secs:
            stats.dropped_too_long += 1
            continue
        if anchor_rate < config.min_anchor_rate:
            stats.dropped_low_anchor += 1
            continue
        rate = token_count / duration
        if not config.min_wps <= rate <= config.max_wps:
            stats.dropped_bad_rate += 1
            continue

        kept.append(
            Utterance(
                text=text,
                start=begin,
                end=finish,
                speaker=turn.speaker,
                role=turn.role,
                anchor_rate=anchor_rate,
                turn_index=turn_index,
                tokens=token_count,
            )
        )
        stats.kept += 1
        stats.seconds_kept += duration
    return kept


def _pack(
    sentences: list[tuple[int, int, str]],
    aligned: AlignedTokens,
    config: CutConfig,
) -> list[tuple[int, int, str]]:
    """Greedily pack sentences into spans under the duration ceiling.

    A single sentence that is itself too long is split at token level:
    dropping it would discard the longest, most fluent stretches of a
    hearing, which are the most valuable training material.
    """
    groups: list[tuple[int, int, str]] = []
    current: list[tuple[int, int, str]] = []

    def flush() -> None:
        if not current:
            return
        start, end = current[0][0], current[-1][1]
        groups.append((start, end, " ".join(part[2] for part in current)))
        current.clear()

    for start, end, text in sentences:
        span = aligned.span(start, end)
        own_duration = (span[1] - span[0]) if span else 0.0
        if span and own_duration > config.max_secs:
            flush()
            groups.extend(_split_long(start, end, text, aligned, config))
            continue

        candidate = [*current, (start, end, text)]
        candidate_span = aligned.span(candidate[0][0], candidate[-1][1])
        if current and candidate_span and (candidate_span[1] - candidate_span[0]) > config.max_secs:
            flush()
        current.append((start, end, text))
    flush()
    return groups


def _split_long(
    start: int,
    end: int,
    text: str,
    aligned: AlignedTokens,
    config: CutConfig,
) -> list[tuple[int, int, str]]:
    """Split one over-long sentence into token-level chunks.

    The text is re-split by whitespace in proportion to the token
    boundaries. Approximate — a word can normalise to several tokens —
    so the chunk text is taken from the raw words rather than the
    normalised stream, which keeps the label verbatim.
    """
    words = text.split()
    total_tokens = end - start
    if total_tokens <= 0 or not words:
        return []

    chunks: list[tuple[int, int, str]] = []
    cursor = start
    word_cursor = 0
    while cursor < end and word_cursor < len(words):
        # Grow the chunk until it reaches the ceiling.
        chunk_end = cursor
        while chunk_end < end:
            span = aligned.span(cursor, chunk_end + 1)
            if span and (span[1] - span[0]) > config.max_secs:
                break
            chunk_end += 1
        chunk_end = max(chunk_end, cursor + 1)
        token_share = (chunk_end - cursor) / total_tokens
        word_count = max(1, round(token_share * len(words)))
        chunk_words = words[word_cursor : word_cursor + word_count]
        if not chunk_words:
            break
        chunks.append((cursor, chunk_end, " ".join(chunk_words)))
        cursor = chunk_end
        word_cursor += word_count
    return chunks


def cut_risalah(
    risalah: Risalah,
    hyp_words: list,
    *,
    config: CutConfig | None = None,
    normalizer: NormalizerConfig = ID_MEETING,
) -> CutResult:
    """Align a whole risalah to a hypothesis and cut it into utterances.

    The document is aligned once, as a whole, and each turn is then cut
    within its own token range. Aligning turn by turn would let an early
    turn's text match a late part of the audio.
    """
    config = config or CutConfig()
    result = CutResult()

    # Token stream for the whole document, remembering where each turn
    # begins so a cut can be attributed to its speaker.
    turn_ranges: list[tuple[Turn, int, int]] = []
    all_tokens: list[str] = []
    for turn in risalah.turns:
        tokens = tokenize(turn.text, normalizer)
        if not tokens:
            continue
        turn_ranges.append((turn, len(all_tokens), len(all_tokens) + len(tokens)))
        all_tokens.extend(tokens)

    if not all_tokens:
        return result

    aligned = align_tokens(all_tokens, hyp_words, config=normalizer)
    result.stats.turns_seen = len(turn_ranges)

    for index, (turn, start, end) in enumerate(turn_ranges):
        result.utterances.extend(cut_turn(turn, index, aligned, start, config, result.stats))
        span = aligned.span(start, end)
        result.turn_reports.append(
            {
                "turn": index,
                "role": turn.role,
                "speaker": turn.speaker,
                "tokens": end - start,
                "anchor_rate": round(span[2], 4) if span else 0.0,
            }
        )

    result.utterances.sort(key=lambda utterance: utterance.start)
    return result
