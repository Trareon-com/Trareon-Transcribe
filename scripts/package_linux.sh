#!/usr/bin/env bash
# Build and package Trareon Transcribe as an AppImage for Linux x86_64.
#
# Dependencies:
#   - Flutter SDK (with Linux desktop support)
#   - Rust toolchain (x86_64-unknown-linux-gnu)
#   - appimagetool (optional, for AppImage creation)
#   - fakeroot (optional, for proper permissions)
#
# Usage:
#   bash scripts/package_linux.sh [version]
#
# Output:
#   dist/trareon-transcribe-<version>-linux-x86_64.AppImage
#   dist/trareon-transcribe-<version>-linux-x86_64.tar.gz
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d+ -f1)}"
APP_NAME="Trareon Transcribe"
APP_BINARY="transcribe"
BUILD_DIR="build/linux/x64/release/bundle"
DIST_DIR="dist"
APPIMAGE_NAME="trareon-transcribe-${VERSION}-linux-x86_64"
APPIMAGE_PATH="$DIST_DIR/${APPIMAGE_NAME}.AppImage"
TAR_PATH="$DIST_DIR/${APPIMAGE_NAME}.tar.gz"

# ── Build Rust library ─────────────────────────────────────────────
echo "==> Building rust_core for x86_64-unknown-linux-gnu"
(cd rust_core && cargo build --release --lib)

# ── Build Flutter Linux release ────────────────────────────────────
echo "==> Building Flutter Linux release"
flutter build linux --release

if [ ! -d "$BUILD_DIR" ]; then
  echo "error: $BUILD_DIR not found after build" >&2
  exit 1
fi

# ── Bundle models ──────────────────────────────────────────────────
MODELS_DIR="$BUILD_DIR/models"
echo "==> Bundling models into $MODELS_DIR"
mkdir -p "$MODELS_DIR"
if [ -f models/ggml-base.bin ]; then
  cp models/ggml-base.bin "$MODELS_DIR/"
  echo "    → base (142 MB) bundled"
else
  echo "    ⚠️  models/ggml-base.bin not found — skipping"
fi
if [ -f models/ggml-large-v3-turbo-q5_0.bin ]; then
  cp models/ggml-large-v3-turbo-q5_0.bin "$MODELS_DIR/"
  echo "    → large-v3-turbo-q5 (548 MB) bundled"
else
  echo "    ⚠️  models/ggml-large-v3-turbo-q5_0.bin not found — skipping"
fi

# ── Create AppDir structure ────────────────────────────────────────
APPDIR="$BUILD_DIR/AppDir"
echo "==> Creating AppDir at $APPDIR"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Copy binary and libraries
cp -r "$BUILD_DIR/"* "$APPDIR/usr/bin/" 2>/dev/null || true
# Copy individual files, not directories that would cause recursive copy
for item in "$BUILD_DIR/"*; do
  if [ -f "$item" ]; then
    cp "$item" "$APPDIR/usr/bin/"
  fi
done
chmod +x "$APPDIR/usr/bin/$APP_BINARY"

# Create .desktop file
cat > "$APPDIR/usr/share/applications/trareon-transcribe.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=100% offline meeting transcriber
Exec=$APP_BINARY
Icon=trareon-transcribe
Type=Application
Categories=AudioVideo;Audio;
Keywords=transcribe;meeting;offline;whisper;
EOF

# Copy icon (if exists)
if [ -f assets/logo.png ]; then
  cp assets/logo.png "$APPDIR/usr/share/icons/hicolor/256x256/apps/trareon-transcribe.png"
  cp assets/logo.png "$APPDIR/trareon-transcribe.png"
elif [ -f assets/tray_icon.png ]; then
  cp assets/tray_icon.png "$APPDIR/usr/share/icons/hicolor/256x256/apps/trareon-transcribe.png"
  cp assets/tray_icon.png "$APPDIR/trareon-transcribe.png"
else
  echo "    ⚠️  No icon found — AppImage may not have icon"
fi

# Create symlinks for AppImage
ln -sf "usr/bin/$APP_BINARY" "$APPDIR/$APP_BINARY"
ln -sf "usr/share/applications/trareon-transcribe.desktop" "$APPDIR/trareon-transcribe.desktop"
ln -sf "usr/share/icons/hicolor/256x256/apps/trareon-transcribe.png" "$APPDIR/trareon-transcribe.png"

# ── Create tar.gz ─────────────────────────────────────────────────
mkdir -p "$DIST_DIR"
echo "==> Creating $TAR_PATH"
tar -czf "$TAR_PATH" -C "$BUILD_DIR" .

# ── Create AppImage (if appimagetool is available) ────────────────
if command -v appimagetool &> /dev/null; then
  echo "==> Creating $APPIMAGE_PATH"
  ARCH=x86_64 appimagetool "$APPDIR" "$APPIMAGE_PATH"
else
  echo "==> appimagetool not found — skipping AppImage creation"
  echo "    Install with: sudo apt install appimagetool"
  echo "    Or download from: https://github.com/AppImage/AppImageKit/releases"
  echo "    Then run: ARCH=x86_64 appimagetool $APPDIR $APPIMAGE_PATH"
fi

# ── Generate checksums ────────────────────────────────────────────
echo "==> Generating checksums"
if [ -f "$TAR_PATH" ]; then
  sha256sum "$TAR_PATH" > "$TAR_PATH.sha256"
fi
if [ -f "$APPIMAGE_PATH" ]; then
  sha256sum "$APPIMAGE_PATH" > "$APPIMAGE_PATH.sha256"
fi

echo "Done!"
echo "  tar.gz:    $TAR_PATH"
echo "  AppImage:  $APPIMAGE_PATH (if appimagetool was available)"