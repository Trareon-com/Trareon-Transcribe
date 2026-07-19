#!/usr/bin/env bash
# commit-msg hook: drop Cursor Co-authored-by trailers so they never hit GitHub Contributors.
set -euo pipefail
MSG_FILE="${1:-}"
[[ -n "$MSG_FILE" && -f "$MSG_FILE" ]] || exit 0
tmp="$(mktemp)"
# Drop Cursor / cursoragent co-author lines (keep everything else)
awk 'BEGIN{IGNORECASE=1} !/^[[:space:]]*Co-authored-by:[[:space:]]*Cursor[[:space:]]*</ && !/^[[:space:]]*Co-authored-by:[[:space:]]*<cursoragent@cursor\.com>/ {print}' "$MSG_FILE" > "$tmp"
# Trim trailing blank lines
awk 'NF{p=1} p{buf[NR]=$0} END{for(i=1;i<=NR;i++) if(buf[i]!="" || i<NR) { /* noop */ }}' "$tmp" >/dev/null 2>&1 || true
# simpler trim:
python3 - "$tmp" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
lines = text.splitlines()
while lines and not lines[-1].strip():
    lines.pop()
p.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
PY
mv "$tmp" "$MSG_FILE"
