"""Session library browser."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import customtkinter as ctk

from config.branding import APP_NAME, set_window_icon
from engine.session_store import (
    delete_session,
    list_sessions,
    load_session,
    rename_session_folder,
    session_disk_bytes,
    update_title,
)
from ui.export_dialog import ExportDialog
from ui.transcript_player import TranscriptPlayerWindow


class LibraryWindow(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, library_root: Path) -> None:
        super().__init__(master)
        self.library_root = library_root
        self.title(f"Library — {APP_NAME}")
        set_window_icon(self)
        self.geometry("780x520")
        self.transient(master)

        top = ctk.CTkFrame(self, fg_color="transparent")
        top.pack(fill="x", padx=12, pady=8)
        ctk.CTkLabel(top, text="Riwayat sesi", font=ctk.CTkFont(size=18, weight="bold")).pack(side="left")
        ctk.CTkButton(top, text="Refresh", width=80, command=self.refresh).pack(side="right")

        self.listbox = ctk.CTkScrollableFrame(self, height=320)
        self.listbox.pack(fill="both", expand=True, padx=12, pady=8)
        self.empty = ctk.CTkLabel(self, text="")
        self.empty.pack()
        self._rows: list[tuple[str, Path]] = []
        self.refresh()

    def refresh(self) -> None:
        for w in self.listbox.winfo_children():
            w.destroy()
        metas = list_sessions(self.library_root)
        if not metas:
            self.empty.configure(text="Belum ada rekaman. Mulai rekam dari jendela utama.")
            return
        self.empty.configure(text="")
        for meta in metas:
            folder = self.library_root / (meta.folder_name or "")
            if not folder.exists():
                # fallback scan by matching title+created
                continue
            size_mb = session_disk_bytes(folder) / (1024 * 1024)
            row = ctk.CTkFrame(self.listbox)
            row.pack(fill="x", pady=4)
            dur = f"{int(meta.duration_sec // 60)}:{int(meta.duration_sec % 60):02d}" if meta.duration_sec else "—"
            label = (
                f"{meta.created_at[:19].replace('T', ' ') if meta.created_at else '?'}  ·  "
                f"{meta.title}  ·  {meta.mode}  ·  {dur}  ·  {size_mb:.1f} MB"
            )
            title_lbl = ctk.CTkLabel(row, text=label, anchor="w")
            title_lbl.pack(side="left", padx=8, fill="x", expand=True)
            title_lbl.bind("<Double-Button-1>", lambda _e, p=folder: self._open(p))
            row.bind("<Double-Button-1>", lambda _e, p=folder: self._open(p))
            ctk.CTkButton(row, text="Putar", width=70, command=lambda p=folder: self._open(p)).pack(
                side="right", padx=2
            )
            ctk.CTkButton(row, text="Export", width=70, command=lambda p=folder: self._export(p)).pack(
                side="right", padx=2
            )
            ctk.CTkButton(row, text="Rename", width=70, command=lambda p=folder: self._rename(p)).pack(
                side="right", padx=2
            )
            ctk.CTkButton(row, text="Folder", width=70, command=lambda p=folder: self._reveal(p)).pack(
                side="right", padx=2
            )
            ctk.CTkButton(
                row, text="Hapus", width=60, fg_color="#C0392B", command=lambda p=folder: self._delete(p)
            ).pack(side="right", padx=2)

    def _open(self, path: Path) -> None:
        TranscriptPlayerWindow(self, path)

    def _export(self, path: Path) -> None:
        sess = load_session(path)
        from config.settings import Settings

        ExportDialog(self, sess, sess.meta.title, Settings.load())

    def _rename(self, path: Path) -> None:
        sess = load_session(path)
        dialog = ctk.CTkInputDialog(text="Judul baru:", title="Rename")
        new = dialog.get_input()
        if not new:
            return
        update_title(sess, new)
        rename_session_folder(sess)
        self.refresh()

    def _delete(self, path: Path) -> None:
        delete_session(path, self.library_root)
        self.refresh()

    def _reveal(self, path: Path) -> None:
        try:
            if sys.platform == "darwin":
                subprocess.run(["open", str(path)], check=False)
            elif sys.platform == "win32":
                subprocess.run(["explorer", str(path)], check=False)
        except Exception:
            pass
