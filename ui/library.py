"""Session library browser."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import customtkinter as ctk

from engine.session_store import (
    delete_session,
    list_sessions,
    load_session,
    rename_session_folder,
    session_disk_bytes,
    update_title,
)
from ui.export_dialog import ExportDialog


class LibraryWindow(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, library_root: Path) -> None:
        super().__init__(master)
        self.library_root = library_root
        self.title("Library — Trareon Transcribe")
        self.geometry("720x480")
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
            label = f"{meta.created_at[:19] if meta.created_at else '?'}  |  {meta.title}  |  {meta.mode}  |  {size_mb:.1f} MB"
            ctk.CTkLabel(row, text=label, anchor="w").pack(side="left", padx=8, fill="x", expand=True)
            ctk.CTkButton(row, text="Buka", width=60, command=lambda p=folder: self._open(p)).pack(side="right", padx=2)
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
        sess = load_session(path)
        win = ctk.CTkToplevel(self)
        win.title(sess.meta.title)
        win.geometry("560x400")
        box = ctk.CTkTextbox(win)
        box.pack(fill="both", expand=True, padx=8, pady=8)
        for seg in sess.segments:
            if seg.is_final:
                box.insert("end", f"[{seg.speaker}] {seg.text}\n")
        box.configure(state="disabled")

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
