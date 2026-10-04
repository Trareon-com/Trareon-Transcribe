/// Design tokens: the vocabulary every widget spaces, rounds and sizes
/// itself with.
///
/// `docs/DESIGN-SYSTEM.md` §4 is the spec; this file is its implementation.
/// Colour tokens live in `app_colors.dart` (theme-aware), type roles in
/// `app_typography.dart`, durations and curves in `app_motion.dart`. These are
/// theme-independent numbers.
///
/// The scale is deliberately short: if a value is not on it, the answer is
/// almost always the neighbouring token, not a new one.
/// `test/design_lint_test.dart` fails the build on a loose `fontSize:`,
/// `BorderRadius.circular(n)`, numeric `EdgeInsets` or `SizedBox` gap outside
/// `lib/theme/`.
library;

import 'package:flutter/widgets.dart';

/// The 4-point spacing scale. Names, not numbers, at every call site.
abstract final class Spacing {
  /// 4: hairline gaps inside a single control (icon to its label).
  static const double xs = 4;

  /// 8: related elements in a row.
  static const double sm = 8;

  /// 12: the default gap between controls.
  static const double md = 12;

  /// 16: screen padding and the gap between groups.
  static const double lg = 16;

  /// 24: between sections.
  static const double xl = 24;

  /// 32: around an empty state or a dialog's content block.
  static const double xxl = 32;

  /// 48: the largest rhythm this app uses. A 1280x800 tool has no business
  /// with marketing-page section gaps.
  static const double xxxl = 48;

  /// Symmetric screen padding, used by every full-page scroll view.
  static const EdgeInsets screen = EdgeInsets.all(lg);

  /// Padding inside a card or a settings tile.
  static const EdgeInsets card = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  /// Padding inside a dense list row.
  static const EdgeInsets row = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  /// Vertical gaps between stacked elements.
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);

  /// Horizontal gaps, for rows.
  static const SizedBox hXs = SizedBox(width: xs);
  static const SizedBox hSm = SizedBox(width: sm);
  static const SizedBox hMd = SizedBox(width: md);
  static const SizedBox hLg = SizedBox(width: lg);
  static const SizedBox hXl = SizedBox(width: xl);
}

/// Corner radii. A documented mixed system (design-taste §4.4): each step owns
/// a class of component and nothing borrows another's.
abstract final class Radii {
  /// 4: keycaps, level-meter track, inline tags.
  static const double xs = 4;

  /// 6: chips, badges, small inline pills.
  static const double sm = 6;

  /// 8: buttons, inputs, list rows, menus, segmented control.
  static const double md = 8;

  /// 12: cards, panels, toasts.
  static const double lg = 12;

  /// 16: dialogs, sheets, the floating player bar.
  static const double xl = 16;

  /// Fully rounded: toggle track, avatar, status pill, record dot.
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Top-only, for bottom sheets.
  static const BorderRadius xlTop = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Type sizes, in logical pixels. The roles that combine these with weight,
/// line height and tracking live in `app_typography.dart`; this is the raw
/// ladder, kept here so the lint test has a single place to point at.
abstract final class FontSizes {
  /// 10: group label (`SESI`, `PERANGKAT`).
  static const double overline = 10;

  /// 11: dense metadata (timestamps, "N segmen", helper counters).
  static const double micro = 11;

  /// 12: captions, helper text, mono timestamps.
  static const double caption = 12;

  /// 13: the default body size in this app's dense desktop layout, and the
  /// size of every control label.
  static const double body = 13;

  /// 14: transcript reading text, list row titles.
  static const double bodyLarge = 14;

  /// 16: section and dialog titles.
  static const double title = 16;

  /// 20: screen headlines.
  static const double headline = 20;

  /// 24: the recording timer.
  static const double timer = 24;

  /// 28: the one number a screen exists to show (empty-state hero, stat).
  static const double display = 28;
}

/// Icon sizes, paired with the type scale.
abstract final class IconSizes {
  /// 14: inline with `micro`.
  static const double xs = 14;

