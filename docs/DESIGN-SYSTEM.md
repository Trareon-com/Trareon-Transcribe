# Trareon Transcribe: Design System

Version 1.0 · Sprint 5 (`sprint/05-design`) · owner-facing beta on macOS and Windows.

This document is the contract. Every colour, size, radius, duration and icon the
app draws is named here first and implemented in `lib/theme/`. If a value is not
in this document it does not belong in a widget, and `test/design_lint_test.dart`
fails the build on it.

UI copy stays Bahasa Indonesia (`lib/l10n/*.arb` and literal strings in
`lib/`). This document is the engineering spec, so it is in English; the copy
rules in §10 are about Indonesian.

---

## 0. Design read and dials

**Design read:** *a local-first desktop productivity tool (meeting capture and
official Indonesian minutes) for government and office staff who keep it open
for three hours at a time, with a calm, dense, dark-first professional language,
leaning toward a hand-built Flutter token system (`ThemeExtension`) plus Inter /
JetBrains Mono and restrained, feedback-only motion.*

The audience is a notulis in a Kementerian office and the owner testing on a
MacBook and a Windows laptop. They are not looking at the app; they are looking
at a meeting through it. Confidence comes from nothing moving unless something
happened.

**Dials** (`design-taste-frontend` §1):

| Dial | Value | Why |
|---|---|---|
| `DESIGN_VARIANCE` | **3** | Productivity chrome, not a landing page. Symmetric grid, one alignment per column, zero asymmetric flourish. The §1.A row for "trust-first / public-sector / accessibility-critical" sets 3-4, and public-sector procurement is a real buyer here (blueprint §1). |
| `MOTION_INTENSITY` | **3** | Hover/press/focus feedback and state transitions only. One continuous animation exists in the whole app (the record button breathing + the live level meter) and it exists because "is this actually recording?" is the product's #1 competitor complaint (blueprint §2, NEW). Everything collapses under reduce-motion. |
| `VISUAL_DENSITY` | **7** | A 3-hour meeting means a transcript list, a sidebar of sessions, a device strip and a timer all legible at 1280x800. Dense-but-breathable: hairlines separate data, cards are used only where elevation means something, and all figures are tabular. |

Because `MOTION_INTENSITY` is 3, §5's "motion claimed = motion shown" bar is low
on purpose and §6.B reduce-motion is still mandatory: every animation in §8
reads `MediaQuery.disableAnimations`.

### Anti-default discipline

Checked against `design-taste-frontend` §9 before any code was written. None of
these appear anywhere in the app:

- No gradients as decoration. The only gradient in the system is the live level
  meter's fill, and it is data.
- No glow, no neon, no drop shadow on a dark surface. Dark-mode depth is a
  surface ladder (§3.2).
- No emoji as UI icons. `⚡` and `🎯` in the session-quality menu and the setup
  wizard were emoji-as-icon and are now `AppIcons.quick` / `AppIcons.accurate`.
- No placeholder people. Speaker names come from the engine (`Pembicara 1`) or
  from the user; the empty states show an icon composition, never an avatar.
- No em-dash (U+2014) in UI copy. `test/copy_lint_test.dart` fails on one.
- No default Material look: no `Card` elevation, no Material ripple splash on a
  dense list row (replaced by a surface-tint hover), no purple `ColorScheme`
  fallbacks, no `Typography.blackMountainView`.
- No decorative status dots. The two coloured dots in the app (`recording`,
  `capture confirmed`) carry real state and are paired with text.

---

## 1. Principles

1. **Nothing moves unless something happened.** Motion is feedback, orientation
   or state change. If a reviewer cannot say which of the three in one sentence,
   the animation is deleted.
2. **One primary action per surface.** Blueprint §4.2. The idle main screen has
   exactly one filled button. Export does not exist until there is a transcript.
3. **Hairlines before boxes, boxes before shadows.** A 1px alpha hairline
   separates almost everything. A card is only used when the thing inside it is
   genuinely at a different elevation (a dialog, a floating player bar, a toast).
4. **Figures are tabular, always.** Timers, timestamps, durations, counts and
   byte sizes use `FontFeature.tabularFigures()` so a running clock does not
   wobble. Timestamps in the transcript use the mono face.
5. **The transcript is a document, not a feed.** The reading column is capped at
   a comfortable measure (~70ch) and centred; the chrome gets out of the way.
6. **Every interactive thing has five states.** default / hover / pressed /
   focus-visible / disabled, plus loading where an action is async. A component
   without all of them is not finished.
7. **Contrast is a gate, not a preference.** WCAG 2.2 AA in both themes, checked
   mechanically (`test/theme_contrast_test.dart`), and AA is the floor: the
   measured ratios in §2 are mostly 6:1 and up.
8. **The app is Indonesian.** Copy is Indonesian, human, and jargon-free
   (blueprint §4.4). Keyboard hints render `⌘` on macOS and `Ctrl` elsewhere.

---

## 2. Visual language and colour tokens

Single source: `lib/theme/app_colors.dart`. Light and dark are **separately
tuned ramps**, not one ramp inverted.

