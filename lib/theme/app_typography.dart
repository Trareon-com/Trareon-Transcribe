/// The type scale. `docs/DESIGN-SYSTEM.md` §3 is the spec.
///
/// Two bundled faces: Inter for everything, JetBrains Mono for figures that
/// have to line up (timestamps, the elapsed timer, keycaps). Both ship under
/// the SIL OFL from `assets/fonts/`.
///
/// Bundling rather than using the platform face is deliberate: the goldens in
/// `test/goldens/` are only deterministic with a bundled font, the owner is
/// comparing macOS and Windows side by side and three platform faces would be
/// three different type rhythms, and `Typography.blackMountainView` is the
/// single most recognisable "default Flutter app" tell.
///
/// Every role here already carries colour-free weight, size, line height,
/// tracking and numeric features. A widget applies colour with `.c(…)` and
/// nothing else.
library;

import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Font family names, as declared in `pubspec.yaml`.
abstract final class AppFonts {
  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';

  /// Behind Inter for any glyph it lacks. Inter covers Latin and therefore all
  /// of Bahasa Indonesia; this is for stray CJK or symbol glyphs in a session
  /// title pasted from elsewhere.
  static const List<String> sansFallback = ['Inter', 'Roboto', 'sans-serif'];

  /// Tabular (monospaced) digits. On for every numeric role so a running clock
  /// does not wobble as the digits change width.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Lining figures plus tabular, for figures inside running text.
  static const List<FontFeature> tabularLining = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];
}

/// Named type roles. Use `AppText.body.c(colors.text)`, never a bare
/// `TextStyle(fontSize: …)`.
abstract final class AppText {
  /// 28/600, tracking -0.5. The one number or hero line a screen exists for.
  static const TextStyle display = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.display,
    fontWeight: FontWeight.w600,
    height: 1.14,
    letterSpacing: -0.5,
    fontFeatures: AppFonts.tabularLining,
  );

  /// 20/600, tracking -0.3. Screen headline.
  static const TextStyle title = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.headline,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.3,
  );

  /// 16/600, tracking -0.2. Section and dialog title.
  static const TextStyle heading = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.title,
    fontWeight: FontWeight.w600,
    height: 1.30,
    letterSpacing: -0.2,
  );

  /// 14/600. Card title, list row title.
  static const TextStyle subheading = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.bodyLarge,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.1,
  );

  /// 13/400. The default body size in this dense desktop layout.
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.body,
    fontWeight: FontWeight.w400,
    height: 1.50,
  );

  /// 13/500. Body with emphasis, inside running text.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.body,
    fontWeight: FontWeight.w500,
    height: 1.50,
  );

  /// 14/400, line height 1.55. Transcript and notulen reading text, which is
  /// the only prose in the app long enough to need the extra leading.
  static const TextStyle reading = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.bodyLarge,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  /// 13/500. Button and control labels.
  static const TextStyle label = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.body,
    fontWeight: FontWeight.w500,
    height: 1.20,
  );

  /// 12/400. Helper text under a control.
  static const TextStyle caption = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.caption,
    fontWeight: FontWeight.w400,
    height: 1.40,
  );

  /// 12/500. A caption that is a label.
  static const TextStyle captionStrong = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.caption,
    fontWeight: FontWeight.w500,
    height: 1.40,
  );

  /// 11/400, tracking +0.1, tabular. Dense metadata.
  static const TextStyle micro = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.micro,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: 0.1,
    fontFeatures: AppFonts.tabular,
  );

  /// 10/600, tracking +0.8, upper case at the call site. Control-group label
  /// only (`SESI`, `PERANGKAT`), never a section eyebrow above a headline,
  /// and at most one per visual group.
  static const TextStyle overline = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.sansFallback,
    fontSize: FontSizes.overline,
    fontWeight: FontWeight.w600,
    height: 1.20,
    letterSpacing: 0.8,
  );

  /// 12/400 mono, tabular. Transcript timestamps, keycaps.
  static const TextStyle mono = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: FontSizes.caption,
    fontWeight: FontWeight.w400,
    height: 1.40,
    fontFeatures: AppFonts.tabular,
  );

  /// 11/400 mono. The smallest figure in the app.
  static const TextStyle monoMicro = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: FontSizes.micro,
    fontWeight: FontWeight.w400,
    height: 1.35,
    fontFeatures: AppFonts.tabular,
  );

  /// 24/500 mono, tabular. The recording timer: the one figure on screen the
  /// user watches continuously, so it must not reflow once a second.
  static const TextStyle monoTimer = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: FontSizes.timer,
    fontWeight: FontWeight.w500,
    height: 1.10,
    fontFeatures: AppFonts.tabular,
  );

  /// Every role, keyed by name. Used by the design-system gallery golden and
  /// by `test/design_lint_test.dart` to prove the scale is monotonic.
  static const Map<String, TextStyle> roles = {
    'display': display,
    'title': title,
    'heading': heading,
    'subheading': subheading,
    'reading': reading,
    'bodyLarge': reading,
    'body': body,
    'bodyStrong': bodyStrong,
    'label': label,
    'caption': caption,
    'captionStrong': captionStrong,
    'micro': micro,
    'overline': overline,
    'mono': mono,
    'monoMicro': monoMicro,
    'monoTimer': monoTimer,
  };
}

/// `AppText.body.c(colors.text)` reads better at 600 call sites than
/// `AppText.body.copyWith(color: colors.text)`.
extension AppTextColor on TextStyle {
  /// This role in [color].
  TextStyle c(Color color) => copyWith(color: color);

  /// This role in [color], at [weight]. Only for the handful of places where
  /// a row's selected state bumps the weight.
  TextStyle cw(Color color, FontWeight weight) =>
      copyWith(color: color, fontWeight: weight);
}
