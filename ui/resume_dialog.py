"""Crash-resume: continue or discard in-progress session."""

from __future__ import annotations

from pathlib import Path
from tkinter import messagebox

import customtkinter as ctk

from engine.session_store import delete_session, load_session, quarantine_session
from ui.theme import bind_responsive, danger_button, heading, muted, paint_window, panel_frame, primary_button


class ResumeDialog(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, session_path: Path, library_root: Path, on_resume, on_discard) -> None:  # noqa: ANN001
        super().__init__(master)
        self.session_path = session_path
        self.library_root = library_root
        self.on_resume = on_resume
        self.on_discard = on_discard
        self.colors = paint_window(self)
        self.title("Sesi belum selesai")
        self.minsize(360, 240)
        self.geometry("460x280")
        self.transient(master)
        self.grab_set()

        try:
            sess = load_session(session_path)
            title = sess.meta.title
        except Exception:
            title = session_path.name

        c = self.colors
        heading(self, "Sesi belum selesai", c, size=18).pack(anchor="w", fill="x", padx=22, pady=(20, 6))
        muted(self, "App tertutup saat rekaman masih berjalan.", c).pack(anchor="w", padx=22, pady=(0, 8))
        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=22, pady=(0, 12))
        muted(
            panel,
            f"Ditemukan sesi:\n{title}\n\nLanjutkan atau buang & mulai baru?",
            c,
            wraplength=360,
            justify="left",
            anchor="w",
            font=ctk.CTkFont(size=13),
        ).pack(padx=16, pady=16, anchor="w", fill="x")

        row = ctk.CTkFrame(self, fg_color="transparent")
        row.pack(fill="x", padx=22, pady=(0, 16))
        danger_button(row, "Buang & mulai baru", self._discard, c, width=150).pack(side="right", padx=(8, 0))
        primary_button(row, "Lanjutkan", self._resume, c, width=120).pack(side="right")
        bind_responsive(self)

    def _resume(self) -> None:
        try:
            sess = load_session(self.session_path)
        except Exception:
            quarantine_session(self.session_path)
            self.grab_release()
            self.destroy()
            messagebox.showerror(
                "Sesi rusak",
                "Data sesi sebelumnya rusak dan tidak bisa dibuka. Sesi ini diarsipkan; memulai baru.",
            )
            self.on_discard()
            return
        self.grab_release()
        self.destroy()
        self.on_resume(sess)

    def _discard(self) -> None:
        delete_session(self.session_path, self.library_root)
        self.grab_release()
        self.destroy()
        self.on_discard()