### 2.1 Neutral scale (light): `TrareonNeutral.light*`

A low-chroma cool grey with a trace of the brand's blue-green, so neutrals and
accent read as one family.

| Token | Hex | Role |
|---|---|---|
| `n0` | `#FFFFFF` | Surface: cards, inputs, sidebar, header |
| `n50` | `#F7F8F8` | Canvas (window background) |
| `n100` | `#EFF1F1` | Sunken fill: chips, search field, keycaps, hover on canvas |
| `n150` | `#E5E8E8` | Pressed fill, selected row on surface |
| `n200` | `#D9DDDD` | Strong hairline, track of a progress bar |
| `n300` | `#C0C6C6` | Disabled border |
| `n400` | `#99A1A1` | Disabled text and icon (exempt from 1.4.3) |
| `n500` | `#636B6B` | Tertiary text (metadata, helper, placeholder) |
| `n600` | `#545C5C` | Secondary text |
| `n700` | `#3B4242` | Strong secondary / icon default |
| `n800` | `#262B2B` | Primary text |
| `n900` | `#151818` | Display headings |
| `n950` | `#0B0D0D` | Reserved (print / export) |

Measured: `n800` on `n50` **13.5:1**, on `n0` **14.4:1**. `n600` on `n0`
**6.9:1**. `n500` on `n0` **5.5:1**, on `n100` **4.8:1**.

### 2.2 Neutral scale (dark): layered elevation, never pure black

Borrowed from Linear and Raycast: depth is a **surface ladder**, there are no
shadows on dark.

| Token | Hex | Role |
|---|---|---|
| `canvas` | `#0C0E0F` | Window background (off-black, faintly blue-green) |
| `s1` | `#131617` | Default surface: sidebar, header, cards |
| `s2` | `#181C1D` | Sunken fill on `s1` *and* raised panel on `canvas` |
| `s3` | `#1E2223` | Menus, popovers, selected row |
| `s4` | `#252A2B` | Dialogs, toasts, the floating player bar |
| `hairline` | `#272C2D` | 1px border, the universal edge |
| `hairlineStrong` | `#333A3B` | Divider that must read as a rule |
| `t1` | `#ECEFEF` | Primary text (16.7:1 on canvas) |
| `t2` | `#B4BBBC` | Secondary text (9.9:1) |
| `t3` | `#8C9496` | Tertiary text (6.3:1 on canvas, 4.7:1 on `s4`) |
| `t4` | `#6A7273` | Disabled |

**Rule:** a surface may rise at most two steps above its parent, and `t3` is not
used on `s4` at caption size (4.7:1 is AA but has no headroom): `t2` is.

### 2.3 Accent scale: Trareon teal, refined

The brand identity stays teal; the **saturated Material `#00796B`** that was
teal-everywhere is replaced by a tuned 10-step ramp at hue ≈ 172°, and the
accent is now *scarce*: brand mark, primary action, focus ring, selection, link.
It no longer paints device pills, chips or section headers.

| Token | Hex |
|---|---|
| `teal50` | `#ECF7F4` |
| `teal100` | `#CFEBE5` |
| `teal200` | `#A6D9CF` |
| `teal300` | `#74C2B4` |
| `teal400` | `#42A595` |
| `teal500` | `#1E8A79` |
| `teal600` | `#146F62` |
| `teal700` | `#0F584E` |
| `teal800` | `#0B423B` |
| `teal900` | `#072C27` |

Assignment:

| Role | Light | Dark |
|---|---|---|
| `accent` (fill) | `teal600` | `teal300` |
| `onAccent` | `#FFFFFF` (6.0:1) | `teal900` (7.2:1) |
| `accentHover` | `teal500` | `teal200` |
| `accentPressed` | `teal700` | `teal400` |
| `accentText` (link, icon) | `teal600` (6.0:1 on `n0`) | `teal300` (9.3:1 on canvas) |
| `accentSubtle` (selected row fill) | `teal50` | `teal900` |
| `focusRing` | `teal500` (4.2:1 ≥ 3:1) | `teal300` (9.3:1) |

### 2.4 Semantic colours

Four semantics plus a dedicated **recording** red, because "recording" is not an
error and the two must never be confusable at a glance.

| Role | Light | on-light ratio | Dark | on-dark ratio (canvas) |
|---|---|---|---|---|
| `success` | `#15713D` | 6.1:1 | `#5FD08B` | 10.0:1 |
| `warning` | `#8A4B00` | 6.8:1 | `#F2C06B` | 11.5:1 |
| `danger` | `#B3261E` | 6.5:1 | `#FF8F85` | 8.8:1 |
| `info` | `#0B5CAD` | 6.7:1 | `#7FC0FF` | 10.0:1 |
| `recording` | `#BF3B21` | 5.4:1 | `#FF7A6E` | 7.6:1 |

Each has an `on*` ink for filled chips (all ≥ 6.4:1) and a `*Subtle` fill at
10% alpha for banners. `recording` is a scarlet; `danger` is a crimson. They are
one hue step apart and always differentiated by shape as well: recording is a
filled dot with a breathing ring, danger is a triangle/`error` glyph.

