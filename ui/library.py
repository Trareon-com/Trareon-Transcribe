"""Session library browser."""

from __future__ import annotations

import subprocess
import sys
import tkinter.messagebox as messagebox
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
from ui.theme import (
    bind_responsive,
    danger_button,
    ghost_button,
    heading,
    muted,
    paint_window,
    panel_frame,
    primary_button,
    styled_entry,
    sync_responsive,
)
from ui.transcript_player import TranscriptPlayerWindow
from ui.window_util import focus_existing, open_singleton
from util.timefmt import format_local


def _fmt_dur(sec: float) -> str:
    if sec <= 0:
        return "—"
    sec = int(sec)
    h, rem = divmod(sec, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m}:{s:02d}"


class LibraryWindow(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, library_root: Path) -> None:
        super().__init__(master)
        self.library_root = library_root
        self.colors = paint_window(self)
        self.title(f"Library — {APP_NAME}")
        set_window_icon(self)
        self.minsize(560, 440)
        self.geometry("1080x640")
        self.transient(master)
        self._player_win: TranscriptPlayerWindow | None = None
        self._export_win: ExportDialog | None = None

        c = self.colors
        top = ctk.CTkFrame(self, fg_color="transparent")
        top.pack(fill="x", padx=22, pady=(18, 6))
        left = ctk.CTkFrame(top, fg_color="transparent")
        left.pack(side="left", fill="x", expand=True)
        heading(left, "Library", c, size=20).pack(anchor="w")
        muted(left, "Rekaman tersimpan · klik ganda untuk putar", c).pack(anchor="w", pady=(2, 0))
        ghost_button(top, "Refresh", self.refresh, c, width=88).pack(side="right")

        self.storage_var = ctk.StringVar(value="")
        self.search_var = ctk.StringVar(value="")
        self.storage_lbl = muted(self, "", c, textvariable=self.storage_var, wraplength=600, anchor="w")
        self.storage_lbl.pack(fill="x", padx=24, pady=(0, 4))
        search_row = ctk.CTkFrame(self, fg_color="transparent")
        search_row.pack(fill="x", padx=24, pady=(0, 6))
        entry = styled_entry(
            search_row, c, textvariable=self.search_var, placeholder_text="Cari judul / mode…"
        )
        entry.pack(fill="x")
        self._search_after: str | None = None

        def _schedule_search(_e=None) -> None:  # noqa: ANN001
            if self._search_after is not None:
                try:
                    self.after_cancel(self._search_after)
                except Exception:
                    pass
            self._search_after = self.after(120, self.refresh)

        entry.bind("<KeyRelease>", _schedule_search)

        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=22, pady=(4, 18))
        self.listbox = ctk.CTkScrollableFrame(panel, fg_color="transparent")
        self.listbox.pack(fill="both", expand=True, padx=12, pady=12)
        self.empty = muted(self.listbox, "", c)
        self.empty.pack(pady=24)
        self._layout_wide: bool | None = None
        self._resize_after: str | None = None
        bind_responsive(self)
        self.bind("<Configure>", self._on_resize, add="+")
        self.refresh()

    def _on_resize(self, event=None) -> None:  # noqa: ANN001
        if event is not None and event.widget is not self:
            return
        try:
            wide = int(self.winfo_width()) >= 820
        except Exception:
            return
        if self._layout_wide is not None and self._layout_wide == wide:
            return
        if self._resize_after is not None:
            try:
                self.after_cancel(self._resize_after)
            except Exception:
                pass

        def _apply() -> None:
            self._resize_after = None
            try:
                now = int(self.winfo_width()) >= 820
            except Exception:
                return
            if self._layout_wide != now:
                self._layout_wide = now
                self.refresh()

        self._resize_after = self.after(100, _apply)

    def refresh(self) -> None:
        c = self.colors
        for w in self.listbox.winfo_children():
            w.destroy()
        try:
            self.storage_var.set(library_storage_summary(self.library_root))
        except Exception:
            self.storage_var.set("")
        metas = list_sessions(self.library_root)
        q = (self.search_var.get() or "").strip().lower()
        if q:
            metas = [
                m
                for m in metas
                if q in (m.title or "").lower()
                or q in (m.mode or "").lower()
                or q in (m.folder_name or "").lower()
            ]
        try:
            wide = int(self.winfo_width()) >= 820
        except Exception:
            wide = True
        self._layout_wide = wide
        if not metas:
            wrap = ctk.CTkFrame(self.listbox, fg_color="transparent")
            wrap.pack(fill="x", pady=48)
            muted(
                wrap,
                "Tidak ada hasil" if q else "Belum ada rekaman",
                c,
                font=ctk.CTkFont(size=15, weight="bold"),
                text_color=c["text"],
            ).pack()
            muted(
                wrap,
                (
                    f"Tidak ada sesi cocok dengan «{q}»."
                    if q
                    else "Mulai rekam dari jendela utama — sesi muncul di sini otomatis."
                ),
                c,
                wraplength=420,
                justify="center",
            ).pack(pady=(6, 0))
            return
        for meta in metas:
            folder = self.library_root / (meta.folder_name or "")
            if not folder.exists():
                continue
            size_mb = session_disk_bytes(folder) / (1024 * 1024)
            row = ctk.CTkFrame(
                self.listbox,
                fg_color=c["row"],
                corner_radius=12,
                border_width=1,
                border_color=c["border"],
            )
            row.pack(fill="x", pady=5)

            body = ctk.CTkFrame(row, fg_color="transparent")
            body.pack(fill="x", padx=16, pady=14)
            when = format_local(meta.created_at)
            title = (meta.title or "Tanpa judul").strip()

            actions = ctk.CTkFrame(body, fg_color="transparent")
            if wide:
                actions.pack(side="right", padx=(12, 0))
            info = ctk.CTkFrame(body, fg_color="transparent")
            info.pack(side="left", fill="x", expand=True)

            ctk.CTkLabel(
                info,
                text=title,
                anchor="w",
                justify="left",
                wraplength=480 if wide else 360,
                font=ctk.CTkFont(size=15, weight="bold"),
                text_color=c["text"],
            ).pack(fill="x", anchor="w")
            muted(
                info,
                f"{when}  ·  {meta.mode}  ·  {_fmt_dur(meta.duration_sec)}  ·  {size_mb:.1f} MB",
                c,
                wraplength=480 if wide else 360,
                anchor="w",
                justify="left",
            ).pack(fill="x", anchor="w", pady=(3, 0 if wide else 10))

            if not wide:
                actions.pack(fill="x", pady=(8, 0))

            primary_button(actions, "Putar", lambda p=folder: self._open(p), c, width=72, height=32).pack(
                side="left", padx=(0, 4), pady=2
            )
            ghost_button(actions, "Export", lambda p=folder: self._export(p), c, width=72, height=32).pack(
                side="left", padx=2, pady=2
            )
            ghost_button(actions, "Rename", lambda p=folder: self._rename(p), c, width=72, height=32).pack(
                side="left", padx=2, pady=2
            )
            ghost_button(actions, "Folder", lambda p=folder: self._reveal(p), c, width=72, height=32).pack(
                side="left", padx=2, pady=2
            )
            danger_button(actions, "Hapus", lambda p=folder: self._delete(p), c, width=68, height=32).pack(
                side="left", padx=(4, 0), pady=2
            )
            body.bind("<Double-Button-1>", lambda _e, p=folder: self._open(p))
            row.bind("<Double-Button-1>", lambda _e, p=folder: self._open(p))
        sync_responsive(self)

    def _open(self, path: Path) -> None:
        # One player at a time — reopen if a different session is chosen.
        if self._player_win is not None and focus_existing(self._player_win):
            try:
                if getattr(self._player_win, "session", None) and self._player_win.session.root == path:
                    return
                self._player_win.destroy()
            except Exception:
                pass
            self._player_win = None
        open_singleton(self, "_player_win", lambda: TranscriptPlayerWindow(self, path))

    def _export(self, path: Path) -> None:
        sess = load_session(path)
        from config.settings import Settings

        open_singleton(
            self,
            "_export_win",
            lambda: ExportDialog(self, sess, sess.meta.title, Settings.load()),
        )

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
        try:
            title = load_session(path).meta.title or path.name
        except Exception:
            title = path.name
        if not messagebox.askyesno("Hapus sesi", f"Hapus «{title}»?\nFile audio & transcript akan dihapus."):
            return
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
