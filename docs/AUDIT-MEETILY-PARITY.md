# Audit — Trareon Transcribe vs Meetily parity

> Branch: `feat/meetily-parity` · Audit date: 2026-09-30
> Method: every user-facing flow traced UI → Riverpod state → `bridge_service.dart`
> → FRB generated bindings → `rust_core`. Status is one of
> **WORKING** / **BROKEN** (wired but wrong) / **STUB** (code exists, does nothing
> real) / **MISSING** (no implementation at all).

---

## 1. Live recording (mic + system audio → VAD → Whisper → UI)

| Leg | Status | Evidence |
|-----|:------:|----------|
| UI → state | WORKING | `main_screen.dart:130` `_toggleStartBerhenti` → `session_model.dart:189` `start()` |
| state → bridge | WORKING | `session_model.dart:210` → `bridge_service.dart:313` `startSession` |
| bridge → FRB → Rust | WORKING | `rust_api.startSession` → `api.rs:72` → `session.rs:140` |
| Mic capture (cpal) | WORKING | `session.rs:171` → `audio/capture.rs` |
| Speaker loopback — macOS | WORKING | ScreenCaptureKit, BlackHole + ffmpeg fallbacks (`audio/loopback.rs`) |
| Speaker loopback — Windows | WORKING | WASAPI `AUDCLNT_STREAMFLAGS_LOOPBACK` |
| **Speaker loopback — Linux** | **BROKEN** | see A-1 |
| VAD gate | WORKING | `pipeline.rs:477` `DualVad::is_speech` per 10 ms frame |
| **VAD on/off setting** | **BROKEN** | see A-2 |
| Whisper inference | WORKING | `pipeline.rs:498` / HPT `pipeline.rs:587` |
| Diarization labels | WORKING (live only) | `pipeline.rs:506` `Diarizer::identify_speaker` |
| Echo dedupe (cross-source) | WORKING | `session.rs:556` `accept_or_drop_echo` |
| Event queue → Dart | WORKING | `poll_session_events` polled every 200 ms, `bridge_service.dart:369` |
| Transcript in UI | WORKING | `session_model.dart:105` merge-by-key, `transcript_view.dart` |
| Auto-save on stop | WORKING | `session_model.dart:297` exports md/txt/json into library path |
| **Session title auto-detect** | **STUB** | see A-3 |

### A-1 — Linux system-audio capture records the microphone, not the speakers · BROKEN

`rust_core/src/audio/loopback.rs`, `linux::run_linux_loopback`:

```rust
Command::new("ffmpeg").args(["-f", "pulse", "-i", "default", ...])
// fallback
Command::new("parec").args(["--rate=16000", "--channels=1", "--format=float32le"])
```

`-i default` and bare `parec` both open the **default PulseAudio/PipeWire
*source***, which is the microphone. System audio requires the default
*sink*'s monitor source (`<sink>.monitor`). Consequences on Linux:

* "Webinar" mode (speaker-only) transcribes the mic.
* "Rapat Online" mode captures the mic on both channels; echo-dedupe then
  silently drops roughly half the segments, so the transcript looks thinned
  out rather than duplicated — failing invisibly.
* `device_hint` is accepted and then discarded (`_device_hint`), so the
  speaker device picked in the setup wizard has no effect.

### A-2 — `vadEnabled`, `sampleRate`, `chunkDurationSecs` are dead-end config · BROKEN

`SessionConfig` carries all three from Dart (`bridge_service.dart:545`) into
`rust_core/src/audio/mod.rs:73-75`, and **nothing ever reads them**.
`pipeline.rs:442` / `:544` hardcode `DualVad::new(VadConfig::default())`.
The "VAD (deteksi suara)" switch in Settings is therefore inert.

### A-3 — `detectFrontmostWindowTitle` always returns `''` · STUB (benign)

`bridge_service.dart:457` returns `''` unconditionally (deliberately removed
for privacy, documented in-place). `session_model.dart:203` still awaits it
and branches on the result — a dead-end call, harmless but misleading.

---

## 2. Import audio file → transcription → saved session

| Leg | Status | Evidence |
|-----|:------:|----------|
| File picker + drag/drop | WORKING | `file_upload_zone.dart:24` — wav/mp3/m4a/aac/ogg/flac/opus/mp4/mov/mkv |
| Queue state | WORKING | `batch_upload_model.dart` |
| Decode (no ffmpeg) | WORKING | Symphonia + rubato, `decode/mod.rs` |
| Transcription | WORKING | `api.rs:288` `transcribe_files_batch` → `stt/file.rs` |
| Export to library | WORKING | `batch_upload_model.dart:110` |
| Source audio copied next to transcript | WORKING | `batch_upload_model.dart:133` |
| **Speaker labels in file mode** | **MISSING** | `stt/file.rs` never calls `Diarizer`; every segment is `source="file"` |
| **HPT (progressive) for files** | **STUB — dead FRB surface** | see A-4 |
| **Re-transcribe / "Enhance"** | **MISSING** | no code path anywhere |
| Progress reporting | BROKEN (coarse) | `transcribe_files_batch` takes an `on_progress` closure but the FRB wrapper (`api.rs:306`) only collects finished results — per-file progress never reaches Dart, so a 1-hour file shows a spinner with no movement |

