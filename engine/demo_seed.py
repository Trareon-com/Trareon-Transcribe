"""Seed dummy sessions so Library / player / export can be checked without live STT."""

from __future__ import annotations

import math
import struct
import wave
from datetime import datetime, timedelta
from pathlib import Path

from config.paths import default_library_root
from config.settings import Settings
from engine.session_store import (
    Session,
    TranscriptSegment,
    create_session,
    finalize_session,
    list_sessions,
    load_session,
)
from export.writer import export_formats

SR = 16000
DEMO_TITLE = "Demo Daily Sync Trareon"
DEMO_MARKER = "demo-seed"


def _write_tone_wav(path: Path, duration_ms: int, beeps: list[tuple[int, float]]) -> None:
    """Write mono 16-bit PCM with soft bed + timed beeps (ms, hz)."""
    n = max(1, int(SR * duration_ms / 1000))
    samples = [0.0] * n
    for i in range(n):
        # quiet bed so file isn't silent
        samples[i] = 0.02 * math.sin(2 * math.pi * 120.0 * i / SR)
    for start_ms, hz in beeps:
        start = int(SR * start_ms / 1000)
        length = int(SR * 0.35)
        for j in range(length):
            idx = start + j
            if idx >= n:
                break
            env = min(1.0, j / 400.0) * min(1.0, (length - j) / 400.0)
            samples[idx] += 0.35 * env * math.sin(2 * math.pi * hz * j / SR)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
        )
        wf.writeframes(frames)


def _demo_segments() -> list[TranscriptSegment]:
    # ~40s bilingual meeting snippet
    return [
        TranscriptSegment(0, 3500, "Selamat pagi, kita mulai daily sync.", "MIC", "id", 0.92, True, "MIC"),
        TranscriptSegment(
            3600, 7200, "Good morning — quick update on Trareon Transcribe.", "SPEAKER", "en", 0.9, True, "SPEAKER"
        ),
        TranscriptSegment(
            7400, 12000, "Kemarin setup wizard dan library player sudah jalan.", "MIC", "id", 0.88, True, "MIC"
        ),
        TranscriptSegment(
            12200, 16800, "I tested export to SRT and Markdown — looks good.", "SPEAKER", "en", 0.91, True, "SPEAKER"
        ),
        TranscriptSegment(
            17000, 21500, "Hari ini fokus polish branding macOS dan dummy seed.", "MIC", "id", 0.89, True, "MIC"
        ),
        TranscriptSegment(
            21800, 26500, "Can you open Library and press Putar to verify sync?", "SPEAKER", "en", 0.87, True, "SPEAKER"
        ),
        TranscriptSegment(
            26800, 32000, "Ya — audio mic dan speaker harus highlight segmen yang aktif.", "MIC", "id", 0.93, True, "MIC"
        ),
        TranscriptSegment(
            32200, 38000, "Great. If search finds 'export', the filter works too.", "SPEAKER", "en", 0.9, True, "SPEAKER"
        ),
        TranscriptSegment(
            38200, 42000, "Oke, demo selesai. Terima kasih.", "MIC", "id", 0.94, True, "MIC"
        ),
    ]


