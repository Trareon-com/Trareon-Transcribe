"""Recording pipeline: audio → VAD → STT workers → dedupe → session + UI events."""

from __future__ import annotations

import logging
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from enum import StrEnum

from engine.audio_capture import SAMPLE_RATE, AudioCapture
from engine.dedupe import EchoDedupe
from engine.session_store import Session, TranscriptSegment, create_session, finalize_session, update_title
from engine.stt import WhisperCppStt
from engine.vad import DualVad
from export.naming import meeting_apps_active
from util.threading_helpers import UiEventQueue

log = logging.getLogger("trareon.pipeline")

CHUNK_SEC = 20
AUTOSAVE_SEC = 10


class PipelineStatus(StrEnum):
    IDLE = "Idle"
    LISTENING = "Listening"
    TRANSCRIBING = "Transcribing"
    PAUSED = "Paused"
    DEVICE_ERROR = "Device error"


@dataclass
class Pipeline:
    settings_mode: str
    model_name: str
    library_root: str
    events: UiEventQueue
    on_status: Callable[[PipelineStatus], None] | None = None
    on_segment: Callable[[TranscriptSegment], None] | None = None
    session: Session | None = None
    status: PipelineStatus = PipelineStatus.IDLE
    mic_enabled: bool = True
    speaker_enabled: bool = True
    _capture: AudioCapture | None = None
    _vad: DualVad = field(default_factory=DualVad)
    _stt: WhisperCppStt | None = None
    _dedupe: EchoDedupe = field(default_factory=EchoDedupe)
    _mic_buf: bytearray = field(default_factory=bytearray)
    _spk_buf: bytearray = field(default_factory=bytearray)
    _lock: threading.Lock = field(default_factory=threading.Lock)
    _stop: threading.Event = field(default_factory=threading.Event)
    _threads: list[threading.Thread] = field(default_factory=list)
    _start_mono: float = 0.0
    _last_autosave: float = 0.0
    _meeting_pause: bool = False
    _stub_warned: bool = False

    def _set_status(self, s: PipelineStatus) -> None:
        self.status = s
        if self.on_status:
            self.events.post(self.on_status, s)

    def start(self, title: str) -> Session:
        from pathlib import Path

        self._stt = WhisperCppStt(self.model_name)
        self.session = create_session(Path(self.library_root), title, self.settings_mode)
        self._apply_mode_defaults()
        self._mic_buf.clear()
        self._spk_buf.clear()
        self._stop.clear()
        self._start_mono = time.monotonic()
        self._last_autosave = self._start_mono

        self._capture = AudioCapture(
            on_mic_chunk=self._on_mic,
            on_speaker_chunk=self._on_spk,
        )
        self._capture.set_mic_enabled(self.mic_enabled)
        self._capture.set_speaker_enabled(self.speaker_enabled)
        self._capture.open_wav_writers(self.session.mic_wav, self.session.speaker_wav)
        try:
            self._capture.start()
        except Exception:
            self._set_status(PipelineStatus.DEVICE_ERROR)
            raise
        self._set_status(PipelineStatus.LISTENING)
        t = threading.Thread(target=self._chunk_loop, name="stt-chunk", daemon=True)
        t.start()
        self._threads.append(t)
        t2 = threading.Thread(target=self._watchdog_loop, name="watchdog", daemon=True)
        t2.start()
        self._threads.append(t2)
        return self.session

    def _apply_mode_defaults(self) -> None:
        if self.settings_mode == "webinar":
            self.mic_enabled, self.speaker_enabled = False, True
        elif self.settings_mode == "rapat_offline":
            self.mic_enabled, self.speaker_enabled = True, False
        else:
            self.mic_enabled, self.speaker_enabled = True, True

    def set_mic(self, enabled: bool) -> None:
        self.mic_enabled = enabled
        if self._capture:
            self._capture.set_mic_enabled(enabled)

    def set_speaker(self, enabled: bool) -> None:
        self.speaker_enabled = enabled
        if self._capture:
            self._capture.set_speaker_enabled(enabled)

    def levels(self) -> tuple[float, float]:
        if self._capture:
            return self._capture.levels()
        return 0.0, 0.0

    def set_title(self, title: str) -> None:
        if self.session:
            update_title(self.session, title)

    def stop(self) -> Session | None:
        self._stop.set()
        if self._capture:
            self._capture.stop()
        # flush remaining buffers
        self._flush("MIC", self._mic_buf)
        self._flush("SPEAKER", self._spk_buf)
        sess = self.session
        if sess:
            sess = finalize_session(sess, rename_for_title=True)
            self.session = sess
        self._set_status(PipelineStatus.IDLE)
        return sess

    def _on_mic(self, pcm: bytes) -> None:
        if self._meeting_pause:
            return
        with self._lock:
            self._mic_buf.extend(pcm)

    def _on_spk(self, pcm: bytes) -> None:
        if self._meeting_pause:
            return
        with self._lock:
            self._spk_buf.extend(pcm)

    def _chunk_loop(self) -> None:
        need = SAMPLE_RATE * 2 * CHUNK_SEC  # bytes
        while not self._stop.is_set():
            time.sleep(0.5)
            for label, buf in (("MIC", self._mic_buf), ("SPEAKER", self._spk_buf)):
                with self._lock:
                    if len(buf) < need:
                        continue
                    chunk = bytes(buf[:need])
                    del buf[:need]
                self._process_chunk(label, chunk)
            now = time.monotonic()
            if self.session and now - self._last_autosave >= AUTOSAVE_SEC:
                self.session.save_transcript()
                self.session.save_meta()
                self._last_autosave = now

    def _flush(self, label: str, buf: bytearray) -> None:
        with self._lock:
            data = bytes(buf)
            buf.clear()
        if data:
            self._process_chunk(label, data)

    def _process_chunk(self, label: str, pcm: bytes) -> None:
        if not self._vad.is_speech(pcm, SAMPLE_RATE):
            return
        assert self._stt is not None
        self._set_status(PipelineStatus.TRANSCRIBING)
        # partial placeholder
        elapsed_ms = int((time.monotonic() - self._start_mono) * 1000)
        partial = TranscriptSegment(
            start_ms=elapsed_ms,
            end_ms=elapsed_ms + CHUNK_SEC * 1000,
            text="…",
            speaker=label,
            language="auto",
            confidence=0.0,
            is_final=False,
            source=label,
        )
        if self.on_segment:
            self.events.post(self.on_segment, partial)
        result = self._stt.transcribe(pcm, SAMPLE_RATE)
        if not result.text or result.text.startswith("[STT:"):
            # Emit stub at most once so caption is not flooded
            if result.text.startswith("[STT:") and not self._stub_warned:
                self._stub_warned = True
                final = TranscriptSegment(
                    start_ms=elapsed_ms,
                    end_ms=elapsed_ms + 1000,
                    text=result.text,
                    speaker=label,
                    language="id",
                    confidence=0.0,
                    is_final=True,
                    source=label,
                )
                self._emit_final(final)
            self._set_status(PipelineStatus.LISTENING)
            return
        final = TranscriptSegment(
            start_ms=elapsed_ms,
            end_ms=elapsed_ms + CHUNK_SEC * 1000,
            text=result.text,
            speaker=label,
            language=result.language,
            confidence=result.confidence,
            is_final=True,
            source=label,
        )
        self._emit_final(final)
        self._set_status(PipelineStatus.LISTENING)

    def _emit_final(self, seg: TranscriptSegment) -> None:
        if not self.session:
            return
        if self.settings_mode == "rapat_online":
            kept = self._dedupe.filter_segment(seg, self.session.segments)
            if kept is None:
                return
            seg = kept
        self.session.segments.append(seg)
        if self.on_segment:
            self.events.post(self.on_segment, seg)

    def _watchdog_loop(self) -> None:
        saw_meeting = False
        while not self._stop.is_set():
            time.sleep(5)
            if self.settings_mode != "rapat_online":
                continue
            active = meeting_apps_active()
            if active:
                saw_meeting = True
                if self._meeting_pause:
                    self._meeting_pause = False
                    self._set_status(PipelineStatus.LISTENING)
            elif saw_meeting and not self._meeting_pause:
                self._meeting_pause = True
                self._set_status(PipelineStatus.PAUSED)

    def pause(self) -> None:
        self._meeting_pause = True
        self._set_status(PipelineStatus.PAUSED)

    def resume(self) -> None:
        self._meeting_pause = False
        self._set_status(PipelineStatus.LISTENING)

    def elapsed_sec(self) -> float:
        if not self._start_mono:
            return 0.0
        return max(0.0, time.monotonic() - self._start_mono)
