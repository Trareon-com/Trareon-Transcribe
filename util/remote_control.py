"""Local Unix-socket remote control for Mac/Linux automation.

CustomTkinter buttons are not reliable via Accessibility / cliclick.
Agents and gate scripts drive the visible app through this socket instead.

Protocol: one JSON object per line. Request `{"cmd":"..."}` → response JSON.
"""

from __future__ import annotations

import json
import logging
import os
import socket
import threading
from collections.abc import Callable
from pathlib import Path
from typing import Any

from config.paths import control_socket_path

log = logging.getLogger("trareon.remote")

# Commands that skip confirm dialogs (start STT warn / stop confirm).
_AUTO_YES_CMDS = frozenset({"start", "stop", "quit"})


class RemoteControl:
    def __init__(self, app: Any, handlers: dict[str, Callable[[dict], dict]]) -> None:
        self.app = app
        self.handlers = handlers
        self.path = control_socket_path()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._server: socket.socket | None = None

    def start(self) -> Path:
        if self.path.exists():
            try:
                self.path.unlink()
            except OSError:
                pass
        srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        srv.bind(str(self.path))
        srv.listen(4)
        srv.settimeout(0.5)
        self._server = srv
        self._thread = threading.Thread(target=self._accept_loop, name="trareon-ctl", daemon=True)
        self._thread.start()
        log.info("Remote control listening on %s", self.path)
        return self.path

    def stop(self) -> None:
        self._stop.set()
        if self._server is not None:
            try:
                self._server.close()
            except OSError:
                pass
        try:
            if self.path.exists():
                self.path.unlink()
        except OSError:
            pass

    def _accept_loop(self) -> None:
        assert self._server is not None
        while not self._stop.is_set():
            try:
                conn, _ = self._server.accept()
            except TimeoutError:
                continue
            except OSError:
                break
            threading.Thread(target=self._serve, args=(conn,), daemon=True).start()

    def _serve(self, conn: socket.socket) -> None:
        with conn:
            buf = b""
            while not self._stop.is_set():
                try:
                    chunk = conn.recv(4096)
                except OSError:
                    return
                if not chunk:
                    return
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        req = json.loads(line.decode("utf-8"))
                    except (UnicodeDecodeError, json.JSONDecodeError) as e:
                        resp = {"ok": False, "error": f"bad json: {e}"}
                    else:
                        resp = self._dispatch(req if isinstance(req, dict) else {})
                    try:
                        conn.sendall((json.dumps(resp, ensure_ascii=False) + "\n").encode("utf-8"))
                    except OSError:
                        return

    def _dispatch(self, req: dict) -> dict:
        cmd = str(req.get("cmd") or "").strip().lower()
        if not cmd:
            return {"ok": False, "error": "missing cmd"}
        if getattr(self.app, "_quitting", False) and cmd != "ping":
            return {"ok": False, "error": "app is quitting"}
        done = threading.Event()
        box: dict[str, dict] = {}

        def run() -> None:
            prev_auto = os.environ.get("TRAREON_AUTO_YES")
            try:
                if cmd in _AUTO_YES_CMDS:
                    os.environ["TRAREON_AUTO_YES"] = "1"
                handler = self.handlers.get(cmd)
                if handler is None:
                    box["r"] = {"ok": False, "error": f"unknown cmd: {cmd}", "cmds": sorted(self.handlers)}
                else:
                    box["r"] = handler(req)
            except Exception as e:  # noqa: BLE001 — surface to client
                log.exception("remote cmd %s failed", cmd)
                box["r"] = {"ok": False, "error": str(e)}
            finally:
                if cmd in _AUTO_YES_CMDS:
                    if prev_auto is None:
                        os.environ.pop("TRAREON_AUTO_YES", None)
                    else:
                        os.environ["TRAREON_AUTO_YES"] = prev_auto
                done.set()

        try:
            self.app.after(0, run)
        except Exception as e:
            return {"ok": False, "error": f"schedule failed: {e}"}
        if not done.wait(timeout=45):
            return {"ok": False, "error": "timeout waiting for UI thread"}
        return box.get("r", {"ok": False, "error": "no response"})


def send_command(cmd: str, timeout: float = 45.0, **extra: Any) -> dict:
    """Client helper — one request/response over the control socket."""
    path = control_socket_path()
    if not path.exists():
        return {"ok": False, "error": f"socket missing: {path} (launch with --control)"}
    req = {"cmd": cmd, **extra}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(timeout)
        sock.connect(str(path))
        sock.sendall((json.dumps(req) + "\n").encode("utf-8"))
        buf = b""
        while b"\n" not in buf:
            chunk = sock.recv(4096)
            if not chunk:
                break
            buf += chunk
    if not buf:
        return {"ok": False, "error": "empty response"}
    line = buf.split(b"\n", 1)[0]
    return json.loads(line.decode("utf-8"))


