#!/usr/bin/env bash
# Build a Debian/Ubuntu package (.deb) of Trareon Transcribe for amd64.
#
# Audit item 29: a tar.gz is not a Linux install story. Government and
# university buyers on Debian/Ubuntu expect `apt install ./file.deb`, which
# pulls the GTK/ALSA/PulseAudio runtime in for them and registers the app in
# the desktop menu.
#
# Layout follows the FHS as it applies to a self-contained Flutter bundle:
# the binary needs its `lib/` and `data/` siblings, so the whole bundle lives
# in /opt and /usr/bin gets a wrapper. That is the same shape Chrome, VS Code
# and Slack ship on Debian.
#
# The speech models are deliberately NOT in the package. ggml-base is 142 MB
# and large-v3-turbo-q5 is 548 MB; a 700 MB .deb is hostile to mirrors and to
# anyone on Indonesian home broadband, and the app already downloads models on
# first run into the user cache. Pass --with-models to override.
#
# Dependencies:
#   - dpkg-deb (dpkg-dev), fakeroot
#   - a completed `flutter build linux --release`, or Flutter + Rust to build
#
# Usage:
#   bash scripts/package_deb.sh [version] [--with-models]
#
# Output:
#   dist/trareon-transcribe_<version>_amd64.deb
#   dist/trareon-transcribe_<version>_amd64.deb.sha256
set -euo pipefail

cd "$(dirname "$0")/.."

WITH_MODELS=0
VERSION=""
for arg in "$@"; do
  case "$arg" in
    --with-models) WITH_MODELS=1 ;;
    *) VERSION="$arg" ;;
  esac
done
if [ -z "$VERSION" ]; then
  VERSION="$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d+ -f1)"
fi

PKG_NAME="trareon-transcribe"
APP_BINARY="transcribe"
INSTALL_DIR="/opt/$PKG_NAME"
BUILD_DIR="build/linux/x64/release/bundle"
DIST_DIR="dist"
DEB_PATH="$DIST_DIR/${PKG_NAME}_${VERSION}_amd64.deb"

for tool in dpkg-deb fakeroot; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "error: $tool not found (apt install dpkg-dev fakeroot)" >&2
    exit 1
  }
done

# ── Build, unless a bundle is already there ────────────────────────
if [ ! -x "$BUILD_DIR/$APP_BINARY" ]; then
  echo "==> No release bundle; building"
  (cd rust_core && cargo build --release --lib)
  flutter build linux --release
fi
[ -x "$BUILD_DIR/$APP_BINARY" ] || {
  echo "error: $BUILD_DIR/$APP_BINARY missing after build" >&2
  exit 1
}

# ── Stage the package root ─────────────────────────────────────────
STAGE="build/deb/$PKG_NAME-$VERSION"
echo "==> Staging package root at $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN"
mkdir -p "$STAGE$INSTALL_DIR"
mkdir -p "$STAGE/usr/bin"
mkdir -p "$STAGE/usr/share/applications"
mkdir -p "$STAGE/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$STAGE/usr/share/doc/$PKG_NAME"

cp -a "$BUILD_DIR/." "$STAGE$INSTALL_DIR/"
chmod 0755 "$STAGE$INSTALL_DIR/$APP_BINARY"

if [ "$WITH_MODELS" = "1" ]; then
  mkdir -p "$STAGE$INSTALL_DIR/models"
  for model in models/ggml-base.bin models/ggml-large-v3-turbo-q5_0.bin; do
    [ -f "$model" ] && cp "$model" "$STAGE$INSTALL_DIR/models/"
  done
else
  # A stale models/ directory copied out of a developer's build tree would
  # silently bloat the package.
  rm -rf "$STAGE$INSTALL_DIR/models"
fi