  /// 16: inline with `caption`/`body`.
  static const double sm = 16;

  /// 18: the default for a leading or trailing icon in a row.
  static const double md = 18;

  /// 20: icon-only buttons.
  static const double lg = 20;

  /// 24: the record glyph, player transport.
  static const double xl = 24;

  /// 40: empty-state composition.
  static const double hero = 40;
}

/// Control heights. Every interactive surface in the app is one of these.
abstract final class ControlSizes {
  /// 28: inline chip button, keycap row.
  static const double sm = 28;

  /// 32: dense control (sidebar search, device dropdown, menu row).
  static const double md = 32;

  /// 36: button, input, segmented control.
  static const double lg = 36;

  /// 44: primary CTA on a hero or empty state.
  static const double xl = 44;

  /// 40: session list row without a snippet.
  static const double rowMd = 40;

  /// 56: session list row with a snippet.
  static const double rowLg = 56;

  /// 20: toggle track height.
  static const double switchHeight = 20;

  /// 36: toggle track width.
  static const double switchWidth = 36;
}

/// Stroke and hairline widths. A hairline is 1 logical pixel, not 0.5: at the
/// 1.0 and 2.0 device pixel ratios these three platforms actually run,
/// `0.5` renders as an inconsistent grey smear rather than a line.
abstract final class Strokes {
  static const double hairline = 1;
  static const double focusRing = 2;
  static const double focusRingOffset = 2;
  static const double selectionRail = 2;
  static const double progress = 4;
  static const double level = 3;
  static const double ring = 2;
}

/// Minimum interactive sizes.
abstract final class TouchTarget {
  /// 48 logical px, the Material minimum and twice WCAG 2.2 AA's 24x24
  /// (SC 2.5.8). Every icon-only button in the app is wrapped to at least
  /// this, even when the glyph inside it is 16 px.
  static const double minimum = 48;

  static const Size minimumSize = Size(minimum, minimum);

  static const BoxConstraints constraints = BoxConstraints(
    minWidth: minimum,
    minHeight: minimum,
  );
}

/// Layout measures: the widths content is allowed to occupy.
abstract final class Measure {
  /// 680: roughly 70 characters at `bodyLarge`. The transcript and the
  /// notulen preview are capped here and centred, so a 1920 px window does
  /// not produce unreadable 200-character lines.
  static const double reading = 680;

  /// 960: [reading] plus the transcript's speaker column, its row actions and
  /// the padding either side. The width the transcript column is capped at,
  /// so the prose itself lands near [reading].
  static const double transcriptColumn = 960;

  /// 560: the widest a hero column (empty state, onboarding step) gets.
  static const double hero = 560;

  /// 520: default dialog width.
  static const double dialog = 520;

  /// 560: dialog width when it contains a form.
  static const double dialogForm = 560;

  /// 480: the widest a toast gets.
  static const double toast = 480;

  /// 260: the permanent sidebar.
  static const double sidebar = 260;

  /// 48: the sidebar collapsed to an icon rail.
  static const double sidebarRail = 48;

  /// 220: the Settings category rail.
  static const double settingsRail = 220;

  /// 360: the summary side panel in the transcript player.
  static const double summaryPanel = 360;
}

/// Window-width breakpoints. Named so a `LayoutBuilder` reads as a decision
/// rather than a magic number.
abstract final class Breakpoints {
  /// Below this the sidebar becomes a drawer and two-pane layouts collapse.
  static const double compact = 700;

  /// At and above this a side-by-side summary panel fits.
  static const double wide = 1100;

  /// At and above this the sidebar may grow.
  static const double xwide = 1500;
}

/// Window geometry. macOS enforces a minimum from the app bundle; Linux and
/// Windows get theirs from `window_manager` at startup.
abstract final class WindowSizes {
  /// The size a first launch opens at.
  static const Size defaultSize = Size(1280, 800);

  /// The smallest window every layout in the app is designed to survive.
  static const Size minimum = Size(900, 600);
}
