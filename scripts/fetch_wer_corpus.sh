#!/usr/bin/env bash
# Builds an Indonesian WER corpus for `wer_bench` (F18).
#
# Downloads a slice of Google FLEURS `id_id` — read speech, CC-BY 4.0 —
# and writes the TSV manifest `wer_bench` expects. Nothing it fetches is
# committed to this repository: the audio is someone else's, it is large,
# and a benchmark corpus that lives in git is a benchmark corpus that
# silently drifts from the published one.
#
#   scripts/fetch_wer_corpus.sh [TARGET_DIR] [CLIPS]
#
# Defaults: bench/fleurs-id, 40 clips. Then:
#
#   cargo run --release --bin wer_bench -- \
#     --manifest bench/fleurs-id/manifest.tsv \
#     --model models/ggml-tiny.bin \
#     --model ~/Library/Caches/TrareonTranscribe/models/ggml-base.bin
#
# Why FLEURS and not Common Voice: FLEURS ships one transcript per clip
# with no per-speaker validation step, so the reference text is usable
# as-is. Common Voice needs its TSV joined and filtered by up-votes
# first, which is a second place for a mistake to hide.
#
# NOTE ON WHAT THESE NUMBERS MEAN: FLEURS is read speech recorded close
# to the microphone. A model that scores well here has not been shown to
# work on a four-person rapat over a laptop microphone. Publish the two
# separately and say which is which — see docs/WER-BENCH.md.
set -euo pipefail

TARGET="${1:-bench/fleurs-id}"
CLIPS="${2:-40}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 diperlukan untuk mengunduh korpus" >&2
  exit 1
fi

mkdir -p "$TARGET/audio"

# `datasets` streams FLEURS, so only the requested clips are downloaded
# rather than the whole 14 GB release.
python3 - "$TARGET" "$CLIPS" <<'PY'
import sys, pathlib, wave

target = pathlib.Path(sys.argv[1])
want = int(sys.argv[2])

try:
    from datasets import load_dataset
except ImportError:
    sys.exit(
        "pustaka `datasets` belum terpasang.\n"
        "  pip install datasets soundfile\n"
        "atau pakai manifes buatan sendiri (lihat docs/WER-BENCH.md)."
    )

print(f"mengunduh {want} klip FLEURS id_id (streaming)…", file=sys.stderr)
stream = load_dataset(
    "google/fleurs", "id_id", split="test", streaming=True, trust_remote_code=True
)

manifest = target / "manifest.tsv"
lines = [
    "# FLEURS id_id (CC-BY 4.0) — ucapan baca, bukan rapat.",
    "# Dibuat oleh scripts/fetch_wer_corpus.sh; jangan di-commit.",
]
written = 0
for row in stream:
    if written >= want:
        break
    reference = (row.get("transcription") or "").strip()
    audio = row.get("audio") or {}
    samples = audio.get("array")
    rate = audio.get("sampling_rate")
    if not reference or samples is None or not rate:
        continue

    name = f"{written:04d}.wav"
    path = target / "audio" / name
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(int(rate))
        wav.writeframes(b"".join(
            int(max(-1.0, min(1.0, float(s))) * 32767).to_bytes(2, "little", signed=True)
            for s in samples
        ))
    # Tab-separated, and the reference must not contain one.
    lines.append(f"audio/{name}\t{reference.replace(chr(9), ' ')}")
    written += 1

if written == 0:
    sys.exit("tidak ada klip yang bisa diambil")

manifest.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"{written} klip → {manifest}", file=sys.stderr)
PY

cat > "$TARGET/.gitignore" <<'EOF'
# Benchmark audio is never committed: it is someone else's, it is large,
# and a corpus in git drifts from the published one.
*
EOF

echo "selesai: $TARGET/manifest.tsv"
