#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Compile Swift audio routing tool (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
    echo "Compiling audio routing tool..."
    swiftc -o setup/create_multi_output setup/create_multi_output.swift 2>/dev/null && \
        echo "✅ Audio routing tool compiled" || echo "⚠️ Swift compile skipped"
fi

python -m pip install -r requirements.txt
pyinstaller --noconfirm --clean packaging/trareon-transcribe.spec
echo "Artifacts in dist/"
