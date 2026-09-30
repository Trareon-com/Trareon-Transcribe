# Meetily parity — what changed

> Branch: `feat/meetily-parity` · 2026-09-30
> Companion document: [`AUDIT-MEETILY-PARITY.md`](AUDIT-MEETILY-PARITY.md),
> which traced every user-facing flow UI → state → bridge → Rust and recorded
> the 15 defects this work addresses.

---

## 1. Feature matrix — Trareon vs Meetily

| Capability | Meetily | Trareon **before** | Trareon **after** |
|---|:---:|---|---|
| Local live transcription (Whisper) | ✅ | ✅ | ✅ |
| Mic capture | ✅ | ✅ | ✅ |
| System-audio capture — macOS | ✅ | ✅ ScreenCaptureKit | ✅ |
| System-audio capture — Windows | ✅ | ✅ WASAPI loopback | ✅ |
| System-audio capture — **Linux** | ✅ | ❌ **recorded the microphone** (A-1) | ✅ PipeWire/Pulse `<sink>.monitor` |
| Import audio file | ✅ | ✅ | ✅ (model loaded once per batch, not per file) |
| **Re-transcribe with another model** | ✅ | ❌ | ✅ "Transkrip Ulang" |
| Local meeting storage + library | ✅ | ✅ | ✅ + metadata sidecar |
| **Full-text search across meetings** | ✅ | ❌ titles only | ✅ title + transcript + summary, with match snippet |
| **Rename a meeting** | ✅ | ❌ | ✅ |
| Delete a meeting | ✅ | ✅ (5 s undo) | ✅ |
| **AI summary — Ollama** | ✅ | ❌ | ✅ |
| **AI summary — OpenAI-compatible** | ✅ | ❌ | ✅ (OpenAI, LM Studio, llama.cpp server, vLLM, Groq, …) |
| **Custom summary templates** | ✅ | ❌ | ✅ 4 Indonesian templates + free-form |
| **Summary editor, saved with the meeting** | ✅ | ❌ | ✅ |
| Markdown export | ✅ | ✅ (no summary) | ✅ **with summary** |
| Other exports (TXT/JSON/SRT/VTT/HTML/DOCX/WAV) | partial | ✅ | ✅ (summary in TXT/HTML/DOCX too) |
| PDF export | ❌ | ❌ | ❌ — see §4 |
| Speaker labels — live | ✅ | ✅ generic `Pembicara N (MIC)` | ✅ `Saya` / `Peserta N` |
| Speaker labels — **imported files** | ✅ | ❌ none | ✅ `Pembicara N` |
| Progressive (fast-then-accurate) transcription | ❌ | ✅ live only | ✅ live **and** import |
| 100 % offline transcription | partial | ✅ | ✅ (enforced by tests) |
| Indonesian-first UI | ❌ | ✅ | ✅ |
| Crash recovery | ❌ | ✅ | ✅ |
| Minimise-to-tray | ❌ | ✅ | ✅ |
| In-app privacy audit | ❌ | ✅ | ✅ + per-request summary endpoint log |

**Where Trareon is now ahead of Meetily:** enforced offline guarantee,
Indonesian-first UI and speaker labels, crash recovery, tray, progressive
transcription, and an in-app privacy audit that names the destination of every
outbound request.

---

## 2. What was fixed

Numbering follows the audit.

### Core flows (Phase 2)

| # | Defect | Fix |
|---|---|---|
| **A-1** | Linux "system audio" recorded the microphone. `ffmpeg -f pulse -i default` and bare `parec` open the default *source*, not the default sink's monitor. In Rapat Online this meant mic on both channels, and echo-dedupe then silently dropped ~half the transcript — failing invisibly. | `resolve_monitor_source()` picks `<sink>.monitor` via `pactl`, honouring the wizard's device hint, and **errors with an actionable message rather than falling back to the mic**. 8 unit tests on the pure rules + 1 test against the real sound server (skips when none). |
| **A-2** | `vadEnabled` reached `SessionConfig` and stopped there — both live pipelines hardcoded `VadConfig::default()`, so the Settings toggle was inert. | Threaded through a new `LiveWorkerConfig`, which also replaced 7–9 positional args on `LiveWorker::spawn*`/`start_capture` and their three `too_many_arguments` allows. `sample_rate`/`chunk_duration_secs` were dead the same way, but wiring them would have regressed live latency 5 s → 30 s, so they were **removed**; a test pins that older recovery snapshots carrying them still deserialize. |
| **A-7** | `autoStopMinutes` and `progressiveEnabled` lived only in Dart memory and reset on every launch (`_fromRustSettings` hardcoded `null`; `progressiveEnabled` was written to `DartPrefs` and never read back). | Both persist in Rust `AppSettings`, `#[serde(default)]` so pre-upgrade settings files keep their model, theme and library path. |
| **A-8** | Imported files had no speaker labels — `stt/file.rs` never touched the `Diarizer`. | File and progressive-file transcription now cluster each segment's PCM window. Both HPT passes are labelled from one diarizer so a label can't flip when the refine pass lands. |
| **A-15** | Batch progress never reached Dart: `transcribe_files_batch` only returns once every file is done. Separately, Dart called it once per file, reloading the ~550 MB model each time, and the FRB wrapper **discarded per-file errors** so a corrupt file vanished from the results with no explanation. | New pollable progress snapshot; `transcribe_files_batch` returns `Vec<BatchFileOutcome>` (transcript *or* error, per file); Dart sends the whole queue in one call. |
| **A-4** | `progressive_transcribe_file` was FRB-exposed but had no Dart caller — "Progressive Mode" did nothing for imports. | Imports use the two-pass path when the refine model is present, matching live recording. |
| **A-12** | `run_rust_diarization()` returned `Vec::new()` with zero call sites. | Replaced by `label_segments()`, which is actually used by both file paths. |
| — | `scanUsageStats` picked "the first `*.json`" in a session folder. Once the metadata sidecar existed (also JSON), a session was counted or skipped depending on filesystem listing order. | Shares `transcriptFileIn`, which excludes the sidecar by name. Caught while implementing the sidecar. |

