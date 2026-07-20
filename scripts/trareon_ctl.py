#!/usr/bin/env python3
"""Drive a running Trareon app that was launched with --control.

Examples:
  TRAREON_NO_RELAUNCH=1 .venv/bin/python main.py --demo --control
  .venv/bin/python scripts/trareon_ctl.py status
  .venv/bin/python scripts/trareon_ctl.py theme
  .venv/bin/python scripts/trareon_ctl.py mode --label Webinar
  .venv/bin/python scripts/trareon_ctl.py start
  .venv/bin/python scripts/trareon_ctl.py stop
  .venv/bin/python scripts/trareon_ctl.py quit
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def main() -> int:
    from util.remote_control import send_command

    p = argparse.ArgumentParser(description="Trareon remote control client")
    p.add_argument(
        "cmd",
        help="ping|status|close|theme|library|settings|export|mode|mic|spk|start|stop|clear|dismiss_banner|focus|quit",
    )
    p.add_argument("--label", default="", help="mode label for `mode` cmd")
    p.add_argument("--mode", default="", help="alias for --label")
    args = p.parse_args()
    extra = {}
    if args.label or args.mode:
        extra["label"] = args.label or args.mode
    resp = send_command(args.cmd, **extra)
    print(json.dumps(resp, ensure_ascii=False, indent=2))
    return 0 if resp.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