# ── /usr/bin wrapper ──────────────────────────────────────────────
# A wrapper rather than a symlink: Flutter resolves `lib/` and `data/`
# relative to the *resolved* executable path, and a symlinked binary on some
# distros resolves to /usr/bin, where neither exists.
cat > "$STAGE/usr/bin/$PKG_NAME" << EOF
#!/bin/sh
exec "$INSTALL_DIR/$APP_BINARY" "\$@"
EOF
chmod 0755 "$STAGE/usr/bin/$PKG_NAME"

# ── Desktop entry and icon ────────────────────────────────────────
cat > "$STAGE/usr/share/applications/$PKG_NAME.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Trareon Transcribe
GenericName=Transkripsi Rapat
Comment=Transkripsi rapat sepenuhnya offline (mikrofon + suara sistem)
Comment[en]=100% offline meeting transcription (microphone + system audio)
Exec=$PKG_NAME
Icon=$PKG_NAME
Terminal=false
Categories=AudioVideo;Audio;Office;
Keywords=transkripsi;rapat;notulen;offline;whisper;transcribe;meeting;
StartupWMClass=transcribe
EOF

if [ -f assets/logo.png ]; then
  cp assets/logo.png "$STAGE/usr/share/icons/hicolor/256x256/apps/$PKG_NAME.png"
elif [ -f assets/tray_icon.png ]; then
  cp assets/tray_icon.png "$STAGE/usr/share/icons/hicolor/256x256/apps/$PKG_NAME.png"
fi

[ -f LICENSE ] && cp LICENSE "$STAGE/usr/share/doc/$PKG_NAME/copyright"

# ── control ───────────────────────────────────────────────────────
# Depends is the GTK/audio runtime a Flutter Linux desktop bundle links
# against, with the alternatives Debian trixie / Ubuntu 24.04 renamed under
# the 64-bit time_t transition listed first.
INSTALLED_KB="$(du -sk "$STAGE" | cut -f1)"
cat > "$STAGE/DEBIAN/control" << EOF
Package: $PKG_NAME
Version: $VERSION
Section: sound
Priority: optional
Architecture: amd64
Maintainer: Trareon <hello@trareon.com>
Homepage: https://github.com/Trareon-com/Transcribe
Installed-Size: $INSTALLED_KB
Depends: libc6 (>= 2.34), libgtk-3-0 (>= 3.24) | libgtk-3-0t64 (>= 3.24),
 libglib2.0-0 (>= 2.66) | libglib2.0-0t64 (>= 2.66),
 libasound2 | libasound2t64, libpulse0, zlib1g (>= 1:1.2.11)
Recommends: libayatana-appindicator3-1 | libappindicator3-1
Description: Transkripsi rapat 100% offline (Indonesia-first)
 Trareon Transcribe merekam mikrofon dan suara sistem sekaligus, lalu
 mentranskripsikannya di perangkat Anda dengan Whisper. Tidak ada audio,
 transkrip, atau metadata yang dikirim ke internet.
 .
 Fitur: kamus istilah untuk singkatan dinas, ekspor Notulen Rapat resmi
 (DOCX/PDF), penanda poin penting saat merekam, ringkasan dengan template
 yang bisa disunting, dan transkrip ulang otomatis dengan model akurat.
EOF

# ── Build ─────────────────────────────────────────────────────────
mkdir -p "$DIST_DIR"
echo "==> Building $DEB_PATH"
fakeroot dpkg-deb --build "$STAGE" "$DEB_PATH"

echo "==> Generating checksum"
(cd "$DIST_DIR" && sha256sum "$(basename "$DEB_PATH")" > "$(basename "$DEB_PATH").sha256")

echo "==> Verifying"
dpkg-deb --info "$DEB_PATH" >/dev/null
dpkg-deb --contents "$DEB_PATH" >/dev/null

echo "Done!"
echo "  deb:  $DEB_PATH"
echo "  size: $(du -h "$DEB_PATH" | cut -f1)"
echo
echo "Install with:  sudo apt install ./$DEB_PATH"
