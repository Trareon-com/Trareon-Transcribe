"""WER and CER, pooled, with the substitution/deletion/insertion split.

Two decisions inherited from `docs/WER-BENCH.md` because changing them
would make this harness's numbers incomparable with the ones this
repository has already published:

* The corpus rate is **pooled** — total errors over total reference
  tokens — not the mean of per-clip rates. Averaging rates weights a
  four-word clip the same as a four-minute one, which is how a harness
  ends up reporting that the worse model won.
* A clip the model fails to decode counts as a **total loss** (every
  reference token deleted), not as a skip. A model that cannot read a
  file has not scored 0% on it.
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field

from eval.normalize import ID_MEETING, NormalizerConfig, characters, tokenize


@dataclass
class Errors:
    """Edit counts against one reference."""

    substitutions: int = 0
    deletions: int = 0
    insertions: int = 0
    reference_length: int = 0

    @property
    def total(self) -> int:
        return self.substitutions + self.deletions + self.insertions

    @property
    def rate(self) -> float:
        """Errors per reference token.

        An empty reference with a non-empty hypothesis is rate 1.0 per
        inserted token rather than a division by zero — and an empty
        reference with an empty hypothesis is 0.0, not NaN, so a silent
        clip transcribed as silence scores perfect instead of poisoning
        the pooled mean.
        """
        if self.reference_length == 0:
            return 1.0 if self.total else 0.0
        return self.total / self.reference_length

    def __add__(self, other: Errors) -> Errors:
        return Errors(
            substitutions=self.substitutions + other.substitutions,
            deletions=self.deletions + other.deletions,
            insertions=self.insertions + other.insertions,
            reference_length=self.reference_length + other.reference_length,
        )

    def as_dict(self) -> dict[str, float | int]:
        return {
            "substitutions": self.substitutions,
            "deletions": self.deletions,
            "insertions": self.insertions,
            "reference_length": self.reference_length,
            "errors": self.total,
            "rate": self.rate,
        }


def edit_counts(reference: Sequence[str], hypothesis: Sequence[str]) -> Errors:
    """Levenshtein alignment of two token sequences, with a backtrace.

    Two rows of the DP matrix plus an operation matrix: the full DP
    matrix for a 40-minute hearing against its risalah is tens of
    millions of cells, and the operation matrix alone is already the
    memory ceiling here.
    """
    ref_len, hyp_len = len(reference), len(hypothesis)
    if ref_len == 0:
        return Errors(insertions=hyp_len, reference_length=0)
    if hyp_len == 0:
        return Errors(deletions=ref_len, reference_length=ref_len)

    # ops[i][j]: 0 match, 1 substitution, 2 deletion (ref token unmatched),
    # 3 insertion (hyp token unmatched).
    ops = [[0] * (hyp_len + 1) for _ in range(ref_len + 1)]
    previous = list(range(hyp_len + 1))
    for j in range(1, hyp_len + 1):
        ops[0][j] = 3
    for i in range(1, ref_len + 1):
        current = [i] + [0] * hyp_len
        ops[i][0] = 2
        ref_token = reference[i - 1]
        for j in range(1, hyp_len + 1):
            if ref_token == hypothesis[j - 1]:
                current[j] = previous[j - 1]
                ops[i][j] = 0
                continue
            substitute = previous[j - 1] + 1
            delete = previous[j] + 1
            insert = current[j - 1] + 1
            best = min(substitute, delete, insert)
            current[j] = best
            # Tie-break substitution first so that a one-for-one
            # mishearing is reported as one substitution rather than a
            # deletion plus an insertion, which would double the count.
            if best == substitute:
                ops[i][j] = 1
            elif best == delete:
                ops[i][j] = 2
            else:
                ops[i][j] = 3
        previous = current

    counts = Errors(reference_length=ref_len)
    i, j = ref_len, hyp_len
    while i > 0 or j > 0:
        op = ops[i][j]
        if op == 0:
            i, j = i - 1, j - 1
        elif op == 1:
            counts.substitutions += 1
            i, j = i - 1, j - 1
        elif op == 2:
            counts.deletions += 1
            i -= 1
        else:
            counts.insertions += 1
            j -= 1
    return counts


def word_errors(reference: str, hypothesis: str, config: NormalizerConfig = ID_MEETING) -> Errors:
    return edit_counts(tokenize(reference, config), tokenize(hypothesis, config))


def char_errors(reference: str, hypothesis: str, config: NormalizerConfig = ID_MEETING) -> Errors:
    return edit_counts(characters(reference, config), characters(hypothesis, config))


@dataclass
class ClipScore:
    clip: str
    reference: str
    hypothesis: str
    words: Errors
    chars: Errors
    audio_secs: float = 0.0
    elapsed_secs: float = 0.0
    failed: bool = False

    @property
    def rtf(self) -> float:
        """Audio seconds per wall-clock second. Below 1.0 cannot keep up
        with a live meeting on the machine that produced the number."""
        return self.audio_secs / self.elapsed_secs if self.elapsed_secs > 0 else 0.0


@dataclass
class SetScore:
    """A model's score on one test set."""

    model: str
    test_set: str
    policy: str
    clips: list[ClipScore] = field(default_factory=list)

    # Set only when the score was *loaded* from a published report whose
    # per-clip detail is absent — an older file, written before
    # `clip_detail` existed. Re-running an afternoon of models to recover
    # numbers the report already states would be absurd, so the loaded
    # totals are carried directly and every accessor prefers them.
    loaded_words: Errors | None = None
    loaded_chars: Errors | None = None
    loaded_clips: int | None = None
    loaded_failures: int | None = None
    loaded_audio_secs: float | None = None
    loaded_elapsed_secs: float | None = None

    @property
    def from_report(self) -> bool:
        return self.loaded_words is not None

    @property
    def words(self) -> Errors:
        if self.loaded_words is not None:
            return self.loaded_words
        total = Errors()
        for clip in self.clips:
            total = total + clip.words
        return total

    @property
    def chars(self) -> Errors:
        if self.loaded_chars is not None:
            return self.loaded_chars
        total = Errors()
        for clip in self.clips:
            total = total + clip.chars
        return total

    @property
    def clip_count(self) -> int:
        return self.loaded_clips if self.loaded_clips is not None else len(self.clips)

    @property
    def audio_secs(self) -> float:
        if self.loaded_audio_secs is not None:
            return self.loaded_audio_secs
        return sum(clip.audio_secs for clip in self.clips)

    @property
    def elapsed_secs(self) -> float:
        if self.loaded_elapsed_secs is not None:
            return self.loaded_elapsed_secs
        return sum(clip.elapsed_secs for clip in self.clips)

    @property
    def rtf(self) -> float:
        return self.audio_secs / self.elapsed_secs if self.elapsed_secs > 0 else 0.0

    @property
    def failures(self) -> int:
        if self.loaded_failures is not None:
            return self.loaded_failures
        return sum(1 for clip in self.clips if clip.failed)

    def as_dict(self) -> dict:
        return {
            "model": self.model,
            "test_set": self.test_set,
            "policy": self.policy,
            "clips": self.clip_count,
            "failed_clips": self.failures,
            "audio_secs": round(self.audio_secs, 2),
            "elapsed_secs": round(self.elapsed_secs, 2),
            "rtf": round(self.rtf, 3),
            "wer": round(self.words.rate, 5),
            "cer": round(self.chars.rate, 5),
            "word_errors": self.words.as_dict(),
            "char_errors": self.chars.as_dict(),
            # Per-clip edit counts, so a published table can be rebuilt
            # or merged with another run's without re-decoding anything.
            # Deliberately not the hypothesis text: that would put a
            # third party's transcript into a committed JSON file.
            "clip_detail": [
                {
                    "clip": clip.clip,
                    "words": {
                        "substitutions": clip.words.substitutions,
                        "deletions": clip.words.deletions,
                        "insertions": clip.words.insertions,
                        "reference_length": clip.words.reference_length,
                    },
                    "chars": {
                        "substitutions": clip.chars.substitutions,
                        "deletions": clip.chars.deletions,
                        "insertions": clip.chars.insertions,
                        "reference_length": clip.chars.reference_length,
                    },
                    "audio_secs": round(clip.audio_secs, 3),
                    "elapsed_secs": round(clip.elapsed_secs, 3),
                    "failed": clip.failed,
                }
                for clip in self.clips
            ],
        }


def pooled(scores: Iterable[SetScore]) -> Errors:
    """Pool several test sets into one figure.

    Exposed, but see `docs/WER-BENCH.md`: pooling read speech with
    meeting audio produces a figure that describes neither. The
    benchmark report keeps them separate and this is here for the
    per-model totals within a single domain.
    """
    total = Errors()
    for score in scores:
        total = total + score.words
    return total
