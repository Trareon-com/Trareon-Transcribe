"""Export format picker + title edit."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import customtkinter as ctk

from config.branding import set_window_icon
from config.settings import Settings
from engine.session_store import Session
from export.writer import export_formats
from ui.theme import (
    bind_responsive,
    field_label,
    ghost_button,
    heading,
    muted,
    paint_window,
    panel_frame,
    primary_button,
    styled_entry,
)
from util.threading_helpers import run_in_thread, ui_after


class ExportDialog(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, session: Session, title: str, settings: Settings | None = None) -> None:
        super().__init__(master)
        self.session = session
        self.settings = settings or Settings.load()
        self.colors = paint_window(self)
        self.title("Export")
        self.minsize(360, 420)
        self.geometry("480x540")
        set_window_icon(self)
        self.transient(master)
        self.grab_set()

        self.title_var = ctk.StringVar(value=title or session.meta.title)
        self.md = ctk.BooleanVar(value=True)
        self.txt = ctk.BooleanVar(value=True)
        self.json_out = ctk.BooleanVar(value=True)
        self.srt = ctk.BooleanVar(value=False)
        self.vtt = ctk.BooleanVar(value=False)
        self.status = ctk.StringVar(value="")

        c = self.colors

        # Footer first so it never clips when the window is short.
        foot = ctk.CTkFrame(self, fg_color="transparent")
        foot.pack(side="bottom", fill="x", padx=22, pady=(0, 16))
        primary_button(foot, "↓  Export", self._export, c, width=128).pack(side="right")
        ghost_button(foot, "Batal", self.destroy, c, width=80).pack(side="right", padx=(0, 8))

        head = ctk.CTkFrame(self, fg_color="transparent")
        head.pack(fill="x", padx=22, pady=(18, 6))
        heading(head, "Export", c, size=20).pack(anchor="w")
        muted(head, "Pilih format lalu ekspor ke folder sesi", c).pack(anchor="w", pady=(2, 0))

        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=22, pady=(4, 12))
        body = ctk.CTkScrollableFrame(panel, fg_color="transparent")
        body.pack(fill="both", expand=True, padx=12, pady=12)

        field_label(body, "Judul rapat", c).pack(anchor="w")
        styled_entry(body, c, textvariable=self.title_var).pack(fill="x", pady=(4, 14))

        field_label(body, "Format", c).pack(anchor="w", pady=(0, 4))
        for label, var in (
            ("Markdown (.md)", self.md),
            ("Plain text (.txt)", self.txt),
            ("JSON", self.json_out),
            ("SRT", self.srt),
            ("VTT", self.vtt),
        ):
            ctk.CTkCheckBox(
                body,
                text=label,
                variable=var,
                text_color=c["text"],
                fg_color=c["accent"],
                hover_color=c["accent_hover"],
                border_color=c["border"],
                checkmark_color=c["on_accent"],
            ).pack(anchor="w", fill="x", pady=2)

        self.bar = ctk.CTkProgressBar(body, progress_color=c["accent"])
        self.bar.set(0)
        self.bar.pack(fill="x", pady=(14, 6))
        self.status_lbl = muted(body, "", c, textvariable=self.status, wraplength=400, anchor="w")
        self.status_lbl.pack(anchor="w", fill="x")
        bind_responsive(self)

    def _export(self) -> None:
        md, txt, json_out, srt, vtt = (
            bool(self.md.get()),
            bool(self.txt.get()),
            bool(self.json_out.get()),
            bool(self.srt.get()),
            bool(self.vtt.get()),
        )
        if not any((md, txt, json_out, srt, vtt)):
            self.status.set("Pilih minimal satu format.")
            return
        self.session.meta.title = self.title_var.get().strip() or self.session.meta.title
        self.session.save_meta()
        self.status.set("Mengekspor…")
        self.bar.set(0.3)
        # Snapshot Tk vars on UI thread — worker threads must not call .get().
        do_diar = bool(self.settings.diarization_enabled)

        def work() -> None:
            note = self._maybe_diarize() if do_diar else ""
            paths = export_formats(
                self.session,
                md=md,
                txt=txt,
                json_out=json_out,
                srt=srt,
                vtt=vtt,
            )
            ui_after(self, lambda p=paths, n=note: self._done(p, n))

        run_in_thread(work)

    def _maybe_diarize(self) -> str:
        from config.keyring_store import get_hf_token
        from engine.diarization import PyannoteDiarizer

        token = get_hf_token()
        diar = PyannoteDiarizer(token)
        if not diar.load():
            return diar.last_error or "Diarization dilewati."
        wav = self.session.mic_wav if self.session.mic_wav.exists() and self.session.mic_wav.stat().st_size > 44 else self.session.speaker_wav
        if not wav.exists() or wav.stat().st_size <= 44:
            return "Diarization: tidak ada WAV yang cukup untuk dianalisis."
        turns = diar.diarize_file(wav)
        if not turns:
            return diar.last_error or "Diarization: tidak ada speaker terdeteksi."
        for seg in self.session.segments:
            start_s = seg.start_ms / 1000.0
            for t0, t1, label in turns:
                if t0 <= start_s <= t1:
                    seg.speaker = label
                    break
        self.session.save_transcript()
        return f"Diarization OK · {len(turns)} segmen speaker."

    def _done(self, paths: list[Path], note: str = "") -> None:
        self.bar.set(1.0)
        msg = f"Selesai: {len(paths)} file"
        if note:
            msg = f"{msg} · {note}"
        self.status.set(msg)
        folder = self.session.root
        try:
            if sys.platform == "darwin":
                subprocess.run(["open", str(folder)], check=False)
            elif sys.platform == "win32":
                subprocess.run(["explorer", str(folder)], check=False)
        except Exception:
            pass
