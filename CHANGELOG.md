# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

Sprint 13 brief asked the team to study two MIT-licensed peer projects
(Meetily, Anarlog — see `THIRD_PARTY_LICENSES.md`) for patterns worth
adopting: an audio limiter, acoustic echo cancellation, VAD masking,
cross-meeting semantic search, and a recording-consent reminder. See
`docs/SPRINT-REPORTS.md` Sprint 13 report for the full per-item audit,
including what was deliberately **not** done and why.

### Ditambahkan

- **Soft-knee limiter pada AGC** (`rust_core/src/agc.rs::soft_limit`):
  gain yang diterapkan `apply_gain` sekarang dibatasi secara lembut
  (tanh di atas -3 dBFS) alih-alih hard clamp, jadi transien keras tidak
  terdistorsi kasar.
- **Peringatan kualitas mikrofon** (`MicQualityBanner`,
  `rust_core/src/audio/device.rs::mic_quality_advisory`): sebelum/saat
  sesi, chip mikrofon menampilkan info non-blocking kalau perangkat aktif
  punya sample rate maksimum < 16 kHz atau namanya menunjukkan Bluetooth
  (`bluez`, pola MAC address) — "disarankan headset wired untuk rapat
  penting".
- **Pengingat persetujuan perekaman** (`ConsentReminderBanner`,
  `AppSettings.consentBannerDismissed`): banner "Pastikan semua peserta
  tahu rapat ini direkam" di layar idle, dengan "Jangan tampilkan lagi"
  yang bertahan lintas sesi; penanda audit per-sesi
  (`rust_api.acknowledgeConsent` → `pdp::acknowledge_consent`) tercatat
  independen dari status banner.
- **Audio sistem dibuka ulang otomatis setelah perangkat tersambung
  kembali** (`rust_core/src/session.rs::reopen_speaker_capture`): sesi
  sekarang menjalankan device watchdog, dan event `DeviceReconnected`
  (TWS ganti profil A2DP↔HFP, sleep/wake) memicu pembukaan ulang capture
  loopback mengikuti sink default yang baru — sebelumnya stream lama yang
  sudah mati terus "merekam" senyap tanpa error terlihat.

### Diperbaiki

- **Toast error mentah saat mulai rekam** (`lib/screens/main_screen.dart`):
  panggilan audit `acknowledgeConsent` bisa melempar secara sinkron
  (bridge belum siap) sebelum sempat mengembalikan `Future`, jadi
  `.catchError` tidak pernah terpasang dan galatnya lolos sebagai toast
  teknis mentah di atas sesi yang sedang berjalan — sekarang dibungkus
  `try`/`catch` yang sebenarnya dan hanya dicatat ke log.
- **`DeviceGroup` ringkas (strip rekaman) melempar `BoxConstraints`
  infinite width** (`lib/widgets/session_controls.dart`): menambahkan
  `MicQualityBanner` membuat mode ringkas mengembalikan `Column`
  (`crossAxisAlignment: stretch`) alih-alih `Wrap` telanjang; ditempatkan
  di dalam `Row` tak terbatas (strip rekaman), `Column` yang stretch itu
  mencoba memberi `Wrap` lebar tak hingga dan merusak seluruh layar
  rekaman. Dibungkus `IntrinsicWidth`.

Sprint 14b brief asked for two things: the no-audio-detected banner turned
into a self-dismissing toast instead of a persistent one, and a visible
progress indicator for every operation that can run longer than 3 seconds.
See `docs/SPRINT-REPORTS.md` Sprint 14b report for the full per-item audit,
including the table of every long-running operation and whether it has a
real indicator.

### Ditambahkan

