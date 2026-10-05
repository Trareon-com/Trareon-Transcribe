"""LoRA adapter → merged HF model → GGML → quantised GGML.

    uv run python -m train.merge_export \
        --adapter out/train/whisper-small-id/adapter \
        --out out/export/whisper-small-id \
        --quantize q5_0

Four steps, and the last two are delegated:

1. **Merge.** Load the base in fp32, apply the adapter, `merge_and_unload`.
   fp32 on purpose: merging into fp16 rounds every updated weight twice
   (once for the base, once for the sum) and the adapter's whole effect
   on a given weight can be smaller than fp16's resolution there. The
   merged model is saved in fp16 — that is a single rounding, at the end.

   A 4-bit-trained adapter is merged into the **unquantised** base, not
   back into the 4-bit one. Merging into a dequantised 4-bit base would
   bake the quantisation error into the released weights permanently.

2. **Save** in `transformers` format, with the processor, because
   whisper.cpp's converter reads the tokenizer from the same directory.

3. **Convert and quantise** by calling
   `scripts/convert_hf_whisper_to_ggml.sh`, which this repository already
   has, already documents, and already prints the SHA256 that the app's
   model catalogue pins.

4. **Report** the licence the model may carry, from what it was trained
   on. A model trained on GigaSpeech 2 cannot be released commercially,
   and that fact has to travel with the file rather than live in
   somebody's memory.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from common.atomic import write_json, write_text

REPO_ROOT = Path(__file__).resolve().parents[2]
CONVERT_SCRIPT = REPO_ROOT / "scripts/convert_hf_whisper_to_ggml.sh"


def read_base_model(adapter_dir: Path) -> str:
    """The base model an adapter was trained against.

    From the adapter's own `adapter_config.json`, so an export cannot be
    pointed at the wrong base — which would produce a model that loads,
    runs, and is quietly much worse.
    """
    config_path = adapter_dir / "adapter_config.json"
    if not config_path.exists():
        raise FileNotFoundError(f"{config_path} tidak ada - apakah ini direktori adapter PEFT?")
    payload = json.loads(config_path.read_text(encoding="utf-8"))
    base = payload.get("base_model_name_or_path")
    if not base:
        raise ValueError(f"{config_path}: tidak ada base_model_name_or_path")
    return str(base)


def merge(adapter_dir: str | Path, out_dir: str | Path, *, base_model: str | None = None) -> Path:
    """Merge the adapter into its base and save in HF format."""
    try:
        import torch
        from peft import PeftModel
        from transformers import WhisperForConditionalGeneration, WhisperProcessor
    except ImportError:  # pragma: no cover - dependency guard
        raise SystemExit(
            "`transformers`/`peft`/`torch` belum terpasang; uv sync --extra train"
        ) from None

    adapter = Path(adapter_dir)
    target = Path(out_dir)
    target.mkdir(parents=True, exist_ok=True)
    base = base_model or read_base_model(adapter)

    print(f"==> memuat basis {base} (fp32, tanpa kuantisasi)", flush=True)
    # fp32 and unquantised: see the module docstring. This is a one-off
    # CPU-friendly step, so the memory cost is acceptable even for turbo.
    model = WhisperForConditionalGeneration.from_pretrained(base, dtype=torch.float32)

    print(f"==> menerapkan adapter {adapter}", flush=True)
    model = PeftModel.from_pretrained(model, str(adapter))
    model = model.merge_and_unload()

    # One rounding, at the end.
    model = model.half()
    model.config.use_cache = True
    model.save_pretrained(str(target), safe_serialization=True)

    # The converter reads the tokenizer from this directory.
    processor = WhisperProcessor.from_pretrained(
        str(adapter) if (adapter / "preprocessor_config.json").exists() else base
    )
    processor.save_pretrained(str(target))

    print(f"==> model gabungan: {target}", flush=True)
    return target


def to_ggml(
    model_dir: str | Path,
    *,
    quantize: str | None = "q5_0",
    out_name: str | None = None,
    work_dir: str | Path | None = None,
    timeout: float = 7200.0,
) -> Path | None:
    """Convert a merged HF model to GGML via the repo's own script."""
    if not CONVERT_SCRIPT.exists():
        print(f"skrip konversi tidak ada: {CONVERT_SCRIPT}", file=sys.stderr)
        return None

    source = Path(model_dir).resolve()
    name = out_name or f"ggml-{source.name}.bin"
    work = Path(work_dir).resolve() if work_dir else source.parent / ".whisper-convert"

    args = [str(CONVERT_SCRIPT), str(source), "--out", name, "--work", str(work)]
    if quantize:
        args += ["--quantize", quantize]

    print(f"==> {' '.join(args)}", flush=True)
    completed = subprocess.run(args, timeout=timeout, check=False)
    if completed.returncode != 0:
        print("konversi GGML gagal - lihat keluaran di atas", file=sys.stderr)
        return None

    produced = name if not quantize else f"{name.removesuffix('.bin')}-{quantize}.bin"
    result = work / produced
    return result if result.exists() else None


