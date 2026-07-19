#!/usr/bin/env bash
# Build/open a .app so Dock, menu bar, AND mic-permission dialogs say
# "Trareon Transcribe" — not "Python" / "Python 3.11".
#
# Critical: after launch we `exec` a Mach-O *copied into this .app*
# (not Homebrew's python path). TCC attributes mic access to the
# enclosing bundle name from Info.plist.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist-run/TrareonTranscribe.app"
VENV_PY="$ROOT/.venv/bin/python3"
EXE_NAME="TrareonTranscribe"
RUNTIME_NAME="runtime"
if [[ ! -x "$VENV_PY" ]]; then
  echo "Missing venv at $VENV_PY — run: python3.11 -m venv .venv && pip install -r requirements.txt" >&2
  exit 1
fi

REAL_PY=$("$VENV_PY" -c 'import os, sys; print(os.path.realpath(sys.executable))')
SITE_PACKAGES=$("$VENV_PY" -c 'import site; print(site.getsitepackages()[0])')
if [[ ! -f "$REAL_PY" ]]; then
  echo "Could not resolve base Python binary" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/assets/trareon-transcribe-icon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Relocatable enough for our use: same Cellar build, lives inside .app for TCC
cp "$REAL_PY" "$APP/Contents/MacOS/${RUNTIME_NAME}"
chmod +x "$APP/Contents/MacOS/${RUNTIME_NAME}"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Trareon Transcribe</string>
  <key>CFBundleDisplayName</key><string>Trareon Transcribe</string>
  <key>CFBundleIdentifier</key><string>com.trareon.transcribe.dev</string>
  <key>CFBundleVersion</key><string>0.1.0</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>${EXE_NAME}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Trareon Transcribe needs the microphone to record meeting audio for offline transcription.</string>
</dict>
</plist>
PLIST

ROOT_LIT=$(/usr/bin/python3 -c 'import sys; print(repr(sys.argv[1]))' "$ROOT")
SITE_LIT=$(/usr/bin/python3 -c 'import sys; print(repr(sys.argv[1]))' "$SITE_PACKAGES")
cat > "$APP/Contents/MacOS/${EXE_NAME}" <<EOF
#!/bin/bash
set -euo pipefail
ROOT=${ROOT_LIT}
SITE=${SITE_LIT}
DIR="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$ROOT"
export TRAREON_APP_BUNDLE=1
export PYTHONNOUSERSITE=1
export PYTHONPATH="\$ROOT:\$SITE\${PYTHONPATH:+:\$PYTHONPATH}"
# Process image stays under TrareonTranscribe.app → TCC / Dock use our name
exec "\$DIR/${RUNTIME_NAME}" "\$ROOT/main.py" "\$@"
EOF
chmod +x "$APP/Contents/MacOS/${EXE_NAME}"

/usr/bin/touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true

rm -f "$HOME/Library/Application Support/TrareonTranscribe/instance.lock"

if [[ $# -gt 0 ]]; then
  open "$APP" --args "$@"
else
  open "$APP"
fi
echo "Opened: $APP${*:+ ($*)}"
echo "Branding: Trareon Transcribe (menu bar + mic permission — not Python 3.11)"
echo "If mic was previously granted to 'Python', re-enable: System Settings → Privacy → Microphone → Trareon Transcribe"
