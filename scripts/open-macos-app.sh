#!/usr/bin/env bash
# Clear quarantine and open the packaged app (first launch after download).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# Prefer sibling .app (inside release zip) then Applications / build dist.
CANDIDATES=(
  "$DIR/Trareon Transcribe.app"
  "/Applications/Trareon Transcribe.app"
  "$DIR/../dist/Trareon Transcribe.app"
)
APP=""
for c in "${CANDIDATES[@]}"; do
  if [[ -d "$c" ]]; then
    APP="$c"
    break
  fi
done
if [[ -z "$APP" ]]; then
  echo "Trareon Transcribe.app not found next to this script." >&2
  exit 1
fi
xattr -cr "$APP" 2>/dev/null || true
open "$APP"
