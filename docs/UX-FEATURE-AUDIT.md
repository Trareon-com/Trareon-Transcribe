# UX / Feature Audit — Trareon Transcribe

> Branch: `feat/meetily-parity` · Audit date: 2026-09-30 · **READ-ONLY audit, no code changed**
> Scope: every file in `lib/screens`, `lib/widgets`, `lib/theme`, `lib/state`,
> `lib/services`, `lib/utils`, plus the `rust_core` paths those depend on for
> durability guarantees.
> Companions: [`AUDIT-MEETILY-PARITY.md`](AUDIT-MEETILY-PARITY.md) (flow tracing),
> [`MEETILY-PARITY-REPORT.md`](MEETILY-PARITY-REPORT.md) (what was fixed).
> Those two documents asked *"is each flow wired?"*. This one asks
> *"is the product usable, safe, and finished?"* — which turns out to be a
> different question with different answers.

**Severity scale**

| | Meaning |
|---|---|
| **P0** | Blocker. Data loss, or the product misleads the user about something it promises. Do not ship. |
| **P1** | Major. A target user (notulis rapat, 3-hour meeting) will hit this and be blocked or harmed. |
| **P2** | Minor. Wrong, annoying, or fragile, but has a workaround. |
| **P3** | Polish. |

---

## Executive summary

Eleven findings dominate everything else. All eleven are new to this audit — the
previous two documents traced wiring and found the flows connected; these are
about what the connected flows actually do.

| # | Finding | Sev |
|---|---|:--:|
| **UX-01** | **Crash recovery recovers no transcript.** `SessionRecoverySnapshot` carries config + counts only (`rust_core/src/session.rs:186`); `recoverFromSnapshot` explicitly resets `segments: []` (`lib/state/session_model.dart:190`). A crash 2 hours into a meeting loses all 2 hours, and the banner says "bisa dipulihkan". | **P0** |
| **UX-02** | **Recorded audio lives only in RAM until stop.** `raw_audio: Arc<Mutex<Vec<f32>>>` (`rust_core/src/session.rs:159`, allocated `:260`) grows unbounded: 16 kHz f32 mono = **691 MB per source per 3 hours**, 1.38 GB for Rapat Online. Nothing is on disk until `stopSession` succeeds. | **P0** |
| **PR-01** | **The Privacy Report under-reports.** It headlines "N panggilan jaringan sejak aplikasi dibuka" but `recordModelDownload` has **zero call sites** (`lib/state/privacy_report_model.dart:40`; `test/privacy_proof_test.dart:85` *asserts* zero), and `UpdateChecker` opens a socket to `raw.githubusercontent.com` (`lib/services/update_checker.dart:88`) that is never recorded. The screen's own copy claims exactly two legitimate network activities (`privacy_report_screen.dart:75`). There are three. | **P0** |
| **UX-03** | **Product name misspelled on the first screen every new user sees:** "Selamat datang di **Traeon** Transcribe" (`lib/screens/onboarding_screen.dart:43`). | **P1** |
| **UX-04** | **Preflight/doctor never runs.** `SetupOverlay` (the only caller of `runPreflightChecks`) is imported by no file in `lib/` — only by `test/test_helpers.dart`. The 500-line `doctor.rs` diagnostic is unreachable in the shipped app. | **P1** |
| **UX-05** | **"Speaker/loopback" device pickers list microphones.** `listOutputAudioDevices()` calls `rust_api.listAudioDevices()` (`lib/services/bridge_service.dart:600-602`). `rust_core/src/audio/device.rs:35` *has* `list_output_devices()`; `api.rs` never exposes it. | **P1** |
| **UX-06** | **Theme "Sistem" cannot persist.** `_toRustSettings` collapses `system → light` (`bridge_service.dart:811`); `_fromRustSettings` maps back to `light` (`:793`). Pick "Sistem", restart, you get "Terang". | **P1** |
| **UX-07** | **Dark-mode primary buttons fail WCAG AA at 2.44:1.** `ElevatedButtonThemeData` hardcodes `foregroundColor: Colors.white` (`lib/theme/app_theme.dart:83`) over dark primary `#4DB6AC`. The correct token (`colors.onPrimary` = `#003D33`, 5.02:1) exists and is ignored. | **P1** |
| **UX-08** | **Speaker-colour palette fails AA for 7 of 8 entries in light mode** (`lib/utils/speaker_color.dart:4-13`): `#2ECC71` = 2.10:1, `#F39C12` = 2.19:1, `#1ABC9C` = 2.41:1, `#E67E22` = 2.85:1 against `#FFFFFF`, at 12 px semibold. It is not theme-aware, so it must fail in one theme or the other. | **P1** |
| **UX-09** | **The import queue overflows the window.** `FileUploadZone` returns a plain `Column` with `...queue.map(...)` (`lib/widgets/file_upload_zone.dart:156`) inside a non-scrolling `Padding` in the tab body (`lib/screens/library_screen.dart:330-333`). Five-ish files and the layout overflows; a notulis importing a day's recordings sees a yellow-black RenderFlex stripe. | **P1** |
| **PR-02** | **Every Dart-side write is non-atomic.** The player's transcript save (`lib/screens/transcript_player_screen.dart:145`), the metadata sidecar (`lib/services/session_store.dart:226`) and prefs (`lib/services/dart_prefs.dart:45`) all `writeAsString` in place. Rust does temp+rename (`export/mod.rs:237`); Dart does not. A crash mid-write truncates the user's edited transcript. No disk-space check exists anywhere in either language. | **P1** |

Beyond these, the recurring theme is **drift between what the code says and what
it does**: 4 whole files and ~20 FRB functions are unreachable, `main.dart:109`
documents a Settings route to the setup wizard that does not exist, a Settings
snackbar tells users to "Selesaikan Setup Wizard" they cannot open, "Lihat Rilis"
is an empty callback with a `// Open release page` comment, and the update checker
compares against a hardcoded `0.1.0` while `pubspec.yaml` says `1.0.0`.

**Counts.** 71 Dart files, ~10.4 kLOC hand-written (excluding `lib/src/rust`
codegen). 114 Dart tests. Zero test coverage on 21 of those files including the
export dialog, the summary panel, the update checker and `main.dart`. Zero
localisation infrastructure (no `intl`, no ARB, no `l10n.yaml`) — every string is
a literal inside a widget. 25 hardcoded colour literals bypass the theme, 6 of
which duplicate a token that already exists.

---

# Part A — UI/UX audit, screen by screen

## A.0 Cross-cutting: navigation map

```
main() ──► RustLib.init ──► acquireInstanceLock ──► TrayService.init
             │
             └─► modelsReady ? MainScreen : _OnboardingRoute        (main.dart:110)
                                              └─► OnboardingScreen  (once, ever)

MainScreen  (home, no route name, no Navigator root beyond MaterialApp.home)
 ├ header ▸ "Upload File"   ──► LibraryScreen              ⚠ lands on the *Sesi* tab
 ├ header ▸ "Perpustakaan"  ──► LibraryScreen
 ├ header ▸ "Pengaturan"    ──► SettingsScreen ─► SettingsSidePanel(embedded: true)
 │                                 ├ "Laporan Privasi"    ──► PrivacyReportScreen
 │                                 ├ "Dasbor Penggunaan"  ──► UsageDashboardScreen
 │                                 ├ "Cek Pembaruan"      ──► AlertDialog ("Lihat Rilis" = no-op)
 │                                 └ "Tentang"            ──► showAboutDialog (version 1.0.0 hardcoded)
 ├ header ▸ theme toggle    (light ⇄ dark only; never "system")
 ├ ⌘/Ctrl+L ─► LibraryScreen · ⌘/Ctrl+, ─► SettingsScreen · ⌘/Ctrl+/ ─► inline shortcuts panel
 └ LibraryScreen
    ├ tab "Sesi"          ─► SessionCard ─► TranscriptPlayerScreen
    │                                        ├ SummaryPanel (inline, collapsible)
    │                                        ├ "Transkrip Ulang" ─► _RetranscribeDialog
    │                                        └ "Ekspor"          ─► showEksporDialog ─► FilePicker
    └ tab "Upload Berkas" ─► FileUploadZone (drag-drop + picker + queue)

UNREACHABLE FROM THE APP
 ✗ SetupWizardScreen        935 lines, 4 steps, 3 tests — no lib/ importer
 ✗ SetupOverlay             the only caller of doctor.rs — no lib/ importer
 ✗ ResourceHud              124 lines — no importer (MainScreen has its own _FooterBar)
 ✗ VuMeter                  114 lines — no importer (MainScreen has its own _VuMeterRow)
 ✗ widgets/shortcuts_panel  70 lines — no importer (MainScreen has its own _ShortcutsPanel)
 ✗ services/flight_recorder 170 lines — no importer
```

**A.0-1 · P1 · Four dead screens/widgets and one dead service, ~1 400 lines.**
Evidence: `lib/screens/setup_wizard_screen.dart` (only importer:
`test/setup_wizard_test.dart:5`), `lib/widgets/setup_overlay.dart` (only
`test/test_helpers.dart:10`), `lib/widgets/resource_hud.dart`,
`lib/widgets/vu_meter.dart`, `lib/widgets/shortcuts_panel.dart`,
`lib/services/flight_recorder.dart` — verified by exhaustive import grep across
`lib/`. Three of them are *duplicates* of private classes inside
`main_screen.dart` (`_VuMeterRow:619`, `_ShortcutsPanel:761`, `_FooterBar:683`),
so a fix to one silently misses the other.
**Fix:** delete `resource_hud.dart`, `vu_meter.dart`, `widgets/shortcuts_panel.dart`,
`services/flight_recorder.dart`. For the wizard and overlay, see A.6-1 and A.0-2 —
they should be *wired*, not deleted.

**A.0-2 · P1 · Preflight diagnostics never run (UX-04).**
`SetupOverlay` is the only caller of `rust_api.runPreflightChecks()`
(`setup_overlay.dart:38`) and `formatPreflightChecks` (`:42`), and nothing in
`lib/` renders it. Consequence: a user with a missing model, a revoked mic
permission, or no PulseAudio gets no diagnosis — they get a record button that
either hangs or produces silence, and then a 12-second watchdog toast
(`audio_watchdog_model.dart:67`) that guesses at three possible causes.
**Fix:** wrap `MainScreen` in `SetupOverlay` in `main.dart:110`, and add a
"Diagnostik" tile in Settings → Lainnya that re-runs it on demand.

**A.0-3 · P2 · `main.dart:109` documents a route that does not exist.**
> `// The legacy SetupWizardScreen remains reachable from Settings for power users.`

It is not. `settings_side_panel.dart` has no such tile. Worse,
`settings_side_panel.dart:174` tells the user
*"Model pilihan belum tersedia. Selesaikan Setup Wizard terlebih dahulu."* —
instructing them to complete a wizard they cannot reach. The correct action is
to open the download dialog, which already exists
(`showModelDownloadDialog`, used by `_QualityToggle` at `main_screen.dart:869`).
**Fix:** either wire the wizard into Settings (making both statements true) or
change the snackbar to offer the download inline.

**A.0-4 · P2 · Twenty-one FRB-exposed Rust functions have no Dart caller.**
Verified: `getAppConfig`, `resumePendingTranscriptions`, `engineVersion`,
`healthCheck`, `getLoopbackDevice`, `setSessionMode`, `getSessionStatus`,
`exportSanitizeFilename`, `decodeAudioFile`, `isAnotherInstanceRunning`,
`releaseInstanceLock`, and all 9 `flight*` functions (`rust_core/src/api.rs:19-493`).
`releaseInstanceLock` never being called means the single-instance lock is only
ever released by process death.
**Fix:** delete or give callers. `flight*` in particular should get a caller —
see PR-07 (no log file exists for bug reports).

**A.0-5 · P3 · Back affordance is an iOS chevron on a desktop app, untooltipped.**
`Icons.arrow_back_ios_new` at `library_screen.dart:238` and
`transcript_player_screen.dart:260`, both overriding the platform-correct
`AppBar` default, neither with a `tooltip`. `SettingsScreen` (`:11`) uses the
default and therefore looks different from the other two.

---

## A.1 Main / recording screen — `lib/screens/main_screen.dart` (907 lines)

**Purpose.** Start a recording, watch the transcript appear, stop and have it
saved. **Primary action:** the record button (`AnimatedRecordButton`,
`main_screen.dart:604`).

**Is the primary action obvious?** Yes — bottom-right of the control bar,
teal-filled, pulsing while active, with an explicit label ("Mulai" / "Berhenti" /
"Lanjutkan") rather than icon-only. This is the best-executed control in the app:
it has a busy state with a distinct label (`isBusy`/`busyLabel`, wired at
`:401-402`), which is how the 221 s freeze of Round 2 became legible.

### Information architecture

**A.1-1 · P2 · The "Upload File" header button does not open upload.**
`main_screen.dart:332-346` pushes `LibraryScreen` with no tab argument;
`LibraryScreen` hardcodes `DefaultTabController(length: 2)` with the "Sesi" tab
first (`library_screen.dart:228-249`). Two adjacent header buttons therefore do
the identical thing, and the one labelled "Upload File" shows the session list.
**Fix:** add `int initialTab = 0` to `LibraryScreen` and pass `1`.

**A.1-2 · P2 · Icon-only header, no labels, 18 px icons in 32 px hit boxes.**
`:332-385` — four `IconButton`s with `constraints: BoxConstraints(minWidth: 32,
minHeight: 32)` and `padding: EdgeInsets.zero`. All four have tooltips (good) but
32×32 is below the 44×44 (Apple) / 48×48 (Material) minimum, and this is the app's
only global navigation.

### States coverage

| State | Covered? | Evidence |
|---|:--:|---|
| idle / empty | ✅ | `TranscriptView` empty state with a shortcut hint, `transcript_view.dart:103-109` |
| loading (session starting) | ✅ | `_isStartingSession` → "Memulai..." spinner, `:142`, `:402` |
| loading (recovery scan) | ✅ | `LinearProgressIndicator(minHeight: 2)`, `:272-273` |
| recording | ✅ | VU meters `:524`, pulsing button, footer dot + timer `:717-739` |
| paused | ✅ | orange dot `:723`, "Lanjutkan" label |
| error — start failed | ✅ | toast, `:147` |
| error — capture died mid-session | ✅ | `sessionNoticeProvider` toast, `:220-224` |
| error — silent capture | ✅ | 12 s watchdog toast, `:210-214` |
| **error — save failed on stop** | ⚠️ **toast only, no retry** | `:117-120`. See A.1-3. |
| **permission denied** | ❌ **not distinguished** | no branch anywhere maps a permission error to a "grant access" affordance |
| **offline** | n/a by design | recording never needs network |
| **model missing** | ⚠️ partial | `_QualityToggle` offers a download `:865-880`, but the record button does not — Rust resolves the path and throws into a generic toast |
| **long content (3 h, 5 000 segments)** | ❌ **see A.1-6, A.1-7** | |

**A.1-3 · P1 · A failed auto-save on stop is announced and then abandoned.**
`session_model.dart:304-315` throws `TranscribeSaveError`;
`main_screen.dart:117-120` shows a 3-second toast and `finally` clears the busy
flag. The segments are still in `state.segments`, but there is no "Coba lagi",
no "Simpan ke lokasi lain", and the only other save path is "Ekspor", which the
user has no reason to know is the workaround. Combined with the 3-second
auto-dismissing toast (`app_toast.dart:13`), a user who looks away loses a
3-hour meeting and never learns why. Disk-full is the realistic trigger — and
nothing checks free space (PR-03).
**Fix:** on `TranscribeSaveError`, show a persistent (non-auto-dismissing) banner
with "Coba lagi" and "Pilih folder lain", and keep `lifecycle` out of `idle`
until one succeeds.

**A.1-4 · P2 · Only one notice is ever visible.** `AppToast._current?.remove()`
(`app_toast.dart:15`) replaces the previous toast unconditionally. Rapat Online
failing both sources emits two notices (`session.rs` `decide_start` warns per
source); the user sees the second only. Errors also auto-dismiss in 3 s with no
dismiss button and no history.
**Fix:** queue toasts, give `ToastType.error` no auto-dismiss and a close button,
and log all notices into a session-scoped list reachable from the footer.

### Interaction

Keyboard: `CallbackShortcuts` at `:226-264` binds ⌘/Ctrl + `R` (start/stop),
`P` (pause/resume), `L` (library), `,` (settings), `/` (shortcut panel) — both
the meta and control variant of each, correctly, so it works on all three
platforms.

**A.1-5 · P2 · The shortcut panel names the wrong modifier on 2 of 3 platforms.**
`:804-808` hardcodes `'Cmd+R'`, `'Cmd+P'`, `'Cmd+L'`, `'Cmd+,'`, `'Cmd+/'`.
On Windows and Linux these are Ctrl. (The empty-state hint at
`transcript_view.dart:107` gets it right: "Tekan Mulai atau Ctrl+R (⌘R)".)
**Fix:** `Platform.isMacOS ? '⌘' : 'Ctrl+'`.

