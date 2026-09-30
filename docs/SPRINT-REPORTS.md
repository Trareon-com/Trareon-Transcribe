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
