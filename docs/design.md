# Trareon Transcribe — Design Spec

> Desktop app untuk live transcribe microphone + speaker secara real-time, 100% offline,
> cross-platform (macOS + Windows), dengan fokus privasi dan best-practice rapat.

---

## 1. Overview

**Nama:** Trareon Transcribe
**Tujuan:** Aplikasi desktop yang merekam & mentranskrip secara live apa yang diucapkan
user (mic) dan apa yang keluar dari speaker laptop (system audio), dengan dukungan
bahasa Indonesia + Inggris, diarization opsional, dan jaminan 100% offline (data rahasia
tidak keluar dari perangkat).

**Platform:** macOS (Apple Silicon + Intel) & Windows 11
**Stack:** Python 3.11 + CustomTkinter (UI) + PyInstaller (build executable) +
whisper.cpp (STT offline) + pyannote (diarization opsional)

**Prinsip utama:**
- Audio tidak pernah dikirim ke cloud. Semua inferensi lokal.
- User belum install apa-apa → setup wizard memasang semua dependency otomatis.
- UI simpel, ringan, tidak mengganggu saat Zoom share screen.

---

## 2. Arsitektur

```
Trareon Transcribe
├── Setup Wizard (first run)
│   ├── Detect OS spec → suggest Whisper model
│   ├── Auto-install: BlackHole (mac) / VB-Audio (win), ffmpeg, whisper.cpp
│   └── Download model pilihan user + panduan HF token (optional)
├── Audio Engine
│   ├── Mic Stream (sounddevice / ffmpeg avfoundation / dshow)
│   ├── Speaker Stream (BlackHole loopback mac / WASAPI loopback win)
│   ├── Toggle mic/speaker independen (runtime, tanpa stop)
│   ├── Dual VAD (WebRTC + Silero) → filter noise sekitar
│   └── Echo-dedupe (mode Rapat Online)
├── STT Engine (whisper.cpp, offline, ggml)
│   ├── Model Whisper: tiny / base / small / medium / large-v3-turbo / large
│   ├── Language: auto (ID/EN detect per-segment; disimpan di JSON)
│   └── Caption UI: MIC/SPK + teks apa adanya (tanpa label bahasa)
├── Diarization (optional, pyannote)
│   ├── Default: per-source (MIC / SPEAKER)
│   └── Optional: Speaker 1..N (butuh HF token gratis)
├── UI (CustomTkinter)
│   ├── 3 Mode: Webinar / Rapat Online / Rapat Offline
│   ├── Toggle mic/speaker live + indikator
│   ├── Live caption (auto-scroll cerdas)
│   ├── Light/Dark mode toggle
│   ├── Minimize to tray (background transcribe)
│   ├── Resource monitor CPU/RAM
│   └── Diarization reminder + panduan
└── Export
    ├── WAV per-track (mic & speaker terpisah)
    ├── Markdown transkrip (speaker + timestamp)
    ├── TXT plain
    ├── JSON (timestamp, speaker, bahasa, confidence)
    └── Opsional: SRT / VTT
```

---

## 3. 3 Mode Rapat (best-practice toggle)

| Mode | Mic | Speaker | Catatan |
|---|---|---|---|
| **Webinar** | OFF | ON | User cuma mendengar, tidak bicara |
| **Rapat Online** (Zoom/Meet/Teams) | ON | ON + echo-dedupe | Suara user + lawan. Echo-dedupe cegah duplikasi |
| **Rapat Offline** (ruang fisik) | ON | OFF | Tidak ada system audio, hanya mic rekam ruangan |

User dapat override toggle mic/speaker secara manual kapan saja saat merekam.

---

## 4. Audio Engine — Detail

### 4.1 Dua stream independen
- **Mic Stream:** capture dari default input device (atau headset jika dipilih).
- **Speaker Stream:** macOS → BlackHole 2ch (virtual loopback); Windows → WASAPI loopback.
- Kedua stream berjalan paralel, masing-masing bisa di-mute/unmute saat runtime
  tanpa menghentikan app.

### 4.2 Toggle real-time
- Tombol `MIC ON/OFF` dan `SPEAKER ON/OFF` terpisah.
- Saat OFF → stream tidak dikirim ke transcriber (hemat resource).
- Indikator visual: `MIC: ON/OFF | SPEAKER: ON/OFF`.
- MIC OFF → indikator merah berkedip (tidak ganggu, tapi awareness).

### 4.3 Dual VAD (Voice Activity Detection)
- Kombinasi **WebRTC VAD** (gate cepat) + **Silero VAD** (akurasi tinggi).
- Tujuan: reduksi suara sekitar (orang di sebelah, AC, noise) masuk transkrip saat mic ON.
- Chunk yang terdeteksi silence → dibuang sebelum dikirim ke STT.

