# RFC - Desktop

## 1. Ringkasan
- **Nama fitur / produk:** Trareon Transcribe
- **Baseline PRD:** PRD-Desktop v1.0
- **Status:** Draft untuk implementasi
- **Target OS:** macOS (Apple Silicon + Intel), Windows 11

## 2. Problem Statement
- Apa masalah teknis yang harus diselesaikan: Capture simultan mic + speaker loopback
  secara offline, transcribe real-time via whisper.cpp, kontrol toggle runtime, dan
  menghindari duplikasi echo di rapat online.
- Kenapa solusi ini dipilih: whisper.cpp native efisien di CPU/Neural Engine; BlackHole
  (mac) / WASAPI loopback (win) menyediakan capture speaker tanpa virtual cable berbayar.

## 3. Goals
- Live transcribe 2 stream audio offline dengan toggle independen.
- Setup zero-manual untuk user awam.
- UI tidak mengganggu saat Zoom share screen (minimize-to-tray).

## 4. Non-Goals
- Cloud STT, kolaborasi online, Linux support.

## 5. Arsitektur Tingkat Tinggi
- Runtime / framework: Python 3.11 + CustomTkinter.
- UI layer: CustomTkinter (light/dark), tray via rumpelstiltskin/pystray.
- State management: in-memory + config JSON lokal.
- Data storage: file disk lokal (WAV/MD/TXT/JSON).
- IPC / command boundary: internal module call (engine ↔ ui ↔ export).
- Update / packaging: PyInstaller single executable.

## 6. Struktur Komponen
- App shell: main_window.py (CustomTkinter).
- Main window: caption area, toggle, mode selector, resource monitor.
- Renderer: CustomTkinter widgets.
- Native bridge: audio_capture (sounddevice/ffmpeg), setup deps (brew/cmd).
- Storage / sync: export writer + naming.
- Background jobs: audio chunk worker, STT worker, auto-save timer.

## 7. Model Data
- Entitas utama: Session (id, mode, start_time, tracks[]), TranscriptSegment
  (timestamp, source, speaker, language, text, confidence).
- Skema / persistence: JSON session + WAV per track + MD/TXT.
- Migrasi: tidak ada (v1).

## 8. API / Boundary
- Command / service boundary: engine.capture_start(track), engine.toggle(track, state),
  stt.transcribe(chunk) → segment, export.write(session).
- Input validation: model name dari allowlist, path aman.
- Error contract: raise typed exception → UI toast, tidak crash.
- Permissions: mic (runtime prompt), screen recording (mac, untuk detect judul).

## 9. Alur Utama
- Flow 1 (first run): wizard detect spec → pilih model → install deps → download → main.
- Flow 2 (live): pilih mode → toggle → capture chunk → VAD → STT → dedupe → UI append.

## 10. Edge Case dan Failure Mode
- App crash / restart: auto-save chunk 10s → resume.
- Permission denied: wizard panduan ulang.
- File not found: model missing → re-download prompt.
- Storage corrupt: JSON parse fail → backup + new session.
- Network offline: tidak masalah (offline), kecuali download model butuh online saat setup.
- Update gagal: tidak ada auto-update; user download build baru (cek manual via Settings →
  update checker, `update/check.py`).
- Device disconnect (sleep/wake, USB unplug BlackHole/VB-Cable): `AudioCapture` menjalankan
  watchdog thread (poll 2s) yang mendeteksi stream `inactive` dan membuka ulang stream mic/
  speaker tanpa restart pipeline; bila loopback device baru muncul setelah start (driver
  ter-install belakangan), watchdog otomatis membuka stream speaker begitu device terdeteksi.

## 11. Phasing
- Phase MVP: capture 2 stream + toggle + whisper.cpp + export MD/WAV/TXT/JSON + wizard.
- Phase berikutnya: pyannote diarization, translate offline, SRT/VTT.

## 12. Testing Plan
- Unit test: vad, dedupe, naming, export.
- Integration test: capture→stt→export end-to-end dengan fixture audio.
- UI test: toggle, mode, theme, tray.
- Platform smoke test: macOS (M-series + Intel), Windows 11.

## 13. Deployment / Packaging
- macOS: PyInstaller --windowed → .app, butuh BlackHole (wizard install via brew cask).
- Windows: PyInstaller --windowed → .exe, butuh VB-Audio Cable (wizard install via
  Chocolatey `vb-cable` bila choco tersedia; instruksi manual + link resmi bila tidak).
- Linux: tidak pada fase ini.

## 13a. Fitur Non-MVP yang Sudah Terimplementasi
- Remote control lokal (`util/remote_control.py`): server Unix socket untuk kontrol
  start/stop/toggle dari luar proses, dipakai untuk automasi/testing internal.
- VU meter (`ui/vu_meter.py` + level tracking di `engine/audio_capture.py`).
- Singleton window / instance lock (`config/instance_lock.py`).
- Update checker manual (`update/check.py`), dipicu tombol di Settings, tidak silent.

## 14. Open Questions
- Apakah detect judul via AppleScript reliable di macOS Sequoia?
- Apakah NLLB translate layak di MVP?
