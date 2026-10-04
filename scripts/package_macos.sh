#!/usr/bin/env bash
# Build a Universal Binary (arm64 + x86_64), ad-hoc sign, and package
# Trareon Transcribe as a .dmg for macOS.
#
# Signing depends on `MACOS_SIGN_IDENTITY`:
#
# * unset (the ADR-12 default) — ad-hoc signing (`codesign --sign -`), which
#   costs $0 and needs no Apple Developer account, at the price of an "Apple
#   cannot verify this app" Gatekeeper warning on first launch (documented
#   for users at download time).
# * set to a Developer ID Application identity — a hardened-runtime,
#   timestamped signature the notary service will accept. The release
#   workflow sets it only when the Apple secrets are configured and performs
#   the notarize/staple step itself; see DISTRIBUTION.md.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d+ -f1)}"
APP_NAME="Trareon Transcribe"
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="dist"
DMG_PATH="$DIST_DIR/transcribe-${VERSION}-macos.dmg"

# ── Add cross-compilation targets if missing ──────────────────────────
echo "==> Ensuring cross-compilation targets"
rustup target add aarch64-apple-darwin x86_64-apple-darwin

# ── Build Rust library for both architectures ─────────────────────────
echo "==> Building rust_core for aarch64-apple-darwin"
(cd rust_core && cargo build --release --target aarch64-apple-darwin --lib)

echo "==> Building rust_core for x86_64-apple-darwin"
(cd rust_core && cargo build --release --target x86_64-apple-darwin --lib --no-default-features)  # ort: no prebuilt for macOS Intel → energy VAD fallback

echo "==> Creating universal librust_core.dylib"
mkdir -p rust_core/target/universal
lipo -create \
  rust_core/target/aarch64-apple-darwin/release/librust_core.dylib \
  rust_core/target/x86_64-apple-darwin/release/librust_core.dylib \
  -output rust_core/target/universal/librust_core.dylib

# ── Build Flutter macOS release ───────────────────────────────────────
# The Xcode build phase builds Rust for native arch and copies it into
# the bundle. We'll overwrite it with the universal dylib afterwards.
echo "==> Building Flutter macOS release"
flutter build macos --release

if [ ! -d "$APP_PATH" ]; then
  echo "error: $APP_PATH not found after build" >&2
  exit 1
fi

# ── Replace native-arch dylib with universal dylib ────────────────────
FRAMEWORKS="$APP_PATH/Contents/Frameworks"
echo "==> Copying universal librust_core.dylib into bundle"
cp rust_core/target/universal/librust_core.dylib "$FRAMEWORKS/"

# ── Bundle models ──────────────────────────────────────────────
# App Sandbox blocks reading arbitrary paths outside the bundle/container,
# so bundled models must physically live inside Contents/Resources —
# lib/state/models.dart's modelPathForId() looks there first.
RESOURCES="$APP_PATH/Contents/Resources"
echo "==> Bundling models into $RESOURCES/models"
mkdir -p "$RESOURCES/models"
if [ -f models/ggml-base.bin ]; then
  cp models/ggml-base.bin "$RESOURCES/models/"
  echo "    → base (142 MB) bundled"
else
  echo "    ⚠️ models/ggml-base.bin not found — skipping"
fi
if [ -f models/ggml-large-v3-turbo-q5_0.bin ]; then
  cp models/ggml-large-v3-turbo-q5_0.bin "$RESOURCES/models/"
  echo "    → large-v3-turbo-q5 (548 MB) bundled"
else
  echo "    ⚠️ models/ggml-large-v3-turbo-q5_0.bin not found — skipping"
fi

# ── Signing ───────────────────────────────────────────────────────────
#
# Two modes, chosen by whether a Developer ID identity was supplied:
#
# * `MACOS_SIGN_IDENTITY` set — a real Developer ID Application signature
#   with the hardened runtime and a secure timestamp. Both are *required*
#   for the notary service to accept the bundle; notarizing an ad-hoc
#   signature fails with "The signature of the binary is invalid".
# * unset — ad-hoc, per ADR-12: $0 and no Apple Developer account, at the
#   price of a Gatekeeper warning on first launch.
#
# The entitlements file grants the microphone and the audio-input device,
# which the hardened runtime otherwise denies outright.
if [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
  echo "==> Signing $APP_PATH with Developer ID"
  ENTITLEMENTS="$(mktemp -d)/entitlements.plist"
  cat > "$ENTITLEMENTS" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.device.audio-input</key>
  <true/>
  <key>com.apple.security.cs.disable-library-validation</key>
  <true/>
</dict>
</plist>
PLIST
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$MACOS_SIGN_IDENTITY" "$APP_PATH"
  rm -rf "$(dirname "$ENTITLEMENTS")"
  codesign --verify --strict --verbose=2 "$APP_PATH"
else
  echo "==> Ad-hoc signing $APP_PATH (no MACOS_SIGN_IDENTITY)"
  codesign --force --deep --sign - "$APP_PATH"
  codesign --verify --verbose "$APP_PATH"
fi

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

# ── DMG creation ──────────────────────────────────────────────────────
# `hdiutil create -srcfolder X -format UDZO` is a compound operation: it
# builds a temporary read/write image, attaches it, copies X in, detaches,
# then compresses. On CI it failed with `create failed - Resource busy`,
# which is the detach step losing a race against whatever still holds a
# file on the freshly mounted volume (Spotlight's `mds` indexing the ~690 MB
# of models we just bundled is the usual culprit on GitHub runners).
#
# Three changes, cheapest first:
#  1. Stage into $TMPDIR (`/var/folders/...`), which is excluded from
#     Spotlight indexing, instead of imaging the live Xcode build tree.
#  2. Split create and compress: build UDRW, then `hdiutil convert` to UDZO.
#     Each step is simple enough to retry meaningfully.
#  3. Retry the create a bounded number of times, detaching any volume left
#     attached by a failed attempt first — otherwise the retry trips over
#     the previous attempt's mount and fails identically.
VOLNAME="TrareonTranscribe"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/trareon-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

echo "==> Staging app bundle in $STAGING"
# ditto (not cp) preserves the code signature we just applied.
ditto "$APP_PATH" "$STAGING/$APP_NAME.app"

detach_stale_volumes() {
  hdiutil info | awk -v vol="/Volumes/$VOLNAME" '$0 ~ vol {print $1}' | while read -r dev; do
    echo "    detaching stale $dev"
    hdiutil detach "$dev" -force || true
  done
}

RW_DMG="$STAGING/$VOLNAME-rw.dmg"
attempt=1
max_attempts=3
until hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING/$APP_NAME.app" \
  -fs HFS+ -format UDRW -ov "$RW_DMG"; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "error: hdiutil create failed after $max_attempts attempts" >&2
    exit 1
  fi
  echo "    hdiutil create failed (attempt $attempt/$max_attempts) — retrying"
  detach_stale_volumes
  sleep 15
  attempt=$((attempt + 1))
done

echo "==> Compressing to $DMG_PATH"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_PATH"

echo "==> Generating checksum"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "==> Verifying signature on packaged app"
codesign -dv "$APP_PATH" 2>&1

echo "Done: $DMG_PATH"