Other interaction gaps:
- **A.1-6 · P2 · No global hotkeys off macOS.** `GlobalHotkeyService` listens on
  `MethodChannel('com.trareon.global_hotkey')` (`global_hotkey_service.dart:6`)
  which only the macOS `AppDelegate` publishes to. Silent no-op elsewhere. This
  matters more than it looks: the app's headline is minimise-to-tray recording,
  and on Windows/Linux there is then no way to stop it without restoring the
  window.
- **P2 · No undo for speaker rename** (`:411-415` → `renameSpeaker` rewrites every
  matching segment in place, `session_model.dart:390-396`).
- **P2 · Segments are not editable during recording.** `TranscriptView` is
  constructed without `onEdit` at `:409-416`, so the edit affordance is hidden
  (`transcript_view.dart:325`, `:479`). A notulis correcting a name as it is
  mis-transcribed must wait until the session is saved and reopened from the
  library.
- **P3 · Stop asks for confirmation although stop is not destructive**
  (`:84-104`), while genuinely destructive actions elsewhere do not (re-transcribe,
  queue clear).
- **P3 · No drag & drop onto the main screen.** Dropping an audio file on the
  home window does nothing; `DropTarget` exists only inside the library's upload
  tab (`file_upload_zone.dart:81`).

### Visual

- `_ControlBar` (`:445`) — the horizontal-scroll wrapper at `:548` is a real fix
  for narrow windows and is correctly commented.
- **A.1-7 · P2 · Hardcoded VU colours.** `Color(0xFF2E7D32)` (`:640`) and
  `Color(0xFFE65100)` (`:646`). The first duplicates `AppColors.statusActive`;
  the second exists nowhere else. Neither is theme-aware: `#E65100` on dark
  `chipBackground` `#2C2C2C` is 3.0:1.
- **P3** `Colors.orange` for the paused dot (`:723`) while the active dot uses
  `AppColors.statusActive` — one token, one Material constant, side by side.
- **P3** `Colors.black.withValues(alpha: 0.1)` shadow (`:776`) is invisible in
  dark mode.
- **P2 · Typography has no scale.** Font sizes used in this file alone: 10, 11,
  12, 13, 14, 15 — all as bare `fontSize:` literals, never
  `Theme.of(context).textTheme.*`. The theme *does* define a text theme
  (`app_theme.dart:47-50`) and no screen uses it except `PrivacyReportScreen` and
  `UsageDashboardScreen`. Two typographic systems coexist.
- **P3** `fontFamily: 'monospace'` (`:736`, `:748`, `:839`) is not a declared
  font family in `pubspec.yaml`; it resolves to whatever the platform picks, so
  the timer's glyph width differs per OS. `FontFeature.tabularFigures()` (used
  correctly at `transcript_view.dart:386`) is the portable way.

### Accessibility

- **A.1-8 · P1 · No `Semantics` anywhere in this file.** Grep: 0 occurrences in
  `main_screen.dart`. The record button, the recovery banner, the elapsed timer,
  the VU meters and the segment counter are all unlabelled. A screen reader gets
  "Mulai" for the button (from the `Text`) and nothing at all for the state.
  `AnimatedRecordButton` is a `GestureDetector`-style `InkWell` with no
  `button: true`, no `Semantics.value` for recording state, and no live region
  for the timer.
  **Fix:** `Semantics(button: true, label: …, value: isRecording ? 'merekam' : 'siap')`
  on the record button; `liveRegion: true` on the timer and segment count;
  labels on both VU bars.
- **P2** Tooltips: 4 of 5 `IconButton`s have one; the shortcut-panel close button
  (`:797-800`) does not.
- **P2 · Text scaling.** Every bar has a fixed height (`Container(height: 44)` at
  `:312`, `height: 36` at `:490` and `:589`). At `MediaQuery.textScaler` 1.5 the
  13 px label in a 36 px box clips. Nothing uses `textScaler` or
  `MediaQuery.withNoTextScaling`.

### Copy

**A.1-9 · P2 · Mixed English in an Indonesian-first product.** In this file:
`'Upload File'` (`:334`). Elsewhere: `'Progressive Mode'`
(`settings_side_panel.dart:187`), `'Echo Dedupe'` (`:244`), `'API key'`
(`summary_settings_section.dart:173`), `'Keputusan & Action Items'`
(`models.dart:36`), `'Standup Harian'` (`:37`), `'Decoding'`
(`file_upload_zone.dart:240`), `'Tone Test'`
(`setup_wizard_screen.dart:864`), `'CPU Cores'` (`:415`), `'Upload Berkas'` tab
(`library_screen.dart:247`), `'Setup Audio'`, `'Pilih Model'`.
Also inconsistent internally: the Settings tile says **"Dasbor Penggunaan"**
while the screen it opens is titled **"Statistik Penggunaan"**
(`settings_side_panel.dart:347` vs `usage_dashboard_screen.dart:154`).

**A.1-10 · P2 · Jargon leaking to users.** `"VAD (deteksi suara)"`
(`settings_side_panel.dart:235`) — the gloss is good, the acronym is still
first. `"Progressive Mode"`, `"Echo Dedupe"`, `"HPT"` (in the `HptMode` enum,
not user-visible — good), `"Decoding"`. The model-label indirection
(`utils/model_labels.dart`, "Cepat"/"Akurat (disarankan)") is exactly right and
should be the pattern for these too.
**Suggested Indonesian:** VAD → "Saring suara latar"; Progressive Mode →
"Mulai cepat, sempurnakan otomatis"; Echo Dedupe → "Hapus suara ganda";
Decoding → "Membaca berkas".

### Performance

**A.1-11 · P1 · The whole transcript list is recomputed 5× per second while
recording, and the recompute is O(total segments).**
Three independent 1–5 Hz `setState` sources converge on one rebuild:

1. `Timer.periodic(1 s)` updating `elapsedSeconds` → new `SessionUiState`
   (`session_model.dart:138-148`).
2. `vuLevelProvider` — the Rust poll timer fires every 200 ms
   (`bridge_service.dart:466`) and emits a `VuLevel` whenever any VU event
   arrived (`:558-563`), i.e. ~5 Hz.
3. Every arriving segment.

`MainScreen.build` watches `sessionProvider` *and* `vuLevelProvider` (`:187`,
`:195`), so each of those rebuilds `TranscriptView`, whose `build` constructs a
**complete `(index, segment)` tuple list over every segment** before handing it
to `ListView.builder` (`transcript_view.dart:183-190`). At 5 000 segments that is
5 000 allocations × 5 Hz = **25 000 tuples/second**, permanently, for a UI that
displays ~15 rows.

**A.1-12 · P1 · Segment ingestion is O(n²) over a session.**
`_onTranscriptSegment` (`session_model.dart:112-130`) does a linear
`indexWhere` over all segments for every arriving segment, then copies the whole
list (`[...segments, segment]`). Over 5 000 segments: ~12.5 M comparisons and
~12.5 M element copies, all on the UI isolate, all while Whisper is saturating
the CPU.
**Fix:** keep a `Map<String, int> _indexByKey` beside the list; mutate a growable
list and expose an unmodifiable view instead of copying.

**A.1-13 · P2 · Per-row entry animation replays on every scroll.**
`_SegmentTile` wraps each row in `TweenAnimationBuilder` 0→1 with a
`Transform.translate` (`transcript_view.dart:300-312`) and the tile has no `key`.
`ListView.builder` recycles elements, so scrolling a long transcript makes every
row fade-and-slide in again, and filtering by search re-animates the entire list.
**Fix:** `ValueKey(segment.segmentKey)` on the tile and animate only rows whose
index exceeds the highest index seen.

**Timers — all correctly cancelled.** `_elapsedTimer`/`_autoStopTimer`
(`session_model.dart:462-468`), `_pollTimers` (`bridge_service.dart:472`),
watchdog (`audio_watchdog_model.dart:84-88`), toast controller
(`app_toast.dart:87`). One exception: `TrayService._watchWindowFrame`
(`tray_service.dart:95`) starts a `Timer.periodic` that self-cancels after 10
ticks but is never stored, so `dispose` cannot stop it — harmless (8 s) but it is
the one un-owned timer in the codebase.

---

## A.2 Library — `lib/screens/library_screen.dart` (361 lines)

**Purpose.** Find and open a past session. **Primary action:** tap a card.
Obvious? Yes. Search, rename, export and delete are all present and discoverable
(`session_card.dart:172-188`), which is a genuine improvement over the
pre-parity state.

### Information architecture

Two tabs, "Sesi" and "Upload Berkas", which are unrelated tasks sharing a screen
because the upload zone had nowhere else to live. A user looking for "transkrip
sebuah rekaman lama" has to guess that it is behind a tab inside
*Perpustakaan* — or use the header button that claims to do it and doesn't
(A.1-1).

### States coverage

| State | Covered? | Evidence |
|---|:--:|---|
| loading | ✅ | `CircularProgressIndicator`, `:289` |
| empty library | ✅ | `EmptyState`, `:291-295` |
| empty search result | ✅ | separate `EmptyState`, `:297-300` |
| deleted (with undo) | ✅ | 5 s soft delete + SnackBar, `:101-132` |
| rename error | ✅ | SnackBar, `:186-188` |
| **library load error** | ❌ | `loadSessionLibrary` swallows every failure and returns `const []` (`session_store.dart:301-303`, `:334-336`). An unreadable library directory (wrong permissions, unmounted network drive) is indistinguishable from an empty one. |
| **corrupt session** | ⚠️ silently skipped | `session_store.dart:334` `continue`. The user is never told one of their meetings failed to load. |
| **partial** (transcript present, audio missing) | ⚠️ | card renders; the player then shows "File audio sumber tidak tersedia" (`transcript_player_screen.dart:77`) only after you open it |
| long content | ❌ | see A.2-4/A.2-5 |

**A.2-1 · P1 · A failed library scan is displayed as "Belum ada sesi tersimpan".**
For a government user whose library path points at a mounted share, this reads
as "your meetings are gone."
**Fix:** have `loadSessionLibrary` return `(sessions, errors)` and render a
distinct error state with the path and the OS error.

### Interaction

- **A.2-2 · P2 · Delete has undo for 5 s, but leaving the screen deletes
  immediately.** `dispose()` (`:84-91`) cancels the timer and then
  `deleteSync(recursive: true)` right away. Pressing Back inside the undo window
  destroys the data with the undo button still theoretically on screen.
  Conversely, if the app is killed inside the window the directory survives but
  was already removed from the list — it reappears on next launch. Two opposite
  surprises from one mechanism.
  **Fix:** move to a real trash: rename the directory to `.trash/<name>` on
  delete, purge on next launch, restore on undo. That also survives A.2-3.
- **P2 · No confirmation on delete.** Undo-instead-of-confirm is a defensible
  choice, but combined with A.2-2 the undo is not reliable.
- **P2 · No keyboard shortcuts at all on this screen.** No `/` or ⌘F to focus
  search, no Esc to clear it, no arrow-key navigation of the list, no Enter to
  open, no Delete to delete. There is no `FocusTraversalGroup`, so tab order is
  source order: search field → (storage bar) → per card: rename, export, delete,
  card — i.e. the destructive button is reached before the primary one on every
  row.
- **P3 · No sort or filter.** Sorted by date descending, always
  (`session_store.dart:339`). No sort by duration/title, no date-range filter, no
  "only with summary" filter, although `meta.hasSummary` is already loaded.
- **P3 · No bulk operations.** No multi-select, so cleaning up 50 sessions is 50
  delete-and-wait-5-seconds cycles.

### Visual

- **P2 · The storage bar is a list item.** `itemCount: filtered.length + 1` with
  `index == 0` returning `StorageBar` (`:303-311`). It scrolls away, it is
  counted in the separator rhythm, and — see A.2-6 — it re-runs a recursive disk
  scan every time it re-enters the viewport.
- **P3 · Emoji as iconography.** `'📁 ${widget.totalSessions}'` / `'📂 Kosong'`
  (`storage_bar.dart:102-103`) next to Material icons everywhere else; renders
  differently on all three platforms.
- **P3** Search field styles its own `OutlineInputBorder` and `fillColor`
  (`:275-283`) instead of using `inputDecorationTheme`, which already specifies
  exactly that (`app_theme.dart:63-79`) — with a different radius (8 vs 10).

### Accessibility

- **P1 · No `Semantics` in `library_screen.dart` or `session_card.dart`.** The
  three per-row `IconButton`s do have tooltips (`session_card.dart:176`, `:181`,
  `:186`), which screen readers use — but the card itself announces its raw
  children ("Rapat Tim", "30 Sep 2026", "45 menit", "128 segmen") with no
  indication it is tappable.
- **P2** Default `IconButton` size is 48×48 here (no `constraints` override) —
  correct, and inconsistent with `main_screen.dart` (32×32) and
  `transcript_view.dart` (32×32).

### Copy

`'Upload Berkas'` tab label (`:247`) mixes English. The search hint
("Cari judul, isi transkrip, atau ringkasan...") is excellent — it tells the user
the search is full-text, which they could not otherwise know.

### Performance — the scalability wall

**A.2-3 · P1 · Opening the library parses every transcript in the corpus, on the
UI isolate.** `loadSessionLibrary` (`session_store.dart:293-341`) iterates every
directory and for each one: `listSync()`, `readAsString()` the whole transcript,
`jsonDecode`, `parseTranscriptJson` into `TranscriptSegment` objects, `readSessionMeta`,
`stat()`, and a second `listSync()` for the audio file. For 200 sessions × 5 000
segments that is **1 000 000 `TranscriptSegment` objects**, several hundred MB,
and seconds-to-minutes of synchronous JSON parsing with the UI showing a spinner
that cannot animate (the decode blocks the isolate).
**Fix:** two-phase load. Phase 1 reads only the sidecar plus a cheap index
(segment count, duration, first line) — write an index file on export so this is
one small read per session. Phase 2 loads a session's segments only when it is
opened. Move any bulk parsing to `compute()`.

**A.2-4 · P1 · Search re-scans the entire corpus on every keystroke.**
`onChanged: (v) => setState(() => _query = v)` (`:260`) → `_filteredSessions`
(`:98-99`) → `sessionMatchesQuery` which does
`record.segments.any((s) => s.text.toLowerCase().contains(q))`
(`session_store.dart:190`) — plus `matchingSnippet` (`:195-204`) re-walks the
segments of every *matching* record to build the snippet, in the `itemBuilder`
(`library_screen.dart:316-317`), i.e. again on every rebuild. `toLowerCase()`
allocates a new string per segment per keystroke.
**Fix:** debounce 200 ms; precompute one lowercased haystack per session at load;
memoise the snippet per (session, query).

**A.2-5 · P2 · Reloads the whole library after closing a session.**
`_openSession` awaits the player and then calls `_loadFromDisk()`
unconditionally (`:220`), paying A.2-3 again even if the user only looked.
**Fix:** have the player return what changed and patch that one record.

**A.2-6 · P2 · `StorageBar` spawns a recursive-stat isolate whenever it scrolls
into view.** `initState` → `compute(_computeBytesSync, libraryPath)`
(`storage_bar.dart:35`, `:50`) walking `listSync(recursive: true)` with a
`statSync` per file. As list item 0 it is disposed and re-created on scroll, and
`didUpdateWidget` re-triggers on any `totalSessions` change (`:39-45`). On a
50 GB library that is a full directory walk per scroll-back.
**Fix:** hoist it out of the list into a fixed header and cache the result with a
TTL.

**A.2-7 · P2 · The displayed date is the directory's mtime, not the meeting's
date.** `date: stat.modified.toIso8601String().substring(0, 10)`
(`session_store.dart:325`), and it is also the sort key (`:339`). Renaming a
session, saving a summary, or re-transcribing all write inside the directory and
therefore bump its mtime — so editing an old meeting moves it to the top of the
list and relabels it today. The real date is available two ways: the `YYYYMMDD-`
directory prefix that `titleFromDirName` already parses (`:174-177`), and
`started_at_unix_ms` which the recovery snapshot carries but the sidecar does not.
**Fix:** store `recorded_at` in the sidecar; fall back to the directory prefix.

---

## A.3 Transcript player — `lib/screens/transcript_player_screen.dart` (468 lines)

**Purpose.** Listen back, correct the transcript, summarise, re-transcribe,
export. **Primary action:** ambiguous — the screen has five co-equal ones
(play, edit, summarise, re-transcribe, export) and no visual hierarchy between
them. For the notulen workflow the primary action is *correct the text while
listening*, and that is the one the layout serves worst.

### Information architecture

