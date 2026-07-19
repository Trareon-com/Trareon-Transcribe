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
from util.threading_helpers import run_in_thread


class SettingsWindow(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, settings: Settings, on_saved=None) -> None:  # noqa: ANN001
        super().__init__(master)
        self.settings = settings
        self.on_saved = on_saved
        self.colors = paint_window(self)
        self.title(f"Settings — {APP_NAME}")
        self.minsize(520, 640)
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
        head.pack(fill="x", padx=20, pady=(16, 8))
        heading(head, "Settings", c).pack(side="left")
        muted(head, f"v{__version__}", c).pack(side="left", padx=10)

        foot = ctk.CTkFrame(self, fg_color="transparent")
        foot.pack(side="bottom", fill="x", padx=20, pady=(0, 12))
        muted(foot, "", c, textvariable=self.status, wraplength=360).pack(side="left", fill="x", expand=True)
        primary_button(foot, "Simpan", self._save, c, width=100).pack(side="right")

        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=20, pady=(0, 8))
        form = ctk.CTkScrollableFrame(panel, fg_color="transparent")
        form.pack(fill="both", expand=True, padx=12, pady=12)

        field_label(form, "Model Whisper", c).pack(anchor="w")
        ctk.CTkOptionMenu(
            form,
            variable=self.model_var,
            values=list(WHISPER_MODELS),
            width=280,
            height=32,
            fg_color=c["bg"],
            button_color=c["border"],
            button_hover_color=c["border"],
            text_color=c["text"],
        ).pack(anchor="w", pady=(4, 10))

        field_label(form, "Library root (Sessions)", c).pack(anchor="w")
        styled_entry(form, c, textvariable=self.library_var, width=460).pack(anchor="w", pady=(4, 10))

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
            ).pack(anchor="w", pady=3)

        field_label(form, "Hugging Face token (pyannote only)", c).pack(anchor="w", pady=(12, 0))
        styled_entry(form, c, textvariable=self.hf_var, width=460, show="•").pack(anchor="w", pady=(4, 10))

        devices = AudioCapture.list_devices()
        muted(form, f"Audio devices detected: {len(devices) or 1}", c).pack(anchor="w", pady=(4, 8))

        row = ctk.CTkFrame(form, fg_color="transparent")
        row.pack(fill="x", pady=4)
        ghost_button(row, "Test audio", self._tone, c, width=100).pack(side="left", padx=(0, 6))
        ghost_button(row, "Unduh model", self._download_model, c, width=110).pack(side="left", padx=3)
        ghost_button(row, "Buka log", lambda: self._open(logs_dir()), c, width=90).pack(side="left", padx=3)

        row2 = ctk.CTkFrame(form, fg_color="transparent")
        row2.pack(fill="x", pady=4)
        ghost_button(row2, "Cache model", lambda: self._open(models_dir()), c, width=110).pack(
            side="left", padx=(0, 6)
        )
        ghost_button(
            row2, "Buka library", lambda: self._open(Path(self.library_var.get())), c, width=110
        ).pack(side="left", padx=3)
        ghost_button(row2, "Ulangi Setup", self._rerun_setup, c, width=110).pack(side="left", padx=3)

        self.bar = ctk.CTkProgressBar(form, width=420, progress_color=c["accent"])
        self.bar.set(0)
        self.bar.pack(pady=(12, 4), anchor="w")

        ghost_button(form, "Cek update", self._check_update, c, width=120).pack(anchor="w", pady=(8, 4))

        muted(
            form,
            "Shortcuts: Space Start/Stop · M Mic · S Speaker · E Export · T Tray · , Settings",
            c,
        ).pack(pady=(8, 4), anchor="w")
        muted(
            form,
            f"{APP_NAME} · https://github.com/Trareon-com/Trareon-Transcribe/releases",
            c,
        ).pack(pady=(0, 8), anchor="w")

    def _save(self) -> None:
        self.settings.model = self.model_var.get()
        self.settings.library_root = self.library_var.get()
        self.settings.always_on_top = self.aot_var.get()
        self.settings.reduced_motion = self.motion_var.get()
        self.settings.diarization_enabled = self.diar_var.get()
        set_hf_token(self.hf_var.get().strip())
        ensure_dir(Path(self.settings.library_root))
        self.settings.save()
        self.status.set("Tersimpan.")
        if self.on_saved:
            self.on_saved()

    def _tone(self) -> None:
        self.status.set("Tone test…")

        def work() -> None:
            res = run_tone_test()
            self.settings.tone_test_ok = res.ok
            self.settings.tone_test_skipped = not res.ok
            self.settings.save()
            self.after(0, lambda: self.status.set(res.message))
            if self.on_saved:
                self.after(0, self.on_saved)

        run_in_thread(work)

    def _download_model(self) -> None:
        model = self.model_var.get()
        self.status.set(f"Mengunduh {model}…")

        def progress(name: str, frac: float) -> None:
            self.after(0, lambda: (self.bar.set(frac), self.status.set(f"{name} {frac*100:.0f}%")))

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
                self.after(0, lambda: self.status.set(msg))
                self.after(0, lambda: self.bar.set(1.0))
                if self.on_saved:
                    self.after(0, self.on_saved)
            except Exception as exc:
                err = str(exc)
                self.after(0, lambda m=err: self.status.set(f"Gagal unduh: {m}"))

        run_in_thread(work)

    def _check_update(self) -> None:
        self.status.set("Mengecek update…")

        def work() -> None:
            info = check_for_update()
            if info is None:
                self.after(0, lambda: self.status.set("Tidak bisa cek update (offline / API)."))
                return
            if not info.update_available:
                self.after(0, lambda: self.status.set(f"Sudah versi terbaru ({info.current})."))
                return

            def ask() -> None:
                import tkinter.messagebox as messagebox

                if messagebox.askyesno(
                    "Update tersedia",
                    f"Versi baru {info.latest} (sekarang {info.current}).\nBuka unduhan?",
                ):
                    open_download(info)
                self.status.set(f"Update {info.latest} tersedia.")

            self.after(0, ask)

        run_in_thread(work)

    def _rerun_setup(self) -> None:
        self.settings.setup_complete = False
        self.settings.save()
        self.status.set("Setup akan muncul saat app dibuka ulang. Tutup & jalankan lagi.")

    def _open(self, path: Path) -> None:
        path.mkdir(parents=True, exist_ok=True)
        try:
            if sys.platform == "darwin":
                subprocess.run(["open", str(path)], check=False)
            elif sys.platform == "win32":
                subprocess.run(["explorer", str(path)], check=False)
        except Exception:
            pass
