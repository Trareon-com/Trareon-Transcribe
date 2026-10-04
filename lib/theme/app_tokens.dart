/// Design tokens — the vocabulary every widget spaces, rounds and sizes
/// itself with (blueprint §4.8).
///
/// Before these existed the codebase carried roughly two hundred loose
/// `EdgeInsets.all(14)` / `BorderRadius.circular(9)` / `fontSize: 12.5`
/// literals, no two screens agreed on a rhythm, and there was nothing to
/// point at in review. The scale is deliberately short: if a value is not on
/// it, the answer is almost always the neighbouring token, not a new one.
///
/// Colour tokens live in `app_colors.dart` and are theme-aware; these are
/// theme-independent. `test/theme_tokens_test.dart` fails the build on a new
/// hardcoded `Color(0x…)`/`Colors.*` outside `lib/theme/`.
library;

import 'package:flutter/widgets.dart';

/// The 4-point spacing scale. Names, not numbers, at every call site.
abstract final class Spacing {
  /// 4 — hairline gaps inside a single control (icon ↔ its label).
  static const double xs = 4;

  /// 8 — related elements in a row.
  static const double sm = 8;

  /// 12 — the default gap between controls.
  static const double md = 12;

  /// 16 — screen padding and the gap between groups.
  static const double lg = 16;

  /// 24 — between sections.
  static const double xl = 24;

  /// 32 — around an empty state or a dialog's content block.
  static const double xxl = 32;

  /// Symmetric screen padding, used by every full-page scroll view.
  static const EdgeInsets screen = EdgeInsets.all(lg);

  /// Padding inside a card or a settings tile.
  static const EdgeInsets card =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// Vertical gap between stacked form fields.
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
}

/// Corner radii. Four steps, so "slightly rounder than that one" is not a
/// decision anybody has to make again.
abstract final class Radii {
  /// 6 — chips, badges, inline pills.
  static const double sm = 6;

  /// 10 — buttons, fields, list rows.
  static const double md = 10;

  /// 16 — cards, dialogs, panels.
  static const double lg = 16;

  /// Fully rounded. Large enough to round any control this app draws.
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Type scale, in logical pixels.
///
/// Sizes only — colour and weight come from the theme and the widget. Values
/// are the ones the existing screens converged on, rounded onto a scale;
/// everything must stay legible at 1.5× text scaling (see
/// `test/text_scaling_test.dart`).
abstract final class FontSizes {
  /// 11 — dense metadata: timestamps, "N segmen", helper counters.
  static const double micro = 11;

  /// 12 — captions and helper text under a control.
  static const double caption = 12;

  /// 13 — the default body size in this app's dense desktop layout.
  static const double body = 13;

  /// 14 — list row titles, button labels.
  static const double bodyLarge = 14;

  /// 16 — section and dialog titles.
  static const double title = 16;

  /// 20 — screen headlines.
  static const double headline = 20;

  /// 28 — the one number a screen exists to show (empty-state hero, stat).
  static const double display = 28;
}

/// Icon sizes, paired with the type scale.
abstract final class IconSizes {
  /// 16 — inline with caption/body text.
  static const double sm = 16;

  /// 18 — the default for a leading or trailing icon in a row.
  static const double md = 18;

  /// 24 — icon-only buttons.
  static const double lg = 24;

  /// 48 — empty-state illustration.
  static const double hero = 48;
}

/// Minimum interactive sizes.
abstract final class TouchTarget {
  /// 48 logical px — the WCAG 2.2 AA / Material minimum. Every icon-only
  /// button in the app is wrapped to at least this, which is why an
  /// `IconButton` here carries an explicit `constraints`/`SizedBox` rather
  /// than relying on Material's default 40 px splash box.
  static const double minimum = 48;

  /// A square box of [minimum] on a side.
  static const Size minimumSize = Size(minimum, minimum);

  static const BoxConstraints constraints = BoxConstraints(
    minWidth: minimum,
    minHeight: minimum,
  );
}
