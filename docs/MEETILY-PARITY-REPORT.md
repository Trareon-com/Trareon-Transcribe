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

---

# Round 2: GUI smoke-test fixes

> 2026-09-30 · same branch · found by actually running the release build on
> the Kali/PipeWire laptop rather than on the test suite.

Everything in §1–§4 above passed CI and passed a `cargo run` probe. Launching
`build/linux/x64/release/bundle/transcribe`, selecting **Rapat Online** and
pressing Ctrl+R did not work at all:

* the record button stayed on "⚡ Memulai..." for minutes and no transcript
  ever appeared;
* stderr took **6.6 million lines / 1.5 GB in about two minutes** — a tight
  loop of `` `alsa::poll()` returned POLLERR `` out of cpal's error callback,
  which on a smaller disk is a denial of service against the user's machine;
* startup printed dozens of lines of ALSA plugin and JACK noise.

Three independent defects, found in that order.

---

## R-1 — The microphone was a rate converter

**Not** a stream bug. A *device selection* bug, three layers deep.

`cpal`'s Linux backend is ALSA. `Host::input_devices()` enumerates every pcm
the system defines, which on a normal desktop includes plugins that are not
capture devices at all. The real listing from this machine:

```
Input devices (16):
  name="lavrate"              default=false     <- ffmpeg rate converter
  name="samplerate"           default=false
  name="speexrate"            default=false
  name="pulse"                default=false
  name="speex"                default=false
  name="upmix"                default=false
  name="vdownmix"             default=false
  name="hw:CARD=PCH,DEV=0"    default=false
  ...
```

Every entry says `default=false`, because `Host::default_input_device()`
opens the pcm literally named `default`, and `default` is never one of the
enumerated names. `session_model._resolveDevices()` picks "the one marked
default, else `inputs.first`" — so it picked **`lavrate`**. The recovery
snapshot left behind by the failing run has it in writing:

```json
"mic_device_id": "lavrate",
"speaker_device_id": "lavrate",
```

Opening `lavrate` as a capture device builds a stream and `play()` succeeds,
and then `snd_pcm_poll_descriptors_revents()` returns `POLLERR` on every
poll, with no forward progress and no end. Hence the flood.

Underneath that, the whole ALSA layer is the wrong one on a machine running
PipeWire: the server owns the card, and cpal fights it for it.

**Fix** — `rust_core/src/audio/pulse.rs`: the microphone is captured through
the sound server, the same mechanism system audio has used since A-1.
`resolve_input_source()` is the exact mirror of `resolve_monitor_source()`,
and it matters for the mirror-image reason: it must never return a
`.monitor`. On this machine `pactl get-default-source` **is** the sink
monitor (PipeWire leaves the default there while the mic is suspended), so
honouring the server's default uncritically would have recorded the speakers
and labelled them `Saya`. An unrecognised hint falls through to the real mic
rather than failing, so settings files still carrying `lavrate` recover by
themselves. cpal stays as the fallback where no sound server answers, and
`TRAREON_CAPTURE_BACKEND=pulse|cpal` forces either for debugging.

Device *listings* moved to `pactl` on Linux too (`audio/device.rs`), so the
picker can no longer offer a rate converter as a microphone, and the entry it
marks as default is by construction the one the capture path would open.

That also removed the startup noise (R-4): the ALSA plugin and libjack
chatter was cpal enumerating pcms, which the app no longer does here.
`audio/alsa_quiet.rs` installs an `snd_lib_error_set_handler` no-op for the
remaining cpal fallback paths.

## R-2 — The error callback had no rate limit

cpal calls the error callback on its audio thread with no back-pressure, and
`tracing::error!` was called once per error. `audio/stream_error.rs` now
collapses a burst into one line plus at most one summary per 5 s, and
escalates a *persistent* error to fatal: the stream is stopped and the reason
reaches the user as a `SessionEvent::Notice`, rather than spinning forever.

Two details that are easy to get wrong:

* The rate limit is **message-independent**. Keyed on the error text, a device
  alternating between two errors defeats it and the flood is back at one line
  per error. A test pins this.
* The fatal threshold (100 errors in 5 s) is sliding, so occasional buffer
  xruns across a three-hour recording never accumulate into a false "device is
  broken" verdict — which would stop a working recording. A test pins that too.

Session start no longer swallows a capture failure either. It used to
`tracing::warn!` and return `Ok(None)`, so "Rapat Online" would happily start
a session with zero working capture. `session::decide_start()` now warns when
one source of two is missing and **refuses to start** when none opened.