### 4.4 Echo-Dedupe (mode Rapat Online)
- Masalah: saat mic ON + speaker ON, suara user yang dikembalikan lawan bicara via
  speaker akan muncul 2x (di stream mic DAN stream speaker).
- Solusi: setelah transkrip, bandingkan teks MIC vs SPEAKER dalam window waktu sama,
  buang yang identik (dedupe di level teks).
- Hasil: transkrip bersih tanpa duplikasi suara user.

---

## 5. STT Engine — whisper.cpp (offline)

### 5.1 Model
- Engine: whisper.cpp (C++, native, efisien di CPU/Apple Neural Engine).
- Model ggml Whisper saja: `tiny` / `base` / `small` / `medium` /
  `large-v3-turbo` / `large` (saran otomatis dari RAM; Apple Silicon
  prefer turbo sebelum `large` penuh).
- First-run wizard detect spec laptop (RAM/CPU/Neural Engine) → sarankan model,
  tapi user tetap bisa pilih dari list + penjelasan tiap model.

### 5.2 Language & Code-Switching
- `language = auto` → deteksi bahasa **per-segment** (bukan per-call).
- Code-switching ID ↔ EN ↔ ID ditangani natural: tiap segment dideteksi ulang.
- UI menampilkan teks apa adanya dengan prefix sumber (`MIC` / `SPK`); field `language` tetap di JSON untuk debug.
- Tidak memaksa `id` atau `en` agar code-switching tidak rusak.

### 5.3 Live streaming behavior
- Audio di-chunk (~15-30 detik), lalu di-transcribe.
- Tiap chunk: **partial** (teks kasar saat diproses) → **final** (teks bersih
  menggantikan partial).
- Teks langsung append ke window secara real-time, selaras dengan pembicaraan.

---

## 6. Diarization

- **Default:** per-source label → `MIC` (kamu/ruangan) vs `SPEAKER` (system audio/lawan).
  Ringan, gratis, tanpa HF token.
- **Optional:** pyannote → `Speaker 1..N` dalam satu stream (cocok rapat offline
  banyak orang). Butuh HF token gratis + RAM +2-4 GB.
- UI menampilkan **pengingat + panduan**: kebutuhan HF token, RAM, cara mendapatkan,
  dan cara mengaktifkan di settings.

---

## 7. Failsafe

| Mekanisme | Fungsi |
|---|---|
| Echo-dedupe | Cegah duplikasi suara user di mode Rapat Online |
| Auto-save chunk 10 detik | Crash-safe: transkrip tersimpan berkala, bisa resume |
| Auto-reconnect device | Jika BlackHole/device putus (sleep/wake) → reconnect + notif |
| Auto-pause saat app inactive | Jika Zoom/Meet ditutup → transcribe pause otomatis (hemat resource) |
| Indikator MIC OFF | Awareness visual agar tidak lupa menyalakan mic |

> Catatan: auto-reminder 10 menit (mic off + speaker on) **dihapus** atas permintaan user.

---

## 8. UI / UX (best practice)

### 8.1 Tema
- **Default: Light Mode** + toggle **Dark Mode**.

### 8.2 Live caption — auto-scroll cerdas
- Jika posisi scroll di **paling bawah** → auto-scroll aktif (teks ikut ke bawah).
- Jika user **scroll ke atas** → auto-scroll OFF (tidak memaksa ke bawah, user bebas baca histori).
- Jika user **kembali ke bawah** → auto-scroll ON lagi.

### 8.3 Window behavior
- Solid (bukan translucent), compact, **draggable**, **resizable**, **responsive layout**
  (text area expand mengikuti ukuran window).
- **Minimize to tray**: app jalan di background, transkrip tetap jalan.
  Klik icon tray → balik ke window. Aman saat Zoom share screen (tinggal minimize).
- Always-on-top optional.

### 8.4 Resource monitor
- Tampilkan CPU/RAM di UI → tahu jika Mac panas/berat, bisa turunkan model.

### 8.5 Diarization reminder
- Di UI ada panel: "Diarization: per-source (MIC/SPK). Aktifkan pyannote? [Panduan]"
  dengan penjelasan kebutuhan HF token & RAM.

---

## 8.6 Wireframe UI

### 8.6.1 Main Window (Light Mode default)

