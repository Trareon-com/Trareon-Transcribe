# Code - Desktop

## Tujuan
- Implementasi slice terkecil yang bernilai dan sesuai RFC Desktop: MVP Trareon Transcribe
  dengan capture 2 stream, toggle runtime, whisper.cpp offline, export, dan setup wizard.

## Input Wajib
- PRD Desktop v1.0 (disetujui)
- RFC Desktop (disetujui)
- Task ID TRAREON-001, risk class high, acceptance criteria di atas
- Target platform: macOS arm64/x86_64, Windows 11 x86_64
- Kode existing: /Users/user/Projects/Trareon/Trareon Transcribe/ (folder kosong, mulai baru)

## Scope Implementasi
- Fitur utama: audio capture 2 stream, toggle, 3 mode, whisper.cpp STT, dual VAD,
  echo-dedupe, UI light/dark + tray + auto-scroll, export WAV/MD/TXT/JSON, setup wizard.
- File yang boleh disentuh: engine/, ui/, export/, setup/, requirements.txt, README.md
- File yang tidak boleh disentuh: (tidak ada, repo baru)

## Aturan
- Ikuti arsitektur RFC (section 5, 6).
- Jangan tambah fitur di luar MVP (pyannote/translate/SRT ditunda phase 2).
- Prioritaskan perubahan kecil dan mudah di-review.
- Gunakan pattern native desktop: CustomTkinter untuk UI, sounddevice/ffmpeg untuk capture.

## Rencana Kerja
1. Identifikasi titik masuk kode: ui/main_window.py sebagai entry.
2. Implementasi model data / boundary: export/naming.py, engine/stt.py contract.
3. Implementasi UI atau shell desktop: main_window, tray, theme.
4. Tambah validasi dan error handling: typed exception, permission prompt.
5. Tambah test: unit vad/dedupe/naming/export, integration fixture.
6. Jalankan verifikasi: pytest + pyinstaller build + smoke.

## Definisi Selesai
- [ ] Portable core/contract checks lulus pada macOS, Windows sejauh runner mendukung
- [ ] Fitur platform-specific berjalan pada target OS yang tercantum dalam task
- [ ] Platform yang belum diuji dilaporkan sebagai `NotValidated`, bukan diasumsikan didukung
- [ ] Test relevan lulus
- [ ] Type-check lulus (mypy/pyright jika ada)
- [ ] Tidak ada capability claim di luar evidence
- [ ] Commit hash, perintah verifikasi, hasil, dan limitation dicatat untuk handoff

## Verifikasi
- Test fokus: pytest engine/ export/ (vad, dedupe, naming, export writer)
- Type-check: pyright ./ (jika di-setup)
- Smoke test: jalankan executable, capture mic+speaker fixture, export file ada
- Packaging check: pyinstaller --windowed hasilkan .app/.exe
- Target OS/build/architecture: macOS arm64, macOS x86_64, Windows x86_64
- Hardware/fixture: Mac M-series, Mac Intel, Windows 11 VM, fixture WAV stereo
- Commit hash yang diuji: (isi saat build)

## Catatan Implementasi
- Keputusan penting: whisper.cpp (bukan PyTorch Whisper) untuk efisiensi offline.
- Tradeoff: model large-v3-turbo akurat tapi berat di Intel → wizard sarankan medium.
- Risiko tersisa: detect judul rapat mac butuh izin screen recording; BlackHole/VB-Cable
  setup manual jika brew/choco gagal atau tidak tersedia.
- 2026-07-22: Ditambahkan audio device watchdog (`engine/audio_capture.py`) — reconnect
  otomatis mic/speaker setelah sleep-wake atau cabut-pasang perangkat, tanpa restart
  pipeline. Windows dep plan (`setup/deps.py`) sekarang mencoba auto-install VB-Audio
  Cable via Chocolatey (`choco install vb-cable`), fallback ke instruksi manual bila
  choco tidak ada.
- 2026-07-22: Tambah `tests/test_vad.py` (unit, WebRTC+Silero+energy fallback) dan
  `tests/test_pipeline_integration.py` (integration, fixture PCM sintetis melalui
  capture→VAD→STT stub→dedupe→export, tanpa bergantung pada binary whisper.cpp asli
  atau hardware audio).