Summary panel (top) → transcript (expanded) → player controls + two outlined
buttons (bottom). Reasonable. But "Transkrip Ulang" (destructive: replaces the
transcript) and "Ekspor" (benign) are rendered identically —
`OutlinedButton.icon` with `colors.primary` foreground, same size, adjacent
(`:390-425`).

### States coverage

| State | Covered? | Evidence |
|---|:--:|---|
| audio missing | ✅ | `_error` set, all controls disabled via `widget.audioPath == null`, `:77`, `:313`, `:331` |
| audio decode failure | ✅ | `:99-102` |
| empty transcript | ✅ | via `TranscriptView` empty state |
| summary absent / present / generating / failed | ✅ | `SummaryPanel` covers all four (`summary_panel.dart:127-275`) |
| summary disabled | ✅ | explicit notice pointing at Settings, `summary_panel.dart:161-169` |
| re-transcribe running / failed / no-speech | ✅ | `retranscribe_dialog.dart:205-230`, and it distinguishes "engine failed" from "nothing heard" (`:120-125`) — good |
| **transcript save failure** | ❌ **`debugPrint` only** | `:147`. See A.3-1. |
| **long content** | ❌ | see A.3-4, A.3-5 |
| **unsaved edits on exit** | ❌ | no guard; a 400 ms debounce may be in flight when the route pops |

**A.3-1 · P1 · A failed transcript save is written to the debug console.**
```dart
} catch (e) {
  debugPrint('_persistSegments error: $e');   // transcript_player_screen.dart:147
}
```
The user has just edited their transcript; the write failed (read-only mount,
disk full, file removed); the UI shows the edit applied. Next open, it is gone.
**Fix:** surface it, and keep a dirty flag so the route can warn on pop.

**A.3-2 · P1 · The transcript is overwritten in place, non-atomically, on a
400 ms debounce, with no backup (PR-02).**
`_schedulePersist` (`:124-127`) → `_persistSegments` →
`jsonFile.writeAsString(encodeTranscriptJson(_segments))` (`:145`). A crash or
power loss during that write truncates the only copy. The Rust exporter writes
`*.tmp` then renames (`rust_core/src/export/mod.rs:237-239`); the Dart path that
rewrites the same file does not.
**Fix:** write `<name>.json.tmp`, `flush`, `rename`. Same for
`writeSessionMeta` (`session_store.dart:226`) and `DartPrefs.save`
(`dart_prefs.dart:45`).

**A.3-3 · P2 · "Transkrip Ulang" destroys the old transcript with no undo.**
The dialog is careful about *failure* (`retranscribe_dialog.dart:29-31`,
and the copy says so at `:161-163`), but on success `_retranscribe` replaces
`_segments` and calls `_persistSegments()` (`:168-170`) — overwriting hand-made
corrections with machine output, permanently. The summary is deliberately spared
(`:151-154`); the transcript, which the user may have spent an hour correcting,
is not.
**Fix:** copy the old transcript to `transcript.<timestamp>.json` before writing,
and offer "Kembalikan transkrip sebelumnya" in a snackbar action.

### Interaction

- **A.3-4 · P1 · The transcript does not follow the audio, and you cannot click a
  line to seek.** `activeSegmentIndex` is computed (`:247-250`) and highlights a
  row (`transcript_view.dart:295-296`, `:209`), but: (a) the list never
  auto-scrolls to it — `TranscriptView` only auto-scrolls when the segment
  *count* grows (`transcript_view.dart:61-74`), which never happens during
  playback; and (b) `TranscriptView` has no `onSeek` callback at all, so tapping
  a row opens the edit dialog instead of jumping the audio there
  (`transcript_view.dart:325`). Reviewing a 3-hour recording therefore means
  dragging a slider and scrolling a 5 000-row list in parallel by hand. This is
  the single biggest usability gap for the notulen use case.
  **Fix:** add `onSeek(double timestamp)` to `TranscriptView`; make row tap seek
  and the pencil icon edit; scroll the active row into view with
  `ScrollablePositionedList` (or an index-based `jumpTo` using a fixed row-height
  estimate).
- **P2 · No keyboard shortcuts.** No Space to play/pause, no ←/→ to skip, no
  ⌘S to save, no J/K/L transport, no "Tab to next segment / Enter to edit".
  For a transcript-correction tool this is the core interaction model and it is
  absent. (See feature FG-12.)
- **P2 · The playback-speed dropdown does not persist** (`_speed` is local state,
  `:51`) and offers no 0.75× — the most useful step for dictation.
- **P3 · The 10 s skip buttons have tooltips; the play/pause button does not**
  (`:337-344`), and it is the largest control on the screen.
- **P3 · `_speedOptions` renders as `'${s}x'` → "0.5x", "1.0x"** (`:371`);
  Indonesian convention is "0,5×".

### Visual

- **A.3-5 · P2 · Times over an hour are displayed wrong.** `_formatTime`
  (`:192-196`) is `(secs / 60).floor()` minutes — a 3-hour meeting's end shows
  **"185:30"** instead of "3:05:30", and the position readout likewise. Three
  other formatters in the codebase do it correctly
  (`utils/format_time.dart:1-6`, `main_screen.dart:694-700`,
  `resource_hud.dart:25-31`) — four implementations, one of them broken.
  Also `utils/format_time.dart:8-13` `formatTimestamp` drops hours too, and is
  unreferenced.
  **Fix:** one `formatDuration` in `utils/format_time.dart`, used everywhere.
- **P2 · Layout overflows at the documented minimum window height.** The body is
  `Column[SummaryPanel, Expanded(TranscriptView), Container(controls)]` (`:264`).
  Expanded `SummaryPanel` with its 12-line `TextField`
  (`summary_panel.dart:223`) is ~420 px; the control block is ~150 px; the app
  bar 56 px. At the macOS minimum of 700 px content height that leaves the
  transcript ~70 px, and at any smaller height (Linux/Windows have **no**
  minimum — A.11-3) `Expanded` is squeezed to zero and the controls overflow.
  **Fix:** make the summary panel a bottom sheet or a side panel, or cap its
  height at `constraints.maxHeight * 0.4`.
- **P3** `AppColors.warning` (`#FF3B30`) for the error line at 12 px (`:298`) is
  3.55:1 on white — below AA.

### Accessibility

- **P1 · No `Semantics` in this file.** The slider has no semantic label or
  value, so a screen-reader user cannot tell where they are in the audio.
  `Slider` does expose a default value, but as a bare number of seconds.
  **Fix:** `Slider(semanticFormatterCallback: (v) => 'Posisi ${_formatTime(v)}')`
  plus `Semantics(label: 'Posisi pemutaran')`.
- **P2** The per-segment `Semantics` label in `TranscriptView` (`:299`) is good
  and is the one place the app does this properly — but it announces
  `segment.speaker`, not the renamed `displaySpeaker`, so after renaming
  "Peserta 1" → "Pak Budi" the screen reader still says "Peserta 1".

### Performance

**A.3-6 · P1 · Every audio position tick rebuilds the entire screen.**
`onPositionChanged` → `setState(() => _positionSeconds = …)` (`:87-92`). The
`audioplayers` position stream fires ~5–10 Hz. Each tick: (a) `_segments.lastIndexWhere`
over all segments (`:247`), O(n); (b) a full `TranscriptView.build`, which rebuilds
the entire `(index, segment)` list (A.1-11). At 5 000 segments and 10 Hz that is
~100 000 operations per second during playback, on the UI isolate, for a moving
highlight.
**Fix:** hoist position into a `ValueNotifier<double>` and wrap only the slider and
the active-row decoration in `ValueListenableBuilder`; find the active index with a
binary search over the sorted timestamps.

**A.3-7 · P2 · `SummaryPanel` registers a provider that is never disposed.**
`initState` creates a `StateNotifierProvider` (`summary_panel.dart:52-61`) and
the widget then `ref.watch`es it. Locally-constructed providers are added to the
enclosing `ProviderScope` container and are not auto-disposed, so opening N
sessions in one app run leaks N `SummaryNotifier`s and their state (each holding
the summary text).
**Fix:** `StateNotifierProvider.autoDispose.family` keyed on
`sessionDirPath`, declared at top level.

---

## A.4 Settings — `lib/screens/settings_screen.dart` (15 lines) + `lib/widgets/settings_side_panel.dart` (754 lines)

**Purpose.** Configure models, audio, storage, summary, and reach the secondary
screens. **Primary action:** none — it is a settings list, correctly.

### Information architecture

Seven sections: Tampilan · Model & Mode · Audio & Suara · Output & Penyimpanan ·
Transkripsi · Ringkasan AI · Lainnya. Sensible grouping. No search, no
"reset to defaults", no per-setting "what does this do" beyond one `_InfoBadge`
(`:247`) — the pattern exists and is used exactly once.

**A.4-1 · P1 · The panel is a 380 px column inside a full-screen route.**
`SettingsSidePanel` hardcodes `Container(width: 380)` (`:86`) and
`SettingsScreen` puts it in a `Scaffold` body (`settings_screen.dart:12`). On a
1920×1080 window, Settings is a 380 px strip on the left with 1 540 px of empty
scaffold. The `embedded` flag suppresses the header (`:96`) but not the width,
the `Material(elevation: 8)`, or the left border — all three are side-panel
chrome rendered in a full-screen context. The slide-in-from-right animation
(`:44-58`) also plays on the full screen, so opening Settings makes the whole
left column fly in from off-screen right.
**Fix:** when `embedded`, drop the width constraint and the decorations, cap
content width (`ConstrainedBox(maxWidth: 720)`) and centre it; skip the slide
animation.

**A.4-2 · P2 · "Lihat Rilis" is an empty callback.**
```dart
onPressed: () {
  Navigator.pop(context);
  // Open release page          // settings_side_panel.dart:397
},
```
`url_launcher` is not in `pubspec.yaml`, so there is no way to open the URL
`UpdateChecker` already computed (`update_checker.dart:109-110`). The user is
told an update exists and given a button that closes the dialog.

**A.4-3 · P1 · The update checker can never report correctly.**
`UpdateChecker.currentVersion` defaults to `'0.1.0'`
(`update_checker.dart:73`), `pubspec.yaml:19` says `version: 1.0.0+1`, the About
dialog hardcodes `'1.0.0'` (`settings_side_panel.dart:442`), and the repo's
`VERSION` file — the manifest the checker fetches — contains `0.1.0`. So today
it always says "Sudah versi terbaru", and the moment `VERSION` is bumped for a
release it will say "update available" forever, because `currentVersion` is a
constant that no release process touches.
**Fix:** read the version from `package_info_plus` (or generate a
`lib/version.g.dart` from `pubspec.yaml` in CI), assert in CI that `VERSION`
equals `pubspec.yaml`'s version, and use one source for the About dialog too.

**A.4-4 · P2 · "Perbandingan Kecepatan" is a fake tile.** `trailing: const SizedBox.shrink()`
(`:321`) — a tappable-looking row that is a paragraph of static text, inside a
list where every other row does something. The numbers in it
("ringan 3s · cepat 10s · akurat 56s per 1 menit audio") are hardcoded and
machine-independent; the app already measures the real figure
(`benchmarkRtf`, `rtfScore`) and doesn't show it.

**A.4-5 · P2 · Two settings persist but do nothing.** `always_on_top` and
`auto_save_interval_secs` are in `AppSettings` (`rust_core/src/settings.rs:25-26`),
defaulted (`:115-116`), round-tripped in JSON (`:269`), written by Dart
(`bridge_service.dart:817-818`, hardcoded `false`/`10`) and read by no
implementation in either language. `auto_save_interval_secs: 10` in particular
implies a 10-second autosave that does not exist (UX-01/PR-02).

### States coverage

| State | Covered? | Evidence |
|---|:--:|---|
| settings loading | ❌ | `SettingsNotifier` starts from `AppSettings.defaults()` and `_load()` is async (`settings_model.dart:14-18`). Opening Settings in the first frames shows *defaults*, not the user's values, with no skeleton — and a tap in that window writes the default back. |
| save failure | ❌ | every `set*` is `await _bridge.saveSettings(state)` with **no try/catch** (`settings_model.dart:82-203`, 15 call sites). A read-only config dir throws into the void; the UI shows the new value and the next launch shows the old one. |
| model unavailable | ✅ | guarded with a snackbar (`:169-179`) — pointing at the unreachable wizard (A.0-3) |
| summary endpoint unreachable | ✅ | `_modelsError` (`summary_settings_section.dart:237-244`) — and "Muat daftar model" is a genuinely good affordance: it proves the endpoint works before a meeting depends on it |
| update check offline | ✅ | caught and toasted (`:407-415`), with a comment explaining the previous silent failure |
| GPU unavailable | ❌ | the toggle claims "Transkripsi menggunakan GPU (Vulkan/CUDA/Metal) — lebih cepat" (`:199`) with no capability probe. On a build without a GPU backend, or a device with 2 GB VRAM, turning it on is either a no-op or a slowdown; the user gets no feedback either way. |

**A.4-6 · P1 · Settings writes are unguarded and un-verified.** Fifteen
`await _bridge.saveSettings(state)` calls with no error handling
(`settings_model.dart:82-203`). Combined with A.4-7 (theme "Sistem" silently
downgraded) the user's mental model of "my settings are saved" is not backed by
anything.
**Fix:** wrap in try/catch, revert optimistic state on failure, toast the reason.

**A.4-7 · P1 · Theme "Sistem" is silently discarded (UX-06).**
`_toRustSettings`: `settings.theme == AppThemeMode.dark ? dark : light`
(`bridge_service.dart:811-813`) — `system` becomes `light`. `_fromRustSettings`
(`:793-795`) can only ever produce `light` or `dark`. The comment at `:791-792`
acknowledges Rust has no `system` variant and says "default to light rather than
lose information silently" — but that is exactly losing it silently. The
dropdown offers three options and honours two.
**Fix:** add `Theme::System` to the Rust enum (`#[serde(default)]`-safe), or
persist theme in `DartPrefs` where `defaultExportFormat` and `hptMode` already
live.

**A.4-8 · P1 · A ~110-second CPU burn on first launch, invisible.**
`SettingsNotifier._load` → `_backgroundBenchmark` (`settings_model.dart:50-64`)
runs `benchmarkRtf(large-v3-turbo-q5)` whenever `progressiveEnabled &&
rtfScore == 0`, i.e. on every fresh install. Round 2 measured that exact call at
**109.6 s** on a 2-core CPU (`MEETILY-PARITY-REPORT.md:365`). The UI shows
nothing: no progress, no explanation, no way to skip. A user whose first action
after onboarding is to press record is competing with it for the CPU.
It also constructs `RustEngineBridge()` directly (`:61`) instead of using the
injected `_bridge`, so a test with a fake bridge still reaches the real engine.
**Fix:** run it lazily on first session start with a visible notice, or reuse the
engine-side bounded benchmark and its cache (`benchmark_rtf_bounded`, already
built in Round 2) instead of a second unbounded one in Dart. Use `_bridge`.

### Interaction

- **P2 · Text fields commit on `onTapOutside`, not on change or blur-with-Tab.**
  `summary_settings_section.dart:167-168`, `:181-182`, `:200-202`, `:272-276`.
  Tab out of the endpoint field and the value is not saved; click elsewhere and
  it is. No validation of the URL either — a typo is only discovered when a
  summary fails.
- **P2 · Switching the summary provider silently overwrites the URL the user
  typed** (`:148-153`). Defensible, but it should say so.
- **P3 · No shortcut to close Settings** (Esc does nothing;
  `Navigator.pop` only via the AppBar back button).
- **P3 · The API-key field is `obscureText: true` with no reveal toggle**
  (`:178`) — so a mistyped key cannot be checked.

### Visual

- **P2 · Fixed 380 px width + long Indonesian labels = guaranteed clipping.**
  `_SettingsTile` gives the label an `Expanded` and the trailing control
  `Flexible(fit: FlexFit.loose)` (`:548-577`), and `_CompactDropdown` sets
  `isExpanded: true` (`:673`) — so the dropdown shrinks to whatever is left.
  "Keputusan & Action Items" in the template dropdown under a 15 px label ellipses
  to "Keputusan &…".
- **P3** `Colors.teal` for the About icon (`:443`) — a fifth teal, not from the
  palette.
- **P3** `_SettingsDivider` uses `indent: 56` (`:515`) matching the 22 px icon +
  14 px gap + 16 px padding = 52, not 56.

### Accessibility

- **P1 · No `Semantics` in this 754-line file.** The switches carry their label
  only as an adjacent `Text`, which `Switch` does not adopt — a screen reader
  announces "switch, on" with no indication of *what* is on. The file's own
  comment (`:98-100`) explains it avoided `SwitchListTile` because of a Material
  ancestor assertion; the accessibility that `SwitchListTile` provides for free
  was not replaced.
  **Fix:** `Semantics(toggled: value, label: label, child: ExcludeSemantics(child: Switch(...)))`
  or wrap each row in `MergeSemantics`.