### A-4 — `progressive_transcribe_file` is exposed but never called

`api.rs:224` implements full dual-pass file HPT and it is FRB-generated into
`lib/src/rust/api.dart:166`. No Dart code calls it. File import always uses the
single `defaultModel`, so the "Progressive Mode" setting does nothing for
imports.

---

## 3. Model download / selection / bundled models

| Leg | Status | Evidence |
|-----|:------:|----------|
| Catalog (6 entries, pinned SHA256) | WORKING | `model.rs:34` `KNOWN_MODELS` |
| Resumable download + checksum | WORKING | `model.rs` `download_with_resume`, `verify_checksum` |
| Download progress → UI | WORKING | `api.rs:158` `get_download_progress`, polled in `bridge_service.dart:460` |
| First-run onboarding download | WORKING | `onboarding_model.dart` + `main.dart:108` |
| Quality toggle (Cepat/Akurat) | WORKING | `main_screen.dart:839`, downloads on demand |
| Settings dropdown | WORKING | `settings_side_panel.dart:150`, clamped to `kKnownModelIds` |
| **`large-v3-turbo` (unquantized)** | BLOCKED by design | pinned hash exists but `KNOWN_MODELS` marks it non-bundled and the UI only offers `base` + `large-v3-turbo-q5` (`models.dart:29`) |
| **Indonesian-specialised model** | MISSING | no `cahya/whisper-medium-id` entry; no ggml conversion published upstream, so this stays out of scope |
| **Setup wizard** | **DEAD CODE** | `SetupWizardScreen` is referenced only by `test/setup_wizard_test.dart`; `main.dart` routes to `OnboardingScreen` instead. The blueprint's `/wizard` route does not exist. |

---

## 4. Session persistence + library

| Feature | Status | Evidence |
|---------|:------:|----------|
| Persist on stop | WORKING | `session_model.dart:297` writes `<libraryPath>/YYYYMMDD-<title>/<title>.{md,txt,json}` |
| List | WORKING | `library_screen.dart:53` `_loadFromDisk` scans subdirectories for the first `*.json` |
| Open (player + editor) | WORKING | `transcript_player_screen.dart`; edits persisted back to the JSON (`:110`) |
| Delete (with undo) | WORKING | `library_screen.dart:140`, 5 s soft-delete |
| Export from library | WORKING | `library_screen.dart:173` → `export_dialog.dart` |
| **Search** | **BROKEN (title only)** | `library_screen.dart:137` `s.title.toLowerCase().contains(q)` — transcript text is loaded into memory but never searched |
| **Rename** | **MISSING** | no rename affordance in `library_screen.dart` or `session_card.dart` |
| **Title shows the date prefix** | cosmetic | title is the raw directory name, e.g. `20260930-Rapat Tim` |
| **No session metadata file** | design gap | there is no per-session sidecar, so anything not expressible as a segment array (summary, model used, language, duration) has nowhere to live |

---

## 5. AI summary

**Status: MISSING end-to-end.**

* `rust_core/src/llm_correction.rs` is **dead code**: nothing in the crate calls
  `correct_and_summarize` (verified by grep across `rust_core/src`). It is not
  in `api.rs`, so it is not FRB-exposed and cannot be reached from Dart at all.
* With the default feature set (`llm` off) it is additionally a **pass-through
  stub** returning `summary: String::new()`.
* With `--features llm` it shells out to `python3 scripts/qwen_correction.py`
  with a relative path — resolvable only when the CWD happens to be the repo
  root, never in a packaged app.
* No Ollama support, no OpenAI-compatible endpoint support, no templates, no
  summary editor, no storage of a summary with the session.
* `docs/`, `SECURITY.md` and `privacy.rs` currently assume the *only*
  legitimate network call is model download.

---

## 6. Speaker diarization

| Piece | Status |
|-------|:------:|
| `Diarizer` acoustic clustering (pitch proxy, RMS, ZCR) | **REAL** — `diarization.rs:44`, 3 unit tests |
| Wired into live pipeline | WORKING — `pipeline.rs:506`, `:594`, `:597` |
| Wired into file transcription | **MISSING** — `stt/file.rs` never touches it |
| `run_rust_diarization()` | **STUB** — `diarization.rs:225` returns `Vec::new()`, zero call sites |
| `pyannote` backend | feature-gated, off by default, requires Python + model |
| Labels shown | `Pembicara N (MIC)` / `Pembicara N (SPK)` — renameable in the UI (`transcript_view.dart`) |

