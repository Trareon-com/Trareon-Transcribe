"""Settings panel — model, devices, library path, tokens, tone test."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import customtkinter as ctk

from config.branding import APP_NAME, set_window_icon
from config.keyring_store import get_hf_token, set_hf_token
from config.paths import logs_dir, models_dir
from config.settings import Settings
from config.version import __version__
from engine.audio_capture import AudioCapture
from engine.tone_test import run_tone_test
from setup.model_dl import download_model, ensure_whisper_binary
from setup.whisper_models import WHISPER_MODELS
from util.threading_helpers import run_in_thread


class SettingsWindow(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, settings: Settings, on_saved=None) -> None:  # noqa: ANN001
        super().__init__(master)
        self.settings = settings
        self.on_saved = on_saved
        self.title(f"Settings — {APP_NAME}")
        self.geometry("520x600")
        set_window_icon(self)
        self.transient(master)

        self.model_var = ctk.StringVar(value=settings.model)
        self.library_var = ctk.StringVar(value=settings.library_root)
        self.aot_var = ctk.BooleanVar(value=settings.always_on_top)
        self.diar_var = ctk.BooleanVar(value=settings.diarization_enabled)
        self.tr_var = ctk.BooleanVar(value=settings.translate_enabled)
        self.motion_var = ctk.BooleanVar(value=settings.reduced_motion)
        self.hf_var = ctk.StringVar(value=get_hf_token() or "")
        self.status = ctk.StringVar(value="")

        ctk.CTkLabel(self, text="Settings", font=ctk.CTkFont(size=18, weight="bold")).pack(pady=12)
        form = ctk.CTkScrollableFrame(self, height=400)
        form.pack(fill="both", expand=True, padx=16)

        ctk.CTkLabel(form, text="Model Whisper").pack(anchor="w")
        ctk.CTkOptionMenu(form, variable=self.model_var, values=list(WHISPER_MODELS)).pack(
            anchor="w", pady=4
        )

        ctk.CTkLabel(form, text="Library root (Sessions)").pack(anchor="w", pady=(10, 0))
        ctk.CTkEntry(form, textvariable=self.library_var, width=420).pack(anchor="w", pady=4)

        ctk.CTkCheckBox(form, text="Always on top", variable=self.aot_var).pack(anchor="w", pady=4)
        ctk.CTkCheckBox(form, text="Reduced motion (MIC OFF solid warning)", variable=self.motion_var).pack(
            anchor="w", pady=4
        )
        ctk.CTkCheckBox(form, text="Enable pyannote diarization", variable=self.diar_var).pack(anchor="w", pady=4)
        ctk.CTkCheckBox(form, text="Enable offline translate (Argos)", variable=self.tr_var).pack(anchor="w", pady=4)

        ctk.CTkLabel(form, text="Hugging Face token").pack(anchor="w", pady=(10, 0))
        ctk.CTkEntry(form, textvariable=self.hf_var, width=420, show="•").pack(anchor="w", pady=4)

        devices = AudioCapture.list_devices()
        names = [str(d.get("name", i)) for i, d in enumerate(devices)] or ["(default)"]
        ctk.CTkLabel(form, text=f"Audio devices detected: {len(names)}").pack(anchor="w", pady=(10, 0))

        row = ctk.CTkFrame(form, fg_color="transparent")
        row.pack(fill="x", pady=8)
        ctk.CTkButton(row, text="Test audio routing", command=self._tone).pack(side="left", padx=4)
        ctk.CTkButton(row, text="Unduh model", command=self._download_model).pack(side="left", padx=4)
        ctk.CTkButton(row, text="Buka log", command=lambda: self._open(logs_dir())).pack(side="left", padx=4)

        row2 = ctk.CTkFrame(form, fg_color="transparent")
        row2.pack(fill="x", pady=4)
        ctk.CTkButton(row2, text="Buka cache model", command=lambda: self._open(models_dir())).pack(
            side="left", padx=4
        )
        ctk.CTkButton(row2, text="Buka library", command=lambda: self._open(Path(self.library_var.get()))).pack(
            side="left", padx=4
        )
        ctk.CTkButton(row2, text="Ulangi Setup", command=self._rerun_setup).pack(side="left", padx=4)

        self.bar = ctk.CTkProgressBar(form, width=400)
        self.bar.set(0)
        self.bar.pack(pady=8)

        ctk.CTkLabel(self, textvariable=self.status, wraplength=480).pack(pady=4)
        ctk.CTkButton(self, text="Simpan", command=self._save).pack(pady=10)

        shortcuts = (
            "Shortcuts: Space Start/Stop · M Mic · S Speaker · E Export · T Tray · , Settings"
        )
        ctk.CTkLabel(self, text=shortcuts, text_color="gray").pack(pady=(0, 4))
        ctk.CTkLabel(
            self,
            text=f"{APP_NAME} v{__version__} · https://github.com/Trareon-com/Trareon-Transcribe/releases",
            text_color="gray",
            font=ctk.CTkFont(size=11),
        ).pack(pady=(0, 10))

    def _save(self) -> None:
        self.settings.model = self.model_var.get()
        self.settings.library_root = self.library_var.get()
        self.settings.always_on_top = self.aot_var.get()
        self.settings.reduced_motion = self.motion_var.get()
        self.settings.diarization_enabled = self.diar_var.get()
        self.settings.translate_enabled = self.tr_var.get()
        set_hf_token(self.hf_var.get().strip())
        Path(self.settings.library_root).mkdir(parents=True, exist_ok=True)
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

        run_in_thread(work)

    def _download_model(self) -> None:
        model = self.model_var.get()
        self.status.set(f"Mengunduh {model}…")

        def progress(name: str, frac: float) -> None:
            self.after(0, lambda: (self.bar.set(frac), self.status.set(f"{name} {frac*100:.0f}%")))

        def work() -> None:
            try:
                ensure_whisper_binary(progress=progress)
                download_model(model, progress=progress)
                self.settings.model = model
                self.settings.save()
                self.after(0, lambda: self.status.set(f"Model {model} siap."))
                self.after(0, lambda: self.bar.set(1.0))
            except Exception as exc:
                err = str(exc)
                self.after(0, lambda m=err: self.status.set(f"Gagal unduh: {m}"))

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