### 2.5 Speaker palette

Eight accents used as the **text colour of the speaker name** on every
transcript row, re-tuned per theme. Light entries measure 6.0:1 to 10.3:1 on
both the canvas and the surface; dark entries 7.8:1 to 10.5:1. Gated by
`test/speaker_color_test.dart`.

### 2.6 Borders and hairlines

Borders are expressed as **alpha over the parent surface**, not as an opaque
grey, so a card inside a card does not stack two visible lines:

- `hairline`: 1px, light `#262B2B @ 10%`, dark `#FFFFFF @ 9%`.
- `hairlineStrong`: 1px, light `#262B2B @ 16%`, dark `#FFFFFF @ 14%`.
- `borderInteractive`: 1px on inputs/secondary buttons: light `#262B2B @ 18%`,
  dark `#FFFFFF @ 15%`.

### 2.7 Elevation

| Level | Light | Dark |
|---|---|---|
| 0 flat | no border, no shadow | same |
| 1 hairline | 1px `hairline` on `n0` | 1px `hairline` on `s1` |
| 2 raised | `n0` + 1px hairline + `0 1px 2px rgba(21,24,24,.06)`, `0 1px 1px rgba(21,24,24,.04)` | step to `s2`, **no shadow** |
| 3 overlay | `n0` + `0 8px 24px rgba(21,24,24,.10)`, `0 2px 6px rgba(21,24,24,.06)` | step to `s3` + 1px hairline |
| 4 modal | `n0` + `0 16px 48px rgba(21,24,24,.16)`, `0 4px 12px rgba(21,24,24,.08)` | step to `s4` + 1px `hairlineStrong` |

Shadows are **tinted to the neutral ramp** (`#151818`), never pure black, and
dark mode gets none above level 1. Two layers maximum.

---

## 3. Typography

### 3.1 Faces

| Family | File | Use |
|---|---|---|
| **Inter** 400/500/600/700 | `assets/fonts/Inter-*.ttf` | Everything |
| **JetBrains Mono** 400/500 | `assets/fonts/JetBrainsMono-*.ttf` | Timestamps, elapsed timer, keycaps, byte/WER figures |

Both are SIL Open Font License 1.1 and both cover Indonesian/Latin fully.
Licences ship as `assets/fonts/Inter-LICENSE.txt` and
`assets/fonts/JetBrainsMono-OFL.txt` and are declared in `assets/fonts/README.md`.

Bundling (rather than the platform face) is deliberate for three reasons: the
goldens in `test/goldens/` are deterministic only with a bundled font; the three
target platforms otherwise render three different type rhythms for the owner's
side-by-side test; and `Typography.blackMountainView` is one of the §9 default
Material tells.

`FontFeature.tabularFigures()` is on for every numeric role, and
`fontFamilyFallback` keeps the platform UI face behind Inter for any glyph Inter
lacks.

### 3.2 Scale

Sizes are logical pixels. Everything must survive 1.5x text scaling
(`test/text_scaling_test.dart`).

| Role | Size | Weight | Line height | Tracking | Use |
|---|---|---|---|---|---|
| `display` | 28 | 600 | 1.14 | −0.5 | The one number or hero line a screen exists for |
| `title` | 20 | 600 | 1.25 | −0.3 | Screen headline |
| `heading` | 16 | 600 | 1.30 | −0.2 | Section / dialog title |
| `subheading` | 14 | 600 | 1.35 | −0.1 | Card title, list row title |
| `body` | 13 | 400 | 1.50 | 0 | Default dense desktop body |
| `bodyLarge` | 14 | 400 | 1.55 | 0 | Transcript reading text |
| `label` | 13 | 500 | 1.20 | 0 | Button and control labels |
| `caption` | 12 | 400 | 1.40 | 0 | Helper text under a control |
| `micro` | 11 | 400 | 1.35 | +0.1 | Dense metadata |
| `overline` | 10 | 600 | 1.20 | +0.8 | Group label (`SESI`, `PERANGKAT`) |
| `mono` | 12 | 400 | 1.40 | 0 | Timestamp, keycap |
| `monoLarge` | 24 | 500 | 1.10 | 0 | Recording timer |

Negative tracking on display/title sizes is the one typographic move borrowed
from Apple and Linear: it is what stops a 28px Indonesian headline from reading
as a browser default.

**Overline restraint** (`design-taste-frontend` §4.7 eyebrow rule, translated):
`overline` is a *control-group* label, never a section eyebrow above a headline,
and at most one per visual group. The main screen has exactly two (`SESI`,
`PERANGKAT`); Settings has one per card group.

### 3.3 Reading measure

Transcript and notulen preview bodies are capped at `Measure.reading` = 680 px
(~70ch at `bodyLarge`) and centred in their pane. Borrowed from Notion, because
a 1920px-wide transcript line is unreadable and that is the screen the owner will
test on.

---

