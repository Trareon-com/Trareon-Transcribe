# Trareon Transcribe V2 — Blueprint

> **Versi:** 2.0 — 27 Juli 2026
> **Versi Kode:** 0.1.0
> **Stack:** Flutter 3.27+ (Dart) + Rust 1.80+ via flutter_rust_bridge V2
> **Target:** macOS (Apple Silicon + Intel), Windows 11, Linux (AppImage)

## Daftar Isi

1. [Ringkasan Produk](#1-ringkasan-produk)
2. [Arsitektur](#2-arsitektur)
3. [Rust Engine](#3-rust-engine)
4. [Flutter UI](#4-flutter-ui)
5. [Model STT](#5-model-stt)
6. [Dual Audio Capture](#6-dual-audio-capture)
7. [Export](#7-export)
8. [CI/CD](#8-cicd)
9. [Distribusi](#9-distribusi)
10. [Testing](#10-testing)
11. [Status Sekarang](#11-status-sekarang)
12. [Roadmap V1](#12-roadmap-v1)

---

## 1. Ringkasan Produk

Trareon Transcribe adalah aplikasi transkripsi meeting 100% offline. Rekam mikrofon dan speaker secara simultan, transkrip otomatis lewat whisper.cpp, tanpa cloud, tanpa telemetri.

**USP:**
- 100% offline — tidak ada data audio keluar
- Dual capture mic + speaker tanpa setup driver
- 7 format export (termasuk DOCX dan SRT)
- Bilingual ID/EN — semua label Bahasa Indonesia

**Tech stack:**

| Layer | Teknologi |
|-------|-----------|
| UI | Flutter 3.27+, Riverpod, Material 3 |
| Engine | Rust 1.80+, whisper-rs 0.14, cpal 0.15 |
| Bridge | flutter_rust_bridge V2 (FRB codegen) |
| Audio decode | Symphonia 0.5 + rubato 0.15 (pure Rust) |
| Model | whisper.cpp GGUF — base (bundled) + large-v3-turbo (download) |

---

## 2. Arsitektur

### 2.1 Layout

```
lib/                          Flutter UI
  screens/                    main_screen, setup_wizard, library, settings,
                              transcript_player, privacy_report, usage_dashboard
  widgets/                    vu_meter, transcript_view, mode_selector,
                              stream_toggle, file_upload_zone, shortcuts_panel, resource_hud
  state/                      Riverpod — session_model, audio_stream_model,
                              batch_upload_model, settings_model, models (Dart mirrors)
  services/                   bridge_service (RustEngineBridge + mock),
                              rust_library_loader, tray_service,
                              global_hotkey_service, update_checker
  src/rust/                   FRB auto-generated Dart bindings
  theme/                      app_colors, app_theme

rust_core/                    Rust engine
  src/
    api.rs                    FRB entry point — semua fungsi publik
    audio/                    capture, device, loopback, ring_buffer
    vad/                      DualVAD (WebRTC gate + confirmation)
    stt/                      whisper-rs wrapper, file/batch transkripsi
    dedupe/                   Echo dedupe (MIC vs SPK similarity)
    export/                   Markdown, TXT, JSON, SRT, VTT, HTML, DOCX, WAV
    decode/                   Symphonia + rubato (no ffmpeg)
    model.rs                  Model catalog, SHA256, resumable download
    session.rs                Session registry, auto-split, crash recovery
    pipeline.rs               Live PCM pipeline per source
    diarization.rs            Acoustic feature clustering
    settings.rs               Persistence
    memory.rs                 Memory pressure detection
    singleton.rs              PID lock
    platform/                 Window title detection
    bin/                      trascribe, gen_fixtures, device_probe,
                              dual_capture_probe, poll_probe
```

### 2.2 Data Flow

```
User klik Start
  → Dart: sessionProvider.start()
  → bridge: RustBridge.startSession(config)
  → Rust: session::start_session()
      → AudioCapture (cpal, 2 thread: mic + speaker)
      → Ring buffer (30s, overlap 10s)
      → DualVAD (WebRTC gate → konfirmasi)
      → whisper-rs infer chunk
      → Diarization (speaker clustering)
      → Echo dedupe (cross-source, di session.rs)
      → SessionEvent queue
  → Dart: poll_session_events (100ms)
  → Riverpod: transcriptProvider, vuMeterProvider
  → UI render
```

### 2.3 Bridge Status

FRB codegen sudah terverifikasi end-to-end. Real `.dylib`/`.so`/`.dll` terkoneksi. Dua fix yang sudah diterapkan:

1. `TrareonTranscribeResult<T>` tidak bisa di-resolve FRB — setiap fungsi publik harus `Result<T, TrareonTranscribeError>`
2. `TrareonTranscribeError::Io` pake `String` bukan `std::io::Error` (tidak ada FFI codec untuk `std::io::Error`)

---

## 3. Rust Engine

### 3.1 Modul

| Modul | Fungsi | Tergantung pada |
|-------|--------|-----------------|
| `audio/` | Enumerasi device, ring buffer, SessionConfig | cpal |
| `vad/` | DualVAD — WebRTC gate + confirmation | webrtc-vad |
| `stt/` | whisper-rs wrapper — live chunk + file batch | whisper-rs |
| `dedupe/` | Echo dedupe (cosine similarity MIC vs SPK) | strsim |
| `export/` | 7 format writer, parallel thread per format | docx-rs |
| `decode/` | File decode + resample (Symphonia + rubato) | symphonia, rubato |
| `session.rs` | Registry, auto-split per jam, crash recovery | uuid, chrono |
| `pipeline.rs` | Live PCM pipeline — VAD → STT → diarization | — |
| `model.rs` | Catalog 5 model, SHA256 verify, resume download | reqwest, sha2 |
| `diarization.rs` | Speaker clustering (pitch, energy, ZCR) | — |
| `memory.rs` | Memory pressure watchdog | — |
| `singleton.rs` | PID lock — cegah multi-instance | — |

### 3.2 API Surface (via FRB ke Dart)

```rust
// Device
pub fn list_audio_devices() -> Result<Vec<AudioDeviceInfo>, TrareonTranscribeError>
pub fn get_loopback_device(name_hint: String) -> Result<AudioDeviceInfo, TrareonTranscribeError>

// Session
pub fn start_session(config: SessionConfig) -> Result<String, TrareonTranscribeError>
pub fn stop_session(session_id: String) -> Result<(), TrareonTranscribeError>
pub fn toggle_mic/speaker(session_id, enabled) -> Result<(), TrareonTranscribeError>
pub fn set_session_mode(session_id, mode: SessionMode) -> Result<(), TrareonTranscribeError>
pub fn get_session_status(session_id) -> Result<SessionStatus, TrareonTranscribeError>
pub fn poll_session_events(session_id) -> Result<Vec<SessionEvent>, TrareonTranscribeError>

// Recovery
pub fn list_recoverable_sessions() -> Result<Vec<SessionRecoverySnapshot>, TrareonTranscribeError>
pub fn recover_session(snapshot) -> Result<String, TrareonTranscribeError>

// Model
pub fn list_available_models(models_dir: String) -> Vec<ModelInfo>
pub fn is_model_downloaded(models_dir, model_id) -> bool
pub async fn download_model(models_dir, model_id) -> Result<(), TrareonTranscribeError>

// Export
pub fn export_session(segments, formats, output_dir, title)
    -> Result<Vec<ExportedFile>, TrareonTranscribeError>

// File transcribe
pub fn transcribe_file(path, model_path) -> Result<Vec<Segment>, TrareonTranscribeError>
```

### 3.3 Session Auto-Split

Sesi panjang (>4 jam) di-split otomatis per jam:

| Trigger | Mekanisme |
|---------|-----------|
| Time boundary | Setiap 3600 detik |
| Memory pressure | Jika RSS > threshold, split paksa |
| Recovery | Snapshot disimpan sebelum split → bisa dipulihkan setelah restart |

---

## 4. Flutter UI

### 4.1 Screen & Route

| Route | Screen | Fungsi |
|-------|--------|--------|
| `/` | MainScreen | Transkripsi live + upload file |
| `/wizard` | SetupWizardScreen | 5-step first-run config |
| `/library` | LibraryScreen | Riwayat sesi, search, export |
| `/settings` | SettingsScreen | Theme, model, export defaults |
| `/player/:id` | TranscriptPlayerScreen | Playback + edit transkrip |
| `/privacy` | PrivacyReportScreen | Audit network calls |
| `/usage` | UsageDashboardScreen | Statistik penggunaan |

### 4.2 State Management (Riverpod)

| Provider | Type | Fungsi |
|----------|------|--------|
| `sessionProvider` | StateNotifier | Session lifecycle + segments |
| `settingsProvider` | StateNotifier | AppSettings persist |
| `firstRunCompleteProvider` | StateProvider | Wizard selesai flag |
| `rustBridgeProvider` | Provider | Bridge instance |

### 4.3 Theme

**Palette teal-green:**

| Token | Light | Dark |
|-------|-------|------|
| Primary | `#00796B` | `#4DB6AC` |
| Background | `#F5F5F5` | `#1A1A2E` |
| Surface | `#FFFFFF` | `#16213E` |
| Header | `#FFFFFF` | dark |
| Recording dot | `#FF3B30` | `#FF453A` |
| Success | `#2E7D32` | `#30D158` |

Support light/dark/system. Material 3. Default light.

### 4.4 Indonesian Labels

Semua label UI Bahasa Indonesia:

| English | Indonesia |
|---------|-----------|
| Library | Perpustakaan |
| Export | Ekspor |
| Mic | Mikrofon |
| ON | HIDUP |
| OFF | MATI |
| Settings | Pengaturan |
| Save | Simpan |
| Cancel | Batal |
| Stop | Berhenti |
| Start | Mulai |

### 4.5 Setup Wizard

5 steps — dipertahankan, konten disederhanakan:

1. Selamat Datang
2. Pilih Mode Cepat/Akurat
3. Deteksi Perangkat
4. Download Model (progress bar)
5. Selesai

---

## 5. Model STT

### 5.1 2-Model Strategy

| Model | Mode | Ukuran | RAM | Bundle | Digunakan untuk |
|-------|------|:------:|:---:|:------:|-----------------|
| **base** (Q5_0) | Live capture | 150MB | ~500MB | ✅ Bundled | Real-time streaming |
| **large-v3-turbo** (Q5_0) | File upload | 548MB | ~2GB | ❌ Download | Akurasi tinggi |

**Perubahan dari v1 blueprint:**
- Sebelumnya: tiny (77MB) + large-v3-turbo-q5
- Sekarang: **base (150MB)** + large-v3-turbo (Q5_0)
- Alasan: base memberikan akurasi lebih baik untuk ID tanpa delay signifikan
- Quantisasi: Q5_0 (bukan Q4_K_M yang sempat dicoba)

### 5.2 Model Catalog (KNOWN_MODELS)

| ID | File | RAM | Bundled | SHA256 |
|----|------|:---:|:-------:|--------|
| tiny | ggml-tiny.bin | 1GB | ✅ | be07e048... |
| base | ggml-base.bin | 1GB | ❌ (opsional) | 60ed5bc3... |
| small | ggml-small.bin | 2GB | ❌ | 1be3a9b2... |
| medium | ggml-medium.bin | 4GB | ❌ | 6c14d5ad... |
| large-v3-turbo | ggml-large-v3-turbo.bin | 6GB | ❌ | 1fc70f77... |

**Catatan:** Meski catalog punya 5 model, UI hanya menawarkan 2: **base** dan **large-v3-turbo**.

### 5.3 Download

- Resumable — partial file append
- SHA256 verification sebelum dipakai
- URL: HuggingFace ggerganov/whisper.cpp mirror
- Progress: Via stream ke Dart (belum terintegrasi penuh)

### 5.4 Model Path Resolution (Dart)

Urutan pencarian model:
1. Library path dari settings
2. macOS: `~/Library/Caches/TrareonTranscribe/models/`
3. Windows: `%LOCALAPPDATA%\TrareonTranscribe\models\`
4. Bundled resources path
5. Dev tree paths

---

## 6. Dual Audio Capture

### 6.1 Platform Support

| Platform | Mic | Speaker (Loopback) | Setup |
|----------|:---:|:-------------------:|:------:|
| **macOS** | ✅ cpal | ✅ screencapturekit crate | Zero |
| **Windows** | ✅ cpal | ✅ WASAPI loopback | Zero |
| **Linux** | ✅ cpal | ✅ PulseAudio (parec/ffmpeg) | Zero |

Auto-detect device — tidak perlu konfigurasi manual.

### 6.2 Mode (SessionMode)

| Mode | Mic | Speaker | Echo Dedupe |
|------|:---:|:-------:|:-----------:|
| Webinar | ❌ | ✅ | ❌ |
| Online | ✅ | ✅ | ✅ |
| Offline | ✅ | ❌ | ❌ |

### 6.3 VAD Strategy

Dual-stage:

1. **WebRTC VAD** — gate cepat, false positive tinggi
2. **Konfirmasi** — jika WebRTC deteksi speech, proses chunk

Hemat ~90% inferensi karena hanya chunk dengan speech yang diproses.

### 6.4 Echo Dedupe

Cross-source (session.rs): setelah MIC dan SPK segments terkumpul, bandingkan cosine similarity. Jika mirip → skip duplicate.

---

## 7. Export

### 7.1 Format

| Format | Ekstensi | Konten | Parallel |
|--------|:--------:|--------|:--------:|
| Markdown | `.md` | Label speaker + timestamp + teks | ✅ |
| TXT | `.txt` | Plain text | ✅ |
| JSON | `.json` | Full metadata segments array | ✅ |
| SRT | `.srt` | Subtitle format | ✅ |
| VTT | `.vtt` | Web subtitle | ✅ |
| HTML | `.html` | Rich HTML dengan styling | ✅ |
| DOCX | `.docx` | Word document (docx-rs) | ✅ |
| WAV | `.wav` | Per-track mic.wav + speaker.wav | ✅ |

**Parallel export:** Setiap format jalan di thread sendiri (thread::spawn). Tidak blocking satu sama lain.

### 7.2 Naming Convention

`YYYYMMDD-judul-session/` — subfolder per sesi.

### 7.3 Segment Struct

```rust
pub struct Segment {
    pub source: String,      // "MIC" / "SPK"
    pub speaker: String,     // "Pembicara 1 (MIC)"
    pub text: String,
    pub timestamp: f64,
    pub duration: f64,
    pub language: String,
    pub confidence: f32,
    pub is_partial: bool,
}
```

---

## 8. CI/CD

### 8.1 GitHub Actions — CI

| Job | Runner | Steps |
|-----|--------|-------|
| **rust** | ubuntu-latest | fmt, clippy, test, audit, deny |
| **flutter** | ubuntu-latest | analyze, test |
| **rust-build** | matrix (3 OS) | cargo build --release --lib |
| **flutter-build** | matrix (3 OS) | flutter build --release |
| **macos-packaging** | macos-latest | package_macos.sh → DMG |
| **windows-packaging** | windows-latest | package_windows.ps1 → ZIP |
| **benchmark** | ubuntu-latest | scripts/benchmark.sh |

### 8.2 Release Workflow

Tag `v*` memicu:
1. Source tarball ke GitHub Releases
2. macOS DMG (ad-hoc signed)
3. Windows ZIP (self-signed)

### 8.3 Dependabot

Aktif untuk Rust + GitHub Actions.

---

## 9. Distribusi

### 9.1 Channel

| Channel | Harga | Untuk |
|---------|:-----:|-------|
| Lynk.ID | $5 | Indonesia (primary) |
| Gumroad | $5 | International (backup) |
| GitHub | Gratis | Source code (MIT) |

### 9.2 Build Artifact

| Platform | Format | Signing | Warning |
|----------|:------:|:-------:|:--------|
| macOS | `.dmg` | Ad-hoc | "Apple tidak dapat memverifikasi" |
| Windows | `.zip` | Self-signed | SmartScreen |
| Linux | `.AppImage` | None | — |

**Paket bundel:** Rust engine + Flutter binary + model base (150MB).

### 9.3 Skip V1

- Apple Developer $99/thn — tidak
- Notarization — tidak
- Auto-update — tidak (manual download)

---

## 10. Testing

### 10.1 Test Pyramid

```
         Manual smoke test (hardware asli)
    ┌──────────────────────────────────┐
    │       Integration test           │  — framework ready
   ┌┴──────────────────────────────────┴┐
   │      Flutter widget test           │  — mock RustLibApi
  ┌┴────────────────────────────────────┴┐
  │         Rust unit test              │  — 110/110 passing
  └──────────────────────────────────────┘
```

### 10.2 Status

| Layer | Status | Jumlah |
|-------|:------:|:-------|
| Rust unit test | ✅ Passing | ~110 |
| Rust clippy | ✅ Clean | 0 warnings |
| Rust fmt | ✅ Clean | — |
| Rust audit | ✅ Clean | 0 high vulns |
| Rust deny | ✅ Clean | — |
| Flutter test | ✅ Passing | 13+ |
| Flutter analyze | ✅ Clean | 0 errors |
| Integration test | 🟡 Framework ready | 1 file |
| E2E hardware test | 🔴 Perlu hardware asli | — |

### 10.3 Hardware Test Checklist

- [ ] Mic capture → WAV → decode → STT
- [ ] Speaker loopback (macOS screencapturekit)
- [ ] Speaker loopback (Windows WASAPI)
- [ ] Speaker loopback (Linux PulseAudio)
- [ ] Dual stream: mic ON + speaker ON
- [ ] Toggle mic/speaker runtime
- [ ] File upload .mp3 → transcribe
- [ ] Export 7 format → file valid
- [ ] Sleep/wake → watchdog reconnect

---

## 11. Status Sekarang

### 11.1 ✅ Sudah Jadi

| Area | Detail |
|------|--------|
| Rust engine | 19 modul — audio, VAD, STT, export, decode, model, session, pipeline, diarization, dll |
| FRB bridge | Codegen terverifikasi, end-to-end connected |
| Flutter UI | 7 screens + 7 widgets + theme teal-green + Riverpod state |
| CI | Rust + Flutter + build matrix (3 OS) + packaging smoke test |
| Dual capture | macOS screencapturekit, Windows WASAPI, Linux PulseAudio |
| Export | 7 format parallel |
| Model | base (bundled) + large-v3-turbo (download) |
| Session | Auto-split, crash recovery, watchdog |
| Singleton | PID lock |
| Diarization | Acoustic feature clustering (pitch, energy, ZCR) |
| 110 Rust test | Semua passing |
| 13+ Flutter test | Semua passing |

### 11.2 ❌ Gap

| Gap | Prioritas | Catatan |
|-----|:---------:|---------|
| Live audio hardware test | P0 | Belum divalidasi di hardware asli |
| Naming "Trareon Transcribe" masih di pubspec & kode | P0 | `pubspec.yaml` masih `name: trascribe` |
| Lynk.ID page | P1 | DISTRIBUTION.md sudah ada checklist |
| Linux AppImage build | P1 | Script belum dibuat |
| Auto-update | P2 | Manual download |
| large-v3-turbo download progress di UI | P1 | Rust sudah support, Flutter belum |
| WCAG keyboard shortcuts | P2 | Kode sudah ada, perlu test |
| Sleep/wake watchdog | P1 | Kode watchdog sudah ada, belum di-test |

### 11.3 Naming Issues

File yang masih pake "Trareon Transcribe":

| File | Yang perlu diubah |
|------|-------------------|
| `pubspec.yaml` | `name: trascribe`, `description` |
| `README.md` | Header, badges |
| `DISTRIBUTION.md` | Judul halaman |
| `PUBLISH_GUIDE.md` | Produk name |
| `lib/main.dart` | Class `TrareonTranscribeApp`, string |
| `Cargo.toml` | `name = "rust_core"`, `description` |
| `AGENTS.md` | Header |

---

## 12. Roadmap V1

### 12.1 P0 — Sebelum Rilis

| Task | Effort | File |
|------|:------:|------|
| Rename "Trareon Transcribe" ke "Trareon Transcribe" | 1 jam | pubspec.yaml, README, main.dart |
| Live audio hardware test (macOS + Windows) | 4 jam | Manual |
| Export 7 format — validasi file output | 1 jam | Manual |
| Model download progress di UI | 4 jam | Flutter screen |
| Lynk.ID page live | 2 jam | DISTRIBUTION.md |

### 12.2 P1 — Sebelum Rilis (Nice)

| Task | Effort | File |
|------|:------:|------|
| Linux AppImage build script | 2 jam | scripts/package_linux.sh |
| Benchmark ID latency base vs large-v3-turbo | 2 jam | scripts/benchmark.sh |
| Sleep/wake watchdog test | 2 jam | audio/capture.rs |
| Setup wizard simplified (5 step → 4 step) | 2 jam | setup_wizard_screen.dart |

### 12.3 P2 — Post V1

| Task | Catatan |
|------|---------|
| Auto-update | Sparkle (macOS), WinSparkle (Windows) |
| Notarization | Butuh Apple Developer $99/thn |
| In-app keyboard shortcuts | Kode sudah ada, test |
| Mobile support (iOS/Android) | Fase 2 |
| Mobile Maestro E2E test | Fase 2 |

### 12.4 Agent Assignments

| Agent | Area |
|-------|------|
| **Agent A (Rust)** | Rust engine — audio, VAD, STT, model, session |
| **Agent B (Flutter UI)** | Screens, widgets, theme, Riverpod |
| **Agent C (Bridge)** | FRB codegen, services integration |
| **Agent D (Docs/CI)** | README, CI, packaging, distribusi |
