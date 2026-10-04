/// `ThemeData` assembled from the tokens. `docs/DESIGN-SYSTEM.md` is the spec.
///
/// Every Material component theme here exists for one reason: the default
/// Material 3 look is itself an "AI tell" (design-taste §9.E) and a desktop
/// productivity tool cannot afford a 40 px tall tonal button with a purple
/// fallback scheme. Anything the component kit in `lib/widgets/ui/` draws
/// itself is still themed, because dialogs, menus and tooltips that Flutter
/// builds internally have to match.
library;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_icons.dart';
import 'app_motion.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColorSet colors) {
    final isDark = colors.isDark;
    final scheme = ColorScheme(
      brightness: colors.brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primarySubtle,
      onPrimaryContainer: colors.primaryText,
      secondary: colors.primary,
      onSecondary: colors.onPrimary,
      tertiary: colors.info,
      onTertiary: colors.onInfo,
      error: colors.error,
      onError: colors.onError,
      errorContainer: colors.errorSubtle,
      onErrorContainer: colors.error,
      surface: colors.surface,
      onSurface: colors.text,
      onSurfaceVariant: colors.textSecondary,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surfaceSunken,
      surfaceContainerHigh: colors.surfaceOverlay,
      surfaceContainerHighest: colors.surfaceModal,
      outline: colors.borderInteractive,
      outlineVariant: colors.hairline,
      shadow: colors.shadow,
      scrim: colors.scrim,
      inverseSurface: isDark ? colors.text : colors.textStrong,
      onInverseSurface: colors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      extensions: [colors],
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.hairline,
      fontFamily: AppFonts.sans,
      fontFamilyFallback: AppFonts.sansFallback,
      // Every bare `TextStyle(fontSize: …)` in a `Text` merges onto
      // `bodyMedium`, so putting Inter and the app's default size here is what
      // makes the bundled face reach the whole tree.
      textTheme: _textTheme(colors),
      iconTheme: IconThemeData(color: colors.icon, size: IconSizes.md),
      primaryIconTheme: IconThemeData(color: colors.onPrimary),
      // Material's own ripple is wrong for a dense desktop list: the kit in
      // lib/widgets/ui uses a surface tint instead. Where Material still
      // draws one (a built-in menu row) it is kept quiet.
      splashFactory: NoSplash.splashFactory,
      highlightColor: colors.pressedOverlay,
      hoverColor: colors.hoverOverlay,
      splashColor: colors.pressedOverlay,
      focusColor: colors.hoverOverlay,
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(
        color: colors.hairline,
        thickness: Strokes.hairline,
        space: Strokes.hairline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.heading.c(colors.text),
        iconTheme: IconThemeData(color: colors.icon, size: IconSizes.lg),
        shape: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(color: colors.hairline),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.textDisabled;
          if (states.contains(WidgetState.selected)) return colors.onPrimary;
          return colors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfacePressed;
          }
          if (states.contains(WidgetState.selected)) return colors.primary;
          return isDark ? colors.surfaceModal : colors.borderDisabled;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : colors.borderInteractive,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(Strokes.hairline),
        overlayColor: WidgetStatePropertyAll(colors.hoverOverlay),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(colors.onPrimary),
        side: BorderSide(color: colors.borderInteractive, width: Strokes.focusRing),
        shape: const RoundedRectangleBorder(borderRadius: Radii.xsAll),
        overlayColor: WidgetStatePropertyAll(colors.hoverOverlay),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.borderInteractive,
        ),
        overlayColor: WidgetStatePropertyAll(colors.hoverOverlay),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSunken,
        hintStyle: AppText.body.c(colors.textTertiary),
        labelStyle: AppText.caption.c(colors.textSecondary),
        helperStyle: AppText.caption.c(colors.textTertiary),
        errorStyle: AppText.caption.c(colors.error),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        border: _fieldBorder(colors.borderInteractive),
        enabledBorder: _fieldBorder(colors.borderInteractive),
        disabledBorder: _fieldBorder(colors.borderDisabled),
        focusedBorder: _fieldBorder(colors.primary, width: Strokes.focusRing),
        errorBorder: _fieldBorder(colors.error),
        focusedErrorBorder: _fieldBorder(colors.error, width: Strokes.focusRing),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _filledStyle(colors),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _filledStyle(colors)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.textDisabled
                : colors.text,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colors.surfacePressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return colors.surfaceSunken;
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? colors.borderDisabled
                  : colors.borderInteractive,
            ),
          ),
          textStyle: const WidgetStatePropertyAll(AppText.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Spacing.lg),
          ),
          minimumSize: const WidgetStatePropertyAll(
            Size(0, ControlSizes.lg),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.mdAll),
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.textDisabled
                : colors.primaryText,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colors.surfacePressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return colors.surfaceSunken;
            }
            return Colors.transparent;
          }),
          textStyle: const WidgetStatePropertyAll(AppText.label),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Spacing.md),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, ControlSizes.lg)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.mdAll),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.textDisabled
                : colors.icon,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colors.pressedOverlay;
            }
            if (states.contains(WidgetState.hovered)) {
              return colors.hoverOverlay;
            }
            return Colors.transparent;
          }),
          iconSize: const WidgetStatePropertyAll(IconSizes.lg),
          minimumSize: const WidgetStatePropertyAll(TouchTarget.minimumSize),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.mdAll),
          ),
        ),
      ),
      // SnackBar is banned by `test/design_lint_test.dart` in favour of the
      // single AppToast system; this theme only exists so a stray framework
      // snack bar (a text-field "paste" hint, say) is not unstyled.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceModal,
        contentTextStyle: AppText.body.c(colors.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(color: colors.hairline),
        ),
        elevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceModal,
          borderRadius: Radii.smAll,
          border: Border.all(color: colors.hairlineStrong),
          boxShadow: colors.shadowOverlay,
        ),
        textStyle: AppText.caption.c(colors.text),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        waitDuration: const Duration(milliseconds: 450),
        preferBelow: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceModal,
        surfaceTintColor: Colors.transparent,
        barrierColor: colors.scrim,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.xlAll,
          side: BorderSide(color: colors.hairlineStrong),
        ),
        titleTextStyle: AppText.heading.c(colors.text),
        contentTextStyle: AppText.body.c(colors.textSecondary),
        insetPadding: const EdgeInsets.all(Spacing.xl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceModal,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: colors.scrim,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlTop),
        clipBehavior: Clip.antiAlias,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final base = colors.textTertiary;
          if (states.contains(WidgetState.hovered)) {
            return base.withValues(alpha: 0.6);
          }
          return base.withValues(alpha: 0.35);
        }),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        radius: const Radius.circular(Radii.xs),
        thickness: const WidgetStatePropertyAll(Strokes.hairline * 6),
        crossAxisMargin: Spacing.xs / 2,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // Selected reads as a *lift* onto a lighter surface, not an accent
          // fill: a three-way mode selector painted in the brand colour makes
          // the accent the loudest thing on the screen (DESIGN-SYSTEM §6.4).
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.text
                : colors.textSecondary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.surface
                : Colors.transparent,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.hairline),
          ),
          textStyle: const WidgetStatePropertyAll(AppText.label),
          minimumSize: const WidgetStatePropertyAll(Size(0, ControlSizes.lg)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Spacing.md),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.mdAll),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: isDark ? colors.surfaceModal : colors.borderDisabled,
        circularTrackColor: Colors.transparent,
        linearMinHeight: Strokes.progress,
        strokeWidth: Strokes.ring,
        strokeCap: StrokeCap.round,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceOverlay,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: colors.hairlineStrong),
        ),
        textStyle: AppText.body.c(colors.text),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.body.c(
            states.contains(WidgetState.disabled)
                ? colors.textTertiary
                : colors.text,
          ),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        position: PopupMenuPosition.under,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceOverlay),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: Radii.mdAll,
              side: BorderSide(color: colors.hairlineStrong),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: Spacing.xs),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceSunken,
        selectedColor: colors.primarySubtle,
        disabledColor: colors.surfaceSunken,
        labelStyle: AppText.micro.c(colors.textSecondary),
        secondaryLabelStyle: AppText.micro.c(colors.primaryText),
        side: BorderSide(color: colors.hairline),
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        labelPadding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.text,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: AppText.label,
        unselectedLabelStyle: AppText.label,
        indicatorColor: colors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: colors.hairline,
        dividerHeight: Strokes.hairline,
        overlayColor: WidgetStatePropertyAll(colors.hoverOverlay),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.icon,
        textColor: colors.text,
        titleTextStyle: AppText.subheading.c(colors.text),
        subtitleTextStyle: AppText.caption.c(colors.textTertiary),
        minVerticalPadding: Spacing.sm,
        horizontalTitleGap: Spacing.md,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        visualDensity: VisualDensity.compact,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: colors.icon,
        collapsedIconColor: colors.icon,
        textColor: colors.text,
        collapsedTextColor: colors.text,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: isDark
            ? colors.surfaceModal
            : colors.borderDisabled,
        thumbColor: colors.primary,
        overlayColor: colors.primarySubtle,
        trackHeight: Strokes.progress,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: Spacing.md),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: Spacing.sm),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double? width}) =>
      OutlineInputBorder(
        borderRadius: Radii.mdAll,
        borderSide: BorderSide(color: color, width: width ?? Strokes.hairline),
      );

  static ButtonStyle _filledStyle(AppColorSet colors) => ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? colors.textDisabled
          // Not `Colors.white`: the dark-mode accent gives white 2.4:1, on
          // every primary button in the app. That shipped once.
          : colors.onPrimary,
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return colors.surfacePressed;
      if (states.contains(WidgetState.pressed)) return colors.primaryPressed;
      if (states.contains(WidgetState.hovered)) return colors.primaryHover;
      return colors.primary;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    textStyle: const WidgetStatePropertyAll(AppText.label),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: Spacing.lg),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, ControlSizes.lg)),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: Radii.mdAll),
    ),
    elevation: const WidgetStatePropertyAll(0),
    animationDuration: Motion.fast,
    iconSize: const WidgetStatePropertyAll(IconSizes.sm),
  );

  /// The Material text theme, so that every bare `TextStyle` in a `Text`
  /// merges onto Inter at the app's own default size rather than onto
  /// `Typography.blackMountainView` at 14.
  static TextTheme _textTheme(AppColorSet colors) => TextTheme(
    displayLarge: AppText.display.c(colors.textStrong),
    displayMedium: AppText.display.c(colors.textStrong),
    displaySmall: AppText.title.c(colors.textStrong),
    headlineLarge: AppText.title.c(colors.textStrong),
    headlineMedium: AppText.title.c(colors.text),
    headlineSmall: AppText.heading.c(colors.text),
    titleLarge: AppText.heading.c(colors.text),
    titleMedium: AppText.subheading.c(colors.text),
    titleSmall: AppText.label.c(colors.text),
    bodyLarge: AppText.reading.c(colors.text),
    bodyMedium: AppText.body.c(colors.text),
    bodySmall: AppText.caption.c(colors.textSecondary),
    labelLarge: AppText.label.c(colors.text),
    labelMedium: AppText.caption.c(colors.textSecondary),
    labelSmall: AppText.micro.c(colors.textTertiary),
  );

  /// Resolves the colour set for a context, falling back to the light ramp.
  ///
  /// Every widget in the app starts with this line. The fallback exists for
  /// widget tests that pump a bare `MaterialApp` without the extension.
  static AppColorSet colorsOf(BuildContext context) =>
      Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
}

/// `context.colors` reads better than `AppTheme.colorsOf(context)` at the
/// several hundred call sites that need it.
extension AppThemeContext on BuildContext {
  AppColorSet get colors => AppTheme.colorsOf(this);

  /// Motion settings with reduce-motion already applied.
  AppMotion get motion => AppMotion.of(this);

  /// True when the window is narrower than [Breakpoints.compact].
  bool get isCompact => MediaQuery.sizeOf(this).width < Breakpoints.compact;

  /// True when the window is at least [Breakpoints.wide].
  bool get isWide => MediaQuery.sizeOf(this).width >= Breakpoints.wide;
}

/// Kept so `AppIcons` is reachable from the theme barrel for the gallery.
typedef AppIconVocabulary = AppIcons;