### Meetily gaps (Phase 3)

**a. AI summary — `rust_core/src/summary.rs` + `SummaryPanel`.**
`llm_correction.rs` was unreachable dead code: no call sites, not FRB-exposed,
and with its feature off a pass-through stub returning an empty string; with
the feature on it shelled out to `python3 scripts/qwen_correction.py` at a
relative path that only resolves when the CWD is the repo root. Removed
(along with the `llm` feature) and replaced with a real implementation:

- **Ollama** (`POST {base}/api/chat`) and **any OpenAI-compatible endpoint**
  (`POST {base}/chat/completions` + bearer auth). llama.cpp's server is
  reachable through the latter, which is what the retained
  `scripts/qwen_correction.py` was reaching for.
- Four Indonesian templates — **Notulen Rapat**, **Ringkasan Eksekutif**,
  **Keputusan & Action Items**, **Standup Harian** — plus free-form *Kustom*.
- Editable in the player, saved with the session, regenerable.
- Prompt building, URL derivation and response parsing are **pure functions**,
  so the feature's whole shape is unit-testable without a socket. Both
  response shapes are accepted regardless of configured provider, because
  "OpenAI-compatible" servers vary and a working reply shouldn't be rejected
  on a technicality.
- Long transcripts are truncated keeping **both ends** (opening context and
  closing decisions) rather than the tail being silently dropped by the
  endpoint's context window.
- A failed summary says *"transkrip tetap aman"* — a red error beside a
  transcript otherwise reads as data loss.

**b. Re-transcribe ("Transkrip Ulang").** Re-runs a saved session's audio with
a different model/language. Defaults to the accurate model, since re-running
is almost always an attempt to improve a fast first pass. The old transcript is
replaced **only after new segments are in hand**, so a failed re-run cannot
lose it; the summary is deliberately left alone (it may be hand-edited).

**c. Full-text search.** Matches titles, summaries and transcript text; the
card shows the matching line so a hit explains itself. Title-only search was
useless for auto-titled sessions ("Sesi 2026-09-30 14:05"), which is most of
them.

**d. Speaker labels.** Mic → `Saya`, loopback → `Peserta N`, imports →
`Pembicara N`; a second voice on the mic stays explicit as
`Pembicara 2 (Mikrofon)` rather than being folded into `Saya`. Mic and speaker
keep independent cluster pools, so identical audio on both channels can't
collapse into one label.

**e. Export with summary.** Markdown/TXT/HTML/DOCX lead with the summary;
SRT/VTT/JSON are untouched (prose in a subtitle cue or a segment array
corrupts the file), pinned by a test. An empty summary produces byte-identical
output to before.

**f. Indonesian-first UX.** Default language was already `id`; the remaining
English strings on the Privacy Report screen are translated.

### Enabling change: the session metadata sidecar

Everything above needed somewhere to keep a summary, a user-chosen title, and
the model/language a transcript came from. The exported `*.json` is a bare
segment array and had to stay that way — it is also an artifact the user hands
to other tools. `trareon-session.json` (`lib/services/session_store.dart`)
holds the rest. Rename writes the title there rather than moving the
directory, which would invalidate the audio path the player holds and desync
the exported filenames from the folder around them. **Sessions written before
the sidecar existed load unchanged** — every field falls back to something
derivable from the directory.

### Privacy boundary

Summaries are the second (and only other) feature that can open a socket, so
the privacy story was restated rather than left contradicting itself:

- Off by default; defaults to loopback Ollama; per-request, never automatic.
- Only transcript **text** is sent — never audio, file paths or device names.
- Every request increments the Privacy Report counter and is logged **with its
  destination endpoint**, since with a user-configurable endpoint that is the
  fact worth auditing.
- API key is stored in the plaintext settings JSON (no OS-keychain dependency
  in this project) — a deliberate trade-off, now documented in `SECURITY.md`.

Enforced, not just documented. `rust_core/src/privacy.rs` fails the build if a
capture/inference/export module gains an HTTP client or references the summary
module, if a third module starts using `reqwest::Client`, or if the shipped
summary default stops being disabled-and-loopback.
`test/privacy_proof_test.dart` mirrors this and additionally asserts that
`generate()` notifies the counter **before** the request leaves.