- **P2** `_InfoBadge` is an `InkWell` with no `Semantics(button: true)` and no
  tooltip (`:709-735`); its only label is the word "Info".
- **P2** `_CompactDropdown` items are 13 px in a `vertical: 4` container — a
  ~26 px hit target (`:664`).

### Copy

"Progressive Mode", "Echo Dedupe", "VAD", "API key" (A.1-9/A.1-10). The
sub-labels are otherwise good — several explain the *consequence* rather than the
mechanism ("Berlaku mulai sesi berikutnya" at `:237` is exactly the right level
of detail), and the privacy sub-label ("Mati — aplikasi tetap 100% offline",
`summary_settings_section.dart:118`) is the best single line of copy in the app.

---

## A.5 Onboarding — `lib/screens/onboarding_screen.dart` (184 lines)

**Purpose.** Download two models before first use. **Primary action:** wait, then
"Mulai menggunakan". Obvious: yes, it is the only button.

**A.5-1 · P1 · The product name is misspelled (UX-03).**
```dart
'Selamat datang di Traeon Transcribe',    // onboarding_screen.dart:43
```
Missing the `r`. This is the first sentence of the product. (The repo has the
same typo in a filename, `TRAEREON-TRANSCRIBE-V2-BLUEPRINT.md`, suggesting it is
habitual — worth a CI grep for `Traeon|Traereon`.)

**A.5-2 · P1 · The screen promises background downloads it does not do.**
> "Anda boleh menutup aplikasi — unduhan akan dilanjutkan di latar belakang."
> (`:103`)

Closing the app kills the process and the download with it. What is actually true
is that the download *resumes* on next launch (`model.rs` `download_with_resume`)
— a different and less reassuring promise.
**Fix:** "Anda boleh menutup aplikasi — unduhan akan dilanjutkan saat aplikasi
dibuka lagi."

### States coverage

| State | Covered? | Evidence |
|---|:--:|---|
| idle / downloading / ready / error, per model | ✅ | `ModelDownloadCard` covers all four (`model_download_card.dart:97-116`) |
| retry | ✅ | `:74-87`, per-model retry functions exist and are both invoked |
| already downloaded | ✅ | skipped via `isModelDownloaded` (`onboarding_model.dart:93-96`) |
| **offline at first launch** | ⚠️ | shows "Gagal mengunduh: <raw Rust error>" (`onboarding_model.dart:148`). No "check your connection", no distinction between no-network and 404. |
| **disk full** | ❌ | 690 MB required, never checked, surfaces as a raw error |
| **checksum mismatch** | ⚠️ | `verify_checksum` fails → generic "Gagal mengunduh" with the Rust message; no "file corrupt, retrying" story |
| **skip / continue with one model** | ❌ | see A.5-3 |
| **cancel** | ❌ | no cancel; quitting is the only exit |

**A.5-3 · P1 · 690 MB is mandatory before the app can be used at all.**
`allReady` requires *both* models (`:127-129`) and the continue button is
disabled until then (`:90`). The app is usable with `base` alone (142 MB) — that
is what `_QualityToggle`'s "Cepat" mode uses, and `modelsReadyProvider` only
checks `isModelAvailable('base')` (`main.dart:83-85`). For the target audience
(Indonesian government/campus networks, metered mobile tethering) forcing a
548 MB download before the first transcript is a hard adoption barrier.
**Fix:** enable "Mulai menggunakan" as soon as `quick` is ready; keep the
accurate model downloading in-app with a progress chip in the header; explain
that "Akurat" and "Transkrip Ulang" unlock when it finishes.

- **P2 · No estimate and no total.** No bytes-downloaded/total, no speed, no ETA
  — just a percentage (`model_download_card.dart:113`). For a 548 MB file on a
  slow link, "37%" with no rate is indistinguishable from stalled.
- **P2 · No pause.** A meeting starting in 5 minutes cannot reclaim the bandwidth.
- **P2 · No "Bahasa" step.** The app's differentiator is Indonesian-first, and
  onboarding never mentions or confirms language. `language` defaults to `id`
  in Rust — correct, but invisible.
- **P2 · No privacy statement at the moment of the only unavoidable network
  call.** "Model tidak akan pernah dikirim ke cloud" (`:102`) appears *after*
  success and is about the wrong direction of traffic. This is the natural place
  for the one-screen "everything stays on your device" promise the product is
  built on, and for a UU PDP consent notice (FG-08).
- **P3 · `Spacer()` inside a non-scrolling `Column`** (`:73`) — at 600 px height
  with text scaling the two 90 px cards plus header overflow.
- **P3** Retry is one button that retries both failed models (`:76-87`) while
  `ModelDownloadCard` shows the error per model — the affordance granularity
  doesn't match the state granularity.

**A.5-4 · P2 · There is no way back to onboarding, ever.** `modelsReadyProvider`
is a `StateProvider` seeded once from disk (`main.dart:83-85`) and flipped by the
continue button (`:143`). If the user later deletes the models, the app still
routes to `MainScreen` and fails at record time. There is no "re-download
models" action anywhere in Settings — only the implicit one inside
`_QualityToggle`.

---

## A.6 Setup wizard — `lib/screens/setup_wizard_screen.dart` (935 lines) — **UNREACHABLE**

**A.6-1 · P1 · 935 lines of finished, tested, well-built UI that no user can
open.** Four steps (spec detect → model choice → audio setup → tone test) with a
progress bar, back/next navigation, real device enumeration, a BlackHole
detection card with install instructions, and a generated 440 Hz test tone. Three
widget tests cover it. Nothing in `lib/` imports it.

This is the most valuable dead code in the repo, because it contains the
**only** UI for things the app otherwise cannot do:
- choosing the mic and speaker device (`_AudioSetupStep`, `:553-729`) — elsewhere
  devices are auto-resolved with no override;
- verifying audio output works before a meeting (`_ToneTestStep`, `:770-935`);
- seeing what the app thinks of your hardware (`_SpecDetectStep`, `:370-439`).

**Fix:** add a "Pandu Saya (Setup)" tile in Settings → Lainnya and run it
automatically once after onboarding. Then fix the following, which the tests do
not catch:

- **P1** `_AudioSetupStep._loadDevices` uses `bridge.listOutputAudioDevices()`
  (`:579`) which returns **input** devices (UX-05) — so
  "Speaker / Loopback (Output)" lists microphones, and `_hasBlackHole` (`:620`)
  searches the wrong list.
- **P1 · macOS-only content shown on all platforms.** The BlackHole card
  (`:656-724`) and its guide — `brew install blackhole-2ch`, "Audio MIDI Setup",
  "MacBook Pro Speakers" (`:716`) — render on Windows and Linux, where the
  correct answers are WASAPI loopback (automatic) and `<sink>.monitor`
  (automatic). A Linux user is told to install a macOS kernel extension.
- **P2 · RAM detection is a guess off macOS.** `_estimateRamMb` = `cores × 2048`
  clamped to 4–32 GB (`:116-123`), presented as a fact in a row labelled "RAM"
  (`:418-422`). `sysctl hw.memsize` is macOS-only (`:98`); `/proc/meminfo` and
  `GlobalMemoryStatusEx` are not attempted. Rust already has `memory.rs`.
- **P2** The tone test marks itself successful even when playback throws
  (`:832-834`, "still mark tested so the user can proceed") and then asserts
  "Speaker berfungsi dengan baik" (`:889`) — a false positive on exactly the
  machine that needs the warning. It also never asks the user *"did you hear it?"*,
  which is the only thing that would make it a test.
- **P2** Step 4 is titled "4. Tone Test" but the class comment says "Step 5"
  (`:769`), and the enum has four steps. Leftover from a removed step.
- **P3** `Colors.orange` ×6, `AppColors.statusActive` ×4, `Colors.white` — no
  theme tokens for status.
- **P3** Emoji-heavy model descriptions with accuracy claims ("🇮🇩 ID: ~96%",
  `:488`) that no measurement in the repo supports.

---

## A.7 Privacy report — `lib/screens/privacy_report_screen.dart` (110 lines)

**Purpose.** Prove the offline claim. For the stated audience — government
officials handling `notulen rapat` — this is arguably the most important screen in
the product, because it is the one that gets shown to a security officer.

**A.7-1 · P0 · The screen's central claim is false as written (PR-01).**
Three things are wrong at once:

1. **Model downloads are not counted.** `recordModelDownload`
   (`privacy_report_model.dart:40`) has zero call sites — and
   `test/privacy_proof_test.dart:85` is named
   *"recordModelDownload counter has zero call sites while bundled"*, so the test
   suite **enforces** the omission. A 548 MB download to
   `huggingface.co` leaves the counter at 0.
2. **Update checks are not counted and not mentioned.**
   `UpdateChecker.checkForUpdate` opens an `HttpClient` to
   `raw.githubusercontent.com` (`update_checker.dart:75`, `:88`). The screen
   states: *"Hanya ada dua aktivitas jaringan yang sah"* (`:75`). There are three.
3. **The counter's label overstates its scope.**
   *"N panggilan jaringan sejak aplikasi dibuka"* (`:59`) implies observation of
   network activity. It is a manually-incremented integer with exactly one caller
   (`summary_panel.dart:58`).

A privacy report that under-reports is worse than none: it converts an honest
"we don't instrument this" into a verifiable false statement. `rust_core/src/privacy.rs`
enforces the *architecture* (which modules may hold a `reqwest::Client`) — which
is genuinely strong — but the *report* is a separate, unenforced surface.

**Fix, in order:**
1. Call `recordModelDownload` from `OnboardingNotifier._download`
   (`onboarding_model.dart:142`) and `_ModelDownloadDialogState._startDownload`
   (`model_download_dialog.dart:72`); delete the test that enforces zero and
   replace it with one that asserts *every* outbound call site increments the
   counter.
2. Add `recordUpdateCheck(endpoint)` and call it from
   `settings_side_panel.dart:379`.
3. Rewrite the copy to enumerate three activities, and state plainly that the
   counter covers calls this app makes, not all traffic from the machine.
4. Move the counter into Rust beside the `reqwest` clients so it cannot be
   bypassed, and extend `privacy.rs` to fail the build when a module gains an
   HTTP client without a counter call — the enforcement pattern already exists.

### Other findings

- **A.7-2 · P2 · A 1 Hz `setState(() {})` on the whole screen.**
  `Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}))`
  (`:22`) rebuilds the entire `ListView` — including the 11-line paragraph and
  every event row — once a second, forever, including while the screen is buried
  under another route (a pushed route does not stop the timer).
  **Fix:** the only thing that changes is the elapsed string; wrap it in a
  `StreamBuilder`/`ValueListenableBuilder`, or drop to 10 s granularity since the
  display is "3j 12m".
- **A.7-3 · P2 · The audit log is not persistent and not exportable.**
  `events` is in-memory, reset every launch (`:36`), and the screen has no
  "Ekspor log" button. For the compliance use case the log needs to survive
  restarts and leave the machine as a file. The Rust flight recorder
  (`rust_core/src/flight_recorder.rs`, 9 FRB functions) is the obvious backing
  store and has no caller (A.0-4).
- **P2 · Raw `DateTime` in user-facing strings.**
  `'Ringkasan AI dikirim ke $endpoint — ${DateTime.now()}'`
  (`privacy_report_model.dart:56`) renders as
  `2026-09-30 14:05:33.123456` — microseconds and all, in an Indonesian UI.
- **P2 · No empty-vs-clean distinction in the card colour.**
  `isClean` is `networkCallCount == 0` and tints the card with
  `AppColors.micAccent.withValues(alpha: 0.1)` (`:43`) — `micAccent` is
  `#00796B`, i.e. the primary, aliased under an audio name. `AppColors.micAccent`
  and `AppColors.spkAccent` are *the same colour* (`app_colors.dart:14-15`), so
  the two "speaker accent" tokens are decorative only.
- **P3 · No `Semantics`**; the verified-user icon (`:48-52`) is the primary signal
  and is announced as nothing.
- **P3** Uses `Theme.of(context).textTheme` (`:60`, `:90`) — correctly, and
  almost uniquely in the codebase.

---

## A.8 Usage dashboard — `lib/screens/usage_dashboard_screen.dart` (216 lines)

**Purpose.** Show totals. **Primary action:** none; it is a read-only report.

- **A.8-1 · P2 · Title mismatch with its entry point.** "Dasbor Penggunaan"
  (`settings_side_panel.dart:347`) opens "Statistik Penggunaan" (`:146`, `:154`).
- **A.8-2 · P2 · Re-reads and re-parses every transcript in the library.**
  `scanUsageStats` (`:42-92`) `listSync`s the library, and for each session
  `readAsString` + `jsonDecode` of the full transcript, just to read
  `list.length` and the last segment's timestamp, on the UI isolate. This is the
  second full-corpus scan in the app (A.2-3) with no shared cache. For 200
  sessions the screen shows a spinner for seconds.
  **Fix:** share the index file proposed in A.2-3; at minimum wrap in `compute()`.
- **A.8-3 · P2 · "Sesi per Mode" is inferred from the first segment's `source`**
  (`:76-79`). An imported file has `source: "file"` → falls into the `_` arm →
  labelled **"Rapat Online"** (`:28-32`). A Rapat Online session whose first
  segment happened to come from the mic is labelled "Rapat Offline". The mode is
  knowable — put it in the sidecar.
- **P2 · No error state.** Every failure is `catch (_) { continue; }` / `catch (_) {}`
  (`:80`, `:84`) → zeros, indistinguishable from a new install.
- **P2 · No empty state for the cards.** With no data the two stat cards show
  "0" and "0.0" and only the mode section gets "Belum ada data sesi tersimpan."
  (`:173`).
- **P3 · Not actually a dashboard.** Three numbers and a list. No trend over
  time, no per-model accuracy or speed, no storage-by-month, no "jam ditranskrip
  bulan ini" — and the data for all of that is already being read.
- **P3 · `hours` is `toStringAsFixed(1)`** (`:151`) so a 20-minute total reads
  "0.3" — minutes would be clearer below an hour.
- **P3 · No `Semantics`**; `_StatCard` reads as two unrelated strings, value
  before label (`:209-210`), so a screen reader says "128" then "Total Sesi".

---

## A.9 Export dialog — `lib/widgets/export_dialog.dart` (207 lines)

**Purpose.** Pick formats, pick a folder, write files. **Primary action:**
"Pilih Folder" — a good label: it tells the user the next step is a folder
picker rather than implying the export already happened.

- ✅ Seven formats with one-line descriptions and icons (`:67-94`).
- ✅ Default format pre-checked from settings, with a correct
  `markdown → md` mapping (`:12-15`).
- ✅ Summary-inclusion notice shown only when a summary exists (`:96-112`), and
  it names exactly which formats get it.
- ✅ Blocking progress dialog during the write (`:146-164`), success and failure
  snackbars (`:187`, `:198`).

- **A.9-1 · P2 · A failed export can leave the progress dialog up.**
  The close is `Navigator.of(context, rootNavigator: true).pop()` in both arms
  (`:185`, `:197`), guarded by `context.mounted`. If `exportSessionWithSummary`
  throws *after* the user navigated away, `!context.mounted` returns early at
  `:195` **before** the pop, leaving a `barrierDismissible: false` dialog
  orphaned — an unclosable modal.
  **Fix:** pop in a `finally`, and use a `GlobalKey`/completer rather than the
  ambient context.
- **P2 · No overwrite warning.** Exporting twice to the same folder silently
  replaces the previous files (the Rust side renames over them). No "file sudah
  ada" prompt, no unique-naming.
- **P2 · No per-format progress or partial-failure reporting.** "Mengekspor 7
  format..." (`:159`) then one success or one failure for the whole set; the Rust
  exporter runs a thread per format and can partially succeed.
- **P2 · No format memory.** The dialog always starts from the single settings
  default; a user who exports "md + docx" every time re-checks docx every time.
- **P3 · Format descriptions are half-English:** "Plain text tanpa timestamp",
  "Full metadata terstruktur", "Subtitle format", "Web subtitle", "Microsoft Word
  document" (`:68-74`).
- **P3 · Fixed `SizedBox(width: 340)`** (`:56`) — the 7-row list plus notice needs
  scrolling on a short window; it is in a `SingleChildScrollView` (good) but the
  dialog can still exceed a 600 px window.
- **P3 · No `Semantics` beyond `CheckboxListTile`'s defaults; no PDF** — the one
  format an Indonesian office will actually ask for (see FG-07).

---

## A.10 Model download — `lib/widgets/model_download_dialog.dart` (156 lines) + `model_download_card.dart` (118 lines)

**Purpose.** Fetch a model on demand when the user flips to "Akurat".

- **A.10-1 · P1 · No cancel during a 548 MB download.**
  `barrierDismissible: false` (`:17`), Esc does nothing, and "Batal" is disabled
  while `_downloading` (`:146`). The user is locked in a modal for the duration
  of a half-gigabyte transfer with no exit but killing the app.
  **Fix:** enable "Batal" during download, wire it to a Rust-side cancel token,
  and keep the partial file for resume (`download_with_resume` already supports it).
