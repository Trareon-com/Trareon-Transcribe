"""First-run setup wizard."""

from __future__ import annotations

import sys

import customtkinter as ctk

from config.branding import APP_NAME, set_window_icon
from config.keyring_store import set_hf_token
from config.settings import Settings
from engine.audio_capture import AudioCapture
from engine.stt import WhisperCppStt
from engine.tone_test import run_tone_test
from setup.deps import detect_spec, macos_dep_plan, run_plan, windows_dep_plan
from setup.model_dl import download_model, ensure_whisper_binary, suggest_model
from setup.whisper_models import MODEL_LABELS, WHISPER_MODELS
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
from util.threading_helpers import run_in_thread


class SetupWizard(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, settings: Settings, on_done) -> None:  # noqa: ANN001
        super().__init__(master)
        self.settings = settings
        self.on_done = on_done
        self._busy = False
        self._finish_btn: ctk.CTkButton | None = None
        self.colors = paint_window(self)

        self.title(f"{APP_NAME} — Setup")
        self.geometry("700x680+160+80")
        set_window_icon(self)
        self.transient(master)
        self.protocol("WM_DELETE_WINDOW", self._on_close_attempt)
        self.lift()
        self.focus_force()
        try:
            self.grab_set()
        except Exception:
            pass

        self.spec = detect_spec()
        suggested = suggest_model(self.spec["ram_gb"], self.spec["is_apple_silicon"])
        if settings.model in WHISPER_MODELS:
            initial_model = settings.model
        else:
            initial_model = suggested
        self.model_var = ctk.StringVar(value=initial_model)
        self.install_deps_var = ctk.BooleanVar(value=True)
        self.diar_var = ctk.BooleanVar(value=False)
        self.hf_var = ctk.StringVar(value="")
        self.status = ctk.StringVar(value="Siap memulai setup. Anda juga bisa lewati dan lengkapi nanti.")

        c = self.colors
        heading(self, f"{APP_NAME} — Setup", c, size=20).pack(anchor="w", padx=24, pady=(18, 4))
        gpu = self.spec.get("gpu") or "GPU"
        muted(
            self,
            (
                f"Spec terdeteksi: {self.spec['machine']}, {self.spec['ram_gb']:.0f} GB RAM, "
                f"{gpu} — saran model: {suggested}"
            ),
            c,
            wraplength=640,
            font=ctk.CTkFont(size=12),
        ).pack(anchor="w", padx=24, pady=(0, 10))

        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=24, pady=(0, 10))
        frame = ctk.CTkScrollableFrame(panel, fg_color="transparent", height=240)
        frame.pack(fill="both", expand=True, padx=10, pady=10)

        field_label(frame, "Pilih model Whisper", c).pack(anchor="w", padx=8, pady=(4, 6))
        for key in WHISPER_MODELS:
            ctk.CTkRadioButton(
                frame,
                text=MODEL_LABELS[key],
                variable=self.model_var,
                value=key,
                text_color=c["text"],
                fg_color=c["accent"],
                hover_color=c["accent_hover"],
                border_color=c["border"],
            ).pack(anchor="w", padx=16, pady=2)

        opts = ctk.CTkFrame(self, fg_color="transparent")
        opts.pack(fill="x", padx=24, pady=(0, 6))
        ctk.CTkCheckBox(
            opts,
            text="Install virtual cable + ffmpeg (otomatis jika memungkinkan)",
            variable=self.install_deps_var,
            text_color=c["text"],
            fg_color=c["accent"],
            hover_color=c["accent_hover"],
            border_color=c["border"],
            checkmark_color=c["on_accent"],
        ).pack(anchor="w", pady=3)
        ctk.CTkCheckBox(
            opts,
            text="Siapkan diarization pyannote (butuh HF token)",
            variable=self.diar_var,
            text_color=c["text"],
            fg_color=c["accent"],
            hover_color=c["accent_hover"],
            border_color=c["border"],
            checkmark_color=c["on_accent"],
        ).pack(anchor="w", pady=3)
        styled_entry(
            opts, c, textvariable=self.hf_var, placeholder_text="HF token (opsional)", width=420
        ).pack(anchor="w", pady=(6, 0))

        self.progress = ctk.CTkProgressBar(self, width=540, progress_color=c["accent"])
        self.progress.set(0)
        self.progress.pack(padx=24, pady=8, anchor="w")
        muted(self, "", c, textvariable=self.status, wraplength=640, font=ctk.CTkFont(size=12)).pack(
            anchor="w", padx=24
        )

        self.btn_row = ctk.CTkFrame(self, fg_color="transparent")
        self.btn_row.pack(fill="x", padx=24, pady=(10, 18))
        self.start_btn = primary_button(self.btn_row, "Mulai Setup", self._start, c, width=120)
        self.start_btn.pack(side="left", padx=(0, 6))
        ghost_button(self.btn_row, "Tone Test", self._tone, c, width=100).pack(side="left", padx=4)
        ghost_button(self.btn_row, "Lewati Tone", self._skip_tone, c, width=110).pack(side="left", padx=4)
        ghost_button(self.btn_row, "Lewati & buka app", self._skip_all, c, width=140).pack(side="left", padx=4)

        stt = WhisperCppStt(self.model_var.get())
        if stt.available():
            self.status.set("Model/binary sudah ada — Anda bisa lanjut atau unduh ulang.")

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        state = "disabled" if busy else "normal"
        try:
            self.start_btn.configure(state=state)
        except Exception:
            pass

    def _set_progress(self, name: str, frac: float) -> None:
        self.after(
            0,
            lambda: (
                self.progress.set(frac),
                self.status.set(f"Mengunduh {name}… {frac * 100:.0f}%"),
            ),
        )

    def _start(self) -> None:
        if self._busy:
            return
        self._set_busy(True)
        self.status.set("Menjalankan setup…")
        run_in_thread(self._run_setup)

    def _run_setup(self) -> None:
        try:
            from config.branding import APP_NAME, apply_macos_menu_name, running_from_app_bundle

            self.after(0, lambda: apply_macos_menu_name(APP_NAME))
            if sys.platform == "darwin" and not running_from_app_bundle():
                self.after(
                    0,
                    lambda: self.status.set(
                        f"⚠ Jalankan via ./scripts/run_mac_app.sh agar izin mic "
                        f"tampil sebagai «{APP_NAME}», bukan Python 3.11."
                    ),
                )
            ok, msg = AudioCapture.check_mic_permission()
            self.after(0, lambda: self.status.set(msg if ok else f"⚠ {msg}"))
            if self.install_deps_var.get():
                plan = macos_dep_plan() if self.spec["os"] == "Darwin" else windows_dep_plan()
                cmds = " | ".join(" ".join(c) for c in plan.commands) or plan.description
                self.after(0, lambda: self.status.set(f"Deps: {cmds[:200]}"))
                success, out = run_plan(plan)
                self.after(
                    0,
                    lambda: self.status.set(
                        (out[:400] if out else "Deps OK") if success else f"Deps gagal: {out[:300]}"
                    ),
                )
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
            lib = str(self.settings.library_path())
            self.after(0, lambda: self._setup_done_ui(lib))
        except Exception as exc:
            err = str(exc)
            self.after(0, lambda m=err: self.status.set(f"Setup gagal: {m}"))
            self.after(0, lambda: self._set_busy(False))

    def _setup_done_ui(self, lib_path: str) -> None:
        self.progress.set(1.0)
        self.status.set(f"Setup selesai. Rekaman disimpan di:\n{lib_path}")
        self._set_busy(False)
        if self._finish_btn is None:
            self._finish_btn = primary_button(
                self, "Lanjut ke App", self._finish, self.colors, width=180, height=36
            )
            self._finish_btn.pack(pady=10)

    def _tone(self) -> None:
        if self._busy:
            return
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

    def _skip_all(self) -> None:
        if self._busy:
            return
        self.settings.model = self.model_var.get()
        self.settings.setup_complete = True
        self.settings.tone_test_skipped = True
        self.settings.save()
        self.status.set("Setup dilewati. Unduh model nanti di Settings / jalankan ulang setup.")
        self._finish()

    def _on_close_attempt(self) -> None:
        if self._busy:
            self.status.set("Setup sedang berjalan — tunggu selesai atau biarkan window terbuka.")
            return
        self._skip_all()

    def _finish(self) -> None:
        try:
            self.grab_release()
        except Exception:
            pass
        self.destroy()
        self.on_done()
