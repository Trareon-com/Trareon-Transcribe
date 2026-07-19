"""Crash-resume: continue or discard in-progress session."""

from __future__ import annotations

from pathlib import Path

import customtkinter as ctk

from engine.session_store import delete_session, load_session
from ui.theme import danger_button, heading, muted, paint_window, panel_frame, primary_button


class ResumeDialog(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, session_path: Path, library_root: Path, on_resume, on_discard) -> None:  # noqa: ANN001
        super().__init__(master)
        self.session_path = session_path
        self.library_root = library_root
        self.on_resume = on_resume
        self.on_discard = on_discard
        self.colors = paint_window(self)
        self.title("Sesi belum selesai")
        self.minsize(420, 260)
        self.geometry("460x280")
        self.transient(master)
        self.grab_set()

        try:
            sess = load_session(session_path)
            title = sess.meta.title
        except Exception:
            title = session_path.name

        c = self.colors
        heading(self, "Sesi belum selesai", c, size=16).pack(anchor="w", padx=20, pady=(18, 8))
        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=20, pady=(0, 12))
        muted(
            panel,
            f"Ditemukan sesi yang belum selesai:\n{title}\n\nLanjutkan atau buang?",
            c,
            wraplength=360,
            justify="left",
            font=ctk.CTkFont(size=13),
        ).pack(padx=16, pady=16, anchor="w")

        row = ctk.CTkFrame(self, fg_color="transparent")
        row.pack(fill="x", padx=20, pady=(0, 16))
        danger_button(row, "Buang & mulai baru", self._discard, c, width=150).pack(side="right", padx=(8, 0))
        primary_button(row, "Lanjutkan", self._resume, c, width=120).pack(side="right")

    def _resume(self) -> None:
        sess = load_session(self.session_path)
        self.grab_release()
        self.destroy()
        self.on_resume(sess)

    def _discard(self) -> None:
        delete_session(self.session_path, self.library_root)
        self.grab_release()
        self.destroy()
        self.on_discard()
