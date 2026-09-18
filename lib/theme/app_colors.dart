import 'package:flutter/material.dart';

/// Color tokens for Trareon Transcribe — teal-green brand with premium,
/// desktop-tuned light/dark palettes. Dark surfaces are teal-tinted (not
/// neutral Material gray) and borders are white-alpha hairlines; the bright
/// teal accent is reserved for the record button, selection and focus.
class AppColors {
  const AppColors._();

  // Brand teal
  static const Color primary = Color(0xFF00796B);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF004D40);

  // Source accents (mic/speaker) — teal; differentiated in the UI by label.
  static const Color micAccent = Color(0xFF00796B);
  static const Color spkAccent = Color(0xFF00796B);

  // Semantic / status. warning is now AMBER (it used to be #FF3B30 red, which
  // collided with the recording dot); error stays red; recordingDot is its
  // own red token.
  static const Color statusActive = Color(0xFF2FA36B);
  static const Color statusError = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF5A623);
  static const Color recordingDot = Color(0xFFFF453A);

  static const LightColors light = LightColors();
  static const DarkColors dark = DarkColors();
}

abstract class AppColorSet extends ThemeExtension<AppColorSet> {
  const AppColorSet();

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

  @override
  AppColorSet copyWith() => this;

  @override
  AppColorSet lerp(ThemeExtension<AppColorSet>? other, double t) {
    if (other is! AppColorSet) return this;
    // MaterialApp wraps the tree in AnimatedTheme, so a real per-color lerp
    // makes the light/dark toggle cross-fade instead of snapping (the old
    // `t < 0.5 ? this : other` hard cut).
    return _LerpColors(this, other, t);
  }
}

class _LerpColors extends AppColorSet {
  final AppColorSet a;
  final AppColorSet b;
  final double t;
  const _LerpColors(this.a, this.b, this.t);

  Color _l(Color x, Color y) => Color.lerp(x, y, t)!;

  @override
  Color get background => _l(a.background, b.background);
  @override
  Color get surface => _l(a.surface, b.surface);
  @override
  Color get surfaceElevated => _l(a.surfaceElevated, b.surfaceElevated);
  @override
  Color get primary => _l(a.primary, b.primary);
  @override
  Color get onPrimary => _l(a.onPrimary, b.onPrimary);
  @override
  Color get text => _l(a.text, b.text);
  @override
  Color get textSecondary => _l(a.textSecondary, b.textSecondary);
  @override
  Color get textTertiary => _l(a.textTertiary, b.textTertiary);
  @override
  Color get divider => _l(a.divider, b.divider);
  @override
  Color get border => _l(a.border, b.border);
  @override
  Color get chipBackground => _l(a.chipBackground, b.chipBackground);
  @override
  Color get chipSelectedBackground =>
      _l(a.chipSelectedBackground, b.chipSelectedBackground);
  @override
  Color get headerBackground => _l(a.headerBackground, b.headerBackground);
  @override
  Color get transcriptBackground =>
      _l(a.transcriptBackground, b.transcriptBackground);
  @override
  Color get primaryDark => _l(a.primaryDark, b.primaryDark);
}

class LightColors extends AppColorSet {
  const LightColors();
  @override
  Color get background => const Color(0xFFF4F6F5);
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get surfaceElevated => const Color(0xFFFFFFFF);
  @override
  Color get primary => const Color(0xFF00796B);
  @override
  Color get primaryDark => const Color(0xFF05564C);
  @override
  Color get onPrimary => const Color(0xFFFFFFFF);
  @override
  Color get text => const Color(0xFF11201C);
  @override
  Color get textSecondary => const Color(0xFF51605C);
  @override
  Color get textTertiary => const Color(0xFF83918D);
  @override
  Color get divider => const Color(0xFFE4E9E7);
  @override
  Color get border => const Color(0xFFDCE3E0);
  @override
  Color get chipBackground => const Color(0xFFECF0EF);
  @override
  Color get chipSelectedBackground => const Color(0xFF00796B);
  @override
  Color get headerBackground => const Color(0xFFFFFFFF);
  @override
  Color get transcriptBackground => const Color(0xFFF8FAF9);
}

class DarkColors extends AppColorSet {
  const DarkColors();
  @override
  Color get background => const Color(0xFF0C100F);
  @override
  Color get surface => const Color(0xFF141917);
  @override
  Color get surfaceElevated => const Color(0xFF1D2320);
  @override
  Color get primary => const Color(0xFF2FB6A2);
  @override
  Color get primaryDark => const Color(0xFF0F8375);
  @override
  Color get onPrimary => const Color(0xFF042420);
  @override
  Color get text => const Color(0xFFE9EDEB);
  @override
  Color get textSecondary => const Color(0xFFA3ADAA);
  @override
  Color get textTertiary => const Color(0xFF6D7674);
  @override
  Color get divider => const Color(0x14FFFFFF);
  @override
  Color get border => const Color(0x26FFFFFF);
  @override
  Color get chipBackground => const Color(0xFF1D2320);
  @override
  Color get chipSelectedBackground => const Color(0xFF2FB6A2);
  @override
  Color get headerBackground => const Color(0xFF141917);
  @override
  Color get transcriptBackground => const Color(0xFF0F1413);
}