- **Toast peringatan audio tidak lagi menetap** (`lib/state/audio_watchdog_model.dart`,
  `lib/screens/main_screen.dart`): peringatan "Belum ada suara terdeteksi" /
  izin mikrofon-audio-sistem sekarang `ToastType.warning` dengan auto-dismiss
  (8 detik generik, 12 detik untuk kasus izin dengan tombol aksi) alih-alih
  `ToastType.error` yang menetap selamanya. Kondisi yang sama tidak tampil
  ulang dalam 60 detik (`_emit`'s cooldown); tombol tutup (x) sekarang selalu
  ada walau toast punya tombol aksi (`lib/widgets/app_toast.dart`).
- **Penanda permanen di bar status** (`AudioHealthIndicator`,
  `lib/widgets/capture_health_view.dart`): ikon mikrofon dengan titik kuning
  muncul di sebelah lencana konfirmasi rekaman selama kondisi audio belum
  teratasi, independen dari toast yang sudah auto-dismiss
  (`audioHealthIndicatorProvider`).
- **Komponen progres bersama** (`TaskProgressTile` + `ProgressGate`,
  `lib/widgets/ui/task_progress_tile.dart`, baru): satu tile determinate
  (persen + ETA) / indeterminate (spinner + tahap) dipakai bersama oleh
  semua fitur progres latar belakang, dengan status jelas
  (queued/running/done/failed/cancelled) dan tombol batal. `ProgressGate`
  menyembunyikan indikator sampai aktif selama >= 3 detik, supaya operasi
  cepat tidak berkedip.
- **Progres nyata untuk "Memperhalus transkrip" (F5)**
  (`lib/state/enhance_queue_model.dart`): pass akurat sekarang memantau
  `batchProgress()` (slot yang sama dipakai impor berkas) dan melaporkan
  tahap (Menyiapkan model → Mentranskripsi → Menggabungkan → Selesai) dan
  persentase nyata — sebelumnya teks statis "Memakai model akurat…" tanpa
  angka, persis keluhan Master di screenshot sesi 49 menit / 189 segmen.
  Kartu sidebar (`EnhanceQueueView`) sekarang memakai `TaskProgressTile`.
- **Lencana "Ditranskrip ulang" menampilkan tahap** (`lib/widgets/session_sidebar.dart`):
  badge di daftar sesi sekarang menampilkan tahap + persen job yang sedang
  berjalan untuk sesi itu, bukan hanya label statis.
- **Antrean segmen "Memperbaiki…" lebih bermakna** (`lib/widgets/transcript_view.dart`):
  hanya segmen partial paling awal yang menampilkan spinner "Diproses…";
  segmen partial lain menampilkan "Antre" tanpa spinner — puluhan spinner
  identik tanpa konteks diganti satu penanda yang berarti. Jumlah total
  segmen yang sedang diperbaiki ditampilkan di toolbar transkrip
  ("N sedang diperbaiki").

### Celah yang diketahui (lihat tabel audit di SPRINT-REPORTS.md)

- Komponen progres bersama (`TaskProgressTile`/`ProgressGate`) belum dipakai
  di dialog ekspor, pemindaian pemulihan sesi saat start, atau pengindeksan
  arsip (F12) — ketiganya masih indeterminate murni tanpa ambang 3 detik.
- Tidak ada jalur progres tunggal dari Rust ke Dart yang dipakai *semua*
  operasi (brief butir 10.3): setiap fitur (unduh model, batch file,
  completion pass, ringkasan) masih memantau slot progres Rust-nya sendiri-
  sendiri. Menyatukan ini jadi satu stream FRB adalah migrasi lebih besar
  yang tidak sempat diselesaikan di sprint ini.
- Pemuatan/inisialisasi model Whisper dan mulai/stop sesi langsung masih
  memakai label generik "Memulai…"/"Menyimpan…" tanpa tahap rinci atau
  ambang 3 detik.

Sprint 14a brief asked for model defaults driven by real benchmark data
instead of two independently-drifting heuristics (a Dart RAM-only
`if ramMb >= 8192 { turbo } else { base }`, duplicated nowhere in Rust),
honest accuracy labels sourced from the FLEURS-id baseline, a pre-ASR
level boost for quiet speech, and a per-session language choice instead
of one global language locked to Indonesian. Audit found the live/refine
speed trade-off (adaptive HPT, `pipeline::route_for_rtf`) already
device-aware and left untouched; the actual gap was the model
*recommendation* itself having no single source of truth. See
`docs/SPRINT-REPORTS.md` Sprint 14a report for the full per-item audit,
what changed, and what is explicitly not done yet.

### Ditambahkan

- **Rekomendasi model satu sumber kebenaran** (`rust_core/src/model_select.rs`,
  baru): `recommend_default_model(ram_mb)` memilih model teliti berdasarkan
  katalog `model::KNOWN_MODELS` (ruang RAM, bukan angka RAM tebakan),
  dipakai baik oleh wizard maupun oleh tawaran "Tingkatkan akurasi" di
  Pengaturan — menggantikan heuristik Dart yang terpisah
  (`setup_wizard_screen.dart`, dihapus).
- **Label akurasi jujur** (item 5): `model_select::accuracy_label`
  menampilkan WER FLEURS-id nyata (mis. "WER FLEURS-id: 8,1%") di kartu
  pilihan model wizard dan di Pengaturan — sebelumnya repo ini sengaja
  tidak menampilkan angka apa pun karena belum ada pengukuran; sekarang
  ada.
- **Tier "Sedang" (`small`)** ditambahkan ke `kKnownModelIds` dan ke kartu
  pilihan model wizard — sebelumnya hanya `base`/`large-v3-turbo-q5` yang
  bisa dipilih meski katalog sudah punya tingkat tengah.
- **Tawaran "Tingkatkan akurasi"** (item 6) di Pengaturan → Model & Mode:
  muncul hanya ketika rekomendasi Rust tidak sama dengan model tersimpan
  dan model itu sudah terunduh; menekan "Nanti saja" menyimpan
  `default_model_upgrade_dismissed` agar tidak ditanya ulang setiap sesi.
  Model tidak pernah berubah tanpa ketukan eksplisit.
- **Impor berkas selalu diperhalus dengan model paling teliti yang
  terpasang** (item 4, `lib/widgets/file_upload_zone.dart`,
  `shouldRefineImport`): sebelumnya jalur impor mewarisi sakelar
  "Cepat dulu, lalu diperhalus" yang hanya masuk akal untuk rekaman
  langsung — mematikannya untuk mempercepat sesi langsung diam-diam juga
  membuat setiap impor berkas berhenti di model cepat saja, padahal impor
  tidak punya tenggat waktu nyata.
- **Penguatan level pra-VAD/ASR** (item 9, `rust_core/src/agc.rs`, baru):
  ucapan pelan (antara ambang senyap -60 dBFS dan target -30 dBFS)
  diperkuat maksimum 20 dB sebelum masuk ke WebRTC VAD maupun Whisper,
  pada jalur rekaman langsung (`pipeline.rs`, dua varian) dan impor berkas
  (`stt/file.rs`). Audio yang sudah cukup keras atau yang sudah di bawah
  ambang senyap tidak disentuh.
- **Bahasa per sesi, bukan terkunci secara global** (item 11): default
  `AppSettings.language` di Rust berubah dari `Some("id")` paksa menjadi
  `None` ("ikut mode sesi") — `lib/state/models.dart` punya fungsi baru
  `effectiveSessionLanguage` yang memilih Indonesia untuk Rapat Offline
  dan Otomatis (deteksi per segmen) untuk Rapat Online/Webinar ketika
  tidak ada pilihan bahasa eksplisit. Instalasi lama yang sudah menyimpan
  `"id"` secara eksplisit di `settings.json` tidak terpengaruh.
- **Pemilih bahasa per sesi di UI** (item 11, menu "Opsi sesi"):
  Otomatis/Indonesia/Inggris, berlaku untuk rapat ini saja — tidak
  mengubah default Pengaturan untuk rapat berikutnya. Dialirkan lewat
  field baru `SessionConfig.language` (Rust dan Dart; FRB diregenerasi)
  yang menang di atas default global/per-mode saat diisi
  (`session::resolve_session_language`).
- **Tawaran "Ganti ke Otomatis"** (item 11, `LanguageMismatchBanner`):
  muncul di atas transkrip langsung ketika bahasa sesi dipaksa tapi lebih
  dari 30% dari 10 segmen terakhir terdeteksi bahasa lain (field
  `TranscriptSegment.language` yang sudah ada per segmen, bukan heuristik
  kata kunci baru) — `shouldOfferAutoLanguage` di `lib/state/models.dart`.
  Diuji dengan fixture ID/EN campuran di `test/session_language_test.dart`.

### Diperbaiki

- Sakelar "Cepat dulu, lalu diperhalus" tidak lagi memengaruhi hasil
  impor berkas — hanya sesi rekaman langsung.
- **Bug ditemukan saat review sendiri (item 11):** `session.rs`
  (`start_session_with_id`) membaca `AppSettings.language` mentah-mentah,
  bukan lewat `effectiveSessionLanguage` — field itu hanya ada di sisi
  Dart dan cuma dipakai untuk metadata sesi (judul/"Transkrip Ulang"),
  tidak pernah dikirim ke mesin transkripsi langsung. Akibatnya, mengubah
  default `AppSettings.language` dari `Some("id")` menjadi `None` nyaris
  diam-diam juga membuat Rapat Offline (yang brief mewajibkan tetap
  Indonesia) jatuh ke deteksi otomatis di sesi rekaman langsung — regresi
  akurasi untuk mode paling umum, bukan perbaikan item 11 yang dimaksud.
  Fix: `session.rs` sekarang punya `effective_session_language(global,
  mode)` sendiri (cermin dari `effectiveSessionLanguage` Dart, dengan
  catatan lintas-bahasa supaya tetap sinkron) dan dipakai saat start
  sesi, bukan nilai settings mentah. Diverifikasi dengan 3 test baru di
  `session.rs` (`offline_with_no_override_still_forces_indonesian`, dll).

Sprint 11 brief asked for F17 (noise reduction, proven not just toggled),
F9 (bookmarks during recording/playback), and F5 (automatic background
re-transcription with a more accurate model). Audit found F17 and F9
already fully shipped and unchanged since Sprint 4b — RNNoise wiring with
real RMS-reduction tests, and bookmarks with a hotkey, a jump list, session
persistence, and a "Poin Penting" section in every export format. The gap
was F5's own default: the background pass existed but ran silently
on-by-default with no visible setting, no audit trail, and no message when
the accurate model was missing. See `docs/SPRINT-REPORTS.md` Sprint 11
report for the full per-item audit.

### Ditambahkan

- **"Perhalus otomatis dengan model lebih akurat di latar belakang"**
  (F5): sakelar baru di Pengaturan → Model & Mode, **mati secara default**
  — `lib/screens/settings_screen.dart`, `lib/state/enhance_queue_model.dart`
  (`shouldAutoEnhance` sekarang mewajibkan opt-in eksplisit, bukan heuristik
  diam-diam).
- Pass F5 yang berhasil kini tercatat di log audit mode PDP
  (`AuditAction::TranscriptEnhanced` — `rust_core/src/pdp/audit.rs`), dan
  sakelar memberi pesan Bahasa Indonesia yang jelas saat model akurat belum
  terpasang, bukan membiarkan pass-nya gagal diam-diam.

### Diperbaiki

- `rust_core/src/export/mod.rs`: tambah tes `bookmarks_appear_as_poin_penting_in_markdown_and_txt`
  — sebelumnya hanya fungsi pemformat (`poin_penting_from_bookmarks`) yang
  diuji, bukan keluaran berkas Markdown/TXT itu sendiri.
- `rust_core/src/api.rs`: tambah tes
  `saving_settings_actually_flips_the_denoise_switch` yang membuktikan
  toggle "Pengurangan derau (RNNoise)" benar-benar menyalakan
  `denoise::set_enabled` lewat `apply_engine_settings`, bukan hanya
  menyimpan nilai di `AppSettings`.

Sprint 12 fixed a live-path gap where the VAD gate failed open ("assume
speech") whenever no Silero model was installed, closing it with an
unconditional peak/RMS backstop (`rust_core/src/silence_gate.rs`) that
runs regardless of which VAD model is or isn't present. Also fixed: a
real timestamp bug where every live-chunk segment landed one overlap
length early (3.0s reported for speech that actually started at 6.0s),
a `low_confidence` threshold that was 0.5 in three independent places
instead of the 0.70 it should have been, missing Malay-spelled
hallucination phrases and whole-word decoder loops, a macOS menu bar
with no application menu (no About/Services/Hide/Quit), and a mic/system
-audio permission-missing banner that took up to a minute to appear.
Measured end to end with the release `transcribe_cli`: a 300s fixture
(2x15s real speech, rest digital silence) now produces exactly the two
expected speech groups and zero hallucinated lines; a 30s -45dBFS noise
clip produces zero segments; real speech is unaffected. See
`docs/SPRINT-REPORTS.md` Sprint 12 report for the full per-item audit,
before/after numbers, and the PERLU VERIFIKASI DI MAC list (build/signing
and GPU-backend fixes could not be verified without real Apple Silicon
hardware).

### Diperbaiki

- **Anti-halusinasi, jalur live**: gerbang senyap pra-ASR (`silence_gate.rs`)
  yang tidak bergantung pada model VAD manapun; ambang `low_confidence`
  disatukan ke 0,70 (sebelumnya 0,5 di tiga tempat independen); frasa
  halusinasi Melayu dan deteksi loop kata utuh ditambahkan; rasio
  kompresi gzip benar-benar dipakai di pipeline (sebelumnya hanya
  dideklarasikan, tidak pernah dipanggil).
- **Timestamp suara-sistem**: segmen pada sesi Webinar/dual-pass tidak
  lagi mendarat satu detik lebih awal per chunk.
- **macOS**: menu aplikasi standar (About, Pengaturan ⌘,, Services,
  Hide/Quit) sekarang ada; dialog "Berhenti merekam?" dapat dioperasikan
  penuh dari keyboard (Enter/Esc/Tab); deteksi izin mikrofon/audio sistem
  yang belum diberikan sekarang tampil dalam 3 detik (sebelumnya hingga
  1 menit) dengan tombol langsung ke Pengaturan Sistem; perbaikan
  strip/signing dylib Rust (belum diverifikasi di hardware Mac nyata).

Sprint 10 brief asked for structured action items, a follow-up checklist
UI, and `.ics`/CSV export. Audit at the start of the sprint found all
three already shipped in Sprint 4 (F6: `rust_core/src/actions.rs`,
`lib/widgets/action_items_panel.dart`, `test/action_items_test.dart`) and
unchanged since. This sprint re-verified the implementation against the
brief's specifics (never inventing a missing owner/deadline, CRLF +
unique UIDs in the `.ics`, checklist state surviving a close/reopen) and
added the gap it found: no manual-QA checklist entry for the feature in
`docs/RELEASE-BETA.md`. See `docs/SPRINT-REPORTS.md` Sprint 10 report for
the full per-item audit.

### Diperbaiki

- `docs/RELEASE-BETA.md`: tambah bagian manual QA "4b. Tindak Lanjut —
  checklist, .ics, .csv" yang sebelumnya tidak ada walau fitur sudah
  dirilis sejak Sprint 4.

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
