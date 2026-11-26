#!/usr/bin/env bash
# Puts the pinned CrispASR CLI into an app bundle at
# Contents/Helpers/crispasr/, where rust_core's `resolve_crispasr_cli_path`
# looks first.
#
# The "Eksperimental" model tiers (Qwen3-ASR) run through this CLI as a
# subprocess. Downloading a model only fetches its GGUF, so without the CLI
# in the bundle those tiers fail on every fresh install.
#
# usage: bundle_crispasr.sh <path/to/App.app> [arch ...]
#   arch: arm64 | x86_64. Default: this machine's arch. Two archs produce
#   universal (lipo) binaries, which is what package_macos.sh asks for.
#
# Signing follows the rest of the build: MACOS_SIGN_IDENTITY, else ad-hoc.
# The CLI is signed with the sandbox *inherit* entitlements so it runs
# inside the app's sandbox when the app spawns it.
set -euo pipefail

VERSION="0.8.43"
BASE_URL="https://github.com/CrispStrobe/CrispASR/releases/download/v${VERSION}"

tarball_for() {
  case "$1" in
    arm64) echo "crispasr-macos-arm64.tar.gz" ;;
    x86_64) echo "crispasr-macos-x86_64.tar.gz" ;;
    *) echo "error: unsupported arch '$1'" >&2; exit 1 ;;
  esac
}

# Digests from the GitHub release asset metadata, checked against a real
# download. A changed upstream file must fail the build, not ship.
sha256_for() {
  case "$1" in
    arm64) echo "5c13fbbc12eb45c3f01823a6bbfbbb22e0682bc76c6b78a0d9511da1aaf88831" ;;
    x86_64) echo "26c7ed772472330a354f08122a59107fff6830f9e7a784df8ab9c1d7dfc4b023" ;;
  esac
}

APP="${1:?usage: bundle_crispasr.sh <App.app> [arch ...]}"
shift
if [ "$#" -eq 0 ]; then
  set -- "$(uname -m)"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE="${CRISPASR_CACHE_DIR:-$HOME/Library/Caches/trareon-build/crispasr-${VERSION}}"
DEST="$APP/Contents/Helpers/crispasr"
mkdir -p "$CACHE"

# Downloads (once) and unpacks the release for one arch; prints the folder.
fetch() {
  local arch="$1" tarball sha archive dir
  tarball="$(tarball_for "$arch")"
  sha="$(sha256_for "$arch")"
  archive="$CACHE/$tarball"
  dir="$CACHE/$arch"
  if [ ! -f "$archive" ] || [ "$(shasum -a 256 "$archive" | cut -d' ' -f1)" != "$sha" ]; then
    echo "==> Downloading CrispASR $VERSION ($arch)" >&2
    curl -fsSL --retry 3 -o "$archive.part" "$BASE_URL/$tarball"
    local got
    got="$(shasum -a 256 "$archive.part" | cut -d' ' -f1)"
    if [ "$got" != "$sha" ]; then
      rm -f "$archive.part"
      echo "error: $tarball checksum mismatch (expected $sha, got $got)" >&2
      exit 1
    fi
    mv "$archive.part" "$archive"
    rm -rf "$dir"
  fi
  if [ ! -f "$dir/crispasr" ]; then
    rm -rf "$dir" && mkdir -p "$dir"
    tar -xzf "$archive" -C "$dir" --strip-components 1
  fi
  echo "$dir"
}

dirs=()
for arch in "$@"; do
  dirs+=("$(fetch "$arch")")
done

rm -rf "$DEST"
mkdir -p "$DEST"
for file in crispasr libc2pa_c.dylib; do
  if [ "${#dirs[@]}" -eq 1 ]; then
    cp "${dirs[0]}/$file" "$DEST/$file"
  else
    inputs=()
    for d in "${dirs[@]}"; do inputs+=("$d/$file"); done
    lipo -create "${inputs[@]}" -output "$DEST/$file"
  fi
  chmod 755 "$DEST/$file"
done
# MIT; the notices cover its bundled third-party code (c2pa, ggml, ...).
cp "${dirs[0]}/LICENSE" "$DEST/LICENSE"
cp "${dirs[0]}/THIRD_PARTY_NOTICES.txt" "$DEST/THIRD_PARTY_NOTICES.txt"

IDENTITY="${MACOS_SIGN_IDENTITY:--}"
SIGN_FLAGS=(--force --sign "$IDENTITY")
if [ "$IDENTITY" != "-" ]; then
  # Notarization requires the hardened runtime and a secure timestamp.
  SIGN_FLAGS+=(--options runtime --timestamp)
fi
codesign "${SIGN_FLAGS[@]}" "$DEST/libc2pa_c.dylib"
codesign "${SIGN_FLAGS[@]}" --entitlements "$SCRIPT_DIR/../Runner/CrispASRHelper.entitlements" "$DEST/crispasr"
echo "==> Bundled CrispASR $VERSION ($*) into $DEST"