- **A.10-2 · P2 · Retry leaks the previous progress subscription.**
  `_startDownload` assigns `_progressSubscription` (`:79`) without cancelling the
  existing one, and the "Unduh" retry button calls `_startDownload` again
  (`:151`). Two subscriptions then race on `setState`, and only the last is
  cancelled in `dispose` (`:60`).
  **Fix:** `await _progressSubscription?.cancel()` first.
- **P2 · Confusing copy while downloading.** The body keeps saying
  *"… belum diunduh. Apakah Anda ingin mengunduh sekarang?"* (`:129`) **below**
  the live progress bar (`:132-141`) — the question is asked while the answer is
  being executed.
- **P2 · The dialog is shown *after* the toggle is tapped, so the quality toggle's
  meaning is "download 548 MB".** `_QualityToggle` (`main_screen.dart:864-882`)
  renders at 40% opacity when the target is unavailable (`:891`) but with no
  download-icon hint and no tooltip. A user taps what looks like a disabled chip
  and gets a modal 548 MB download.
- **P2 · No free-space check** before starting (PR-03).
- **P3** `Colors.red.shade700` (`model_download_card.dart:89`, `:106`) and
  `Color(0xFF2E7D32)` (`:105`) instead of `AppColors.statusError`/`statusActive`.
- **P3** `Theme.of(context).extension<AppColorSet>()!` — a bang
  (`model_download_card.dart:29`); same in `app_toast.dart:17` and
  `animated_record_button.dart:47`. Every other file uses
  `?? AppColors.light`. Three crash sites if the extension is ever absent (e.g.
  a dialog built under a bare `MaterialApp` in a test).

---

## A.11 Overlays, toasts and window behaviour

### Toasts — `lib/widgets/app_toast.dart` (151 lines)

- ✅ Overlay-based (works without a `Scaffold`, which is why the update-check
  fix moved to it — `settings_side_panel.dart:370-377`), animated in and out,
  width-clamped (`:120`).
- **P2 · Single-slot: a new toast destroys the previous one** (`:15`) — A.1-4.
- **P2 · Errors auto-dismiss after 3 s** (`:13`) with no dismiss button, no
  "copy details", no history. Used for capture failure and save failure — the two
  messages a user most needs to still be there when they look back at the screen.
- **P3 · Hardcoded `Color(0xFF2E7D32)` / `Color(0xFFD32F2F)`** (`:100-101`),
  duplicating `AppColors.statusActive` / `statusError`.
- **P3 · No `Semantics(liveRegion: true)`** — a screen-reader user is never told
  a toast appeared. For an error toast this means the failure is invisible to them.

### Two parallel notification systems

The app uses `AppToast` (overlay) **and** `ScaffoldMessenger.showSnackBar`
(`library_screen.dart:117`, `:186`; `transcript_view.dart:89`, `:218`;
`transcript_player_screen.dart:181`; `summary_panel.dart:87`, `:248`;
`export_dialog.dart:187`, `:198`; `file_upload_zone.dart:41`, `:201`;
`settings_side_panel.dart:171`) with different styling, different positions and
different dismissal rules, for messages of the same importance.
**P2 · Fix:** pick one. `AppToast` is the more robust (no `Scaffold`
dependency); give it `action` support so it can replace the undo snackbar.

### `SetupOverlay` — unreachable (A.0-2). Its own quality issues, for when it is wired:

- **P2** `_runPreflight` has no `try/catch` — if `runPreflightChecks` itself
  throws (no engine, no permissions), the overlay stays on the spinner forever
  (`setup_overlay.dart:37-51`), gating the entire app behind an infinite loader.
- **P2** `bool skipPreflightChecks` is a mutable global (`:8`) and
  `SetupOverlay.test` is a constructor that behaves identically to the default
  one (`:17`) — the "test" variant does nothing.
- **P3** `Colors.orange` (`:66`); no theme token.

### Window resize behaviour

**A.11-1 · P1 · Minimum window size is set on macOS only.**
- macOS: `contentMinSize = NSSize(width: 860, height: 700)`
  (`macos/Runner/MainFlutterWindow.swift`), with a comment explaining the
  toolbar overflows below it.
- Linux: `gtk_window_set_default_size(window, 1280, 720)`
  (`linux/runner/my_application.cc:55`) — a *default*, no minimum.
- Windows: `Win32Window::Size size(1280, 720)` (`windows/runner/main.cpp:29`) —
  likewise.
- `window_manager` is a dependency (`pubspec.yaml:39`) and
  `windowManager.setMinimumSize` is called nowhere in `lib/`.

So the constraint the macOS code documents as necessary is absent on the two
platforms most Indonesian government desktops run.

| Window | Behaviour |
|---|---|
| **800×600** (below the macOS minimum; reachable on Linux/Windows) | Main screen: control bar survives via the horizontal scroller (`main_screen.dart:548`) — this part is genuinely well handled. Player: `Expanded` transcript squeezed, controls overflow (A.3). Settings: 380 px panel + 420 px void. Export dialog: scrolls. Library upload tab with 4+ files: overflows (UX-09). |
| **1280×720** (default) | Fine, except Settings' dead space. |
| **1920×1080** | Settings is a 380 px strip (A.4-1). Transcript rows stretch to 1 900 px with a 72 px speaker column and no max text width — long lines become unreadable (no `ConstrainedBox(maxWidth: ~80ch)` anywhere). Library cards stretch full width. |
| **Ultrawide 3440×1440** | Same, worse: a 3 300 px transcript line. The two-pane layout this width is begging for (transcript + summary side by side) does not exist; `SummaryPanel` is always stacked above (`transcript_player_screen.dart:266-272`). |

**Fix:** `windowManager.setMinimumSize(const Size(860, 700))` in `main()`;
`ConstrainedBox(maxWidth: 900)` around transcript text; switch the player to a
side-by-side layout above ~1400 px.

---

## A.12 Cross-cutting: theme, contrast, accessibility, copy

### Contrast — computed from `lib/theme/app_colors.dart` and the hardcoded literals

WCAG 2.1: AA normal text ≥ 4.5:1; AA large (≥18.66 px bold or ≥24 px) ≥ 3.0:1;
AAA ≥ 7.0:1. Note the app's body text is 13–14 px and its metadata 10–12 px, so
**"AA-large" never applies** to anything below.

| Pair | Ratio | Verdict |
|---|---:|---|
| light `text #333333` on `surface #FFFFFF` | **12.63** | AAA |
| light `text #333333` on `background #F5F5F5` | **11.59** | AAA |
| light `textSecondary #666666` on `#FFFFFF` | **5.74** | AA |
| light `textSecondary #666666` on `chipBackground #F0F0F0` | **5.04** | AA |
| light `textTertiary #757575` on `#FFFFFF` | **4.61** | AA (margin 0.11) |
| light **`textTertiary #757575` on `chipBackground #F0F0F0`** | **4.04** | ❌ **FAIL** — used for 11–12 px metadata (`session_card.dart:136`, `storage_bar.dart:104`, `main_screen.dart:509`) |
| light `primary #00796B` on `#FFFFFF` | **5.32** | AA |
| light `primary #00796B` on `#F5F5F5` | **4.88** | AA |
| light `onPrimary #FFFFFF` on `primary #00796B` | **5.32** | AA |
| light `statusError #D32F2F` on `#FFFFFF` | **4.98** | AA |
| light `statusActive #2E7D32` on `#FFFFFF` | **5.13** | AA |
| light **`warning #FF3B30` on `#FFFFFF`** | **3.55** | ❌ **FAIL** — the app's error-text colour (`transcript_player_screen.dart:298`, `retranscribe_dialog.dart:202`, `summary_settings_section.dart:242`, `summary_panel.dart:273`) |
| light **low-confidence `#D97706` on `#FFFFFF`** | **3.19** | ❌ **FAIL** — 10 px italic (`transcript_view.dart:447`, `:454`) |
| `divider #E0E0E0` vs `surface #FFFFFF` | **1.32** | ❌ FAIL non-text (needs 3.0 for UI boundaries) |
| dark `text #E0E0E0` on `surface #1E1E1E` | **12.63** | AAA |
| dark `textSecondary #B0B0B0` on `#1E1E1E` | **7.69** | AAA |
| dark `textTertiary #9E9E9E` on `chipBackground #2C2C2C` | **5.21** | AA |
| dark `primary #4DB6AC` on `#1E1E1E` | **6.83** | AA |
| dark `onPrimary #003D33` on `primary #4DB6AC` | **5.02** | AA ✅ *(the correct token)* |
| dark **`Colors.white` on `primary #4DB6AC`** | **2.44** | ❌ **FAIL** — what `ElevatedButtonThemeData` actually uses (`app_theme.dart:83`) |
| dark **`statusActive #2E7D32` on `#1E1E1E`** | **3.25** | ❌ FAIL |
| dark `warning #FF3B30` on `#1E1E1E` | **4.70** | AA (barely) |
| dark `divider #333333` vs `#1E1E1E` | **1.32** | ❌ FAIL non-text |
| VU mic `#2E7D32` on `chipBackground #F0F0F0` | **4.50** | AA (exactly) |
| VU spk **`#E65100` on `#F0F0F0`** | **3.33** | ❌ FAIL |

**Speaker palette** (`lib/utils/speaker_color.dart:4-13`), rendered as 12 px
`FontWeight.w600` speaker names (`transcript_view.dart:362-372`) and as avatar
initials at `size * 0.38 ≈ 8.4 px` (`speaker_avatar.dart:36`):

| Colour | on light `#FFFFFF` | on dark `#1E1E1E` |
|---|---:|---:|
| `#00796B` | 5.32 ✅ | **3.13 ❌** |
| `#E67E22` | **2.85 ❌** | 5.85 ✅ |
| `#2ECC71` | **2.10 ❌** | 7.93 ✅ |
| `#9B59B6` | 4.67 ✅ | **3.57 ❌** |
| `#E74C3C` | **3.82 ❌** | **4.36 ❌** |
| `#1ABC9C` | **2.41 ❌** | 8.09 ✅ |
| `#3498DB` | **3.15 ❌** | 5.29 ✅ |
| `#F39C12` | **2.19 ❌** | 8.54 ✅ |

**UX-08 · P1 · 6 of 8 fail AA in light mode, 3 of 8 in dark, 1 fails both.**
The palette is a `const` list with no theme parameter (`speaker_color.dart:15-18`)
even though the function already *receives* `AppColorSet colors` and uses it only
for the empty-name fallback. Which speaker gets which colour is
`name.hashCode.abs() % 8` — so a user cannot avoid a bad one by renaming
predictably.
**Fix:** two palettes (light-safe and dark-safe) selected off
`Theme.of(context).brightness`, each validated ≥ 4.5:1 against both `surface` and
`transcriptBackground`; assert the ratios in a unit test so the palette cannot
regress.

**UX-07 · P1 · `ElevatedButtonThemeData` hardcodes `foregroundColor: Colors.white`**
(`app_theme.dart:83`) → 2.44:1 in dark mode on every primary button: "Mulai
menggunakan" in onboarding, "Lanjut"/"Selesai" in the wizard, "Coba Lagi" in the
overlay. `ColorScheme.onPrimary` is already set correctly (`:23`) and
`FilledButton` (used in dialogs) picks it up — so dialogs are fine and
`ElevatedButton`s are not, in the same app.
**Fix:** `foregroundColor: colors.onPrimary`. Same at `:26-27`
(`onSecondary: Colors.white`, `onError: Colors.white`).

### Theme-token hygiene

| File | Hardcoded colour literals / Material constants bypassing `AppColorSet` |
|---|---|
| `utils/speaker_color.dart` | 8 (`:4-13`) |
| `widgets/vu_meter.dart` *(dead)* | 5 (`:28`, `:35`, `:94-96`) |
| `theme/app_theme.dart` | 5 — `Colors.white` ×3 (`:26`, `:27`, `:83`), `Colors.grey` ×2 (`:54`, `:59`) |
| `screens/setup_wizard_screen.dart` *(dead)* | ~7 — `Colors.orange` ×6, `Colors.white` |
| `widgets/app_toast.dart` | 2 (`:100-101`) — duplicates existing tokens |
| `widgets/transcript_view.dart` | 2 (`:447`, `:454`) |
| `screens/main_screen.dart` | 2 (`:640`, `:646`) + `Colors.orange` (`:723`) + `Colors.black` (`:776`) |
| `widgets/model_download_card.dart` | 3 (`:89`, `:105`, `:106`) |
| `widgets/settings_side_panel.dart` | 1 — `Colors.teal` (`:443`) |

**≈25 in live code**, 6 of which duplicate a token that already exists
(`statusActive`, `statusError`). Only `AppColorSet.primary`/`text`/`surface` are
used consistently. There are no spacing or radius tokens at all: `BorderRadius.circular`
appears with 2, 3, 4, 6, 8, 10, 12 and 20 in different widgets, and
`SizedBox(width:/height:)` with 2, 4, 5, 6, 8, 10, 12, 14, 16, 20, 24, 32.
**P2 · Fix:** add `AppSpacing` / `AppRadius` / `AppTextStyles` and a lint or test
that fails on a raw `Color(0x…)` outside `theme/`.

### Accessibility summary

| Surface | `Semantics` count |
|---|---:|
| `widgets/file_upload_zone.dart` | 9 ✅ |
| `widgets/shortcuts_panel.dart` *(dead)* | 4 |
| `widgets/mode_selector.dart` | 2 ✅ |
| `widgets/stream_toggle.dart` | 1 ⚠️ (see below) |
| `widgets/transcript_view.dart` | 1 ✅ |
| **all 8 screens** | **0** |
| `settings_side_panel.dart` (754 lines) | **0** |
| `session_card.dart`, `export_dialog.dart`, `summary_panel.dart`, `app_toast.dart`, `animated_record_button.dart`, `retranscribe_dialog.dart`, `storage_bar.dart` | **0** |

**A.12-1 · P1 · Screen-reader support is effectively absent outside the upload
zone.** No screen has a single `Semantics`. No `liveRegion` anywhere, so
transcript rows arriving during a meeting are never announced — which is exactly
the case where a blind user would most want them. No `MergeSemantics` on the
cards, so each becomes 5+ unlabelled fragments.

**A.12-2 · P2 · `StreamToggle`'s Indonesian semantic labels are dead code.**
```dart
if (label == 'Mic') { … } else if (label == 'Speaker') { … }   // stream_toggle.dart:23-26
```
`main_screen.dart:567` passes `'Mikrofon'` and `:576` passes `'Pengeras Suara'`,
so both branches are unreachable and the generic fallback (`:28`) is always used.
Renaming the labels for the Indonesian UI silently broke the accessibility code
written for them. (`test/stream_toggle_test.dart` has 1 test and does not cover it.)

**A.12-3 · P2 · Touch targets below the minimum in the most-used places.**
- `main_screen.dart:344`, `:359`, `:369`, `:383` — 32×32 for all global nav.
- `transcript_view.dart:469-489` — 32×32 copy and edit, per row.
- `_CompactDropdown` (`settings_side_panel.dart:664`) — ~26 px tall.
- `settings_side_panel.dart:121-122` — close button with
  `padding: EdgeInsets.zero, constraints: BoxConstraints()`, i.e. exactly the
  20 px icon.

Material minimum is 48×48; macOS HIG 28×28 for pointer-only, which some of these
meet, but the app is also a candidate for touch-screen Windows tablets in
meeting rooms.

**A.12-4 · P2 · Tooltips missing on 5 icon-only buttons:**
`library_screen.dart:237` (back) and `:265` (clear search);
`transcript_view.dart:134` (clear search) and `:337` (play/pause — the largest
control on the player); `main_screen.dart:797` (close shortcuts).

**A.12-5 · P2 · No focus management.** No `FocusTraversalGroup` or
`FocusTraversalOrder` anywhere; no visible focus ring styling beyond Material
defaults (which the custom `GestureDetector`-based controls — `StreamToggle:35`,
`_QualityToggle:864` — do not render at all, so they are unreachable by keyboard
*and* invisible when focused). Dialogs autofocus their text field correctly
(`transcript_view.dart:525`, `library_screen.dart:147`) — that part is right.

**A.12-6 · P2 · Text scaling is untested and structurally unsupported.** Fixed
heights on every bar (see A.1), `SizedBox(width: 72)` for the speaker column
(`transcript_view.dart:348`), `SizedBox(width: 340/360)` in dialogs, and
`maxLines: 1` with ellipsis on titles. At `textScaleFactor` 1.3 (a common OS
accessibility setting for older users — very relevant for the government
audience) labels clip rather than wrap.

### Copy inventory — English strings in the Indonesian UI