```
╔════════════════════════════════════════════════════════════════════╗
║  Trareon Transcribe            [☀/🌙]    [ _ ][ □ ][ ✕ ]            ║
╠════════════════════════════════════════════════════════════════════╣
║  Mode rapat:                                                        ║
║   (•) Webinar   ( ) Rapat Online   ( ) Rapat Offline               ║
║                                                                     ║
║  ┌──────────────┐   ┌──────────────┐                                ║
║  │ MIC  [ ON  ] │   │ SPK [ ON  ]  │   ← toggle live terpisah      ║
║  └──────────────┘   └──────────────┘                                ║
║  ● REC 00:14:32        CPU 12%  RAM 1.8G                            ║
║                                                                     ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │ MIC  Ini projectnya, please review ya                       │  ║
║  │ SPK  Sure, I will check tomorrow                            │  ║
║  │ MIC  besok kita bahas di meeting                            │  ║
║  │ SPK  oke, kirim file-nya                                    │  ║
║  │ MIC  (scroll ke atas = auto-scroll OFF)                     │  ║
║  └─────────────────────────────────────────────────────────────┘  ║
║                                                                     ║
║  [ Stop ]   [ Export ]   [ Minimize to Tray ]                       ║
║                                                                     ║
║  ⓘ Diarization: per-source (MIC/SPK).                              ║
║    Aktifkan pyannote? [Panduan]  (butuh HF token gratis)            ║
╚════════════════════════════════════════════════════════════════════╝
```

### 8.6.2 Saat MIC OFF (indikator merah berkedip)

```
║  ┌──────────────┐   ┌──────────────┐                                ║
║  │ MIC  [ OFF ] │   │ SPK [ ON  ]  │                                ║
║  └──────────────┘   └──────────────┘                                ║
║  ⚠ MIC DIMATIKAN (klik untuk nyalakan)                              ║
```

### 8.6.3 Dark Mode

```
║▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒║
║▒ Trareon Transcribe        [☀/🌙]    [ _ ][ □ ][ ✕ ]            ▒░║
║▒══════════════════════════════════════════════════════════════════▒░║
║▒ Mode: ( ) Webinar  (•) Rapat Online  ( ) Rapat Offline         ▒░║
║▒ MIC [ ON ]   SPK [ ON ]                                        ▒░║
║▒ ● REC 00:14:32  CPU 12% RAM 1.8G                               ▒░║
║▒ ┌───────────────────────────────────────────────────────────┐ ▒░║
║▒ │ MIC  live caption di dark mode...                          │ ▒░║
║▒ └───────────────────────────────────────────────────────────┘ ▒░║
║▒ [ Stop ] [ Export ] [ Minimize to Tray ]                       ▒░║
╚▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒╝
```

### 8.6.4 Setup Wizard (first run)

```
╔════════════════════════════════════════════════════════════════════╗
║  Trareon Transcribe — Setup                                        ║
╠════════════════════════════════════════════════════════════════════╣
║  Spec terdeteksi: Apple M2, 16GB RAM, Apple M2 GPU                 ║
║  Saran model: large-v3-turbo                                       ║
║                                                                     ║
║  Pilih model Whisper:                                               ║
║   ( ) tiny / base / small / medium                                 ║
║   (•) large-v3-turbo   ( ) large                                   ║
║                                                                     ║
║  [x] Install BlackHole + ffmpeg (otomatis)                         ║
║  [ ] Aktifkan diarization pyannote (butuh HF token)                ║
║                                                                     ║
║  [ Mulai Setup ]                                                    ║
║  ↓ downloading whisper.cpp + model... 45%                           ║
╚════════════════════════════════════════════════════════════════════╝
```

### 8.6.5 Behavior notes
- Window **draggable** (drag title bar) & **resizable** (text area expand).
- **Minimize to Tray** → app di tray, transkrip jalan background, klik tray → balik.
- **Auto-scroll**: di bawah = ikut; scroll ke atas = berhenti; balik bawah = nyala lagi.
- **Light/Dark**: toggle ☀/🌙 di kanan atas, persist ke config.
- Saat Zoom share screen → cukup Minimize to Tray, tidak ada yang kelewat.

---

## 9. Setup Wizard (first run, otomatis)

Asumsi: user belum install apa-apa.

1. Detect spec → list model + penjelasan → user pilih.
2. macOS: install BlackHole via `brew install --cask blackhole-2ch`, ffmpeg via `brew install ffmpeg`.
3. Windows: install VB-Audio Virtual Cable, ffmpeg.
4. Download whisper.cpp binary + model ggml pilihan.
5. Panduan dapat HF token (opsional, untuk diarization).

Setelah setup, user tinggal double-click executable (tidak perlu install Python).

---

## 10. Export & Filename

