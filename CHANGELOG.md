# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0-beta.1] — 2026-10-09

Rilis beta pertama yang dibagikan ke luar tim inti. Merangkum Sprint 1–7
(lihat `docs/SPRINT-REPORTS.md` untuk rincian per item, berkas, dan hasil
uji). Tidak ada breaking change pada format data sesi atau ekspor yang
sudah dirilis di `1.0.0` — sesi dan transkrip lama tetap bisa dibuka.

### Ditambahkan

- **Transkripsi live LocalAgreement-2**: pratinjau kata-demi-kata yang
  stabil (hipotesis "sementara" ditandai abu-abu, dikonfirmasi setelah
  beberapa chunk berikutnya sepakat) — `rust_core/src/streaming.rs`.
- **Tumpukan anti-halusinasi**: deteksi pengulangan, filter segmen energi
  rendah, dan penyaringan keluaran whisper yang tidak didukung audio.
- **Timestamp per kata + mode karaoke**: klik kata di transkrip untuk
  lompat ke waktu itu di pemutar.
- **Diarization neural opsional (sherpa-onnx)**: alternatif yang lebih
  akurat dari clustering akustik bawaan, diverifikasi di Linux (Windows/
  macOS belum diuji manual — lihat Batasan).
- **Pembelajaran kamus pribadi**: koreksi manual pengguna pada transkrip
  dipelajari dan diterapkan otomatis pada sesi berikutnya.
- **Mesin notulen rapat berbasis LLM lokal**: Ollama lokal atau endpoint
  kompatibel-OpenAI mana pun, map-reduce untuk rapat panjang, skema
  keluaran ketat, periksa-fakta otomatis terhadap transkrip sumber, 4
  templat (Lengkap/Ringkas/Risalah Resmi/Aksi), dan sekarang (Sprint 8)
  mode **poin catatan** (notulen tanpa audio), **preset panjang**
  (Ringkas/Sedang/Lengkap), **progres jujur** dengan tombol Coba lagi, dan
  **konteks dokumen lokal** (txt/md/pdf) sebagai masukan tambahan ke LLM.
- **Ekspor siap-SRIKANDI**: metadata arsip instansi pada ekspor DOCX/PDF.
- **Paket kepatuhan PDP**: pemetaan UU PDP 27/2022 dan ISO/IEC 27001/27701,
  diagram alur data, templat DPIA, prosedur retensi & penghapusan — lihat
  `docs/compliance/` (bukan sertifikasi, lihat janji privasi di README).
- **Sistem desain & kemasan rilis beta**: layar tanda tangan (setup wizard,
  onboarding), rasa native per platform, skrip packaging macOS (DMG) dan
  Windows (ZIP).
- **Benchmark & alat ASR Bahasa Indonesia**: pipeline data, baseline WER
  multi-model, kit pelatihan fine-tune (lihat Batasan — pelatihan
  sungguhan belum dijalankan).
- **Log audit PDP**: setiap ekspor dan pemakaian konteks dokumen dicatat
  secara lokal saat mode PDP aktif.

### Diperbaiki

- `chunks_exact` → `as_chunks` dan idiom lain yang disyaratkan clippy
  Rust 1.98 (CI) agar gerbang lokal dan CI sepakat.
- Kerentanan keamanan `lopdf` (lewat `pdf-extract`) dinaikkan ke versi
  aman; `cargo audit`/`cargo deny` hijau dengan satu pengecualian yang
  didokumentasikan (`ttf-parser` belum terawat, tidak ada upstream aman).
- Berbagai perbaikan gerbang CI (fixture bench notulen, tenggat uji
  performa transcript view, format Rust antar-versi toolchain).

### Batasan yang diketahui

- **Fine-tune model Bahasa Indonesia khusus**: skrip dan dokumen siap,
  konversi model dan pengukuran WER belum dijalankan (butuh GPU — lihat
  `docs/INDONESIAN-MODEL.md`).
- **Kit penyetelan halus mesin notulen**: NOT DONE — celah target sudah
  terukur, menunggu GPU dan korpus asli untuk dijalankan.
- **Pilot data risalah resmi (MK/DPR)**: 0 jam — kedua lembaga menolak
  akses otomatis; butuh permintaan resmi lewat PPID, menunggu keputusan
  pemilik produk.
- **Code-switching Indonesia–Inggris**: set uji masih sintetis, belum ada
  rekaman asli dengan consent.
- **Diarization neural (sherpa-onnx) dan rendering jendela Windows**:
  diverifikasi di Linux; verifikasi manual Windows/macOS belum diulang
  sejak Sprint 4b dan perlu dikonfirmasi ulang sebelum rilis stabil.
- **Progress notulen "≈N kata"**: kepatuhan panjang keluaran hanya bisa
  diverifikasi lawan LLM sungguhan (tidak ada mock-HTTP di `rust_core`);
  diuji sebatas "instruksi sampai ke prompt dengan angka benar".

## [1.0.0] — 2026-08-06