| String | Location |
|---|---|
| `'Upload File'` | `main_screen.dart:334` |
| `'Upload Berkas'` (tab) | `library_screen.dart:247` |
| `'Progressive Mode'` | `settings_side_panel.dart:187` |
| `'Echo Dedupe'` | `settings_side_panel.dart:244` |
| `'VAD (deteksi suara)'` | `settings_side_panel.dart:235` |
| `'API key'`, `'sk-...'` | `summary_settings_section.dart:173`, `:179` |
| `'Keputusan & Action Items'`, `'Standup Harian'` | `models.dart:36-37` |
| `'Template'` | `summary_panel.dart:178` |
| `'Decoding'` | `file_upload_zone.dart:240` |
| `'Ganti Nama Speaker'` | `transcript_view.dart:573` (vs "Ganti Nama Sesi" — Indonesian — at `library_screen.dart:145`) |
| `'Plain text tanpa timestamp'`, `'Full metadata terstruktur'`, `'Subtitle format'`, `'Web subtitle'`, `'Dokumen dengan styling'`, `'Microsoft Word document'` | `export_dialog.dart:68-74` |
| `'Tone Test'`, `'CPU Cores'`, `'Setup Audio'`, `'Pilih Model'`, `'Model Rekomendasi'` | `setup_wizard_screen.dart` *(dead)* |
| `'Traeon Transcribe'` | `onboarding_screen.dart:43` — **typo** |
| `'Statistik'` vs `'Dasbor'` | `usage_dashboard_screen.dart:154` vs `settings_side_panel.dart:347` |

**Tone** is otherwise consistent and good: formal-but-warm *Anda*, consequences
explained rather than mechanisms, and reassurance where it counts ("transkrip
tetap aman", "Transkrip lama tetap dipertahankan"). Two places break it:
raw exception text interpolated into user messages
(`'Gagal mengunduh: $e'`, `onboarding_model.dart:148`;
`'Gagal membuat ringkasan (transkrip tetap aman): $e'`, `summary_model.dart:160`;
`'$e'` straight into a toast, `main_screen.dart:147`) — a Rust `TranscribeError`
Debug string is not Indonesian and not actionable.

---

# Part B — Feature gap and improvement list

## B.1 Current features: depth and robustness

### 1. Live recording
**Works:** mic + system audio on all three platforms after Round 2; VAD gate;
echo dedupe in Rapat Online; mode presets; per-source toggles mid-session;
pause/resume; auto-stop on silence; VU meters; an error-rate limiter that turned
a 1.5 GB log flood into 1 551 bytes; `decide_start` refusing to start with zero
working sources.
**Shallow / fragile:**
- Audio is RAM-only until stop (UX-02) — 1.38 GB for a 3-hour Rapat Online, and
  nothing on disk if anything goes wrong.
- No transcript autosave (UX-01); `auto_save_interval_secs` is a decorative
  setting (A.4-5).
- Device selection has no UI (the only picker is in the dead wizard, A.6-1) and
  the fallback heuristic searches the *wrong device list* (UX-05).
- Dual-pass HPT still runs quick and refine synchronously
  (`MEETILY-PARITY-REPORT.md:532`), so the promised instant partials are not
  delivered within a chunk.
- A muted sink yields silent "system audio" with no explanation
  (`MEETILY-PARITY-REPORT.md:534`).
- `AudioCapture::stop` doesn't survive SIGKILL — an orphan `parec`/`ffmpeg`
  keeps recording (`:535`).
- No segment editing during recording (A.1-6).
**Production-grade needs:** ring-buffer WAV to disk continuously with periodic
transcript flush; a device picker in Settings with live level preview; a
pre-flight "test 5 seconds" before the real session; the refine pass on its own
queue; `PR_SET_PDEATHSIG` on the capture child.

### 2. Import / batch transcription
**Works:** 10 container formats; drag-drop and picker; queue with per-file
status; Symphonia decode with no ffmpeg dependency; one model load per batch;
per-file outcomes carrying either transcript or error; diarization labels;
progressive two-pass; source audio copied next to the transcript; sidecar written.
**Shallow / fragile:**
- **The default path has no progress.** `processBatch` polls
  `bridge.batchProgress()` only in the non-progressive branch
  (`batch_upload_model.dart:125-134`); `_processProgressive` (`:194-237`) has no
  polling at all. `progressiveEnabled` defaults to **`true`**
  (`models.dart:411`), so the default import path shows a static spinner — the
  exact symptom A-15 was raised to fix.
- **A crash if the queue is emptied mid-batch.** `state.firstWhere((e) => e.path == path)`
  (`:170`, `:181`) throws `StateError` when the entry is gone; "Kosongkan"
  (`file_upload_zone.dart:149`) removes entries while the batch runs, with no
  confirmation and no cancel.
- **Windows filenames are wrong.** `path.split('/').last` (`:53`) — on Windows
  the queue shows the full `C:\Users\…\rapat.mp3`.
- No cancel for an in-flight batch; no queue reordering; no persistence (quitting
  loses the queue); the list overflows the window (UX-09);
  `copyWith(error: error ?? this.error)` (`:23-30`) cannot clear an error.
**Production-grade needs:** per-file byte/second progress and ETA; a real cancel;
a persisted, resumable queue; `p.basename` from `package:path`; guard
`firstWhere` with `orElse`.

### 3. Re-transcribe ("Transkrip Ulang")
**Works:** model + language choice restricted to installed models; defaults to
the accurate model; distinguishes engine failure from no-speech; never replaces
the old transcript unless new segments exist; updates the sidecar.
**Shallow:** destroys hand corrections with no undo or backup (A.3-3); no
progress (just "Memproses… ini bisa memakan waktu"); no cancel; only reachable
from the player, so re-running a batch of sessions is one-at-a-time; re-uses
`batchTranscribeFiles` so it cannot do the progressive path.
**Needs:** timestamped backup + restore; progress; cancel; a library-level
"re-transcribe selected" action; segment-level "re-transcribe just this part",
which is what a notulis actually wants.

### 4. AI summary
**Works:** genuinely well built. Ollama + any OpenAI-compatible endpoint; 4
Indonesian templates + free-form; model discovery from the endpoint before you
depend on it; editable and saved to the sidecar; regenerable; both-ends
truncation for long transcripts; pure-function prompt building with real unit
tests; privacy counter fired before the request; a reassuring failure message.
**Shallow / fragile:** the provider leaks per opened session (A.3-7); no
streaming, so a 7 B model on a long transcript is a spinner for minutes with no
cancel; no timeout feedback (180 s hardcoded, `models.dart:513`); API key in
plaintext (documented trade-off, PR-05); no "preview exactly what will be sent"
in the UI although `summaryPreviewTranscript` exists and is FRB-exposed
(`bridge_service.dart:149`) — that would be the single best trust affordance for
the privacy-conscious user; no per-session template memory beyond the sidecar; no
summary of *multiple* sessions.
**Needs:** streamed tokens + cancel; a "Lihat apa yang dikirim" dialog before the
first request; OS keychain via `flutter_secure_storage`; a bundled small local
model so the feature works with no setup.

### 5. Search
**Works:** full-text over title, summary and segment text, with a match snippet
that explains the hit (`session_store.dart:185-204`).
**Shallow:** O(corpus) per keystroke, no debounce (A.2-4); substring only — no
word boundaries, no diacritic folding, no stemming, no phrase quoting, no
`speaker:` or date filters; no result count; no in-result navigation (the
snippet shows the first match only); the in-transcript search
(`transcript_view.dart:126`) is a separate, unrelated implementation with its own
highlighting (`:243-269`) and no match counter or next/previous.
**Needs:** an inverted index built at export time (or SQLite FTS5 — one file, no
server, offline); debounce; `next/prev match` in the transcript view.

### 6. Diarization
**Works:** acoustic clustering on pitch proxy + RMS + ZCR, separate cluster
pools per channel so mic and speaker cannot collapse; Indonesian labels
(`Saya` / `Peserta N` / `Pembicara N`); live and file paths; renameable.
**Shallow:** three weakly-scaled features with a fixed 0.22 threshold — within-channel
accuracy is best-effort (`MEETILY-PARITY-REPORT.md:241`); **speaker names do not
persist across sessions**, so a weekly rapat means renaming the same five people
every week; no speaker merge/split; no "this is the same person as in that
session"; no per-speaker talk-time stats (a real notulen ask).
**Needs:** name persistence + a voice profile store (FG-09); merge/split UI;
speaker statistics.

### 7. Export
**Works:** 7 formats, per-track WAV, atomic writes, filename sanitisation,
date-prefixed folders, summary in md/txt/html/docx, SRT/VTT/JSON deliberately
left clean and pinned by a test.
**Shallow:** no PDF (the format an Indonesian office asks for); no DOCX template
control — one fixed layout, no letterhead, no Tata Naskah Dinas structure
(FG-07); no overwrite protection or per-format failure reporting (A.9-1); no
clipboard-as-formatted-table; no "export all sessions" / date-range export;
"Ekspor" on the main screen (`main_screen.dart:153-183`) silently uses the
default md/txt/json formats and bypasses the dialog entirely — two different
export behaviours behind the same word.
**Needs:** PDF via `printpdf` + an embedded Latin-Extended font; a DOCX template
system; bulk export; unify the two export entry points.

### 8. Settings
**Works:** persisted in Rust with `#[serde(default)]` so upgrades don't lose
settings; theme, model, mode, language, library path, GPU, VAD, auto-stop,
progressive, summary config all round-trip.
**Shallow:** "Sistem" theme cannot persist (A.4-7); no error handling on 15 save
paths (A.4-6); no reset-to-defaults; no import/export of settings (relevant for
an IT department rolling out to 50 machines); no device pickers; GPU toggle with
no capability check; two dead settings (A.4-5); the panel is the wrong shape for
a full screen (A.4-1).
**Needs:** try/catch + revert; a settings JSON export/import; a managed-policy
file for institutional deployment; a capability probe behind the GPU toggle.

### 9. Tray
**Works:** minimise-to-tray keeps a session running; show/quit menu; icon per
platform; off-screen-window recovery, which is a real bug fixed properly
(`tray_service.dart:110-129`).
**Shallow:** the tray menu doesn't show or control recording state — no
"Merekam 01:23:45", no start/stop/pause items, so the headline "record in the
background" flow has no background controls (worse on Windows/Linux, where global
hotkeys are also absent). No tray notification when a session auto-stops or a
source dies — those go to an in-window toast the user cannot see. No badge or
icon change while recording. `dispose()` exists and is never called.
**Needs:** dynamic tray menu with state + transport; icon change while recording;
OS notifications for auto-stop, capture failure, and save failure.

### 10. Hotkeys
**Works:** five in-app shortcuts, both modifiers, on all platforms.
**Shallow:** global hotkeys are macOS-only (A.1-6); the panel names the wrong
modifier off macOS (A.1-5); not customisable; the `hotkey_manager` package is
not a dependency although `window_manager` and `tray_manager` are.
**Needs:** `hotkey_manager` for cross-platform global hotkeys; a customisation UI
(the shortcut panel is already the right place); shortcuts on the library and
player screens, which currently have none.

### 11. Crash recovery
**Works:** `*.inprogress` snapshots in the per-user config dir, written
atomically at every lifecycle transition (`session.rs:326-407`), with a
size-bounded loader (`:579`); a banner on next launch; a guard against recovering
while another session is active.
**Shallow:** **it recovers nothing** (UX-01). `SessionRecoverySnapshot` is
config + `segments_count` (`session.rs:186-192`) and Dart resets
`segments: []` (`session_model.dart:190`). It also cannot recover the audio,
because the audio was never on disk (UX-02). The banner offers "Pulihkan" for
whichever snapshot is `.first` with no list, no date, no duration, and no
indication that the transcript is gone — and "Abaikan" just clears the banner
(`main_screen.dart:290`), leaving the `.inprogress` files on disk forever.
**Needs:** append segments to a JSONL sidecar as they arrive; ring-buffer audio to
disk; make recovery reconstruct the transcript; list recoverable sessions with
"N segmen, HH:MM" and a delete action.

### 12. Model management
**Works:** 6-entry pinned catalog with SHA256; resumable download; checksum
verification that hard-refuses unpinned models; multi-location path resolution
that survives the macOS sandbox; a 2-model UI abstraction that never exposes a
model id; download-on-demand from the quality toggle.
**Shallow:** no model manager screen — you cannot see what is installed, how much
space it uses, or delete one; no cancel (A.10-1); the retry leaks a subscription
(A.10-2); no re-verify/repair; no free-space check; no Indonesian-specialised
model (upstream GGML gap, documented and out of scope).
**Needs:** a "Model" section in Settings listing installed/available/size with
download, delete and verify per row.

### 13. Privacy report
**Works:** the *architectural* enforcement is excellent — `privacy.rs` fails the
build if a capture/inference/export module gains an HTTP client, and
`privacy_proof_test.dart` mirrors it in Dart.
**Shallow:** the *report* is wrong (PR-01/A.7-1): model downloads uncounted,
update checks uncounted and unmentioned, counter resets each launch, log not
persistable or exportable, timestamps raw.
**Needs:** move the counter into Rust beside the clients; persist the log via the
flight recorder; export as a signed text file; extend `privacy.rs` to require a
counter call at every outbound site.

### 14. Updates
**Works:** a manifest fetch with proper per-exception Indonesian messages and a
sane timeout.
**Shallow:** compares against a hardcoded `0.1.0` (A.4-3); "Lihat Rilis" is a
no-op (A.4-2); the manifest is an unsigned plain-text file over HTTPS with no
signature, no minimum-version floor and no rollback protection (PR-06); no
auto-check, so most users will never look; not counted in the privacy report
(A.7-1); `VERSION` is not bumped by the release workflow, so the manifest will
lag every release.
**Needs:** version from `package_info_plus`; `url_launcher` for the release page;
a signed manifest (minisign/Ed25519) with the public key pinned in the binary; a
CI check that `VERSION == pubspec version`; an opt-in weekly check with a clear
privacy disclosure.

---

## B.2 Proposed new features — Indonesia-first

Effort: **S** ≤ 2 days · **M** ≤ 1 week · **L** 2–3 weeks · **XL** > 1 month.

### FG-01 · Continuous durability: audio ring buffer + transcript journal · **XL** · value: critical
The fix for UX-01 + UX-02, and the precondition for trusting the app with a
3-hour rapat.
- Rust: replace `raw_audio: Vec<f32>` (`session.rs:159`) with a chunked WAV
  writer into `<library>/.inprogress/<session_id>/{mic,speaker}.wav`, flushed
  every N seconds, with a bounded footprint.
- Rust: append each emitted segment to `<session_id>/transcript.jsonl` before it
  is queued to Dart.
- Recovery reads both back and reconstructs a full session.
- Touches: `rust_core/src/session.rs`, `pipeline.rs`, `export/mod.rs`,
  `lib/state/session_model.dart`, `lib/screens/main_screen.dart` (banner UI).
- Risks: disk write contention with Whisper; needs a disk-space guard and a
  retention policy for abandoned `.inprogress` dirs; changes the recovery file
  format (keep the old loader for one release).

### FG-02 · Notulen Rapat DOCX per Tata Naskah Dinas · **L** · value: very high
The single highest-leverage differentiator for the government audience. Meetily
has nothing comparable and neither does any generic transcriber.
- A DOCX template with the standard structure: kop surat (letterhead image),
  *Notulen Rapat* title, Hari/Tanggal, Waktu, Tempat, Pimpinan Rapat, Peserta
  (table), Agenda, Pembahasan, Keputusan, Tindak Lanjut (Tugas / Penanggung
  Jawab / Tenggat table), and a signature block (Notulis / Pimpinan Rapat).
- A form in the app for the fields the audio cannot supply (tempat, pimpinan,
  agenda, nomor notulen), remembered per "Unit Kerja".
- Reuse the existing `notulenRapat` summary template output as the body.
- Touches: `rust_core/src/export/docx.rs` (or a new `export/notulen.rs`),
  `rust_core/src/summary.rs` (structured rather than free-Markdown output),
  a new `lib/widgets/notulen_form.dart`, `lib/widgets/export_dialog.dart`.
- Deps: `docx-rs` template support (or build the XML directly); FG-07 for PDF.
- Risks: Tata Naskah Dinas varies per ministry/pemda — ship 2–3 variants and let
  an admin supply a `.docx` template with `{{placeholders}}`.

### FG-03 · Glossary / `initial_prompt` vocabulary · **M** · value: very high
The cheapest large accuracy win available. Whisper's `initial_prompt` biases
decoding; Indonesian meetings are dense with acronyms it will never guess
(`Kemenkeu`, `DIPA`, `SPPD`, `Musrenbang`, `RKAKL`, `e-Katalog`), plus person and
place names.
- A "Kosakata" section in Settings: a free-text list plus per-session additions,
  with an "import from a previous transcript's corrections" helper.
