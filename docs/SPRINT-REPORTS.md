# Sprint Reports

Per-sprint record of what was built, what was verified, and what was left
undone. Each section is written against the item numbers in
`docs/TRAREON-V1-PRODUCTION-BLUEPRINT.md` §5 and `docs/UX-FEATURE-AUDIT.md`
Part D.

---

# Sprint 0 + Sprint 1 report — branch `sprint/01-durability`

*"Tidak ada yang hilang, tidak ada yang bohong."*

Base: `5724ef6` (merged PR #6). 14 commits, 88 files, +8518 / −4900.

## Verification gate

All green, run on the final commit (`1b82acd`).

```
$ cd rust_core && cargo fmt --check
(no output)

$ cargo clippy --all-targets -- -D warnings
Finished `dev` profile [unoptimized + debuginfo] target(s)

$ cargo test --lib
test result: ok. 309 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out

$ flutter analyze
No issues found!

$ flutter test
01:13 +276: All tests passed!

$ flutter build linux --release
✓ Built build/linux/x64/release/bundle/transcribe
```

Test counts moved from **259 → 309** Rust unit tests (+50) and
**216 → 276** Dart tests (+60).

## Sprint 0 — quick wins

### 1. Typo "Traeon" → "Trareon" + CI grep · **DONE**
`onboarding_screen.dart:43` fixed. `doctor.rs` carried the same typo in
two places that mattered: the preflight probed
`~/.config/TraeonTranscribe`, a directory the app never uses, so the
config-dir writability check was testing nothing.

- Files: `lib/screens/onboarding_screen.dart`, `rust_core/src/doctor.rs`
- Tests: `test/product_name_spelling_test.dart` (2) — scans `lib/`,
  `test/`, `integration_test/`, `rust_core/src`, `scripts/` and the three
  platform folders for every misspelling in this repo's history. `docs/`
  is deliberately out of scope: the audit quotes the typo as evidence.

### 2. Button contrast + WCAG test · **DONE**
`ElevatedButtonThemeData` hardcoded `Colors.white` over `colors.primary`,
which in dark mode (#4DB6AC) is **2.44:1** — every primary button in the
app. `ColorScheme` did the same for `onSecondary`/`onError`, and the one
hardcoded error accent (#FF3B30, 3.55:1 on white) was used as body-text
colour in four dialogs.

`secondary`/`onSecondary`/`error`/`onError` joined `AppColorSet` so each
theme carries its own pair; light `textTertiary` went #757575 → #6B6B6B
(4.23:1 → 4.89:1 on the app background).

- Files: `lib/theme/app_colors.dart`, `lib/theme/app_theme.dart`,
  `lib/theme/contrast.dart` (new), plus four widgets switched off the
  hardcoded accent.
- Tests: `test/theme_contrast_test.dart` (47) — a ratio assertion for
  every text pair in **both** themes, plus the resolved
  `ElevatedButton`/`SegmentedButton` styles rather than a restatement of
  the tokens, plus the WCAG reference extremes (21:1, 4.48:1, 1:1).
- The maths lives in `lib/`, not `test/`: a contrast rule that exists only
  in a test can be satisfied by editing the test, and `speakerColor`
  needed the same function.

### 3. Speaker picker lists output devices · **DONE**
Both pickers called `listAudioDevices`, so "Pengeras Suara" offered a list
of microphones to record the system audio from.
`api::list_output_audio_devices` exposes the `list_output_devices` that
`audio/device.rs` already had. On Linux that resolves to
PulseAudio/PipeWire **sinks** — the same source of truth `audio::pulse`
turns into `<sink>.monitor` for the actual capture.

- Files: `rust_core/src/api.rs`, `rust_core/src/audio/mod.rs`,
  `lib/services/bridge_service.dart`
- Verified in the real app: the recovery snapshot of a live session shows
  `"speaker_device_id": "alsa_output.pci-0000_00_1f.3.analog-stereo"` — a
  sink, not a capture source.

### 4. Theme "Sistem" persists · **DONE**
Rust `Theme` gains a `System` variant. It was a Dart-only concept with no
Rust counterpart, so the bridge wrote it out as `Light` and the app came
back "Terang" after every restart. `theme` also picked up
`#[serde(default)]`, so a settings file missing the field loads its other
fields instead of resetting everything.

- Files: `rust_core/src/settings.rs`, `lib/services/bridge_service.dart`
  (mapping extracted to top-level `toRustTheme`/`fromRustTheme`, like
  `toRustSegment`, so it is directly testable)
- Tests: `settings::tests::system_theme_survives_a_roundtrip`,
  `settings::tests::a_settings_file_without_a_theme_keeps_its_other_fields`,
  `test/theme_persistence_test.dart` (3)

### 5. Real version + "Lihat Rilis" · **DONE**
The updater compared a hardcoded `0.1.0` against a `pubspec.yaml` saying
`1.0.0` and a `VERSION` manifest saying `0.1.0` — wrong in both
directions. "Lihat Rilis" was a button whose `onPressed` body was the
comment `// Open release page`.

`kAppVersion` is a compile-time constant rather than `package_info_plus`:
the updater runs before any platform channel is guaranteed up, and the
string already exists in `pubspec.yaml`. What was missing is a guarantee
they stay together.

- Files: `lib/app_version.dart` (new), `lib/services/update_checker.dart`,
  `lib/widgets/settings_side_panel.dart`, `VERSION` (0.1.0 → 1.0.0),
  `pubspec.yaml` (+`url_launcher`)
- Tests: `test/app_version_test.dart` (4) — constant vs pubspec vs
  VERSION; `test/update_checker_test.dart` (7, new — the class had none)
  against a loopback HTTP server: version comparison including
  `1.10 > 1.9` (which a lexicographic compare gets wrong), the
  404/empty/unreachable branches, and that a check that failed to connect
  is still recorded.

### 6. Privacy Report truthfulness · **DONE**
The report claimed two network activities. In fact `recordModelDownload`
had **no callers at all** — pinned there by a test asserting it had zero —
while the updater contacted `raw.githubusercontent.com` on every "Cek
Pembaruan" and recorded nothing.

Four outbound paths are now enumerated and each records itself *before*
the request leaves: model download (both call sites), AI summary, update
check, and handing the releases URL to the browser. `UpdateChecker` and
`OnboardingNotifier` take their recorder as a **required** constructor
argument — an omittable callback is one that gets omitted.

- Files: `lib/state/privacy_report_model.dart`,
  `lib/screens/privacy_report_screen.dart`, `lib/services/update_checker.dart`,
  `lib/state/onboarding_model.dart`, `lib/widgets/model_download_dialog.dart`,
  `lib/widgets/settings_side_panel.dart`
- Tests: `test/privacy_proof_test.dart` — the invariant flips from *"this
  counter is never incremented"* to *"every call site that can initiate a
  request records itself first"*, checked structurally over `lib/`, plus
  "the recorder set matches the initiator set exactly" so a fifth outbound
  path cannot be added without a recorder.
- Screen copy now names all four activities and their destinations, and
  the activity log moved **above** the explanation — what happened on this
  machine is the point of the screen and it was under a screenful of prose.

## Sprint 1

### 7. Continuous transcript journal + real recovery (item 1, P0) · **DONE**
`rust_core/src/journal.rs` (new). Every finalized segment is appended to
`transcript.jsonl` as it is emitted, flushed to the OS per segment (so a
process crash loses nothing) and `fsync`ed on a 2 s interval (so a power
cut loses seconds without a disk barrier per segment on a machine already
saturated by Whisper).

Replay applies the same merge rules as the live UI — refine replaces its
quick pass in place, a late partial never overwrites a refined row — and
tolerates the torn final line a `kill -9` leaves.

- Files: `rust_core/src/journal.rs`, `rust_core/src/session.rs`,
  `lib/state/session_model.dart` (`segments: []` was hardcoded in
  `recoverFromSnapshot`)
- Tests: `journal::tests` (8), `session::tests` crash-recovery group (11)

### 8. Audio streamed to disk (item 2, P0) · **DONE**
`rust_core/src/audio/wav_writer.rs` + `rust_core/src/audio/sink.rs` (new).
16-bit PCM goes straight to `<name>.wav.part`; the header is patched on
stop, and `repair` does the same patch from the file's own length — which
is what turns "the bytes are on disk" into "a file that plays". Written by
hand rather than with `hound` because `hound` only fixes the header on a
clean `finalize`.

Behind `SessionConfig.audio_to_disk` / `AppSettings.audio_to_disk`,
default **on**, with a bounded RAM buffer (capped at one hour per source)
as the fallback when the writer cannot be opened. The old unbounded
`Vec<f32>` — 691 MB per source for three hours — is gone.

`export_session_audio` **moves** the finished WAV rather than re-encoding
it: re-reading 700 MB to write it back out would reintroduce the peak
memory this removes.

- Tests: `audio::wav_writer::tests` (7) including repair-after-crash and a
  sample torn mid-write; `audio::sink::tests` (12)

### 9. Atomic writes, disk-space checks, recoverable saves (items 5/6) · **DONE**
- **Atomic writes**: `lib/utils/atomic_file.dart` (new) writes a temp file
  *in the same directory* (rename is only atomic within a filesystem) and
  flushes before the rename. Applied to the transcript the player rewrites
  on a 400 ms debounce, the sidecar holding the only copy of the summary,
  and the prefs file. Tests: `test/atomic_file_test.dart` (7), including
  "a failed write leaves the previous file intact".
- **Disk space**: `rust_core/src/disk.rs` (new). A grep for
  `available_space`/`disk_space`/`ENOSPC` across the codebase previously
  returned nothing. Recording is refused below 100 MB, warned about below
  500 MB, and stopped **on purpose** if it falls below 100 MB mid-session
  — while writing the transcript still works. Tests: `disk::tests` (6).
- **Failed saves**: a failed auto-save on Stop was a three-second toast
  over a transcript still in memory; a failed edit-save in the player was
  a `debugPrint`. Both raise a persistent banner with "Coba lagi" and
  "Simpan ke folder lain". Tests: `test/session_save_retry_test.dart` (9).
- `DartPrefs.save` no longer swallows write errors whole.

### 10. Backup before "Transkrip Ulang" + restore (item 7) · **DONE**
The transcript is copied to `trareon-transkrip-cadangan.json` before the
re-run replaces it, and the player shows "Pulihkan cadangan" while that
copy exists. A backup that cannot be written **aborts** the re-transcribe
rather than proceeding without one. The backup is excluded from
transcript lookup so it can never be loaded *as* the transcript.

- Files: `lib/services/session_store.dart`,
  `lib/screens/transcript_player_screen.dart`
- Tests: `test/transcript_backup_test.dart` (7)

### 11. Recovery dialog (item 12) · **DONE**
The banner said "Ada N sesi yang bisa dipulihkan", had one "Pulihkan" that
silently acted on the **first** entry, and an "Abaikan" that hid the list
without deleting anything — so the same sessions reappeared on every
launch, forever.

It now summarises what is actually recoverable and opens a dialog listing
each session with title, start time, duration and contents, with
per-session **Pulihkan** / **Hapus**. A session with nothing left is
flagged in the error colour rather than promised. Empty snapshots and
pre-journal `*.inprogress` files are cleaned up before they are listed;
a directory with audio but no snapshot is **kept and logged**, because
tidying up is not worth deleting a recording for.

- Files: `lib/widgets/recovery_dialog.dart` (new), `lib/screens/main_screen.dart`
- Tests: `test/main_screen_recovery_test.dart` (5, rewritten)

### 12. Capture health + integrity summary (F4) · **DONE**
A badge beside the VU meters distinguishes "Menunggu suara dari X" from
"Rekaman terkonfirmasi" — a VU meter twitching at the noise floor looks
identical to a working microphone. The engine raises a notice when an
expected source has been silent for a minute, once per outage rather than
once per poll, and re-arms when sound returns.

At Stop, a session with any warning gets a dialog listing duration, %
silent and segment count per channel with the dead channel named in red;
a clean session still gets only the toast.

- Files: `rust_core/src/audio/sink.rs`, `rust_core/src/session.rs`,
  `lib/widgets/capture_health_view.dart` (new), `lib/screens/main_screen.dart`
- Tests: `test/capture_health_view_test.dart` (10), `audio::sink::tests`,
  `session::tests::capture_health_*`

### 13. Import queue scrollable + window minimum size (item 11) · **DONE**
The queue was spread straight into a `Column`, so it overflowed off the
bottom after about five files and the tiles past that were unreachable.
Now a lazily-built `ListView` inside an `Expanded`. Linux and Windows had
no minimum window size (macOS gets one from the bundle); 800×600 is now
enforced at startup.

- Files: `lib/widgets/file_upload_zone.dart`, `lib/main.dart`
- Tests: `test/file_upload_queue_overflow_test.dart` (3) at 800×600

### 14. Theme-aware speaker palette (item 10) · **DONE**
Six of the eight entries were between 2.3:1 and 4.2:1 in light mode, on
the app's most-repeated text. Each theme now carries its own eight-entry
palette, gated at 4.5:1 against the transcript background, the app
background, **and** the 15% tint `SpeakerAvatar` draws the initials on
(the tightest of the three, and what pushed three light entries to their
900 shades). Selection moved from `String.hashCode` to FNV-1a, because
`hashCode` is not specified to be stable across Dart releases.

- Files: `lib/theme/app_colors.dart`, `lib/utils/speaker_color.dart`
- Tests: `test/speaker_color_test.dart` (53)

### 15. Dead code + FRB regeneration (item 30) · **DONE (with a stated exception)**
Deleted, none with an importer anywhere in `lib/`: `resource_hud.dart`,
`vu_meter.dart`, `widgets/shortcuts_panel.dart` (all three duplicates of
private classes inside `main_screen.dart`, so a fix to one silently
missed the other), `services/flight_recorder.dart` and
`src/rust/flight_recorder.dart` — two separate hand-written wrappers over
the same Rust API, the second sitting in the generated directory where a
codegen run would have removed it without warning.

The FRB whitelist named nine modules, so codegen emitted a wire function
for every public item in `session`, `audio`, `settings`, `export`,
`model`, `decode` and `summary` — a duplicate of `api.rs` that Dart never
called. Narrowed to `crate::api,crate::error`; every type Dart uses is
still reached transitively through an `api` signature. **~2500 lines of
bindings removed.** `api.rs` also lost eight wrappers with no caller.
`ARCHITECTURE.md` and `CONTRIBUTING.md` updated with the new command.

**Kept deliberately, and why:**
- the setup wizard and `SetupOverlay`/preflight — Sprint 2 wires them in
  (per this sprint's brief);
- the Rust flight recorder and its nine API functions — the audit's own
  fix for those is "give them a caller" (Sprint 3, item 27), not delete;
  only the orphaned Dart wrappers were the dead part;
- `engine_version`, `health_check`, `get_session_status` — listed by the
  audit as uncalled, but `integration_test/app_test.dart` calls all three.
  Deleting them would have broken the only integration test to satisfy a
  count.

Also removed two false statements the audit found: `main.dart` claimed the
setup wizard was "reachable from Settings" (it is not), and the model
dropdown told the user to "Selesaikan Setup Wizard terlebih dahulu" for a
wizard with no route into it — it now opens the download dialog that does
exist.

## Exit criteria

> `kill -9` the app mid-session after ≥ 60 s of audio → relaunch →
> transcript segments **and** audio are recovered.

**Met.** Full run against the release build on display `:0`, Indonesian
speech (`rapat_id.mp3`, looped) played into the PipeWire sink.

| Step | Observed |
|---|---|
| Launch | Three pre-journal `*.inprogress` files from earlier builds were cleaned up automatically; no recovery banner. |
| Start "Rapat Uji Crash" (Rapat Online) | `recovery/<uuid>/` immediately contains `snapshot.json`, `transcript.jsonl`, `mic.wav.part`, `speaker.wav.part`. Snapshot records `speaker_device_id: alsa_output...` — a **sink** (item 3 verified end to end). |
| ~50 s in | Badge reads "Menunggu suara dari Mikrofon"; live notice: *"Mikrofon belum merekam suara apa pun sejak sesi dimulai (1 menit)…"*. This machine has no live microphone, so F4 caught the exact failure it exists for. |
| 12 min in | 7 Indonesian segments in the journal and on screen; 22 MB per channel streamed to disk. |
| `kill -9` | Process gone. On disk: 7 journal lines, `mic.wav.part` 23.2 MB, `speaker.wav.part` 22.0 MB, snapshot intact. |
| Relaunch | Banner: *"1 sesi terhenti — 7 segmen transkrip dan 23 menit audio bisa dipulihkan."* |
| Dialog | Lists the session with start time, duration, `7 segmen transkrip · audio: mikrofon 12 menit, audio sistem 11 menit`, and per-session Pulihkan / Hapus. |
| Pulihkan | **All 7 segments restored**, recording resumed, elapsed clock continued at 12:08 rather than 00:00, `.part` files reopened and appended to. |
| Berhenti | Integrity dialog: *"Sesi selesai — ada masalah · Durasi 13 menit · 7 segmen transkrip · Mikrofon: tidak ada suara sama sekali · Audio sistem: 36 detik terekam, 15% senyap"*. |
| Library | `20261001-Sesi …/` with `mic.wav` (764 s), `speaker.wav` (**725 s**, valid `pcm_s16le` 16 kHz mono per `ffprobe`), the transcript in `.json`/`.md`/`.txt`, and the sidecar. The WAV spans **pre-crash and post-recovery as one continuous file**. Recovery directory empty afterwards. |

Screenshots: `/tmp/shot01_main.png` … `/tmp/shot15_shortstop.png`.

> Contrast tests pass.

47 theme assertions + 53 speaker-palette assertions, both themes.

> Privacy report counts match call sites.

Enforced structurally by `test/privacy_proof_test.dart`: the recorder set
and the initiator set must be equal, and every initiating call site must
record before it fires.

## Defects the smoke test found (fixed in-sprint)

The release build surfaced three things no test had:

1. **The session title never reached the snapshot.** `setTitle` only
   pushed to Rust while already recording, but the normal order is to type
   the title *then* press Mulai — so the recovery dialog showed
   "Sesi 67629ec7" for a session the user had named. Now mirrored on
   start and on recovery, not only on the next keystroke. (`71d17ad`)
2. **The integrity summary mixed timescales.** It reported the session's
   full duration ("Durasi 13 menit") next to per-channel figures covering
   only the seconds since a restart ("Mikrofon: 38 detik terekam"),
   because the capture counters restart with the capture threads while the
   clock and the audio file do not. The counters are now persisted per
   source in the snapshot and seeded back on recovery. Re-verified:
   "Durasi 1 menit · Mikrofon … (76 detik terekam)". (`71d17ad`)
3. **A session with audio but no transcript threw the audio away.**
   `stop()` returned early when the transcript was empty — and since audio
   now streams to disk, the recording was both dropped *and* left in the
   recovery directory, invisible to the recovery dialog (needs a snapshot)
   and to the library (needs a transcript). Whisper lags far behind
   capture on a slow device, so stopping before the first segment is
   finalized is an ordinary outcome, not an edge case. The audio is now
   placed first and unconditionally, with an empty transcript written
   alongside so the session is visible and "Transkrip Ulang" can run over
   it later. Verified: a 12 s session produced a library folder with
   `mic.wav`, `speaker.wav` and the sidecar. (`1b82acd`)

## Known gaps

- **Recovery resumes capture rather than only restoring.** Recovering a
  session restarts the microphone and loopback. New segments are offset
  onto the end of the recovered timeline, and the `.part` files are
  appended to, so the artefacts are continuous — but the wall-clock gap
  between the crash and the relaunch is simply absent from both. It is not
  represented as a silence in the audio.
- **The recovery banner sums audio across sources.** "23 menit audio" for
  a 12-minute session with two tracks is arithmetically honest but reads
  oddly; the per-session dialog breaks it down correctly. Worth revisiting
  with the Sprint 2 layout work.
- **`SessionEvent::Notice` is not deduplicated across a poll boundary.**
  The silence warning latches per channel, but a source that oscillates
  around the 60 s threshold can raise more than one notice.
- **The RAM fallback silently caps at one hour per source.** It reports
  once when the cap is hit; there is no UI for it beyond that notice,
  because the fallback should be unreachable in normal operation.
- **Preflight and the setup wizard are still unreachable** — excluded from
  this sprint's scope by the brief; Sprint 2 (audit items 19, 20).
- **The flight recorder still has no caller** — Sprint 3 (audit item 27).
- **`integration_test/` still does not run in CI** and remains macOS-only
  by construction (audit PR-11). It compiles, and its `SessionConfig`
  literal was updated for the new field, but nothing exercises it.
- **Smoke-test residue**: one recovery directory
  (`045b371c-…`, ~4.7 MB of WAV) was left behind by an *intermediate*
  build during the smoke test, before fix (3) above. The shipped code no
  longer creates these; it now keeps and logs them rather than deleting a
  recording, which is what that directory demonstrates.
- **Not verified on macOS or Windows.** Every claim above is from Linux
  (PipeWire) on this machine. The audio path is shared, but the loopback
  backend is not.

---

## Sprint 1 — fix round (CI failure)

### The failure

CI's `flutter test` reported **275 passed, 1 failed**:

```
❌ test/session_save_retry_test.dart: retrySave can write somewhere else entirely (failed)
Expected: ['/home/kali/Documents/TrareonTranscribe']
```

### Root cause — DONE

The test asserted a literal absolute path containing *this developer's*
home directory. `SessionNotifier` defaults its library path to
`~/Documents/TrareonTranscribe` and resolves the tilde against `HOME`
(`lib/state/models.dart:58`), so the expectation only ever held on a
machine whose `HOME` is `/home/kali`. On the runner, `HOME` is
`/home/runner`, and the audio correctly landed in
`/home/runner/Documents/TrareonTranscribe`.

The production code was right; the assertion was machine-dependent. It
was also the *only* such assertion — a repo-wide search for `/home/kali`
and `/Users/` outside `docs/` turned up nothing else in `lib/` or
`test/` (only `TODO.md` prose and an example binary that already falls
back correctly).

The test was not weakened. It still asserts exactly what it was written
to assert — that on `retrySave(outputDir: …)` only the transcript moves
to the override while the already-placed audio stays in the default
library folder — but the expected default is now derived rather than
transcribed.

Alongside the fix, the default library path literal (which had been
duplicated in `AppSettings.defaults()` and `SessionNotifier`) was given
a name, `kDefaultLibraryPath`, so the test and both production defaults
cannot drift apart again.

**Files touched**
- `lib/state/models.dart` — new `kDefaultLibraryPath` constant;
  `AppSettings.defaults()` uses it.
- `lib/state/session_model.dart` — `_libraryPath` initialises from it.
- `test/session_save_retry_test.dart` — expectation is now
  `resolveTilde(kDefaultLibraryPath)`.

**Tests added**: none (this is a fix to an existing test's portability,
not new behaviour). The fix was verified by re-running the suite under a
foreign home directory:

```
$ HOME=/tmp/fake-ci-home flutter test test/session_save_retry_test.dart
00:00 +9: All tests passed!
```

That is the exact condition that broke CI, and it now passes — before
the fix it fails there the same way it failed on the runner.

### Verification gate

```
$ cd rust_core && cargo fmt --check
FMT OK
$ cargo clippy --all-targets -- -D warnings
Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.60s   (no warnings)
$ cargo test --lib
test result: ok. 309 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out

$ flutter analyze
No issues found! (ran in 4.3s)

$ flutter test
00:01:16 +276: All tests passed!          (was 275 passed / 1 failed)

$ flutter build linux --release
✓ Built build/linux/x64/release/bundle/transcribe
```

### Smoke test

The change alters a production default's *spelling*, not its value, so
the smoke test confirmed the resolved path is unchanged. Launched the
release bundle on `:0`; the main window came up normally ("Belum ada
transkrip", mode chips, MIC/SPK both `HIDUP`). Opened Pengaturan and
scrolled to **Output & Penyimpanan**: *Folder output* reads
`/home/kali/Documents/TrareonTranscribe` — identical to before the
refactor, i.e. `kDefaultLibraryPath` resolves exactly as the inline
literal did. App killed with `pkill -9 -x transcribe`.

### Known gaps

- The gaps listed for Sprint 1 above are unchanged; this round fixed the
  CI failure only and touched no capture, export or privacy code.
- No other test asserts an absolute path, but nothing *enforces* that.
  A lint or a test helper that forbids `Platform.environment['HOME']`
  literals in expectations would make the class of bug unrepeatable;
  that was out of scope here.

---

# Sprint 2 report — branch `sprint/02-scale`

*"Nyaman untuk rapat 3 jam."*

Base: `13b89d7` (merged PR #7). 6 commits, 57 files, +8 400 / −2 800.
Covers audit Part D items 13–21, blueprint F1, and the layout redesign
from blueprint §4 points 1–3, 5 and 7.

## Verification gate

All green, run on the final commit.

```
$ cd rust_core && cargo fmt --check
(no output)

$ cargo clippy --all-targets -- -D warnings
Finished `dev` profile [unoptimized + debuginfo] target(s)

$ cargo test --lib
test result: ok. 315 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out

$ flutter analyze
No issues found!

$ flutter test
01:17 +333: All tests passed!

$ flutter build linux --release
✓ Built build/linux/x64/release/bundle/transcribe
```

Test counts moved from **309 → 315** Rust unit tests (+6) and
**276 → 333** Dart tests (+57).

## Exit criteria

| Criterion | Result |
|---|---|
| 5 000-segment session scrolls without jank | **Met.** Per-frame scroll cost at 5 000 segments is **0.82×** the cost at 40 segments (12.17 ms vs 14.93 ms avg under `flutter test`), i.e. independent of transcript length. Only 12 rows are materialised at rest. |
| Library open with 200 sessions < 500 ms | **Met.** Warm open **199 ms**; cold index build 1 055 ms, paid once. |
| Search responsive while typing | **Met.** Keystroke cost 19.5 ms avg at 5 000 segments (debounced, so only the last keystroke filters); one filter pass over 5 000 segments 199 ms; 100 index-level library searches over 200 sessions 54 ms. |
| Clicking a transcript line seeks the audio | **Met**, verified in the release build — see smoke test. |
| Setup wizard and preflight reachable | **Met**, verified in the release build. |

## Per item

### 1. Synthetic 5 000-segment / 3-hour fixture as a permanent benchmark · **DONE**

`test/support/large_session.dart` and `rust_core/src/bench_fixture.rs`
generate the same shape on both sides — 5 000 segments over 3 hours, one
utterance every 2.16 s, deterministic (fixed mixer, no clock, no I/O) so
runs are comparable between commits. The Dart fixture also writes a
200-session library to a temp directory for the library benchmark.

- Files: `test/support/large_session.dart`,
  `rust_core/src/bench_fixture.rs`, `rust_core/src/lib.rs`
- Tests: `test/perf/transcript_view_perf_test.dart` (7),
  `test/perf/session_ingest_perf_test.dart` (3),
  `test/perf/library_index_perf_test.dart` (6),
  `test/segment_lookup_test.dart` (6), plus 4 Rust tests (fixture
  determinism/shape and two journal benchmarks).

The timing assertions are deliberately **ratios measured in the same
run** (5 000 segments vs 40; 5 000 ingested segments vs 1 250), not
absolute budgets. Absolute budgets under `flutter test` on shared CI
hardware would be flaky; the ratios are machine-independent and are what
actually catch a return of O(n) per frame or O(n²) ingestion. Absolute
numbers are printed as `[perf] …` lines and quoted below.

### 2. (Item 13) Transcript-list rebuild storm · **DONE**

- The `(index, segment)` tuple list over every segment, rebuilt on every
  build, is gone. With an empty search box no index list is allocated at
  all; with a query the match list is computed once per (segments,
  query, revision) change.
- Rows carry a `ValueKey`, and the per-row entry animation — which
  replayed on every scroll and every search keystroke because
  `ListView.builder` recycles elements — is removed.
- The playing row arrives as a `ValueListenable<int?>` that only fires
  when the row changes, so the 5–10 Hz position stream no longer
  rebuilds anything but the seek bar and the clock.
- `SegmentTimeline` (`lib/utils/segment_lookup.dart`) replaces the
  per-tick `lastIndexWhere` with a binary search over sorted starts. It
  sorts rather than assuming sorted input, because live capture
  interleaves two pipelines. The highlight is now sticky across silence
  instead of blinking off in every pause.
- Seeking across the meeting re-anchors the viewport (a
  `CustomScrollView` with a reverse leading sliver) instead of scrolling
  to an estimated offset. Measured first: `jumpTo` across 4 200
  variable-height rows in a `ListView.builder` builds all of them —
  **20 193 ms** on this machine. Re-anchoring: **392 ms**.

Files: `lib/widgets/transcript_view.dart`,
`lib/utils/segment_lookup.dart`, `lib/screens/transcript_player_screen.dart`.

Measured:

```
[perf] rows materialised at rest: 12
[perf] scroll @40:   n=40 avg=14.93ms p95=45.57ms max=61.30ms
[perf] scroll @5000: n=40 avg=12.17ms p95=36.95ms max=41.38ms
[perf] scroll scale factor: 0.82×
[perf] rebuild @40:   n=40 avg=117.21ms p95=194.52ms max=245.62ms
[perf] rebuild @5000: n=40 avg=55.04ms p95=107.32ms max=110.89ms
[perf] parent-rebuild scale factor: 0.47×
[perf] unchanged position tick @5000: n=100 avg=0.09ms p95=0.15ms max=0.29ms
[perf] first build of 5000 segments: 1331ms
[perf] reveal row 4200 of 5000: 392ms
```

Read the absolute frame numbers as *test-binding* numbers: a `pump()` in
`flutter_test` on this weak CPU costs tens of milliseconds regardless of
what is on screen, which is why the 40-segment control is sometimes
*slower* than the 5 000-segment one. The scale factor is the signal.

### 3. (Item 14) O(1) segment ingestion · **DONE**

`SessionNotifier` keeps a growable list plus a `segmentKey → index` map
and publishes an `UnmodifiableListView` of it, instead of an
`indexWhere` scan plus a full list copy per arriving segment.
`SessionUiState` gains a `revision` counter, because an in-place edit
(an HPT refine pass replacing its quick pass) changes neither the list
identity nor its length and the UI needs something to cache against.
`setSegments()` is the supported way to seed the list from outside the
live stream.

- Files: `lib/state/session_model.dart`
- Tests: `test/perf/session_ingest_perf_test.dart` (3); four existing
  tests updated to seed through `setSegments`.

```
[perf] ingest 1250 = 23.78ms, 5000 = 39.13ms, ratio = 1.65× for 4× the segments
[perf] refine of the 5000th row: 44µs
```

### 4. (Item 15) Two-phase library load · **DONE**

`lib/services/library_index.dart` is phase 1: one index file
(`.trareon-library-index.json`, written atomically) holding title, date,
duration, segment count, snippet, audio path and summary per session.
Every entry is validated against the transcript's size and mtime, so the
index is a cache and never a source of truth — corrupt, stale and
future-versioned index files each cost one slow open, all covered by
tests. Phase 2 (`loadSessionRecord`) parses segments only when a session
is opened or exported.

Also in this item, from the same audit section:

- Search: 250 ms debounce, a precomputed lowercased haystack per
  session, and a background-isolate full-text scan over the transcripts
  the index cannot answer. Snippets come from that scan instead of
  being recomputed inside `itemBuilder`.
- The session date now comes from the exporter's `YYYYMMDD-` directory
  prefix (A.2-7), so saving a summary no longer relabels an old meeting
  as today and floats it to the top.
- `StorageBar` moved out of the list, where it was disposed and
  recreated on every scroll and walked the whole library each time
  (A.2-6).
- Returning from the player re-reads one session, not the corpus (A.2-5).
- `loadSessionLibrary`, `sessionMatchesQuery` and `matchingSnippet` are
  deleted: superseded and used only by their own tests.

- Files: `lib/services/library_index.dart`,
  `lib/services/session_store.dart`, `lib/screens/library_screen.dart`,
  `lib/state/library_model.dart`
- Tests: `test/library_index_test.dart` (20),
  `test/perf/library_index_perf_test.dart` (6)

```
[perf] cold library open (index build): 1055ms
[perf] warm library open (index hit): 199ms
[perf] 100 index-level searches over 200 sessions: 54ms
[perf] deep scan of 200 transcripts: 96ms
[perf] phase-2 load of one session: 5ms
```

The warm path only stats each transcript, so it is independent of how
long the meetings are; the fixture uses 40-segment sessions because the
index never reads their contents.

### 5. (F1, item 16) Audio-synced transcript · **DONE**

Click a row → the audio seeks to that segment; the playing row is
highlighted and scrolled into view; following pauses the moment the user
scrolls by hand and resumes from the toolbar toggle. Playback speeds are
0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0×. Keyboard: **Space** or **K** play
/ pause, **←/→** 5 s, **J/L** 10 s, with a help dialog in the app bar.
The clock now shows hours, so minute 5 and minute 65 of a three-hour
recording no longer both read `05:00`.

- Files: `lib/screens/transcript_player_screen.dart`,
  `lib/widgets/transcript_view.dart`, `lib/utils/segment_lookup.dart`
- Tests: `test/segment_lookup_test.dart` (6), plus click-to-seek and
  follow-the-playhead cases in `test/perf/transcript_view_perf_test.dart`

### 6. (Item 17) Settings saves with visible feedback · **DONE**

Every setter goes through one `_apply()` that catches, **rolls the value
back**, and reports a `SettingsSaveFailure` carrying the value that
failed — so "Coba lagi" retries that value rather than whatever the
state has become. A switch that stays flipped after a failed write is
telling the user something untrue. Found and fixed while doing it:
turning Auto-Stop off never worked at all, because
`copyWith(autoStopMinutes: null)` keeps the old value.

- Files: `lib/state/settings_model.dart`, `lib/screens/settings_screen.dart`
- Tests: `test/settings_screen_test.dart` — a failed save shows the
  banner, leaves the switch where it was, and the retry lands.

### 7. (Item 19) Preflight + Diagnostik · **DONE**

`doctor.rs` has existed since the first release and nothing ever called
it. Now:

- `SetupOverlay` runs it **after the first frame**, so the app is on
  screen before the checks start. Warnings become a dismissible banner;
  only a hard failure blocks, and even then "Lanjutkan saja" is always
  there, because a preflight that is wrong about the machine must not
  lock a user out of their own recordings.
- Settings → "Diagnostik" re-runs the checks on demand and shows each as
  ✓ / ! / ✗ with its remediation.
- `doctor.rs` now speaks Indonesian — those strings go straight to the
  user — and checks two more things that answer most support questions:
  at least one audio input device, and free space on the library volume.
- **Found during the smoke test:** the model check joined
  `library_path + filename` only, while the downloader writes into an OS
  cache directory, so the very first launch put "model tidak ditemukan"
  in front of a perfectly working install. `model::find_model_file` now
  searches every directory the app itself searches.

- Files: `rust_core/src/doctor.rs`, `rust_core/src/model.rs`,
  `lib/services/preflight_service.dart`,
  `lib/screens/diagnostics_screen.dart`, `lib/widgets/setup_overlay.dart`,
  `lib/main.dart`
- Tests: `test/diagnostics_screen_test.dart` (8), 3 new Rust tests

### 8. (Item 20) Setup wizard · **DONE**

Reachable from Settings → "Jalankan Ulang Penyiapan", with a "Tutup" it
never needed when it only ran once. The A.6 platform bugs:

- Loopback guidance is per platform — BlackHole on macOS,
  PipeWire/PulseAudio monitors on Linux, WASAPI loopback on Windows —
  instead of telling a Linux user to `brew install` a macOS kernel
  extension.
- RAM is read from `/proc/meminfo`, `sysctl` or CIM, and labelled
  "perkiraan" only when it really is a guess
  (`lib/utils/system_specs.dart`).
- The tone test asks "Apakah Anda mendengar nadanya?" and reports a
  playback exception instead of asserting "Speaker berfungsi dengan
  baik" on the machine that most needs the warning.
- The model cards no longer quote accuracy percentages that nothing in
  this repository measures.
- Step 4's title matches its content ("4. Uji Suara"), and the device
  dropdowns finally render the labels they were being passed.

- Files: `lib/screens/setup_wizard_screen.dart`,
  `lib/utils/system_specs.dart`, `lib/screens/settings_screen.dart`
- Tests: `test/system_specs_test.dart` (4), wizard reachability in
  `test/settings_screen_test.dart`

### 9. (Item 21) Batch import · **DONE**

- Progress is real on **both** paths. `BatchProgressSnapshot` gained a
  per-file fraction; `transcribe_file` reports it every 30-second chunk,
  and `progressive_transcribe_file` — which published nothing, so
  turning Progressive Mode on froze the indicator — reports the same
  snapshot, counting both passes as the unit of work.
- The `state.firstWhere(...)` that threw a `StateError` and killed the
  batch when the queue was cleared mid-run is replaced by a nullable
  `entryFor()`.
- Per-file cancel and retry. A queued file never reaches the engine and
  the files behind a running one stop; the file already inside
  whisper.cpp is *not* claimed to be interruptible, because it isn't.
- `p.basename`/`p.extension` instead of `split('/')` and `split('.')`.
- The drop zone lists accepted formats and a 2 GB per-file limit that is
  actually enforced, shows each file's size, and highlights on drag-over.
- Language and model are chosen **before** processing, which is now an
  explicit "Mulai Transkripsi" instead of starting the moment a file
  lands — that is what made the pickers possible.

- Files: `lib/state/batch_upload_model.dart`,
  `lib/widgets/file_upload_zone.dart`, `rust_core/src/stt/file.rs`,
  `rust_core/src/api.rs`
- Tests: `test/batch_upload_model_test.dart` (16, +6)

### 10. Layout redesign (blueprint §4.1–4.3) · **DONE**

- A permanent left sidebar carries session history (newest first), its
  own search box and "Sesi baru"; the folder/document header icons are
  gone. It falls back to a drawer only below 700 px, i.e. below the
  app's own supported minimum window.
- The workspace shows the live recording or the selected session, with
  the player **embedded** rather than pushed as a route.
- One primary action: a big centred "Mulai Rekam" on the empty state,
  and "Ekspor" only once a transcript exists.
- Controls grouped into **Sesi** (title, mode, options menu — where
  "⚡ Cepat" moved) and **Perangkat** (mic and system-audio pills, each
  showing the device that will actually be recorded, with a picker and a
  live level).
- Ctrl+R and Ctrl+, unchanged; Ctrl+L focuses the sidebar search.

- Files: `lib/screens/main_screen.dart`,
  `lib/widgets/session_sidebar.dart`,
  `lib/widgets/session_controls.dart`, `lib/state/library_model.dart`
- Tests: `test/widget_test.dart` — sidebar present, single primary
  action, Sesi/Perangkat groups, Ctrl+L focus, and no overflow at
  800×600, 1280×720 and 1920×1080.

### 11. Settings two-pane + dynamic helper texts · **DONE**

Category list left, content right, using the full window (it was a
~380 px column in a full-width window). Seven categories; below 640 px
the rail becomes a chip strip. Helper texts are dynamic, and the GPU one
describes the **machine**: a new `gpu_capability()` reports whether a GPU
backend was compiled in, so a plain Linux build says "Build ini
dikompilasi tanpa dukungan GPU…" instead of claiming "Transkripsi
menggunakan GPU (Vulkan/CUDA/Metal)".

- Files: `lib/screens/settings_screen.dart`,
  `lib/widgets/settings_controls.dart` (replacing
  `lib/widgets/settings_side_panel.dart`), `rust_core/src/api.rs`
- Tests: `test/settings_screen_test.dart` (7)

## FRB codegen

Two regenerations, both with the scoped command from `ARCHITECTURE.md`
(`--rust-input crate::api,crate::error`), codegen 2.13.0 matching the
pinned crate version. No orphan files appeared under `lib/src/rust/`;
`git status` showed only `api.dart`, `stt/file.dart` and the three
`frb_generated*` files as modified. New surface: `GpuCapability` /
`gpu_capability()`, and a `progress` field on `BatchProgressSnapshot`.

## Smoke test

Release build, driven with `xdotool` on a 1920×1080 `Xvfb :9` — the
physical `:0` session is 1360×768, so a 1920×1080 window cannot be
captured there, and a 1280×720 window has its bottom 18 px pushed
off-screen. Launched with the prescribed capped-log form.

What was done and seen:

1. **Start-up.** Main window renders with the new layout; preflight runs
   after the first frame and shows nothing (all five checks pass). The
   first run *did* surface "Perlu diperiksa: Model transkripsi" — a real
   false positive, traced to the library-folder-only model lookup and
   fixed in `model::find_model_file`; re-verified clean afterwards.
2. **Recording.** "Mulai Rekam" → the sidebar pins "Sedang merekam", the
   system-audio pill shows a live level, and the capture badge says
   "Menunggu suara dari Mikrofon". Played
   `/home/kali/trareon-sprints/rapat_id.mp3` into the sink; after ~50 s
   two Indonesian segments appeared ("…diapkan laporan kewangan paling
   lambat hari jungat.", "Rapat berikutnya"), and **"Ekspor" appeared
   only at that point** — the empty-state rule working.
   → `docs/screenshots/sprint-2/live-transcript.png`
3. **Stop.** Confirmation dialog, then the capture-integrity dialog
   honestly reporting "Mikrofon: tidak ada suara sama sekali" (this
   machine's mic is silent) alongside "Audio sistem: 1 menit terekam".
   The new session appeared in the sidebar immediately, without a
   restart. → `docs/screenshots/sprint-2/capture-integrity.png`
4. **Click-to-seek (F1).** Selected that session in the sidebar; the
   player opened inside the workspace. Clicked the second transcript
   line: the clock jumped `00:00 → 00:03`, the slider moved, and that
   row became the highlighted active row.
   → `docs/screenshots/sprint-2/click-to-seek.png`
5. **Diagnostik.** Settings → Penyiapan & Diagnostik → Diagnostik: five
   checks, all ✓, all Indonesian, ending "Semua siap. Aplikasi bisa
   merekam." → `docs/screenshots/sprint-2/diagnostik.png`
6. **Wizard.** Settings → "Jalankan Ulang Penyiapan" opens it with
   "Tutup". Step 1 reads **RAM 16 GB** with no "perkiraan" label, which
   matches `free -m` (15 885 MB) — the `/proc/meminfo` path. Step 3
   shows the Linux guidance ("…lewat monitor sink PipeWire/PulseAudio —
   tidak perlu memasang apa pun") with the real device ids. Step 4 plays
   the tone and asks "Apakah Anda mendengar nadanya?" with Ya/Tidak.
   → `docs/screenshots/sprint-2/wizard-audio-linux.png`,
   `docs/screenshots/sprint-2/wizard-tone-test.png`
7. **Settings two-pane** → `docs/screenshots/sprint-2/settings-two-pane.png`

`pkill -9 -x transcribe` afterwards.

### Layout screenshots

| Size | Path |
|---|---|
| 800×600 | `docs/screenshots/sprint-2/layout-800x600.png` |
| 1280×720 | `docs/screenshots/sprint-2/layout-1280x720.png` |
| 1920×1080 | `docs/screenshots/sprint-2/layout-1920x1080.png` |

At 800×600 the first capture showed "Mulai Rekam" half below the fold
(the control groups take ~340 px of 600). The empty state now collapses
its illustration and spacing below 300 px of workspace height, so the
primary action is fully visible; re-captured after the fix.

## Known gaps

- **Cancelling a file mid-transcription is not possible.** whisper.cpp
  runs a chunk to completion and the FRB call is a single `await`. The
  UI cancels queued files and stops the ones behind a running one, and
  says so rather than pretending otherwise. Real cancellation needs a
  cancellation token threaded through the engine — not attempted here.
- **The 2 GB import limit is a policy we chose**, not a measured
  breaking point. It is enforced and advertised consistently, but no
  test establishes that 2.1 GB actually fails to decode.
- **The `/proc/meminfo` and CIM RAM paths are only exercised on Linux**
  here. The macOS `sysctl` and Windows PowerShell branches are written
  and analysed but unverified on those platforms.
- **`gpu_capability()` reports what was compiled in, not what the GPU
  can do.** A build with `gpu-vulkan` on a machine with no usable Vulkan
  device will still say the backend is available. Detecting that needs a
  probe at model-load time.
- **Progress on the progressive import is per chunk of two passes**, so
  it advances in ~1/(2·chunks) steps; for a file under 30 s it jumps
  0 → 50 → 100 %.
- **Accessibility (item 25) is untouched** — it is Sprint 3's, and the
  new sidebar and control groups will need the same `Semantics` pass as
  the rest.
- **i18n (item 26) is untouched.** All new strings are hardcoded
  Indonesian; no ARB infrastructure exists in this branch to put them in.
- The smoke test's microphone channel is silent on this machine, so the
  mic capture path was exercised only to the point of the (correct)
  "tidak ada suara sama sekali" warning.

---

# Sprint 2 fix round — CI failures

Independent verification of `sprint/02-scale` failed on two jobs. Both
root causes are fixed below; neither was fixed by weakening a test or
disabling a lint.

## 1. `flutter analyze` — 21 errors in four test files · **DONE**

**Symptom.** CI reported `uri_does_not_exist` for
`test/fixtures/large_session.dart` plus cascading `undefined_function` /
`undefined_identifier` for `buildBenchmarkSegments`,
`writeBenchmarkLibrary`, `kBenchmarkSegmentCount`,
`kBenchmarkSessionCount` and `kBenchmarkDurationSeconds` across
`test/perf/library_index_perf_test.dart`,
`test/perf/session_ingest_perf_test.dart`,
`test/perf/transcript_view_perf_test.dart` and
`test/segment_lookup_test.dart`.

**Root cause.** Sprint 2 wrote the benchmark helper to
`test/fixtures/large_session.dart`. `test/fixtures/` is gitignored, and
correctly so: it holds the WAV artifacts that
`cargo run --bin gen_fixtures` generates. The helper was therefore never
committed. Every local gate stayed green because the local gate only
ever sees the working tree, where the file exists; CI checks out the
commit, where it does not. Confirmed empirically — `git archive HEAD`
on the pre-fix commit contains no `test/fixtures/` entries at all.

**Fix.** Hand-written test sources now live in `test/support/`. The
helper moved to `test/support/large_session.dart` with a comment
explaining the distinction, and the four imports were updated.

**Regression gate.** `test/tracked_sources_test.dart` asserts that no
Dart source under `lib/`, `test/` or `integration_test/` is gitignored,
so this class of green-locally / red-on-CI failure cannot recur. It
probes `git rev-parse --is-inside-work-tree` (not `git --version` — that
succeeds in a source export, where every `check-ignore` then returns
128) and skips loudly when the invariant is not observable.

Verified on all three paths:

| Situation | Expected | Observed |
| --- | --- | --- |
| Repo, clean tree | pass | `+1: All tests passed!` |
| Dart file placed under `test/fixtures/` | fail | `Actual: ['test/fixtures/_probe.dart']` |
| Non-git source export | skip | `~1: All tests skipped.` |

- Files: `test/support/large_session.dart` (moved from `test/fixtures/`),
  `test/tracked_sources_test.dart` (new),
  `test/perf/library_index_perf_test.dart`,
  `test/perf/session_ingest_perf_test.dart`,
  `test/perf/transcript_view_perf_test.dart`,
  `test/segment_lookup_test.dart`, `rust_core/src/bench_fixture.rs`
  (doc comment), `docs/SPRINT-REPORTS.md`
- Tests added: 1 (`tracked_sources_test.dart`)

## 2. macOS packaging — `hdiutil: create failed - Resource busy` · **DONE (unverified on macOS)**

**Root cause.** `hdiutil create -srcfolder X -format UDZO` is a compound
operation: it builds a temporary read/write image, attaches it, copies
`X` in, detaches it, then compresses. "Resource busy" is that detach
losing a race against a process still holding a file on the freshly
mounted volume — on GitHub runners, Spotlight's `mds` indexing the
~690 MB of models the script had just bundled.

**Fix**, in `scripts/package_macos.sh`, cheapest change first:

1. Stage the signed bundle into `$TMPDIR` (`/var/folders/...`, which is
   excluded from Spotlight indexing) with `ditto` — not `cp`, so the
   ad-hoc signature survives — instead of imaging the live Xcode build
   tree.
2. Split create from compress: build `UDRW`, then `hdiutil convert` to
   `UDZO`. Each step is then simple enough for a retry to mean something.
3. Retry the create up to three times, detaching any volume a failed
   attempt left mounted first — otherwise the retry trips over the
   previous attempt's mount and fails identically.

`-srcfolder` still points at the `.app` bundle, not at the staging
directory, so the DMG's internal layout is unchanged.

- Files: `scripts/package_macos.sh`
- Tests added: none — this is a shell script for a platform not
  available here. See known gaps.

## Verification gate

    cd rust_core && cargo fmt --check          → clean
    cargo clippy --all-targets -- -D warnings  → exit 0, zero warning/error lines
    cargo test --lib                           → 315 passed; 0 failed; 0 ignored
    flutter analyze                            → No issues found! (ran in 4.4s)
    flutter test                               → 334 tests, All tests passed!
    flutter build linux --release              → ✓ Built build/linux/x64/release/bundle/transcribe

**CI-equivalent check.** The whole point of this round is that a green
working tree proved nothing, so the fix was verified the way CI sees it:
`git archive HEAD | tar -x` into a clean directory, then the Flutter gate
run there: `flutter analyze` → `No issues found!`, `flutter test` → 333
passed, 1 skipped. That export is a pristine checkout of the commit, with
no untracked files to mask a missing one. The one skip is
`tracked_sources_test.dart` itself: the export is not a git work tree, so
the ignore rules are unobservable and it skips by design. In the repo the
same suite is 334 passed, 0 skipped.

## Smoke test

Release build launched on `:0` per the standard recipe. The 1280x720
window came up showing Sprint 2's redesigned main screen: permanent
session sidebar with three real sessions from the library
(`Sesi 2026-10-01 02:18` · 49 detik · 7 segmen, `Sesi Pendek Tanpa
Transkrip` · 0 segmen, `Sesi 2026-10-01 05:23` · 5 detik · 2 segmen),
the session/mode/device header with both ALSA devices resolved, and the
"Siap merekam" empty state with the single primary "Mulai Rekam" action.
`/tmp/trareon_smoke.log` was empty — no stderr output. Process killed
with `pkill -9 -x transcribe` afterwards.

No capture run was repeated this round: the fix round touches no file
under `lib/`. The only non-test, non-docs change is a macOS shell
script, and `rust_core/src/bench_fixture.rs` changed by one doc-comment
line. The launch above is a regression check that the release bundle
still starts, not a re-verification of Sprint 2's capture claims.

## Known gaps

- **The macOS DMG fix is unverified.** There is no macOS machine here;
  the script is syntax-checked (`bash -n`) and the reasoning is stated
  above, but whether "Resource busy" is gone can only be established by
  the CI job. If it recurs, the next thing to try is disabling Spotlight
  on the staging volume (`mdutil -i off`) — the retry loop will make the
  failure mode visible in the log either way.
- **The retry sleeps 15 s between attempts**, so a genuinely broken
  packaging step now takes ~30 s longer to fail than before.
- Everything in Sprint 2's own "Known gaps" list above still stands;
  this round fixed CI, not product scope.

---

# Sprint 3 report — branch `sprint/03-indonesia`

> Theme: make the Indonesian-first claim real. The blueprint's §4 feature
> gap (F2 notulen, F3 kamus istilah, F5 transkrip ulang, F8 template, F9
> bookmark) plus audit items 22–29.

11 commits on top of `origin/main`; 105 files changed, +15 403 / −682.

## Verification gate

All green, run on the final commit (`d5a4ba8`) with a clean working tree.

```
$ cd rust_core && cargo fmt --check
(no output)

$ cargo clippy --all-targets -- -D warnings
Finished `dev` profile [unoptimized + debuginfo] target(s)

$ cargo test --lib
test result: ok. 376 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out

$ flutter analyze
No issues found!

$ flutter test
02:08 +436: All tests passed!

$ flutter build linux --release
✓ Built build/linux/x64/release/bundle/transcribe
```

Test counts moved from **315 → 376** Rust unit tests (+61) and
**333 → 436** Dart tests (+103).

Ten new Dart test files account for 101 of those: `enhance_queue_test`
(21), `notulen_form_test` (13), `glossary_settings_test` (11),
`localization_test` (10), `theme_tokens_test` (10), `text_scaling_test`
(9), `accessibility_test` (8), `bookmark_test` (8),
`summary_template_editor_test` (8), `copy_inventory_test` (3). On the Rust
side the sprint's modules carry `glossary` 26, `summary` 37,
`export::notulen` 22, `bookmark` 3.

## Per item

### Item 22 · Kamus istilah / `initial_prompt` (F3) · **DONE**

Glossary terms are fed to Whisper as `initial_prompt`, with a per-session
list layered over a global dictionary in Settings. Session terms win.

Files: `rust_core/src/glossary.rs`, `rust_core/src/stt/`,
`rust_core/src/settings.rs`, `lib/widgets/glossary_settings_section.dart`
(global dictionary in Settings), `lib/widgets/session_controls.dart`
(the per-session "Istilah rapat" dialog).
Tests: `glossary` 26 Rust, `test/glossary_settings_test.dart` 11 Dart.
Commits: `9d48c67` (engine), `e10a446` (UI).

### Item 23 · Notulen Rapat DOCX per Tata Naskah Dinas (F2) · **DONE**

`NotulenForm` + `draft_from_summary` + `to_docx_bytes`: kop surat,
identity table, Pembahasan / Keputusan / Tindak Lanjut, signature block,
and a Ringkas variant that drops the letterhead. Prefilled from the
`NotulenRapat` summary template so the user edits rather than types.

Files: `rust_core/src/export/notulen.rs`, `lib/widgets/notulen_dialog.dart`,
`lib/widgets/notulen_settings_section.dart`, `scripts/validate_notulen.py`.
Tests: `export::notulen` 22 Rust, `test/notulen_form_test.dart` 13 Dart,
plus an independent read-back (below).
Commits: `9d48c67`, `995ff08`, `d5a4ba8`.

**Independent verification.** The engine asserting on its own
WordprocessingML proves little — the writer and the assertions share
assumptions. `scripts/validate_notulen.py` opens the output with
python-docx, a different OOXML implementation. On a generated document:
32 paragraphs, 3 tables, every required heading and identity field
present, and both glossary terms (`PPBJ`, `RKAKL`) survived into the text:

```
$ python3 scripts/validate_notulen.py /tmp/notulen_sample.docx \
    --expect PPBJ --expect RKAKL
    paragraphs: 32  tables: 3
    body characters: 842
    expected terms found: 2/2 ['PPBJ', 'RKAKL']
OK    the document opens and carries every required section
```

### Item 24 · Bookmark saat merekam (F9) · **DONE**

Ctrl+B marks the current moment during recording, with an optional note;
markers survive into the player and become `Poin Penting` in the notulen.
`retainAlignedBookmarks` drops rather than clamps a marker that falls past
the end of a re-transcribed transcript.

Files: `rust_core/src/export/mod.rs` (the `Bookmark` type),
`rust_core/src/export/notulen.rs` (`poin_penting_from_bookmarks`),
`lib/widgets/bookmark_bar.dart`, `lib/screens/transcript_player_screen.dart`.
Tests: `bookmark` 3 Rust, `test/bookmark_test.dart` 8 Dart.
Commits: `e10a446`, `995ff08`.

### Item 25 · Aksesibilitas · **DONE**

`Semantics` across the main surfaces, a live region that announces new
transcript rows as they arrive, 48 px minimum touch targets, and the dead
`StreamToggle` label bug fixed (it compared its visible label against the
English literals `'Mic'`/`'Speaker'`, so translating the label silently
broke the screen-reader announcement — it now takes a `StreamSource` enum).

Two real defects fell out of writing the tests: `TranscriptPlayerScreen`
had icon buttons under 48 px, and the live-region announcer counted
recovered sessions as "new rows" on load, so a recovery read the whole
transcript aloud.

Files: `lib/widgets/*`, `lib/screens/*`.
Tests: `test/accessibility_test.dart` 8, `test/text_scaling_test.dart` 9
(1.5× scale at the 800×600 minimum window).
Commit: `ce22c02`.

### Item 26 · Infrastruktur i18n (ARB + `flutter_localizations`) · **PARTIAL**

**Done:** the infrastructure, working end to end. `l10n.yaml` with
`app_id.arb` as the *template* (so a new string is written in Indonesian
and English is what shows up as incomplete), `app_en.arb` at full key
parity (41/41), `flutter_localizations` + `intl`, `generate: true`,
generated `AppLocalizations` wired into both `MaterialApp`s, and
`_AlreadyRunningApp` converted to be a real consumer so the path is
exercised rather than merely plumbed.

**Not done:** extraction of the remaining screens. The audit sizes this
item **L** and the blueprint schedules it as a *jalur paralel*; 41 keys are
in the ARB, the rest of the UI is still hardcoded Indonesian literals. The
app is not yet switchable to English at runtime, and there is no UI
language selector (`AppSettings.language` is the *transcription* language,
a different setting — the ARB keys for the selector exist but nothing
reads them yet).

Two findings worth recording:

* `flutter gen-l10n` emits `supportedLocales` alphabetically, so Flutter's
  default resolution falls back to `supportedLocales.first` — **English** —
  for any system locale that is neither `id` nor `en`. For an
  Indonesian-first product that is backwards. `resolveLocale` in
  `main.dart` makes the fallback Indonesian; five of the ten tests in
  `localization_test.dart` pin that behaviour.
* The generated Dart is **committed**, like the FRB bindings in
  `lib/src/rust/`. Gitignoring it reproduces exactly the failure
  `tracked_sources_test.dart` was written to catch — green locally, then CI
  fails with `uri_does_not_exist` because the import has no file behind it.
  That test caught it in this sprint, which is the second time it has paid
  for itself.

Files: `l10n.yaml`, `lib/l10n/`, `lib/main.dart`, `pubspec.yaml`.
Tests: `test/localization_test.dart` 10.
Commit: `124a20f`.

### Item 27 · Flight recorder · **DONE**

Initialised at startup, lifecycle transitions logged as metadata, and
"Ekspor Log Diagnostik" on the Diagnostik screen writes a `.zip` of the
rotated logs plus the doctor report — with the copy stating plainly that
no transcript or audio is in it. The machinery already existed and nothing
had ever called it.

Files: `lib/services/flight_recorder_service.dart`,
`lib/screens/diagnostics_screen.dart`, `lib/main.dart`.
Commit: `eb385af`.

### Item 28 · Transkrip ulang otomatis dengan model akurat (F5) · **DONE**

After the meeting, a session transcribed with the quick model is
re-transcribed with the accurate one in the background. The old transcript
stays in place until the new one succeeds; a failed pass leaves it exactly
as it was. Hand-renamed speakers survive a slight timestamp shift;
an engine label never overrides the accurate pass's labelling. The queue
pauses while a recording is running.

A test-only defect was fixed properly rather than papered over: six cases
waited a fixed 50 ms for async file I/O and were racy on a loaded machine.
`EnhanceQueueNotifier` now exposes an `idle` future and the tests await it.

Files: `lib/state/enhance_queue_model.dart`, `lib/widgets/enhance_queue_view.dart`.
Tests: `test/enhance_queue_test.dart` 21.
Commits: `e10a446`, `567d748`.

### Item 29 · Notarisasi macOS, `.deb`/AppImage, SHA256 · **DONE (Linux verified, macOS unverifiable here)**

`scripts/package_deb.sh` produces a real amd64 package: bundle in `/opt`
(the shape Chrome and VS Code use, because the binary needs its `lib/` and
`data/` siblings), wrapper in `/usr/bin`, `.desktop` entry with
`StartupWMClass` so the window matches the launcher, 256×256 hicolor icon,
and a `Depends` line carrying the `t64` alternatives so it installs on both
Ubuntu 22.04 and 24.04. Models are deliberately excluded (142 MB + 548 MB
would make a 700 MB package); `--with-models` overrides for air-gapped use.

`scripts/package_macos.sh` signs with a Developer ID and notarizes when
`MACOS_SIGN_IDENTITY` is set, and still produces an ad-hoc signed DMG when
it is not. `release.yml` resolves secret availability into a step output
first, because secrets cannot be read in a job-level `if:` — a fork with no
Apple account must still get a release.

Every build job now uploads to a workflow artifact and a single `publish`
job writes one `SHA256SUMS` covering every file. Per-job uploads made a
complete manifest impossible: no job could see the other platforms'
outputs.

**Verified locally** against the real release bundle:

```
$ bash scripts/package_deb.sh
  deb:  dist/trareon-transcribe_1.0.0_amd64.deb
  size: 17M

$ dpkg-deb --info dist/trareon-transcribe_1.0.0_amd64.deb
 Depends: libc6 (>= 2.34), libgtk-3-0 (>= 3.24) | libgtk-3-0t64 (>= 3.24),
  libglib2.0-0 (>= 2.66) | libglib2.0-0t64 (>= 2.66),
  libasound2 | libasound2t64, libpulse0, zlib1g (>= 1:1.2.11)

$ desktop-file-validate .../trareon-transcribe.desktop
(hint only — see Known gaps)
```

Files: `scripts/package_deb.sh`, `scripts/package_macos.sh`,
`.github/workflows/release.yml`, `DISTRIBUTION.md`.
Commit: `73d21fa`.

### F8 · Template ringkasan yang bisa disunting · **DONE**

Built-in templates can be duplicated and edited, custom ones created from
scratch, and either deleted; a built-in is copied rather than mutated.

Files: `lib/widgets/summary_template_editor.dart`, `rust_core/src/summary.rs`.
Tests: `test/summary_template_editor_test.dart` 8, `summary` 37 Rust.
Commits: `995ff08`, `431cc24`.

### §4.4 · Bahasa manusia, bukan jargon · **DONE**

`VAD → Abaikan jeda sunyi`, `Echo Dedupe → Hapus suara ganda`,
`Progressive Mode → Cepat dulu, lalu diperhalus`, `API key → Kunci API`,
`Action Items → Tindak Lanjut`, and the rest of the audit's A.12 table.
`test/copy_inventory_test.dart` reads `lib/` and fails on a known English
UI word or internal acronym, stripping Dart interpolations first so
`${settings.autoStopMinutes}` is not read as "Settings". It is a blocklist
with a suggested replacement per entry, deliberately not a general English
detector — that would flag Markdown, Ollama and DOCX and be silenced.

Commit: `eb385af`.

### Design tokens · **DONE**

Colour moved into the theme with a lint that keeps it there.
Tests: `test/theme_tokens_test.dart` 10. Commit: `3ba038b`.

## Smoke test

Release build launched on `:0` per the standard recipe, 1280×720 window.

**Main screen.** Came up in full Indonesian with no English leakage:
sidebar "Sesi baru" / "Cari sesi… (Ctrl+L)" over three real library
sessions (`Sesi 2026-10-01 02:18` · 49 detik · 7 segmen, `Sesi Pendek
Tanpa Transkrip` · 0 segmen, `Sesi 2026-10-01 05:23` · 5 detik · 2
segmen); the session header with Webinar / Rapat Online / Rapat Offline,
the "Akurat" model picker and the "Istilah rapat" button; both ALSA
devices resolved under "Perangkat" (Mikrofon + Suara sistem, both
toggled on); and the "Siap merekam" empty state with the single primary
"Mulai Rekam" action and its `Ctrl+R` hint.

**Glossary (F3/item 22).** Clicking "Istilah rapat" opened the dialog
titled "Istilah khusus rapat ini" with the helper line "Satu istilah per
baris: nama peserta, singkatan, nama program. Diutamakan di atas kamus di
Pengaturan." — and it was **populated with terms persisted from an earlier
run** (`Pak Budi Santoso`, `SPBE`, `RKAKL`), which is the persistence path
working, not a fixture. Actions read "Batal" / "Simpan".

`/tmp/trareon_smoke.log` was **0 bytes** — no stderr at all, including
from the newly added localisation delegates. Process killed with
`pkill -9 -x transcribe` afterwards.

No capture run was performed this round. The sprint's only change to the
live capture path is the glossary `initial_prompt`, which is covered by 26
Rust tests; the UI changes smoke-tested above are the localisation wiring
and the dialogs.

## Known gaps

- **Item 26 is PARTIAL by design and is the main one.** The infrastructure
  works, but only 41 strings are in the ARB and there is no runtime
  language switch. Finishing it means extracting every remaining screen and
  adding a UI-language setting distinct from the existing transcription
  `language` field. The audit sizes it **L**; it is the one item in this
  sprint that is not closed.
- **macOS signing and notarization are unverified.** There is no macOS
  machine here. `scripts/package_macos.sh` is syntax-checked (`bash -n`)
  and the secret-gating logic is reasoned through above, but whether a
  Developer ID build actually notarizes can only be established by CI with
  the secrets present. The ad-hoc path is the one that has been exercised.
- **The AppImage is CI-only in practice.** `appimagetool` needs
  `APPIMAGE_EXTRACT_AND_RUN=1` on a host without FUSE; this was not built
  locally this round, only the `.deb`.
- **`desktop-file-validate` emits one hint**, not an error: `Categories`
  lists both `AudioVideo` and `Office` as main categories, so the app may
  appear twice in some application menus. Kept deliberately — a notulis
  looks for this tool under Office, and a transcription tool belongs under
  AudioVideo. Exit code is 0, so CI is unaffected.
- **The two perf tests are load-sensitive.** `library_index_perf_test` and
  `transcript_view_perf_test` failed once during this sprint when the full
  suite ran concurrently with a release build on this weak CPU, and passed
  in isolation and in every uncontended full run (`436 passed`). They
  assert wall-clock budgets, so they are measuring the machine as much as
  the code. Worth converting to a relative/scale-factor assertion rather
  than an absolute millisecond budget.
- **Glossary accuracy is not measured.** The terms demonstrably reach
  Whisper as `initial_prompt` and survive into the exported notulen, but no
  before/after word-error-rate comparison was run on real Indonesian audio,
  so "cheapest large accuracy win" remains the audit's claim rather than a
  measured result here.

---

# Penggabungan origin/main ke sprint/03-indonesia

Dikerjakan setelah laporan Sprint 3 di atas, saat `origin/main` sudah berisi
PR #9 (`faa3f36`, "port orphaned recording fixes + modernise GitHub
Actions"). Merge yang tertinggal setengah jalan diselesaikan dengan menjaga
niat kedua sisi.

## Berkas yang bentrok dan cara penyelesaiannya

**`.github/workflows/release.yml` — DONE.** Struktur sprint ini
dipertahankan: setiap job build mengunggah *workflow artifact*, lalu satu job
`publish` mengumpulkan semuanya, menulis satu `SHA256SUMS` yang mencakup
seluruh berkas, dan mengunggahnya sekaligus (butir 29). Di atas struktur itu
dipasang modernisasi dari main: runner Ubuntu dipaku ke `ubuntu-24.04`
(bukan `ubuntu-latest`) di `source-release`, `build-linux`, dan `publish`;
`softprops/action-gh-release` dinaikkan ke `v3` di job `publish` — satu-satunya
tempat yang masih memanggilnya. `actions/checkout@v7` dan
`Swatinem/rust-cache@v2.9.2` dari main masuk tanpa bentrok.

Satu langkah dari main sengaja **tidak** dibawa: "Generate checksum" per-job
yang menulis `*.sha256` di sebelah arsip sumber. Manifes tunggal di `publish`
sudah mencakup arsip itu, dan `publish` justru menghapus `*.sha256`
per-platform sebelum menghitung — kalau tidak, berkas checksum ikut
ter-checksum di dalam manifes. Alasan ini ditulis sebagai komentar di job
`source-release` agar tidak "diperbaiki" kembali nanti.

**`lib/state/session_model.dart` — DONE.** Penjaga start-ganda dari main
dipakai utuh: `_launching` diset sinkron sebelum `await` pertama dan
dibersihkan di `finally`, jadi klik ganda pada Mulai (atau Ctrl+R ditahan)
tidak lagi membuat sesi Rust kedua yang terlantar. Reset
`bookmarks: const []` milik sprint ini tetap ada di `copyWith` pembuatan sesi
baru — penanda rapat sebelumnya tidak boleh ikut ke rapat baru karena
timestamp-nya sudah tidak ada.

Bagian `_resolveDevices` menggabung bersih ke versi main: hint speaker
dilewatkan apa adanya, termasuk `null`. Itu memang perbaikannya — hint kosong
yang membuat engine menyelesaikan sendiri audio sistem (ScreenCaptureKit di
macOS, `.monitor` sink default di Linux, render device default di Windows).
Tebakan nama di sisi Dart justru yang dulu mematikannya.

**`lib/widgets/empty_state.dart` — DONE.** Tata letak compact + scroll dari
main (di 800x600 panel transkrip hanya ~140px, sedangkan tata letak penuh
butuh ~220px, sehingga dulu muncul garis overflow kuning-hitam) digabung
dengan semantik aksesibilitas sprint ini: ikon dibungkus `ExcludeSemantics`
karena hanya mengulang judul, dan judul ditandai `Semantics(header: true)`.
Keduanya kini hidup di dalam `LayoutBuilder` yang sama; ikon hanya dirender
saat tidak compact, sesuai aturan main.

**`test/session_double_start_test.dart`** (berkas baru dari main) perlu
`glossary: kEmptyGlossary` pada `SessionConfig`-nya plus impor
`bridge_service.dart`: cabang ini sudah menambahkan glosarium sebagai
parameter wajib. Tanpa itu `flutter analyze` gagal.

Berkas lain dari main (`.github/dependabot.yml`, `ci.yml`,
`docs/REPO-HEALTH-REPORT.md`, `main_screen.dart`, `bridge_service.dart`,
empat berkas Rust, dan tiga berkas tes) tergabung otomatis tanpa bentrok.

## Gate verifikasi (setelah merge, semua hijau)

```
cd rust_core && cargo fmt --check            → bersih
cargo clippy --all-targets -- -D warnings    → bersih (tanpa peringatan)
cargo test --lib                             → 381 passed; 0 failed; 0 ignored
flutter analyze                              → No issues found!
flutter test                                 → All tests passed! (455 tes)
flutter build linux --release                → ✓ Built build/linux/x64/release/bundle/transcribe
```

Jumlah tes Rust naik dari 376 (laporan Sprint 3) ke 381 karena tes port dari
main: `sck_handler_registration` dan `wants_zero_setup_capture`.

## Smoke test aplikasi nyata

Build rilis dijalankan di DISPLAY=:0 (log dibatasi ke
`/tmp/trareon_smoke.log`).

1. **1280x720, idle.** Workspace kosong tampil penuh — ikon mikrofon, "Siap
   merekam", dua baris penjelasan, tombol "Mulai Rekam". Tidak ada garis
   overflow.
2. **Diperkecil ke 800x600.** Ikon hilang, teks dan tombol tetap terbaca,
   tetap tanpa garis overflow — persis aturan compact yang digabung tadi.
   Panel transkrip juga memakai `EmptyState` compact ("Belum ada transkrip")
   tanpa ikon.
3. **Ctrl+R dua kali berselang 2 detik.** Sidebar hanya menampilkan satu
   "Sedang merekam", tidak ada sesi kedua — penjaga `_launching`/lifecycle
   bekerja.
4. **Audio uji** `rapat_id.mp3` diputar ke sink lewat `paplay`. VU "Suara
   sistem" bergerak; setelah pemutaran kedua, transkrip muncul: **2 segmen**,
   "Hari ini kita membahas anggaran kuartal 4. Budi bertanggung jawab
   menyelesaikan." — jalur capture → VAD → Whisper → UI utuh setelah merge.
   Model "Akurat" (q5) di CPU lemah ini memang butuh ~2 menit untuk klip 15
   detik, jadi transkrip baru muncul setelah penantian itu.
5. **Berhenti.** Dialog konfirmasi menyebut "2 segmen transkrip"; setelah
   dikonfirmasi, sesi tersimpan dan muncul di sidebar ("Sesi 2026-10-04
   10:12 · 8 detik · 2 segmen"). Laporan akhir sesi jujur: mikrofon tidak
   menghasilkan suara sama sekali (memang tidak ada mic di mesin ini) dan
   audio sistem 93% senyap (benar — 2×15 detik bicara dalam sesi 6 menit).
6. `pkill -9 -x transcribe` setelahnya.

## Celah yang diketahui

- Jalur notarisasi macOS di `release.yml` tetap belum terbukti; merge ini
  tidak mengubah statusnya, hanya memindahkan job-nya ke runner yang dipaku.
- `actions/upload-artifact` / `download-artifact` dibiarkan di `v4`. Keduanya
  tidak ada di diff main, jadi tidak ikut dinaikkan di sini.

---

# Putaran perbaikan CI — Sprint 3 (`sprint/03-indonesia`)

Verifikasi independen / CI GitHub gagal setelah merge. Dua akar masalah
ditemukan, keduanya pada **tes**, bukan pada kode produksi — dan keduanya
sejenis: tes yang mengukur lingkungan alih-alih perilaku yang diklaimnya.
Tidak ada tes yang dilemahkan dan tidak ada lint yang dimatikan.

## 1 · `test/enhance_queue_test.dart` — 5 tes gagal di CI · **DONE**

**Gejala di CI.** `450 tests passed, 5 failed`, semuanya di grup
`EnhanceQueueNotifier`: `Expected: <1>` (jumlah panggilan mesin), 
`Expected: ['PPBJ']` (glosarium), dan `Bad state: No element`.

**Akar masalah.** `EnhanceQueueNotifier.considerSession()`
(`lib/state/enhance_queue_model.dart:262`) menolak mengantre apa pun kecuali
model akurat terpasang, lewat `isModelAvailable(kAccurateModelId, ...)`.
Fungsi itu memeriksa `$HOME/Library/Caches/TrareonTranscribe/models/` tanpa
syarat. Di mesin ini berkas `ggml-large-v3-turbo-q5_0.bin` (574 MB) ada, jadi
tes lulus; runner CI tidak pernah mengunduhnya, jadi tidak ada job yang
terantre dan setiap asersi antrean kehilangan objeknya. Bukan kegagalan
produksi: gerbang "model harus terpasang" memang benar.

**Reproduksi lokal** (membuktikan akar masalah, bukan menduganya):
`HOME=/tmp/fakehome flutter test test/enhance_queue_test.dart` menghasilkan
**5 kegagalan yang persis sama** dengan CI.

**Perbaikan.** Tes kini menanam berkas model tiruan di dalam direktori temp
yang sudah dipakainya sebagai `libraryPath`. Mesinnya tiruan, jadi isinya
tidak pernah dibaca — `isModelAvailable()` hanya memeriksa keberadaan berkas.
Nama berkas diambil dari `modelPathForId()`, bukan ditulis literal, supaya
tidak bisa melenceng dari pemetaan yang dipakai gerbang produksi.

Dua tes yang **lulus di CI karena alasan yang salah** juga diperbaiki: "a
session with no audio is never queued" dan "an already-enhanced session is
not queued again" sebelumnya lulus karena modelnya hilang, bukan karena
gerbang yang mereka klaim uji. Keduanya sekarang menanam model, jadi
penolakan yang mereka amati hanya bisa berasal dari gerbang audio dan
gerbang "sudah pernah". Cakupan bertambah, bukan berkurang.

- Berkas: `test/enhance_queue_test.dart` (+24 baris, pembantu
  `installAccurateModelStub()` dan tiga pemanggilannya)
- Commit: `a2e44e5`

## 2 · `journal::tests::a_three_hour_journal_writes_and_replays_linearly` · **DONE**

**Gejala.** Gagal acak di `cargo test --lib`: `380 passed; 1 failed`, dengan
`replaying 4x the segments took 12.7x as long — that is the shape of a
quadratic replay, not a linear one`. Lulus sendirian, gagal di suite penuh.

**Akar masalah.** Yang diukur yang salah, bukan algoritmanya. Tes mengambil
**satu** sampel wall-clock per ukuran lalu membaginya, dengan ambang 10,0
padahal nilai linear yang diharapkan 4,0 — kelonggaran hanya 2,5×. Dengan 381
tes berbagi 4 inti, utas yang di-*deschedule* menumpuk wall-clock tanpa
mengerjakan apa pun, dan inflasi itu **tak berbatas atas**.

**Bukti terukur** (15 jalanan di bawah 6 proses pemakan CPU): replay identik
berbiaya 94 ms sampai 468 ms, dan kedua ukuran pernah **terbalik total** —
1250 segmen 901 ms melawan 5000 segmen 172 ms. Tidak ada ambang atau
rata-rata yang bisa menyelamatkan rasio wall-clock seperti itu; dua upaya
pertama (fastest-of-5, lalu equal-work di atas wall-clock) masih gagal
masing-masing pada 10,3× dan 3,2×. Itu menunjuk ke desain pengukurannya,
bukan ke konstantanya.

**Perbaikan** — dua langkah, keduanya menghapus sumber derau alih-alih
merata-ratakannya:

1. **Equal-work, bukan equal-calls.** Jurnal kecil diputar `SIZE_FACTOR`
   kali melawan satu lintasan jurnal besar, jadi kedua sisi mencerna jumlah
   segmen yang sama dan berdurasi sama. Linear ⇒ biaya setara; kuadratik ⇒
   yang besar `SIZE_FACTOR`× lebih mahal. Tidak ada lagi baseline yang
   bergantung ukuran untuk dikalibrasi.
2. **Waktu CPU utas** (`CLOCK_THREAD_CPUTIME_ID` via `libc`, yang sudah jadi
   dependensi unix) untuk asersi bentuk kompleksitas. Jam itu tidak berdetak
   saat utas diparkir, yaitu persis derau yang membuat tes ini goyah.

Anggaran latensi (`< 2 s`) tetap diukur dengan wall-clock, karena yang
dijanjikannya memang wall-clock yang ditunggu pengguna; kelonggarannya lebih
dari satu orde besaran, jadi kontensi tidak bisa menjangkaunya. Jalur
non-unix memakai `Instant` sebagai pengganti (`cargo test --lib` adalah job
Linux di CI).

**Verifikasi bahwa tesnya masih bergigi** — bukan sekadar lulus: regresi
kuadratik disuntikkan sengaja ke `replay()` (satu pemindaian linear per
baris, `order.iter().position(...)`). Tes **menangkapnya pada 2,6×** dengan
pesan yang dimaksud, sementara jalanan bersih berkumpul di ≤ 1,29×. Suntikan
sudah dicabut kembali (tidak ada sisa `TEMP` di pohon kerja).

- Berkas: `rust_core/src/journal.rs` (pembantu `thread_cpu_micros()`,
  `Cost`, `replay_cost()`, `cheapest_cost()`; `replay()` sendiri **tidak**
  diubah)
- Commit: `75e4385`

## Gate verifikasi (semua hijau)

```
cd rust_core && cargo fmt --check          → FMT OK
cargo clippy --all-targets -- -D warnings  → Finished, 0 peringatan
cargo test --lib                           → 381 passed; 0 failed  (6 jalanan berturut)
flutter analyze                            → No issues found! (12,7 s)
flutter test                               → 455 passed            (sebelumnya 450 + 5 gagal)
flutter build linux --release              → ✓ Built build/linux/x64/release/bundle/transcribe
```

**Gate tambahan, dalam kondisi CI yang sebenarnya.** Karena akar masalah
nomor 1 adalah ketergantungan lingkungan, suite penuh dijalankan ulang
dengan model akurat tidak terlihat:

```
HOME=/tmp/fakehome flutter test            → 455 passed
```

Itu pembuktian yang menentukan: kondisi yang menggagalkan CI sekarang lulus.

**Stabilitas, bukan sekadar hijau sekali.** Tes journal dijalankan 25× di
bawah 8 proses pemakan CPU pada 4 inti (oversubscription 2×, jauh lebih
kasar daripada CI): **25/25 lulus**, rasio CPU berkumpul di 0,76–1,29
sementara wall-clock berayun 114–965 ms. Ayunan 8,5× itulah yang dulu
diukur oleh asersi lama.

## Smoke test aplikasi nyata

Kedua perubahan hanya menyentuh berkas tes, jadi tidak ada perubahan UI atau
capture. Build rilis tetap diluncurkan untuk memastikan tidak ada yang rusak:
jendela 1280×720 muncul, UI Bahasa Indonesia utuh ("Siap merekam",
"Mulai Rekam", "atau tekan Ctrl+R"), kedua perangkat terdeteksi (Mikrofon dan
Suara sistem, keduanya `alsa_*.pci-0000_00_1f.3`), dan 4 sesi perpustakaan
yang sudah ada tampil benar di sidebar — termasuk "Sesi 2026-10-04 10:12 ·
8 detik · 2 segmen" dari smoke test merge sebelumnya. Log keluaran 320 byte
tanpa galat. `pkill -9 -x transcribe` setelahnya.

## Celah yang diketahui

- Jalur notarisasi macOS di `release.yml` masih belum terbukti; putaran ini
  tidak menyentuhnya.
- `isModelAvailable()` memeriksa `~/Library/Caches/...` di semua platform,
  termasuk Linux. Itu perilaku lama dan bukan bagian dari perbaikan ini,
  tetapi memang alasan sebuah tes bisa lulus di laptop pengembang dan gagal
  di CI. Tes lain yang bergantung model sebaiknya menanam stub dengan cara
  yang sama.
- Tes benchmark lain (`a_three_hour_journal_of_refined_passes_...`) hanya
  mencetak wall-clock tanpa mengasersinya, jadi tidak bisa goyah.


# Sprint 4 report — branch `sprint/04-differentiators`

> ITEM 0 (P0) + fitur diferensiator F6, F7, F10, F12, F13, F14, F15, F17,
> F18, F19, F20. 17 commit di atas `origin/main`; 115 berkas, +28.731 /
> −1.212 baris.

Semua angka di bawah ini diukur di mesin ini (Kali Linux, CPU lemah, tanpa
GPU) pada commit `d27be9a`, bukan disalin dari rencana.

---

## Gate verifikasi — hasil sebenarnya

| Langkah | Hasil |
|---|---|
| `cargo fmt --check` | bersih |
| `cargo clippy --all-targets -- -D warnings` | bersih (0 peringatan) |
| `cargo test --lib` | **605 lulus, 0 gagal** |
| `flutter analyze` | **No issues found!** (termasuk level info) |
| `flutter test` | **548 lulus, 0 gagal** |
| `flutter build linux --release` | `✓ Built build/linux/x64/release/bundle/transcribe` |

---

## ITEM 0 (P0) — "Setiap detik yang terekam masuk ke transkrip" ✅

### Yang salah sebelumnya

Bukti dari sesi nyata di mesin ini
(`20261004-Sesi 2026-10-04 10_12/`): `speaker.wav` 359,7 detik, RMS per 30
detik menunjukkan ucapan hanya di 0–30 s dan 150–180 s. Transkrip live
hanya memuat kemunculan **pertama** (2 segmen, t = 1–8 s). Jalur berkas
mengeluarkan baris halusinasi `[MENGENI]` untuk tiap bentang sunyi.

### Perbaikan

1. **Coverage + completion pass** (`rust_core/src/coverage.rs`,
   `completion.rs`): saat Stop, mesin membandingkan ucapan terdeteksi
   dengan apa yang sudah tertranskrip; selisihnya dikerjakan ulang dari
   WAV yang tersimpan, per sumber, di latar belakang.
2. **VAD lebih dulu di jalur berkas** (`stt/file.rs`): keheningan tidak
   pernah diberikan ke Whisper, jadi model tidak punya kesempatan
   mengarang kalimat untuknya.
3. **Filter halusinasi** (`hallucination.rs`): token dalam kurung dan
   kalimat-kredit subtitle yang sudah dikenal dibuang.
4. **Tidak ada lagi backlog yang dibuang**: antrean completion disimpan di
   sidecar (`pending_completion`), jadi keluar aplikasi lalu membukanya
   lagi melanjutkan, bukan kehilangan.
5. **Coverage = track paling tidak lengkap** (`74eb3b4`), supaya track mic
   yang senyap tidak menutupi track speaker yang masih kurang lima menit.

### Verifikasi nyata 1 — rekaman 4 menit di build rilis

Build rilis dijalankan di display `:0`, mode **Rapat Online**, mikrofon
**dimatikan** dan "Suara sistem" diarahkan ke `trareon_silent` (lihat
catatan OFFICE AUDIO RULES di bawah). `rapat_id.mp3` (14,8 s) diputar 13×
berturut-turut ke sink senyap — 192 detik ucapan di dalam rekaman 284
detik.

Yang terlihat:

* Model terpilih **Akurat** (large-v3-turbo-q5). Pratinjau live tetap
  mengalir (15 segmen), tetapi jelas tertinggal: pada 03:50 waktu rekam,
  baris terakhir masih t = 01:26.
* Dialog setelah Stop berbunyi, apa adanya:
  > **Sesi selesai — ada masalah.** Durasi 4 menit · 16 segmen transkrip.
  > Audio sistem: 4 menit terekam, 42% senyap.
  > **Transkrip langsung audio sistem tertinggal 187 detik dari rekaman.
  > Sisanya diselesaikan otomatis setelah sesi berhenti.**
* Sidecar mencatat ketidaklengkapan itu di disk:
  `"pending_completion": [".../speaker.wav"]`,
  `"coverage_fraction": 0.2007`.
* Sidebar menampilkan kartu **"Menyelesaikan transkrip — Menyelesaikan
  audio sistem… 43% — sisa 32 menit"** (persentase per sumber + ETA),
  dengan tombol batal.
* Setelah pass selesai: `pending_completion` kosong,
  **`coverage_fraction` 0,2007 → 0,9957**, transkrip **15 → 38 segmen**,
  rentang 34,7 s → 229,7 s.

Dua bentang tanpa segmen sama sekali — 0–34,7 s (sebelum pemutaran
dimulai) dan 229,7–284 s (setelah pemutaran berhenti) — keduanya memang
senyap. Tidak ada satu pun baris yang dikarang untuk keheningan.

Kualitas juga naik seperti yang dimaksud: pratinjau live menulis
*"membahas angeran kuartan empat"*, sedangkan pass penyelesaian dengan
model akurat menulis *"Hari ini kita membahas anggaran kuartal 4."*

`/tmp/trareon_smoke.log` hanya berisi dua baris, keduanya bukan error:
pemberitahuan backend Impeller dan peringatan deprecation
`libayatana-appindicator`.

### Verifikasi nyata 2 — sesi 6 menit yang jadi bukti awal

Salinan `speaker.wav` sesi 10:12 (359,7 s) dijalankan lewat jalur berkas
(`transcribe_cli`, ggml-base, `--language id`):

```
segments: 6
  [   1.4 s] Selamat pagi semuanya, hari ini kita membahas anggaran kuartal empat.
  [   7.1 s] Budi bertanggung jawab menyiapkan laporan keuangan paling lambat hari jungat.
  [  12.5 s] Rapat berikutnya di jadualkan minggu depan.
  [ 152.4 s] Selamat pagi semuanya, hari ini kita membahas anggaran kuartal empat.
  [ 158.2 s] Budi bertanggung jawab menyiapkan laporan kewangan paling lambat hari jungat.
  [ 163.6 s] Rapat berikutnya dijadualkan minggu depan.

baris halusinasi berkurung: 0
ucapan tertranskrip: 29,5 s dari berkas 359,7 s (keheningan: tidak ada keluaran)
```

* **Kedua** kemunculan ucapan ada (sebelumnya hanya yang pertama), tepat
  di 0–30 s dan 150–180 s sesuai profil RMS.
* **Nol** baris `[MENGENI]` (sebelumnya 12 dari 15 baris).

### Cacat yang ditemukan oleh smoke test ini

Setelah pass selesai, baris sesi di sidebar masih menulis *"1 menit · 15
segmen"* untuk sesi yang sudah menjadi 4 menit / 38 segmen. Indeks
perpustakaan menyimpan jumlah segmen berdasarkan ukuran+mtime transkrip
dan tidak ada yang memberitahunya bahwa transkrip sudah ditulis ulang.
Diperbaiki di `d27be9a` (callback sekali per sesi + tes yang memakunya).

---

## F13 — Mode Kepatuhan UU PDP ✅

`rust_core/src/pdp/` + `lib/widgets/pdp_settings_section.dart`.

* **Penyamaran saat ekspor**: NIK (16 digit), telepon (+62/08…), surel,
  NPWP, rekening bank, dan nama yang didaftarkan pengguna. Pratinjau
  menyorot temuan sebelum ekspor; transkrip tersimpan tidak diubah.
* **Retensi**: hapus otomatis sesi lebih tua dari N hari, audio dan/atau
  transkrip terpisah, dengan pratinjau + konfirmasi + entri log.
* **Log audit append-only** (sesi dibuat / diekspor / ringkasan dikirim /
  dihapus), bisa dilihat dan diekspor.
* **Pemberitahuan persetujuan** yang bisa disalin ke chat rapat;
  pengakuannya dicatat di log audit.
* Semua mati secara bawaan — tiap bagiannya menyembunyikan atau menghapus
  sesuatu, jadi tidak boleh mulai terjadi hanya karena aplikasi diperbarui.

Enkripsi at-rest **tidak dikerjakan** (stretch); trade-off-nya dicatat di
"Celah yang diketahui".

---

## F6 — Tindak lanjut terstruktur ✅

Mesin: `rust_core/src/actions.rs` (parser JSON + fallback ke daftar
berpoin), `.ics` RFC 5545 (satu `VTODO` per tugas, plus `VEVENT` untuk
tenggat yang bisa diresolusi), dan CSV.

UI: `lib/widgets/action_items_panel.dart` — daftar centang empat kolom
(tugas, PJ, tenggat, status) yang bisa disunting, disimpan di sidecar
sehingga status "selesai" bertahan setelah ditutup, diekspor sebagai
`.ics` dan `.csv` di sebelah sesi, dan dipakai mengisi "Tindak Lanjut" di
notulen — mengalahkan hasil parse ulang prosa ringkasan, karena baris yang
sudah ditinjau pengguna itulah yang ditandatangani. Tugas berstatus
*dibatalkan* dan baris kosong tidak pernah masuk kalender.

Ditemukan sambil menguji: dropdown status meluber 108 px keluar barisnya
di jendela minimum 800×600 — justru menyembunyikan kontrol dengan label
terpanjang. Barisnya sekarang dua baris.

---

## F7 — Provenans ringkasan ✅

`rust_core/src/provenance.rs`: tiap `[#n]` diresolusi ke stempel waktu
segmen; id di luar transkrip dibuang **dan dihitung**, lalu diperiksa
sekali lagi — kutipan yang nyaris tidak berbagi kosakata dengan klaimnya
ikut dibuang.

Di layar, tiap baris ringkasan tampil dengan stempel waktu yang bisa
diklik untuk melompatkan pemutar. Jumlah kutipan yang ditolak ditampilkan,
bukan disembunyikan: ringkasan dengan banyak rujukan tidak sah berasal
dari model yang sedang menebak, dan itu perlu diketahui sebelum notulen
ditandatangani.

---

## F15 — Ringkasan rapat panjang ✅

`rust_core/src/mapreduce.rs`: potong per jendela waktu 10 menit (dengan
batas karakter keras per jendela), ringkas tiap jendela, lalu ringkas
ringkasannya. `generate()` sekarang selalu lewat jalur ini — ia jatuh
kembali ke satu permintaan tunggal begitu transkrip muat, jadi ia superset
dari jalur lama, bukan mode kedua yang harus dipilih pengguna. Sebelumnya
rapat tiga jam diringkas dari bagian tengah yang dipotong diam-diam.

Progres per jendela ditarik ke panel ("Bagian 3 dari 10 — 20:00–30:00").

---

## F12 — Tanya arsip rapat ✅

Indeks SQLite FTS5 lokal atas seluruh sesi (`rust_core/src/archive.rs`),
diperbarui inkremental (hanya sesi yang transkripnya berubah dibaca
ulang), peringkat BM25.

Dua tombol, karena keduanya benar-benar berbeda:

* **Cari** — murni lokal, tidak butuh endpoint, tidak mengirim apa pun.
* **Jawab** — mengirim kutipan yang sudah ditemukan ke endpoint ringkasan
  yang pengguna atur, dan dicatat di Laporan Privasi sebagai jenis
  panggilan keluar tersendiri (bukan digabung ke "Ringkasan AI": yang
  keluar adalah potongan dari beberapa rapat, bukan satu transkrip).

Tiap kutipan membawa menitnya, bukan cuma rapatnya: pemutar sekarang punya
`initialSeekSeconds` dan nilai itu ikut jadi bagian dari key-nya, supaya
kutipan kedua ke sesi yang sudah terbuka tetap melompat.

Kriteria keluar: tes integrasi Rust menjawab pertanyaan atas 3 sesi
sintetis dengan kutipan yang benar (digerbangi env var, memakai Ollama
lokal bila ada).

---

## F10 — Pembicara ✅

* **Ganti nama sekali → berlaku se-sesi**: sudah ada sebelumnya.
* **Gabungkan dua pembicara** (baru): pengelompokan akustik memecah satu
  orang di rapat panjang menjadi `Peserta 2` dan `Peserta 4`; tanpa
  penggabungan, satu-satunya perbaikan adalah menamai keduanya sama dan
  hidup dengan transkrip yang mengaku dua orang mengucapkan kalimat yang
  sama. Mengganti nama ke nama yang sudah ada **adalah** penggabungan.
* **Diingat untuk rapat berikutnya** (baru): disimpan dengan kunci label
  **mesin** (`Peserta 2`), bukan nama yang diketik — kalau dikunci ke nama
  ketikan, tidak akan pernah cocok lagi. Selalu ditawarkan, tidak pernah
  diterapkan diam-diam. Mengingat per-suara akan lebih baik, dan ciri
  akustik di sini jauh dari cukup stabil untuk itu; alasannya ditulis di
  `lib/services/speaker_aliases.dart`.
* **Petunjuk jumlah pembicara saat impor** (baru): begitu kuota klaster
  habis, jendela baru bergabung ke klaster terdekat alih-alih mengarang
  "Pembicara 7". Diteruskan ke jalur impor satu-lintasan maupun dua-lintasan.

---

## F14 — "Apa Jalan di Mana" ✅

`rust_core/src/capabilities.rs` adalah tabel kemampuan **sebagai data**,
dan `rust_core/src/privacy.rs` memeriksanya terhadap sumber: baris yang
mengaku "Lokal" tetapi modulnya memuat primitif jaringan **menggagalkan
build**, begitu pula baris yang mengaku memakai jaringan dari modul yang
bukan `model.rs` atau `summary.rs`.

Jadi tabel yang dibaca pengguna dan gerbang yang menggagalkan CI adalah
daftar yang sama. Layarnya duduk di sebelah Laporan Privasi karena
keduanya menjawab dua paruh satu pertanyaan: yang itu "apa yang pernah
dikirim", yang ini "apa yang bisa dikirim, dan apa yang aktif". Tiap baris
menyebut modul Rust-nya supaya klaimnya bisa diperiksa.

---

## F17 — Pengurangan derau (RNNoise) ✅ — dan hasilnya jujur: tidak membantu di sini

`rust_core/src/denoise.rs` memakai `nnnoiseless` (port RNNoise murni Rust,
tanpa dependensi C, tanpa unduhan). RNNoise terdefinisi di 48 kHz
sedangkan semua jalur dekode menargetkan 16 kHz, jadi: naik ×3, denoise,
turun ÷3; skalanya juga diubah ke rentang 16-bit yang model itu harapkan.
Frame pertama (yang dokumentasinya sendiri sebut berisi artefak fade-in)
diganti kembali dengan aslinya.

**Pengukuran** — `rapat_id.mp3` (14,8 s) dicampur derau pink sampai SNR
≈ 7,2 dB, lalu ditranskrip dengan ggml-base lewat `transcribe_cli`
(`--denoise` ditambahkan di sprint ini supaya pertanyaan ini bisa dijawab
dari berkas):

| Masukan | Transkrip |
|---|---|
| Bersih (acuan) | *Selamat pagi semuanya, hari ini kita membahas anggaran kuartal empat. / Budi bertanggung jawab menyiapkan laporan keuangan paling lambat hari jungat. / Prapat berikutnya dijadualkan hingga depan.* |
| Berderau, tanpa RNNoise | *Selamat pagi semuanya, hari ini kita membahas anggaran **kuarta** empat. / Budi bertanggung jawab menyiapkan laporan **kewangan** paling lambat hari **jungan**. / Rapat berikutnya dijadualkan **nih budapan**.* |
| Berderau, **dengan** RNNoise | *Selamat pagi semuanya. / Hari ini kita membahas **hanggaran kuarta** empat. / Budi bertanggung jawab **mengiapkan** laporan **kewangan** paling lambat **kari junga**. / Rapat berikutnya dijadualkan **nginggu** depan.* |

Diukur terhadap keluaran audio bersih: **24,0% → 32,0%** deviasi kata.
Pada klip ini RNNoise **memperburuk** hasil. Itu persis alasan setelannya
mati secara bawaan dan dideskripsikan di UI sebagai pertukaran, bukan
peningkatan.

Biaya waktu: pada klip 14,8 s, total waktu dengan dan tanpa denoise tidak
terpisahkan dari variasi antar-jalankan di mesin ini (tanpa: 14,7–18,2 s;
dengan: 15,7–23,3 s). Klaim "+15%" di draf laporan sebelumnya tidak
didukung pengukuran dan sudah dihapus.

---

## F18 — Harness WER ✅

`rust_core/src/wer.rs` + `rust_core/src/bin/wer_bench.rs` +
`scripts/fetch_wer_corpus.sh` + `docs/WER-BENCH.md`.

Levenshtein atas kata (WER) dan karakter (CER) dengan substitusi/hapus/
sisip dihitung terpisah; galat **dikumpulkan se-korpus**, bukan rata-rata
laju per klip (merata-ratakan laju membuat klip empat kata seberat klip
empat menit — begitulah harness melaporkan model yang lebih buruk sebagai
pemenang). Acuan kosong menghasilkan 1,0, bukan tak hingga. Klip yang
gagal didekode dihitung rugi total, bukan dilewati.

Korpus: FLEURS `id_id` (CC-BY 4.0) diunduh streaming oleh skrip; **tidak
ada audio yang di-commit**.

**Hasil di mesin ini — 12 klip FLEURS id_id, bukan angka publikasi:**

| Model | WER | CER | RTF | Klip |
|---|---|---|---|---|
| ggml-base | 31,9% | 10,1% | 0,32× | 12 |
| ggml-tiny | 49,5% | 18,8% | 0,54× | 12 |

RTF di bawah 1,0 untuk keduanya: CPU ini memang tidak bisa mengikuti rapat
secara live dengan model mana pun — konsisten dengan ITEM 0 yang
mengandalkan pass setelah Stop.

Peringatan yang juga ditulis di `docs/WER-BENCH.md`: FLEURS adalah ucapan
**baca** jarak dekat satu pembicara. Model yang bagus di sini belum
terbukti bagus untuk rapat empat orang lewat mikrofon laptop. Angka 12
klip ini adalah uji asap, bukan WER model.

---

## F19 — Ekspor PDF + CSV ✅

* **PDF** dengan font **tertanam** (DejaVu Sans, lisensi Bitstream Vera,
  ikut di-vendor bersama berkas hak ciptanya). Pembungkusan baris diukur
  dengan lebar maju font itu sendiri, bukan ditebak dari jumlah karakter;
  halaman A4 dipaginasi.
* **CSV** per segmen dengan pengutipan RFC 4180 — transkrip adalah teks
  bebas yang rutin memuat koma dan tanda kutip.

**Bug yang ditemukan oleh verifikasi nyata**: `Op::SetTextCursor` di
`printpdf` ternyata menghasilkan `Td`, yang memposisikan **relatif**
terhadap awal baris berjalan. Diberi koordinat halaman absolut, tiap baris
menumpuk offset baris sebelumnya, sehingga semua yang setelah judul
mendarat di luar halaman — `pdftotext` atas ekspor sungguhan hanya
mengembalikan judulnya, padahal berkasnya tetap punya header, trailer, dan
program font tertanam yang valid; persis yang diperiksa tes lama.
Diperbaiki memakai `TextMatrix::Translate` (`Tm`, mengganti matriks), dan
tes barunya menserialisasi ulang dengan `optimize: false` supaya bisa
membaca operator dan menegaskan ada satu `Tm` per baris dan nol `Td`.

Sesudah perbaikan, atas ekspor sungguhan:

```
$ pdffonts clean.pdf
name                              type           encoding    emb sub uni
HEIGIDGCBAAHFGBHAEFHCBHGAJHCJDHF  CID TrueType   Identity-H  yes no  yes

$ pdftotext clean.pdf -
clean
Transkrip
[00:00] Pembicara 1: Selamat pagi semuanya, hari ini kita membahas anggaran kuartal empat.
[00:06] Pembicara 1: Budi bertanggung jawab menyiapkan laporan keuangan paling lambat hari jungat.
[00:11] Pembicara 1: Prapat berikutnya dijadualkan hingga depan.
```

`emb yes` — font benar-benar tertanam, bukan hanya disebut namanya.

---

## F20 — Folder/tag, filter Tinjau, penyuntingan lewat papan ketik ✅

Mengoreksi satu jam transkrip adalah empat operasi yang sama ratusan kali.
Transkrip di pemutar sekarang punya kursor papan ketik (↑↓, digambar
berbeda dari baris yang sedang diputar — meninjau dan mendengarkan adalah
dua kegiatan berbeda), **Enter** menyunting di tempat, **Esc** membatalkan,
**Ctrl+↑↓** memindahkan baris ke giliran pembicara yang benar, **Ctrl+M**
menyambung kalimat yang dipotong VAD, **Ctrl+Shift+S** memisah kalimat yang
didekode menyatu. Contekan keenam tombol itu ada di layar.

Ketiga mutasi menjaga garis waktu tetap konsisten: pemindahan membiarkan
stempel waktu bersama audionya, penggabungan mengambil awal yang lebih
dini dan jumlah durasi serta mempertahankan tanda ketidakyakinan bila
salah satu paruhnya punya, pemisahan membagi durasi sebanding teksnya.
Memisah di salah satu ujung ditolak, bukan menghasilkan segmen kosong.

Di layar yang punya tombol-tombol itu, dialog sunting modal dihapus — dua
cara menyunting satu baris adalah satu cara kelebihan. Tampilan rekaman
live, yang tidak bisa melakukan suntingan struktural, tetap memakainya.

**Tinjau** menyaring daftar ke segmen yang ditandai mesin sebagai ragu, dan
tombolnya hanya muncul bila memang ada yang ditandai. (Terlihat bekerja di
smoke test: tiap baris pratinjau live bertanda *"Kepercayaan rendah"*.)

**Tag**, bukan folder: satu rapat rutin sekaligus "Anggaran" dan
"Mingguan", dan memindahkan direktori akan memutus tiap path tersimpan —
audio, hasil ekspor, indeks arsip. Tag tinggal di sidecar, menyaring di
bilah sisi secara irisan, dan ditawarkan sebagai chip supaya satu tag tidak
menjadi tiga ejaan.

---

## Yang tidak dikerjakan

* **F11** (catatan pribadi saat rapat digabung AI) — stretch, tidak
  dimulai.
* **F16** (deteksi otomatis rapat Zoom/Meet/Teams) — stretch, tidak
  dimulai.
* **Enkripsi at-rest** (stretch F13). Trade-off-nya: kunci harus tinggal di
  suatu tempat, dan pada aplikasi desktop tanpa keychain itu berarti di
  berkas setelan — yang melindungi dari pencurian disk tetapi bukan dari
  siapa pun yang bisa menjalankan aplikasi. Mode PDP yang ada sekarang
  (penyamaran, retensi, log audit) memberi manfaat nyata tanpa klaim
  keamanan yang tidak bisa ditepati. Sebaiknya dikerjakan bersama integrasi
  keychain per-platform.

## Celah yang diketahui

* **Angka WER adalah uji asap**, 12 klip ucapan baca. Belum ada korpus
  rapat berlabel; itulah angka yang sebenarnya menggambarkan beban kerja
  aplikasi ini.
* **RNNoise memperburuk** klip uji di sini (24% → 32%). Mati secara
  bawaan; perlu diuji pada rekaman ruangan sungguhan sebelum
  direkomendasikan.
* **Tes langsung arsip chat** (F12) butuh Ollama lokal; digerbangi env var
  dan tidak jalan di CI.
* **Diarisasi tetap kasar** — pitch/energi/ZCR. Petunjuk jumlah pembicara
  dan penggabungan manual meredam gejalanya, bukan menyembuhkan sebabnya.
* **Nama pembicara diingat per-label, bukan per-suara**, jadi hanya
  berguna untuk rapat berulang dengan urutan pembicara yang mirip.
* **PDF memakai satu bobot font** (regular). Tebal/miring akan
  melipatgandakan ~740 kB yang sudah ikut di binary.
* **Uji audio Windows (WASAPI)** tidak dijalankan — lihat di bawah.

## PERLU IZIN OWNER: uji audio Windows

Uji tangkap langsung di `win2060` (mikrofon/loopback WASAPI) **tidak
dijalankan** sesuai OFFICE AUDIO RULES. Yang perlu dijadwalkan bila owner
mengizinkan: rekam Rapat Online di Windows, pastikan pass penyelesaian
setelah Stop berjalan sama seperti di Linux.

## Catatan OFFICE AUDIO RULES

Seluruh smoke test berjalan tanpa suara yang terdengar dan tanpa membuka
mikrofon ruangan:

* `pactl get-default-sink` diperiksa = `trareon_silent` sebelum tiap
  pemutaran; pemutaran hanya lewat `paplay -d trareon_silent`.
* **Catatan untuk sprint berikutnya**: aplikasi secara bawaan memilih
  perangkat ALSA sungguhan (`alsa_input.pci-…`) di kedua pemilih. Dalam uji
  ini mikrofon **dimatikan manual** dan "Suara sistem" dialihkan ke
  `trareon_silent` sebelum menekan Rekam. Di mesin kantor, bawaan itu
  berarti satu klik Rekam akan membuka mikrofon ruangan.
