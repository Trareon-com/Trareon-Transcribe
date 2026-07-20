"""Main CustomTkinter window — modes, toggles, live caption, controls."""

from __future__ import annotations

import logging
import os
import tkinter as tk
import tkinter.messagebox as messagebox

import customtkinter as ctk
from PIL import Image

from config.branding import APP_NAME, icon_png, set_window_icon
from config.settings import Settings, sanitize_geometry
from config.version import __version__
from engine.audio_capture import AudioCapture
from engine.audio_probe import probe_audio
from engine.pipeline import Pipeline, PipelineStatus
from engine.session_store import Session, TranscriptSegment, find_inprogress
from engine.stt import WhisperCppStt
from export.naming import detect_meeting_title
from export.writer import source_label
from setup.disk import MIN_SESSION_FREE, ensure_space
from ui.export_dialog import ExportDialog
from ui.library import LibraryWindow
from ui.resume_dialog import ResumeDialog
from ui.settings_window import SettingsWindow
from ui.theme import apply_theme, bind_responsive, ghost_button, primary_button, sync_responsive
from ui.tray import TrayController
from ui.vu_meter import BarVuMeter
from ui.window_util import open_singleton
from util.threading_helpers import UiEventQueue

_MODE_LABEL = {
    "webinar": "Webinar",
    "rapat_online": "Rapat Online",
    "rapat_offline": "Rapat Offline",
}
_MODE_VALUE = {v: k for k, v in _MODE_LABEL.items()}
log = logging.getLogger("trareon")


class _ModeSegProxy:
    """Tiny stand-in so harness/remote can still call mode_seg.set(label)."""

    def __init__(self, win: MainWindow) -> None:
        self._win = win

    def set(self, label: str) -> None:
        self._win._on_mode_seg(label)


