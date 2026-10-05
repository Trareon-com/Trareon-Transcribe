#!/usr/bin/env bash
#
# Builds the mostly-silent WAV the hallucination tests are measured on.
#
#   scripts/make_silence_fixture.sh                      # -> /tmp/silent5min.wav
#   scripts/make_silence_fixture.sh /path/out.wav
#
# Why this script exists
# ----------------------
# Sprint 4b's headline hallucination number — "zero hallucinated lines on a
# five-minute mostly-silent recording" — is only checkable if the recording
# can be rebuilt. It was originally made by hand in /tmp, which made the
# figure in docs/SPRINT-REPORTS.md impossible for anyone else to reproduce.
#
# The shape matters more than the content. Whisper does not answer silence
# with an empty string; it answers with the most frequent caption in its
# training data, which on Indonesian audio is `[MENGENI]`, `(Selamat
# tinggal)` or "Terima kasih telah menonton". Two short speech bursts
# separated by minutes of silence is the smallest recording that tells the
# two failure modes apart:
#
#   * invented lines in the silence  -> the VAD gate and the non-speech
#     filter are not doing their job;
#   * missing lines where the bursts are -> the gate is too aggressive and
#     the sprint's completeness guarantee is broken.
#
# A recording of pure silence can only catch the first.
#
# The speech is the first ~15 s of the Indonesian meeting clip used
# throughout these sprints, placed at 40 s and again at 210 s. Reusing one
# clip twice is deliberate: the two bursts are acoustically identical, so a
# transcript that reports one and not the other is a bug in the live path,
# not a difference in the audio.
#
# Needs: ffmpeg. No network.

set -euo pipefail

OUT=${1:-/tmp/silent5min.wav}
SPEECH=${TRAREON_SPEECH_CLIP:-/home/kali/trareon-sprints/rapat_id.mp3}

# Must match what the engine decodes to, or the measurement is really a
# resampler measurement: 16 kHz mono, which is Whisper's input rate.
RATE=16000
TOTAL_SECS=300
FIRST_AT=40
SECOND_AT=210
BURST_SECS=15

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg tidak ditemukan — skrip ini membutuhkannya" >&2
  exit 1
fi

if [ ! -f "$SPEECH" ]; then
  echo "klip bicara tidak ada: $SPEECH" >&2
  echo "setel TRAREON_SPEECH_CLIP ke sebuah rekaman Bahasa Indonesia" >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Digital silence, not a quiet room. This fixture tests the *filters*; room
# tone is what the real-session smoke test is for, and mixing the two into
# one fixture would mean a failure could not be attributed to either.
ffmpeg -v error -y \
  -f lavfi -i "anullsrc=channel_layout=mono:sample_rate=$RATE" \
  -t "$TOTAL_SECS" "$TMP/silence.wav"

ffmpeg -v error -y -i "$SPEECH" \
  -t "$BURST_SECS" -ac 1 -ar "$RATE" "$TMP/burst.wav"

# `adelay` on each copy, then mix. `amix` would halve the amplitude of the
# bursts (it divides by the number of inputs), so normalize=0 keeps them at
# the level the engine would really hear.
ffmpeg -v error -y \
  -i "$TMP/silence.wav" -i "$TMP/burst.wav" -i "$TMP/burst.wav" \
  -filter_complex "\
    [1:a]adelay=${FIRST_AT}s:all=1[a1]; \
    [2:a]adelay=${SECOND_AT}s:all=1[a2]; \
    [0:a][a1][a2]amix=inputs=3:normalize=0:duration=first[out]" \
  -map "[out]" -ac 1 -ar "$RATE" -c:a pcm_s16le "$TMP/out.wav"

# Same directory, then rename: a reader must never see a half-written WAV.
mv -f "$TMP/out.wav" "$OUT.partial"
mv -f "$OUT.partial" "$OUT"

echo "Selesai: $OUT"
echo "  panjang   : ${TOTAL_SECS} s @ ${RATE} Hz mono"
echo "  bicara    : ${BURST_SECS} s di ${FIRST_AT} s dan ${SECOND_AT} s"
echo
echo "Harapan: tepat dua kelompok baris, tidak ada baris di antara keduanya."
echo "Ukur jalur berkas dengan:"
echo "  cd rust_core && cargo run --release --bin transcribe_cli -- \\"
echo "    --audio $OUT --model ../models/ggml-tiny.bin"