def seed_demo_sessions(
    library_root: Path | None = None,
    *,
    force: bool = False,
    update_settings: bool | None = None,
) -> list[Session]:
    """Create finalized demo sessions with WAV + transcript (+ export files)."""
    # Only rewrite user Settings when seeding the real library (not test tmp dirs).
    if update_settings is None:
        update_settings = library_root is None
    root = library_root or default_library_root()
    root.mkdir(parents=True, exist_ok=True)

    existing = [
        m
        for m in list_sessions(root)
        if DEMO_MARKER in (m.folder_name or "") or (m.title or "").startswith("Demo ")
    ]
    if existing and not force:
        return [load_session(root / m.folder_name) for m in existing if (root / m.folder_name).exists()]

    if force:
        from engine.session_store import delete_session

        for m in existing:
            folder = root / (m.folder_name or "")
            if folder.exists():
                delete_session(folder, root)

    sessions: list[Session] = []

    # Primary playable session
    s1 = create_session(root, DEMO_TITLE, "rapat_online")
    # Rename folder to include marker for idempotent re-seed detection
    marker_name = f"{s1.root.name}-{DEMO_MARKER}"
    dest = root / marker_name
    s1.root.rename(dest)
    s1.root = dest
    s1.meta.folder_name = marker_name
    s1.meta.mic_device = "Demo Mic"
    s1.meta.speaker_device = "Demo Speaker"
    segs = _demo_segments()
    s1.segments = segs
    duration_ms = max(s.end_ms for s in segs) + 2000
    mic_beeps = [(s.start_ms, 660.0) for s in segs if s.source == "MIC"]
    spk_beeps = [(s.start_ms, 440.0) for s in segs if s.source == "SPEAKER"]
    _write_tone_wav(s1.mic_wav, duration_ms, mic_beeps)
    _write_tone_wav(s1.speaker_wav, duration_ms, spk_beeps)
    s1.meta.duration_sec = duration_ms / 1000.0
    s1.meta.created_at = (datetime.now().astimezone() - timedelta(minutes=15)).isoformat()
    s1 = finalize_session(s1, rename_for_title=False)
    export_formats(s1, md=True, txt=True, json_out=True, srt=True, vtt=True)
    sessions.append(s1)

    # Second shorter session (list UI looks less empty)
    s2 = create_session(root, "Demo Standup singkat", "rapat_offline")
    marker2 = f"{s2.root.name}-{DEMO_MARKER}"
    dest2 = root / marker2
    s2.root.rename(dest2)
    s2.root = dest2
    s2.meta.folder_name = marker2
    s2.segments = [
        TranscriptSegment(0, 2500, "Standup: tidak ada blocker.", "MIC", "id", 0.9, True, "MIC"),
        TranscriptSegment(2600, 5200, "Same here — shipping the demo seed.", "SPEAKER", "en", 0.88, True, "SPEAKER"),
        TranscriptSegment(5400, 8000, "Sip, lanjut kerja.", "MIC", "id", 0.91, True, "MIC"),
    ]
    dur2 = 9000
    _write_tone_wav(s2.mic_wav, dur2, [(0, 700.0), (5400, 700.0)])
    _write_tone_wav(s2.speaker_wav, dur2, [(2600, 480.0)])
    s2.meta.duration_sec = dur2 / 1000.0
    s2.meta.created_at = (datetime.now().astimezone() - timedelta(hours=2)).isoformat()
    s2 = finalize_session(s2, rename_for_title=False)
    export_formats(s2, md=True, txt=True, json_out=True, srt=False, vtt=False)
    sessions.append(s2)

    if update_settings:
        settings = Settings.load()
        # Demo may open the main UI, but do not fake a real speaker tone pass.
        settings.setup_complete = True
        settings.tone_test_ok = False
        settings.tone_test_skipped = True
        settings.library_root = str(root)
        settings.last_meeting_title = DEMO_TITLE
        settings.save()

    return sessions


def verify_demo(session: Session) -> list[str]:
    """Return list of OK checks; raise AssertionError on hard failure."""
    checks: list[str] = []
    assert session.transcript_path.exists(), "transcript.json missing"
    checks.append("transcript.json")
    session.load_transcript()
    assert len(session.segments) >= 3, "too few segments"
    checks.append(f"{len(session.segments)} segments")
    assert session.mic_wav.exists() and session.mic_wav.stat().st_size > 1000, "mic.wav"
    checks.append(f"mic.wav {session.mic_wav.stat().st_size}B")
    assert session.speaker_wav.exists() and session.speaker_wav.stat().st_size > 1000, "speaker.wav"
    checks.append(f"speaker.wav {session.speaker_wav.stat().st_size}B")
    for name in ("transcript.md", "transcript.txt", "transcript.srt"):
        p = session.root / name
        if p.exists() and p.stat().st_size > 20:
            checks.append(name)
    return checks
