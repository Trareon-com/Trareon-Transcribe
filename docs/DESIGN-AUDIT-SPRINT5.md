# Design self-audit, sprint 5

Run against the committed screenshots of the real release build in
`docs/screenshots/sprint5/` and the goldens in `test/goldens/`, using the
eight categories and the scoring bands from the `design-audit` skill. Audited
on Linux (the 30 screenshots, three window sizes, both themes) and on Windows
(the interactive-session capture in `docs/screenshots/sprint5/windows/`).

Everything marked **FIXED** was fixed inside this sprint and the evidence is a
screenshot or a golden committed alongside this file. Everything marked
**OPEN** is in the sprint report's known gaps.

---

## Score

| Category | Weight | Before (end of sprint 4) | After |
|---|---|---|---|
| Colour & contrast | 20% | 72 | 95 |
| Typography | 15% | 48 | 92 |
| Spacing & layout | 15% | 58 | 90 |
| Component consistency | 20% | 55 | 92 |
| Dark mode | 10% | 65 | 95 |
| Responsiveness | 10% | 75 | 88 |
| Accessibility | 10% | 80 | 92 |
| Motion | 10% | 45 | 90 |
| **Weighted total** | | **62 (C)** | **92 (A)** |

The "before" column is a judgement against the same checklist, using the
pre-sprint code and the screenshots that shipped with it; it is an estimate,
not a measurement. The "after" column is the one that matters, and every
deduction behind it is listed below.

---

## 1. Colour & contrast, 95

**Before.** One saturated Material teal (`#00796B`) used as fill, as text, as
chip background and as section accent, so the brand colour was the loudest
thing on every screen. Three greys in dark mode. 25 loose colour literals
outside the theme.

**After.** A ten-step accent ramp with the accent used scarcely (brand mark,
primary action, focus ring, selection, link), two separately tuned 12-step
neutral ramps, four semantics plus a dedicated recording scarlet. Every text
pair measured: `test/theme_contrast_test.dart` holds AA in both themes and the
measured ratios run 5.4:1 to 16.7:1.