Caveat: clustering keys on a Euclidean distance over three weakly-scaled
features with a fixed `0.22` threshold. It reliably separates mic vs speaker
(they are separate cluster pools by construction) but multi-speaker accuracy
within one channel is best-effort.

---

## 7. Export

| Format | Status |
|--------|:------:|
| Markdown / TXT / JSON / SRT / VTT / HTML / DOCX | WORKING — `export/mod.rs`, one thread per format |
| Per-track WAV (`mic.wav` / `speaker.wav`) | WORKING — `api.rs:179` |
| Atomic writes, filename sanitisation, date-prefixed folder | WORKING |
| **Markdown with summary** | MISSING (no summary exists) |
| PDF | MISSING |

---

## 8. Settings, wizard, tray, hotkeys, crash recovery

| Feature | Status | Evidence |
|---------|:------:|----------|
| Rust-side settings JSON | WORKING | `settings.rs`, OS config dir |
| Theme / model / mode / language / library path / GPU | WORKING | round-trips through `bridge_service.dart:584` |
| **`autoStopMinutes` persistence** | **BROKEN** | `_fromRustSettings` hardcodes `autoStopMinutes: null` (`bridge_service.dart:599`); it is never written to `DartPrefs` either, so the setting resets every launch |
| **`progressiveEnabled` persistence** | **BROKEN** | written to `DartPrefs` (`settings_model.dart:95`) but **never read back**; `_load` takes it from `loaded.progressiveEnabled`, which is the Dart default `true` |
| **`defaultExportFormat` / `hptMode` / device ids** | WORKING | via `DartPrefs` |
| Setup wizard | DEAD CODE | see §3 |
| Tray (minimise-to-tray, quit) | WORKING | `tray_service.dart` |
| In-app shortcuts (Cmd/Ctrl+R/P/L/,//) | WORKING | `main_screen.dart:216` |
| **Global hotkeys** | **macOS only** | `global_hotkey_service.dart` listens on a `MethodChannel`; only the macOS `AppDelegate` publishes to it — a silent no-op on Linux and Windows |
| Crash recovery (snapshot + banner) | WORKING | `session.rs` `*.inprogress` snapshots, `main_screen.dart:264` |
| `resume_pending_transcriptions` | DEAD FRB SURFACE | `api.rs:32`, no Dart caller |
| Preflight checks | WORKING | `setup_overlay.dart` |
| Flight recorder | DEAD FRB SURFACE | `api.rs:335-381`, 8 functions, no Dart caller |

---

## Summary of defects, by priority

| # | Defect | Kind | Flow |
|---|--------|------|------|
| A-1 | Linux loopback captures the mic instead of the monitor source | BROKEN | 1 |
| A-2 | `vadEnabled` / `sampleRate` / `chunkDurationSecs` never read by Rust | BROKEN | 1, 8 |
| A-5 | Library search matches titles only | BROKEN | 4 |
| A-6 | No rename in library | MISSING | 4 |
| A-7 | `autoStopMinutes` + `progressiveEnabled` don't persist | BROKEN | 8 |
| A-8 | No speaker labels for imported files | MISSING | 2, 6 |
| A-9 | AI summary absent end-to-end; `llm_correction.rs` dead | MISSING | 5 |
| A-10 | No re-transcribe / "Enhance" | MISSING | 2 |
| A-11 | No per-session metadata sidecar (blocks summary, enhance, rename) | MISSING | 4, 5 |
| A-4 | `progressive_transcribe_file` never called | dead-end | 2 |
| A-3 | `detectFrontmostWindowTitle` dead-end | dead-end | 1 |
| A-12 | `run_rust_diarization` returns empty, zero call sites | STUB | 6 |
| A-13 | `SetupWizardScreen` unreachable from the app | dead code | 3, 8 |
| A-14 | Global hotkeys are macOS-only | partial | 8 |
| A-15 | Batch file progress never reaches Dart | BROKEN | 2 |

---

## Meetily feature matrix — before

| Meetily capability | Trareon (before) |
|--------------------|------------------|
| Local live transcription (Whisper) | ✅ |
| Mic + system audio | ✅ macOS/Windows · ❌ Linux (A-1) |
| Import audio file | ✅ |
| Re-transcribe with another model | ❌ |
| Local meeting storage + library | ✅ |
| Full-text search across meetings | ❌ (titles only) |
| Rename meeting | ❌ |
| AI summary (Ollama) | ❌ |
| AI summary (OpenAI-compatible) | ❌ |
| Custom summary templates | ❌ |
| Summary editor, saved with meeting | ❌ |
| Markdown export | ✅ (without summary) |
| Speaker labels | ✅ live · ❌ imported files |
| 100 % offline transcription | ✅ (stronger than Meetily) |
| Indonesian-first UI | ✅ |