def attach_to_main_window(app: Any) -> RemoteControl:
    """Wire standard commands onto MainWindow."""

    def status(_req: dict) -> dict:
        return {
            "ok": True,
            "recording": bool(app._recording),  # noqa: SLF001
            "theme": app.settings.theme,
            "mode": app.mode_var.get(),
            "status": app.status_var.get(),
            "ready": app.ready_var.get(),
            "banner": app.banner_var.get(),
            "mic": app.mic_var.get(),
            "spk": app.spk_var.get(),
            "title": app.title_var.get(),
            "timer": app.timer_var.get(),
            "conf": app.conf_var.get(),
            "hud": app.hud_var.get(),
            "banner_dismissed": bool(getattr(app, "_banner_dismissed", False)),
            "session": str(app.session.root) if app.session else None,
        }

    def close_dialogs(_req: dict) -> dict:
        from customtkinter import CTkToplevel

        n = 0
        for w in list(app.winfo_children()):
            try:
                if isinstance(w, CTkToplevel):
                    w.destroy()
                    n += 1
            except Exception:
                continue
        app.update_idletasks()
        return {"ok": True, "closed": n}

    def theme(_req: dict) -> dict:
        before = app.settings.theme
        app._toggle_theme()  # noqa: SLF001
        app.update_idletasks()
        return {"ok": True, "theme": app.settings.theme, "was": before}

    def library(_req: dict) -> dict:
        app._open_library()  # noqa: SLF001
        app.update_idletasks()
        return {"ok": True}

    def settings(_req: dict) -> dict:
        app._open_settings()  # noqa: SLF001
        app.update_idletasks()
        return {"ok": True}

    def export(_req: dict) -> dict:
        app._export()  # noqa: SLF001
        app.update_idletasks()
        return {"ok": True, "has_session": app.session is not None}

    def mode(req: dict) -> dict:
        label = str(req.get("label") or req.get("mode") or "").strip()
        aliases = {
            "webinar": "Webinar",
            "rapat_online": "Rapat Online",
            "rapat_offline": "Rapat Offline",
            "online": "Rapat Online",
            "offline": "Rapat Offline",
        }
        label = aliases.get(label.lower().replace(" ", "_"), label) if label else "Rapat Online"
        if label not in ("Webinar", "Rapat Online", "Rapat Offline"):
            return {"ok": False, "error": f"bad mode: {label}"}
        app._on_mode_seg(label)  # noqa: SLF001
        app.update_idletasks()
        return {"ok": True, "mode": app.mode_var.get()}

    def mic(_req: dict) -> dict:
        app._toggle_mic()  # noqa: SLF001
        return {"ok": True, "mic": app.mic_var.get()}

    def spk(_req: dict) -> dict:
        app._toggle_spk()  # noqa: SLF001
        return {"ok": True, "spk": app.spk_var.get()}

    def start(_req: dict) -> dict:
        if app._recording:  # noqa: SLF001
            return {"ok": True, "recording": True, "already": True}
        app._start_record()  # noqa: SLF001
        app.update_idletasks()
        return {"ok": True, "recording": bool(app._recording), "status": app.status_var.get()}  # noqa: SLF001

    def stop(_req: dict) -> dict:
        if not app._recording:  # noqa: SLF001
            return {"ok": True, "recording": False, "already": True}
        app._stop_record()  # noqa: SLF001
        app.update_idletasks()
        return {
            "ok": True,
            "recording": bool(app._recording),  # noqa: SLF001
            "session": str(app.session.root) if app.session else None,
        }

    def clear(_req: dict) -> dict:
        app._clear_caption()  # noqa: SLF001
        return {"ok": True}

    def dismiss_banner(_req: dict) -> dict:
        app._dismiss_banner()  # noqa: SLF001
        return {"ok": True, "banner_dismissed": True}

    def focus(_req: dict) -> dict:
        app.deiconify()
        app.lift()
        app.focus_force()
        try:
            app.attributes("-topmost", True)
            app.after(200, lambda: app.attributes("-topmost", app.settings.always_on_top))
        except Exception:
            pass
        return {"ok": True}

    def quit_app(_req: dict) -> dict:
        app._quitting = True  # noqa: SLF001 — reject further remote cmds
        if app._recording:  # noqa: SLF001
            app._stop_record()  # noqa: SLF001
        try:
            app._stop_meters()  # noqa: SLF001
        except Exception:
            pass
        try:
            app._persist_geometry()  # noqa: SLF001
        except Exception:
            pass
        try:
            app.tray.stop()
        except Exception:
            pass

        def _die() -> None:
            try:
                rc.stop()
            except Exception:
                pass
            try:
                app.destroy()
            except Exception:
                pass

        app.after(50, _die)
        return {"ok": True, "quitting": True}

    def ping(_req: dict) -> dict:
        return {"ok": True, "pong": True}

    handlers = {
        "ping": ping,
        "status": status,
        "close": close_dialogs,
        "theme": theme,
        "library": library,
        "settings": settings,
        "export": export,
        "mode": mode,
        "mic": mic,
        "spk": spk,
        "start": start,
        "stop": stop,
        "clear": clear,
        "dismiss_banner": dismiss_banner,
        "focus": focus,
        "quit": quit_app,
    }
    rc = RemoteControl(app, handlers)
    rc.start()
    app._remote_control = rc  # noqa: SLF001
    return rc
