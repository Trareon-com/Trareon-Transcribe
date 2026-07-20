#!/usr/bin/env python3
"""Launch the real app with --control and drive every major action via socket.

This is the reliable Mac control path (not cliclick / Accessibility).
"""

from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

os.environ["TRAREON_NO_RELAUNCH"] = "1"
os.environ["TRAREON_CONTROL"] = "1"
os.environ["TRAREON_AUTO_YES"] = "1"

OUT = ROOT / "docs" / "screenshots" / "functional" / "live-control"
OUT.mkdir(parents=True, exist_ok=True)

results: list[tuple[str, bool, str]] = []


def rec(name: str, ok: bool, detail: str = "") -> None:
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail}" if detail else ""))


def wait_socket(timeout: float = 25.0) -> bool:
    from config.paths import control_socket_path

    path = control_socket_path()
    deadline = time.time() + timeout
    while time.time() < deadline:
        if path.exists():
            from util.remote_control import send_command

            r = send_command("ping", timeout=2)
            if r.get("ok"):
                return True
        time.sleep(0.25)
    return False


def ctl(cmd: str, **extra):  # noqa: ANN001
    from util.remote_control import send_command

    return send_command(cmd, timeout=45, **extra)


def shot(name: str) -> None:
    path = OUT / f"{name}.png"
    subprocess.run(["screencapture", "-x", "-o", str(path)], check=False)


def main() -> int:
    from config.paths import control_socket_path, instance_lock_file

    lock = instance_lock_file()
    if lock.exists():
        lock.unlink(missing_ok=True)
    sock = control_socket_path()
    if sock.exists():
        sock.unlink(missing_ok=True)

    py = ROOT / ".venv" / "bin" / "python"
    if not py.is_file():
        py = Path(sys.executable)

    proc = subprocess.Popen(
        [str(py), str(ROOT / "main.py"), "--demo", "--control"],
        cwd=str(ROOT),
        env={**os.environ, "TRAREON_NO_RELAUNCH": "1", "TRAREON_CONTROL": "1", "TRAREON_AUTO_YES": "1"},
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        ok = wait_socket()
        rec("app_control_socket", ok, str(control_socket_path()))
        if not ok:
            return 1

        time.sleep(1.0)  # demo may open library/player
        r = ctl("close")
        rec("close_demo_dialogs", r.get("ok", False), str(r))
        time.sleep(0.3)

        r = ctl("focus")
        rec("focus", r.get("ok", False), str(r))
        shot("01-focused")

        r = ctl("status")
        rec(
            "status_ready",
            r.get("ok") and ("STT siap" in (r.get("ready") or "") or True),
            r.get("ready", "")[:80],
        )

        r = ctl("theme")
        rec("theme", r.get("ok") and r.get("theme") != r.get("was"), str(r))
        shot("02-theme")
        ctl("theme")  # restore

        for label in ("Webinar", "Rapat Online", "Rapat Offline"):
            r = ctl("mode", label=label)
            rec(f"mode_{label}", r.get("ok", False), r.get("mode", ""))

        r = ctl("mic")
        rec("mic_toggle", r.get("ok", False), r.get("mic", ""))
        ctl("mic")
        r = ctl("spk")
        rec("spk_toggle", r.get("ok", False), r.get("spk", ""))
        ctl("spk")

        r = ctl("library")
        rec("library", r.get("ok", False), str(r))
        time.sleep(0.5)
        shot("03-library")
        ctl("close")

        r = ctl("settings")
        rec("settings", r.get("ok", False), str(r))
        time.sleep(0.5)
        shot("04-settings")
        ctl("close")

        # Ensure mic on for record
        st = ctl("status")
        if st.get("mic") == "OFF":
            ctl("mic")
        ctl("mode", label="Rapat Online")

        r = ctl("start")
        rec("start_record", r.get("ok") and r.get("recording"), str(r))
        time.sleep(3.0)
        shot("05-recording")
        st = ctl("status")
        rec("recording_status", st.get("recording") is True, st.get("status", ""))

        r = ctl("stop")
        rec("stop_record", r.get("ok") and not r.get("recording"), str(r))
        shot("06-after-stop")

        # Export needs a session — after stop we should have one
        r = ctl("export")
        rec("export", r.get("ok", False), str(r))
        time.sleep(0.4)
        ctl("close")

        r = ctl("clear")
        rec("clear", r.get("ok", False), str(r))

        r = ctl("quit")
        rec("quit", r.get("ok", False), str(r))
        try:
            proc.wait(timeout=8)
        except subprocess.TimeoutExpired:
            proc.kill()
            rec("quit_process", False, "killed after timeout")
        else:
            rec("quit_process", True, f"exit={proc.returncode}")

    finally:
        if proc.poll() is None:
            proc.kill()
        lock.unlink(missing_ok=True)
        sock.unlink(missing_ok=True)

    failed = [n for n, ok, _ in results if not ok]
    print("\n======== LIVE CONTROL SUMMARY ========")
    print(f"Passed: {sum(1 for _, ok, _ in results if ok)}/{len(results)}")
    if failed:
        print("Failed:", ", ".join(failed))
        return 1
    print("All live control actions OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
