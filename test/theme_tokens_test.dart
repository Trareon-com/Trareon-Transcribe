import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/theme/app_tokens.dart';
import 'package:transcribe/theme/contrast.dart';

/// Blueprint §4.8: colour belongs to the theme, and the theme alone.
///
/// Twenty-five loose `Color(0x…)` literals had accumulated across the UI by
/// the end of sprint 2 — including an amber that was used in five places with
/// no dark-mode variant, and a `Colors.white` button label that measured
/// 2.44:1 in dark mode. Catching the *next* one in CI is cheaper than
/// auditing for it again, so this test reads the source.
void main() {
  group('colour literals stay in lib/theme', () {
    /// `Colors.transparent` carries no colour decision — it means "draw
    /// nothing here", usually on a `Material` wrapping an `InkWell`, and
    /// there is no sensible theme token for it. Everything else in
    /// `Colors.*` is a Material palette swatch that bypasses the theme.
    const allowedMaterialColors = {'Colors.transparent'};

    final literal = RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)');
    // `Colors.foo` but not `AppColors.foo` — the `(?<![A-Za-z])` guard is
    // what keeps the project's own token class out of the results.
    final materialColor = RegExp(r'(?<![A-Za-z])Colors\.[a-zA-Z]+');

    test('no hardcoded colours outside lib/theme', () {
      final offenders = <String>[];
      for (final file in _uiSources()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          for (final match in literal.allMatches(line)) {
            offenders.add('${_relative(file)}:${i + 1} ${match.group(0)}');
          }
          for (final match in materialColor.allMatches(line)) {
            final found = match.group(0)!;
            if (allowedMaterialColors.contains(found)) continue;
            offenders.add('${_relative(file)}:${i + 1} $found');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Colour belongs in lib/theme/app_colors.dart as a role on '
            'AppColorSet, so light and dark can differ and the contrast test '
            'can check it. Offenders:\n  ${offenders.join('\n  ')}',
      );
    });

    test('the scan actually sees the UI sources', () {
      // A regex that matches nothing, or a glob that finds nothing, would
      // make the test above pass vacuously forever.
      final sources = _uiSources().toList();
      expect(sources.length, greaterThan(30));
      expect(
        sources.any((f) => _relative(f) == 'lib/screens/main_screen.dart'),
        isTrue,
      );
      expect(literal.hasMatch('color: Color(0xFFD97706),'), isTrue);
      expect(materialColor.hasMatch('color: Colors.red,'), isTrue);
      expect(
        materialColor.hasMatch('color: AppColors.light.primary,'),
        isFalse,
        reason: "the project's own token class must not be flagged",
      );
    });
  });

  group('design tokens', () {
    test('spacing is a strictly increasing 4-point scale', () {
      const scale = [
        Spacing.xs,
        Spacing.sm,
        Spacing.md,
        Spacing.lg,
        Spacing.xl,
        Spacing.xxl,
      ];
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
      for (final step in scale) {
        expect(step % 4, 0, reason: '$step is off the 4-point grid');
      }
    });

    test('radii and type scale are strictly increasing', () {
      expect(Radii.sm, lessThan(Radii.md));
      expect(Radii.md, lessThan(Radii.lg));
      expect(Radii.lg, lessThan(Radii.pill));

      const sizes = [
        FontSizes.micro,
        FontSizes.caption,
        FontSizes.body,
        FontSizes.bodyLarge,
        FontSizes.title,
        FontSizes.headline,
        FontSizes.display,
      ];
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i], greaterThan(sizes[i - 1]));
      }
    });

    test('the minimum touch target meets WCAG 2.2 AA', () {
      expect(TouchTarget.minimum, greaterThanOrEqualTo(44));
      expect(TouchTarget.constraints.minWidth, TouchTarget.minimum);
      expect(TouchTarget.constraints.minHeight, TouchTarget.minimum);
    });
  });

  group('the new colour roles are legible in both themes', () {
    // Added this sprint: success/warning/recording used to be fixed
    // `AppColors` constants applied over both a white and a #121212 surface.
    for (final entry in {
      'light': AppColors.light,
      'dark': AppColors.dark,
    }.entries) {
      final name = entry.key;
      final colors = entry.value;

      test('$name: status text reaches AA on its surface', () {
        for (final pair in {
          'success': colors.success,
          'warning': colors.warning,
          'error': colors.error,
          'recording': colors.recording,
        }.entries) {
          final ratio = contrastRatio(pair.value, colors.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$name ${pair.key} on surface is '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('$name: filled status chips reach AA against their own fill', () {
        for (final pair in {
          'success': (colors.success, colors.onSuccess),
          'warning': (colors.warning, colors.onWarning),
          'error': (colors.error, colors.onError),
        }.entries) {
          final (fill, ink) = pair.value;
          final ratio = contrastRatio(ink, fill);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$name on${pair.key} over ${pair.key} is '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      });
    }

    test('shadow is translucent in both themes', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        expect(colors.shadow.a, lessThan(1.0));
        expect(colors.shadow.a, greaterThan(0.0));
      }
    });
  });
}

/// Hand-written UI sources: `lib/`, minus the theme itself (which is where
/// colour is *supposed* to live) and minus `lib/src/rust/`, which is
/// generated and must never be hand-edited.
Iterable<File> _uiSources() {
  final root = Directory('lib');
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) {
        final relative = _relative(f);
        return !relative.startsWith('lib/theme/') &&
            !relative.startsWith('lib/src/rust/');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _relative(File file) => file.path.replaceAll(r'\', '/');
