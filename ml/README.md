# `ml/` — Indonesian Meeting ASR: data, benchmark, training

Python side of Trareon Transcribe: collecting Indonesian meeting speech,
aligning it against official minutes, measuring models on it, and
fine-tuning one that fits a 6 GB GPU.

**This directory is not part of the app.** Nothing in `ml/` is imported
by the Flutter or Rust build, and the app ships without it. It has its
own `pyproject.toml`, its own virtualenv, and its own CI job. The only
coupling runs the other way: the benchmark *drives* `rust_core`'s
`wer_bench` and `transcribe_cli` binaries, because measuring the engine
the product actually ships beats measuring a Python reimplementation of
it.

## Why this exists

From `docs/research/RESEARCH-DECISION-FINAL.md`, all figures verified:

- Whisper on **read** Indonesian (FLEURS) is decent: small 16.3% WER,
  large-v2 7.1%.
- Whisper on **spontaneous** Indonesian is not: a 2024 study over 80.5
  hours measured whisper-small at 30.9% WER overall, splitting into
  27.2% for read/formal and **40.7% for spontaneous/informal**.
- **Code-switching ID–EN is an open problem.** Whisper commits to one
  language token per 30-second window. Measured Indonesian CER: 4.1%
  monolingual, 37.6% synthetic code-switching, **above 80% natural**.
- A fine-tune closes the gap: Rafiqspace reports 95.6% accuracy on
  government meetings against Gemini Pro's 91.8%.

So the accuracy gap for Indonesian meetings is real and large, and
fine-tuning is known to close it. The missing pieces were a benchmark
that measures the gap honestly and data that is legal to train on. That
is what this directory is.

## Setup

```bash
cd ml
uv sync --extra dev --extra data --extra pdf     # everyday work
uv sync --extra train                            # + CPU training/eval
uv sync --extra train --extra gpu                # + GPU (RTX 2060 box)
```

`uv run python -m <module>` for everything below; the examples omit the
prefix for brevity.

## Layout

| Path | What |
|---|---|
| `common/` | atomic writes, manifest format, the polite HTTP client |
| `collect/` | source collectors: MK, DPR, YouTube, Hugging Face sets |
| `align/` | risalah → timestamped training utterances |
| `eval/` | normalisation, WER/CER, the benchmark harness |
| `train/` | LoRA fine-tuning, VRAM dry run, merge + GGML export |
| `record_kit/` | consent form, session script, ingest for own recordings |
| `tests/` | 247 tests, hermetic (no network, no GPU, no models) |
| `DATA_CARD.md` | every source's licence, legal basis, and PII handling |
| `MODEL_CARD_TEMPLATE.md` | what a released model has to state |
| `BENCHMARK.md` | the measured results table |

## The four things you probably came here to do

### 1. See what data is available and what is blocked

```bash
python -m eval.fetch_sets --status     # no network; prints what a human must do
python -m eval.run_benchmark --list    # models and test sets on this machine
```

### 2. Build the test sets and measure models

```bash
python -m eval.fetch_sets --public                  # FLEURS id + en
python -m eval.build_sets                           # code-switch + silence sets
cd ../rust_core && cargo build --release --bin wer_bench && cd ../ml
python -m eval.run_benchmark --ggml tiny,base,small,turbo-q5
```

Results go to `BENCHMARK.md` and `out/benchmark.json`.

### 3. Align a hearing against its minutes

```bash
cd ../rust_core && cargo build --release --bin transcribe_cli && cd ../ml
python -m align.pipeline \
    --audio data/pilot/mk-0001.wav \
    --risalah data/pilot/mk-0001.pdf \
    --model ~/Library/Caches/TrareonTranscribe/models/ggml-base.bin \
    --out data/shards/mk
```

Prints hours in, hours kept, and why the rest went. With no real hearing
to hand, `align/synthetic.py` builds one from FLEURS whose correct
alignment is known, and `align/validate.py` scores the recovery.

### 4. Fine-tune

```bash
./train/train.sh dry-run-cpu           # prove the chain on a CPU, minutes
./train/train.sh whisper-base-id       # the live-preview model
./train/train.sh whisper-turbo-id-6gb  # the accuracy model, on the 2060
```

On Windows: `.\ml\train\train.ps1 -Config whisper-turbo-id-6gb`. See
`train/WINDOWS.md`.

## Three things that will bite you

**1. The government sources refuse automated access.** Measured
2026-10-05: `mkri.id` serves a Cloudflare interstitial on every path,
and `dpr.go.id` loads but renders its risalah list client-side from an
endpoint its own robots.txt meant to forbid. The collectors detect both,
report precisely what happened, and **stop** — they do not work around
an anti-bot control. The route forward is an official data request
(PPID), after which `collect/gov_sources.py::load_index` takes over and
the tested half of the pipeline runs unchanged. Full detail in
`DATA_CARD.md` §4.

**2. WER figures need their normalisation policy quoted.** `12` and `dua
belas` are the same words spoken; scoring them as an error measures
orthography. `eval/normalize.py` has two named, versioned presets —
`minimal` reproduces `rust_core`'s `wer_bench` so older published
figures stay comparable, `id_meeting` is the benchmark's. Every result
carries the policy name and version. A WER without them is not
reproducible.

**3. A model trained on GigaSpeech 2 cannot be released commercially.**
This is checked in code (`train/data.py::check_licences`), recorded in
`train_metrics.json`, and surfaced in the generated model card. Do not
work around it; read `DATA_CARD.md` §3.3 first.

## Tests

```bash
uv run pytest                 # hermetic: no network, no GPU, no models
uv run pytest -m network      # opt-in, hits real hosts
uv run ruff check . && uv run ruff format --check .
```

CI runs the hermetic set plus lint (`.github/workflows/ml.yml`). Tests
needing the network, a GPU, or more than ten seconds are marked and
excluded by default — a test that silently stops testing because
`mkri.id` changed is worse than no test.
