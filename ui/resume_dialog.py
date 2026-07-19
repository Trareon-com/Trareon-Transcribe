"""Crash-resume: continue or discard in-progress session."""

from __future__ import annotations

from pathlib import Path

import customtkinter as ctk

from engine.session_store import delete_session, load_session


class ResumeDialog(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, session_path: Path, library_root: Path, on_resume, on_discard) -> None:  # noqa: ANN001
        super().__init__(master)
        self.session_path = session_path
        self.library_root = library_root
        self.on_resume = on_resume
        self.on_discard = on_discard
        self.title("Sesi belum selesai")
        self.geometry("420x200")
        self.transient(master)
        self.grab_set()

        try:
            sess = load_session(session_path)
            title = sess.meta.title
        except Exception:
            title = session_path.name

        ctk.CTkLabel(
            self,
            text=f"Ditemukan sesi yang belum selesai:\n{title}\n\nLanjutkan atau buang?",
            wraplength=380,
        ).pack(padx=16, pady=20)
        row = ctk.CTkFrame(self, fg_color="transparent")
        row.pack(pady=8)
        ctk.CTkButton(row, text="Lanjutkan", command=self._resume).pack(side="left", padx=8)
        ctk.CTkButton(row, text="Buang & mulai baru", fg_color="#C0392B", command=self._discard).pack(
            side="left", padx=8
        )

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
