"""CLI for the Indonesian Meeting ASR benchmark.

    uv run python -m eval.run_benchmark --list
    uv run python -m eval.run_benchmark --ggml tiny,base --sets fleurs-id --limit 20
    uv run python -m eval.run_benchmark --all-ggml --hf cahya/whisper-medium-id

Writes `ml/BENCHMARK.md` and `ml/out/benchmark.json`.

Measured on the maintainer's CPU, 2026-10-05: tiny runs at 3.4x real
time, small at 0.37x and `large-v3-turbo-q5` at **0.09x** — eleven times
slower than the audio. The models therefore differ in cost by a factor
of forty, which is why each test set carries its own `default_limit`
rather than the runs sharing one global cap. Override with `--limit`
when there is time for a full-scale run; the limit always applies to
every model equally, so a column stays comparable.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from eval.harness import TestSet, render_markdown, run_benchmark, write_report
from eval.normalize import preset
from eval.runners import GgmlRunner, Runner, TransformersRunner

ML_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ML_ROOT.parent
DATA_ROOT = ML_ROOT / "data"

#: Where this project keeps GGML models, in search order.
MODEL_DIRS = (
    Path.home() / "Library/Caches/TrareonTranscribe/models",
    REPO_ROOT / "models",
)

WER_BENCH = REPO_ROOT / "rust_core/target/release/wer_bench"

#: The benchmark's test sets. `fetch_sets.py` populates the manifests;
#: a set whose manifest is absent is reported as unmeasured rather than
#: silently dropped.
TEST_SETS: dict[str, TestSet] = {
    "fleurs-id": TestSet(
        name="fleurs-id",
        manifest=DATA_ROOT / "fleurs-id/manifest.tsv",
        domain="ucapan baca, satu penutur, mikrofon dekat",
        speech_kind="baca",
        licence_note="CC-BY 4.0",
        default_limit=10,
    ),
    "cv-id": TestSet(
        name="cv-id",
        manifest=DATA_ROOT / "cv-id/manifest.tsv",
        domain="ucapan baca, banyak penutur, mikrofon beragam",
        speech_kind="baca",
        licence_note="CC0 1.0",
        default_limit=10,
        notes="Butuh HF_TOKEN + persetujuan lisensi.",
    ),
    "gs2-id-test": TestSet(
        name="gs2-id-test",
        manifest=DATA_ROOT / "gs2-id-test/manifest.tsv",
        domain="multi-domain YouTube, dianotasi manusia profesional",
        speech_kind="rapat",
        licence_note="Riset NON-KOMERSIAL",
        notes=(
            "Set uji paling realistis yang tersedia. Butuh akses ter-approve. "
            "Model yang DILATIH dengan GigaSpeech 2 harus dirilis non-komersial."
        ),
    ),
    "mk-holdout": TestSet(
        name="mk-holdout",
        manifest=DATA_ROOT / "mk-holdout/manifest.tsv",
        domain="sidang Mahkamah Konstitusi, spontan-formal",
        speech_kind="rapat",
        licence_note="Teks: UU 28/2014 Ps. 42. Rekaman: perlu izin penyiaran.",
        notes="Sidang yang TIDAK dipakai untuk training.",
    ),
    "dpr-holdout": TestSet(
        name="dpr-holdout",
        manifest=DATA_ROOT / "dpr-holdout/manifest.tsv",
        domain="rapat DPR RI, spontan-formal, banyak penutur",
        speech_kind="rapat",
        licence_note="Teks: UU 28/2014 Ps. 42. Rekaman: perlu izin penyiaran.",
        notes="Rapat yang TIDAK dipakai untuk training.",
    ),
    "codeswitch-synth-id-en": TestSet(
        name="codeswitch-synth-id-en",
        manifest=DATA_ROOT / "codeswitch-synth-id-en/manifest.tsv",
        domain="peralihan bahasa ID<->EN dalam satu jendela dekode (SINTETIS)",
        speech_kind="rapat",
        licence_note="CC-BY 4.0 (FLEURS id_id + en_us digabung)",
        default_limit=8,
        notes=(
            "SINTETIS: dua ujaran baca digabung, bukan code-switching alami "
            "intra-kalimat. Mengukur kegagalan terdokumentasi Whisper memilih "
            "SATU token bahasa per jendela 30 detik. Code-switching alami "
            "diperkirakan JAUH lebih buruk - lihat ml/eval/build_sets.py."
        ),
    ),
    "codeswitch-id-en": TestSet(
        name="codeswitch-id-en",
        manifest=DATA_ROOT / "codeswitch-id-en/manifest.tsv",
        domain="rapat kantor campur ID-EN, direkam sendiri ber-consent",
        speech_kind="rapat",
        licence_note="Rekaman sendiri, consent UU PDP (lihat ml/record_kit/)",
        notes=(
            "PLACEHOLDER - belum direkam. Celah terpenting: tidak ada korpus "
            "code-switching ID-EN ALAMI berlisensi terbuka. Lihat ml/record_kit/."
        ),
    ),
    "silence": TestSet(
        name="silence",
        manifest=DATA_ROOT / "silence/manifest.tsv",
        domain="hening - menguji halusinasi, acuan kosong",
        speech_kind="rapat",
        licence_note="Dibuat sendiri (ml/eval/build_sets.py)",
        default_limit=4,
        notes=(
            "Acuan kosong: setiap kata yang keluar adalah sisipan. WER 0% = tidak berhalusinasi."
        ),
    ),
}

#: GGML models by short name.
GGML_MODELS = {
    "tiny": "ggml-tiny.bin",
    "base": "ggml-base.bin",
    "small": "ggml-small.bin",
    "medium": "ggml-medium.bin",
    "turbo-q5": "ggml-large-v3-turbo-q5_0.bin",
}


def find_model(filename: str) -> Path | None:
    for directory in MODEL_DIRS:
        candidate = directory / filename
        if candidate.exists():
            return candidate
    return None


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="eval.run_benchmark", description="Benchmark Indonesian Meeting ASR v0"
    )
    parser.add_argument("--ggml", default="", help="daftar model GGML: tiny,base,turbo-q5")
    parser.add_argument("--all-ggml", action="store_true", help="semua model GGML yang ada di disk")
    parser.add_argument(
        "--hf", action="append", default=[], help="model Hugging Face (boleh berulang)"
    )
    parser.add_argument("--adapter", default=None, help="direktori LoRA untuk model --hf terakhir")
    parser.add_argument("--sets", default="", help="daftar set uji; kosong = semua yang tersedia")
    parser.add_argument("--limit", type=int, default=None, help="berhenti setelah N klip")
    parser.add_argument("--policy", default="id_meeting", help="preset normalisasi")
    parser.add_argument("--gpu", action="store_true", help="pakai GPU untuk wer_bench")
    parser.add_argument("--list", action="store_true", help="tampilkan apa yang tersedia")
    parser.add_argument("--markdown", default=str(ML_ROOT / "BENCHMARK.md"))
    parser.add_argument("--json", default=str(ML_ROOT / "out/benchmark.json"))
    return parser


def show_inventory() -> None:
    print("Model GGML:")
    for short, filename in GGML_MODELS.items():
        found = find_model(filename)
        print(f"  {short:10} {'ADA   ' if found else 'HILANG'} {found or filename}")
    print(f"\nwer_bench: {'ADA' if WER_BENCH.exists() else 'HILANG - cargo build --release'}")
    print(f"  {WER_BENCH}")
    print("\nSet uji:")
    for name, test_set in TEST_SETS.items():
        ready = Path(test_set.manifest).exists()
        print(f"  {name:18} {'SIAP  ' if ready else 'KOSONG'} [{test_set.speech_kind}]")
        if not ready:
            print(f"      -> {test_set.manifest}")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.list:
        show_inventory()
        return 0

    config = preset(args.policy)

    runners: list[Runner] = []
    wanted = [name.strip() for name in args.ggml.split(",") if name.strip()]
    if args.all_ggml:
        wanted = list(GGML_MODELS)
    if wanted and not WER_BENCH.exists():
        print(
            f"wer_bench tidak ada di {WER_BENCH}\n"
            "  bangun dulu: cd rust_core && cargo build --release --bin wer_bench",
            file=sys.stderr,
        )
        return 2
    for short in wanted:
        filename = GGML_MODELS.get(short)
        if filename is None:
            print(f"model GGML tidak dikenal: {short}", file=sys.stderr)
            return 2
        path = find_model(filename)
        if path is None:
            # Not an error: the point of --all-ggml is "whatever is here".
            print(f"  lewati {short}: {filename} tidak ada di disk", file=sys.stderr)
            continue
        runners.append(GgmlRunner(model_path=path, binary=WER_BENCH, gpu=args.gpu, name=short))

    for index, model_id in enumerate(args.hf):
        adapter = args.adapter if index == len(args.hf) - 1 else None
        runners.append(TransformersRunner(model_id=model_id, adapter=adapter))

    if not runners:
        print("tidak ada model untuk diukur (pakai --ggml / --all-ggml / --hf)", file=sys.stderr)
        return 2

    names = [name.strip() for name in args.sets.split(",") if name.strip()] or list(TEST_SETS)
    try:
        chosen = [TEST_SETS[name] for name in names]
    except KeyError as error:
        print(f"set uji tidak dikenal: {error}; pilihan: {sorted(TEST_SETS)}", file=sys.stderr)
        return 2
    available = [item for item in chosen if Path(item.manifest).exists()]
    if not available:
        print(
            "tidak ada set uji yang manifesnya tersedia; jalankan eval/fetch_sets.py",
            file=sys.stderr,
        )
        return 2

    print(f"Mengukur {len(runners)} model x {len(available)} set uji (policy {config.name})")
    result = run_benchmark(runners, available, config=config, limit=args.limit)
    write_report(result, chosen, markdown_path=args.markdown, json_path=args.json)
    print(f"\n{render_markdown(result, chosen)}")
    print(f"\nDitulis: {args.markdown} dan {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
