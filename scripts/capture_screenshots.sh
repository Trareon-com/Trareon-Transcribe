#!/usr/bin/env bash
# Capture the real release build's signature screens, light and dark, at the
# three window sizes the design system names, into docs/screenshots/<label>/.
#
# This drives the actual binary rather than rendering a golden: a golden proves
# the widget tree, a screenshot proves the app.
#
# The host's physical display is 1360x768, so the captures run on an Xvfb
# display sized to the target. It is the same release binary, and a virtual
# display is the only way to photograph a window larger than the screen. Pass
# DISPLAY_MODE=real to drive the live session on :0 instead (useful for
# checking the window manager's own decorations).
#
# The theme is set by rewriting the persisted setting before each launch,
# because toggling it through the UI means ten brittle synthetic clicks.
#
# Usage:
#   bash scripts/capture_screenshots.sh sprint5
#   bash scripts/capture_screenshots.sh sprint5 1280x800
#   bash scripts/capture_screenshots.sh sprint5 1280x800 dark
set -euo pipefail

cd "$(dirname "$0")/.."

LABEL="${1:-sprint5}"
ONLY_SIZE="${2:-}"
ONLY_THEME="${3:-}"
OUT="docs/screenshots/$LABEL"
BUNDLE="build/linux/x64/release/bundle"
LOG=/tmp/trareon_screenshots.log
SETTINGS="$HOME/.config/TrareonTranscribe/settings.json"
XVFB_DISPLAY="${XVFB_DISPLAY:-:77}"

[ -x "$BUNDLE/transcribe" ] || {
  echo "error: $BUNDLE/transcribe not built. Run: flutter build linux --release" >&2
  exit 1
}
for tool in xdotool import convert python3; do
  command -v "$tool" >/dev/null || { echo "error: $tool missing" >&2; exit 1; }
done

mkdir -p "$OUT"

SIZES=(900x600 1280x800 1920x1080)
if [ -n "$ONLY_SIZE" ]; then SIZES=("$ONLY_SIZE"); fi
THEMES=(Light Dark)
if [ -n "$ONLY_THEME" ]; then THEMES=("$ONLY_THEME"); fi

ORIGINAL_SETTINGS=""
if [ -f "$SETTINGS" ]; then
  ORIGINAL_SETTINGS=$(cat "$SETTINGS")
fi

XVFB_PID=""
cleanup() {
  pkill -9 -x transcribe 2>/dev/null || true
  if [ -n "$XVFB_PID" ]; then
    kill "$XVFB_PID" 2>/dev/null || true
  fi
  # Put the user's own theme back: this script is a tool, not a setting.
  if [ -n "$ORIGINAL_SETTINGS" ]; then
    printf '%s' "$ORIGINAL_SETTINGS" > "$SETTINGS"
  fi
}
trap cleanup EXIT

set_theme() { # set_theme <Light|Dark>
  [ -f "$SETTINGS" ] || return 0
  python3 - "$SETTINGS" "$1" <<'PY'
import json, sys
path, theme = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
data['theme'] = theme
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
PY
}

# Sets DISP. Same reason as launch: the Xvfb it starts would hold a command
# substitution's pipe open.
DISP=""
start_display() { # start_display <WxH>
  if [ "${DISPLAY_MODE:-virtual}" = real ]; then
    DISP=":0"
    return
  fi
  local w h
  w="${1%x*}"; h="${1#*x}"
  if [ -n "$XVFB_PID" ]; then
    kill "$XVFB_PID" 2>/dev/null || true
    sleep 1
  fi
  Xvfb "$XVFB_DISPLAY" -screen 0 "${w}x${h}x24" >/dev/null 2>&1 &
  XVFB_PID=$!
  sleep 3
  DISP="$XVFB_DISPLAY"
}

