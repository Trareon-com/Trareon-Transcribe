#!/usr/bin/env bash
# Capture the real release build's signature screens at three window sizes, in
# light and dark, into docs/screenshots/<label>/.
#
# This drives the actual binary on a real X11 display rather than rendering a
# golden: a golden proves the widget tree, a screenshot proves the app. Sprint
# 5 asked for both.
#
# Usage:
#   bash scripts/capture_screenshots.sh sprint5            # all sizes
#   bash scripts/capture_screenshots.sh sprint5 1280x800   # one size
#
# Requires: a running X11 session on DISPLAY (default :0), xdotool, ImageMagick.
# The app is launched with its log capped so a transcription flood cannot fill
# the disk.
set -euo pipefail

cd "$(dirname "$0")/.."

LABEL="${1:-sprint5}"
ONLY_SIZE="${2:-}"
OUT="docs/screenshots/$LABEL"
BUNDLE="build/linux/x64/release/bundle"
DISPLAY_ID="${DISPLAY_ID:-:0}"
LOG=/tmp/trareon_screenshots.log

[ -x "$BUNDLE/transcribe" ] || {
  echo "error: $BUNDLE/transcribe not built. Run: flutter build linux --release" >&2
  exit 1
}
command -v xdotool >/dev/null || { echo "error: xdotool missing" >&2; exit 1; }
command -v import >/dev/null || { echo "error: ImageMagick missing" >&2; exit 1; }

mkdir -p "$OUT"

SIZES=(900x600 1280x800 1920x1080)
[ -n "$ONLY_SIZE" ] && SIZES=("$ONLY_SIZE")

launch() {
  pkill -9 -x transcribe 2>/dev/null || true
  sleep 1
  (
    cd "$BUNDLE" &&
      DISPLAY="$DISPLAY_ID" GDK_BACKEND=x11 setsid sh -c \
        "./transcribe 2>&1 | head -c 5000000 > $LOG" </dev/null >/dev/null 2>&1 &
  )
  # Wait for a window that is not the 10x10 placeholder Flutter briefly shows.
  for _ in $(seq 1 40); do
    sleep 1
    for id in $(DISPLAY="$DISPLAY_ID" xdotool search --class transcribe 2>/dev/null); do
      geom=$(DISPLAY="$DISPLAY_ID" xdotool getwindowgeometry "$id" 2>/dev/null || true)
      case "$geom" in *"Geometry: 10x10"*) continue ;; esac
      [ -n "$geom" ] && { echo "$id"; return 0; }
    done
  done
  echo "error: no app window appeared; see $LOG" >&2
  return 1
}

resize() { # resize <win> <WxH>
  local w h
  w="${2%x*}"; h="${2#*x}"
  DISPLAY="$DISPLAY_ID" xdotool windowsize "$1" "$w" "$h"
  DISPLAY="$DISPLAY_ID" xdotool windowmove "$1" 0 0
  DISPLAY="$DISPLAY_ID" xdotool windowactivate "$1" 2>/dev/null || true
  sleep 2
}

shoot() { # shoot <win> <name>
  local path="$OUT/$2.png"
  DISPLAY="$DISPLAY_ID" timeout 20 import -window "$1" "$path"
  # The brief caps each committed PNG at 400 KB. These are flat-colour UI
  # screenshots, so a palette reduction is lossless to the eye and typically
  # takes a 1920x1080 capture from ~900 KB to ~120 KB.
  if [ "$(stat -c%s "$path")" -gt 400000 ]; then
    convert "$path" -strip -colors 256 PNG8:"$path"
  fi
  printf '  %-44s %s\n' "$2.png" "$(du -h "$path" | cut -f1)"
}

key() { DISPLAY="$DISPLAY_ID" xdotool key --window "$1" "$2"; sleep 1; }
click() { DISPLAY="$DISPLAY_ID" xdotool mousemove "$2" "$3" click 1; sleep 2; }

WIN=$(launch)
echo "window: $WIN"

for size in "${SIZES[@]}"; do
  echo "== $size =="
  resize "$WIN" "$size"
  shoot "$WIN" "main-idle-$size"
  # The shortcuts panel, which is also the proof the keycaps render.
  key "$WIN" "ctrl+slash"
  shoot "$WIN" "shortcuts-$size"
  key "$WIN" "ctrl+slash"
done

echo
echo "Screenshots in $OUT"
echo "The theme-specific and per-screen captures are driven interactively;"
echo "see docs/SPRINT-REPORTS.md for what each committed file shows."
pkill -9 -x transcribe 2>/dev/null || true
