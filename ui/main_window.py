"""Main CustomTkinter window — modes, toggles, live caption, controls."""

from __future__ import annotations

import tkinter as tk
import tkinter.messagebox as messagebox

import customtkinter as ctk

from config.branding import APP_NAME, set_window_icon
from config.settings import Settings
from config.version import __version__
from engine.pipeline import Pipeline, PipelineStatus
from engine.session_store import Session, TranscriptSegment, find_inprogress
from engine.stt import WhisperCppStt
from export.naming import detect_meeting_title
from export.writer import format_caption_line
from setup.disk import MIN_SESSION_FREE, ensure_space
from ui.export_dialog import ExportDialog
from ui.library import LibraryWindow
from ui.resume_dialog import ResumeDialog
from ui.settings_window import SettingsWindow
from ui.theme import apply_theme
from ui.tray import TrayController
from util.threading_helpers import UiEventQueue


class MainWindow(ctk.CTk):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.settings = settings
        self.colors = apply_theme(settings.theme)
        self.title(f"{APP_NAME}  v{__version__}")
        set_window_icon(self)
        self.minsize(780, 520)
        geo = settings.window_geometry or "920x640"
        if "x" in geo and "+" not in geo:
            self.geometry(f"{geo}+120+80")
        else:
            self.geometry(geo)
        if settings.window_x is not None and settings.window_y is not None:
            if settings.window_x >= -20 and settings.window_y >= -20:
                self.geometry(f"{geo.split('+')[0]}+{settings.window_x}+{settings.window_y}")
        self.attributes("-topmost", settings.always_on_top)

        self.events = UiEventQueue()
        self.pipeline: Pipeline | None = None
        self.session: Session | None = None
        self._recording = False
        self._auto_scroll = True
        self._mic_blink_on = False
        self._partial_mark: str | None = None
        self._conf_scores: list[float] = []
        self._caption_font_size = 14

        self.mode_var = ctk.StringVar(value=settings.meeting_mode)
        self.title_var = ctk.StringVar(value=settings.last_meeting_title or "")
        self.status_var = ctk.StringVar(value=PipelineStatus.IDLE.value)
        self.timer_var = ctk.StringVar(value="00:00:00")
        self.res_var = ctk.StringVar(value="CPU —  RAM —  GPU —")
        self.conf_var = ctk.StringVar(value="Conf —")
        self.banner_var = ctk.StringVar(value="")
        self.ready_var = ctk.StringVar(value="")
        self.mic_var = ctk.StringVar(value="ON")
        self.spk_var = ctk.StringVar(value="ON")
        self.font_var = ctk.StringVar(value="14")

        self._build()
        self._bind_keys()
        self._apply_mode_defaults()
        self._prefill_title()
        self.refresh_readiness()

        self.tray = TrayController(on_show=self._show_from_tray, on_quit=self._quit_app)
        self.protocol("WM_DELETE_WINDOW", self._on_close)
        self.after(200, self._poll)
        self.after(500, self._check_resume)
        self.after(1000, self._tick_resources)
        self.after(100, self._tick_vu)

    def _build(self) -> None:
        header = ctk.CTkFrame(self, fg_color="transparent")
        header.pack(fill="x", padx=16, pady=(12, 4))
        brand = ctk.CTkFrame(header, fg_color="transparent")
        brand.pack(side="left")
        ctk.CTkLabel(brand, text=APP_NAME, font=ctk.CTkFont(size=22, weight="bold")).pack(anchor="w")
        ctk.CTkLabel(
            brand,
            text=f"v{__version__} · offline Whisper",
            font=ctk.CTkFont(size=12),
            text_color=("gray40", "gray65"),
        ).pack(anchor="w")
        ctk.CTkButton(header, text="☀/🌙", width=48, command=self._toggle_theme).pack(side="right", padx=4)
        ctk.CTkButton(header, text="Settings", width=80, command=self._open_settings).pack(side="right", padx=4)
        ctk.CTkButton(header, text="Library", width=80, command=self._open_library).pack(side="right", padx=4)

        ctk.CTkLabel(self, textvariable=self.banner_var, text_color="#C0392B", wraplength=860).pack(
            fill="x", padx=16
        )
        ctk.CTkLabel(self, textvariable=self.ready_var, text_color=("gray40", "gray65"), wraplength=860).pack(
            fill="x", padx=16
        )

        ctk.CTkLabel(self, text="Judul rapat").pack(anchor="w", padx=16)
        title_entry = ctk.CTkEntry(self, textvariable=self.title_var, placeholder_text="Rapat tanpa judul")
        title_entry.pack(fill="x", padx=16, pady=(0, 8))
        title_entry.bind("<KeyRelease>", lambda _e: self._on_title_edit())

        mode_f = ctk.CTkFrame(self, fg_color="transparent")
        mode_f.pack(fill="x", padx=16, pady=4)
        ctk.CTkLabel(mode_f, text="Mode rapat:").pack(side="left")
        for text, val in (
            ("Webinar", "webinar"),
            ("Rapat Online", "rapat_online"),
            ("Rapat Offline", "rapat_offline"),
        ):
            ctk.CTkRadioButton(
                mode_f, text=text, variable=self.mode_var, value=val, command=self._apply_mode_defaults
            ).pack(side="left", padx=8)

        tog = ctk.CTkFrame(self)
        tog.pack(fill="x", padx=16, pady=8)
        self.mic_btn = ctk.CTkButton(tog, text="MIC  [ ON ]", width=140, command=self._toggle_mic)
        self.mic_btn.pack(side="left", padx=8, pady=8)
        self.spk_btn = ctk.CTkButton(tog, text="SPK  [ ON ]", width=140, command=self._toggle_spk)
        self.spk_btn.pack(side="left", padx=8, pady=8)
        self.mic_warn = ctk.CTkLabel(tog, text="", text_color="#C0392B")
        self.mic_warn.pack(side="left", padx=8)

        vu = ctk.CTkFrame(self, fg_color="transparent")
        vu.pack(fill="x", padx=16, pady=(0, 4))
        ctk.CTkLabel(vu, text="MIC", width=36).pack(side="left")
        self.mic_vu = ctk.CTkProgressBar(vu, width=200, height=10)
        self.mic_vu.set(0)
        self.mic_vu.pack(side="left", padx=(4, 16))
        ctk.CTkLabel(vu, text="SPK", width=36).pack(side="left")
        self.spk_vu = ctk.CTkProgressBar(vu, width=200, height=10)
        self.spk_vu.set(0)
        self.spk_vu.pack(side="left", padx=4)

        meta = ctk.CTkFrame(self, fg_color="transparent")
        meta.pack(fill="x", padx=16)
        self.rec_label = ctk.CTkLabel(meta, text="○ IDLE")
        self.rec_label.pack(side="left")
        ctk.CTkLabel(meta, textvariable=self.timer_var).pack(side="left", padx=12)
        ctk.CTkLabel(meta, textvariable=self.status_var).pack(side="left", padx=12)
        ctk.CTkLabel(meta, textvariable=self.conf_var).pack(side="left", padx=12)
        ctk.CTkLabel(meta, textvariable=self.res_var).pack(side="right")

        cap_tools = ctk.CTkFrame(self, fg_color="transparent")
        cap_tools.pack(fill="x", padx=16, pady=(4, 0))
        ctk.CTkLabel(cap_tools, text="Font").pack(side="left")
        ctk.CTkOptionMenu(
            cap_tools,
            variable=self.font_var,
            values=["12", "14", "16", "18"],
            width=70,
            command=self._on_font_change,
        ).pack(side="left", padx=6)
        ctk.CTkButton(cap_tools, text="Clear", width=70, command=self._clear_caption).pack(side="left", padx=4)

        self.caption = ctk.CTkTextbox(self, wrap="word", font=ctk.CTkFont(size=self._caption_font_size))
        self.caption.pack(fill="both", expand=True, padx=16, pady=8)
        self.caption.bind("<MouseWheel>", self._on_scroll)
        self.caption.insert("end", "Menunggu suara…\n")
        self.caption.tag_config("partial", foreground="#7A8490")
        self.caption.tag_config("final", foreground="")

        actions = ctk.CTkFrame(self, fg_color="transparent")
        actions.pack(fill="x", padx=16, pady=8)
        self.start_btn = ctk.CTkButton(actions, text="Start", command=self._toggle_record)
        self.start_btn.pack(side="left", padx=4)
        ctk.CTkButton(actions, text="Export", command=self._export).pack(side="left", padx=4)
        ctk.CTkButton(actions, text="Minimize to Tray", command=self._minimize_tray).pack(side="left", padx=4)

        ctk.CTkLabel(
            self,
            text="Diarization: per-source (MIC/SPK). Aktifkan pyannote di Settings (butuh HF token).",
            text_color="gray",
        ).pack(pady=(0, 10))

    def _bind_keys(self) -> None:
        self.bind("<space>", self._hotkey_record)
        self.bind("m", lambda e: self._hotkey(self._toggle_mic))
        self.bind("M", lambda e: self._hotkey(self._toggle_mic))
        self.bind("s", lambda e: self._hotkey(self._toggle_spk))
        self.bind("S", lambda e: self._hotkey(self._toggle_spk))
        self.bind("e", lambda e: self._hotkey(self._export))
        self.bind("E", lambda e: self._hotkey(self._export))
        self.bind("t", lambda e: self._hotkey(self._minimize_tray))
        self.bind("<comma>", lambda e: self._hotkey(self._open_settings))

    def _focus_is_entry(self) -> bool:
        try:
            w = self.focus_get()
            return w is not None and w.winfo_class() in ("Entry", "Text", "CTkEntry", "CTkTextbox")
        except Exception:
            return False

    def _hotkey(self, fn) -> str:  # noqa: ANN001
        if self._focus_is_entry():
            return ""
        fn()
        return "break"

    def _hotkey_record(self, _event=None) -> str:  # noqa: ANN001
        return self._hotkey(self._toggle_record)

    def _prefill_title(self) -> None:
        if self.title_var.get().strip():
            return
        detected = detect_meeting_title()
        if detected:
            self.title_var.set(detected)

    def refresh_readiness(self) -> None:
        self._update_tone_banner()
        stt = WhisperCppStt(self.settings.model)
        if stt.available():
            self.ready_var.set(f"STT siap · model {self.settings.model}")
        else:
            self.ready_var.set(
                "⚠ Model/binary Whisper belum lengkap — Settings → Unduh model, atau Setup wizard."
            )

    def _update_tone_banner(self) -> None:
        if not self.settings.tone_test_ok and (
            self.settings.tone_test_skipped or self.settings.setup_complete
        ):
            self.banner_var.set(
                "⚠ Routing speaker belum diverifikasi. Settings → Test audio routing."
            )
        else:
            self.banner_var.set("")

    def _apply_mode_defaults(self) -> None:
        mode = self.mode_var.get()
        self.settings.meeting_mode = mode
        self.settings.save()
        if mode == "webinar":
            self._set_mic(False)
            self._set_spk(True)
        elif mode == "rapat_offline":
            self._set_mic(True)
            self._set_spk(False)
        else:
            self._set_mic(True)
            self._set_spk(True)

    def _set_mic(self, on: bool) -> None:
        self.mic_var.set("ON" if on else "OFF")
        self.mic_btn.configure(text=f"MIC  [ {'ON' if on else 'OFF'} ]")
        if self.pipeline:
            self.pipeline.set_mic(on)
        self._update_mic_warn()

    def _set_spk(self, on: bool) -> None:
        self.spk_var.set("ON" if on else "OFF")
        self.spk_btn.configure(text=f"SPK  [ {'ON' if on else 'OFF'} ]")
        if self.pipeline:
            self.pipeline.set_speaker(on)

    def _toggle_mic(self) -> None:
        self._set_mic(self.mic_var.get() != "ON")

    def _toggle_spk(self) -> None:
        self._set_spk(self.spk_var.get() != "ON")

    def _update_mic_warn(self) -> None:
        if self.mic_var.get() == "OFF":
            self.mic_warn.configure(text="⚠ MIC DIMATIKAN (klik untuk nyalakan)")
            if not self.settings.reduced_motion:
                self._mic_blink_on = True
                self._blink_mic()
            else:
                self.mic_warn.configure(text_color="#C0392B")
        else:
            self._mic_blink_on = False
            self.mic_warn.configure(text="")

    def _blink_mic(self) -> None:
        if not self._mic_blink_on or self.settings.reduced_motion:
            return
        current = self.mic_warn.cget("text_color")
        self.mic_warn.configure(text_color="#F5B7B1" if current == "#C0392B" else "#C0392B")
        self.after(600, self._blink_mic)

    def _on_title_edit(self) -> None:
        title = self.title_var.get().strip()
        self.settings.last_meeting_title = title
        if self.pipeline and self._recording:
            self.pipeline.set_title(title)

    def _toggle_theme(self) -> None:
        self.settings.theme = "dark" if self.settings.theme != "dark" else "light"
        self.colors = apply_theme(self.settings.theme)
        self.settings.save()

    def _toggle_record(self) -> None:
        if self._recording:
            if not self._confirm_stop():
                return
            self._stop_record()
        else:
            self._start_record()

    def _confirm_stop(self) -> bool:
        return bool(messagebox.askyesno("Stop", "Hentikan rekaman sesi ini?"))

    def _start_record(self) -> None:
        ok, msg = ensure_space(MIN_SESSION_FREE, self.settings.library_path())
        if not ok:
            messagebox.showerror("Disk", msg)
            return
        if not WhisperCppStt(self.settings.model).available():
            if not messagebox.askyesno(
                "STT belum siap",
                "Model/binary Whisper belum terpasang.\n"
                "Rekaman audio tetap jalan, tapi teks mungkin placeholder.\n\n"
                "Lanjut rekam?",
            ):
                return
        if self.mic_var.get() == "OFF" and self.spk_var.get() == "OFF":
            messagebox.showwarning("Audio", "MIC dan SPK sama-sama OFF. Nyalakan salah satu dulu.")
            return
        title = self.title_var.get().strip() or "Rapat tanpa judul"
        self.pipeline = Pipeline(
            settings_mode=self.mode_var.get(),
            model_name=self.settings.model,
            library_root=str(self.settings.library_path()),
            events=self.events,
            on_status=self._on_status,
            on_segment=self._on_segment,
        )
        self.pipeline.mic_enabled = self.mic_var.get() == "ON"
        self.pipeline.speaker_enabled = self.spk_var.get() == "ON"
        try:
            self.session = self.pipeline.start(title)
        except Exception as e:
            messagebox.showerror("Audio", str(e))
            self.status_var.set(PipelineStatus.DEVICE_ERROR.value)
            return
        self._recording = True
        self._conf_scores.clear()
        self.conf_var.set("Conf —")
        self.start_btn.configure(text="Stop")
        self.rec_label.configure(text="● REC")
        self.caption.delete("1.0", "end")
        self.caption.insert("end", "Menunggu suara…\n")
        self.settings.last_meeting_title = title
        self.settings.save()

    def _stop_record(self) -> None:
        if self.pipeline:
            self.session = self.pipeline.stop()
        self.pipeline = None
        self._recording = False
        self.start_btn.configure(text="Start")
        self.rec_label.configure(text="○ IDLE")
        self.status_var.set(PipelineStatus.IDLE.value)
        self.mic_vu.set(0)
        self.spk_vu.set(0)

    def _on_status(self, status: PipelineStatus) -> None:
        self.status_var.set(status.value)

    def _on_segment(self, seg: TranscriptSegment) -> None:
        if not seg.is_final:
            # replace trailing partial line
            if self._partial_mark:
                self.caption.delete(self._partial_mark, "end")
            self._partial_mark = self.caption.index("end-1c")
            self.caption.insert("end", format_caption_line(seg) + "\n", "partial")
        else:
            if self._partial_mark:
                try:
                    self.caption.delete(self._partial_mark, "end")
                except tk.TclError:
                    pass
                self._partial_mark = None
            # clear empty state once
            content = self.caption.get("1.0", "end").strip()
            if content == "Menunggu suara…":
                self.caption.delete("1.0", "end")
            self.caption.insert("end", format_caption_line(seg) + "\n", "final")
            if seg.confidence > 0:
                self._conf_scores.append(float(seg.confidence))
                # keep last N for a responsive average
                if len(self._conf_scores) > 40:
                    self._conf_scores = self._conf_scores[-40:]
                avg = sum(self._conf_scores) / len(self._conf_scores)
                self.conf_var.set(f"Conf {avg * 100:.0f}%")
        if self._auto_scroll:
            self.caption.see("end")

    def _on_font_change(self, value: str) -> None:
        try:
            size = int(value)
        except ValueError:
            return
        self._caption_font_size = size
        self.caption.configure(font=ctk.CTkFont(size=size))

    def _clear_caption(self) -> None:
        self.caption.delete("1.0", "end")
        self._partial_mark = None
        self._auto_scroll = True

    def _on_scroll(self, _event=None) -> None:  # noqa: ANN001
        # If not at bottom, disable auto-scroll
        try:
            yview = self.caption.yview()
            self._auto_scroll = yview[1] >= 0.98
        except Exception:
            pass

    def _export(self) -> None:
        if not self.session:
            messagebox.showinfo("Export", "Belum ada sesi aktif / terakhir.")
            return
        ExportDialog(self, self.session, self.title_var.get(), self.settings)

    def _open_library(self) -> None:
        LibraryWindow(self, self.settings.library_path())

    def _open_settings(self) -> None:
        SettingsWindow(self, self.settings, on_saved=self._after_settings)

    def _after_settings(self) -> None:
        self.settings = Settings.load()
        self.attributes("-topmost", self.settings.always_on_top)
        self.refresh_readiness()

    def _minimize_tray(self) -> None:
        self.tray.start()
        self.withdraw()

    def _show_from_tray(self) -> None:
        self.deiconify()
        self.lift()

    def _poll(self) -> None:
        self.events.drain()
        if self._recording and self.pipeline:
            sec = int(self.pipeline.elapsed_sec())
            h, rem = divmod(sec, 3600)
            m, s = divmod(rem, 60)
            self.timer_var.set(f"{h:02d}:{m:02d}:{s:02d}")
        self.after(200, self._poll)

    def _tick_resources(self) -> None:
        from util.resources import sample_resources

        self.res_var.set(sample_resources())
        self.after(2000, self._tick_resources)

    def _tick_vu(self) -> None:
        if self._recording and self.pipeline:
            mic, spk = self.pipeline.levels()
            self.mic_vu.set(max(0.0, min(1.0, mic)))
            self.spk_vu.set(max(0.0, min(1.0, spk)))
        else:
            self.mic_vu.set(0)
            self.spk_vu.set(0)
        self.after(80, self._tick_vu)

    def _check_resume(self) -> None:
        path = find_inprogress(self.settings.library_path())
        if path:

            def on_resume(sess: Session) -> None:
                self.session = sess
                self.title_var.set(sess.meta.title)
                self.caption.delete("1.0", "end")
                self._conf_scores.clear()
                for seg in sess.segments:
                    if seg.is_final:
                        self.caption.insert("end", format_caption_line(seg) + "\n", "final")
                        if seg.confidence > 0:
                            self._conf_scores.append(float(seg.confidence))
                if self._conf_scores:
                    avg = sum(self._conf_scores) / len(self._conf_scores)
                    self.conf_var.set(f"Conf {avg * 100:.0f}%")
                else:
                    self.conf_var.set("Conf —")

            ResumeDialog(
                self,
                path,
                self.settings.library_path(),
                on_resume=on_resume,
                on_discard=lambda: None,
            )

    def _persist_geometry(self) -> None:
        geo = self.geometry()
        # "WxH+X+Y"
        self.settings.window_geometry = geo.split("+")[0]
        try:
            parts = geo.split("+")
            if len(parts) >= 3:
                self.settings.window_x = int(parts[1])
                self.settings.window_y = int(parts[2])
        except ValueError:
            pass
        self.settings.save()

    def _on_close(self) -> None:
        if self._recording:
            if not self._confirm_stop():
                return
            self._stop_record()
        self._persist_geometry()
        self.tray.stop()
        self.destroy()

    def _quit_app(self) -> None:
        self.after(0, self._on_close)