### Added
- First-launch onboarding screen: model download progress, zero-config setup (no model names exposed to user).
- Slide-up overlay toast system (replaces SnackBar), unified `EmptyState` widget, speaker avatars with initials.
- Pulsing animated record button, 3-row control bar, gradient VU meters (green → amber → red).
- Shared `formatTime` / `speakerColor` utilities (removed 4 duplicated implementations).
- Silero VAD (ONNX, 87.7% TPR vs WebRTC 50%) with graceful energy-VAD fallback on platforms without prebuilt ort.
- Confidence routing: hallucination discard + low-confidence segment flags.
- Initial-prompt injection: 200-char rolling context between chunks.
- Whisper config: large-v3-turbo default, `language=id`, `audio_ctx=1500`, beam search 5.
- Speaker diarization harness (pyannote v3.3) + LLM post-correction/summary harness (Qwen2.5-7B, MLX/llama.cpp/pass-through).
- Whisper-CD contrastive decoding harness.

### Fixed
- Settings dropdown crash when stored default model not in choices (default → `base`).
- Export atomic-write race: unique `.tmp` per format (7 formats now export reliably).
- Confidence routing now uses real per-segment signals (previously always accepted).
- Duplicate Privacy Report / Usage Dashboard screens — single source in `lib/screens/`.
- macOS packaging: APP_NAME matches PRODUCT_NAME "Trareon Transcribe"; Intel slice builds with `--no-default-features` (ort has no prebuilt for macOS x86_64).
- CI: flutter-action pinned to v2.23.0; invalid rust-cache inputs removed; benchmark installs libasound2-dev and runs `transcribe_cli`.
- Full test suite green: 55 Flutter tests + 102 Rust tests.

## [0.1.2] — 2026-07-28

### Fixed
- ToneTest step number 3→4 (UI title + wizard test name) to match actual 4-step wizard.
- README wizard step count: "3-step" → "4-step" (spec detect, model choice, audio setup, tone test).
- README Flutter badge version: "3.27+" → "3.32+" (matches Dart SDK ^3.12.2 constraint).
- README Tech Stack + Prerequisites Flutter version: same fix across all references.
- Minimum window height 560→700 so Settings Audio section fully visible without scroll.

## [0.1.1] — 2026-07-27

### Fixed
- Setup wizard test: update assertion for 4-step wizard flow.
- Clippy warnings in Rust code.
- CI clippy lint: unused import warning.

## [0.1.0] — 2026-07-26

### Fixed
- CI `flutter test` failure: `session_model_test` now creates a temp directory with
  a stub model file so `_sanitizeDefaultModel` resolves correctly on CI runners
  without pre-downloaded models.
- Fixed branch in CI badge URL (README.md).

### Added

- Repo scaffold, CI (cargo fmt/clippy/test/audit/deny + flutter
  analyze/test), Dependabot, SECURITY.md, performance benchmark scripts
- Rust engine core: audio device enumeration, ring buffer, dual-stage VAD
  (WebRTC + confirmation), whisper-rs STT engine + file/batch
  transcription, echo-dedupe, export (Markdown/TXT/JSON/SRT/VTT/HTML/
  DOCX/WAV), pure-Rust decode (Symphonia + rubato, no ffmpeg), model
  catalog with SHA256 verification and resumable download, in-memory
  session registry with auto-split (time + memory pressure), settings
  persistence, singleton instance lock, CLI mode (`transcribe-cli`),
  diarization (acoustic feature clustering for multi-speaker)
- Flutter UI: theme (light/dark/system), Riverpod state management, main
  screen (mode selector, mic/speaker toggles, VU meter, transcript view,
  pause/resume, stop confirmation), first-run setup wizard (5 steps with
  premium dark glassmorphism design), settings screen, library screen
  (search, soft-delete with undo, export dialog, file upload with drag &
  drop), transcript player (seek, speed control, inline editing), Privacy
  Report screen, usage dashboard, native share sheet, in-app keyboard
  shortcuts + visible shortcuts panel, minimize-to-tray, accessibility
  semantics across all widgets (WCAG 2.2 AA)
- flutter_rust_bridge wired end-to-end: `RustEngineBridge` is now the
  default bridge, calling real generated Dart bindings (`lib/src/rust/`)
  into the compiled Rust engine.
- Desktop build plumbing now builds and installs the Rust library on
  Linux, Windows, and macOS as part of the native desktop build flow.
- Resume download for models now appends partial files and is covered
  by a deterministic unit test.
- Transcript-player edits now notify listeners, and the session state
  exposes a shared transcript-edit update path.
- Auto-stop timer: configurable inactivity timeout stops recording after
  N minutes of silence (Settings → Auto-stop, default: disabled).
- Accessibility: WCAG 2.2 AA contrast ratios, keyboard focus traversal,
  Semantics labels on all widgets, minimum 24x24pt tap targets.
- Release workflow now builds macOS DMG (ad-hoc signed) and Windows ZIP
  (self-signed) on tag push. DISTRIBUTION.md documents Lynk.ID setup.
- Performance benchmark script (`scripts/benchmark.sh`) with CI gate
  thresholds for STT latency, export time, and VAD processing.
- STT priority queue: mic segments processed before speaker segments.
- Parallel export: each format runs in its own thread.
- Chunked file processing: large files transcoded in 30s chunks.

### Known gaps
- Live audio capture still needs real hardware validation, especially
  end-to-end on a machine with the target microphones/speakers.
- No notarization (macOS); SmartScreen warning (Windows) — see DISTRIBUTION.md
- No auto-update (manual check only in v1)
- Lynk.ID product page not yet live (DISTRIBUTION.md has the checklist)
