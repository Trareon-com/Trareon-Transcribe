"""Settings panel — model, devices, library path, tokens, tone test."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import customtkinter as ctk

from config.branding import APP_NAME, set_window_icon
from config.keyring_store import get_hf_token, set_hf_token
from config.paths import ensure_dir, logs_dir, models_dir
from config.settings import Settings
from config.version import __version__
from engine.audio_capture import AudioCapture
from engine.stt import WhisperCppStt
from engine.tone_test import run_tone_test
from setup.model_dl import download_model, ensure_whisper_binary
from setup.whisper_models import WHISPER_MODELS
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
from update.check import check_for_update, open_download
from util.threading_helpers import run_in_thread, ui_after


class SettingsWindow(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, settings: Settings, on_saved=None) -> None:  # noqa: ANN001
        super().__init__(master)
        self.settings = settings
        self.on_saved = on_saved
        self.colors = paint_window(self)
        self.title(f"Settings — {APP_NAME}")
        self.minsize(480, 560)
        self.geometry("560x680")
        set_window_icon(self)
        self.transient(master)

        self.model_var = ctk.StringVar(value=settings.model)
        self.library_var = ctk.StringVar(value=settings.library_root)
        self.aot_var = ctk.BooleanVar(value=settings.always_on_top)
        self.diar_var = ctk.BooleanVar(value=settings.diarization_enabled)
        self.motion_var = ctk.BooleanVar(value=settings.reduced_motion)
        self.hf_var = ctk.StringVar(value=get_hf_token() or "")
        self.status = ctk.StringVar(value="")

        c = self.colors
        head = ctk.CTkFrame(self, fg_color="transparent")
        head.pack(fill="x", padx=22, pady=(18, 8))
        heading(head, "Settings", c, size=20).pack(side="left")
        muted(head, f"v{__version__}", c).pack(side="left", padx=10)

        foot = ctk.CTkFrame(self, fg_color="transparent")
        foot.pack(side="bottom", fill="x", padx=22, pady=(0, 14))
        primary_button(foot, "Simpan", self._save, c, width=108).pack(side="right")
        self.status_lbl = muted(foot, "", c, textvariable=self.status, wraplength=280, anchor="w")
        self.status_lbl.pack(side="left", fill="x", expand=True, padx=(0, 10))

        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=22, pady=(0, 8))
        form = ctk.CTkScrollableFrame(panel, fg_color="transparent")
        form.pack(fill="both", expand=True, padx=14, pady=14)

        def _section(title: str) -> None:
            field_label(form, title, c).pack(anchor="w", pady=(10, 4))

        _section("Model & library")
        ctk.CTkOptionMenu(
            form,
            variable=self.model_var,
            values=list(WHISPER_MODELS),
            height=32,
            fg_color=c["bg"],
            button_color=c["border"],
            button_hover_color=c["border"],
            text_color=c["text"],
        ).pack(anchor="w", fill="x", pady=(0, 8))
        muted(form, "Library root (Sessions)", c, font=ctk.CTkFont(size=11)).pack(anchor="w")
        lib_row = ctk.CTkFrame(form, fg_color="transparent")
        lib_row.pack(anchor="w", fill="x", pady=(2, 6))
        styled_entry(lib_row, c, textvariable=self.library_var).pack(side="left", fill="x", expand=True)
        ghost_button(lib_row, "Browse…", self._browse_library, c, width=88).pack(side="left", padx=(8, 0))

        _section("Preferensi")
        for text, var in (
            ("Always on top", self.aot_var),
            ("Reduced motion (MIC OFF solid warning)", self.motion_var),
            ("Enable pyannote diarization", self.diar_var),
        ):
            ctk.CTkCheckBox(
                form,
                text=text,
                variable=var,
                text_color=c["text"],
                fg_color=c["accent"],
                hover_color=c["accent_hover"],
                border_color=c["border"],
                checkmark_color=c["on_accent"],
            ).pack(anchor="w", fill="x", pady=3)

        _section("Diarization (pyannote)")
        styled_entry(form, c, textvariable=self.hf_var, show="•").pack(anchor="w", fill="x", pady=(0, 4))
        from engine.diarization import pyannote_status

        self.hf_status = ctk.StringVar(value=pyannote_status(self.hf_var.get().strip() or get_hf_token()))
        self.hf_status_lbl = muted(form, "", c, textvariable=self.hf_status, wraplength=400, anchor="w")
        self.hf_status_lbl.pack(anchor="w", fill="x", pady=(0, 6))

        devices = AudioCapture.list_devices()
        muted(form, f"Audio devices detected: {len(devices) or 1}", c).pack(anchor="w", pady=(4, 6))

        _section("Alat")
        for texts in (
            (
                ("Test audio", self._tone, 100),
                ("Unduh model", self._download_model, 110),
                ("Buka log", lambda: self._open(logs_dir()), 90),
            ),
            (
                ("Cache model", lambda: self._open(models_dir()), 110),
                ("Buka library", lambda: self._open(Path(self.library_var.get())), 110),
                ("Ulangi Setup", self._rerun_setup, 110),
            ),
        ):
            row = ctk.CTkFrame(form, fg_color="transparent")
            row.pack(fill="x", pady=3)
            for label, cmd, w in texts:
                ghost_button(row, label, cmd, c, width=w).pack(side="left", padx=(0, 6), pady=2)

        self.bar = ctk.CTkProgressBar(form, progress_color=c["accent"])
        self.bar.set(0)
        self.bar.pack(fill="x", pady=(12, 4), anchor="w")

        ghost_button(form, "Cek update", self._check_update, c, width=120).pack(anchor="w", pady=(8, 4))

        self.hint_lbl = muted(
            form,
            "Shortcuts: Space Start/Stop · M Mic · S Speaker · E Export · T Tray · "
            "Cmd/Ctrl+L Clear · Cmd/Ctrl+/- Font · , Settings",
            c,
            wraplength=400,
            anchor="w",
        )
        self.hint_lbl.pack(fill="x", pady=(10, 4), anchor="w")
        self.link_lbl = muted(
            form,
            f"{APP_NAME} · https://github.com/Trareon-com/Trareon-Transcribe/releases",
            c,
            wraplength=400,
            anchor="w",
        )
        self.link_lbl.pack(fill="x", pady=(0, 8), anchor="w")
        bind_responsive(self)

    def _save(self) -> None:
        self.settings.model = self.model_var.get()
        self.settings.library_root = self.library_var.get()
        self.settings.always_on_top = self.aot_var.get()
        self.settings.reduced_motion = self.motion_var.get()
        self.settings.diarization_enabled = self.diar_var.get()
        token = self.hf_var.get().strip()
        try:
            set_hf_token(token)
        except Exception as e:
            self.status.set(f"Gagal simpan token ke keyring: {e}")
            return
        ensure_dir(Path(self.settings.library_root))
        self.settings.save()
        from engine.diarization import pyannote_status

        msg = pyannote_status(token or get_hf_token())
        self.hf_status.set(msg)
        if self.diar_var.get() and "pyannote" in msg and "siap" not in msg:
            self.status.set("Tersimpan — tapi pyannote belum siap (lihat status token).")
        else:
            self.status.set("Tersimpan.")
            self.after(2500, lambda: self.status.set("") if self.status.get() == "Tersimpan." else None)
        if self.on_saved:
            self.on_saved()

    def _tone(self) -> None:
        self.status.set("Tone test…")

        def work() -> None:
            res = run_tone_test()
            self.settings.tone_test_ok = res.ok
            self.settings.tone_test_skipped = not res.ok
            self.settings.save()
            ui_after(self, lambda: self.status.set(res.message))
            if self.on_saved:
                ui_after(self, self.on_saved)

        run_in_thread(work)

    def _download_model(self) -> None:
        model = self.model_var.get()
        self.status.set(f"Mengunduh {model}…")

        def progress(name: str, frac: float) -> None:
            ui_after(self, lambda: (self.bar.set(frac), self.status.set(f"{name} {frac*100:.0f}%")))

        def work() -> None:
            try:
                binary = ensure_whisper_binary(progress=progress)
                download_model(model, progress=progress)
                self.settings.model = model
                stt = WhisperCppStt(model)
                if stt.available():
                    self.settings.setup_complete = True
                    msg = f"Model {model} siap (STT OK)."
                elif binary is None:
                    msg = (
                        f"Model {model} terunduh, tapi whisper-cli belum ada. "
                        "Windows: unduh ulang release terbaru. macOS: brew install whisper-cpp."
                    )
                else:
                    msg = f"Model {model} terunduh — cek binary di cache models."
                self.settings.save()
                ui_after(self, lambda: self.status.set(msg))
                ui_after(self, lambda: self.bar.set(1.0))
                if self.on_saved:
                    ui_after(self, self.on_saved)
            except Exception as exc:
                err = str(exc)
                ui_after(self, lambda m=err: self.status.set(f"Gagal unduh: {m}"))

        run_in_thread(work)

    def _check_update(self) -> None:
        self.status.set("Mengecek update…")

        def work() -> None:
            info = check_for_update()
            if info is None:
                ui_after(self, lambda: self.status.set("Tidak bisa cek update (offline / API)."))
                return
            if not info.update_available:
                ui_after(self, lambda: self.status.set(f"Sudah versi terbaru ({info.current})."))
                return

            def ask() -> None:
                import tkinter.messagebox as messagebox

                if messagebox.askyesno(
                    "Update tersedia",
                    f"Versi baru {info.latest} (sekarang {info.current}).\nBuka unduhan?",
                ):
                    open_download(info)
                self.status.set(f"Update {info.latest} tersedia.")

            ui_after(self, ask)

        run_in_thread(work)

    def _rerun_setup(self) -> None:
        self.settings.setup_complete = False
        self.settings.save()
        self.status.set("Setup akan muncul saat app dibuka ulang. Tutup & jalankan lagi.")

    def _browse_library(self) -> None:
        from tkinter import filedialog

        initial = self.library_var.get().strip() or str(Path.home())
        path = filedialog.askdirectory(initialdir=initial, title="Pilih folder Library")
        if path:
            self.library_var.set(path)
            self.status.set("Folder dipilih — klik Simpan.")

    def _open(self, path: Path) -> None:
        path.mkdir(parents=True, exist_ok=True)
        try:
            if sys.platform == "darwin":
                subprocess.run(["open", str(path)], check=False)
            elif sys.platform == "win32":
                subprocess.run(["explorer", str(path)], check=False)
        except Exception:
            pass
