/// Colour tokens. `docs/DESIGN-SYSTEM.md` §2 is the spec.
///
/// Light and dark are two separately tuned ramps, not one ramp inverted. Dark
/// mode carries depth with a five-step surface ladder and hairline borders and
/// has no shadow above elevation 1, which is the one structural idea borrowed
/// from Linear and Raycast (see DESIGN-SYSTEM.md §11).
///
/// Every pair that carries text is measured by `test/theme_contrast_test.dart`
/// against WCAG 2.2 AA, and `test/design_lint_test.dart` fails the build on a
/// `Color(0x…)` or `Colors.*` literal anywhere outside `lib/theme/`.
library;

import 'package:flutter/material.dart';

/// Raw neutral and accent ramps. Widgets never touch these: they take a
/// semantic role off [AppColorSet]. They are public only so the design-system
/// gallery and the golden tests can render the ramps themselves.
abstract final class TrareonRamp {
  // ── neutral, light: low-chroma cool grey with a trace of the brand hue ──
  static const Color n0 = Color(0xFFFFFFFF);
  static const Color n50 = Color(0xFFF7F8F8);
  static const Color n100 = Color(0xFFEFF1F1);
  static const Color n150 = Color(0xFFE5E8E8);
  static const Color n200 = Color(0xFFD9DDDD);
  static const Color n300 = Color(0xFFC0C6C6);
  static const Color n400 = Color(0xFF99A1A1);
  static const Color n500 = Color(0xFF636B6B);
  static const Color n600 = Color(0xFF545C5C);
  static const Color n700 = Color(0xFF3B4242);
  static const Color n800 = Color(0xFF262B2B);
  static const Color n900 = Color(0xFF151818);
  static const Color n950 = Color(0xFF0B0D0D);

  // ── neutral, dark: a surface ladder, never pure black ──────────────────
  static const Color dCanvas = Color(0xFF0C0E0F);
  static const Color dS1 = Color(0xFF131617);
  static const Color dS2 = Color(0xFF181C1D);
  static const Color dS3 = Color(0xFF1E2223);
  static const Color dS4 = Color(0xFF252A2B);
  static const Color dHairline = Color(0xFF272C2D);
  static const Color dHairlineStrong = Color(0xFF333A3B);
  static const Color dT1 = Color(0xFFECEFEF);
  static const Color dT2 = Color(0xFFB4BBBC);
  static const Color dT3 = Color(0xFF8C9496);
  static const Color dT4 = Color(0xFF6A7273);

  // ── accent: Trareon teal, hue ~172, ten steps ─────────────────────────
  static const Color teal50 = Color(0xFFECF7F4);
  static const Color teal100 = Color(0xFFCFEBE5);
  static const Color teal200 = Color(0xFFA6D9CF);
  static const Color teal300 = Color(0xFF74C2B4);
  static const Color teal400 = Color(0xFF42A595);
  static const Color teal500 = Color(0xFF1E8A79);
  static const Color teal600 = Color(0xFF146F62);
  static const Color teal700 = Color(0xFF0F584E);
  static const Color teal800 = Color(0xFF0B423B);
  static const Color teal900 = Color(0xFF072C27);

  /// The ten accent steps in order, for the gallery.
  static const List<Color> accentScale = [
    teal50,
    teal100,
    teal200,
    teal300,
    teal400,
    teal500,
    teal600,
    teal700,
    teal800,
    teal900,
  ];

  /// The thirteen light neutral steps in order, for the gallery.
  static const List<Color> lightNeutralScale = [
    n0,
    n50,
    n100,
    n150,
    n200,
    n300,
    n400,
    n500,
    n600,
    n700,
    n800,
    n900,
    n950,
  ];

  /// The dark surface ladder plus its text ramp, for the gallery.
  static const List<Color> darkNeutralScale = [
    dCanvas,
    dS1,
    dS2,
    dS3,
    dS4,
    dHairline,
    dHairlineStrong,
    dT4,
    dT3,
    dT2,
    dT1,
  ];
}

