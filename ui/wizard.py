"""First-run setup wizard."""

from __future__ import annotations

import customtkinter as ctk

from config.keyring_store import set_hf_token
from config.settings import Settings
from engine.audio_capture import AudioCapture
from engine.tone_test import run_tone_test
from setup.deps import detect_spec, macos_dep_plan, run_plan, windows_dep_plan
from setup.model_dl import download_model, ensure_whisper_binary, suggest_model
from util.threading_helpers import run_in_thread


class SetupWizard(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, settings: Settings, on_done) -> None:  # noqa: ANN001
        super().__init__(master)
        self.settings = settings
        self.on_done = on_done
        self.title("Trareon Transcribe — Setup")
        self.geometry("640x520")
        self.transient(master)
        self.grab_set()

        self.spec = detect_spec()
        suggested = suggest_model(self.spec["ram_gb"], self.spec["is_apple_silicon"])
        self.model_var = ctk.StringVar(value=settings.model or suggested)
        self.install_deps_var = ctk.BooleanVar(value=True)
        self.diar_var = ctk.BooleanVar(value=False)
        self.hf_var = ctk.StringVar(value="")
        self.status = ctk.StringVar(value="Siap memulai setup.")

        ctk.CTkLabel(self, text="Trareon Transcribe — Setup", font=ctk.CTkFont(size=20, weight="bold")).pack(
            pady=(16, 8)
        )
        ctk.CTkLabel(
            self,
            text=f"Spec: {self.spec['machine']}, {self.spec['ram_gb']:.0f} GB RAM — saran model: {suggested}",
            wraplength=580,
        ).pack(pady=4)

        frame = ctk.CTkFrame(self)
        frame.pack(fill="x", padx=20, pady=10)
        ctk.CTkLabel(frame, text="Pilih model Whisper:").pack(anchor="w", padx=12, pady=(8, 4))
        for key, desc in (
            ("tiny", "tiny ~75MB — cepat, akurasi rendah"),
            ("medium", "medium ~1.5GB — seimbang"),
            ("large-v3-turbo", "large-v3-turbo ~3GB — akurasi tinggi ID/EN"),
        ):
            ctk.CTkRadioButton(frame, text=desc, variable=self.model_var, value=key).pack(anchor="w", padx=20, pady=2)

        ctk.CTkCheckBox(self, text="Install virtual cable + ffmpeg (otomatis jika memungkinkan)", variable=self.install_deps_var).pack(
            anchor="w", padx=24, pady=6
        )
        ctk.CTkCheckBox(self, text="Siapkan diarization pyannote (butuh HF token)", variable=self.diar_var).pack(
            anchor="w", padx=24, pady=2
        )
        ctk.CTkEntry(self, textvariable=self.hf_var, placeholder_text="HF token (opsional)", width=400).pack(
            padx=24, pady=6
        )

        self.progress = ctk.CTkProgressBar(self, width=500)
        self.progress.set(0)
        self.progress.pack(pady=8)
        ctk.CTkLabel(self, textvariable=self.status, wraplength=580).pack(pady=4)

        btn_row = ctk.CTkFrame(self, fg_color="transparent")
        btn_row.pack(pady=12)
        ctk.CTkButton(btn_row, text="Mulai Setup", command=self._start).pack(side="left", padx=6)
        ctk.CTkButton(btn_row, text="Tone Test", command=self._tone).pack(side="left", padx=6)
        ctk.CTkButton(btn_row, text="Lewati Tone Test", command=self._skip_tone).pack(side="left", padx=6)

    def _set_progress(self, name: str, frac: float) -> None:
        self.after(0, lambda: (self.progress.set(frac), self.status.set(f"Downloading {name}… {frac*100:.0f}%")))

    def _start(self) -> None:
        self.status.set("Menjalankan setup…")
        run_in_thread(self._run_setup)

    def _run_setup(self) -> None:
        try:
            ok, msg = AudioCapture.check_mic_permission()
            self.after(0, lambda: self.status.set(msg))
            if self.install_deps_var.get():
                plan = macos_dep_plan() if self.spec["os"] == "Darwin" else windows_dep_plan()
                self.after(0, lambda: self.status.set("Perintah: " + " | ".join(" ".join(c) for c in plan.commands)))
                success, out = run_plan(plan)
                self.after(0, lambda: self.status.set(out[:500] if out else ("OK" if success else "Gagal deps")))
            self.after(0, lambda: self.status.set("Mengunduh whisper binary…"))
            ensure_whisper_binary(progress=self._set_progress)
            model = self.model_var.get()
            download_model(model, progress=self._set_progress)
            if self.hf_var.get().strip():
                set_hf_token(self.hf_var.get().strip())
            self.settings.model = model
            self.settings.diarization_enabled = bool(self.diar_var.get())
            self.settings.setup_complete = True
            self.settings.save()
            self.after(0, lambda: self.status.set(
                f"Setup selesai. Rekaman disimpan di: {self.settings.library_path()}"
            ))
            self.after(0, lambda: ctk.CTkButton(self, text="Lanjut ke App", command=self._finish).pack(pady=8))
        except Exception as exc:
            err = str(exc)
            self.after(0, lambda m=err: self.status.set(f"Setup gagal: {m}"))

    def _tone(self) -> None:
        self.status.set("Menjalankan tone test…")

        def work() -> None:
            res = run_tone_test()
            self.settings.tone_test_ok = res.ok
            self.settings.tone_test_skipped = False
            self.settings.save()
            self.after(0, lambda: self.status.set(res.message))

        run_in_thread(work)

    def _skip_tone(self) -> None:
        self.settings.tone_test_skipped = True
        self.settings.tone_test_ok = False
        self.settings.save()
        self.status.set("Tone test dilewati — banner peringatan akan tampil di app.")

    def _finish(self) -> None:
        self.grab_release()
        self.destroy()
        self.on_done()