# Sets WIN to the app's window id. Deliberately *not* a function that echoes
# the id: the app is launched in the background, and inside a `$(...)` the
# substitution blocks until every process holding the pipe exits, which for a
# GUI app means forever.
WIN=""
launch() { # launch <display> <width> <height>
  pkill -9 -x transcribe 2>/dev/null || true
  sleep 1
  (
    cd "$BUNDLE" &&
      DISPLAY="$1" GDK_BACKEND=x11 setsid sh -c \
        "./transcribe 2>&1 | head -c 5000000 > $LOG" </dev/null >/dev/null 2>&1 &
  ) </dev/null >/dev/null 2>&1
  # Match on the window title rather than the class: the class also matches
  # the 10x10 and 16x16 helper windows GTK creates.
  WIN=""
  for _ in $(seq 1 45); do
    sleep 1
    WIN=$(DISPLAY="$1" xdotool search --name '^Trareon Transcribe$' 2>/dev/null \
      | head -1 || true)
    if [ -n "$WIN" ]; then
      # The app restores its remembered geometry, which is almost never the
      # size being captured, so pin it to the screen and to the origin.
      DISPLAY="$1" xdotool windowmove "$WIN" 0 0 2>/dev/null || true
      DISPLAY="$1" xdotool windowsize "$WIN" "$2" "$3" 2>/dev/null || true
      # The window is mapped several seconds before Impeller paints the first
      # frame; capturing immediately gets a black rectangle.
      sleep 8
      return 0
    fi
  done
  echo "error: no app window appeared; see $LOG" >&2
  return 1
}

shoot() { # shoot <display> <win> <name>
  local path="$OUT/$3.png"
  DISPLAY="$1" timeout 30 import -window "$2" "$path"
  # A capture of an unpainted window is a near-empty PNG. Retry once rather
  # than committing a black rectangle.
  if [ "$(stat -c%s "$path")" -lt 8000 ]; then
    sleep 6
    DISPLAY="$1" timeout 30 import -window "$2" "$path"
  fi
  # The brief caps each committed PNG at 400 KB. These are flat-colour UI
  # captures, so a palette reduction is invisible and takes a 1920x1080 shot
  # from roughly 900 KB to 150.
  if [ "$(stat -c%s "$path")" -gt 400000 ]; then
    convert "$path" -strip -colors 256 PNG8:"$path"
  fi
  printf '  %-40s %8s\n' "$3.png" "$(du -h "$path" | cut -f1)"
}

# Xvfb has no window manager, so nothing sets the input focus for us and a
# synthetic key event has nowhere to land. Setting it explicitly first is what
# makes keyboard-driven states capturable at all.
key() {
  DISPLAY="$1" xdotool windowfocus "$2" 2>/dev/null || true
  DISPLAY="$1" xdotool key --clearmodifiers --window "$2" "$3"
  sleep 2
}
click() { DISPLAY="$1" xdotool mousemove --window "$2" "$3" "$4" click 1; sleep 3; }

for size in "${SIZES[@]}"; do
  for theme in "${THEMES[@]}"; do
    low=$(echo "$theme" | tr 'A-Z' 'a-z')
    echo "== $size $low =="
    set_theme "$theme"
    start_display "$size"
    W="${size%x*}"
    H="${size#*x}"
    launch "$DISP" "$W" "$H"

    shoot "$DISP" "$WIN" "main-idle-$size-$low"

    # The shortcuts panel, from the footer hint. Also the proof the keycaps
    # render.
    click "$DISP" "$WIN" $((W - 80)) $((H - 16))
    shoot "$DISP" "$WIN" "shortcuts-$size-$low"

    # The sidebar collapsed to its icon rail. Relaunched first, because the
    # shortcuts panel is still open.
    launch "$DISP" "$W" "$H"
    key "$DISP" "$WIN" "ctrl+shift+s"
    shoot "$DISP" "$WIN" "sidebar-rail-$size-$low"

    # The transcript player, reached by opening the first session in the
    # sidebar. The row sits just below the search field and the group header.
    click "$DISP" "$WIN" 130 215
    shoot "$DISP" "$WIN" "player-$size-$low"

    # Settings, the last row of the sidebar footer.
    launch "$DISP" "$W" "$H"
    click "$DISP" "$WIN" 130 $((H - 30))
    shoot "$DISP" "$WIN" "settings-$size-$low"
  done
done

echo
echo "Screenshots in $OUT"
