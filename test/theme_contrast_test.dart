import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/theme/contrast.dart';

/// Mechanical WCAG AA gate on the theme.
///
/// The audit measured 2.44:1 on every primary button in dark mode — a
/// hardcoded `Colors.white` over a light-teal fill. Nothing in the build
/// noticed, because no test had ever asserted a ratio. These do.
void main() {
  /// Foreground/background pairs that carry normal-size body text and
  /// therefore need 4.5:1.
  List<(String, Color, Color)> textPairs(String theme, AppColorSet c) => [
    ('$theme text on background', c.text, c.background),
    ('$theme text on surface', c.text, c.surface),
    ('$theme text on surfaceElevated', c.text, c.surfaceElevated),
    ('$theme text on chipBackground', c.text, c.chipBackground),
    ('$theme text on headerBackground', c.text, c.headerBackground),
    ('$theme text on transcriptBackground', c.text, c.transcriptBackground),
    ('$theme textSecondary on background', c.textSecondary, c.background),
    ('$theme textSecondary on surface', c.textSecondary, c.surface),
    ('$theme textTertiary on background', c.textTertiary, c.background),
    ('$theme textTertiary on surface', c.textTertiary, c.surface),
    ('$theme onPrimary on primary', c.onPrimary, c.primary),
    ('$theme onSecondary on secondary', c.onSecondary, c.secondary),
    ('$theme onError on error', c.onError, c.error),
    ('$theme error on background', c.error, c.background),
    ('$theme error on surface', c.error, c.surface),
    ('$theme primary on background', c.primary, c.background),
    ('$theme primary on surface', c.primary, c.surface),
    (
      '$theme onPrimary on chipSelectedBackground',
      c.onPrimary,
      c.chipSelectedBackground,
    ),
  ];

  /// Non-text UI components (borders, dividers, focus rings) need 3:1.
  List<(String, Color, Color)> componentPairs(String theme, AppColorSet c) => [
    ('$theme primary on surface (icon)', c.primary, c.surface),
    ('$theme primary on chipBackground (icon)', c.primary, c.chipBackground),
  ];

  for (final (theme, colors) in <(String, AppColorSet)>[
    ('light', AppColors.light),
    ('dark', AppColors.dark),
  ]) {
    group('$theme theme', () {
      for (final (label, fg, bg) in textPairs(theme, colors)) {
        test('$label reaches WCAG AA for body text', () {
          final ratio = contrastRatio(fg, bg);
          expect(
            ratio,
            greaterThanOrEqualTo(kWcagAaNormalText),
            reason:
                '$label is ${ratio.toStringAsFixed(2)}:1, '
                'needs $kWcagAaNormalText:1',
          );
        });
      }

      for (final (label, fg, bg) in componentPairs(theme, colors)) {
        test('$label reaches WCAG AA for UI components', () {
          final ratio = contrastRatio(fg, bg);
          expect(
            ratio,
            greaterThanOrEqualTo(kWcagAaLargeText),
            reason:
                '$label is ${ratio.toStringAsFixed(2)}:1, '
                'needs $kWcagAaLargeText:1',
          );
        });
      }
    });
  }

  group('ThemeData wiring', () {
    for (final (name, theme, colors) in <(String, ThemeData, AppColorSet)>[
      ('light', AppTheme.light(), AppColors.light),
      ('dark', AppTheme.dark(), AppColors.dark),
    ]) {
      test('$name ColorScheme pairs each on* with its own surface', () {
        final scheme = theme.colorScheme;
        for (final (label, fg, bg) in <(String, Color, Color)>[
          ('onPrimary/primary', scheme.onPrimary, scheme.primary),
          ('onSecondary/secondary', scheme.onSecondary, scheme.secondary),
          ('onError/error', scheme.onError, scheme.error),
          ('onSurface/surface', scheme.onSurface, scheme.surface),
        ]) {
          final ratio = contrastRatio(fg, bg);
          expect(
            ratio,
            greaterThanOrEqualTo(kWcagAaNormalText),
            reason:
                '$name $label is ${ratio.toStringAsFixed(2)}:1, '
                'needs $kWcagAaNormalText:1',
          );
        }
      });

      test('$name ElevatedButton label is readable on its own fill', () {
        final style = theme.elevatedButtonTheme.style!;
        const states = <WidgetState>{};
        final fg = style.foregroundColor!.resolve(states)!;
        final bg = style.backgroundColor!.resolve(states)!;
        final ratio = contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(kWcagAaNormalText),
          reason:
              '$name ElevatedButton is ${ratio.toStringAsFixed(2)}:1 — '
              'this is the regression that shipped at 2.44:1',
        );
        // The specific defect: a hardcoded white label.
        expect(fg, equals(colors.onPrimary));
      });

      test('$name SegmentedButton selected label is readable', () {
        final style = theme.segmentedButtonTheme.style!;
        const selected = <WidgetState>{WidgetState.selected};
        final fg = style.foregroundColor!.resolve(selected)!;
        final bg = style.backgroundColor!.resolve(selected)!;
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(kWcagAaNormalText));
      });
    }
  });

  test('contrastRatio matches the WCAG reference extremes', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21.0, 0.01),
    );
    expect(
      contrastRatio(const Color(0xFF777777), const Color(0xFFFFFFFF)),
      closeTo(4.48, 0.01),
    );
    expect(
      contrastRatio(const Color(0xFF00796B), const Color(0xFF00796B)),
      closeTo(1.0, 0.001),
    );
  });
}
