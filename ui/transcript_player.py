"""Library transcript viewer + synced WAV playback (no translate)."""

from __future__ import annotations

import threading
import wave
from pathlib import Path

import customtkinter as ctk
import numpy as np

from config.settings import Settings
from engine.session_store import TranscriptSegment, load_session
from ui.export_dialog import ExportDialog

SPEAKER_COLORS = {
    "MIC": "#0B6E4F",
    "SPEAKER": "#6C3483",
    "SPK": "#6C3483",
}


def _fmt_ms(ms: int) -> str:
    s = max(0, int(ms // 1000))
    h, rem = divmod(s, 3600)
    m, sec = divmod(rem, 60)
    if h:
        return f"{h:02d}:{m:02d}:{sec:02d}"
    return f"{m:02d}:{sec:02d}"


def _speaker_color(name: str) -> str:
    key = name.upper()
    if key in SPEAKER_COLORS:
        return SPEAKER_COLORS[key]
    # stable-ish color for Speaker N
    palette = ("#0B6E4F", "#6C3483", "#B9770E", "#1F618D", "#922B21")
    return palette[sum(ord(c) for c in key) % len(palette)]


class WavPlayer:
    """Chunked WAV playback with seek + position tracking (sounddevice)."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._data = np.zeros(0, dtype=np.float32)
        self._sr = 16000
        self._pos = 0  # sample index
        self._playing = False
        self._stream = None
        self._path: Path | None = None

    @property
    def duration_ms(self) -> int:
        if self._sr <= 0 or self._data.size == 0:
            return 0
        return int(1000 * self._data.size / self._sr)

    @property
    def position_ms(self) -> int:
        with self._lock:
            if self._sr <= 0:
                return 0
            return int(1000 * self._pos / self._sr)

    def load(self, path: Path) -> bool:
        self.stop()
        if not path.exists() or path.stat().st_size < 44:
            self._data = np.zeros(0, dtype=np.float32)
            self._path = None
            return False
        with wave.open(str(path), "rb") as wf:
            self._sr = wf.getframerate() or 16000
            ch = wf.getnchannels()
            raw = wf.readframes(wf.getnframes())
        audio = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
        if ch > 1:
            audio = audio.reshape(-1, ch).mean(axis=1)
        self._data = audio
        self._pos = 0
        self._path = path
        return self._data.size > 0

    def play(self) -> None:
        if self._data.size == 0:
            return
        with self._lock:
            if self._playing:
                return
            self._playing = True
        try:
            import sounddevice as sd
        except ImportError:
            self._playing = False
            return

        def callback(outdata, frames, time_info, status) -> None:  # noqa: ANN001
            with self._lock:
                if not self._playing:
                    outdata.fill(0)
                    raise sd.CallbackStop
                end = min(self._pos + frames, self._data.size)
                chunk = self._data[self._pos : end]
                self._pos = end
                if chunk.size < frames:
                    out = np.zeros(frames, dtype=np.float32)
                    out[: chunk.size] = chunk
                    outdata[:, 0] = out
                    self._playing = False
                    raise sd.CallbackStop
                outdata[:, 0] = chunk

        self._stream = sd.OutputStream(
            samplerate=self._sr,
            channels=1,
            dtype="float32",
            callback=callback,
        )
        self._stream.start()

    def pause(self) -> None:
        with self._lock:
            self._playing = False
        if self._stream is not None:
            try:
                self._stream.stop()
                self._stream.close()
            except Exception:
                pass
            self._stream = None

    def stop(self) -> None:
        self.pause()
        with self._lock:
            self._pos = 0

    def seek_ms(self, ms: int) -> None:
        was = False
        with self._lock:
            was = self._playing
        self.pause()
        with self._lock:
            sample = int(ms / 1000.0 * self._sr)
            self._pos = max(0, min(sample, max(0, self._data.size - 1)))
        if was:
            self.play()

    @property
    def is_playing(self) -> bool:
        with self._lock:
            return self._playing


class TranscriptPlayerWindow(ctk.CTkToplevel):
    def __init__(self, master: ctk.CTk, session_path: Path) -> None:
        super().__init__(master)
        self.session = load_session(session_path)
        self.player = WavPlayer()
        self._seg_frames: list[tuple[TranscriptSegment, ctk.CTkFrame]] = []
        self._current_idx = -1
        self._seek_drag = False

        self.title(self.session.meta.title or "Transcript")
        self.geometry("880x640")
        self.minsize(720, 520)

        self._build_header()
        self._build_search()
        self._build_transcript()
        self._build_transport()
        self._load_default_track()
        self.protocol("WM_DELETE_WINDOW", self._on_close)
        self.bind("<space>", lambda _e: self._toggle_play())
        self.after(200, self._tick)

    def _build_header(self) -> None:
        head = ctk.CTkFrame(self, fg_color="transparent")
        head.pack(fill="x", padx=16, pady=(14, 6))
        left = ctk.CTkFrame(head, fg_color="transparent")
        left.pack(side="left", fill="x", expand=True)
        ctk.CTkLabel(
            left,
            text=self.session.meta.title or "Tanpa judul",
            font=ctk.CTkFont(size=20, weight="bold"),
            anchor="w",
        ).pack(anchor="w")
        created = (self.session.meta.created_at or "")[:19].replace("T", " ")
        dur = _fmt_ms(int((self.session.meta.duration_sec or 0) * 1000))
        meta = f"{created}  ·  {dur}  ·  {self.session.meta.mode}"
        ctk.CTkLabel(left, text=meta, text_color="gray", anchor="w").pack(anchor="w")
        right = ctk.CTkFrame(head, fg_color="transparent")
        right.pack(side="right")
        ctk.CTkButton(right, text="Export", width=90, command=self._export).pack(side="right", padx=4)

    def _build_search(self) -> None:
        row = ctk.CTkFrame(self, fg_color="transparent")
        row.pack(fill="x", padx=16, pady=(0, 6))
        self.search_var = ctk.StringVar(value="")
        entry = ctk.CTkEntry(row, textvariable=self.search_var, placeholder_text="Cari di transcript…")
        entry.pack(fill="x", side="left", expand=True)
        entry.bind("<KeyRelease>", lambda _e: self._render_segments())
        tracks = []
        if self.session.mic_wav.exists() and self.session.mic_wav.stat().st_size > 44:
            tracks.append("Mic")
        if self.session.speaker_wav.exists() and self.session.speaker_wav.stat().st_size > 44:
            tracks.append("Speaker")
        if not tracks:
            tracks = ["(tidak ada audio)"]
        self.track_var = ctk.StringVar(value=tracks[0])
        self.track_menu = ctk.CTkOptionMenu(
            row, variable=self.track_var, values=tracks, width=120, command=self._on_track_change
        )
        self.track_menu.pack(side="right", padx=(8, 0))

    def _build_transcript(self) -> None:
        self.list = ctk.CTkScrollableFrame(self)
        self.list.pack(fill="both", expand=True, padx=16, pady=6)
        self.empty_lbl = ctk.CTkLabel(self.list, text="")
        self._render_segments()

    def _build_transport(self) -> None:
        bar = ctk.CTkFrame(self)
        bar.pack(fill="x", padx=16, pady=(4, 14))
        controls = ctk.CTkFrame(bar, fg_color="transparent")
        controls.pack(fill="x", padx=8, pady=(8, 4))
        self.play_btn = ctk.CTkButton(controls, text="▶", width=44, command=self._toggle_play)
        self.play_btn.pack(side="left", padx=2)
        ctk.CTkButton(controls, text="−10s", width=50, command=lambda: self._nudge(-10000)).pack(
            side="left", padx=2
        )
        self.speed_var = ctk.StringVar(value="1.0x")
        # speed: restart with resample is heavy — keep 1.0 for v1 honesty, menu reserved
        ctk.CTkLabel(controls, textvariable=self.speed_var, width=40).pack(side="left", padx=4)
        ctk.CTkButton(controls, text="+10s", width=50, command=lambda: self._nudge(10000)).pack(
            side="left", padx=2
        )
        self.time_var = ctk.StringVar(value="00:00 / 00:00")
        ctk.CTkLabel(controls, textvariable=self.time_var).pack(side="right")

        self.seek = ctk.CTkSlider(bar, from_=0, to=1000, number_of_steps=1000, command=self._on_seek)
        self.seek.set(0)
        self.seek.pack(fill="x", padx=12, pady=(0, 10))
        self.seek.bind("<ButtonPress-1>", lambda _e: setattr(self, "_seek_drag", True))
        self.seek.bind("<ButtonRelease-1>", self._on_seek_release)

    def _segments(self) -> list[TranscriptSegment]:
        q = self.search_var.get().strip().lower()
        out = [s for s in self.session.segments if s.is_final and s.text.strip()]
        out.sort(key=lambda s: s.start_ms)
        if q:
            out = [s for s in out if q in s.text.lower() or q in s.speaker.lower()]
        return out

    def _render_segments(self) -> None:
        for w in self.list.winfo_children():
            w.destroy()
        self._seg_frames.clear()
        segs = self._segments()
        if not segs:
            ctk.CTkLabel(self.list, text="Belum ada segmen transcript di sesi ini.").pack(pady=24)
            return
        for seg in segs:
            frame = ctk.CTkFrame(self.list, fg_color=("gray95", "gray20"), corner_radius=8)
            frame.pack(fill="x", pady=4, padx=2)
            top = ctk.CTkFrame(frame, fg_color="transparent")
            top.pack(fill="x", padx=10, pady=(8, 0))
            color = _speaker_color(seg.speaker)
            ctk.CTkLabel(
                top,
                text=seg.speaker,
                text_color=color,
                font=ctk.CTkFont(weight="bold"),
            ).pack(side="left")
            ctk.CTkLabel(top, text=_fmt_ms(seg.start_ms), text_color="gray").pack(side="left", padx=10)
            body = ctk.CTkLabel(
                frame,
                text=seg.text.strip(),
                anchor="w",
                justify="left",
                wraplength=780,
            )
            body.pack(fill="x", padx=10, pady=(2, 10))
            frame.bind("<Button-1>", lambda _e, s=seg: self._jump_to(s.start_ms))
            body.bind("<Button-1>", lambda _e, s=seg: self._jump_to(s.start_ms))
            self._seg_frames.append((seg, frame))

    def _load_default_track(self) -> None:
        self._on_track_change(self.track_var.get())

    def _on_track_change(self, choice: str) -> None:
        self.player.stop()
        self.play_btn.configure(text="▶")
        path = self.session.speaker_wav if choice == "Speaker" else self.session.mic_wav
        ok = self.player.load(path)
        dur = self.player.duration_ms
        self.time_var.set(f"00:00 / {_fmt_ms(dur)}")
        self.seek.set(0)
        if not ok and choice != "(tidak ada audio)":
            self.time_var.set("Audio tidak tersedia")

    def _toggle_play(self) -> None:
        if self.player.is_playing:
            self.player.pause()
            self.play_btn.configure(text="▶")
        else:
            if self.player.position_ms >= max(0, self.player.duration_ms - 200):
                self.player.seek_ms(0)
            self.player.play()
            self.play_btn.configure(text="❚❚")

    def _nudge(self, delta_ms: int) -> None:
        self.player.seek_ms(self.player.position_ms + delta_ms)
        self._sync_ui()

    def _jump_to(self, ms: int) -> None:
        self.player.seek_ms(ms)
        if not self.player.is_playing:
            self.player.play()
            self.play_btn.configure(text="❚❚")
        self._sync_ui()

    def _on_seek(self, value: float) -> None:
        if not self._seek_drag:
            return
        dur = self.player.duration_ms
        if dur <= 0:
            return
        self.time_var.set(f"{_fmt_ms(int(value / 1000 * dur))} / {_fmt_ms(dur)}")

    def _on_seek_release(self, _event=None) -> None:  # noqa: ANN001
        self._seek_drag = False
        dur = self.player.duration_ms
        if dur <= 0:
            return
        ms = int(self.seek.get() / 1000.0 * dur)
        self.player.seek_ms(ms)
        self._sync_ui()

    def _tick(self) -> None:
        if self.winfo_exists():
            if not self._seek_drag:
                self._sync_ui()
            if not self.player.is_playing and self.play_btn.cget("text") != "▶":
                # playback ended
                if self.player.position_ms >= max(0, self.player.duration_ms - 50):
                    self.play_btn.configure(text="▶")
            self.after(200, self._tick)

    def _sync_ui(self) -> None:
        pos = self.player.position_ms
        dur = self.player.duration_ms
        self.time_var.set(f"{_fmt_ms(pos)} / {_fmt_ms(dur)}")
        if dur > 0 and not self._seek_drag:
            self.seek.set(min(1000, max(0, pos / dur * 1000)))
        # highlight active segment
        idx = -1
        for i, (seg, _frame) in enumerate(self._seg_frames):
            end = seg.end_ms if seg.end_ms > seg.start_ms else seg.start_ms + 15000
            if seg.start_ms <= pos < end:
                idx = i
                break
        if idx == self._current_idx:
            return
        for i, (_seg, frame) in enumerate(self._seg_frames):
            if i == idx:
                frame.configure(fg_color=("#D5F5E3", "#1E3A2F"))
            else:
                frame.configure(fg_color=("gray95", "gray20"))
        self._current_idx = idx

    def _export(self) -> None:
        ExportDialog(self, self.session, self.session.meta.title, Settings.load())

    def _on_close(self) -> None:
        self.player.stop()
        self.destroy()
