#!/usr/bin/env bash
# Pre-release / daily Mac gate. Fail closed — do not ship if this is red.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PY="${ROOT}/.venv/bin/python"
if [[ ! -x "$PY" ]]; then PY="$(command -v python3)"; fi

export TRAREON_NO_RELAUNCH=1
export TRAREON_AUTO_YES=1

rm -f "${HOME}/Library/Application Support/TrareonTranscribe/instance.lock"
rm -f "${HOME}/Library/Application Support/TrareonTranscribe/control.sock"

echo "== 1/3 smoke_local_mac =="
"$PY" scripts/smoke_local_mac.py

echo "== 2/3 functional_drive_mac =="
"$PY" scripts/functional_drive_mac.py

echo "== 3/3 live_control_mac (visible app + socket) =="
"$PY" scripts/live_control_mac.py

echo "== MAC GATE GREEN =="