class MainWindow(ctk.CTk):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.settings = settings
        self.colors = apply_theme(settings.theme)
        self.configure(fg_color=self.colors["bg"])
        self.title(f"{APP_NAME}  v{__version__}")
        set_window_icon(self)
        self.minsize(720, 560)
        geo = sanitize_geometry(settings.window_geometry or "1180x760")
        self.settings.window_geometry = geo
        if settings.window_x is not None and settings.window_y is not None:
            if settings.window_x >= -20 and settings.window_y >= -20:
                self.geometry(f"{geo}+{settings.window_x}+{settings.window_y}")
            else:
                self.geometry(f"{geo}+120+80")
        else:
            self.geometry(f"{geo}+120+80")
        self.attributes("-topmost", settings.always_on_top)
        self._audio_probe_msg = ""

        self.events = UiEventQueue()
        self.pipeline: Pipeline | None = None
        self.session: Session | None = None
        self._meter: AudioCapture | None = None
        self._meter_revive_pending = False
        self._quitting = False
        self._recording = False
        self._lib_win: LibraryWindow | None = None
        self._settings_win: SettingsWindow | None = None
        self._export_win: ExportDialog | None = None
        self._main_resize_bound = False
        self._layout_mode: str | None = None
        self._auto_scroll = True
        self._mic_blink_on = False
        self._partial_mark: str | None = None
        self._conf_scores: list[float] = []
        self._banner_dismissed = False
        font_size = max(12, min(24, int(getattr(settings, "caption_font_size", 16) or 16)))
        self._caption_font_size = font_size

        self.mode_var = ctk.StringVar(value=settings.meeting_mode)
        self.title_var = ctk.StringVar(value=settings.last_meeting_title or "")
        self.status_var = ctk.StringVar(value=PipelineStatus.IDLE.value)
        self.timer_var = ctk.StringVar(value="00:00:00")
        self.res_var = ctk.StringVar(value="CPU —  |  RAM —  |  GPU —")
        self.conf_var = ctk.StringVar(value="Conf -")
        self.hud_var = ctk.StringVar(value="●  Idle  ·  00:00:00  ·  Conf -")
        self.banner_var = ctk.StringVar(value="")
        self.ready_var = ctk.StringVar(value="")
        self.mic_var = ctk.StringVar(value="ON")
        self.spk_var = ctk.StringVar(value="ON")
        self.font_var = ctk.StringVar(value=str(font_size))

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
        self.after(300, self._probe_audio_engine)
        self.after(400, self._start_meters)

    def _ghost_btn(self, parent: ctk.CTkFrame, text: str, command, width: int = 88) -> ctk.CTkButton:  # noqa: ANN001
        return ghost_button(parent, text, command, self.colors, width=width)

    def _nav_link(self, parent: ctk.CTkFrame, text: str, command, *, width: int = 88) -> ctk.CTkButton:  # noqa: ANN001
        """Text+icon style nav — matches mock (no heavy bordered chips)."""
        c = self.colors
        return ctk.CTkButton(
            parent,
            text=text,
            command=command,
            width=width,
            height=28,
            corner_radius=8,
            fg_color="transparent",
            hover_color=c["row"],
            text_color=c["muted"],
            font=ctk.CTkFont(size=12),
            border_width=0,
        )

    def _build(self) -> None:
        """Layout mirrors redesign mockup: header · toolbar · caption · footer."""
        c = self.colors
        pad = 18
        self._narrow_row = None

        # —— 1. Header: brand · HUD pill · metrics · nav ——
        header = ctk.CTkFrame(self, fg_color="transparent")
        header.pack(fill="x", padx=pad, pady=(12, 8))

        brand = ctk.CTkFrame(header, fg_color="transparent")
        brand.pack(side="left")
        try:
            logo = ctk.CTkImage(Image.open(icon_png()), size=(22, 22))
            ctk.CTkLabel(brand, text="", image=logo).pack(side="left", padx=(0, 8))
            self._logo_img = logo
        except Exception:
            pass
        ctk.CTkLabel(
            brand,
            text=APP_NAME,
            font=ctk.CTkFont(size=17, weight="bold"),
            text_color=c["accent"],
            anchor="w",
        ).pack(side="left")

        # Mock HUD: light pill + thin border + green status text (no fixed height — avoids clip).
        self.hud_pill = ctk.CTkFrame(
            header,
            fg_color=c["panel"],
            corner_radius=16,
            border_width=1,
            border_color=c["border"],
        )
        self.hud_pill.pack(side="left", padx=(18, 0))
        self.rec_label = ctk.CTkLabel(
            self.hud_pill,
            textvariable=self.hud_var,
            font=ctk.CTkFont(size=12, weight="bold"),
            text_color=c["hud_fg"],
        )
        self.rec_label.pack(padx=16, pady=6)

        nav = ctk.CTkFrame(header, fg_color="transparent")
        nav.pack(side="right")
        theme_glyph = "☾" if self.settings.theme == "light" else "☀"
        self._nav_link(nav, f"{theme_glyph}  Theme", self._toggle_theme, width=92).pack(side="right", padx=(2, 0))
        self._nav_link(nav, "⚙  Settings", self._open_settings, width=96).pack(side="right", padx=2)
        self._nav_link(nav, "📁  Library", self._open_library, width=92).pack(side="right", padx=2)
        ctk.CTkLabel(
            header,
            textvariable=self.res_var,
            font=ctk.CTkFont(size=11),
            text_color=c["muted"],
            anchor="e",
        ).pack(side="right", padx=(12, 10))

        # —— 2. Toolbar: left cluster (title·modes) · gap · right cluster (VU·Start·Export) ——
        # Pack RIGHT first so the empty middle is real whitespace, not a stretched meter.
        self._toolbar = ctk.CTkFrame(self, fg_color="transparent")
        self._toolbar.pack(fill="x", padx=pad, pady=(0, 8))

        self._actions = ctk.CTkFrame(self._toolbar, fg_color="transparent")
        self._actions.pack(side="right")
        self.start_btn = primary_button(self._actions, "▶  Start", self._toggle_record, c, width=96, height=34)
        self.start_btn.pack(side="left")
        self.export_btn = ghost_button(self._actions, "↓  Export", self._export, c, width=96, height=34)
        self.export_btn.pack(side="left", padx=(6, 0))
        self._style_export_btn()

        # Compact meter cluster (natural width) — packed RIGHT so gap is whitespace.
        self._meters = ctk.CTkFrame(self._toolbar, fg_color="transparent")
        self._meters.pack(side="right", padx=(0, 10))

        mic_box = ctk.CTkFrame(self._meters, fg_color="transparent")
        mic_box.pack(side="left", padx=(0, 14))
        self.mic_btn = ctk.CTkButton(
            mic_box,
            text="🎙 MIC",
            width=58,
            height=28,
            corner_radius=8,
            fg_color="transparent",
            hover_color=c["row"],
            text_color=c["accent"],
            font=ctk.CTkFont(size=11, weight="bold"),
            border_width=0,
            command=self._toggle_mic,
        )
        self.mic_btn.pack(side="left")
        self.mic_vu = BarVuMeter(mic_box, colors=c, height=24)
        self.mic_vu.pack(side="left", padx=(2, 0))

        spk_box = ctk.CTkFrame(self._meters, fg_color="transparent")
        spk_box.pack(side="left")
        self.spk_btn = ctk.CTkButton(
            spk_box,
            text="🔊 SPK",
            width=58,
            height=28,
            corner_radius=8,
            fg_color="transparent",
            hover_color=c["row"],
            text_color=c["text"],
            font=ctk.CTkFont(size=11, weight="bold"),
            border_width=0,
            command=self._toggle_spk,
        )
        self.spk_btn.pack(side="left")
        self.spk_vu = BarVuMeter(spk_box, colors=c, height=24)
        self.spk_vu.pack(side="left", padx=(2, 0))

        self._title_wrap = ctk.CTkFrame(
            self._toolbar, fg_color=c["panel"], corner_radius=10, border_width=1, border_color=c["border"], height=34
        )
        self._title_wrap.pack(side="left", padx=(0, 8))
        self._title_entry = ctk.CTkEntry(
            self._title_wrap,
            textvariable=self.title_var,
            placeholder_text="Judul rapat — mis. Weekly Product Sync",
            height=30,
            width=300,
            border_width=0,
            fg_color=c["panel"],
            text_color=c["text"],
            placeholder_text_color=c["muted"],
            corner_radius=8,
        )
        self._title_entry.pack(side="left", padx=(8, 0), pady=2)
        self._title_entry.bind("<KeyRelease>", lambda _e: self._on_title_edit())
        # Mock pencil affordance as text (glyph ✎ mis-renders as paperclip on some macOS fonts).
        ctk.CTkLabel(
            self._title_wrap,
            text="edit",
            text_color=c["muted"],
            font=ctk.CTkFont(size=11),
            width=32,
        ).pack(side="right", padx=(0, 10))

        self._modes_frame = ctk.CTkFrame(
            self._toolbar, fg_color=c["panel"], corner_radius=10, border_width=1, border_color=c["border"]
        )
        self._modes_frame.pack(side="left", padx=(0, 8))
        self._mode_btns: dict[str, ctk.CTkButton] = {}
        for key, label in _MODE_LABEL.items():
            btn = ctk.CTkButton(
                self._modes_frame,
                text=label,
                height=28,
                width=108 if key != "webinar" else 88,
                corner_radius=8,
                font=ctk.CTkFont(size=12, weight="bold"),
                command=lambda lab=label: self._on_mode_seg(lab),
            )
            btn.pack(side="left", padx=2, pady=2)
            self._mode_btns[key] = btn
        self.mode_seg = _ModeSegProxy(self)
        # Kept for reflow API / older callers — unused in wide layout (right-pack gap).
        self._toolbar_gap = ctk.CTkFrame(self._toolbar, fg_color="transparent", width=1, height=1)

        # Status (warnings) — soft band, hidden when empty; dismissible for the session
        self.status_box = ctk.CTkFrame(
            self,
            fg_color=c.get("warn_bg", "#FEF2F2"),
            corner_radius=10,
            border_width=1,
            border_color=c.get("warn_border", "#FECACA"),
        )
        self._status_body = ctk.CTkFrame(self.status_box, fg_color="transparent")
        self.mic_warn = ctk.CTkLabel(
            self._status_body, text="", text_color=c["danger"], font=ctk.CTkFont(size=11),
            anchor="w", justify="left", wraplength=600,
        )
        self.banner_label = ctk.CTkLabel(
            self._status_body, textvariable=self.banner_var, text_color=c["danger"],
            wraplength=600, anchor="w", justify="left", font=ctk.CTkFont(size=12),
        )
        self.ready_label = ctk.CTkLabel(
            self._status_body, textvariable=self.ready_var, text_color=c["muted"],
            wraplength=600, anchor="w", justify="left", font=ctk.CTkFont(size=11),
        )
        self._banner_dismiss_btn = ctk.CTkButton(
            self.status_box,
            text="✕",
            width=28,
            height=28,
            corner_radius=8,
            fg_color="transparent",
            hover_color=c["row"],
            text_color=c["danger"],
            font=ctk.CTkFont(size=13),
            border_width=0,
            command=self._dismiss_banner,
        )
        self._banner_help_btn = ctk.CTkButton(
            self.status_box,
            text="Bantuan",
            width=72,
            height=28,
            corner_radius=8,
            fg_color="transparent",
            hover_color=c["row"],
            text_color=c["danger"],
            font=ctk.CTkFont(size=11),
            border_width=0,
            command=self._banner_help,
        )

        # —— 3. Caption (mock: clean transcript panel) ——
        self._stage = ctk.CTkFrame(
            self, fg_color=c["panel"], corner_radius=12, border_width=1, border_color=c["border"]
        )
        self._stage.pack(fill="both", expand=True, padx=pad, pady=(0, 8))
        self.caption = ctk.CTkTextbox(
            self._stage,
            wrap="word",
            font=ctk.CTkFont(size=self._caption_font_size),
            fg_color=c["panel"],
            text_color=c["text"],
            border_width=0,
            corner_radius=0,
        )
        self.caption.pack(fill="both", expand=True, padx=28, pady=22)
        self.caption.bind("<MouseWheel>", self._on_scroll)
        self.caption.bind("<Button-2>", self._caption_menu)
        self.caption.bind("<Control-Button-1>", self._caption_menu)
        self.caption.tag_config("partial", foreground=c["partial"])
        self.caption.tag_config("final", foreground=c["text"])
        self.caption.tag_config("mic", foreground=c["mic"])
        self.caption.tag_config("spk", foreground=c["spk"])
        self.caption.tag_config("empty", foreground=c["muted"])
        # Centered idle state (mock: airy empty stage, not top-left stub text).
        self._empty_overlay = ctk.CTkLabel(
            self._stage,
            text="Menunggu suara…\n\nTekan Start untuk mulai.\nLabel MIC / SPK muncul otomatis di caption.",
            text_color=c["muted"],
            font=ctk.CTkFont(size=15),
            justify="center",
        )
        self._show_caption_empty()

        # —— 4. Footer (mock: minimize left · diarization right; no Clear/font chrome) ——
        foot = ctk.CTkFrame(self, fg_color="transparent")
        foot.pack(fill="x", padx=pad, pady=(0, 14))
        ctk.CTkButton(
            foot,
            text="↧↧  Minimize to tray",
            command=self._minimize_tray,
            height=28,
            width=168,
            corner_radius=8,
            fg_color="transparent",
            hover_color=c["row"],
            text_color=c["muted"],
            font=ctk.CTkFont(size=12),
            border_width=0,
        ).pack(side="left")
        self.foot_hint = ctk.CTkLabel(
            foot,
            text=self._footer_status_text(),
            text_color=c["muted"],
            font=ctk.CTkFont(size=12),
            wraplength=520,
            anchor="e",
            justify="right",
        )
        # Diarization right (mock); readiness fills the middle.
        self.foot_hint.pack(side="right", padx=(12, 0))
        self.ready_foot = ctk.CTkLabel(
            foot,
            textvariable=self.ready_var,
            text_color=c["muted"],
            font=ctk.CTkFont(size=11),
            wraplength=360,
            anchor="w",
            justify="left",
        )
        self.ready_foot.pack(side="left", fill="x", expand=True, padx=(16, 12))

        self._refresh_hud()
        self._style_source_btns()
        self._style_mode_btns()
        self._sync_status_band()
        bind_responsive(self)
        if not self._main_resize_bound:
            self.bind("<Configure>", self._on_main_resize, add="+")
            self._main_resize_bound = True
        self._layout_mode = None  # force reflow after rebuild
        self.after(80, self._reflow_controls)

    def _footer_status_text(self) -> str:
        # Mock copy; note pyannote when diarization is off.
        if self.settings.diarization_enabled:
            return "Diarization aktif · Pembicara dipisahkan otomatis (MIC / SPK)."
        return "Diarization siap di Settings · Label MIC / SPK aktif di caption."

    def _sync_status_band(self) -> None:
        """Warnings only above caption — ready status lives in the footer (no empty gap)."""
        if not hasattr(self, "status_box"):
            return
        warn = (self.mic_warn.cget("text") or "").strip()
        banner = (self.banner_var.get() or "").strip()
        if self._banner_dismissed:
            banner = ""
        for w in self.status_box.winfo_children():
            w.pack_forget()
        for w in self._status_body.winfo_children():
            w.pack_forget()
        shown = False
        if warn:
            self.mic_warn.pack(fill="x", pady=(0, 2))
            shown = True
        if banner:
            self.banner_label.pack(fill="x", pady=(0 if not warn else 2, 0))
            shown = True
        # ready_label kept for bind_responsive but not packed — shown via ready_foot.
        try:
            mapped = bool(self.status_box.winfo_ismapped())
        except Exception:
            mapped = False
        c = self.colors
        try:
            self.status_box.configure(
                fg_color=c.get("warn_bg", "#FEF2F2"),
                border_color=c.get("warn_border", "#FECACA"),
            )
        except Exception:
            pass
        if shown:
            self._status_body.pack(side="left", fill="x", expand=True, padx=(12, 4), pady=8)
            if banner:
                self._banner_help_btn.pack(side="right", padx=(0, 2), pady=6)
                self._banner_dismiss_btn.pack(side="right", padx=(0, 8), pady=6)
            if not mapped:
                self.status_box.pack(fill="x", padx=18, pady=(0, 8), before=self._stage)
        elif mapped:
            self.status_box.pack_forget()

    def _dismiss_banner(self) -> None:
        self._banner_dismissed = True
        self._sync_status_band()

    def _banner_help(self) -> None:
        messagebox.showinfo(
            "Routing speaker",
            "Agar Zoom/Teams terekam di SPK:\n\n"
            "macOS: brew install blackhole-2ch\n"
            "  lalu set Output device ke BlackHole 2ch (atau Multi-Output Device).\n\n"
            "Windows: pasang VB-Cable, set playback ke CABLE Input.\n\n"
            "MIC tetap jalan tanpa driver loopback.",
        )

    def _on_main_resize(self, event=None) -> None:  # noqa: ANN001
        if event is not None and event.widget is not self:
            return
        self._reflow_controls()

    def _reflow_controls(self) -> None:
        """Wide = mock row (left title·modes / right VU·actions); narrow = stacked."""
        try:
            w = int(self.winfo_width())
        except Exception:
            return
        sync_responsive(self)
        if not hasattr(self, "_toolbar"):
            return
        mode = "wide" if w >= 1080 else "narrow"
        if getattr(self, "_layout_mode", None) != mode:
            self._layout_mode = mode
            try:
                if getattr(self, "_narrow_row", None) is not None:
                    try:
                        self._narrow_row.destroy()
                    except Exception:
                        pass
                    self._narrow_row = None
                for child in (self._title_wrap, self._modes_frame, self._meters, self._actions):
                    child.pack_forget()
                if mode == "wide":
                    # Right cluster first → empty centre gap (mock).
                    self._actions.pack(side="right")
                    self._meters.pack(side="right", padx=(0, 10))
                    self._title_entry.configure(width=300)
                    self._title_wrap.pack(side="left", padx=(0, 8))
                    self._modes_frame.pack(side="left", padx=(0, 8))
                    for key, btn in self._mode_btns.items():
                        btn.configure(width=108 if key != "webinar" else 88)
                        btn.pack_configure(fill="none", expand=False)
                else:
                    self._title_wrap.pack(side="top", fill="x", pady=(0, 6))
                    self._title_entry.configure(width=400)
                    self._modes_frame.pack(side="top", fill="x", pady=(0, 6))
                    for btn in self._mode_btns.values():
                        btn.configure(width=0)
                        btn.pack_configure(fill="x", expand=True)
                    row = ctk.CTkFrame(self._toolbar, fg_color="transparent")
                    self._narrow_row = row
                    row.pack(side="top", fill="x")
                    self._meters.pack(in_=row, side="left")
                    self._actions.pack(in_=row, side="right")
            except Exception:
                pass
        if hasattr(self, "foot_hint"):
            try:
                self.foot_hint.configure(
                    wraplength=max(180, min(420, w // 3)),
                    anchor="e" if w >= 720 else "w",
                    justify="right" if w >= 720 else "left",
                )
            except Exception:
                pass
        if hasattr(self, "ready_foot"):
            try:
                self.ready_foot.configure(wraplength=max(160, w - 420))
            except Exception:
                pass

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
        self.bind("<Command-l>", lambda e: self._hotkey(self._clear_caption))
        self.bind("<Control-l>", lambda e: self._hotkey(self._clear_caption))
        self.bind("<Command-equal>", lambda e: self._hotkey(lambda: self._nudge_font(+2)))
        self.bind("<Control-equal>", lambda e: self._hotkey(lambda: self._nudge_font(+2)))
        self.bind("<Command-minus>", lambda e: self._hotkey(lambda: self._nudge_font(-2)))
        self.bind("<Control-minus>", lambda e: self._hotkey(lambda: self._nudge_font(-2)))

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
        parts: list[str] = []
        if self._audio_probe_msg and not self._audio_probe_msg.startswith("Audio OK"):
            parts.append(f"⚠ {self._audio_probe_msg}")
        if stt.available():
            parts.append(f"STT siap · model {self.settings.model}")
        else:
            parts.append(
                "⚠ Model/binary Whisper belum lengkap — Settings → Unduh model, atau Setup wizard."
            )
        self.ready_var.set("  ·  ".join(parts))
        self._sync_status_band()

    def _probe_audio_engine(self) -> None:
        res = probe_audio()
        self._audio_probe_msg = res.message
        if not res.ok:
            messagebox.showerror("Audio", res.message)
        self.refresh_readiness()

    def _update_tone_banner(self) -> None:
        from engine.audio_capture import find_loopback_input_device

        msgs: list[str] = []
        if find_loopback_input_device() is None:
            msgs.append(
                "⚠ Tidak ada BlackHole (Mac) / VB-Cable (Win) — VU SPK diam & "
                "suara Zoom/Teams tidak terekam. MIC tetap jalan."
            )
        elif not self.settings.tone_test_ok and (
            self.settings.tone_test_skipped or self.settings.setup_complete
        ):
            msgs.append("⚠ Routing speaker belum diverifikasi. Settings → Test audio routing.")
        if self._recording and self.pipeline and not self.pipeline.speaker_capture_ok():
            msgs.append(
                "⚠ Speaker capture tidak aktif — rekaman mic tetap jalan. "
                "Pasang VB-Cable (Win) / BlackHole (Mac)."
            )
        self.banner_var.set("\n".join(msgs))
        self._sync_status_band()

    def _on_mode_seg(self, label: str) -> None:
        if self._recording:
            return
        self.mode_var.set(_MODE_VALUE.get(label, "rapat_online"))
        self._apply_mode_defaults()

    def _apply_mode_defaults(self) -> None:
        mode = self.mode_var.get()
        self.settings.meeting_mode = mode
        self.settings.save()
        self._style_mode_btns()
        if self._recording:
            return
        if mode == "webinar":
            self._set_mic(False)
            self._set_spk(True)
        elif mode == "rapat_offline":
            self._set_mic(True)
            self._set_spk(False)
        else:
            self._set_mic(True)
            self._set_spk(True)

    def _style_mode_btns(self) -> None:
        c = self.colors
        selected = self.mode_var.get()
        locked = self._recording
        for key, btn in getattr(self, "_mode_btns", {}).items():
            on = key == selected
            btn.configure(
                fg_color=c["accent"] if on else "transparent",
                hover_color=c["accent_hover"] if on else c["row"],
                text_color=c["on_accent"] if on else (c["muted"] if locked else c["text"]),
                border_width=0,
                state="disabled" if locked and not on else "normal",
            )

    def _style_source_btns(self) -> None:
        c = self.colors
        for btn, var, on_color, label in (
            (self.mic_btn, self.mic_var, c["mic"], "🎙 MIC"),
            (self.spk_btn, self.spk_var, c["spk"], "🔊 SPK"),
        ):
            on = var.get() == "ON"
            btn.configure(
                text=label,
                fg_color="transparent",
                text_color=on_color if on else c["muted"],
                border_width=0,
            )

    def _refresh_hud(self) -> None:
        status = self.status_var.get() or "Idle"
        if self._recording and status.lower() in ("idle", ""):
            status = "Listening"
        elif not self._recording and status.lower() == "idle":
            status = "Idle"
        conf = self.conf_var.get() or "Conf -"
        # Mock: ● Listening · 00:14:32 · Conf 90%
        self.hud_var.set(f"●  {status}  ·  {self.timer_var.get()}  ·  {conf}")
        try:
            c = self.colors
            self.hud_pill.configure(fg_color=c["accent_soft"] if self._recording else c["panel"])
            self.rec_label.configure(text_color=c["hud_fg"])
        except Exception:
            pass
        self._style_export_btn()

    def _style_export_btn(self) -> None:
        if not hasattr(self, "export_btn"):
            return
        c = self.colors
        ready = self.session is not None and not self._recording
        try:
            self.export_btn.configure(
                border_width=2,
                border_color=c["accent"] if ready else c["border"],
                text_color=c["accent"] if ready else c["muted"],
                state="normal" if ready else "disabled",
            )
        except Exception:
            pass

    def _set_mic(self, on: bool) -> None:
        self.mic_var.set("ON" if on else "OFF")
        self._style_source_btns()
        if self.pipeline:
            self.pipeline.set_mic(on)
        self._update_mic_warn()

    def _set_spk(self, on: bool) -> None:
        self.spk_var.set("ON" if on else "OFF")
        self._style_source_btns()
        if self.pipeline:
            self.pipeline.set_speaker(on)

    def _toggle_mic(self) -> None:
        self._set_mic(self.mic_var.get() != "ON")

    def _toggle_spk(self) -> None:
        self._set_spk(self.spk_var.get() != "ON")

    def _update_mic_warn(self) -> None:
        c = self.colors
        if self.mic_var.get() == "OFF":
            self.mic_warn.configure(
                text="⚠ MIC DIMATIKAN (klik untuk nyalakan)",
                text_color=c["danger"],
                cursor="hand2",
            )
            self.mic_warn.bind("<Button-1>", lambda _e: self._set_mic(True))
            if not self.settings.reduced_motion:
                self._mic_blink_on = True
                self._blink_mic()
        else:
            self._mic_blink_on = False
            self.mic_warn.configure(text="", cursor="")
            self.mic_warn.unbind("<Button-1>")
        self._sync_status_band()

    def _blink_mic(self) -> None:
        if not self._mic_blink_on or self.settings.reduced_motion:
            return
        c = self.colors
        on = c["danger"]
        off = c.get("warn_border", on)
        try:
            current = str(self.mic_warn.cget("text_color"))
        except Exception:
            current = on
        self.mic_warn.configure(text_color=off if current == on else on)
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
        caption = ""
        try:
            caption = self.caption.get("1.0", "end-1c")
        except Exception:
            pass
        recording = self._recording
        # Never destroy Library/Settings/Export toplevels — only rebuild main chrome.
        for child in list(self.winfo_children()):
            try:
                cls = str(child.winfo_class()).lower()
                if isinstance(child, ctk.CTkToplevel) or cls.endswith("toplevel"):
                    continue
            except Exception:
                pass
            try:
                child.destroy()
            except Exception:
                pass
        self.configure(fg_color=self.colors["bg"])
        self._build()
        self._restore_caption_text(caption)
        if recording:
            self.start_btn.configure(
                text="■  Stop",
                fg_color=self.colors["danger"],
                hover_color=self.colors["danger_hover"],
                text_color="#FFFFFF",
            )
            self._style_mode_btns()
        self.refresh_readiness()
        self._update_mic_warn()
        if hasattr(self, "foot_hint"):
            self.foot_hint.configure(text=self._footer_status_text())
        self._repaint_toplevels()
        if not recording:
            self.after(100, self._start_meters)

    def _restore_caption_text(self, text: str) -> None:
        """Re-insert caption with MIC/SPK color tags after theme rebuild."""
        raw = (text or "").strip()
        if not raw or raw.startswith("Menunggu suara") or raw.startswith("Listening"):
            if self._recording:
                self.caption.delete("1.0", "end")
                self._partial_mark = None
                try:
                    self._empty_overlay.configure(text="Listening…\n\nMenunggu suara.")
                except Exception:
                    pass
                self._set_empty_overlay(True)
            else:
                self._show_caption_empty()
            return
        self.caption.delete("1.0", "end")
        self._partial_mark = None
        self._set_empty_overlay(False)
        for line in text.splitlines():
            if line.startswith("MIC"):
                body = line[3:].lstrip()
                self.caption.insert("end", "MIC", ("mic",))
                self.caption.insert("end", f"  {body}\n\n" if body else "\n\n", ("final",))
            elif line.startswith("SPK"):
                body = line[3:].lstrip()
                self.caption.insert("end", "SPK", ("spk",))
                self.caption.insert("end", f"  {body}\n\n" if body else "\n\n", ("final",))
            elif line.strip():
                self.caption.insert("end", line + "\n\n", ("final",))

    def _repaint_toplevels(self) -> None:
        """Close open dialogs so the next open picks up the new theme cleanly."""
        for attr in ("_lib_win", "_settings_win", "_export_win"):
            win = getattr(self, attr, None)
            if win is None:
                continue
            try:
                if win.winfo_exists():
                    win.destroy()
            except Exception:
                pass
            setattr(self, attr, None)

    def _toggle_record(self) -> None:
        if self._recording:
            if not self._confirm_stop():
                return
            self._stop_record()
        else:
            self._start_record()

    def _auto_yes(self) -> bool:
        return os.environ.get("TRAREON_AUTO_YES") == "1"

    def _confirm_stop(self) -> bool:
        if self._auto_yes():
            return True
        return bool(messagebox.askyesno("Stop", "Hentikan rekaman sesi ini?"))

    def _start_record(self) -> None:
        ok, msg = ensure_space(MIN_SESSION_FREE, self.settings.library_path())
        if not ok:
            messagebox.showerror("Disk", msg)
            return
        if not WhisperCppStt(self.settings.model).available():
            if not self._auto_yes() and not messagebox.askyesno(
                "STT belum siap",
                "Model/binary Whisper belum terpasang.\n"
                "Rekaman audio tetap jalan, tapi teks mungkin placeholder.\n\n"
                "Lanjut rekam?",
            ):
                return
        if self.mic_var.get() == "OFF" and self.spk_var.get() == "OFF":
            messagebox.showwarning("Audio", "MIC dan SPK sama-sama OFF. Nyalakan salah satu dulu.")
            return
        self._stop_meters()
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
            self._start_meters()
            return
        self._recording = True
        self._banner_dismissed = False  # re-show routing warnings for a new session
        self._conf_scores.clear()
        self.conf_var.set("Conf -")
        self.start_btn.configure(
            text="■  Stop",
            fg_color=self.colors["danger"],
            hover_color=self.colors["danger_hover"],
            text_color="#FFFFFF",
        )
        self._style_mode_btns()
        self.status_var.set(PipelineStatus.LISTENING.value)
        self.caption.delete("1.0", "end")
        self._partial_mark = None
        self._set_empty_overlay(True)
        try:
            self._empty_overlay.configure(text="Listening…\n\nMenunggu suara.")
        except Exception:
            pass
        self.settings.last_meeting_title = title
        self.settings.save()
        self._update_tone_banner()
        self._refresh_hud()

    def _stop_record(self) -> None:
        if self.pipeline:
            self.session = self.pipeline.stop()
        self.pipeline = None
        self._recording = False
        self.start_btn.configure(
            text="▶  Start",
            fg_color=self.colors["accent"],
            hover_color=self.colors["accent_hover"],
            text_color=self.colors["on_accent"],
        )
        self._style_mode_btns()
        self.status_var.set(PipelineStatus.IDLE.value)
        self._start_meters()
        self._refresh_hud()
        if self.session:
            msg = "Sesi selesai · Export atau buka Library untuk putar ulang"
            self.ready_var.set(msg)
            if hasattr(self, "foot_hint"):
                self.foot_hint.configure(text=msg)
                self.after(
                    8000,
                    lambda: self.foot_hint.configure(text=self._footer_status_text())
                    if hasattr(self, "foot_hint")
                    else None,
                )
            self.after(8000, self.refresh_readiness)

    def _on_status(self, status: PipelineStatus) -> None:
        self.status_var.set(status.value)
        self._refresh_hud()

    def _caption_tags(self, seg: TranscriptSegment, *extra: str) -> tuple[str, ...]:
        src = "mic" if (seg.speaker or "").upper().startswith("MIC") else "spk"
        return (src, *extra)

    def _set_empty_overlay(self, show: bool) -> None:
        if not hasattr(self, "_empty_overlay"):
            return
        try:
            if show:
                self._empty_overlay.place(relx=0.5, rely=0.42, anchor="center")
            else:
                self._empty_overlay.place_forget()
        except Exception:
            pass

    def _show_caption_empty(self) -> None:
        self.caption.delete("1.0", "end")
        self._partial_mark = None
        try:
            self._empty_overlay.configure(
                text="Menunggu suara…\n\nTekan Start untuk mulai.\nLabel MIC / SPK muncul otomatis di caption."
            )
        except Exception:
            pass
        self._set_empty_overlay(True)

    def _caption_menu(self, event=None) -> str:  # noqa: ANN001
        menu = tk.Menu(self, tearoff=0)
        menu.add_command(label="Clear caption", command=self._clear_caption)
        menu.add_command(label="Font lebih besar", command=lambda: self._nudge_font(+2))
        menu.add_command(label="Font lebih kecil", command=lambda: self._nudge_font(-2))
        try:
            menu.tk_popup(event.x_root, event.y_root)
        finally:
            menu.grab_release()
        return "break"

    def _nudge_font(self, delta: int) -> None:
        size = max(12, min(24, int(self._caption_font_size) + delta))
        self.font_var.set(str(size))
        self._on_font_change(str(size))

    def _insert_caption_line(self, seg: TranscriptSegment, *extra: str) -> None:
        """MIC/SPK label colored; body uses final/partial — matches design guide."""
        self._set_empty_overlay(False)
        label = source_label(seg.speaker)
        src = "mic" if label == "MIC" else "spk"
        body_tag = "partial" if "partial" in extra else "final"
        # Label color only (CTk Textbox forbids per-tag fonts).
        self.caption.insert("end", label, (src,))
        self.caption.insert("end", f"  {seg.text}\n\n", (body_tag,))

    def _on_segment(self, seg: TranscriptSegment) -> None:
        if not seg.is_final:
            if self._partial_mark:
                self.caption.delete(self._partial_mark, "end")
            self._partial_mark = self.caption.index("end-1c")
            self._insert_caption_line(seg, "partial")
        else:
            if self._partial_mark:
                try:
                    self.caption.delete(self._partial_mark, "end")
                except tk.TclError:
                    pass
                self._partial_mark = None
            self._insert_caption_line(seg, "final")
            if seg.confidence > 0:
                self._conf_scores.append(float(seg.confidence))
                if len(self._conf_scores) > 40:
                    self._conf_scores = self._conf_scores[-40:]
                avg = sum(self._conf_scores) / len(self._conf_scores)
                self.conf_var.set(f"Conf {avg * 100:.0f}%")
                self._refresh_hud()
        if self._auto_scroll:
            self.caption.see("end")

    def _on_font_change(self, value: str) -> None:
        try:
            size = int(value)
        except ValueError:
            return
        size = max(12, min(24, size))
        self._caption_font_size = size
        self.font_var.set(str(size))
        self.caption.configure(font=ctk.CTkFont(size=size))
        self.settings.caption_font_size = size
        try:
            self.settings.save()
        except Exception:
            pass

    def _clear_caption(self) -> None:
        self._show_caption_empty()
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
        open_singleton(
            self,
            "_export_win",
            lambda: ExportDialog(self, self.session, self.title_var.get(), self.settings),  # type: ignore[arg-type]
        )

    def _open_library(self) -> None:
        open_singleton(
            self,
            "_lib_win",
            lambda: LibraryWindow(self, self.settings.library_path()),
            on_reuse=lambda w: w.refresh(),
        )

    def _open_settings(self) -> None:
        open_singleton(
            self,
            "_settings_win",
            lambda: SettingsWindow(self, self.settings, on_saved=self._after_settings),
        )

    def _after_settings(self) -> None:
        self.settings = Settings.load()
        self.attributes("-topmost", self.settings.always_on_top)
        self.refresh_readiness()
        if hasattr(self, "foot_hint"):
            try:
                self.foot_hint.configure(text=self._footer_status_text())
            except Exception:
                pass

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
            self._refresh_hud()
        self.after(200, self._poll)

    def _tick_resources(self) -> None:
        from util.resources import sample_resources

        self.res_var.set(sample_resources())
        self.after(2000, self._tick_resources)

    def _start_meters(self) -> None:
        """Always-on MIC/SPK VU indicators (hardware levels, ignore mute toggles)."""
        if self._recording:
            return
        if self._meter is not None and self._meter.state.running:
            return
        self._stop_meters()
        try:
            self._meter = AudioCapture()
            # Streams stay open; mute buttons do not silence the VU.
            self._meter.set_mic_enabled(True)
            self._meter.set_speaker_enabled(True)
            self._meter.start()
        except Exception as e:
            self._meter = None
            log.warning("VU meter failed: %s", e)

    def _stop_meters(self) -> None:
        if self._meter is not None:
            try:
                self._meter.stop()
            except Exception:
                pass
            self._meter = None

    def _tick_vu(self) -> None:
        mic = spk = 0.0
        src = None
        if self._recording and self.pipeline and self.pipeline._capture:  # noqa: SLF001
            src = self.pipeline._capture  # noqa: SLF001
        elif self._meter is not None and self._meter.state.running:
            src = self._meter
        else:
            # Revive idle meters once if PortAudio dropped them (no retry storm).
            if not self._recording and not self._meter_revive_pending and not self._quitting:
                self._meter_revive_pending = True

                def _revive() -> None:
                    self._meter_revive_pending = False
                    self._start_meters()

                self.after(400, _revive)
        if src is not None:
            src.decay_levels(0.85)
            mic, spk = src.levels()
        # Deadzone — sub-threshold wiggle never paints as movement.
        if mic < 0.06:
            mic = 0.0
        if spk < 0.06:
            spk = 0.0
        try:
            self.mic_vu.set(max(0.0, min(1.0, mic)))
            self.spk_vu.set(max(0.0, min(1.0, spk)))
        except Exception:
            pass
        self.after(50, self._tick_vu)

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
                        self._insert_caption_line(seg, "final")
                        if seg.confidence > 0:
                            self._conf_scores.append(float(seg.confidence))
                if self._conf_scores:
                    avg = sum(self._conf_scores) / len(self._conf_scores)
                    self.conf_var.set(f"Conf {avg * 100:.0f}%")
                else:
                    self.conf_var.set("Conf -")
                self._refresh_hud()

            ResumeDialog(
                self,
                path,
                self.settings.library_path(),
                on_resume=on_resume,
                on_discard=lambda: None,
            )

    def _persist_geometry(self) -> None:
        geo = self.geometry()
        self.settings.window_geometry = sanitize_geometry(geo.split("+")[0])
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
        self._stop_meters()
        self._persist_geometry()
        self.tray.stop()
        self.destroy()

    def _quit_app(self) -> None:
        self.after(0, self._on_close)
