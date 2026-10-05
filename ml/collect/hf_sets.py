"""The Hugging Face-hosted Indonesian test sets.

Three sources, three access situations, and the difference matters more
than the code:

* **FLEURS `id_id`** (CC-BY 4.0) — public, streams, no credentials.
  Read speech: one speaker, close microphone, no crosstalk.
* **Common Voice `id`** (CC0) — the dataset card is public but the audio
  is **gated**: the download needs an accepted licence on the Hugging
  Face account and a token. Read speech, 678 speakers.
* **GigaSpeech 2 `id`** — gated *and* **non-commercial**. Its DEV/TEST
  splits are 10 hours each, annotated by professional humans, and they
  are the only realistic multi-domain Indonesian test material in this
  list. Its `refined` train split is 6 000 hours of machine-labelled
  YouTube audio.

  **A model trained on GigaSpeech 2 cannot be released commercially.**
  See `ml/DATA_CARD.md`: the benchmark uses its TEST split for
  evaluation only, and training on it is gated behind an explicit flag
  plus the owner's legal decision.

Everything streams. The maintainer's machine has under 30 GB free and
the full releases do not fit; `--clips` is a hard cap, not a hint.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from common.atomic import write_bytes, write_text
from common.manifest import ManifestWriter, Record

#: Env vars `datasets`/`huggingface_hub` read a token from.
TOKEN_ENV = ("HF_TOKEN", "HUGGING_FACE_HUB_TOKEN", "HUGGINGFACE_TOKEN")


@dataclass(frozen=True)
class HfTestSet:
    """One Hugging Face speech set, as this project consumes it."""

    name: str
    repo: str
    config: str
    split: str
    #: Column holding the reference text.
    text_column: str
    licence_note: str
    gated: bool
    #: What the speech actually is. Printed next to every WER figure,
    #: because "16% WER" means nothing without it.
    domain: str
    #: Non-empty when the licence restricts what a trained model may be.
    training_caveat: str = ""
    #: Human steps needed before the downloader can work.
    access_steps: str = ""


FLEURS_ID = HfTestSet(
    name="fleurs-id",
    repo="google/fleurs",
    config="id_id",
    split="test",
    text_column="transcription",
    licence_note="CC-BY 4.0 (Google FLEURS)",
    gated=False,
    domain="ucapan baca, satu penutur, mikrofon dekat - bukan rapat",
)

COMMON_VOICE_ID = HfTestSet(
    name="cv-id",
    repo="mozilla-foundation/common_voice_17_0",
    config="id",
    split="test",
    text_column="sentence",
    licence_note="CC0 1.0 (Mozilla Common Voice)",
    gated=True,
    domain="ucapan baca, banyak penutur, mikrofon beragam",
    access_steps=(
        "1. Masuk ke huggingface.co, buka halaman dataset "
        "mozilla-foundation/common_voice_17_0 dan setujui ketentuannya.\n"
        "2. Buat token akses (Settings > Access Tokens, cukup hak 'read').\n"
        "3. export HF_TOKEN=hf_xxx  lalu jalankan ulang perintah ini.\n"
        "Catatan: rilis terbaru Common Voice kini dibagikan lewat Mozilla "
        "Data Collective dan mungkin menuntut pendaftaran terpisah; versi "
        "17.0 di Hugging Face tetap bisa diakses dengan token."
    ),
)

GIGASPEECH2_ID_TEST = HfTestSet(
    name="gs2-id-test",
    repo="speechcolab/gigaspeech2",
    config="id",
    split="test",
    text_column="text",
    licence_note=(
        "GigaSpeech 2 - akses riset NON-KOMERSIAL. Model yang dilatih "
        "dengan data ini tidak boleh dirilis untuk penggunaan komersial."
    ),
    gated=True,
    domain="multi-domain (YouTube), dianotasi manusia profesional - paling realistis",
    training_caveat=(
        "Dataset ini non-komersial. Dipakai untuk EVALUASI saja secara "
        "bawaan; pelatihan memerlukan keputusan hukum pemilik dan "
        "pelabelan model sebagai CC-BY-NC-4.0."
    ),
    access_steps=(
        "1. Buka huggingface.co/datasets/speechcolab/gigaspeech2 dan ajukan "
        "akses (formulir persetujuan riset non-komersial).\n"
        "2. Tunggu persetujuan pengelola dataset.\n"
        "3. Buat token akses 'read' lalu export HF_TOKEN=hf_xxx."
    ),
)

GIGASPEECH2_ID_DEV = HfTestSet(
    name="gs2-id-dev",
    repo="speechcolab/gigaspeech2",
    config="id",
    split="dev",
    text_column="text",
    licence_note=GIGASPEECH2_ID_TEST.licence_note,
    gated=True,
    domain=GIGASPEECH2_ID_TEST.domain,
    training_caveat=GIGASPEECH2_ID_TEST.training_caveat,
    access_steps=GIGASPEECH2_ID_TEST.access_steps,
)

TEST_SETS = {
    item.name: item
    for item in (FLEURS_ID, COMMON_VOICE_ID, GIGASPEECH2_ID_TEST, GIGASPEECH2_ID_DEV)
}


class GatedDataset(RuntimeError):
    """The set needs credentials that are not present."""

    def __init__(self, test_set: HfTestSet, cause: str = "") -> None:
        message = f"{test_set.name} ({test_set.repo}) butuh kredensial.\n{test_set.access_steps}"
        if cause:
            message += f"\nPenyebab asli: {cause}"
        super().__init__(message)
        self.test_set = test_set


def hf_token() -> str | None:
    for name in TOKEN_ENV:
        value = os.environ.get(name)
        if value:
            return value
    return None


def fetch(
    test_set: HfTestSet,
    target_dir: str | Path,
    *,
    clips: int = 40,
    verbose: bool = True,
) -> Path:
    """Download `clips` clips of `test_set` and write both manifests.

    Produces two files in `target_dir`:

    * `manifest.jsonl` — the collector format every other stage reads.
    * `manifest.tsv` — `path<TAB>reference`, which `rust_core`'s
      `wer_bench` consumes directly, so the benchmark can drive the real
      app CLI without a conversion step.

    Streams, so only the requested clips are downloaded rather than the
    whole release. Resumable: clips already on disk are not re-fetched.
    """
    try:
        from datasets import Audio, load_dataset
    except ImportError as error:  # pragma: no cover - dependency guard
        raise ImportError("`datasets` belum terpasang; jalankan `uv sync --extra data`") from error

    target = Path(target_dir)
    audio_dir = target / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)

    token = hf_token()
    if test_set.gated and not token:
        raise GatedDataset(test_set, "tidak ada HF_TOKEN di environment")

    try:
        stream = load_dataset(
            test_set.repo,
            test_set.config,
            split=test_set.split,
            streaming=True,
            token=token,
        )
        # decode=False hands over the published file bytes instead of a
        # decoded array: no audio backend needed, and the benchmark
        # measures the clip as published rather than as re-encoded here.
        stream = stream.cast_column("audio", Audio(decode=False))
    except Exception as error:
        if test_set.gated or _looks_gated(error):
            raise GatedDataset(test_set, f"{type(error).__name__}: {error}") from error
        raise

    writer = ManifestWriter(target / "manifest.jsonl")
    tsv_lines = [
        f"# {test_set.name}: {test_set.repo} [{test_set.config}/{test_set.split}]",
        f"# Lisensi: {test_set.licence_note}",
        f"# Jenis ucapan: {test_set.domain}",
        "# Dibuat oleh ml/collect/hf_sets.py; jangan di-commit.",
    ]

    written = 0
    for row in stream:
        if written >= clips:
            break
        reference = (row.get(test_set.text_column) or "").strip()
        audio = row.get("audio") or {}
        payload = audio.get("bytes")
        if not reference or not payload:
            continue

        source_name = audio.get("path") or row.get("path") or "klip.wav"
        suffix = Path(str(source_name)).suffix or ".wav"
        name = f"{written:04d}{suffix}"
        clip_path = audio_dir / name
        if not (clip_path.exists() and clip_path.stat().st_size > 0):
            write_bytes(clip_path, payload)

        writer.add(
            Record(
                id=f"{test_set.name}:{written:04d}",
                source=test_set.name,
                url=f"https://huggingface.co/datasets/{test_set.repo}",
                audio_path=f"audio/{name}",
                transcript_path=None,
                duration=None,  # probed by the harness; never guessed here
                licence_note=test_set.licence_note,
                extra={
                    "reference": reference,
                    "config": test_set.config,
                    "split": test_set.split,
                    "domain": test_set.domain,
                    "training_caveat": test_set.training_caveat,
                },
            )
        )
        # A reference containing a tab would silently corrupt the TSV.
        tsv_lines.append(f"audio/{name}\t{reference.replace(chr(9), ' ')}")
        written += 1
        if verbose and written % 10 == 0:
            print(f"  {test_set.name}: {written}/{clips} klip", flush=True)

    if written == 0:
        raise RuntimeError(f"{test_set.name}: tidak ada klip yang bisa diambil")

    write_text(target / "manifest.tsv", "\n".join(tsv_lines) + "\n")
    # Benchmark audio is never committed: it is someone else's, it is
    # large, and a corpus in git drifts from the published one.
    write_text(target / ".gitignore", "*\n")
    if verbose:
        print(f"{test_set.name}: {written} klip -> {target}", flush=True)
    return target / "manifest.tsv"


def _looks_gated(error: BaseException) -> bool:
    text = f"{type(error).__name__} {error}".casefold()
    return any(
        marker in text
        for marker in ("401", "403", "gated", "authenticat", "unauthorized", "access to model")
    )


def describe_access() -> list[dict]:
    """Access status of every set, for the sprint report.

    Does not touch the network: it reports whether credentials are
    *present*, which is the thing a human has to act on.
    """
    token = hf_token()
    rows = []
    for test_set in TEST_SETS.values():
        if not test_set.gated:
            status = "siap (publik)"
        elif token:
            status = "token tersedia - coba unduh"
        else:
            status = "TERKUNCI - butuh HF_TOKEN + persetujuan lisensi"
        rows.append(
            {
                "name": test_set.name,
                "repo": test_set.repo,
                "config": test_set.config,
                "split": test_set.split,
                "gated": test_set.gated,
                "status": status,
                "licence_note": test_set.licence_note,
                "domain": test_set.domain,
                "training_caveat": test_set.training_caveat,
                "access_steps": test_set.access_steps,
            }
        )
    return rows