## 4. Spacing, radius, sizing

### 4.1 Spacing: 4-point scale

`xs 4` · `sm 8` · `md 12` · `lg 16` · `xl 24` · `xxl 32` · `xxxl 48`

Rules: gap inside a control = `xs`; between controls in a row = `sm`; default
gap = `md`; screen padding and gap between groups = `lg`; between sections =
`xl`; around an empty state = `xxl`. Section rhythm never exceeds `xxxl`: this
is a 1280x800 tool, not a marketing page.

### 4.2 Radius: documented mixed system

`design-taste-frontend` §4.4 allows a mixed radius system only with a written
rule. The rule:

| Token | Value | Applies to |
|---|---|---|
| `xs` | 4 | Keycaps, level-meter track, inline tags |
| `sm` | 6 | Chips, badges, small inline pills |
| `md` | 8 | **Buttons, inputs, list rows, menus, segmented control** |
| `lg` | 12 | Cards, panels, toasts |
| `xl` | 16 | Dialogs, sheets, the floating player bar |
| `pill` | 999 | Toggle track, avatar, the live-status pill, the record dot |

Nothing else. The previous code mixed 4/6/8/9/10/12/16 with no rule.

### 4.3 Control sizing

| Token | Height | Use |
|---|---|---|
| `controlSm` | 28 | Inline chip button, keycap row |
| `controlMd` | 32 | Default dense control (sidebar search, device dropdown) |
| `controlLg` | 36 | Button, input, segmented control |
| `controlXl` | 44 | Primary CTA on a hero/empty state |
| `rowMd` | 40 | Session list row |
| `rowLg` | 56 | Session list row with snippet |

Every icon-only control is wrapped to **48x48** (`TouchTarget.minimum`), well
above WCAG 2.2 AA's 24x24 (2.5.8), even when the glyph is 16px.

### 4.4 Icon sizes

`xs 14` · `sm 16` · `md 18` · `lg 20` · `xl 24` · `hero 40`

Paired with the type scale: `sm` inline with `caption`/`body`, `md` leading an
`subheading` row, `lg` for icon-only buttons, `hero` for empty states.

### 4.5 Breakpoints

| Name | Width | Behaviour |
|---|---|---|
| `compact` | < 700 | Sidebar becomes a drawer; two-pane settings becomes a list + push |
| `medium` | 700-1099 | Persistent sidebar at 260; summary panel stacks under the transcript |
| `wide` | ≥ 1100 | Persistent sidebar; summary panel beside the transcript |
| `xwide` | ≥ 1500 | Sidebar may expand to 300; reading measure still capped |

Window: default **1280x800**, minimum **900x600**, size and position remembered
across launches.

---

## 5. Iconography

**One family: Material Symbols Rounded**, reached through Flutter's bundled
`Icons.*_rounded` set (no new dependency, no hand-rolled SVG paths, which §9.E
bans). All of them are declared once in `lib/theme/app_icons.dart` as
`AppIcons.<semantic name>`; `Icons.` is **banned everywhere else** and
`test/design_lint_test.dart` enforces it.

Naming is semantic, not visual: `AppIcons.record`, `AppIcons.stop`,
`AppIcons.bookmark`, `AppIcons.glossary`: so a glyph can be swapped without a
sweep through 40 files.

Consistency rules:

- Rounded variant only. The old code mixed `_outlined`, `_rounded`, filled and
  bare glyphs in the same row.
- Decorative icons are wrapped in `ExcludeSemantics`; meaningful icons get a
  `Semantics` label or sit next to text.
- Every icon-only button has a `Tooltip` **and** a semantics label.
- Stroke/optical weight is uniform because the family is uniform; we never mix a
  filled glyph beside an outlined one at the same level.

---

## 6. Component specs

All live under `lib/widgets/ui/`. Each spec lists the states it must implement.
"Focus" always means `focus-visible`-equivalent: a 2px `focusRing` outline with
a 2px offset, which is drawn on keyboard traversal and not on click.

### 6.1 Buttons: `AppButton`

Variants `primary` · `secondary` · `ghost` · `danger`. Sizes `sm` (28) · `md`
(36) · `lg` (44).

| State | primary | secondary | ghost | danger |
|---|---|---|---|---|
| default | `accent` fill, `onAccent` ink | surface fill, 1px `borderInteractive`, primary ink | transparent, secondary ink | `danger` fill, `onDanger` ink |
| hover | `accentHover` | fill → `n100`/`s2` | fill → `n100`/`s2` | `dangerHover` |
| pressed | `accentPressed` + `scale 0.98` | fill → `n150`/`s3` + `scale 0.98` | fill → `n150`/`s3` + `scale 0.98` | `dangerPressed` + `scale 0.98` |
| focus | 2px `focusRing`, offset 2 | same | same | same |
| disabled | `n150`/`s2` fill, `n400`/`t4` ink, no border change | `n400` ink, `n300` border | `n400` ink | same as primary-disabled |
| loading | 14px ring in current ink replaces the leading icon, label stays, pointer ignored | " | " | " |