- Pass it as `initial_prompt` on every `whisper_full` call (live and file), and
  as a post-pass fuzzy correction over the output for terms the prompt missed.
- Touches: `rust_core/src/stt/*` (prompt plumbing), `settings.rs`,
  `lib/widgets/settings_side_panel.dart`, `lib/state/settings_model.dart`.
- Risks: `initial_prompt` is capped (~224 tokens) — needs prioritisation and a
  visible "N of M terms used"; an over-long prompt degrades quality, so validate
  and warn.

### FG-04 · Auto re-transcribe after the meeting with the accurate model · **M** · value: high
Round 2's `HptRoute::QuickOnly` already tells the user to do this by hand
(`MEETILY-PARITY-REPORT.md:394`). Automate it: on stop, if the live pass used the
quick model and the accurate model is installed, queue a background re-run, show
a chip ("Menyempurnakan transkrip… 40%"), and swap it in on success while keeping
the original as a backup. This turns the slow-device compromise into a feature.
- Depends on FG-01 (audio must be on disk) and A.3-3 (backup before replace).
- Touches: `lib/state/session_model.dart`, a new
  `lib/state/enhance_queue_model.dart`, `lib/screens/library_screen.dart` (badge),
  `rust_core/src/api.rs`.
- Risks: CPU contention if the user starts another meeting — needs a queue that
  yields; must be cancellable and opt-out.

### FG-05 · Action-item tracking + `.ics` export · **M** · value: high
The `actionItems` summary template already produces a
Tugas / Penanggung Jawab / Tenggat table (`MEETILY-PARITY-REPORT.md:197-203`).
Parse it into structured items, let the user edit owner and due date, persist in
the sidecar, show an aggregated "Tindak Lanjut" view across sessions with
open/done state, and export as `.ics` VTODO/VEVENT so it lands in Outlook or
Google Calendar.
- Touches: `session_store.dart` (sidecar schema), new
  `rust_core/src/export/ics.rs`, new `lib/screens/action_items_screen.dart`,
  `lib/widgets/summary_panel.dart`.
- Risks: LLM table output is not reliably parseable — ask the model for JSON and
  validate, falling back to a free-text panel.

### FG-06 · Local chat / Q&A over the meeting archive · **L** · value: high
"Apa keputusan soal anggaran kuartal 4?" across all past meetings, fully local.
- SQLite FTS5 index over segments (this also fixes A.2-4 and the search
  shallowness) + optional embeddings via a small local model.
- Retrieval → the existing summary endpoint with a Q&A prompt → an answer with
  clickable citations that jump to the segment in the player (needs A.3-4).
- Touches: new `rust_core/src/index.rs` + `rust_core/src/qa.rs`,
  `Cargo.toml` (`rusqlite` bundled), new `lib/screens/ask_screen.dart`,
  `privacy.rs` (the index is local; the Q&A call goes through the existing,
  audited summary client — do not add a second HTTP client or the build fails,
  correctly).
- Risks: the privacy story gets harder — this sends *retrieved excerpts from
  multiple meetings*, not one transcript. Needs an explicit consent step per
  query and full logging in the privacy report.

### FG-07 · PDF export with an embedded font · **M** · value: high
Previously deferred as disproportionate (`MEETILY-PARITY-REPORT.md:229`). With
FG-02 it becomes proportionate: an Indonesian office circulates PDF, and
"print the DOCX from a viewer" is not an answer when the app is the deliverable.
`printpdf` + a bundled Latin-Extended font (Noto Sans / Inter, ~300 KB
subsetted).
- Touches: `rust_core/Cargo.toml`, new `rust_core/src/export/pdf.rs`,
  `export/mod.rs`, `lib/widgets/export_dialog.dart`, `assets/fonts/`.
- Risks: bundle size; table layout in `printpdf` is manual work; licence check on
  the font (OFL is fine).

### FG-08 · UU PDP mode: retention, redaction, audit log, consent · **L** · value: very high for institutions
The regulatory unlock. UU 27/2022 obliges a data controller to limit retention,
log processing, and obtain consent.
- **Retention:** per-library policy (delete audio after N days, keep transcripts;
  or delete everything after N days), with a visible countdown per session and a
  dry-run report before the first purge.
- **Redaction:** detect and mask NIK, NPWP, phone numbers, emails and bank
  accounts in transcripts and exports (regex is sufficient for all of these and
  fully local), with per-match accept/reject.
- **Audit log:** append-only, persistent, exportable — who opened/exported/deleted
  what and when. The flight recorder is already the right backing store (A.0-4).