### 10.1 Format
- **WAV** per-track (mic & speaker terpisah)
- **Markdown** transkrip (speaker label + timestamp)
- **TXT** plain
- **JSON** (timestamp, speaker, bahasa, confidence score)
- Opsional: **SRT / VTT** (subtitle dengan timestamp)

### 10.2 Naming
- Format: `YYYYMMDD-[judul-rapat-atau-UUID].ext`
- Detect judul dari window title aplikasi rapat:
  - macOS: AppleScript baca title Zoom/Meet aktif
  - Windows: win32gui baca title
- Fallback: UUID random jika tidak terdeteksi.
- User dapat **edit judul** di UI sebelum export.

---

## 11. Translate

Tidak di-bundle. Gunakan app translate eksternal jika perlu; caption tetap teks asli.

---

## 12. Privasi

- Audio tidak dikirim ke mana pun. Semua inferensi lokal.
- Mode default per-source (tanpa HF token) → user awam langsung jalan tanpa daftar akun.
- Tidak ada telemetri/analytics keluar.

---

## 13. Distribusi

- PyInstaller → `Trareon Transcribe.app` (Mac) / `Trareon Transcribe.exe` (Windows).
- User double-click → wizard jalan otomatis → tidak perlu install Python/dependency manual.
- Dapat dibagikan ke komputer lain dengan mudah.

---

## 14. Folder Structure (rekomendasi)

```
trareon-transcribe/
├── engine/
│   ├── audio_capture.py      # mic + speaker stream
│   ├── vad.py                # dual VAD (WebRTC + Silero)
│   ├── stt.py                # whisper.cpp wrapper
│   ├── diarization.py        # pyannote wrapper
│   └── dedupe.py             # echo-dedupe logic
├── ui/
│   ├── main_window.py        # CustomTkinter UI
│   ├── tray.py               # minimize to tray
│   └── theme.py              # light/dark mode
├── export/
│   ├── writer.py             # WAV/MD/TXT/JSON/SRT
│   └── naming.py             # YYYYMMDD + judul/UUID
├── setup/
│   ├── wizard.py             # first-run setup
│   ├── deps.py               # install BlackHole/ffmpeg
│   └── model_dl.py           # download whisper.cpp + model
├── README.md
└── requirements.txt
```

---

## 15. Build Instructions (README)

```bash
# macOS
brew install --cask blackhole-2ch
brew install ffmpeg
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
pyinstaller --onefile --windowed --name "Trareon Transcribe" ui/main_window.py

# Windows
# install VB-Audio Virtual Cable + ffmpeg
python -m venv venv && venv\Scripts\activate
pip install -r requirements.txt
pyinstaller --onefile --windowed --name "Trareon Transcribe" ui/main_window.py
```

---

## 16. Best-practice diadopsi dari repo GitHub lain

| Sumber | Best-practice | Diadopsi di Trareon |
|---|---|---|
| node-trans | Overlay always-on-top + Socket.IO chunking | Toggle live + chunk streaming |
| sososo | Diarization "you vs remote" | Per-source label MIC/SPK |
| lumiaspic/transcription | 2 track WAV terpisah + merged Markdown | Export WAV per-track + Markdown |
| TalkTrack | Per-app capture + auto-stop saat inactive | Auto-pause saat Zoom/Meet inactive |
| Audio-process | Dual VAD (WebRTC + Silero) + SpeakerTracker | Dual VAD filter noise sekitar |
| WhisperLive | VAD + save wav + translation thread | Save WAV (translate via app eksternal) |
| emidium-science | Floating overlay + resource monitor | Resource monitor CPU/RAM di UI |
| collabora/WhisperLive | VAD server + save wav mic | Save WAV mic + VAD |

---

## 17. Pertanyaan yang sudah disepakati

- ✅ Python + CustomTkinter + PyInstaller (D)
- ✅ 2 stream independen + toggle runtime
- ✅ 3 mode: Webinar / Rapat Online / Rapat Offline
- ✅ Diarization: per-source default + pyannote optional (Opsi A)
- ✅ whisper.cpp offline, auto language (JSON), caption tanpa label bahasa
- ✅ Dual VAD, echo-dedupe, failsafe
- ✅ Light mode default + dark toggle
- ✅ Auto-scroll cerdas (bawah = on, atas = off)
- ✅ Minimize to tray (bukan translucent)
- ✅ Export WAV + MD + TXT + JSON (+ SRT/VTT opsional)
- ✅ Filename YYYYMMDD-[judul/UUID], detect judul rapat
- ✅ Nama: Trareon Transcribe
- ✅ Auto-reminder 10 menit dihapus
- ✅ Setup wizard otomatis (user belum install apa-apa)