Press scale is a `transform`, honours reduce-motion, and the label never wraps:
labels are two words at most (`Mulai Rekam`, `Simpan`, `Coba Lagi`).

### 6.2 Icon button: `AppIconButton`

20px glyph in a 48x48 hit box with a `md`-radius hover/pressed surface tint,
mandatory `tooltip`, optional `badge`. States as §6.1 ghost. A `danger` flavour
tints the glyph only.

### 6.3 Input and search: `AppTextField`, `AppSearchField`

`controlLg`/`controlMd` high, `md` radius, `n100`/`s2` fill, 1px
`borderInteractive`. Label **above** the field, never a placeholder-as-label.
Helper text slot always present in the tree (so focus does not reflow the
layout), error text replaces it and turns the border `danger`. Focus = border
`accent` + 3px `focusRing @ 24%` halo. Search adds a leading `AppIcons.search`,
a clear button that appears only when non-empty, and a right-aligned `KeyHint`.
Placeholders end with `…`.

### 6.4 Segmented control: `AppSegmented`

The mode selector. `controlLg` high, `md` radius, `n100`/`s2` track with 1px
hairline; the selected segment is a `n0`/`s4` **lifted tile** with elevation 2
and primary ink, not an accent fill: borrowed from Linear's pricing tabs and
Raycast's pill tabs, because an accent fill on a three-way selector makes the
accent the loudest thing on the screen. Keyboard: arrows move, Space selects.

### 6.5 Toggle: `AppSwitch`

36x20 `pill` track, 16px thumb, 2px inset. Off: `n200`/`s4` track. On: `accent`
track, `onAccent` thumb. Thumb travel 160 ms `standard`, track colour 120 ms.
Disabled drops to 40% and loses the travel animation. Always wrapped with a
`Semantics(toggled:)`.

### 6.6 Menus and dropdowns: `AppMenu`

Elevation 3, `md` radius, 1px hairline, 4px internal padding, rows at
`controlMd` with `sm` radius and surface-tint hover. Trailing `KeyHint` where a
shortcut exists; leading check column for a checked group. Opens below the
anchor, 120 ms fade + 4px rise.

### 6.7 Chips and pills

- `AppChip`: static metadata (`sm` radius, `n100`/`s2`, `micro` ink).
- `AppFilterChip`: selectable tag; selected = `accentSubtle` fill + `accentText`
  ink + 1px `accent @ 35%`.
- `AppStatusBadge`: semantic; `*Subtle` fill, semantic ink, 6px leading dot or
  glyph, `micro` text. Variants: `success` / `warning` / `danger` / `info` /
  `neutral` / `recording`.
- `DeviceStatusChip`: the mic / system-audio pill: glyph, name, device
  dropdown, `AppSwitch`, and a 3px `LevelMeter` along the bottom edge while
  live. Off state is fully neutral; **no accent tint**, which is what made the
  old screen read as "teal everywhere".

### 6.8 Cards and panels

`AppCard`: `lg` radius, elevation 1 by default, `lg` padding, optional header
row (`subheading` + trailing actions) separated by a hairline.
`AppSectionCard`: the Settings grouping: `heading`, optional `caption`
description, then hairline-separated `AppSettingRow`s. No shadow in either.

### 6.9 List rows: `AppListRow`

`rowMd`/`rowLg`, `md` radius, no Material ink splash (a 120 ms surface tint
instead, because a 5,000-row list with ripples is visibly janky). Selected =
`accentSubtle` fill + a 2px `accent` left rail + `subheading` weight. Hover
reveals the trailing action cluster, which is always also reachable by keyboard
(the row is a focus stop and the actions follow it in traversal order).

### 6.10 Dialogs and sheets

`AppDialog`: elevation 4, `xl` radius, max width 520 (`560` for forms),
`xxl` padding, title `heading`, body `body`, actions right-aligned with the
primary last. Scrim `#0B0D0D @ 40%` light / `60%` dark. Enter: 140 ms fade +
`scale 0.98 → 1`.
`AppSheet`: the post-stop integrity summary and the notulen preview. Bottom
sheet, `xl` top corners, drag handle, 200 ms `emphasized` rise, max height 80%.

### 6.11 Toasts: one notification system

`AppToast` is the only transient notification in the app; `SnackBar` is banned
and `test/design_lint_test.dart` fails on `ScaffoldMessenger`/`SnackBar` in
`lib/`. Bottom-centre, elevation 4, `lg` radius, semantic glyph + message +
optional action, `aria-live`-equivalent (`Semantics(liveRegion: true)`), 200 ms
rise + fade, auto-dismiss 3 s (6 s with an action, never for `danger`), stacks
up to 3 newest-first.

### 6.12 Tabs: `AppTabs`

Underline tabs: `label` ink `n600`→`n800` on select, 2px `accent` underline that
slides 200 ms `standard`. Hairline under the whole strip. Arrow-key navigation,
`Semantics(selected:)`.

### 6.13 Skeleton loaders: `AppSkeleton`

