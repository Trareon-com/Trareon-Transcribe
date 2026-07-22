# Task - Desktop

## Identity
- **Task ID:** TRAREON-001
- **Title:** Implementasi MVP Trareon Transcribe — Live transcribe mic + speaker offline
- **Risk class:** high
- **Author:** User (design owner)
- **Independent reviewer:** (belum ditugaskan)
- **Branch / worktree:** feat/traeon-mvp

## Specification Mapping
- **PRD requirement:** PRD-Desktop v1.0 section 7, 8
- **RFC section / requirement:** RFC-Desktop section 5, 6, 9
- **Parent milestone:** MVP Trareon Transcribe

## Scope
- **Behavior being changed:** Aplikasi baru; capture audio 2 stream, transcribe offline,
  toggle runtime, export multi-format.
- **Files or APIs allowed to change:** engine/, ui/, export/, setup/ (semua baru)
- **Target OS/build/architecture:** macOS arm64 + x86_64, Windows 11 x86_64; Python 3.11
- **Explicit non-goals:** Cloud STT, pyannote wajib, Linux, translate online.

## Acceptance Criteria
- [ ] App jalan 100% offline; tidak ada network call saat transkrip.
- [ ] Toggle MIC/SPEAKER runtime tanpa stop rekaman.
- [ ] 3 mode (Webinar/Rapat Online/Rapat Offline) set default toggle benar.
- [ ] whisper.cpp transcribe ID+EN, label bahasa per segment.
- [ ] Export WAV per-track + MD + TXT + JSON, nama YYYYMMDD-[judul/UUID].
- [ ] Setup wizard install BlackHole(ffmpeg di mac / VB-Audio+ffmpeg di win) + download model.
- [ ] Minimize-to-tray menjaga transkrip background.
- [ ] Light/dark mode + auto-scroll cerdas (bawah=on, atas=off).

## Test Oracle dan Verification
- **Test written before implementation:** unit test vad, dedupe, naming, export; integration fixture audio.
- **Expected success result:** transkrip muncul real-time, export file valid.
- **Expected failure/tamper result:** model corrupt → re-download prompt; mic denied → wizard panduan.
- **Commands to run:** pytest engine/ export/ ; pyinstaller build; smoke di mac+win.
- **Fixture or allowlisted lab hardware:** Mac M-series, Mac Intel, Windows 11 VM; fixture WAV.

## Security dan Evidence Boundary
- **Privilege required:** user-level; mic + screen recording (mac) permission.
- **Data classification:** prohibited-real-evidence (jangan pakai rapat rahasia asli saat test).
- **Destructive operation:** none (hanya tulis file export di folder user).
- **Secrets or signing keys:** prohibited unless separate approved release task.

## Acceptance Criteria (tambahan 2026-07-22)
- [x] Mic/speaker device disconnect (sleep/wake, cabut kabel) auto-reconnect tanpa restart app.
- [x] Windows setup wizard auto-install VB-Audio Cable via Chocolatey bila tersedia.
- [x] Unit test VAD (`tests/test_vad.py`).
- [x] Integration test capture→VAD→STT→dedupe→export dengan fixture PCM sintetis
      (`tests/test_pipeline_integration.py`).

## Handoff
- **Commit hash:** (isi saat commit)
- **Commands actually run and results:** `pytest tests/ -q` → 69 passed; `ruff check .` → All checks passed.
- **Known limitations:** Intel lawas lambat di large model; detect judul mac butuh screen
  recording; VB-Audio Cable via Chocolatey mungkin perlu restart Windows agar driver aktif;
  belum ada smoke test nyata di Windows 11 VM / Mac Intel fisik dalam sesi ini — dilaporkan
  `NotValidated`, bukan diasumsikan lulus.
- **Unverified platforms or capabilities:** Linux; pyannote diarization (phase 2); reconnect
  watchdog belum diuji di hardware Windows/mac fisik dengan device dicabut-pasang sungguhan.
- **Reviewer decision:** (ship / fix-first / blocked)
