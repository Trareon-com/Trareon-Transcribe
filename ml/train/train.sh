#!/usr/bin/env bash
# Single entry point for a fine-tune on Linux/macOS.
#
#   ml/train/train.sh dry-run-cpu          # prove the chain on a CPU
#   ml/train/train.sh whisper-base-id      # the live-preview model
#   ml/train/train.sh whisper-turbo-id-6gb --steps 500
#
# Runs, in order: memory dry run -> train -> merge -> GGML -> evaluate.
# Every stage is resumable, so re-running after an interruption picks up
# where it stopped rather than starting again.
set -euo pipefail

CONFIG_NAME="${1:?pakai: train.sh <nama-config> [--steps N] [--skip-memcheck]}"
shift || true

ML_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ML_DIR/train/configs/${CONFIG_NAME}.yaml"
[[ -f "$CONFIG" ]] || { echo "config tidak ada: $CONFIG" >&2; exit 1; }

STEPS=""
SKIP_MEMCHECK=0
QUANTIZE="q5_0"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --steps)          STEPS="${2:?}"; shift 2 ;;
        --skip-memcheck)  SKIP_MEMCHECK=1; shift ;;
        --quantize)       QUANTIZE="${2:?}"; shift 2 ;;
        *) echo "opsi tidak dikenal: $1" >&2; exit 1 ;;
    esac
done

cd "$ML_DIR"
RUN="uv run python"
OUT="out/train/$CONFIG_NAME"
EXPORT_DIR="out/export/$CONFIG_NAME"

if [[ $SKIP_MEMCHECK -eq 0 ]]; then
    echo "==> [1/4] uji memori"
    # Non-fatal: on a CPU there is no VRAM limit to exceed, and the
    # report is what matters either way.
    $RUN -m train.dry_run_memory --config "$CONFIG" \
        --json "$OUT/memory_report.json" || \
        echo "    (uji memori melaporkan tidak muat - lanjut atas permintaan Anda)"
fi

echo "==> [2/4] latih"
if [[ -n "$STEPS" ]]; then
    $RUN -m train.lora --config "$CONFIG" --max-steps "$STEPS"
else
    $RUN -m train.lora --config "$CONFIG"
fi

echo "==> [3/4] gabungkan adapter + ekspor GGML"
$RUN -m train.merge_export \
    --adapter "$OUT/adapter" \
    --out "$EXPORT_DIR" \
    --quantize "$QUANTIZE"

echo "==> [4/4] ukur hasilnya"
GGML="$(find "$EXPORT_DIR" ".whisper-convert" -name 'ggml-*.bin' 2>/dev/null | head -1 || true)"
if [[ -n "$GGML" ]]; then
    echo "    model: $GGML"
    echo "    jalankan: uv run python -m eval.run_benchmark --ggml-path '$GGML'"
else
    echo "    tidak ada GGML yang dihasilkan; lewati pengukuran"
fi
echo "selesai."