Shape-matched blocks (`sm` radius) in `n100`/`s2` with a 1.4 s shimmer sweep
that **stops entirely** under reduce-motion and becomes a static block. Used for
the session list, the transcript while a session loads, and the summary panel.
Never a bare `CircularProgressIndicator` in the middle of an empty pane.

### 6.14 Empty states: `AppEmptyState`

An icon composition (one `hero` glyph in a 72px `pill` `n100`/`s2` plate with a
second 16px glyph badged bottom-right), a `heading`, a ≤ 20-word `caption`, and
at most one action. Five written variants: first-run, no sessions, no search
results, nothing to export, error.

### 6.15 Progress

`AppLinearProgress`: 4px, `pill`, `n200`/`s4` track, `accent` fill,
indeterminate variant sweeps 1.2 s.
`AppProgressRing`: 16/20/32px, 2px stroke, used inside buttons and next to
queue rows. Determinate wherever a percentage exists (model download, enhance
queue, export).
`LevelMeter`: audio level, 3px, `pill`, 80 ms ease-out follow, `success` for
mic and `info` for system audio. Not a progress bar: no filled background track
beyond the hairline (§9.F).

### 6.16 Badges

`AppCountBadge`: `pill`, `micro` tabular, `accent`/`danger` fill, min 16px
wide, used on the sidebar rail when collapsed.

### 6.17 Keyboard hints: `KeyHint`

Renders a shortcut as keycaps: `xs` radius, `n100`/`s2` fill, 1px hairline,
`mono` ink, 20px high. **Platform-aware**: `⌘`/`⌥`/`⇧`/`⌃` on macOS,
`Ctrl`/`Alt`/`Shift` elsewhere, joined by a thin space, never an em-dash or a
`+` on macOS. Borrowed wholesale from Superhuman and Raycast: a keyboard-first
tool has to show its keys.

---

## 7. Signature screens

### 7.1 Main / recording

**Idle (hero).** Centred column, max 560 wide: icon composition, `title`
"Siap merekam", one `caption` line, three **mode cards** (Rapat Offline / Rapat
Online / Webinar) as a 3-up row of `AppCard`s with a glyph, a name and a
one-line explanation: selected card gets `accentSubtle` + `accent` border, so
the mode decision is made *before* the record button rather than inside a
segmented control. Below them the `controlXl` primary CTA and a `KeyHint`.
Device status sits as two `DeviceStatusChip`s under the CTA.

**Recording.** Header collapses to a single strip: a `recording` dot with a
breathing ring, the elapsed timer in `monoLarge` tabular, the two device chips
with live `LevelMeter`s, the capture-health badge, a bookmark `AppIconButton`,
and the stop button. Live transcript below: speaker avatar (initial on a
speaker-coloured plate), speaker name in the speaker colour, `mono` timestamp,
`bodyLarge` text. A partial segment renders at 70% opacity and transitions to
final with a 160 ms fade; new segments fade+rise 6px, staggered off the index
and **disabled past 200 rows** so the Sprint-2 5,000-segment perf tests stay
green.

**Post-stop.** `AppSheet` with the integrity summary: per-channel seconds, the
warnings, what was saved and where, and one primary action.

### 7.2 Sidebar

260 wide, `s1`/`n0`, hairline right edge. Brand row (mark + wordmark +
settings `AppIconButton`), `Sesi baru` primary button, `AppSearchField` with a
`Ctrl L` `KeyHint`, tag `AppFilterChip`s, then the session list **grouped by
`Hari ini` / `Kemarin` / `7 hari terakhir` / `Lebih lama`** with sticky
`overline` group headers. Each row: title (`subheading`), a one-line snippet of
the first segment (`micro`, `n500`), duration and segment count in tabular
`micro`, status `AppStatusBadge`s (`sedang ditranskrip ulang`, `ada ringkasan`),
and hover/focus actions. Footer actions as `AppListRow`s. Collapses to a **48px
icon rail** with tooltips and count badges; the collapse animates 200 ms
`emphasized` and the state persists.

### 7.3 Transcript player

Document layout: the transcript column is capped at `Measure.reading` and
centred. Sticky player bar at the bottom: elevation 4, `xl` radius, 12px inset
from the edges, containing play/pause, the elapsed/total in `mono` tabular, a
**waveform scrubber** (pre-computed peaks, `n200`/`s4` unplayed, `accent`
played, a 2px `accent` playhead), and a speed `AppMenu`. The active segment gets
an `accentSubtle` fill and a 2px `accent` left rail and auto-scrolls. Summary is
a side card at `wide` and a top card below `wide`, sectioned (`Ringkasan`,
`Keputusan`, `Tindak lanjut`); action items are real checkboxes; provenance
renders as `AppChip`s that seek the audio.

### 7.4 Settings

Two panes like macOS System Settings: a 220 left rail of `AppListRow` categories
with glyphs, and a right pane of `AppSectionCard`s. Each row is label +
`caption` helper + control, with the helper text **dynamic** (it says what the
current value means, not what the setting is). Inline status lives in the row
(`AppStatusBadge`), never in a toast. Below `compact` the rail becomes a list
and selecting a category pushes the pane.

