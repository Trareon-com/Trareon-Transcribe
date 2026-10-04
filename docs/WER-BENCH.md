# WER benchmark harness (F18)

How to measure, and — more importantly — what the numbers do and do not
say.

## Running it

```bash
# 1. Build a corpus. FLEURS id_id, CC-BY 4.0, streamed so only the
#    requested clips are downloaded. No audio is committed.
scripts/fetch_wer_corpus.sh bench/fleurs-id 40

# 2. Measure one or more models against it.
cargo run --release --bin wer_bench -- \
  --manifest bench/fleurs-id/manifest.tsv \
  --model models/ggml-tiny.bin \
  --model ~/Library/Caches/TrareonTranscribe/models/ggml-base.bin \
  --out bench/results.md
```

`--limit N` stops after N clips (a smoke run on a slow machine).
`--json` additionally prints the per-clip detail, which is what you want
when the question is *which* clips a model loses rather than by how much.
`--gpu` uses the GPU if this binary was built with a backend.

## The manifest

TSV, one clip per line, `path<TAB>reference text`:

```
# comments and blank lines are skipped
audio/0000.wav	tim-tim virtual memiliki standar keunggulan yang sama
audio/0001.wav	segera setelah permusuhan pecah britania memulai blokade laut jerman
```

Paths are relative to the manifest's own directory, so a corpus can be
moved as a unit. A line without a tab is an **error**, not a skipped
clip: a manifest that quietly measures fewer clips than it lists
produces a number nobody can reproduce.

Any corpus works. FLEURS is the one with a downloader because it ships
one transcript per clip with no validation step to replicate; Common
Voice needs its TSV joined and filtered by up-votes first, which is a
second place for a mistake to hide.

## What is measured

* **WER** — word error rate, Levenshtein over normalised words, with
  substitutions, deletions and insertions counted separately.
* **CER** — the same over characters. Reported alongside WER because
  Indonesian affixation makes WER brutal: `mempertanggungjawabkan`
  misheard by one syllable is a whole word wrong, and CER says how near
  the miss was.
* **RTF** — audio seconds per wall-clock second. Below 1.0 cannot keep
  up with a live meeting on this machine, which is the number Item 0's
  live-model fallback keys off.

Both sides are case-folded, stripped of punctuation and
whitespace-collapsed before alignment, because comparing raw strings
measures punctuation habits rather than transcription quality. Hyphens
and apostrophes *inside* a word are kept — `undang-undang` is one
Indonesian word and splitting it would invent two errors out of one.

Deliberately **not** normalised: numbers (`12` vs `dua belas`) and
abbreviations (`RAB` vs `rencana anggaran biaya`). Both are judgement
calls that would make the harness flatter whichever model happens to
share its convention, and a harness with a built-in preference is worse
than no harness.

The corpus WER is **pooled** — total errors over total reference words —
not the mean of per-clip rates. Averaging rates weights a four-word clip
the same as a four-minute one, which is how a harness ends up reporting
that the worse model won.

A clip the model fails to decode counts as a total loss, not as a skip:
a model that cannot read a file has not scored 0% on it.

## What the numbers do not say

FLEURS is **read speech**, recorded close to a microphone, one speaker,
no crosstalk. A model that scores well here has not been shown to work
on a four-person rapat over a laptop microphone with an air conditioner
running — which is the only workload this app has.

So when publishing:

1. Say which corpus, which commit, and which machine. RTF is meaningless
   without the last one.
2. Publish read-speech and meeting-audio numbers **separately** and
   label them. Averaging them produces a figure that describes neither.
3. Quote WER *and* CER. A model with a better WER and a much worse CER is
   making different mistakes, not fewer.
4. Do not quote a figure from a 12-clip smoke run as the model's WER. It
   is a smoke run; say so.

## Measured on this machine

See the "F18" section of `docs/SPRINT-REPORTS.md` for the numbers this
repository has actually measured, with the corpus size and the hardware
stated next to them.