def write_model_card(
    out_dir: str | Path,
    *,
    base_model: str,
    adapter: str,
    ggml: Path | None,
    metrics: dict | None,
) -> Path:
    """Fill the model card template with what this export knows."""
    template = REPO_ROOT / "ml/MODEL_CARD_TEMPLATE.md"
    licence = (metrics or {}).get("licence", {})
    body = template.read_text(encoding="utf-8") if template.exists() else "# Model card\n"

    filled = [
        "<!-- Dihasilkan oleh ml/train/merge_export.py; lengkapi bagian",
        "     yang masih bertanda TODO sebelum merilis. -->",
        "",
        f"- Model basis: `{base_model}`",
        f"- Adapter LoRA: `{adapter}`",
        f"- GGML: `{ggml}`" if ggml else "- GGML: belum dikonversi",
        f"- Lisensi yang disarankan: **{licence.get('recommended_licence', 'TODO')}**",
        f"- Boleh komersial: **{licence.get('commercial_use_allowed', 'TODO')}**",
    ]
    if licence.get("non_commercial_sources"):
        filled.append("- ⚠️ Sumber non-komersial: " + ", ".join(licence["non_commercial_sources"]))
    if licence.get("summary"):
        filled.append(f"- Catatan lisensi: {licence['summary']}")
    filled += ["", "---", "", body]

    return write_text(Path(out_dir) / "MODEL_CARD.md", "\n".join(filled))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="train.merge_export")
    parser.add_argument("--adapter", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--base-model", default=None)
    parser.add_argument("--quantize", default="q5_0", help="q5_0 / q8_0 / q4_0 / none")
    parser.add_argument("--ggml-name", default=None)
    parser.add_argument("--work", default=None)
    parser.add_argument("--skip-ggml", action="store_true", help="hanya gabungkan, jangan konversi")
    args = parser.parse_args(argv)

    adapter = Path(args.adapter)
    merged = merge(adapter, args.out, base_model=args.base_model)

    ggml: Path | None = None
    if not args.skip_ggml:
        quantize = None if args.quantize.casefold() in {"none", "no", ""} else args.quantize
        ggml = to_ggml(merged, quantize=quantize, out_name=args.ggml_name, work_dir=args.work)

    # The training run's metrics sit next to the adapter.
    metrics_path = adapter.parent / "train_metrics.json"
    metrics = (
        json.loads(metrics_path.read_text(encoding="utf-8")) if metrics_path.exists() else None
    )

    write_model_card(
        args.out,
        base_model=args.base_model or read_base_model(adapter),
        adapter=str(adapter),
        ggml=ggml,
        metrics=metrics,
    )
    write_json(
        Path(args.out) / "export.json",
        {
            "adapter": str(adapter),
            "merged": str(merged),
            "ggml": str(ggml) if ggml else None,
            "quantize": args.quantize,
            "licence": (metrics or {}).get("licence"),
        },
    )

    print(f"\nselesai: {merged}")
    if ggml:
        print(f"GGML   : {ggml}")
        print(
            "\nUkur sebelum dipakai:\n"
            f"  uv run python -m eval.run_benchmark --ggml-path {ggml}\n"
            "atau langsung:\n"
            f"  rust_core/target/release/wer_bench --manifest ml/data/fleurs-id/manifest.tsv "
            f"--model {ggml}"
        )
    else:
        print("GGML   : tidak dibuat")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