### 7.5 Onboarding / first run

Three steps, skippable, progress as three `pill` segments:
1. `Izin mikrofon & audio sistem`: what is captured, what is not, and the two
   permission actions.
2. `Pilih model`: two `AppCard`s (Cepat / Akurat) with size, speed and a
   determinate download `AppProgressRing`.
3. `Siap rekam`: the three mode cards and the `Ctrl R` hint.

Each step has one icon composition, one `title`, ≤ 25 words of `caption`, and
one primary action. No illustration of a person, no stock art.

### 7.6 Notulen / summary preview

`AppSheet` (or a full pane at `wide`) rendering the generated document in the
app before export: the official heading block, the body sections, the attendee
table, with the reading measure applied and a sticky action bar
(`Ekspor DOCX` / `Ekspor PDF` / `Salin`).

---

## 8. Motion spec

Single source: `lib/theme/app_motion.dart`.

### 8.1 Durations

| Token | ms | Use |
|---|---|---|
| `instant` | 80 | Press-down, level-meter follow |
| `fast` | 120 | Hover, focus ring, colour change, icon swap |
| `base` | 160 | Toggle travel, list-item insert, partial→final text |
| `slow` | 200 | Panel/menu/toast enter, tab underline, sidebar collapse |
| `slowest` | 240 | Dialog and sheet enter, pane transition |

Nothing in the app animates longer than 240 ms except two deliberate loops:
the record button's breathing pulse (1600 ms) and the skeleton shimmer (1400 ms).

### 8.2 Curves

| Token | Cubic | Use |
|---|---|---|
| `standard` | `(0.2, 0, 0, 1)` | Default: anything moving between two states |
| `decelerate` | `(0.05, 0.7, 0.1, 1)` | Entering: menus, toasts, dialogs |
| `accelerate` | `(0.3, 0, 1, 1)` | Exiting |
| `emphasized` | `(0.2, 0, 0, 1)` at `slow`+ | Sidebar collapse, pane transition |

No spring, no overshoot, no bounce: `DESIGN_VARIANCE 3` and a 3-hour tool.

### 8.3 Catalogue

Every animation in the app, with its one-sentence justification:

| Animation | Duration / curve | Justification |
|---|---|---|
| Button hover tint | `fast` / `standard` | Feedback: the thing is interactive |
| Button press scale 0.98 | `instant` / `standard` | Feedback: physical acknowledgement of the click |
| Focus ring | `fast` / `standard` | Feedback: where the keyboard is |
| Toggle thumb travel | `base` / `standard` | State transition: on vs off |
| Segmented tile slide | `slow` / `standard` | State transition: which mode is selected |
| Tab underline slide | `slow` / `standard` | Orientation: which pane you are in |
| Menu / popover enter | `slow` / `decelerate` + 4px rise | Orientation: it came from the anchor |
| Dialog enter | `slowest` / `decelerate` + `scale 0.98→1` | Orientation: it is above the page |
| Sheet rise | `slowest` / `emphasized` | Orientation: it came from the bottom edge |
| Toast rise + fade | `slow` / `decelerate` | Feedback: something finished |
| Transcript segment insert | `base` / `decelerate`, fade + 6px rise, off past 200 rows | Hierarchy: the new line is the one to read |
| Partial → final text | `base` / `standard` opacity 0.7→1 | State transition: the text is settled now |
| Record button breathing | 1600 ms `standard`, scale 1→1.03, `recording` ring 0.35→0 alpha | Feedback: capture is live right now. The single most important state in the app. |
| Live level meter | `instant` / `decelerate` | Feedback: audio is actually arriving |
| Sidebar collapse | `slow` / `emphasized` | State transition: the rail is the same sidebar |
| Skeleton shimmer | 1400 ms linear | Feedback: work is in progress |
| Theme change | `slow` / `standard` | Continuity across a full-screen colour swap |

### 8.4 Reduce motion

`MediaQuery.disableAnimations` (which Flutter maps from the OS "reduce motion"
setting) is read by `AppMotion.of(context)`. When true:

- every duration in §8.1 becomes `Duration.zero`;
- the record button's pulse and the skeleton shimmer **stop** and hold a static
  frame (the recording dot stays fully opaque, the skeleton stays flat);
- list-item inserts, dialog scale and sheet rise become instant;
- the level meter still updates: it is data, not decoration.

`test/reduce_motion_test.dart` asserts no `AnimationController` in the app is
left repeating when `disableAnimations` is on.

---

## 9. Platform adaptation

