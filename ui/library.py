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
from setup.disk import library_storage_summary
from ui.export_dialog import ExportDialog
from ui.theme import danger_button, ghost_button, heading, muted, paint_window, panel_frame, primary_button
from ui.transcript_player import TranscriptPlayerWindow


class LibraryWindow(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, library_root: Path) -> None:
        super().__init__(master)
        self.library_root = library_root
        self.colors = paint_window(self)
        self.title(f"Library — {APP_NAME}")
        set_window_icon(self)
        self.minsize(720, 480)
        self.geometry("820x560")
        self.transient(master)

        c = self.colors
        top = ctk.CTkFrame(self, fg_color="transparent")
        top.pack(fill="x", padx=20, pady=(16, 6))
        heading(top, "Library", c).pack(side="left")
        ghost_button(top, "Refresh", self.refresh, c, width=88).pack(side="right")

        self.storage_var = ctk.StringVar(value="")
        muted(self, "", c, textvariable=self.storage_var, anchor="w").pack(fill="x", padx=22)

        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=20, pady=(8, 16))
        self.listbox = ctk.CTkScrollableFrame(panel, fg_color="transparent")
        self.listbox.pack(fill="both", expand=True, padx=10, pady=10)
        self.empty = muted(self.listbox, "", c)
        self.empty.pack(pady=24)
        self.refresh()

    def refresh(self) -> None:
        c = self.colors
        for w in self.listbox.winfo_children():
            w.destroy()
        try:
            self.storage_var.set(library_storage_summary(self.library_root))
        except Exception:
            self.storage_var.set("")
        metas = list_sessions(self.library_root)
        if not metas:
            self.empty = muted(
                self.listbox, "Belum ada rekaman. Mulai rekam dari jendela utama.", c
            )
            self.empty.pack(pady=32)
            return
        for meta in metas:
            folder = self.library_root / (meta.folder_name or "")
            if not folder.exists():
                continue
            size_mb = session_disk_bytes(folder) / (1024 * 1024)
            row = ctk.CTkFrame(
                self.listbox,
                fg_color=c["row"],
                corner_radius=10,
                border_width=1,
                border_color=c["border"],
            )
            row.pack(fill="x", pady=4)
            dur = (
                f"{int(meta.duration_sec // 60)}:{int(meta.duration_sec % 60):02d}"
                if meta.duration_sec
                else "—"
            )
            label = (
                f"{meta.created_at[:19].replace('T', ' ') if meta.created_at else '?'}  ·  "
                f"{meta.title}  ·  {meta.mode}  ·  {dur}  ·  {size_mb:.1f} MB"
            )
            title_lbl = ctk.CTkLabel(row, text=label, anchor="w", text_color=c["text"])
            title_lbl.pack(side="left", padx=12, pady=10, fill="x", expand=True)
            title_lbl.bind("<Double-Button-1>", lambda _e, p=folder: self._open(p))
            row.bind("<Double-Button-1>", lambda _e, p=folder: self._open(p))
            danger_button(row, "Hapus", lambda p=folder: self._delete(p), c, width=64).pack(
                side="right", padx=(2, 10), pady=8
            )
            ghost_button(row, "Folder", lambda p=folder: self._reveal(p), c, width=70).pack(
                side="right", padx=2, pady=8
            )
            ghost_button(row, "Rename", lambda p=folder: self._rename(p), c, width=70).pack(
                side="right", padx=2, pady=8
            )
            ghost_button(row, "Export", lambda p=folder: self._export(p), c, width=70).pack(
                side="right", padx=2, pady=8
            )
            primary_button(row, "Putar", lambda p=folder: self._open(p), c, width=70, height=30).pack(
                side="right", padx=2, pady=8
            )

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
