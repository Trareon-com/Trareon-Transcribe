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
from ui.theme import field_label, heading, muted, paint_window, panel_frame, primary_button, styled_entry
from util.threading_helpers import run_in_thread


class ExportDialog(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, session: Session, title: str, settings: Settings | None = None) -> None:
        super().__init__(master)
        self.session = session
        self.settings = settings or Settings.load()
        self.colors = paint_window(self)
        self.title("Export")
        self.minsize(480, 520)
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
        foot.pack(side="bottom", fill="x", padx=20, pady=(0, 16))
        primary_button(foot, "Export", self._export, c, width=120).pack(side="right")

        heading(self, "Export", c).pack(anchor="w", padx=20, pady=(18, 8))

        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=20, pady=(0, 12))
        body = ctk.CTkScrollableFrame(panel, fg_color="transparent")
        body.pack(fill="both", expand=True, padx=10, pady=10)

        field_label(body, "Judul rapat", c).pack(anchor="w")
        styled_entry(body, c, textvariable=self.title_var).pack(fill="x", pady=(4, 12))

        field_label(body, "Format", c).pack(anchor="w")
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
            ).pack(anchor="w", pady=2)

        self.bar = ctk.CTkProgressBar(body, progress_color=c["accent"])
        self.bar.set(0)
        self.bar.pack(fill="x", pady=(14, 6))
        muted(body, "", c, textvariable=self.status, wraplength=400).pack(anchor="w")

    def _export(self) -> None:
        self.session.meta.title = self.title_var.get().strip() or self.session.meta.title
        self.session.save_meta()
        self.status.set("Mengekspor…")
        self.bar.set(0.3)

        def work() -> None:
            if self.settings.diarization_enabled:
                self._maybe_diarize()
            paths = export_formats(
                self.session,
                md=self.md.get(),
                txt=self.txt.get(),
                json_out=self.json_out.get(),
                srt=self.srt.get(),
                vtt=self.vtt.get(),
            )
            self.after(0, lambda: self._done(paths))

        run_in_thread(work)

    def _maybe_diarize(self) -> None:
        from config.keyring_store import get_hf_token
        from engine.diarization import PyannoteDiarizer

        token = get_hf_token()
        diar = PyannoteDiarizer(token)
        if not diar.load():
            return
        wav = self.session.mic_wav if self.session.mic_wav.exists() else self.session.speaker_wav
        if not wav.exists():
            return
        turns = diar.diarize_file(wav)
        if not turns:
            return
        for seg in self.session.segments:
            start_s = seg.start_ms / 1000.0
            for t0, t1, label in turns:
                if t0 <= start_s <= t1:
                    seg.speaker = label
                    break
        self.session.save_transcript()

    def _done(self, paths: list[Path]) -> None:
        self.bar.set(1.0)
        self.status.set(f"Selesai: {len(paths)} file")
        folder = self.session.root
        try:
            if sys.platform == "darwin":
                subprocess.run(["open", str(folder)], check=False)
            elif sys.platform == "win32":
                subprocess.run(["explorer", str(folder)], check=False)
        except Exception:
            pass