| | macOS | Windows | Linux |
|---|---|---|---|
| Title bar | Hidden (`TitleBarStyle.hidden`), content runs under the traffic lights; a 28px drag strip is reserved at the top of the sidebar | Custom caption bar with minimise / maximise / close drawn to the Windows metrics, double-click-to-maximise and snap-layouts preserved via `window_manager` | Native GTK CSD, untouched |
| Background | Tuned solid surface (no vibrancy package added: `macos_window_utils` is not in the dependency set and a half-working translucency is worse than a correct opaque surface: recorded as a known gap) | Tuned solid surface (`flutter_acrylic` likewise not added; see known gaps) | Tuned solid surface |
| Modifier | `⌘` | `Ctrl` | `Ctrl` |
| Menu bar | `PlatformMenuBar`: Berkas / Edit / Tampilan / Jendela / Bantuan | none (actions live in the app) | none |
| Icon | `.icns`, all 10 sizes | `.ico`, 16-256 | PNG 16-512 |

Shortcuts are declared once in `lib/theme/app_shortcuts.dart` so `KeyHint`, the
menu bar and the actual `SingleActivator` bindings cannot drift apart.

---

## 10. Copy rules (Bahasa Indonesia)

- **No em-dash.** U+2014 and U+2013 are banned in every user-visible string, including
  ARB files. Use a period, a comma, a colon, or `(…)`. Enforced by
  `test/copy_lint_test.dart`.
- **Ellipsis is `…`**, never `...`. Loading states end with `…`
  (`Menyimpan…`, `Memuat…`).
- **Sentence case** for Indonesian labels and headings; Indonesian does not use
  English title case. Button labels are imperative and ≤ 3 words
  (`Mulai Rekam`, `Simpan`, `Coba Lagi`).
- **Specific labels, not "Lanjutkan".** `Simpan kunci API`, not `Lanjutkan`.
- **Errors say the next step**, not just the problem.
- **Human words, not jargon** (blueprint §4.4): VAD → `Lewati jeda sunyi`;
  Echo Dedupe → `Hapus suara ganda`; Progressive → `Cepat dulu, lalu diperhalus`;
  Auto-detect → `Deteksi otomatis`.
- **Numerals for counts**: `8 segmen`, not `delapan segmen`.
- **One label per intent.** The record action is `Mulai Rekam` everywhere, never
  also `Rekam sekarang` or `Mulai sesi`.
- Numbers, dates and durations go through `intl` / the existing
  `formatDurationId`, never a hand-rolled format.

---

## 11. Synthesis: what was borrowed, and why

Per `shared-skills/image-to-code`, the references were read as *systems* and
re-synthesised. No brand asset, colour, typeface or copy was copied.

| Borrowed | From | Why |
|---|---|---|
| Surface ladder as the only dark-mode depth mechanism; hairline borders carrying every edge; "selected = lift one surface step" | **Linear**, **Raycast** | Both are dense dark-first desktop chrome that stays legible for hours with no shadows. Trareon's dark mode had exactly three greys and a pure-ish `#121212`; a 5-step ladder is what lets a dialog sit over a menu sit over a card without a single shadow. |
| Negative tracking on display sizes; weight 600 (not 700) for headings; 44px minimum control; `scale(0.98)` as the universal press state; two-pane settings | **Apple** | The owner's primary test machine is a MacBook, and these are the four things that make a cross-platform app stop feeling foreign there. |
| Capped reading measure, warm-calm document layout, hairline-and-whitespace grouping instead of boxes for the transcript and notulen | **Notion** | The transcript *is* a document, and the one competitor complaint Granola cannot answer is reading it comfortably. |
| Waveform as the scrubber; level meters as first-class data; audio state shown as a visual, not a label | **ElevenLabs** | It is the only reference in the set whose subject is audio, and its lesson is that the waveform is content, not chrome. |
| Keycap rendering, shortcut hints beside every action they belong to, search-first sidebar | **Superhuman**, **Raycast** | A notulis runs the same five actions hundreds of times; showing the keys is how they graduate from clicking. |

Deliberately **not** borrowed: Linear's lavender accent (we keep teal), Linear's
and Raycast's dark-only stance (public-sector offices run light), ElevenLabs'
pastel atmospheric gradients and weight-300 serif display (a §9.A/§9.B tell in a
productivity tool), Notion's multi-colour sticker palette (we have exactly one
accent plus semantics), Apple's single-shadow-on-photography system (we have no
photography).

---

## 12. Definition of done

- [ ] Every token in §2-§4 exists in `lib/theme/` and nowhere else.
- [ ] `test/design_lint_test.dart`: no colour literal, no `fontSize:` literal,
      no `BorderRadius.circular(n)`, no numeric `EdgeInsets`/`SizedBox` gap, no
      `Icons.`, no `SnackBar`, outside `lib/theme/`.
- [ ] `test/theme_contrast_test.dart`: AA in both themes, including every
      semantic, speaker and on-fill pair.
- [ ] `test/copy_lint_test.dart`: no em-dash, no `...`, in `lib/` or `lib/l10n/`.
- [ ] `test/goldens/`: the component gallery and the five signature screens, in
      light and dark, at 1280x800.
- [ ] Screenshots of the real release build for every signature screen, light
      and dark, at 900x600 / 1280x800 / 1920x1080, committed under
      `docs/screenshots/sprint5/`.
- [ ] A written self-audit against `design-audit`'s eight categories with
      before/after evidence, on Linux and on Windows.