/// Entry point: `AppColors.light` / `AppColors.dark`, installed on
/// [ThemeData.extensions] by `AppTheme`.
abstract final class AppColors {
  static const AppColorSet light = AppColorSet(
    brightness: Brightness.light,
    // surfaces
    background: TrareonRamp.n50,
    surface: TrareonRamp.n0,
    surfaceSunken: TrareonRamp.n100,
    surfacePressed: TrareonRamp.n150,
    surfaceRaised: TrareonRamp.n0,
    surfaceOverlay: TrareonRamp.n0,
    surfaceModal: TrareonRamp.n0,
    // text
    text: TrareonRamp.n800,
    textStrong: TrareonRamp.n900,
    textSecondary: TrareonRamp.n600,
    textTertiary: TrareonRamp.n500,
    textDisabled: TrareonRamp.n400,
    icon: TrareonRamp.n700,
    // lines
    hairline: Color(0x1A262B2B),
    hairlineStrong: Color(0x29262B2B),
    borderInteractive: Color(0x2E262B2B),
    borderDisabled: TrareonRamp.n300,
    // accent
    primary: TrareonRamp.teal600,
    onPrimary: TrareonRamp.n0,
    primaryHover: TrareonRamp.teal500,
    primaryPressed: TrareonRamp.teal700,
    primaryText: TrareonRamp.teal600,
    primarySubtle: TrareonRamp.teal50,
    primaryDark: TrareonRamp.teal800,
    focusRing: TrareonRamp.teal500,
    // semantics
    success: Color(0xFF15713D),
    onSuccess: TrareonRamp.n0,
    successSubtle: Color(0x1A15713D),
    warning: Color(0xFF8A4B00),
    onWarning: TrareonRamp.n0,
    warningSubtle: Color(0x1A8A4B00),
    error: Color(0xFFB3261E),
    onError: TrareonRamp.n0,
    errorSubtle: Color(0x1AB3261E),
    errorHover: Color(0xFFC53028),
    errorPressed: Color(0xFF8F1E18),
    info: Color(0xFF0B5CAD),
    onInfo: TrareonRamp.n0,
    infoSubtle: Color(0x1A0B5CAD),
    recording: Color(0xFFBF3B21),
    onRecording: TrareonRamp.n0,
    recordingSubtle: Color(0x1ABF3B21),
    // overlays
    hoverOverlay: Color(0x0F262B2B),
    pressedOverlay: Color(0x1F262B2B),
    scrim: Color(0x660B0D0D),
    shadow: Color(0x1A151818),
    // speakers
    speakerPalette: [
      Color(0xFF0F6B5C), // teal
      Color(0xFF9A3B10), // burnt orange
      Color(0xFF1156A8), // blue
      Color(0xFF6B1F93), // purple
      Color(0xFF1D6322), // green
      Color(0xFFA52121), // red
      Color(0xFFA01256), // magenta
      Color(0xFF3F2A9E), // indigo
    ],
  );

  static const AppColorSet dark = AppColorSet(
    brightness: Brightness.dark,
    // surfaces: the ladder. `surface` is one step above the canvas, so a
    // sidebar and a card both sit on s1 and a dialog can rise three steps
    // above them without a single shadow.
    background: TrareonRamp.dCanvas,
    surface: TrareonRamp.dS1,
    surfaceSunken: TrareonRamp.dS2,
    surfacePressed: TrareonRamp.dS3,
    surfaceRaised: TrareonRamp.dS2,
    surfaceOverlay: TrareonRamp.dS3,
    surfaceModal: TrareonRamp.dS4,
    // text
    text: TrareonRamp.dT1,
    textStrong: TrareonRamp.dT1,
    textSecondary: TrareonRamp.dT2,
    textTertiary: TrareonRamp.dT3,
    textDisabled: TrareonRamp.dT4,
    icon: TrareonRamp.dT2,
    // lines: alpha-white, so a nested surface does not stack two visible
    // greys the way two opaque borders did.
    hairline: Color(0x17FFFFFF),
    hairlineStrong: Color(0x24FFFFFF),
    borderInteractive: Color(0x26FFFFFF),
    borderDisabled: Color(0x1FFFFFFF),
    // accent
    primary: TrareonRamp.teal300,
    onPrimary: TrareonRamp.teal900,
    primaryHover: TrareonRamp.teal200,
    primaryPressed: TrareonRamp.teal400,
    primaryText: TrareonRamp.teal300,
    primarySubtle: Color(0x2E1E8A79),
    primaryDark: TrareonRamp.teal200,
    focusRing: TrareonRamp.teal300,
    // semantics
    success: Color(0xFF5FD08B),
    onSuccess: Color(0xFF06240F),
    successSubtle: Color(0x2E5FD08B),
    warning: Color(0xFFF2C06B),
    onWarning: Color(0xFF3A2600),
    warningSubtle: Color(0x2EF2C06B),
    error: Color(0xFFFF8F85),
    onError: Color(0xFF3F0E0A),
    errorSubtle: Color(0x2EFF8F85),
    errorHover: Color(0xFFFFA8A0),
    errorPressed: Color(0xFFE8776D),
    info: Color(0xFF7FC0FF),
    onInfo: Color(0xFF06243E),
    infoSubtle: Color(0x2E7FC0FF),
    recording: Color(0xFFFF7A6E),
    onRecording: Color(0xFF3F0E0A),
    recordingSubtle: Color(0x2EFF7A6E),
    // overlays
    hoverOverlay: Color(0x14FFFFFF),
    pressedOverlay: Color(0x24FFFFFF),
    scrim: Color(0x990B0D0D),
    shadow: Color(0x66000000),
    // speakers
    speakerPalette: [
      Color(0xFF6FC6B6), // teal
      Color(0xFFF0A882), // burnt orange
      Color(0xFF8FC4F5), // blue
      Color(0xFFCFA3E6), // purple
      Color(0xFF8ACB8E), // green
      Color(0xFFF39B96), // red
      Color(0xFFF09CC0), // magenta
      Color(0xFFAFA7EE), // indigo
    ],
  );
}

