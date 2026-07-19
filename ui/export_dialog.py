"""Export format picker + title edit."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import customtkinter as ctk

from config.settings import Settings
from engine.session_store import Session
from engine.translate import translate_text
from export.writer import export_formats
from util.threading_helpers import run_in_thread


class ExportDialog(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, session: Session, title: str, settings: Settings | None = None) -> None:
        super().__init__(master)
        self.session = session
        self.settings = settings or Settings.load()
        self.title("Export")
        self.geometry("420x400")
        self.transient(master)
        self.grab_set()

        self.title_var = ctk.StringVar(value=title or session.meta.title)
        self.md = ctk.BooleanVar(value=True)
        self.txt = ctk.BooleanVar(value=True)
        self.json_out = ctk.BooleanVar(value=True)
        self.srt = ctk.BooleanVar(value=False)
        self.vtt = ctk.BooleanVar(value=False)
        self.translate = ctk.BooleanVar(value=bool(self.settings.translate_enabled))
        self.status = ctk.StringVar(value="")

        ctk.CTkLabel(self, text="Judul rapat").pack(anchor="w", padx=16, pady=(16, 4))
        ctk.CTkEntry(self, textvariable=self.title_var, width=360).pack(padx=16)
        ctk.CTkLabel(self, text="Format").pack(anchor="w", padx=16, pady=(12, 4))
        for label, var in (
            ("Markdown (.md)", self.md),
            ("Plain text (.txt)", self.txt),
            ("JSON", self.json_out),
            ("SRT", self.srt),
            ("VTT", self.vtt),
            ("Translate EN↔ID (offline Argos)", self.translate),
        ):
            ctk.CTkCheckBox(self, text=label, variable=var).pack(anchor="w", padx=24, pady=2)

        self.bar = ctk.CTkProgressBar(self, width=320)
        self.bar.set(0)
        self.bar.pack(pady=10)
        ctk.CTkLabel(self, textvariable=self.status, wraplength=380).pack()
        ctk.CTkButton(self, text="Export", command=self._export).pack(pady=12)

    def _export(self) -> None:
        self.session.meta.title = self.title_var.get().strip() or self.session.meta.title
        self.session.save_meta()
        self.status.set("Mengekspor…")
        self.bar.set(0.3)

        def work() -> None:
            if self.translate.get():
                for seg in self.session.segments:
                    if seg.is_final and seg.text.strip():
                        seg.text = translate_text(seg.text, self.settings.translate_direction)
                self.session.save_transcript()
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