## R-3 — `start_session` blocked for 221.8 seconds

With the flood gone the button still sat on "Memulai...". Measured with the
new `session_start_probe`:

```
$ ./target/release/session_start_probe <tiny> <large-v3-turbo-q5>
mode:   Rapat Online (mic + system audio)
12:36:09  linux mic: capturing via PipeWire/PulseAudio
12:36:10  whisper engine initialized                     <- q5 loaded, ~1 s
12:37:59  adaptive hpt benchmark rtf=0.0456 mode=Auto    <- 109.6 s
12:38:00  whisper engine initialized (x2)                <- reloaded for dual-pass
12:39:50  adaptive hpt benchmark rtf=0.0457 mode=Auto    <- 109.5 s, again
start_session returned OK in 221.8s
```

Model loading was about 3 s of that. The rest was the adaptive-HPT benchmark:
110 s to transcribe a 5 s clip with `large-v3-turbo-q5` on this 2-core CPU,
run **once per source**, even though what it measures is the machine.

Three fixes, each derived rather than tuned:

1. **A deadline.** The benchmark's only job is to answer "is
   `rtf >= threshold`?". Once `audio_secs / threshold` seconds of wall-clock
   have passed with no result, the answer is already no, and the exact figure
   cannot change the decision. `benchmark_rtf_bounded()` stops *waiting*
   there. It cannot cancel `whisper_full`, so on the slow path one detached
   thread runs to completion and drops the engine itself — a core for a
   minute or two on a machine already judged slow, against minutes of a
   frozen button. It happens at most once per process because of (2).
2. **A cache**, keyed on (model, GPU config). The second source reuses the
   first's decision.
3. **A third route.** Both existing routes run the refine model on *every*
   chunk, so below `rtf 1.0` neither can ever emit anything: a 5 s chunk
   takes longer to transcribe than the next one takes to arrive, and the
   worker falls behind forever. That is exactly what the smoke test saw —
   **zero segments in 90 s of continuous speech**. `HptRoute::QuickOnly`
   drops the refine pass from the live path and says so in Indonesian,
   pointing at "Transkrip Ulang" to recover the accuracy afterwards with no
   real-time constraint. `HPT_LIVE_FLOOR = 1.0` is not a knob — it is the
   definition of keeping up.

`ForceDual` still forces the old behaviour for anyone who wants it.

---

## Verification on this machine

### Dual capture, real hardware

Audio played into the sink throughout (`ffmpeg … | paplay`).

```
$ timeout 25 ./target/release/dual_capture_probe 8
backend override: None
sound server: PulseAudio/PipeWire reachable
  default source: Some("alsa_output.pci-0000_00_1f.3.analog-stereo.monitor")
  default sink:   Some("alsa_output.pci-0000_00_1f.3.analog-stereo")
  resolved mic:   Ok("alsa_input.pci-0000_00_1f.3.analog-stereo")
  source: alsa_output.pci-0000_00_1f.3.analog-stereo.monitor 2ch 48000Hz  [monitor]
  source: alsa_input.pci-0000_00_1f.3.analog-stereo          2ch 48000Hz
INFO linux mic: capturing via PipeWire/PulseAudio source=alsa_input.pci-0000_00_1f.3.analog-stereo
mic:     capture started
INFO linux loopback: recording system audio monitor source=alsa_output.pci-0000_00_1f.3.analog-stereo.monitor
speaker: capture started

recording for 8s ...

mic      chunks=165 samples=131984 (103% of 128000 expected @16000Hz) rms=0.000084 peak=0.000427
speaker  chunks=162 samples=129584 (101% of 128000 expected @16000Hz) rms=0.140172 peak=0.793599

RESULT: OK — both sources delivered audio
```

No POLLERR, and the mic resolves to the real input rather than to the monitor
that PipeWire reports as the default source. The mic RMS is the ADC noise
floor of a silent room — non-zero and three orders of magnitude below the
monitor, which is what proves the two channels are genuinely different
sources rather than the monitor twice.

### The old path, reproduced on purpose

```
$ TRAREON_CAPTURE_BACKEND=cpal timeout 20 ./target/release/dual_capture_probe 5 lavrate
bytes: 1551  lines: 20  POLLERR: 2
mic device arg:   Some("lavrate")
mic:     capture started
ERROR audio input stream error source=mic error=A backend-specific error has occurred: `alsa::poll()` returned POLLERR
ERROR audio input stream failing persistently — stopping capture source=mic error=... total=100
mic      chunks=0   samples=0     (0% of 80000 expected @16000Hz) rms=0.000000 peak=0.000000
RESULT: FAIL — mic delivered no audio
```

