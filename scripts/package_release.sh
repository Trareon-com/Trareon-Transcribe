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
  ZIP="$OUT/Trareon-Transcribe-${VERSION}-macos-${ARCH}.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  echo "Built: $ZIP"
elif [[ "$OS" == MINGW* || "$OS" == MSYS* || "$OS" == CYGWIN* || "$OS" == Windows_NT ]]; then
  EXE="$ROOT/dist/TrareonTranscribe.exe"
  ZIP="$OUT/Trareon-Transcribe-${VERSION}-windows-x64.zip"
  (cd "$ROOT/dist" && zip -9 "$ZIP" TrareonTranscribe.exe)
  echo "Built: $ZIP"
else
  echo "Unsupported OS: $OS" >&2
  exit 1
fi

ls -lh "$OUT"
echo "Upload with: gh release create v${VERSION} dist-release/* --title \"v${VERSION}\" --generate-notes"
