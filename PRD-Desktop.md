# PRD - Desktop

## 1. Ringkasan
- **Nama produk:** Trareon Transcribe
- **Platform target:** macOS (Apple Silicon + Intel), Windows 11
- **Versi dokumen:** 1.0
- **Status:** Disetujui (dari design spec 2026-07-20)

## 2. Masalah yang Ingin Diselesaikan
- Masalah utama: Tidak ada tool open-source Mac/Windows yang merekam & mentranskrip
  secara live mic + speaker laptop secara bersamaan, 100% offline, dengan kontrol
  privasi mic/speaker terpisah, dan dukungan bahasa Indonesia + Inggris.
- Siapa yang terdampak: Pengguna yang rapat via Zoom/Meet/Webinar dengan konten rahasia,
  serta rapat offline di ruangan fisik yang ingin diarsipkan.
- Dampak bisnis / pengguna: Kerahasiaan terjaga (audio tidak ke cloud), transkrip rapat
  tersedia untuk arsip tanpa biaya berlangganan.

## 3. Tujuan
- Tujuan utama: Live transcribe real-time mic + speaker, offline, cross-platform.
- Tujuan sekunder: Diarization opsional, export multi-format, setup otomatis untuk
  user yang belum install apa-apa.

## 4. Non-Tujuan
- Tidak membangun fitur translate cloud atau API berbayar.
- Tidak membangun editor transkrip kolaboratif online.
- Tidak mendukung Linux pada fase ini (template menyebutkan, tapi scope kita mac+win).

## 5. Ruang Lingkup
### In scope
- 2 stream audio independen (mic, speaker) dengan toggle runtime.
- 3 mode: Webinar, Rapat Online, Rapat Offline.
- STT whisper.cpp offline, auto language ID/EN.
- Dual VAD, echo-dedupe, failsafe.
- UI light/dark, auto-scroll cerdas, minimize-to-tray.
- Export WAV + MD + TXT + JSON (+ SRT/VTT opsional).
- Setup wizard otomatis (BlackHole/ffmpeg/model).
### Out of scope
- Cloud STT, telemetri, akun online.
- Diarization pyannote wajib (hanya optional).

## 6. User Story
- Sebagai peserta Zoom, saya ingin merekam lawan bicara + suara saya sendiri secara
  offline supaya rahasia tidak bocor ke cloud.
- Sebagai peserta webinar, saya ingin hanya merekam speaker tanpa mic supaya transkrip
  bersih.
- Sebagai peserta rapat offline, saya ingin mic merekam ruangan dan membedakan pembicara.
- Sebagai user awam, saya ingin setup otomatis tanpa install BlackHole/ffmpeg manual.

## 7. Kebutuhan Fungsional
- Capture mic + speaker secara simultan dan independen.
- Toggle MIC ON/OFF & SPEAKER ON/OFF saat live tanpa stop.
- 3 mode rapat dengan best-practice default toggle.
- whisper.cpp offline, pemilihan model via wizard.
- Code-switching ID↔EN dengan label bahasa per segment.
- Diarization per-source default + pyannote optional.
- Dual VAD filter noise sekitar.
- Echo-dedupe di mode Rapat Online.
- Export WAV/MD/TXT/JSON, nama file YYYYMMDD-[judul/UUID].

## 8. Kebutuhan Desktop Khusus
- Perilaku jendela: draggable, resizable, responsive, minimize-to-tray.
- Multi-window / single-window: single main window + tray.
- Offline support: penuh, tanpa koneksi.
- Penyimpanan lokal: file transkrip di disk lokal user.
- Update aplikasi: tidak ada auto-update (executable statis).
- Akses file sistem: baca/muat model, tulis export.
- Notifikasi desktop: opsional (indikator tray).
- Shortcut keyboard: tidak wajib di MVP.
- Responsivitas lintas resolusi: layout fleksibel (text area expand).

## 9. Kebutuhan Non-Fungsional
- Performa: transkrip near-realtime (lag <3s di large-v3-turbo + M-series).
- Keamanan: audio tidak keluar perangkat, tidak ada telemetri.
- Reliabilitas: auto-save chunk 10s, auto-reconnect device (mic/speaker, sleep-wake,
  cabut-pasang), crash-safe.
- Aksesibilitas: contrast cukup di light/dark.
- Kompatibilitas OS: macOS 11+, Windows 11.

## 9a. Fitur Tambahan (di luar MVP awal, kini bagian resmi produk)
- Remote control lokal via Unix socket (`util/remote_control.py`) untuk automasi/scripting
  internal — hanya listen di socket lokal, tidak membuka port jaringan.
- VU meter live untuk mic + speaker (indikator level audio real-time di UI).
- Singleton window / single-instance lock agar app tidak terbuka dobel.
- Update checker manual (cek rilis terbaru di GitHub Releases via tombol di Settings,
  membuka browser untuk download) — bukan auto-update diam-diam, tetap sesuai §8
  "tidak ada auto-update".

## 10. Edge Case
- Mic OFF tapi speaker ON → transkrip hanya lawan bicara.
- Zoom mute tapi app tetap rekam mic → user aware via indikator.
- Sleep/wake → device putus → auto-reconnect.
- BlackHole belum terinstall → wizard install otomatis.
- Code-switching cepat ID↔EN → label per segment.
- Disk penuh saat export → error handling.

## 11. Acceptance Criteria
- [ ] App jalan offline 100%, audio tidak ke network.
- [ ] Toggle mic/speaker runtime berfungsi tanpa stop.
- [ ] 3 mode mengatur default toggle sesuai best-practice.
- [ ] whisper.cpp transcribe ID+EN dengan label bahasa.
- [ ] Export WAV+MD+TXT+JSON dengan nama YYYYMMDD-[judul/UUID].
- [ ] Setup wizard install BlackHole/ffmpeg + download model otomatis.
- [ ] Minimize-to-tray menjaga transkrip jalan background.
- [ ] Light/dark mode + auto-scroll cerdas.
- [ ] Device mic/speaker terputus (sleep/wake, cabut kabel) otomatis reconnect tanpa
      restart aplikasi.
- [ ] Setup wizard Windows: ffmpeg + VB-Audio Cable terinstall otomatis via Chocolatey
      bila tersedia; instruksi manual jelas bila tidak.

## 12. Metrik Keberhasilan
- Akurasi WER < 10% (EN), < 15% (ID) di large-v3-turbo.
- Setup first-run < 5 menit termasuk download model.
- CPU < 30% di idle transkrip (M-series).

## 13. Risiko
- whisper.cpp di Intel lawas lambat → mitigasi model medium.
- BlackHole memerlukan izin macOS → wizard panduan.
- pyannote berat → optional, tidak default.

## 14. Open Questions
- Apakah detect judul rapat via AppleScript cukup reliable di macOS terbaru?
- Apakah translate offline NLLB layak di MVP atau ditunda?
