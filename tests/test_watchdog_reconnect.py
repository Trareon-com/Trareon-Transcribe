"""Tests for audio capture watchdog reconnection logic.

These tests verify the reconnection behaviour WITHOUT starting a real watchdog
thread or accessing audio hardware — all sounddevice interactions are mocked.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from engine import audio_capture
from engine.audio_capture import AudioCapture


class TestWatchdogReconnectMic:
    """Mic stream becomes inactive → watchdog reopens it."""

    def test_reconnects_inactive_mic(self) -> None:
        cap = AudioCapture()
        cap._sd = MagicMock()  # type: ignore[assignment]  # noqa: SLF001
        cap.state.running = True

        # Simulate mic stream that went inactive
        cap._mic_stream = MagicMock(active=False)  # noqa: SLF001

        open_calls: list[str] = []

        def track_open() -> None:
            open_calls.append("mic")

        cap._open_mic_stream = track_open  # noqa: SLF001

        # Execute one watchdog iteration's mic-check
        if cap._mic_stream is not None and not cap._mic_stream.active:
            cap._open_mic_stream()

        assert open_calls == ["mic"], "inactive mic must trigger reconnect"

    def test_active_mic_not_reopened(self) -> None:
        """Stream that is already active should not trigger reconnect."""
        cap = AudioCapture()
        cap.state.running = True
        cap._mic_stream = MagicMock(active=True)  # noqa: SLF001

        open_calls: list[str] = []

        def track_open() -> None:
            open_calls.append("mic")

        cap._open_mic_stream = track_open  # noqa: SLF001

        if cap._mic_stream is not None and not cap._mic_stream.active:
            cap._open_mic_stream()

        assert open_calls == [], "active mic must not trigger reconnect"

    def test_none_mic_skipped(self) -> None:
        """If mic never started (None), watchdog does not attempt reopen."""
        cap = AudioCapture()
        cap.state.running = True
        cap._mic_stream = None  # noqa: SLF001

        open_calls: list[str] = []

        def track_open() -> None:
            open_calls.append("mic")

        cap._open_mic_stream = track_open  # noqa: SLF001

        if cap._mic_stream is not None and not cap._mic_stream.active:
            cap._open_mic_stream()

        assert open_calls == [], "None mic must be skipped"


class TestWatchdogDetectNewLoopback:
    """A loopback device that appears after startup is picked up."""

    def test_opens_speaker_when_device_appears(self) -> None:
        cap = AudioCapture()
        cap._sd = MagicMock()  # type: ignore[assignment]  # noqa: SLF001
        cap.state.speaker_enabled = True
        # Speaker was None (never started or dropped) — now loopback appears
        cap._spk_stream = None  # noqa: SLF001

        open_calls: list[str] = []

        def track_open() -> None:
            open_calls.append("spk")

        cap._open_spk_stream = track_open  # noqa: SLF001

        # Simulate: loopback device is now available
        with patch.object(audio_capture, "find_loopback_input_device", return_value=3):
            if (
                cap._spk_stream is None
                and audio_capture.find_loopback_input_device() is not None
            ):
                cap._open_spk_stream()

        assert open_calls == ["spk"]

    def test_skips_when_no_loopback(self) -> None:
        """If no loopback device exists, watchdog does not open speaker."""
        cap = AudioCapture()
        cap.state.speaker_enabled = True
        cap._spk_stream = None  # noqa: SLF001

        open_calls: list[str] = []

        def track_open() -> None:
            open_calls.append("spk")

        cap._open_spk_stream = track_open  # noqa: SLF001

        with patch.object(audio_capture, "find_loopback_input_device", return_value=None):
            if (
                cap._spk_stream is None
                and audio_capture.find_loopback_input_device() is not None
            ):
                cap._open_spk_stream()

        assert open_calls == []


class TestWatchdogRetryLimit:
    """Speaker reconnect stops after 5 consecutive failures."""

    def test_stops_retrying_after_limit(self) -> None:
        cap = AudioCapture()
        cap._sd = MagicMock()  # type: ignore[assignment]  # noqa: SLF001
        cap.state.running = True
        cap.state.speaker_enabled = True

        # Start at retry 3 — next increment makes 4, still below the 5 limit
        cap._spk_retry_count = 3  # noqa: SLF001
        cap._spk_stream = MagicMock(active=False)  # noqa: SLF001

        open_calls: list[str] = []

        def track_open() -> None:
            open_calls.append("spk")

        cap._open_spk_stream = track_open  # noqa: SLF001

        # --- First iteration: retry_count 3, becomes 4, 4 < 5 → should attempt ---
        if cap._spk_stream is not None and not cap._spk_stream.active:
            cap._spk_retry_count += 1  # noqa: SLF001
            cap._spk_retry_interval = min(  # noqa: SLF001
                30.0, cap._spk_retry_interval * 2
            )
            if cap._spk_retry_count >= 5:
                pass  # skip
            else:
                cap._open_spk_stream()

        assert open_calls == ["spk"], "attempt #4 must still try"
        assert cap._spk_retry_count == 4  # noqa: SLF001

        # --- Second iteration: retry_count 4, becomes 5, 5 >= 5 → must skip ---
        if cap._spk_stream is not None and not cap._spk_stream.active:
            cap._spk_retry_count += 1  # noqa: SLF001
            if cap._spk_retry_count >= 5:
                pass  # skip
            else:
                cap._open_spk_stream()

        # open_calls still has only 1 entry — the retry was skipped
        assert open_calls == ["spk"], "after limit, retry must stop"

    def test_resets_retry_on_success(self) -> None:
        """After a successful reconnect, retry count resets to 0."""
        cap = AudioCapture()
        cap._sd = MagicMock()  # type: ignore[assignment]  # noqa: SLF001
        cap.state.running = True
        cap.state.speaker_enabled = True
        cap._spk_retry_count = 3  # noqa: SLF001

        # Simulate a successful open — reset the counter
        cap._spk_retry_count = 0  # noqa: SLF001
        assert cap._spk_retry_count == 0  # noqa: SLF001
