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
from setup.whisper_models import MODEL_LABELS, MODEL_SIZES, WHISPER_MODELS
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
        self.minsize(520, 560)
        self.geometry("700x700+160+80")
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
        self.status = ctk.StringVar(
            value=(
                "Setup wajib sebelum rekaman nyata: unduh model + pasang "
                "BlackHole (Mac) / VB-Cable (Win). Lewati hanya jika Anda paham risikonya."
            )
        )

        c = self.colors
        heading(self, f"{APP_NAME} — Setup", c, size=22).pack(anchor="w", fill="x", padx=24, pady=(20, 4))
        gpu = self.spec.get("gpu") or "GPU"
        self.spec_lbl = muted(
            self,
            (
                f"Spec terdeteksi: {self.spec['machine']}, {self.spec['ram_gb']:.0f} GB RAM, "
                f"{gpu} — saran model: {suggested}"
            ),
            c,
            wraplength=400,
            font=ctk.CTkFont(size=12),
            anchor="w",
            justify="left",
        )
        self.spec_lbl.pack(anchor="w", fill="x", padx=24, pady=(0, 12))

        panel = panel_frame(self, c)
        panel.pack(fill="both", expand=True, padx=24, pady=(0, 12))
        frame = ctk.CTkScrollableFrame(panel, fg_color="transparent")
        frame.pack(fill="both", expand=True, padx=10, pady=10)

        field_label(frame, "Pilih model Whisper", c).pack(anchor="w", padx=8, pady=(4, 6))
        for key in WHISPER_MODELS:
            size = MODEL_SIZES.get(key, 0)
            size_str = f" ({size} MB)" if size else ""
            ctk.CTkRadioButton(
                frame,
                text=MODEL_LABELS[key] + size_str,
                variable=self.model_var,
                value=key,
                text_color=c["text"],
                fg_color=c["accent"],
                hover_color=c["accent_hover"],
                border_color=c["border"],
            ).pack(anchor="w", fill="x", padx=16, pady=2)

        opts = ctk.CTkFrame(self, fg_color="transparent")
        opts.pack(fill="x", padx=24, pady=(0, 6))
        self.deps_cb = ctk.CTkCheckBox(
            opts,
            text=(
                "Install BlackHole + ffmpeg (Mac via brew) — wajib agar VU SPK / "
                "Zoom terdengar. Windows: VB-Cable manual (lihat README)."
            ),
            variable=self.install_deps_var,
            text_color=c["text"],
            fg_color=c["accent"],
            hover_color=c["accent_hover"],
            border_color=c["border"],
            checkmark_color=c["on_accent"],
        )
        self.deps_cb.pack(anchor="w", fill="x", pady=3)
        self.diar_cb = ctk.CTkCheckBox(
            opts,
            text="Siapkan diarization pyannote (butuh HF token)",
            variable=self.diar_var,
            text_color=c["text"],
            fg_color=c["accent"],
            hover_color=c["accent_hover"],
            border_color=c["border"],
            checkmark_color=c["on_accent"],
        )
        self.diar_cb.pack(anchor="w", fill="x", pady=3)
        styled_entry(
            opts, c, textvariable=self.hf_var, placeholder_text="HF token (opsional)"
        ).pack(anchor="w", fill="x", pady=(6, 0))

        self.progress = ctk.CTkProgressBar(self, progress_color=c["accent"])
        self.progress.set(0)
        self.progress.pack(fill="x", padx=24, pady=(12, 2))
        self.step_var = ctk.StringVar(value="")
        self.step_lbl = muted(
            self, "", c, textvariable=self.step_var, wraplength=420, font=ctk.CTkFont(size=11, weight="bold")
        )
        self.step_lbl.pack(anchor="w", fill="x", padx=26, pady=(0, 2))
        self.status_lbl = muted(
            self, "", c, textvariable=self.status, wraplength=400, font=ctk.CTkFont(size=12)
        )
        self.status_lbl.pack(anchor="w", fill="x", padx=24)

        self.btn_row = ctk.CTkFrame(self, fg_color="transparent")
        self.btn_row.pack(fill="x", padx=24, pady=(12, 4))
        self.start_btn = primary_button(self.btn_row, "Mulai Setup", self._start, c, width=132)
        self.start_btn.pack(side="left", padx=(0, 8), pady=2)
        ghost_button(self.btn_row, "Tone Test", self._tone, c, width=100).pack(side="left", padx=4, pady=2)
        ghost_button(self.btn_row, "Lewati Tone", self._skip_tone, c, width=110).pack(
            side="left", padx=4, pady=2
        )
        btn_row2 = ctk.CTkFrame(self, fg_color="transparent")
        btn_row2.pack(fill="x", padx=24, pady=(4, 20))
        muted(
            btn_row2,
            "Lewati hanya jika model + routing audio sudah siap.",
            c,
            wraplength=400,
            anchor="w",
        ).pack(side="left", fill="x", expand=True, padx=(0, 8))
        ghost_button(btn_row2, "Lewati & buka app", self._skip_all, c, width=150).pack(
            side="right", pady=2
        )
        bind_responsive(self)

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
            self.after(0, lambda: self.step_var.set("1/5: Memeriksa perangkat audio & izin mic"))
            ok, msg = AudioCapture.check_mic_permission()
            self.after(0, lambda: self.status.set(msg if ok else f"⚠ {msg}"))
            if self.install_deps_var.get():
                self.after(0, lambda: self.step_var.set("2/5: Memasang BlackHole / VB-Cable"))
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
            # Audio routing check — safe, no system changes
            self.after(0, lambda: self.step_var.set("3/5: Memeriksa BlackHole & routing"))
            try:
                from engine.audio_capture import find_loopback_input_device
                bh = find_loopback_input_device()
                if bh is not None:
                    self.after(0, lambda: self.status.set(
                        "BlackHole terdeteksi ✓ — routing dapat diatur nanti"
                    ))
                else:
                    self.after(0, lambda: self.status.set(
                        "BlackHole tidak terdeteksi — SPK capture hanya via MIC"
                    ))
            except Exception:
                self.after(0, lambda: self.status.set("Pengecekan routing: skip"))
            self.after(0, lambda: self.step_var.set("4/5: Mengunduh binary whisper.cpp"))
            self.after(0, lambda: self.status.set("Mengunduh whisper binary…"))
            binary = ensure_whisper_binary(progress=self._set_progress)
            model = self.model_var.get()
            self.after(0, lambda: self.step_var.set("5/5: Mengunduh model & menyimpan"))
            self.after(0, lambda: self.status.set(f"Mengunduh model {model}…"))
            download_model(model, progress=self._set_progress)
            if self.hf_var.get().strip():
                set_hf_token(self.hf_var.get().strip())
            self.settings.model = model
            self.settings.diarization_enabled = bool(self.diar_var.get())
            stt_ok = WhisperCppStt(model).available()
            self.settings.setup_complete = stt_ok
            self.settings.save()
            lib = str(self.settings.library_path())
            note = ""
            if not stt_ok:
                note = (
                    " STT belum lengkap"
                    + ("" if binary else " (whisper-cli gagal / belum terpasang)")
                    + "."
                )
            self.after(0, lambda: self._setup_done_ui(lib, note))
        except Exception as exc:
            err = str(exc)
            self.after(0, lambda m=err: self.status.set(f"Setup gagal: {m}"))
            self.after(0, lambda: self._set_busy(False))

    def _setup_done_ui(self, lib_path: str, note: str = "") -> None:
        self.progress.set(1.0)
        self.step_var.set("✓ Setup selesai")
        self.status.set(f"Setup selesai{note} Rekaman disimpan di:\n{lib_path}")
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
        self._set_busy(True)

        def work() -> None:
            res = run_tone_test()
            self.settings.tone_test_ok = res.ok
            self.settings.tone_test_skipped = False
            self.settings.save()
            self.after(0, lambda: self.status.set(res.message))
            self.after(0, lambda: self._set_busy(False))

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
        # Explicit skip: allow app entry; readiness banner will warn if STT incomplete.
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
