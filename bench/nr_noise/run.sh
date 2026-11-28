#!/bin/bash
# Issue #69 — NR on vs off, 20 FLEURS-id dev utterances x 4 conditions
set -u
cd "$(dirname "$0")"
BIN=${BIN:-../../rust_core/target/release/transcribe_cli}
MODEL=${MODEL:?set MODEL to a ggml-small.bin path}
for v in clean fan5 babble5 pink5; do
  for nr in off on; do
    out=out/$v-$nr
    if [ "$(ls $out 2>/dev/null | wc -l)" -ge 20 ]; then echo "$v $nr skip(done)"; continue; fi
    rm -rf $out; mkdir -p $out
    flag=""; [ $nr = on ] && flag="--denoise"
    s=$(date +%s)
    $BIN --batch "set/$v/[01][0-9].wav" --output $out --model $MODEL --language id --format txt $flag > $out.log 2>&1
    echo "$v $nr exit=$? $(( $(date +%s)-s ))s files=$(ls $out | wc -l)"
  done
done
.venv/bin/python score.py
