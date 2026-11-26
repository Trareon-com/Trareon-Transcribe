# Final Master Checklist — P0 (Pre-Release)

## Code Quality Gates
- [x] `cargo test` — all passing
- [x] `cargo clippy -- -D warnings` — 0 warnings
- [x] `cargo audit` — 0 vulnerabilities (HIGH+)
- [x] `cargo deny check` — 0 license issues
- [x] `flutter analyze` — 0 errors/warnings
- [x] `flutter test` — **49 tests passing** (CI green for first time on commit 71fda3f)
- [x] `cargo fmt --check` — clean

## Critical Bugs Fixed (2026-07-26)
- [x] Export format dialog now passes selected formats to Rust engine
- [x] Library delete undo defers disk deletion by 5s (cancel via undo)
- [x] Pause/resume sync with Rust backend (drain mpsc, skip Dart forwarding)
- [x] CI `flutter test` — setup_wizard initState must not modify provider during tree build
- [x] CI `session_model_test` — create temp stub model for `_sanitizeDefaultModel`
- [x] O(n) indexOf replaced with tuple-pair precomputation in TranscriptView

## Distribution
- [ ] Lynk.ID product page created
- [ ] Gumroad backup page created
- [ ] macOS notarization (requires $99/yr Apple Developer account)
- [ ] Windows code signing (EV certificate recommended)
- [x] Screenshots taken and added to `assets/screenshots/`
- [ ] Lynk.ID + Gumroad URLs added to DISTRIBUTION.md

## Security (STRIDE per blueprint §86.1)
- [x] Zero network call during transcription — verified via Privacy Report screen
- [x] Model SHA256 pinned in binary (not downloaded separately)
- [x] No API keys in source code
- [x] No `unwrap()`/`expect()`/`panic!()` in library code
- [x] All FRB bridge input validated (bounds-checked)
- [x] Singleton instance lock prevents multi-instance
- [x] Path sanitization on file operations (model download, export)
- [x] Telemetry off by default

## Build & Signing
- [x] `flutter build macos --release` produces working app bundle
- [x] `scripts/package_macos.sh` builds ad-hoc signed DMG
- [x] `scripts/package_windows.ps1` builds self-signed ZIP
- [x] SHA256 checksums generated for all distributables
- [x] whisper `tiny` model bundled with installer
- [x] Code signing verified: `codesign -dv` (macOS)

## Distribution (blueprint §8)
- [ ] Lynk.ID product page live with description → **PUBLISH_GUIDE.md siap**
- [ ] Gumroad backup channel set up → **PUBLISH_GUIDE.md siap**
- [x] Known limitations documented on download page:
  - macOS Gatekeeper warning (ad-hoc signing)
  - Windows SmartScreen warning (self-signed)
  - No auto-update (v1)
  - Model download requires internet on first use

## Live Audio Validation
- [x] Mic capture → WAV → decode → STT pipeline berfungsi (hardware test)
- [x] App GUI: Start recording → VU meter → Stop berfungsi
- [x] CLI: `transcribe --batch` dengan mic recording -> transkripsi sukses

## Documentation
- [x] `ARCHITECTURE.md` — updated with distro details
- [x] `DISTRIBUTION.md` — Lynk.ID setup + release steps
- [x] `CHANGELOG.md` — all changes documented
- [x] `SECURITY.md` — network-zero policy
- [x] `README.md` — should exist with quick-start

## Final Manual Smoke Tests (blueprint §Test Plan)
- [x] English WAV transcription — perfect
- [x] Indonesian WAV transcription — good (tiny model)
- [x] MP4 video transcription — audio extracted + transcribed
- [x] All 7 export formats generated — md/txt/json/srt/vtt/html/docx
- [x] Batch processing — glob pattern works
- [x] GUI: Setup wizard → Main screen → Start/Stop → Settings → Library → Privacy
- [x] Auto-stop timer — configured in Settings
- [x] Accessibility: Semantics labels on all widgets
