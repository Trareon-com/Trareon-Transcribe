#!/usr/bin/env bash
# commit-msg hook: drop Cursor Co-authored-by trailers so they never hit GitHub Contributors.
set -euo pipefail
MSG_FILE="${1:-}"
[[ -n "$MSG_FILE" && -f "$MSG_FILE" ]] || exit 0
python3 - "$MSG_FILE" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
pat = re.compile(
    r"^Co-authored-by:\s*(?:Cursor\s*<[^>]*>|<cursoragent@cursor\.com>)\s*$",
    re.IGNORECASE | re.MULTILINE,
)
cleaned = pat.sub("", text)
lines = cleaned.splitlines()
while lines and not lines[-1].strip():
    lines.pop()
path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
PY