---

## 3. Verification

All commands run from a clean tree at `04d806a` + the final commit.

```
$ cd rust_core && cargo fmt --check
(clean)

$ cargo clippy --all-targets -- -D warnings
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.33s

$ cargo test --lib
test result: ok. 219 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 1.85s

$ flutter analyze
Analyzing Trareon-Transcribe-parity...
No issues found! (ran in 5.7s)

$ flutter test
00:44 +110: All tests passed!
```

| Gate | Before | After |
|---|---:|---:|
| `cargo test --lib` | 172 passed | **219 passed** |
| `flutter test` | 71 passed | **110 passed** |
| `flutter analyze` | 0 issues | 0 issues |
| `cargo clippy -D warnings` | clean | clean |

### Live end-to-end check (not part of CI)

`rust_core/tests/summary_live.rs` is gated on `TRAREON_SUMMARY_LIVE=1` so CI,
which has no model server, skips it. Run against a local Ollama during this
work:

```
$ TRAREON_SUMMARY_LIVE=1 TRAREON_SUMMARY_MODEL=qwen2.5:0.5b \
    cargo test --test summary_live -- --nocapture

test lists_models_from_a_real_endpoint ...
models: ["huihui_ai/qwen3-abliterated:8b-v2", "nomic-embed-text:latest", "qwen2.5:0.5b"]
ok
test summarises_an_indonesian_meeting_transcript ...
--- summary ---
## Keputusan
- Saya: Selamat pagi semua, kita bahas anggaran kuartal empat.

## Action Items
| Tugas | Penanggung Jawab | Tenggat |
| --- | --- | --- |
| 1. | Budi | - |
| 2. | Peserta 1 | - |
| 3. | Peserta 2 | - |
---------------
ok

test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 21.85s
```

Model listing, request, Indonesian output and the Action Items template shape
are all correct end-to-end. Content quality is limited by `qwen2.5:0.5b`
(a 0.5 B parameter model used because it was already pulled locally) — a
7 B-class model is the realistic recommendation.

The Linux system-audio fix was likewise verified against the real sound server
on this machine (PipeWire): `cargo test --lib` includes
`resolves_a_real_monitor_source_when_a_sound_server_is_running`, which asserts
what `capture_loopback` would actually record is a `.monitor` source. It
skips rather than fails where no sound server exists.

---

## 4. What remains

### Not done, with reasons

| Item | Why |
|---|---|
| **PDF export** | `docx-rs` cannot produce PDF; a real writer means a new dependency (e.g. `printpdf`) *plus* font embedding, since the default PDF base-14 fonts don't cover the full Latin-1 range Indonesian text needs. Disproportionate to the gap: DOCX and HTML both print to PDF from any OS viewer. Meetily doesn't offer PDF either. |
| **Indonesian-specialised ASR model** (`cahya/whisper-medium-id`) | No GGML conversion is published upstream, so it can't be loaded by whisper.cpp. Converting and hosting one is a separate piece of work with its own distribution and licence questions. `large-v3-turbo-q5` remains the accuracy recommendation for Indonesian. |
| **Real-time streaming summaries** | Meetily doesn't do this either, and it would put a network call in the recording path — directly against the privacy guarantee. |

### Known gaps still open (carried from the audit)

| # | Gap | Impact |
|---|---|---|
| A-13 | `SetupWizardScreen` is unreachable from the app — referenced only by its own test. `main.dart` routes to `OnboardingScreen` instead. | Dead code, and the blueprint's `/wizard` route doesn't exist. Either wire it into Settings or delete it. |
| A-14 | Global hotkeys are macOS-only: `GlobalHotkeyService` listens on a `MethodChannel` only the macOS `AppDelegate` publishes to. | Silent no-op on Linux and Windows. In-app shortcuts (Cmd/Ctrl+R/P/L/,) work everywhere. |
| A-3 | `detectFrontmostWindowTitle()` returns `''` unconditionally (deliberately, for privacy) but `session_model.start()` still awaits it and branches on the result. | Harmless dead-end; worth deleting. |
| — | `resume_pending_transcriptions` and the 8 flight-recorder functions are FRB-exposed with no Dart caller. | Dead public surface. |
| — | Diarization clusters on three weakly-scaled acoustic features with a fixed `0.22` threshold. | Reliably separates mic from system (separate pools by construction); multi-speaker accuracy *within* one channel is best-effort. A real embedding model would need a neural dependency. |
| — | Live capture, mic/loopback devices and real model inference are still only covered by manual smoke tests. | Unchanged from before; the Linux monitor-resolution test above is the first automated coverage of any of it. |

### Suggested next steps, in order

1. Resolve A-13 — wire the setup wizard into Settings or delete it and its test.
2. Delete the dead FRB surface (A-3, `resume_pending_transcriptions`, flight recorder) or give it callers.
3. Windows/Linux global hotkeys (A-14).
4. A hardware smoke test for dual capture on each platform, per `CHECKLIST.md`.
