#!/usr/bin/env bash
# Build shareable zip(s) under dist-release/ (not committed to git).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${1:-$("$ROOT/.venv/bin/python" -c 'from config.version import __version__; print(__version__)' 2>/dev/null || echo 0.1.0)}"
OUT="$ROOT/dist-release"
rm -rf "$OUT"
mkdir -p "$OUT"

PY="${ROOT}/.venv/bin/python"
if [[ ! -x "$PY" ]]; then
  PY=python3
fi
"$PY" -m pip install -q -r requirements.txt
"$PY" -m PyInstaller --noconfirm --clean packaging/trareon-transcribe.spec

ARCH="$(uname -m)"
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
  APP="$ROOT/dist/Trareon Transcribe.app"
  if [[ ! -d "$APP" ]]; then
    echo "Missing $APP" >&2
    exit 1
  fi
  # Ad-hoc sign by default; Developer ID + notary if env set.
  if [[ -n "${APPLE_CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --options runtime --sign "$APPLE_CODESIGN_IDENTITY" "$APP"
    if [[ -n "${APPLE_NOTARY_PROFILE:-}" ]]; then
      NOTARY_ZIP="$OUT/_notarize.zip"
      ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
      xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait
      xcrun stapler staple "$APP"
      rm -f "$NOTARY_ZIP"
    fi
  else
    codesign --force --deep --sign - "$APP" || true
  fi
  STAGE="$OUT/stage-macos"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  ditto "$APP" "$STAGE/Trareon Transcribe.app"
  cp "$ROOT/scripts/open-macos-app.sh" "$STAGE/open-macos-app.sh"
  cp "$ROOT/scripts/Open Trareon Transcribe.command" "$STAGE/Open Trareon Transcribe.command"
  chmod +x "$STAGE/open-macos-app.sh" "$STAGE/Open Trareon Transcribe.command"
  ZIP="$OUT/Trareon-Transcribe-${VERSION}-macos-${ARCH}.zip"
  (cd "$STAGE" && zip -ry "$ZIP" "Trareon Transcribe.app" open-macos-app.sh "Open Trareon Transcribe.command")
  rm -rf "$STAGE"
  echo "Built: $ZIP"
elif [[ "$OS" == MINGW* || "$OS" == MSYS* || "$OS" == CYGWIN* || "$OS" == Windows_NT ]]; then
  ZIP="$OUT/Trareon-Transcribe-${VERSION}-windows-x64.zip"
  (cd "$ROOT/dist" && zip -9 "$ZIP" TrareonTranscribe.exe)
  echo "Built: $ZIP"
else
  echo "Unsupported OS: $OS" >&2
  exit 1
fi

ls -lh "$OUT"
echo "Upload with: gh release create v${VERSION} dist-release/* --title \"v${VERSION}\" --generate-notes"
