#!/usr/bin/env bash
# Render the master app icon (assets/branding/app-icon.svg) to every size the
# three platforms need. Run from the repo root after editing the SVG.
#
# Requires ImageMagick (`convert`). Its built-in MSVG renderer handles the
# master's single path plus four rects; nothing in the file needs librsvg.
set -euo pipefail

cd "$(dirname "$0")/.."

SRC=assets/branding/app-icon.svg
MARK=assets/branding/wordmark.svg
[ -f "$SRC" ] || { echo "missing $SRC" >&2; exit 1; }

render() { # render <size> <out>
  convert -background none "$SRC" \
    -resize "${1}x${1}" -strip "PNG32:$2"
}

echo "macOS .icns sources"
MAC=macos/Runner/Assets.xcassets/AppIcon.appiconset
for s in 16 32 64 128 256 512 1024; do
  render "$s" "$MAC/app_icon_$s.png"
done

echo "Windows .ico (16..256 in one file)"
TMP=$(mktemp -d)
for s in 16 24 32 48 64 128 256; do render "$s" "$TMP/ico_$s.png"; done
convert "$TMP/ico_16.png" "$TMP/ico_24.png" "$TMP/ico_32.png" \
        "$TMP/ico_48.png" "$TMP/ico_64.png" "$TMP/ico_128.png" \
        "$TMP/ico_256.png" windows/runner/resources/app_icon.ico

echo "Linux hicolor PNGs"
mkdir -p linux/icons
for s in 16 24 32 48 64 128 256 512; do
  render "$s" "linux/icons/trareon-transcribe-$s.png"
done

echo "In-app assets"
render 512 assets/logo.png
# The tray icon is drawn at 16-22 px in a system tray that may be light or
# dark, so it is the flat mark on transparency rather than the teal tile.
if [ -f "$MARK" ]; then
  convert -background none "$MARK" -resize 64x64 -strip \
    PNG32:assets/tray_icon.png
  convert -background none "$MARK" -resize 32x32 -strip \
    assets/tray_icon.ico
fi

rm -rf "$TMP"
echo "done"
