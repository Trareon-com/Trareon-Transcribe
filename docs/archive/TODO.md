# TODO — Trareon Transcribe Development Roadmap

> Status: Aktif. Clone kerja: `/home/kali/workspace/transcribe`
> Blueprint: `~/Trareon-Transcribe-Docs/TRAREON-TRANSCRIBE-BLUEPRINT.md`
> Skill: `flutter-rust-desktop-master`, `flutter-rust-architecture`, `flutter-rust-desktop`

---

## Batch 1: Engine Inti (Zero Friction)

- - File: `rust_core/src/decode/`
 - Verify: `cargo test` + decode fixture MP3/M4A tanpa ffmpeg
 - [x] **Symphonia + Rubato decoding** — Full pure-Rust audio decode (MP3/M4A/OGG/FLAC) → PCM 16kHz. ✓ `src/decode/mod.rs` + 4 test hijau.
   - File: `rust_core/src/decode/`
   - Verify: `cargo test` decode + resample test hijau
- [ ] **SSE Codec (FRB v2)** — Aktifkan `#[frb(serialize)]` untuk transfer buffer audio 30 detik tanpa latency.
  - Verify: benchmark buffer transfer Rust→Dart
- [ ] **Dual Capture Probe** — WASAPI loopback (Windows) + CoreAudio Process Taps (macOS 14.4+) + PipeWire (Linux) tanpa intervensi user.
  - Existing: `rust_core/src/bin/dual_capture_probe.rs`
- [ ] **Watchdog reconnect** — Auto-reconnect device <5s setelah sleep/wake.
  - Existing: `rust_core/src/watchdog.rs` (sudah ada, verifikasi)
+ - [x]**Watchdog reconnect** — ✓ `watchdog.rs` auto-reconnect, pure `evaluate_health` + 5 reconnect-transition test hijau.
- [x]**Privacy proof** — ✓ `privacy.rs` compile-time scan (forbidden: reqwest/http/tokio::net), 126 lib tests green.

## Batch 2: Hybrid Progressive Transcription (HPT) ⭐

**Konsep:** Base dulu (latency <1s, UI responsif), lalu large-v3-turbo-q5 refine (ganti teks, akurasi maksimal). Target: teks muncul 3-5 detik setelah suara, tapi akurasi setara Q5.

- File: `rust_core/src/pipeline.rs`, `rust_core/src/stt/`
- Verify: test update-by-id di Dart state
- [x] **Dual-Context Model Loader** — ✓ `model.rs` (dual WhisperEngine), RAM ~700MB.
- [x] **Priority Inference Queue** — ✓ `LivePipelineHpt::ingest` (base → q5).
- [x] **UUID Segment Tracking** — ✓ merge-by-key `(source, timestamp)` di `pipeline.rs` + Dart update-by-ID (`session_model.dart`).
- [x] **UI Refinement Indicator** — ✓ `CircularProgressIndicator` pada `isPartial` rows (`transcript_view.dart:474`).
- [x] **Hallucination Guard** — ✓ `filter_loops` n-gram di kedua pass (`pipeline.rs:334-335`).
- [x] **Echo-Dedupe Sync** — ✓ per-source pipeline, cross-source dedupe di level Dart (`pipeline.rs:203-204`).

## Batch 3: UI & UX Polish

- [~]**4-step Setup Wizard** — Sebagian ada (`setup_wizard_screen.dart`), belum sempurna.
- [~]**Interactive Transcript** — Sebagian ada, belum RichText search/highlight.
+ - [~]**4-step Setup Wizard** — `setup_wizard_screen.dart` + test file. Butuh verifikasi flow lengkap.
+ - [~]**Interactive Transcript** — Ada (RichText search/highlight ✓), auto-scroll ✓, 48 test green.
- [ ] **OBS-style Side-panel Settings** — belum.
+ - [x]**Smart Auto-scroll** — ✓ `transcript_view.dart` auto-scroll (bottom anchor), widget test (`transcript_view_test.dart`) verify render + search filter, 48 flutter test green.

## Batch 4: Model & Accuracy

+ - [x]**2-Model Bundle Default** — ✓ `KNOWN_MODELS` base+q5 `is_bundled=true`, test `default_bundle_includes_base_and_q5`.
+ - [x]**Hallucination Filter** — ✓ `progressive.rs:filter_loops`.
- [x]**Per-segment ID/EN detection** — ✓ `stt/mod.rs:149-174` `segment_language` + EN/ID keyword hit-ratio.
- [x]**Model ID Sync Check** — ✓ `model.rs` ↔ `models.dart` model ID sync.

## Batch 5: Distribusi & Hygiene

- [ ] **Portable ZIP** — belum.
- [ ]**AppImage Linux** — Belum.
+ - [x]**AppImage Linux** — ✓ `transcribe.AppImage` (15MB, static-pie ELF x86_64). Path: `/home/kali/workspace/transcribe/transcribe.AppImage`.
- [x]**Portable ZIP** — ✓ `transcribe-linux-portable.zip` (14MB, AppImage + README + LICENSE). Path: `/home/kali/workspace/transcribe/transcribe-linux-portable.zip`.
- [x]**Privacy Report** — ✓ `privacy_report_screen.dart` + `privacy_proof_test.dart` (3 proof tests: no network primitives, downloadModel guarded, counter zero-call).
- [x]**Repo Cleanup** — ✓ artifact `--output/`, `--help/` dibersihkan.
- [x]**CI Fix** — ✓ `.github/workflows/ci.yml` cargo fmt+clippy (115 test hijau).

---

## Prioritas Eksekusi

1. **B2 HPT dual-model loader** — jantung nilai produk
2. **B1 Symphonia** — fondasi zero-friction
3. **B4 accuracy** — kualitas hasil
4. **B3 UI** — polish
5. **B5 distribusi** — pengiriman

## Acceptance Criteria HPT

- [x]**Acceptance Criteria** — 115/115 rust ✅, 0 network-call design ✅ (local whisper), 115/115 hijau.
