#!/usr/bin/env bash
#
# Converts a HuggingFace Whisper fine-tune into a whisper.cpp GGML model.
#
#   scripts/convert_hf_whisper_to_ggml.sh cahya/whisper-medium-id
#   scripts/convert_hf_whisper_to_ggml.sh cahya/whisper-medium-id --quantize q5_0
#
# Why this script exists
# ----------------------
# `cahya/whisper-medium-id` is the best-measured open Indonesian Whisper
# fine-tune there is — WER 3.83% on Common Voice 11, against ~12-15% for
# multilingual large-v3 (Research Round 2 §2.5.2). It is published only in
# the `transformers` format, and nobody has published a GGML conversion of
# it that states its provenance, so Trareon cannot ship one: the model
# catalog pins a SHA256 for every file it will download, and pinning the
# hash of an unattributed third-party binary would be security theatre.
#
# What it does instead is make the conversion a documented, repeatable,
# ten-minute job the user runs once on their own machine. See
# docs/INDONESIAN-MODEL.md for the whole path, including how to point the
# app at the result.
#
# Requirements: python3, git, and ~8 GB of free disk (the PyTorch weights,
# the f16 GGML, and the quantised GGML, briefly all at once).

set -euo pipefail

usage() {
    cat <<'EOF'
Penggunaan:
  scripts/convert_hf_whisper_to_ggml.sh <repo-huggingface> [opsi]

Opsi:
  --quantize <jenis>   Kuantisasi setelah konversi (q5_0, q8_0, q4_0).
                       Tanpa ini hasilnya f16 (±1,5 GB untuk medium).
  --out <berkas>       Nama berkas keluaran. Default:
                       ggml-<nama-model>.bin di direktori kerja.
  --work <direktori>   Direktori kerja. Default: ./.whisper-convert
  --keep               Jangan hapus unduhan dan klon setelah selesai.

Contoh:
  scripts/convert_hf_whisper_to_ggml.sh cahya/whisper-medium-id --quantize q5_0
EOF
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

REPO="$1"
shift

QUANTIZE=""
OUT=""
WORK="$(pwd)/.whisper-convert"
KEEP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --quantize) QUANTIZE="${2:?--quantize butuh jenis}"; shift 2 ;;
        --out)      OUT="${2:?--out butuh nama berkas}"; shift 2 ;;
        --work)     WORK="${2:?--work butuh direktori}"; shift 2 ;;
        --keep)     KEEP=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *)          echo "opsi tidak dikenal: $1" >&2; usage; exit 1 ;;
    esac
done

MODEL_NAME="${REPO##*/}"
OUT="${OUT:-ggml-${MODEL_NAME}.bin}"

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "butuh '$1' di PATH" >&2
        exit 1
    }
}
need python3
need git

mkdir -p "$WORK"
cd "$WORK"

# whisper.cpp's own converter, plus the original OpenAI repo it needs for
# the mel filterbank and the tokenizer vocabularies. Shallow clones: the
# full histories are ~1 GB between them and nothing here reads them.
if [[ ! -d whisper.cpp ]]; then
    echo "==> mengklon whisper.cpp"
    git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git
fi
if [[ ! -d whisper ]]; then
    echo "==> mengklon openai/whisper (untuk filterbank + tokenizer)"
    git clone --depth 1 https://github.com/openai/whisper.git
fi

echo "==> menyiapkan lingkungan Python"
if [[ ! -d venv ]]; then
    python3 -m venv venv
fi
# shellcheck disable=SC1091
source venv/bin/activate
pip install --quiet --upgrade pip
# `torch` CPU-only: the conversion reads the weights and writes them out,
# it never runs the model, so a CUDA build would be a 2 GB download for
# nothing.
pip install --quiet \
    "torch --index-url https://download.pytorch.org/whl/cpu" \
    transformers numpy

echo "==> mengunduh $REPO"
python3 - "$REPO" <<'PY'
import sys
from transformers import WhisperForConditionalGeneration

repo = sys.argv[1]
# `cache_dir` left at the default so a second run is free.
WhisperForConditionalGeneration.from_pretrained(repo)
print(f"ok: {repo}")
PY

echo "==> mengonversi ke GGML"
# convert-h5-to-ggml.py wants: <model-dir-or-repo> <openai-whisper-repo> <out-dir>
python3 whisper.cpp/models/convert-h5-to-ggml.py "$REPO" ./whisper .
GENERATED="$(ls -t ggml-model.bin 2>/dev/null || true)"
if [[ -z "$GENERATED" ]]; then
    echo "konversi tidak menghasilkan ggml-model.bin — periksa keluaran di atas" >&2
    exit 1
fi
mv "$GENERATED" "$OUT"
echo "==> f16 selesai: $WORK/$OUT ($(du -h "$OUT" | cut -f1))"

if [[ -n "$QUANTIZE" ]]; then
    echo "==> membangun alat kuantisasi whisper.cpp"
    cmake -S whisper.cpp -B whisper.cpp/build -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build whisper.cpp/build --target quantize -j"$(nproc 2>/dev/null || echo 4)" >/dev/null
    QUANT_OUT="${OUT%.bin}-${QUANTIZE}.bin"
    ./whisper.cpp/build/bin/quantize "$OUT" "$QUANT_OUT" "$QUANTIZE"
    echo "==> kuantisasi selesai: $WORK/$QUANT_OUT ($(du -h "$QUANT_OUT" | cut -f1))"
    OUT="$QUANT_OUT"
fi

echo
echo "SHA256 (catat ini bila Anda membagikan berkasnya):"
sha256sum "$OUT" 2>/dev/null || shasum -a 256 "$OUT"
echo
cat <<EOF
Langkah berikutnya
------------------
1. Salin berkas ke folder model Trareon:
     macOS/Linux : ~/Library/Caches/TrareonTranscribe/models/
     Windows     : %LOCALAPPDATA%\\TrareonTranscribe\\models\\
2. Di Pengaturan → Model, pilih berkas itu lewat "Model lain di komputer ini".
3. Bandingkan dengan model bawaan sebelum memakainya untuk rapat sungguhan:
     cd rust_core && cargo run --release --bin wer_bench -- \\
       --manifest bench/id_id.tsv \\
       --model $WORK/$OUT \\
       --model ~/Library/Caches/TrareonTranscribe/models/ggml-large-v3-turbo-q5_0.bin
   WER yang dilaporkan model aslinya diukur pada Common Voice, bukan pada
   rekaman rapat; lihat docs/INDONESIAN-MODEL.md.
EOF

if [[ $KEEP -eq 0 ]]; then
    echo "(jalankan dengan --keep untuk menyimpan klon dan venv di $WORK)"
fi