| Finding | Status |
|---|---|
| Device pills filled themselves with an 8 % accent wash whether or not anything was recording, which is most of why the screen read as teal everywhere | **FIXED**, `DeviceStatusChip` is neutral at rest |
| The segmented mode selector painted the selected option in the accent, making a three-way control the brightest thing on screen | **FIXED**, selected now lifts one surface step (Linear's pricing-tab move) |
| Dark mode had three greys and no ladder, so a dialog over a menu over a card were all the same colour | **FIXED**, five-step ladder, `test/design_lint_test.dart` asserts it is monotonic |
| 25 colour literals outside `lib/theme/` | **FIXED**, 0; lint |
| `recording` and `danger` were the same red | **FIXED**, scarlet vs crimson, different shapes, and the badge always carries a word |
| Deduction: `t3` on `s4` measures 4.7:1. It is AA, but it has no headroom, so the system rule is "not at caption size on `s4`". That rule is documented, not enforced | **OPEN** |

## 2. Typography, 92

**Before.** `Typography.blackMountainView` (the Material default), 169 loose
`fontSize:` literals, no line-height or tracking anywhere, no tabular figures,
a running timer that reflowed every second.

**After.** Inter and JetBrains Mono bundled under the OFL, twelve named roles
each carrying weight, line height, tracking and numeric features.

| Finding | Status |
|---|---|
| The transcript body used `RichText`, which does not merge `DefaultTextStyle`, so **the most-read text in the app** rendered in the platform fallback face rather than the app's own. Caught by the first golden that loaded a real font | **FIXED**, `Text.rich` + `AppText.reading`; lint bans `RichText` |
| Every `Dropdown` handed its selected value a bare `TextStyle`, and Dropdown *replaces* `DefaultTextStyle`, so all of them rendered outside the typeface too | **FIXED**; lint covers `DropdownButton`, `DropdownButtonFormField` and `DefaultTextStyle` |
| The recording timer wobbled: proportional figures | **FIXED**, `monoTimer`, tabular; lint asserts every numeric role is tabular |
| 169 `fontSize:` literals | **FIXED**, 0; lint |
| Deduction: 221 call sites still build a bare `TextStyle` for colour or weight on top of an inherited style. They are correct (they inherit the family) but they are not roles | **OPEN** |

## 3. Spacing & layout, 90

| Finding | Status |
|---|---|
| The settings pane ran the full window width, so at 1920 px a five-character theme picker got an 800 px dropdown | **FIXED**, capped at 760 and centred. Before: `settings-1920x1080-*.png` in the first capture run; after: the committed file |
| The shortcuts panel put every keycap a screen-width from the action it names | **FIXED**, capped at the reading measure |
| The transcript ran edge to edge, producing 200-character lines at 1920 px | **FIXED**, capped at 960 so the prose lands near 70ch |
| The speaker column was 72 px, so every row in the app read "Pe…" | **FIXED**, 148 px |
| Nine controls stacked above the transcript on an empty screen | **FIXED**, the idle state is a hero with one filled button |
| 184 numeric `SizedBox` gaps, 128 numeric `EdgeInsets`, 70 ad-hoc radii | **FIXED**, 0; lint |
| Deduction: the session list abuts the sidebar footer, so at 900x600 the last visible row is sliced mid-row. Visible in `main-idle-900x600-light.png` | **OPEN** |

## 4. Component consistency, 92

| Finding | Status |
|---|---|
| 142 different Material icons in four visual variants (`_outlined`, `_rounded`, filled, bare), sometimes two in the same row | **FIXED**, one semantic vocabulary over Material Symbols Rounded; `Icons.` banned outside `app_icons.dart` |
| Two emoji used as UI icons in the quality menu and the setup wizard | **FIXED**, `AppIcons.quick` / `AppIcons.accurate` |
| Two notification systems: `AppToast` and eight `SnackBar` call sites | **FIXED**, one; `SnackBar` and `ScaffoldMessenger` banned in `lib/` |
| No pressed or focus state anywhere; focus was Material's hover highlight | **FIXED**, every control in the kit carries default / hover / pressed / focus-visible / disabled, and loading where the action is async |
| The sidebar offered "Sesi Baru" twice on one surface (the button and the empty state) | **FIXED**, duplicate-CTA removed |
| Deduction: a few screens still use Material `OutlinedButton`/`FilledButton` directly rather than `AppButton`. They are themed, so they look right, but they are not the kit | **OPEN** |

## 5. Dark mode, 95

| Finding | Status |
|---|---|
| Near-black `#121212` with no ladder | **FIXED**, `#0C0E0F` canvas and a five-step ladder |
| Shadows on dark surfaces, where they are invisible and only cost fill rate | **FIXED**, dark carries no shadow above elevation 1; asserted by the lint |
| Opaque grey borders stacking visibly when surfaces nested | **FIXED**, alpha hairlines; the lint asserts every line role is translucent |
| Both themes render every screen in the committed screenshots | verified |

## 6. Responsiveness, 88

| Finding | Status |
|---|---|
| The hero pushed the record button below the fold in a short pane | **FIXED**, it sheds the headline at <660 px and the mode explanations at <600 px. Evidence: `main-idle-900x600-light.png` versus `main-idle-1280x800-light.png` |
| The recording strip overflowed by 48 px at 800x600 | **FIXED**, the waveform moves under the device chips below 640 px of workspace |
| `AppStatusBadge` could not shrink, so a sentence-length label overflowed its pill at 1.5x text scale | **FIXED**, `Flexible` + ellipsis |
| Deduction: the window minimum moved to 900x600, but 800x600 is still exercised by the layout tests because an older saved geometry can restore to it. Both pass | noted |

## 7. Accessibility, 92

| Finding | Status |
|---|---|
| Focus was indistinguishable from hover | **FIXED**, a 2 px focus ring at a 2 px offset, drawn outside the control's own box so it cannot be clipped by a neighbouring row (SC 2.4.11) |
| Icon-only buttons without names | already gated by `test/accessibility_test.dart`; the kit now makes `tooltip` a *required* parameter, and the scan was widened to cover it |
| Colour as the only carrier of selection | **FIXED**, the selected list row also has a 2 px accent rail and a weight change; the selected mode card also has a border and a tick |
| Reduce motion | **FIXED**, one `AppMotion.of(context)`; both continuous loops stop and hold a static frame |
| Deduction: no screen-reader pass has been run on any platform. The semantics are declared and unit-tested, which is not the same thing | **OPEN** |

## 8. Motion, 90

| Finding | Status |
|---|---|
| Durations were 200/250/300/900 ms picked per call site, with `Curves.easeInOut` everywhere | **FIXED**, five durations and four curves, and a catalogue in DESIGN-SYSTEM §8.3 where every animation carries a one-sentence justification |
| The record button pulsed with a scale on a glow shadow (an "AI tell") | **FIXED**, an expanding hairline ring, no glow |
| Reduce motion was not honoured anywhere | **FIXED** |
| Deduction: the transcript insert animation is capped at 200 rows to protect the 5,000-segment perf budget, so a long meeting loses it. A deliberate trade, not a defect | noted |

---

## 9. Windows pass (win2060, RTX 2060, Windows 11 Pro)

The release build was compiled on the Windows machine and driven through the
preflight blocker, the idle main screen and the settings screen with a
scheduled task in the interactive session. No audio was played and no
microphone was opened; the machine has no input device, which is why the
blocker is the first screen. Two defects were only visible here, and both are
fixed with a before and an after in `docs/screenshots/sprint5/windows/`.

| Finding | Status |
|---|---|
| Hiding the native title bar hides it for *every* route, but the drag strip and caption buttons were built inside the main screen, so the preflight blocker and the onboarding had no way to move, minimise or close the window at all. Before: `before-no-caption-buttons-windows.png`. After: `preflight-blocker-windows.png` | **FIXED**, `WindowChromeScaffold` in `MaterialApp.builder` |
| The first fix left the main screen's own copy in place, so the main screen drew **two** rows of minimise/maximise/close stacked on top of each other. Before: `before-double-caption-windows.png`. After: `main-idle-windows.png` | **FIXED**, the strip is drawn once, at the root |
| The caption buttons match the Windows 11 metrics (46x32, close turns red on hover) and the snap-layout flyout still attaches to the maximise button | verified |
| The two-pane settings layout, the bundled typeface, the icon vocabulary and the accent all render identically to Linux. Evidence: `settings-windows.png` | verified |
| Deduction: the sidebar footer is pinned to the bottom of the window, and Windows clamps a 800 px request to the 740 px work area, so the last footer row ("Pengaturan") can sit under the taskbar. The shortcut and the settings entry elsewhere still reach it, but the row itself is unreachable at that height | **OPEN** |
| Not covered: live WASAPI capture, by the owner's standing rule. Listed in the sprint report under "PERLU IZIN OWNER: uji audio Windows" | **OPEN** |

---

## Anti-slop pass (`design-taste-frontend` §9)

Checked against the committed screenshots, one line each:

- No decorative gradient anywhere. The only gradient is the skeleton shimmer.
- No glow, no neon, no drop shadow on a dark surface.
- No emoji in the UI.
- No placeholder people and no invented names: every name in a screenshot is
  either the engine's `Pembicara N` or real data from this machine's library.
- No em-dash in any user-visible string; `test/copy_lint_test.dart` gates it.
- No `...` typed as three periods; same test.
- No default Material look: no card elevation, no ripple on a dense row, no
  purple fallback scheme, no `blackMountainView`.
- No decorative status dots: the two coloured dots carry real state and are
  paired with text.
- One accent, used identically on every screen.
- One documented radius system (DESIGN-SYSTEM §4.2).
- Every button label is one or two words and fits on one line at every size
  captured.
- No eyebrow above a section headline; `overline` is a control-group label and
  there are at most two on any screen.