/// The semantic colour roles the whole app draws with.
///
/// A concrete `ThemeExtension` with named fields rather than an abstract class
/// plus two subclasses: the subclasses meant every new role was three edits in
/// three places, which is how the palette drifted in the first place.
@immutable
class AppColorSet extends ThemeExtension<AppColorSet> {
  const AppColorSet({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceSunken,
    required this.surfacePressed,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.surfaceModal,
    required this.text,
    required this.textStrong,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.icon,
    required this.hairline,
    required this.hairlineStrong,
    required this.borderInteractive,
    required this.borderDisabled,
    required this.primary,
    required this.onPrimary,
    required this.primaryHover,
    required this.primaryPressed,
    required this.primaryText,
    required this.primarySubtle,
    required this.primaryDark,
    required this.focusRing,
    required this.success,
    required this.onSuccess,
    required this.successSubtle,
    required this.warning,
    required this.onWarning,
    required this.warningSubtle,
    required this.error,
    required this.onError,
    required this.errorSubtle,
    required this.errorHover,
    required this.errorPressed,
    required this.info,
    required this.onInfo,
    required this.infoSubtle,
    required this.recording,
    required this.onRecording,
    required this.recordingSubtle,
    required this.hoverOverlay,
    required this.pressedOverlay,
    required this.scrim,
    required this.shadow,
    required this.speakerPalette,
  });

  /// Which ramp this is. Widgets that genuinely need to branch (the shadow
  /// ladder, a platform blur) read this instead of `Theme.of(context)`.
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  // ── surfaces ──────────────────────────────────────────────────────────
  /// The window background.
  final Color background;

  /// One step up: sidebar, header, card, list.
  final Color surface;

  /// Sunken fill on [surface]: inputs, chips, keycaps, progress tracks.
  final Color surfaceSunken;

  /// Pressed fill, and the selected row where no accent applies.
  final Color surfacePressed;

  /// Elevation 2: a panel that is genuinely lifted off [surface].
  final Color surfaceRaised;

  /// Elevation 3: menus, popovers, tooltips.
  final Color surfaceOverlay;

  /// Elevation 4: dialogs, sheets, toasts, the floating player bar.
  final Color surfaceModal;

  // ── text and icons ────────────────────────────────────────────────────
  final Color text;

  /// Display headings only. Equal to [text] in dark mode, where going lighter
  /// than `dT1` starts to bloom.
  final Color textStrong;

  final Color textSecondary;
  final Color textTertiary;

  /// Disabled text and icons. Exempt from SC 1.4.3, so it is the one role in
  /// this file the contrast test does not gate.
  final Color textDisabled;

  /// Default icon colour where an icon is not carrying a semantic.
  final Color icon;

  // ── lines ─────────────────────────────────────────────────────────────
  /// 1 px universal edge. Alpha over the parent surface, so nesting does not
  /// stack two visible lines.
  final Color hairline;

