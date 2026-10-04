import 'package:flutter/material.dart';

/// Color tokens for Trareon Transcribe — teal-green primary palette
/// matching the redesign mockup. Light/dark variants included.
class AppColors {
  const AppColors._();

  // Primary palette — teal-green accent
  static const Color primary = Color(0xFF00796B);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF004D40);

  // Speaker accent colors
  static const Color micAccent = Color(0xFF00796B);
  static const Color spkAccent = Color(0xFF00796B);

  // Status colors
  static const Color statusActive = Color(0xFF2E7D32);
  static const Color statusError = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFF3B30);
  static const Color recordingDot = Color(0xFFFF3B30);

  // Light theme
  static const LightColors light = LightColors();
  // Dark theme
  static const DarkColors dark = DarkColors();
}

abstract class AppColorSet extends ThemeExtension<AppColorSet> {
  const AppColorSet();

  @override
  AppColorSet copyWith() => this;

  @override
  AppColorSet lerp(ThemeExtension<AppColorSet>? other, double t) {
    if (other is! AppColorSet) return this;
    return t < 0.5 ? this : other;
  }

  Color get background;
  Color get surface;
  Color get surfaceElevated;
  Color get primary;
  Color get onPrimary;
  Color get text;
  Color get textSecondary;
  Color get textTertiary;
  Color get divider;
  Color get border;
  Color get chipBackground;
  Color get chipSelectedBackground;
  Color get headerBackground;
  Color get transcriptBackground;
  Color get primaryDark;

  /// Accent used for the secondary action colour in [ColorScheme]. Paired
  /// with [onSecondary], which must reach WCAG AA against it — the theme
  /// previously hardcoded `Colors.white` here, which is only legible over
  /// the light-mode accent.
  Color get secondary;
  Color get onSecondary;

  /// Error/destructive accent. Theme-aware because the single hardcoded
  /// `AppColors.warning` (#FF3B30) reaches only 3.55:1 on a light surface —
  /// below AA for the error messages it is used for.
  Color get error;
  Color get onError;

  /// "This worked" / "capture confirmed" accent. Theme-aware for the same
  /// reason as [error]: the fixed `AppColors.statusActive` (#2E7D32) is
  /// unreadable on the dark surface it was also being used on.
  Color get success;
  Color get onSuccess;

  /// "Needs attention, but nothing is broken" accent — a quiet channel, a
  /// model that is not the accurate one, a glossary over its prompt budget.
  /// Distinct from [error], which means something failed.
  Color get warning;
  Color get onWarning;

  /// Drop-shadow colour. Pure black at 10 % is almost invisible over a dark
  /// surface, so this is theme-aware like everything else.
  Color get shadow;

  /// The recording indicator dot. Its own role rather than [error]: a
  /// recording in progress is not a problem, and the two must not be
  /// confusable at a glance.
  Color get recording;

  /// Per-speaker accents, used as *text* colour for the speaker name on
  /// every transcript row — the most repeated text in the app. Theme-aware
  /// because one fixed palette cannot be legible on both #FFFFFF and
  /// #1E1E1E: the previous shared palette failed AA on 6 of 8 entries in
  /// light mode. Every entry is gated by `test/speaker_color_test.dart`.
  List<Color> get speakerPalette;
}

class LightColors extends AppColorSet {
  const LightColors();
  @override
  Color get background => const Color(0xFFF5F5F5);
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get surfaceElevated => const Color(0xFFFFFFFF);
  @override
  Color get primary => const Color(0xFF00796B);
  @override
  Color get primaryDark => const Color(0xFF004D40);
  @override
  Color get onPrimary => const Color(0xFFFFFFFF);
  @override
  Color get text => const Color(0xFF333333);
  @override
  Color get textSecondary => const Color(0xFF666666);
  // #757575 reached only 4.23:1 on the #F5F5F5 app background — below AA for
  // the hint and metadata text it is used for.
  @override
  Color get textTertiary => const Color(0xFF6B6B6B);
  @override
  Color get divider => const Color(0xFFE0E0E0);
  @override
  Color get border => const Color(0xFFE0E0E0);
  @override
  Color get chipBackground => const Color(0xFFF0F0F0);
  @override
  Color get chipSelectedBackground => const Color(0xFF00796B);
  @override
  Color get headerBackground => const Color(0xFFFFFFFF);
  @override
  Color get transcriptBackground => const Color(0xFFFFFFFF);
  @override
  Color get secondary => const Color(0xFF00796B);
  @override
  Color get onSecondary => const Color(0xFFFFFFFF);
  @override
  Color get error => const Color(0xFFC62828);
  @override
  Color get onError => const Color(0xFFFFFFFF);
  @override
  Color get success => const Color(0xFF1B5E20);
  @override
  Color get onSuccess => const Color(0xFFFFFFFF);
  @override
  Color get warning => const Color(0xFF8A4B00);
  @override
  Color get onWarning => const Color(0xFFFFFFFF);
  @override
  Color get recording => const Color(0xFFC62828);
  @override
  Color get shadow => const Color(0x1A000000);
  @override
  List<Color> get speakerPalette => const [
    Color(0xFF00695C), // teal
    Color(0xFFA03400), // deep orange
    Color(0xFF1565C0), // blue
    Color(0xFF6A1B9A), // purple
    Color(0xFF1B5E20), // green
    Color(0xFFB71C1C), // red
    Color(0xFFAD1457), // pink
    Color(0xFF4527A0), // indigo
  ];
}

class DarkColors extends AppColorSet {
  const DarkColors();
  @override
  Color get background => const Color(0xFF121212);
  @override
  Color get surface => const Color(0xFF1E1E1E);
  @override
  Color get surfaceElevated => const Color(0xFF2C2C2C);
  @override
  Color get primary => const Color(0xFF4DB6AC);
  @override
  Color get primaryDark => const Color(0xFF00796B);
  @override
  Color get onPrimary => const Color(0xFF003D33);
  @override
  Color get text => const Color(0xFFE0E0E0);
  @override
  Color get textSecondary => const Color(0xFFB0B0B0);
  @override
  Color get textTertiary => const Color(0xFF9E9E9E);
  @override
  Color get divider => const Color(0xFF333333);
  @override
  Color get border => const Color(0xFF333333);
  @override
  Color get chipBackground => const Color(0xFF2C2C2C);
  @override
  Color get chipSelectedBackground => const Color(0xFF4DB6AC);
  @override
  Color get headerBackground => const Color(0xFF1E1E1E);
  @override
  Color get transcriptBackground => const Color(0xFF1E1E1E);
  @override
  Color get secondary => const Color(0xFF4DB6AC);
  @override
  Color get onSecondary => const Color(0xFF003D33);
  @override
  Color get error => const Color(0xFFFF8A80);
  @override
  Color get onError => const Color(0xFF690005);
  @override
  Color get success => const Color(0xFF81C784);
  @override
  Color get onSuccess => const Color(0xFF0B2E0D);
  @override
  Color get warning => const Color(0xFFFFCC80);
  @override
  Color get onWarning => const Color(0xFF3B2200);
  @override
  Color get recording => const Color(0xFFFF8A80);
  @override
  Color get shadow => const Color(0x66000000);
  @override
  List<Color> get speakerPalette => const [
    Color(0xFF4DB6AC), // teal
    Color(0xFFFFAB91), // deep orange
    Color(0xFF90CAF9), // blue
    Color(0xFFCE93D8), // purple
    Color(0xFF81C784), // green
    Color(0xFFEF9A9A), // red
    Color(0xFFF48FB1), // pink
    Color(0xFFB39DDB), // indigo
  ];
}