- **Consent notice:** a first-run screen and a per-session banner ("Rekaman ini
  memerlukan persetujuan peserta") with a one-click "Salin teks pemberitahuan"
  the chair can read out.
- Touches: `rust_core/src/privacy.rs`, `flight_recorder.rs`, new
  `rust_core/src/redact.rs`, `settings.rs`, `lib/screens/privacy_report_screen.dart`,
  new `lib/screens/retention_screen.dart`, `onboarding_screen.dart`.
- Risks: over-claiming compliance is itself a legal risk — the copy must say what
  the feature does, not that the user is compliant. Redaction false negatives
  must be stated plainly.

### FG-09 · Speaker naming persistence + voice profiles · **M** · value: high
Name someone once; the app recognises them in the next rapat.
- Persist `{label → name}` per session (sidecar) and a global roster; match new
  clusters against stored centroids from `diarization.rs`.
- UI: a "Peserta" roster in Settings, and "Ini Pak Budi?" suggestions in the
  player.
- Touches: `rust_core/src/diarization.rs` (export centroids),
  `session_store.dart`, `transcript_view.dart`, a new roster screen.
- Risks: the current 3-feature clustering is too weak for reliable
  cross-session identity — ship it as *suggestions*, never silent assignment, and
  be honest about accuracy. A real embedding model is the proper fix and is an
  XL dependency.

### FG-10 · Bookmarks / highlights during recording · **S** · value: high
One keystroke (⌘/Ctrl+B) or one button drops a marker at the current timestamp,
optionally with a one-line note ("keputusan penting", "tindak lanjut"). Markers
appear on the player's seek bar and as a jump list, and lead the exported
notulen as "Poin Penting".
Cheapest meaningful win on this list: a notulis' real workflow is *flagging*
during the meeting, and right now nothing lets them do it.
- Touches: `lib/state/session_model.dart` (marker list), `main_screen.dart`
  (button + shortcut + footer chips), `session_store.dart` (sidecar),
  `transcript_player_screen.dart` (seek-bar ticks), `export/mod.rs`.
- Risks: none material.

### FG-11 · Audio-synced transcript with click-to-seek · **M** · value: critical
The fix for A.3-4 — and the difference between a transcript viewer and a
transcript *editor*.
- `onSeek` on `TranscriptView`; row tap seeks, pencil edits; active row
  auto-scrolls into view; a karaoke-style progress tint across the active row.
- Needs the perf work in A.3-6 (`ValueNotifier` + binary search) or it will be
  unusable at 5 000 segments.
- Touches: `transcript_view.dart`, `transcript_player_screen.dart`.
- Deps: `scrollable_positioned_list` (or fixed-extent rows).

### FG-12 · Keyboard-first correction editor · **M** · value: very high
Correcting a 3-hour transcript is the bulk of the notulis' actual work, and today
every correction is: tap row → modal dialog → edit → Simpan → find your place
again.
- Inline editing (no modal), Tab/Shift-Tab between segments, Enter to commit and
  advance, Esc to cancel, ⌘Z undo, Space to play/pause without leaving the field,
  ⌘/Ctrl+↓ to play from the current segment, F2 to rename the speaker of the
  current segment and all following.
- A visible "N koreksi belum disimpan" state and an explicit save (with
  autosave as a backstop), replacing the silent 400 ms debounce (A.3-1/A.3-2).
- An undo stack in `session_store` (append-only edit journal) — which also gives
  A.3-3 its restore path.
- Touches: `transcript_view.dart` (substantially), `transcript_player_screen.dart`,
  `session_store.dart`.
- Risks: the biggest single UI rewrite on this list; do it after FG-11 and the
  perf fixes, not before.

### FG-13 · Per-word confidence highlighting · **M** · value: medium-high
`avgLogProb` is already carried through the whole stack unused
(`models.dart:283`, "not surfaced in the UI today"), and `lowConfidence` is shown
only as a 10 px italic label per segment (`transcript_view.dart:439-460`).
- Segment-level: a subtle underline whose intensity maps to `avgLogProb`, plus a
  "Tinjau (N)" filter that shows only low-confidence segments — which turns
  "proofread 5 000 segments" into "proofread 180".
- Word-level needs `whisper.cpp` token timestamps and probabilities threaded
  through `pipeline.rs` — that is the L part; ship the segment-level filter first
  (S).
- Touches: `rust_core/src/confidence.rs`, `pipeline.rs`, `models.dart`,
  `transcript_view.dart`.
- Risks: over-highlighting makes the transcript unreadable — must be subtle and
  toggleable. Fix the `#D97706` contrast failure (A.12 table) while there.

### FG-14 · ID/EN code-switch handling · **M** · value: high
Real Indonesian professional speech is code-switched ("kita perlu align dulu soal
timeline-nya sebelum di-approve"). With `language: 'id'` forced, English spans
are transliterated into Indonesian nonsense; with auto-detect, whole chunks flip
to English.
- Per-chunk language detection from Whisper's own language probabilities, keeping
  `id` as the prior and only switching above a margin.
- Preserve English technical terms verbatim via the FG-03 glossary.
- Mark language per segment in the UI (the `TranscriptSegment.language` field
  already exists and is displayed nowhere).
- Touches: `rust_core/src/stt/*`, `pipeline.rs`, `transcript_view.dart`.
- Risks: needs a real evaluation set of code-switched Indonesian audio to tune
  against — build that first or this is guesswork.

### FG-15 · Meeting auto-detect · **S–M** · value: medium
Offer "Mulai merekam?" when Zoom/Teams/Meet starts playing audio. Deliberately
**not** via window titles — that was removed for privacy and should stay removed
(`bridge_service.dart:604-611`). Detect instead by: a known process name
(`zoom`, `Teams`, `chrome` with an active audio stream), or simply
sustained non-silence on the sink monitor for > 20 s while idle.
- A non-modal toast with "Mulai" / "Jangan tawarkan lagi".
- Touches: a new `rust_core/src/detect.rs`, `api.rs`, `main_screen.dart`,
  `settings.rs` (opt-in, default off).
- Risks: the privacy story — process enumeration is observation of the user's
  machine. The sink-activity approach avoids it entirely and should be preferred;
  it must be opt-in and named in the privacy report.

### FG-16 · Per-speaker talk time and meeting stats · **S** · value: medium
Talk-time per speaker, longest monologue, silence ratio, interruptions — from
data already loaded. Useful in a notulen ("Pak Budi 42%") and it makes the usage
dashboard (A.8) worth opening.
- Touches: `usage_dashboard_screen.dart`, `transcript_player_screen.dart` (a
  "Statistik" tab), `export/mod.rs`.

### FG-17 · Institutional deployment support · **M** · value: high for the target buyer
A `managed_settings.json` read from a system path that pins the library path,
disables the summary feature, sets the retention policy and pre-loads the
glossary — so an IT unit can roll the app out to 50 machines with one file. Plus
settings export/import for individual users.
- Touches: `rust_core/src/settings.rs`, `lib/state/settings_model.dart`,
  `DISTRIBUTION.md`.
- Risks: a managed setting must be visibly locked in the UI, not silently
  unchangeable.

---

# Part C — Production readiness

## PR-01 · Privacy report under-reports · **P0**
See A.7-1 in full. Three defects, one of them enforced by a test.

## PR-02 · Data loss: five distinct paths · **P0/P1**

| # | Path | Evidence |
|---|---|---|
| 1 | **Crash during recording loses the entire transcript.** Snapshots carry config only. | `rust_core/src/session.rs:186-192`, `:534`; `lib/state/session_model.dart:190` |
| 2 | **Crash during recording loses the entire audio.** RAM-only until stop. | `rust_core/src/session.rs:159`, `:260` |
| 3 | **Failed save on stop is a 3-second toast with no retry.** | `lib/screens/main_screen.dart:117-120` |
| 4 | **Failed transcript save in the player is `debugPrint`.** | `lib/screens/transcript_player_screen.dart:147` |
| 5 | **Re-transcribe overwrites hand corrections with no backup.** | `lib/screens/transcript_player_screen.dart:168-170` |

**Atomicity.** Rust writes atomically in both places it matters
(`export/mod.rs:237-239`, `session.rs:558-562`) — good. **Every Dart write is
non-atomic:** `transcript_player_screen.dart:145` (transcript),
`session_store.dart:226` (sidecar), `dart_prefs.dart:45` (prefs). All three are
`writeAsString` in place, and the sidecar carries the only copy of the summary.

**PR-03 · No disk-space handling anywhere.** Grep for `available_space`,
`disk_space`, `ENOSPC` across `rust_core/src` and `lib`: zero hits. The app
writes, per 3-hour Rapat Online session: ~690 MB × 2 WAV + transcript + a 548 MB
model download at setup. On a full disk: the model download fails with a raw
error (A.5), the session save fails into a 3-second toast (A.1-3), and
`DartPrefs.save` fails silently (`dart_prefs.dart:46-49`).
**Fix:** check free space before starting a session (refuse with an actionable
message below a threshold derived from the expected duration), before a model
download, and before an export; surface `ENOSPC` distinctly.

**PR-04 · Long-session memory growth.** Measured from the code, for a 3-hour
Rapat Online:

| Source | Growth | Evidence |
|---|---|---|
| Rust `raw_audio`, per source | 16 000 × 4 B × 10 800 s = **691 MB** | `session.rs:159`, `:260` |
| …×2 sources | **1.38 GB**, none of it freed until `export_session_audio` | `session.rs:167-178` |
| `audio_registry` after stop | holds the same 1.38 GB until export or removal | `session.rs:169` |
| Dart `segments` list | ~5 000 × ~250 B ≈ 1.2 MB (fine) — but reallocated per segment: **~12.5 M element copies** cumulatively | `session_model.dart:124`, `:127` |
| `TranscriptView` per-build tuple list | 5 000 allocations × ~5 Hz | `transcript_view.dart:183-190` |
| Library screen | full corpus in memory (A.2-3) | `session_store.dart:310` |
| `SummaryNotifier` | one leaked provider per opened session | `summary_panel.dart:52-61` |

`memory.rs` + auto-split on memory pressure exists (`session.rs:196-204`) — but
splitting the *session* does not release `raw_audio`, which is the thing growing.

**PR-05 · Secrets.** The summary API key is stored in plaintext in the settings
JSON. This is a *documented, deliberate* trade-off (`SECURITY.md`,
`summary_settings_section.dart:174-175`) and the UI says so to the user, which is
the right way to make that call. It is still the wrong default for a tool aimed
at government users who may point it at a paid endpoint.
**Fix:** `flutter_secure_storage` (Keychain / DPAPI / libsecret) with the
plaintext path as a documented fallback. Also: the key is included in
`saveSettings` on **every** settings change (`settings_model.dart:82-203`), so it
is rewritten to disk dozens of times per session.

**PR-06 · Updater security.** The manifest is an unsigned plain-text file at
`raw.githubusercontent.com/.../VERSION` (`update_checker.dart:75`). No signature,
no pinning, no minimum-version floor, no rollback protection. Nothing is
downloaded or executed, so the current exposure is limited to a false update
prompt — but "Lihat Rilis" is meant to lead to a binary download, and the moment
that is wired (A.4-2) this becomes the trust root for shipped code.
**Fix:** sign the manifest (minisign/Ed25519) with the public key compiled in;
verify before displaying; add a `minimum_version` field; never auto-download.

**PR-07 · Code signing, notarization, installer UX.**

| Platform | Status | Evidence |
|---|---|---|
| **macOS** | **Ad-hoc signature only** (`codesign --force --deep --sign -`), no Developer ID, **no notarization**, no stapling. Gatekeeper will refuse to open it; the user must right-click → Open, or run `xattr -d com.apple.quarantine`. | `scripts/package_macos.sh:77`, and `:5` documents this as intentional per ADR-12 |
| **Windows** | Signing is conditional on a `-PfxPath` argument that CI never passes. An unsigned `.exe` in a `.zip` → SmartScreen "unrecognized app", and no installer at all (no MSI/MSIX, no Start-menu entry, no uninstaller). | `scripts/package_windows.ps1:89`; `.github/workflows/release.yml:118-125` |
| **Linux** | `tar.gz` only. No `.deb`, no `.rpm`, no AppImage, no Flatpak, no `.desktop` file, no icon installation, no dependency declaration — and the app needs `libgtk-3`, `libasound2`, `libappindicator3`, PulseAudio/PipeWire (`ci.yml:136-141`). A user extracting the tarball on a fresh Ubuntu gets a dynamic-link error. | `.github/workflows/release.yml:88-96` |
| **Checksums** | Published for the **source** archive only; the three binary artifacts ship without any. | `release.yml:22-23` vs `:55-58`, `:93-96`, `:122-125` |

`--deep` on `codesign` is also deprecated and unreliable for nested frameworks —
sign inner bundles first, then the app.
**Fix priority:** (1) publish SHA256 for every artifact; (2) Developer ID +
notarization for macOS — without it the macOS build is effectively
undistributable; (3) `.deb` + AppImage with declared dependencies; (4) an
Authenticode certificate and an MSIX for Windows.

**PR-08 · Logging hygiene.** `init_logging()` is
`tracing_subscriber::fmt::try_init()` (`rust_core/src/api.rs:48-50`): stderr
only, no file, no rotation, no level control from the UI. Consequences:
- **A user cannot produce a log for a bug report.** A packaged GUI app's stderr
  goes nowhere the user can find on any of the three platforms. The
  purpose-built solution exists — `flight_recorder.rs` plus 9 FRB functions plus
  a 170-line Dart service — and has no caller (A.0-4).
- **No level control**, so the Round-2 rate limiter is the only thing standing
  between a misbehaving device and another log flood.
- **Hygiene itself is good:** a grep for `tracing::*!` lines containing
  text/path/transcript/key/prompt finds exactly one — a settings-file path in a
  corruption warning (`settings.rs:154`) — which is appropriate. No transcript
  text, no device names beyond capture diagnostics, no API keys. `debugPrint`
  in Dart appears 4 times and leaks only exception strings.
**Fix:** wire the flight recorder; write a rotating file under the app-support
dir; add "Ekspor Log Diagnostik" in Settings that redacts paths to
`<library>/…`; keep the level behind `RUST_LOG` plus a debug toggle.

**PR-09 · i18n infrastructure: none.** No `intl`, no `flutter_localizations`, no
`generate: true`, no `l10n.yaml`, no `lib/l10n/`, no `.arb` files. Every one of
the ~400 user-facing strings is a literal inside a widget, including 15+ English
ones (A.12 copy inventory) and a misspelled product name (UX-03).
Consequences: the "Indonesian-first" positioning is unenforceable (nothing stops
the next English string), regional-language support (Jawa, Sunda — a real
government ask) is impossible, an English UI for the international
open-source audience is impossible, and the user-facing typo can only be found by
reading every file.
**Fix:** `flutter_localizations` + ARB, `id` as the template locale, `en` as the
second; extract mechanically (`dart fix` won't do it — but a one-time script plus
`flutter analyze` on a `no_literal_strings` custom lint will). Add a CI grep for
`Traeon|Traereon`.

**PR-10 · Test coverage gaps.** 114 Dart tests, 259 Rust unit tests, `flutter
analyze` clean, `clippy -D warnings` clean. Well covered: `session_store`
(23 tests), `summary_model` (13), `batch_upload_model` (10), `session_model` (7),
`transcript_player_screen` (6), `privacy_proof` (6).

**Zero test coverage** (never imported by any test file — verified by import grep):

| File | Why it matters |
|---|---|
| `lib/main.dart` | app bootstrap, instance lock, onboarding routing — the "already running" screen has never been executed by a test |
| `lib/widgets/export_dialog.dart` | 7 formats, folder picking, the orphaned-dialog bug (A.9-1) |
| `lib/widgets/summary_panel.dart` | the only network-touching UI |
| `lib/widgets/summary_settings_section.dart` | where the endpoint and API key are entered |
| `lib/widgets/retranscribe_dialog.dart` | the destructive-replace path (A.3-3) |
| `lib/widgets/model_download_dialog.dart` | the no-cancel modal (A.10-1) and the subscription leak (A.10-2) |
| `lib/widgets/session_card.dart`, `storage_bar.dart`, `app_toast.dart`, `animated_record_button.dart`, `empty_state.dart`, `speaker_avatar.dart` | |
| `lib/services/update_checker.dart` | version comparison, 5 exception branches — and the `0.1.0` bug (A.4-3) would have been caught by one test |
| `lib/services/tray_service.dart`, `global_hotkey_service.dart`, `dart_prefs.dart` | |
| `lib/utils/format_time.dart`, `speaker_color.dart`, `model_labels.dart` | the >1 h formatting bug (A.3-5) is a 3-line test |
| `lib/screens/onboarding_screen.dart` | first-run UI; the "Traeon" typo (UX-03) is a `find.text` away |
| `lib/theme/app_colors.dart` contrast | no test asserts any WCAG ratio; all of A.12 is mechanically testable |

**Critical paths with no automated coverage at all:**
1. Crash recovery *end to end* — that it recovers no transcript is not asserted
   either way; a test would have made UX-01 obvious.
2. Live capture, real devices, real inference — manual smoke tests only
   (carried forward from `MEETILY-PARITY-REPORT.md:242`).
3. Long-session behaviour — nothing exercises 5 000 segments or a 3-hour
   duration, so every finding in A.1-11/A.2-3/A.3-6 is invisible to CI.
4. Disk-full / read-only / permission-denied I/O paths.
5. The export → re-import → re-export round trip.
6. Window resize / layout overflow — `tester.binding.setSurfaceSize(Size(800,600))`
   would catch UX-09 and A.3's overflow in a few lines each.

**PR-11 · CI gaps.** `ci.yml` (293 lines) is thorough on build coverage: Rust
fmt/clippy/test/audit/deny, Flutter analyze/test, Rust and Flutter release builds
on all three OSes, macOS and Windows packaging smoke tests, a benchmark job.
Missing:
- **`flutter test` runs on Ubuntu only.** Platform-conditional Dart code
  (`Platform.isWindows` paths in `models.dart:98-102`, `transcript_player_screen.dart:451-455`,
  the `split('/')` bug at `batch_upload_model.dart:53`) is never exercised on the
  platform it is written for.
- **No coverage measurement** (`--coverage`, no threshold, no trend).
- **No `dart format --set-exit-if-changed`** — Rust has `cargo fmt --check`, Dart
  has no equivalent gate.
- **`integration_test/` never runs.** It is also macOS-only by construction
  (hardcoded `Contents/Frameworks/librust_core.dylib`, `app_test.dart:34-40`) and
  contains no UI interaction at all — six direct FRB calls. Its
  `session lifecycle` test starts a session with both sources disabled
  (`:69-79`), which Round 2's `decide_start` was changed to refuse — so it is
  probably already broken, and nothing would report it.
- **No Linux packaging smoke test**, although Linux is the platform whose
  packaging is weakest (PR-07).
- **No version consistency check** (`VERSION` vs `pubspec.yaml`, A.4-3).
- **No accessibility or contrast gate**, no golden/screenshot tests, no
  `flutter build --analyze-size` budget.
- `cargo test --lib` only — `cargo test --tests` (the integration tests under
  `rust_core/tests/`, including `summary_live.rs`) never runs, even in the
  gated-skip form.
- `permissions: packages: write` is granted for no apparent reason; `NODE_OPTIONS:
  --experimental-vm-modules` is set in a workflow with no Node step.

---

# Part D — Prioritized roadmap

## Top 30

| # | Item | Category | Sev / Value | Effort | Rationale |
|---:|---|---|---|---|---|
| 1 | Persist the transcript continuously (JSONL journal) and make recovery restore it | Bug / Prod | **P0** | M | A crash loses a whole meeting. Everything else is cosmetic next to this. UX-01. |
| 2 | Stream captured audio to disk instead of holding it in RAM | Bug / Prod | **P0** | L | 1.38 GB for a 3 h session, and gone on any crash. Unblocks items 1, 12, FG-04. UX-02. |
| 3 | Fix the Privacy Report: count model downloads, count and disclose update checks, correct the copy | Bug / Prod | **P0** | S | The product's central promise is currently a verifiably false statement. PR-01. |
| 4 | Fix "Traeon" → "Trareon" on the onboarding screen; add a CI grep | Bug / UX | **P1** | S | Minutes of work; it is the first sentence of the product. UX-03. |
| 5 | Make failed saves recoverable: persistent banner + retry + save-elsewhere, in both save paths | Bug / UX | **P1** | S | Turns three silent data-loss paths into one visible, fixable one. A.1-3, A.3-1. |
| 6 | Atomic writes (temp+rename) for transcript, sidecar and prefs; add disk-space checks | Bug / Prod | **P1** | S | Rust already does this; Dart does not. PR-02, PR-03. |
| 7 | Back up the transcript before re-transcribe; offer restore | Bug / UX | **P1** | S | An hour of manual correction is destroyed by one button. A.3-3. |
| 8 | Expose `list_output_devices` through FRB and use it for speaker/loopback pickers | Bug | **P1** | S | "Output device" pickers currently list microphones. UX-05. |
| 9 | `foregroundColor: colors.onPrimary` on `ElevatedButtonThemeData`; fix `onSecondary`/`onError` | Bug / UX | **P1** | S | 2.44:1 on every primary button in dark mode. One line. UX-07. |
| 10 | Theme-aware, contrast-validated speaker palette + a ratio unit test | Bug / UX | **P1** | S | 6 of 8 colours fail AA in light mode, on the app's most-repeated text. UX-08. |
| 11 | Make the import queue scrollable; `setMinimumSize` on Linux/Windows | Bug / UX | **P1** | S | Layout overflow on the two platforms with no minimum window size. UX-09, A.11-1. |
| 12 | Improve the recovery banner: list sessions with segment count and duration, say what is and isn't recovered, allow delete | UX | **P1** | S | Honest even before item 1 lands; essential after. |
| 13 | Fix the transcript-list rebuild storm: cache the item list, key the rows, `ValueNotifier` for playback position, binary-search the active index | Bug / UX | **P1** | M | The app is unusable at the duration it is built for. A.1-11, A.1-13, A.3-6. |
| 14 | O(1) segment ingestion (`Map<key,index>`, no full list copy) | Bug | **P1** | S | O(n²) over a session, on the UI isolate, while Whisper saturates the CPU. A.1-12. |
| 15 | Two-phase library load (index file) + debounced search + memoised snippets | Bug / UX | **P1** | M | Library open currently parses the entire corpus; search re-scans it per keystroke. A.2-3, A.2-4. |
| 16 | Click-to-seek + auto-scroll to the active segment | Feature / UX | **high** | M | The core review loop for a 3 h recording does not exist today. FG-11, A.3-4. |
| 17 | Persist theme "Sistem"; wrap all 15 settings saves in error handling | Bug | **P1** | S | Settings silently do not do what the UI says. A.4-6, A.4-7. |
| 18 | Version from `package_info_plus`; wire "Lihat Rilis" via `url_launcher`; CI check `VERSION == pubspec` | Bug | **P1** | S | The updater cannot currently report correctly in either direction. A.4-3, A.4-2. |
| 19 | Wire `SetupOverlay` (preflight) into `main.dart` + a "Diagnostik" tile; add `try/catch` | Bug / UX | **P1** | S | `doctor.rs` exists and never runs; it is the answer to most support questions. A.0-2. |
| 20 | Wire the setup wizard into Settings and fix its three platform bugs, or delete it | UX | **P1** | M | 935 tested lines containing the only device picker and audio test. A.6-1. |
| 21 | Fix the batch-import defects: progress on the progressive path, `firstWhere` guard, `p.basename`, cancel | Bug | **P1** | M | The default import path shows no progress and can crash on queue clear. B.1-2. |
| 22 | Glossary / `initial_prompt` vocabulary | Feature | **very high** | M | Cheapest large accuracy win for Indonesian meeting jargon. FG-03. |
| 23 | Notulen Rapat DOCX template per Tata Naskah Dinas (+ the form) | Feature | **very high** | L | The differentiator for the government audience; nothing comparable exists. FG-02. |
| 24 | Bookmarks / highlights during recording | Feature | **high** | S | Matches how a notulis actually works; ~1 day. FG-10. |
| 25 | Accessibility pass: `Semantics` on all 8 screens, live regions, 48 px targets, 5 missing tooltips, fix the dead `StreamToggle` labels | UX | **P1** | M | Zero screen-reader support outside the upload zone; a public-sector procurement blocker. A.12. |
| 26 | i18n infrastructure (ARB + `flutter_localizations`) and extraction of all strings | Prod | **P1** | L | The Indonesian-first claim is currently unenforceable, and the UX-03 typo proves it. PR-09. |
| 27 | Wire the flight recorder: rotating log file + "Ekspor Log Diagnostik" | Prod | **P1** | S | Users cannot currently produce a log; the machinery is already written. PR-08. |
| 28 | Auto re-transcribe after the meeting with the accurate model | Feature | **high** | M | Turns the slow-device compromise into a feature. Needs items 2 and 7. FG-04. |
| 29 | macOS Developer ID + notarization; SHA256 for every artifact; `.deb`/AppImage | Prod | **P1** | M | The macOS build is effectively undistributable and the Linux tarball won't launch on a clean system. PR-07. |
| 30 | Delete the dead code (4 widgets/screens, 1 service, ~20 FRB functions) and the stale comments that reference it | Prod | P2 | S | ~1 400 lines plus three duplicate implementations of live widgets. A.0-1, A.0-4. |

**Deliberately below the line, with reasons:** UU PDP mode (FG-08 — very high
value but L effort and it must sit on top of a durable store, so sprint 4);
local Q&A over the archive (FG-06 — needs the search index from item 15 first);
PDF export (FG-07 — pairs with item 23, not before); keyboard-first editor
(FG-12 — depends on item 16 and the perf work in item 13); per-word confidence
(FG-13 — the segment-level "Tinjau (N)" filter is cheap and could be pulled
forward); code-switch handling (FG-14 — needs an evaluation set built first);
speaker voice profiles (FG-09 — the current clustering is too weak to build
identity on).

## Suggested 3-sprint plan (2 weeks each)

### Sprint 1 — "Nothing is lost, nothing is a lie" (items 1–12, 30)
Durability and truthfulness. Ten of the thirteen are S-effort, so this is
achievable and it removes every P0.

- Week 1: items 1, 3, 4, 5, 6, 30. Ship the transcript journal and recovery
  first; do the privacy-report correction and the typo on day one because they
  are minutes of work with outsized consequences.
- Week 2: items 2, 7, 8, 9, 10, 11, 12.
- **Exit criteria:** kill `-9` the app 90 minutes into a recording and recover
  the transcript and the audio. The privacy report's three statements each match
  a call site. `flutter test` includes a contrast test, a >1 h formatting test,
  and a `setSurfaceSize(800×600)` overflow test for the library and player.
- **Risk:** item 2 (audio to disk) is the one L item and touches the capture
  path Round 2 just stabilised. Keep it behind a flag for one release and keep
  the RAM path as a fallback.

### Sprint 2 — "Usable at three hours" (items 13–21)
Performance and the review loop. Everything here is about the actual target
workload, which no current code path has been exercised against.

- Week 1: items 13, 14, 15. Build a synthetic 5 000-segment / 3-hour fixture
  **first** and make it a permanent benchmark test — without it the fixes cannot
  be verified and will regress.
- Week 2: items 16, 17, 18, 19, 20, 21.
- **Exit criteria:** a 5 000-segment session scrolls at 60 fps; library open with
  200 sessions is under 500 ms; search is responsive while typing; clicking a
  transcript line seeks the audio; the setup wizard and preflight are reachable.
- **Risk:** item 20 (wizard) may reveal that the device-picker plumbing needs
  more than the UI — timebox it and fall back to "delete it" if the platform
  bugs run deep.

### Sprint 3 — "Indonesian-first, for real" (items 22–29)
Differentiation and shippability. This is the sprint that makes the product
distinct rather than merely correct.

- Week 1: items 22 (glossary), 24 (bookmarks), 27 (log export), 28 (auto
  re-transcribe). Four independent, parallelisable pieces.
- Week 2: items 23 (notulen DOCX), 25 (accessibility), 29 (signing and
  packaging). Start 26 (i18n) as a background track — the extraction is
  mechanical and can proceed in parallel, but do not merge it mid-sprint or it
  will conflict with every other change.
- **Exit criteria:** a real rapat produces a Tata Naskah Dinas notulen DOCX with
  correct jargon from the glossary; the macOS build opens without a Gatekeeper
  warning; `.deb` installs on a clean Ubuntu; a screen reader can drive the
  recording and library screens; every artifact has a published SHA256.
- **Risk:** item 23's template varies per institution. Ship 2–3 variants plus a
  `{{placeholder}}` mechanism rather than trying to satisfy everyone; validate
  against one real ministry's format before building the second.

**Sprint 4 and beyond, sketched:** UU PDP mode (FG-08), local Q&A over the
archive (FG-06) on the search index from item 15, PDF (FG-07), the keyboard-first
editor (FG-12), the low-confidence review filter (FG-13), and a proper design
system (spacing/radius/typography tokens with a lint) to stop the theme drift
catalogued in A.12 from recurring.