  /// 1 px divider that has to read as a rule.
  final Color hairlineStrong;

  /// 1 px border on an input or a secondary button.
  final Color borderInteractive;

  final Color borderDisabled;

  // ── accent ────────────────────────────────────────────────────────────
  /// The accent fill: primary button, selected toggle, playhead.
  final Color primary;

  /// Ink on [primary].
  final Color onPrimary;

  final Color primaryHover;
  final Color primaryPressed;

  /// The accent as *text or icon* colour: a link, an active tab label, an
  /// accent glyph. Separate from [primary] because a fill and a glyph need
  /// different lightness to hit the same ratio.
  final Color primaryText;

  /// Low-alpha accent wash: a selected list row, an active filter chip.
  final Color primarySubtle;

  /// A deeper accent for the brand mark on a light surface, and a lighter one
  /// on dark. Kept for the app icon and the wordmark only.
  final Color primaryDark;

  /// Focus-ring stroke. Measured at 4.2:1 (light) and 9.3:1 (dark), both
  /// above SC 1.4.11's 3:1.
  final Color focusRing;

  // ── semantics ─────────────────────────────────────────────────────────
  final Color success;
  final Color onSuccess;

  /// 10 % (light) / 18 % (dark) wash for a banner or a status chip.
  final Color successSubtle;

  final Color warning;
  final Color onWarning;
  final Color warningSubtle;

  /// Destructive and failed. A crimson.
  final Color error;
  final Color onError;
  final Color errorSubtle;
  final Color errorHover;
  final Color errorPressed;

  final Color info;
  final Color onInfo;
  final Color infoSubtle;

  /// A recording in progress. Its own role rather than [error] because a live
  /// capture is not a problem, and a scarlet rather than a crimson so the two
  /// are not confusable at a glance.
  final Color recording;
  final Color onRecording;
  final Color recordingSubtle;

  // ── overlays ──────────────────────────────────────────────────────────
  /// Hover tint, composited over whatever surface the control sits on. Used
  /// instead of a Material ink splash on dense list rows, where 5,000 ripples
  /// are visibly janky.
  final Color hoverOverlay;
  final Color pressedOverlay;

  /// Scrim behind a dialog or a sheet.
  final Color scrim;

  /// Shadow colour, tinted to the neutral ramp rather than pure black.
  final Color shadow;

  // ── speakers ──────────────────────────────────────────────────────────
  /// Per-speaker accents, used as the *text* colour of the speaker name on
  /// every transcript row and as the fill of the speaker avatar plate.
  /// Theme-aware: one fixed palette cannot be legible on both `#FFFFFF` and
  /// `#0C0E0F`. Gated by `test/speaker_color_test.dart`.
  final List<Color> speakerPalette;

  /// Elevation 2: a lifted panel. Empty in dark mode, where the ladder does
  /// the work.
  List<BoxShadow> get shadowRaised => isDark
      ? const []
      : [
          BoxShadow(
            color: shadow.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: shadow.withValues(alpha: 0.04),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ];

  /// Elevation 3: a menu or popover.
  List<BoxShadow> get shadowOverlay => isDark
      ? const []
      : [
          BoxShadow(
            color: shadow.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: shadow.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];

  /// Elevation 4: a dialog, sheet or toast.
  List<BoxShadow> get shadowModal => isDark
      ? const []
      : [
          BoxShadow(
            color: shadow.withValues(alpha: 0.16),
            blurRadius: 48,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];

  /// Legacy role names kept so the whole app did not have to be renamed in
  /// one commit. Each is an alias onto the ramp above.
  Color get surfaceElevated => surfaceRaised;
  Color get divider => hairline;
  Color get border => hairline;
  Color get chipBackground => surfaceSunken;
  Color get chipSelectedBackground => primary;
  Color get headerBackground => surface;
  Color get transcriptBackground => surface;
  Color get secondary => primary;
  Color get onSecondary => onPrimary;

  @override
  AppColorSet copyWith() => this;

  @override
  AppColorSet lerp(ThemeExtension<AppColorSet>? other, double t) {
    // The two ramps are tuned independently, so interpolating between them
    // produces greys that belong to neither. The theme cross-fade in
    // MaterialApp already covers the transition visually.
    if (other is! AppColorSet) return this;
    return t < 0.5 ? this : other;
  }
}
