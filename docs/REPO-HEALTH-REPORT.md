# Repo health report — recovering the orphaned `fix/recording-pipeline-and-permissions` commits

Branch: `fix/repo-health`, based on `origin/main` (`ac419cf`, Sprint 2).

PR #5 merged at `ea8dad6`, but three commits were pushed to its branch
*after* the merge and never reached `main`:

| Commit | Subject |
|---|---|
| `ca315e4` | fix: recording pipeline + permissions (ScreenCaptureKit, capture errors, leaks) |
| `b01465a` | fix(ui): reflow the mode/action toolbar with Wrap so controls never clip |
| `af782d1` | feat(ui): premium redesign — settings void fix, teal-tinted palette, denser type |

`main` has since moved a long way (PR #6 Meetily parity, PR #7 Sprint 1
durability, PR #8 Sprint 2 sidebar / two-pane settings / 3-hour scale), so
every item below was re-checked against current code rather than
cherry-picked. Seven of `ca315e4`'s bullets were still missing and are
ported; two were already fixed differently and better in `main`.

---

## Part 1 — `ca315e4`

### 1. ScreenCaptureKit handler registration inverted — **PORTED** (`248c582`)

`rust_core/src/audio/loopback.rs`. `SCStream::add_output_handler` returns
`Option<usize>`: `Some(handler_id)` on success. The call site mapped it with
`.map_or(Ok(()), |e| Err(..))`, which is the mapping backwards — every
healthy registration became an `Err`, and a genuine `None` became `Ok`
(starting a handler-less stream that captures silence). ScreenCaptureKit
therefore never worked on any Mac, and system audio always fell through to
the fallback chain.

Fixed via `sck_handler_registration`, a `pub(crate)` helper deliberately
placed **outside** the `#[cfg(target_os = "macos")]` module and generic over
the handler id, so `macos_policy_tests::sck_handler_registration_is_ok_only_on_some`
compiles and runs on Linux CI. The inversion was a logic bug; a gate with no
Mac could never have caught it while it lived inside macOS-only code.

### 2. macOS no longer records the mic as "system audio" — **PORTED** (`248c582`, `87bcd99`)

When zero-setup capture is requested and fails, `capture_loopback` now
returns the actionable error. The two fallbacks it used to drop into were
both wrong: BlackHole-by-name (not installed — the user picked nothing), and
`ffmpeg -f avfoundation -i :default`, which **is the microphone** —
avfoundation exposes no system-audio device. A Webinar session with Screen
Recording denied recorded and transcribed the user's own mic, labelled
"Audio sistem", even with the mic toggle off. The named-device path lost its
`ffmpeg` fallback for the same reason. This matches Linux, where
`pulse::monitor_source` already refuses to record `default`; `ffmpeg_fallback`
is deleted rather than left as dead code.

**This fix alone was not enough.** `main`'s `_resolveDevices` filled in a
concrete `speakerDeviceId` whenever the user had not picked one (first
output matching "blackhole"/"loopback", else `outputs.first`), and
`capture_loopback` skips the zero-setup path as soon as it gets a device
name — so ScreenCaptureKit *still* never ran. On a Mac without BlackHole
that guess is "MacBook Pro Speakers", a playback device the engine then
tried to open as a capture source, which is exactly what dropped it into
the mic fallback; on Linux it handed `resolve_monitor_source` a sink name
where it wants a `.monitor`. `87bcd99` removes the guess. Each platform
already resolves system audio better than Dart could (ScreenCaptureKit, the
default sink's monitor, the default render device), and a device the user
*did* choose is still passed through untouched. `start_capture` only needs
`enabled`, so a null device id is handled fine — the comment in `start()`
claiming otherwise was stale and is corrected.

Tests: `macos_policy_tests` (3, cfg-independent),
`test/session_device_resolution_test.dart` (+2).

### 3. Capture failures surfaced rather than swallowed — **SKIPPED, already fixed better**

`main` does this through `CaptureAttempt` + `session::decide_start`, which is
strictly better than `ca315e4`'s `return Err(e)`: one source failing in
"Rapat Online" is now `ProceedWithWarning` (a meeting recorded from the
speakers alone is still worth having) and only *both* failing is `Fail`.
`ca315e4` would have refused the whole session on either. Already covered by
`decide_start` tests in `session.rs`.

### 4. `poll_events` dropping drained events — **PORTED** (`1a9611c`)

`poll_events` takes `pending_events` out of the registry and *then*
snapshots, so `persist_session_snapshot(session_id)?` discarded transcript
text and VU levels that nothing re-delivers — a hole in the meeting with no
error anywhere. Now best-effort, matching `get_status` directly above.

Test: `poll_events_keeps_drained_events_when_the_snapshot_cannot_be_written`,
which makes the write fail for real (recovery root pointed at a path under a
regular file, so `create_dir_all` fails) rather than mocking it, and asserts
a second poll is empty — i.e. that losing them once would have been
permanent. Verified to fail with `?` restored.

### 5. `start()` / `recoverFromSnapshot()` double-start race — **PORTED** (`84a09f2`)

Both set `lifecycle` to `recording` only *after* their awaits, so the
lifecycle check could not see a launch in flight. A double-click on Mulai,
Ctrl+R held down, or Pulihkan during a start spawned a second live Rust
session; the first was unreachable from Dart and kept recording to disk
until app exit. `_launching` is set synchronously before the first await and
cleared in a `finally`, so a failed start can still be retried.

Test: `test/session_double_start_test.dart` (4 cases, including start-vs-
recover and retry-after-failure). 3 of the 4 verified to fail without the
guard.

### 6. `downloadProgress()` timer leak + `stopSession()` teardown — **PORTED** (`bcd7535`)

`downloadProgress` only stopped its `Timer.periodic` on reaching ratio 1.0.
A cancelled, failed or stalled download never gets there, so it kept calling
into Rust five times a second for the rest of the app's life with a
`StreamController` nobody would close. (`main` already had `onCancel`; the
`isClosed` checks were missing — two of them, because the tick body awaits
and `add()` on a closed controller throws.) `stopSession` closed its three
controllers *after* the engine call, so a throw from Rust left all of them
open and registered, with the UI listening to a session the engine had
dropped; the teardown is now in a `finally` and the caller still sees the
error.

The timer logic moved to a top-level `pollDownloadProgress`, alongside
`toRustSegment` and for the same stated reason — the part with the bug is
now directly testable without the native library. `stopSession` got one
`@visibleForTesting` seam (`stopEngineSession`) plus `openStreamCount`,
because `RustEngineBridge` otherwise has no test surface at all.

Test: `test/bridge_teardown_test.dart` (5 cases).

### 7. Propagate the Rust `lowConfidence` flag — **SKIPPED, already in `main`**

`main` routes every segment through the shared top-level `fromRustSegment`
(`lib/services/bridge_service.dart`), which carries `lowConfidence` and
`avgLogProb`. The live `_poll` path delegates to it, so there is no longer a
separate hand-written mapping to drop the flag.

### 8. Delete a failed-checksum model download — **PORTED** (`f3b102d`)

`download_single_url` resumes from `metadata(dest_path).len()`, so a corrupt
or truncated file left on disk is permanently poisoned: the Range request
appends to the bad bytes, the hash never matches, and `is_model_downloaded`
reports the model as installed meanwhile. No UI could clear it. Implemented
as `model::discard_corrupt_download`, which only logs its own failure — the
checksum error is the one worth showing the user.

Test: `a_failed_checksum_download_is_deleted_so_resume_cannot_be_poisoned`,
including the `is_model_downloaded` precondition and idempotency.

### 9. `_loadRecoveries` handling bridge errors — **PORTED, half superseded** (`1012a22`)

`_recoverSession` already toasts its own failures in `main` (added with
Sprint 2's recovery dialog), so only the listing needed fixing: a throw from
`listRecoverableSessions` left `_loadingRecoveries` true forever — an
indeterminate progress bar in place of the recovery banner, so a crashed
meeting could not be reached at all.

Test: `main_screen_recovery_test.dart`, deliberately not using
`pumpAndSettle` (an indeterminate `LinearProgressIndicator` never settles,
which is precisely what the stuck state looked like).

### Also in `ca315e4`'s diff but not its message

| Change | Verdict |
|---|---|
| `list_recoverable_sessions` sorted newest-first | already in `main` (`sort_by_key(Reverse(updated_at_unix_ms))`) |
| `settings.default_model` `large-v3-turbo` → `base` | already in `main` |
| "Traeon" → "Trareon" typos (`doctor.rs`, onboarding) | already in `main`, and gated by `test/product_name_spelling_test.dart` |
| `api::list_output_audio_devices` + its Dart binding | already in `main` |
| `recoverSession` wiring the poll timer and controllers | already in `main` via `_openSessionStreams` |
| `MEMORY_SPLIT_COOLDOWN_SECS` in `should_split` | **skipped**: the cooldown exists because `ca315e4` called `check_auto_split` from `poll_events`. In current `main` `check_auto_split` has no caller outside `session.rs`, so the premise ("re-triggers on every 100-200 ms poll") does not hold. Adding it now would be speculative; worth revisiting whenever the live split loop is wired up. |

No `api.rs` **public** surface changed, so no FRB regeneration was needed
(`discard_corrupt_download` is `#[flutter_rust_bridge::frb(ignore)]`,
`sck_handler_registration` / `wants_zero_setup_capture` are `pub(crate)`).
`lib/src/rust/` is untouched.

---

## Part 2 — `b01465a` and `af782d1`

### `b01465a` (toolbar `Wrap`) — superseded; its *guarantee* ported as a test, which found a live bug (`d742993`)

The diff itself is obsolete: Sprint 2 rebuilt the toolbar as `_ControlArea`
and already uses a `Wrap` for the Sesi/Perangkat groups, replacing the
clipping `SingleChildScrollView` row that `b01465a` was fixing. Re-applying
it would have reverted Sprint 2's layout.

What was missing is any test holding the line, so
`test/narrow_window_layout_test.dart` pins the guarantee to the current
layout instead of to that commit's widget tree: at 800x600, 900x700 and
1024x768, the record button, mode selector and *both* device toggles are
fully inside the window and hit-testable, idle and recording, with no
overflow. ("Pengeras Suara", the control that used to vanish behind Ekspor,
is now labelled "Suara sistem".)

That test failed at 800x600 — not horizontally, but with **"A RenderFlex
overflowed by 80 pixels on the bottom"** for one frame as a session starts.
The culprit is `EmptyState` (`lib/widgets/empty_state.dart`): a fixed layout
needing ~220px (40px padding, 40px glyph, two lines) rendered into the
~140px the transcript pane gets at the minimum window size, painting the
yellow-and-black stripes exactly where the first transcript line was about
to appear. It now drops the glyph and tightens padding below 220px and
scrolls below that — the same `compact` rule `_IdleWorkspace` already uses,
so it stays inside the Sprint 2 design. Verified to fail without the fix.

### `af782d1` (premium redesign) — **SKIPPED in full**, per item

| `af782d1` change | Why skipped |
|---|---|
| Settings "void fix" (extract the 380px panel body, centre it capped at 700) | File gone. Sprint 2 replaced `settings_side_panel.dart` with the two-pane `settings_screen.dart`; there is no void left to fix. |
| Teal-tinted palette (`#0C100F`/`#141917`/`#1D2320`, brighter teal accent) | `main` is already a teal palette (`primary #00796B`), and Sprint 1 re-derived several tokens for WCAG AA (`textTertiary #6B6B6B`, theme-aware `error`/`onError`, the per-speaker palette gated by `test/speaker_color_test.dart`). Replacing it wholesale was explicitly out of scope and would break `test/theme_contrast_test.dart`. |
| `warning` → amber `#F5A623` so it stops colliding with the recording dot | The collision is real on paper (`warning` and `recordingDot` are both `#FF3B30`), but all three remaining `AppColors.warning` call sites are **errors**, not warnings: privacy-report "not clean", an export failure snackbar, and `BatchFileStatus.error`. Sprint 1 moved genuine warnings onto the theme-aware `colors.error`. Turning those three amber would be a regression, so this is left alone. |
| `AppColorSet.lerp` interpolating every colour so the theme toggle cross-fades | Cosmetic only — the endpoints are identical. Would mean rewriting both concrete colour classes, with contrast unverifiable mid-animation. Not worth the risk against the Sprint 1 contrast gate. |
| Flat cards (elevation 0, 12px radius, hairline border), desktop 13pt type scale | Already how `app_theme.dart` is built in `main`. |
| `VisualDensity.compact` | Deliberately not ported: Sprint 3 is adding ≥44–48px touch targets, which compact density works directly against. |
| Transcript capped to a centred 820px reading column; teal glyph badge in the empty state | Sprint 2 layout decisions. The sidebar already narrows the transcript pane, and capping would change the Sprint 2 row design (speaker avatars, inline metadata). |

---

## Part 3 — GitHub Actions (`2f46375`)

Every run warned `Node.js 20 is deprecated` and noticed that `ubuntu-latest`
migrates to Ubuntu 26 on 2026-10-19.

| Action | Before | After | Runtime after |
|---|---|---|---|
| `actions/checkout` | `v4` | `v7` (latest `v7.0.1`) | node24 |
| `actions/upload-artifact` | `v4` | `v7` (latest `v7.0.1`) | node24 |
| `softprops/action-gh-release` | `v2` | `v3` (latest `v3.0.3`) | node24 |
| `Swatinem/rust-cache` | `v2.9.1` | `v2.9.2` | node24 |
| `dtolnay/rust-toolchain` | `@stable` | unchanged | composite (no Node) |
| `subosito/flutter-action` | `v2.23.0` | unchanged (is latest) | composite (no Node) |

All tags confirmed to exist via `git ls-remote --tags`. Pinning granularity
follows each action's existing style in this repo (major for the three
major-pinned ones, exact for `rust-cache`); dependabot updates both forms.
**No Node 20 action remains in either workflow.**

Breaking changes checked against the release notes and `action.yml` of each
target, and none apply here:

- **upload-artifact v5/v6/v7** — Node 24 + ESM. v7 adds direct (unzipped)
  uploads, where the artifact takes the *file's* name instead of `name`; that
  is opt-in through the new `archive` input, which this repo does not set.
  `name`, `path` and `retention-days` are all still defined.
- **checkout v5/v6/v7** — Node 24, plus `allow-unsafe-pr-checkout` and a
  block on checking out fork PRs for `pull_request_target` and
  `workflow_run`. Both workflows trigger on `pull_request` / `push` / tag
  `push` only, and pass no inputs at all.
- **action-gh-release v3** — Node 24 only; inputs unchanged, `files` still
  valid.

Other changes:

- **Linux runners pinned to `ubuntu-24.04`** (8 places across both
  workflows) instead of `ubuntu-latest`. The Ubuntu 26 image renames apt
  packages, and `libasound2-dev` / `libwebkit*` / `libegl1-mesa-dev` are
  exactly what the desktop build installs — not a surprise worth taking on a
  date nobody will be watching. `macos-latest`, `windows-latest` and
  `windows-2022` are untouched; they warn about nothing.
- **`NODE_OPTIONS: --experimental-vm-modules` removed** from `ci.yml`.
  Nothing in this Rust + Flutter repo runs Node, but a workflow-level
  `NODE_OPTIONS` is inherited by the *actions*, which are now all ESM on
  Node 24.
- **`packages: write` removed** from `ci.yml` permissions. No job publishes a
  package, so no action's token should be able to.
- **`.github/dependabot.yml` added** (new file — there was none, so no
  existing ecosystems to keep). `github-actions`, weekly, grouped into one
  PR with a `ci` commit prefix. Cargo and pub ecosystems were deliberately
  not added: not asked for, and they would start a lot of PR traffic on a
  repo with pinned Flutter constraints.
- Release workflow semantics unchanged beyond the bumps. (Note: it builds
  macOS/Linux/Windows artifacts, not only a source archive.)

Validation:

```
$ python3 -c "import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]];print('YAML OK')" \
    .github/workflows/*.yml .github/dependabot.yml
YAML OK

$ actionlint 1.7.12 .github/workflows/*.yml
exit=0        # clean, no output
```

---

## Verification gate

```
$ cd rust_core && cargo fmt --all -- --check
OK

$ cargo clippy --all-targets -- -D warnings
Finished `dev` profile [unoptimized + debuginfo] target(s) in 12.23s

$ cargo test --lib
test result: ok. 320 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out

$ flutter analyze
No issues found! (ran in 14.2s)

$ flutter test
02:41 +352: All tests passed!

$ flutter build linux --release
✓ Built build/linux/x64/release/bundle/transcribe
```

Rust: 320 lib tests (+5 new). Flutter: 352 tests (+15 new across
`bridge_teardown_test.dart`, `session_double_start_test.dart`,
`narrow_window_layout_test.dart`, `session_device_resolution_test.dart`,
`main_screen_recovery_test.dart`).

One caveat on the Flutter suite: an earlier run on a loaded machine failed
two wall-clock budgets in `test/perf/transcript_view_perf_test.dart`
(2020 ms against a 2000 ms limit, and a different pair on a second run).
They pass on an unloaded machine and the failing pair varies between runs,
so this is host-load flakiness in those thresholds, not a regression — none
of the changes here touch `TranscriptView`. Worth loosening or making those
budgets relative at some point.

---

## Needs verification on a Mac

Nothing under `#[cfg(target_os = "macos")]` can be compiled here, so
`loopback.rs`'s macOS module was changed by careful review only. Please
confirm on real hardware:

1. **Webinar / Rapat Online with permission granted** — the log says `using
   ScreenCaptureKit for system audio` and the transcript contains the
   *system* audio, not the microphone. This is the path that has never once
   worked; it is the single most important thing to check.
2. **Webinar with Screen Recording denied** — an actionable error toast
   ("grant Screen & System Audio Recording permission"), and *no* recording
   of the microphone.
3. **A named loopback device (BlackHole 2ch) chosen in Settings** — still
   opens through cpal; if it cannot be opened, the new Indonesian error names
   the device instead of silently swapping in the mic.
4. That `try_sck_capture` still compiles against the `screencapturekit`
   crate: `add_output_handler`'s result is now bound to a local and passed to
   `sck_handler_registration` (the `Option<usize>` is discarded), and the
   `std::io::Read` / `std::process::{Command, Stdio}` imports were removed
   with `ffmpeg_fallback`.

## Found but not fixed

`release.yml`'s `build-windows` job runs
`powershell -File scripts/package_windows.ps1 -Version "${GITHUB_REF_NAME#v}"`
with no `shell:`, so it executes under pwsh, where `${GITHUB_REF_NAME#v}` is
not valid syntax — the version argument is wrong or empty. It is
pre-existing and fixing it would change Release behaviour beyond the action
bumps this task scoped, so it is left alone and flagged here instead.