Two log lines and a stopped stream, in **1551 bytes**. The same condition
previously produced 6.6 million lines and 1.5 GB.

### Session start

| | before | after |
|---|---:|---:|
| `start_session`, Rapat Online, tiny + q5 | **221.8 s** | **7.5 s** |
| `start_session`, Rapat Online, single model | — | **0.6 s** |

```
$ ./target/release/session_start_probe <tiny> <large-v3-turbo-q5> 60
13:08:58 adaptive hpt benchmark outran its deadline — the refine model cannot
         keep up with live audio on this device, using the quick model only
         deadline_secs=6.0
start_session returned OK in 7.5s
t=10s  vu(mic)=0.0001 vu(spk)=0.3833  0 transcript(s)
      NOTICE: Perangkat ini terlalu lambat untuk model akurat secara langsung,
              jadi transkrip langsung memakai model cepat. Setelah sesi selesai,
              gunakan "Transkrip Ulang" untuk menjalankan ulang dengan model akurat.
t=30s  vu(mic)=0.0001 vu(spk)=0.3579  1 transcript(s)
      [Peserta 1] Anggain dibertalan bariawab mengyakkan lapor apaguan ...
t=60s  vu(mic)=0.0001 vu(spk)=0.3975  1 transcript(s)
      [Peserta 1] 2-2 kali udah pahant, 4-3 kutnya di jadu-mampang gue udah pahanya.
```

Before this change the same command produced no transcript at all in 90 s.
The text is poor because the quick model here is `ggml-tiny`; that is the
model's accuracy, not the pipeline's — the single-model run against
`ggml-tiny` alone produces the same quality, and "Transkrip Ulang" with the
accurate model is the answer to it.

### The GUI, which is where this started

Release build, X11, **Rapat Online**, Ctrl+R, audio playing into the sink:

* startup stderr: **0 bytes** (was: dozens of ALSA/JACK plugin lines)
* "Memulai..." lasted about 3 s, then the UI entered the recording state
* 60 s of recording produced **2 transcript segments** labelled `Peserta 1`,
  a live VU meter, and a **6147-byte** log — of which the only two non-Whisper
  lines are a Flutter renderer notice and a libayatana deprecation warning.

### Gates

```
$ cd rust_core && cargo fmt --check
(clean)

$ cargo clippy --all-targets -- -D warnings
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 5.47s

$ cargo test --lib
test result: ok. 259 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out

$ flutter analyze
No issues found! (ran in 6.8s)

$ flutter test
00:40 +114: All tests passed!

$ flutter build linux --release
✓ Built build/linux/x64/release/bundle/transcribe
```

| Gate | Round 1 | Round 2 |
|---|---:|---:|
| `cargo test --lib` | 219 passed | **259 passed** |
| `flutter test` | 110 passed | **114 passed** |
| `flutter analyze` | 0 issues | 0 issues |
| `cargo clippy -D warnings` | clean | clean |

New tests: the rate limiter and its escalation policy (8), the benchmark
deadline derivation (5), the HPT route thresholds (4), `decide_start` (6),
Pulse source resolution including the stale-`lavrate` recovery (9), the Linux
device listing against the real server (1), mic-vs-monitor resolution against
the real server (1) — plus four Dart tests covering a failed start returning
the button to idle and a mid-session capture failure reaching the user.

---

## Still open after Round 2

| Gap | Impact |
|---|---|
| **Dual-pass HPT runs quick and refine synchronously** in `LivePipelineHpt::ingest`, so nothing is emitted until the refine pass finishes — the "instant partials" the design promises are not actually delivered within a chunk. `QuickOnly` routes around it on slow devices, but the dual-pass path itself needs the refine pass moved onto its own queue. Not attempted here: it is a pipeline redesign, not a bug fix. |
| **The abandoned benchmark thread** keeps a core busy until `whisper_full` returns (about two minutes on this machine), once per process. `whisper.cpp` offers no way to interrupt it. |
| **A muted sink silently yields silent "system audio."** Muting a sink also mutes its monitor source in PipeWire, and unmuting the sink does *not* unmute the monitor — so the recording is digital silence with nothing to indicate why. The silence watchdog catches it after 12 s; naming the cause would be better. (Hit accidentally while automating the GUI for this round, which is how it was found.) |
| **`AudioCapture::stop` does not survive SIGKILL of the app**, so a hard kill can leave the `ffmpeg`/`parec` helper running. A `PR_SET_PDEATHSIG` on the child would close it on Linux. |
