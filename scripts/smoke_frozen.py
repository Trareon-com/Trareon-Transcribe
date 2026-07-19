#!/usr/bin/env python3
"""Smoke checks for frozen / source builds (CI + local)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def main() -> int:
    from engine.audio_probe import probe_audio
    from engine.stt import find_whisper_binary

    audio = probe_audio()
    print("audio:", audio.ok, audio.message, "devices=", audio.device_count)
    if not audio.ok:
        print("FAIL: audio probe", file=sys.stderr)
        return 1

    binary = find_whisper_binary()
    print("whisper_binary:", binary)
    # Binary may be absent in CI source smoke; only require when --require-whisper
    if "--require-whisper" in sys.argv and binary is None:
        print("FAIL: whisper-cli not found", file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
