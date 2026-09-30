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
