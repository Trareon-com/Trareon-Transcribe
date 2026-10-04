import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/theme/app_icons.dart';
import 'package:transcribe/theme/app_tokens.dart';
import 'package:transcribe/theme/app_typography.dart';

/// The design system is only a system if it is the only source of these
/// values. `docs/DESIGN-SYSTEM.md` §12 is the checklist; this file is what
/// fails the build when something drifts off it.
///
/// Before sprint 5 the app carried 25 loose colour literals, 169 loose
/// `fontSize:` numbers, 70 ad-hoc radii, 184 numeric `SizedBox` gaps and 142
/// different Material icons in four visual variants. Every one of those was
/// added by somebody reasonable who needed a value and typed one.
void main() {
  group('colour belongs to lib/theme', () {
    /// `Colors.transparent` carries no colour decision. It means "draw
    /// nothing here", usually on a `Material` wrapping an `InkWell`, and
    /// there is no sensible theme token for it.
    const allowed = {'Colors.transparent'};

    final literal = RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)');
    // `Colors.foo` but not `AppColors.foo`: the lookbehind is what keeps the
    // project's own token class out of the results.
    final materialColor = RegExp(r'(?<![A-Za-z])Colors\.[a-zA-Z]+');

    test('no hardcoded colours outside lib/theme', () {
      final offenders = <String>[];
      for (final (file, lines) in _uiSourceLines()) {
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isComment(line)) continue;
          for (final match in literal.allMatches(line)) {
            offenders.add('${_rel(file)}:${i + 1} ${match.group(0)}');
          }
          for (final match in materialColor.allMatches(line)) {
            final found = match.group(0)!;
            if (allowed.contains(found)) continue;
            offenders.add('${_rel(file)}:${i + 1} $found');
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
  });

  group('size belongs to lib/theme', () {
    test('no hardcoded fontSize', () {
      final pattern = RegExp(r'fontSize:\s*[0-9]');
      expect(
        _scan(pattern),
        isEmpty,
        reason:
            'Use a role from AppText (which carries weight, line height and '
            'tracking too), or FontSizes if only the size is wanted.',
      );
    });

    test('no hardcoded corner radius', () {
      final pattern = RegExp(r'Radius\.circular\(\s*[0-9]');
      expect(
        _scan(pattern),
        isEmpty,
        reason:
            'Use Radii.xs/sm/md/lg/xl/pill. Each step owns a class of '
            'component (DESIGN-SYSTEM.md §4.2).',
      );
    });

    test('no numeric EdgeInsets', () {
      // `EdgeInsets.all(Spacing.lg)` and `EdgeInsets.only(top: Spacing.xs / 2)`
      // are fine: both are derived from the scale. `EdgeInsets.all(16)` and
      // `EdgeInsets.only(left: 40)` are not. Zero is on the grid by
      // definition and stays allowed.
      final offenders = <String>[];
      for (final (file, lines) in _uiSourceLines()) {
        for (var i = 0; i < lines.length; i++) {
          if (_isComment(lines[i])) continue;
          for (final value in _edgeInsetsValues(lines[i])) {
            if (_isBareNumber(value)) {
              offenders.add('${_rel(file)}:${i + 1} ${lines[i].trim()}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Use the Spacing scale (4-point). DESIGN-SYSTEM.md §4.1. '
            'Offenders:\n  ${offenders.join('\n  ')}',
      );
    });

    test('no single-dimension numeric SizedBox gaps', () {
      // `SizedBox(height: 0)` is a deliberate "render nothing here" and is
      // on the grid; every other number is a gap that belongs to the scale.
      final pattern = RegExp(r'SizedBox\((?:height|width):\s*[1-9][0-9]*\s*\)');
      expect(
        _scan(pattern),
        isEmpty,
        reason:
            'Use Spacing.gapXs..gapXxl for vertical gaps and Spacing.hXs..hXl '
            'for horizontal ones.',
      );
    });
  });

  group('one icon vocabulary', () {
    test('Icons.* is only used in lib/theme/app_icons.dart', () {
      final pattern = RegExp(r'(?<![A-Za-z])Icons\.[a-zA-Z_0-9]+');
      expect(
        _scan(pattern, extraSkip: {'lib/theme/app_icons.dart'}),
        isEmpty,
        reason:
            'Add a semantic name to AppIcons instead. A glyph can then be '
            'swapped once rather than with a sweep through forty files '
            '(DESIGN-SYSTEM.md §5).',
      );
    });

    test('the vocabulary is non-empty and every entry resolves', () {
      // Without this the scan above could pass vacuously against an empty
      // AppIcons.
      expect(AppIcons.all.length, greaterThan(100));
      for (final entry in AppIcons.all.entries) {
        expect(
          entry.value.fontFamily,
          isNotNull,
          reason: '${entry.key} has no font family',
        );
      }
    });
  });

  group('text always carries the app typeface', () {
    // The three widgets that *replace* DefaultTextStyle rather than merging
    // with it. Handed a bare `TextStyle(...)` they render in the platform
    // fallback face, which is how the most-read text in the app (the
    // transcript body) and every settings dropdown ended up outside Inter
    // until the goldens caught it.
    test('RichText is not used; Text.rich merges the default style', () {
      expect(
        _scan(RegExp(r'(?<![A-Za-z])RichText\(')),
        isEmpty,
        reason:
            'Use Text.rich. RichText does not merge DefaultTextStyle, so its '
            'spans lose the app typeface.',
      );
    });

    test('DefaultTextStyle and Dropdown styles come from AppText', () {
      final offenders = <String>[];
      final replacers = RegExp(
        r'(?<![A-Za-z])(DefaultTextStyle|DropdownButton|'
        r'DropdownButtonFormField)[(<]',
      );
      for (final (file, lines) in _uiSourceLines()) {
        for (var i = 0; i < lines.length; i++) {
          if (_isComment(lines[i])) continue;
          if (!replacers.hasMatch(lines[i])) continue;
          // Only the widget's own argument list: scan forward while the
          // indentation stays deeper than the line it opened on. A fixed
          // window would pick up the `style:` of whatever Text happens to
          // follow it.
          final indent = lines[i].length - lines[i].trimLeft().length;
          String? value;
          for (var j = i + 1; j < lines.length; j++) {
            final line = lines[j];
            if (line.trim().isEmpty) continue;
            final depth = line.length - line.trimLeft().length;
            if (depth <= indent) break;
            final style = RegExp(r'style:\s*(.*)').firstMatch(line);
            if (style != null) {
              value = style.group(1);
              break;
            }
          }
          if (value == null) continue;
          if (value.contains('AppText.') || value.contains('AppFonts.')) {
            continue;
          }
          if (!value.contains('TextStyle')) continue;
          offenders.add('${_rel(file)}:${i + 1} ${lines[i].trim()}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These widgets replace DefaultTextStyle. Give them a role from '
            'AppText so the text keeps the app typeface. Offenders:\n  '
            '${offenders.join('\n  ')}',
      );
    });
  });

  group('one notification system', () {
    test('SnackBar and ScaffoldMessenger are not used in lib/', () {
      final pattern = RegExp(r'(?<![A-Za-z])(SnackBar|ScaffoldMessenger)\b');
      expect(
        _scan(pattern),
        isEmpty,
        reason:
            'AppToast is the only transient notification in the app. Two '
            'systems means two visual languages and two dismiss behaviours '
            '(DESIGN-SYSTEM.md §6.11).',
      );
    });
  });

  group('the scan actually sees the UI sources', () {
    test('it reads a representative set of files', () {
      // A regex that matches nothing, or a glob that finds nothing, would
      // make every test above pass forever.
      final files = _uiSourceLines().map((e) => _rel(e.$1)).toList();
      expect(files.length, greaterThan(40));
      expect(files, contains('lib/screens/main_screen.dart'));
      expect(files, contains('lib/widgets/ui/app_button.dart'));
    });

    test('each pattern catches its own violation', () {
      expect(RegExp(r'fontSize:\s*[0-9]').hasMatch('fontSize: 13,'), isTrue);
      expect(
        RegExp(r'fontSize:\s*[0-9]').hasMatch('fontSize: FontSizes.body,'),
        isFalse,
      );
      expect(
        RegExp(r'Radius\.circular\(\s*[0-9]').hasMatch('Radius.circular(8)'),
        isTrue,
      );
      expect(
        RegExp(
          r'Radius\.circular\(\s*[0-9]',
        ).hasMatch('Radius.circular(Radii.md)'),
        isFalse,
      );
      bool edgeOffends(String line) =>
          _edgeInsetsValues(line).any(_isBareNumber);
      expect(edgeOffends('EdgeInsets.all(16)'), isTrue);
      expect(edgeOffends('EdgeInsets.symmetric(horizontal: 12)'), isTrue);
      expect(edgeOffends('EdgeInsets.only(left: 40, top: Spacing.xs)'), isTrue);
      expect(edgeOffends('EdgeInsets.all(compact ? 16 : 40)'), isTrue);
      expect(edgeOffends('EdgeInsets.all(Spacing.lg)'), isFalse);
      expect(edgeOffends('EdgeInsets.only(left: 0)'), isFalse);
      expect(
        edgeOffends('EdgeInsets.symmetric(horizontal: Spacing.xs / 2)'),
        isFalse,
        reason: 'an expression derived from the scale is still the scale',
      );
      expect(edgeOffends('EdgeInsets.only(top: Spacing.xs + 1)'), isFalse);
      final box = RegExp(r'SizedBox\((?:height|width):\s*[1-9][0-9]*\s*\)');
      expect(box.hasMatch('SizedBox(height: 8)'), isTrue);
      expect(box.hasMatch('SizedBox(height: Spacing.sm)'), isFalse);
      expect(box.hasMatch('SizedBox(height: 0)'), isFalse);
      expect(
        box.hasMatch('SizedBox(width: 20, height: 20, child: x)'),
        isFalse,
        reason: 'a two-dimension SizedBox is a size, not a gap',
      );
      final icons = RegExp(r'(?<![A-Za-z])Icons\.[a-zA-Z_0-9]+');
      expect(icons.hasMatch('Icon(Icons.close)'), isTrue);
      expect(icons.hasMatch('Icon(AppIcons.close)'), isFalse);
    });
  });

  group('the type scale is a scale', () {
    test('sizes are strictly increasing', () {
      const sizes = [
        FontSizes.overline,
        FontSizes.micro,
        FontSizes.caption,
        FontSizes.body,
        FontSizes.bodyLarge,
        FontSizes.title,
        FontSizes.headline,
        FontSizes.timer,
        FontSizes.display,
      ];
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i], greaterThan(sizes[i - 1]));
      }
    });

    test('every role carries a family, a height and a weight', () {
      for (final entry in AppText.roles.entries) {
        final style = entry.value;
        expect(style.fontFamily, isNotNull, reason: '${entry.key} family');
        expect(style.height, isNotNull, reason: '${entry.key} line height');
        expect(style.fontWeight, isNotNull, reason: '${entry.key} weight');
        expect(
          style.color,
          isNull,
          reason:
              '${entry.key} must not carry colour: a role is applied with '
              '.c(colour) so light and dark share one definition',
        );
      }
    });

    test('every numeric role uses tabular figures', () {
      // A running clock that reflows once a second is the single most
      // noticeable typographic defect in an app that shows one.
      for (final name in ['micro', 'mono', 'monoMicro', 'monoTimer']) {
        final style = AppText.roles[name]!;
        expect(
          style.fontFeatures?.any((f) => f.feature == 'tnum'),
          isTrue,
          reason: '$name must be tabular',
        );
      }
    });

    test('the mono roles use the mono family and the rest use the sans', () {
      for (final entry in AppText.roles.entries) {
        final expected = entry.key.toLowerCase().startsWith('mono')
            ? AppFonts.mono
            : AppFonts.sans;
        expect(entry.value.fontFamily, expected, reason: entry.key);
      }
    });
  });

  group('the token scales are scales', () {
    test('spacing is a strictly increasing 4-point scale', () {
      const scale = [
        Spacing.xs,
        Spacing.sm,
        Spacing.md,
        Spacing.lg,
        Spacing.xl,
        Spacing.xxl,
        Spacing.xxxl,
      ];
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
      for (final step in scale) {
        expect(step % 4, 0, reason: '$step is off the 4-point grid');
      }
    });

    test('radii, icon sizes and control sizes increase', () {
      expect(Radii.xs, lessThan(Radii.sm));
      expect(Radii.sm, lessThan(Radii.md));
      expect(Radii.md, lessThan(Radii.lg));
      expect(Radii.lg, lessThan(Radii.xl));
      expect(Radii.xl, lessThan(Radii.pill));

      const icons = [
        IconSizes.xs,
        IconSizes.sm,
        IconSizes.md,
        IconSizes.lg,
        IconSizes.xl,
        IconSizes.hero,
      ];
      for (var i = 1; i < icons.length; i++) {
        expect(icons[i], greaterThan(icons[i - 1]));
      }

      expect(ControlSizes.sm, lessThan(ControlSizes.md));
      expect(ControlSizes.md, lessThan(ControlSizes.lg));
      expect(ControlSizes.lg, lessThan(ControlSizes.xl));
    });

    test('the minimum touch target meets WCAG 2.2 AA', () {
      // SC 2.5.8 asks for 24x24; Material and this app ask for 48.
      expect(TouchTarget.minimum, greaterThanOrEqualTo(44));
      expect(TouchTarget.constraints.minWidth, TouchTarget.minimum);
      expect(TouchTarget.constraints.minHeight, TouchTarget.minimum);
    });

    test('the window minimum is the geometry the layouts are tested at', () {
      expect(WindowSizes.minimum.width, 900);
      expect(WindowSizes.minimum.height, 600);
      expect(
        WindowSizes.defaultSize.width,
        greaterThan(WindowSizes.minimum.width),
      );
      expect(
        WindowSizes.defaultSize.height,
        greaterThan(WindowSizes.minimum.height),
      );
    });
  });

  group('dark mode is a tuned ramp, not an inversion', () {
    test('neither canvas is pure black or pure white', () {
      // Pure values kill depth, and #000000 on an OLED laptop smears on
      // scroll. DESIGN-SYSTEM.md §2.2.
      expect(AppColors.dark.background, isNot(const Color(0xFF000000)));
      expect(AppColors.light.background, isNot(const Color(0xFFFFFFFF)));
    });

    test('the dark surface ladder gets lighter, step by step', () {
      final ladder = [
        AppColors.dark.background,
        AppColors.dark.surface,
        AppColors.dark.surfaceSunken,
        AppColors.dark.surfaceOverlay,
        AppColors.dark.surfaceModal,
      ];
      for (var i = 1; i < ladder.length; i++) {
        expect(
          _luminance(ladder[i]),
          greaterThan(_luminance(ladder[i - 1])),
          reason: 'step $i must be lighter than step ${i - 1}',
        );
      }
    });

    test('the light ladder does the opposite, as it must', () {
      // On light, "elevated" reads as closer to white, and the canvas is the
      // darkest of the three.
      expect(
        _luminance(AppColors.light.surface),
        greaterThan(_luminance(AppColors.light.background)),
      );
      expect(
        _luminance(AppColors.light.surfaceSunken),
        lessThan(_luminance(AppColors.light.surface)),
      );
    });

    test('hairlines are translucent in both themes', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        for (final line in [
          colors.hairline,
          colors.hairlineStrong,
          colors.borderInteractive,
          colors.hoverOverlay,
          colors.pressedOverlay,
        ]) {
          expect(line.a, lessThan(1.0));
          expect(line.a, greaterThan(0.0));
        }
      }
    });

    test('dark mode carries no shadow above elevation 1', () {
      expect(AppColors.dark.shadowRaised, isEmpty);
      expect(AppColors.dark.shadowOverlay, isEmpty);
      expect(AppColors.dark.shadowModal, isEmpty);
      expect(AppColors.light.shadowRaised, isNotEmpty);
      expect(AppColors.light.shadowModal, isNotEmpty);
    });

    test('light-mode shadows are tinted, never pure black', () {
      for (final shadow in [
        ...AppColors.light.shadowRaised,
        ...AppColors.light.shadowOverlay,
        ...AppColors.light.shadowModal,
      ]) {
        expect(shadow.color.a, lessThan(0.3));
        final opaque = Color.from(
          alpha: 1,
          red: shadow.color.r,
          green: shadow.color.g,
          blue: shadow.color.b,
        );
        expect(opaque, isNot(const Color(0xFF000000)));
      }
    });
  });
}

bool _isComment(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//');
}

/// Hand-written UI sources: `lib/`, minus the theme itself (which is where
/// these values are *supposed* to live) and minus `lib/src/rust/`, which is
/// generated and must never be hand-edited.
Iterable<(File, List<String>)> _uiSourceLines({Set<String> keep = const {}}) {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) {
        final rel = _rel(f);
        if (keep.contains(rel)) return true;
        return !rel.startsWith('lib/theme/') &&
            !rel.startsWith('lib/src/rust/');
      })
      .map((f) {
        // A few generated/binary-ish files in lib/state are not valid UTF-8
        // in every checkout; skipping them beats failing the whole scan.
        try {
          return (f, f.readAsLinesSync());
        } catch (_) {
          return (f, <String>[]);
        }
      })
      .toList()
    ..sort((a, b) => a.$1.path.compareTo(b.$1.path));
}

/// Every non-comment line in `lib/` matching [pattern], as `path:line text`.
List<String> _scan(RegExp pattern, {Set<String> extraSkip = const {}}) {
  final offenders = <String>[];
  for (final (file, lines) in _uiSourceLines(keep: extraSkip)) {
    final rel = _rel(file);
    if (extraSkip.contains(rel)) continue;
    for (var i = 0; i < lines.length; i++) {
      if (_isComment(lines[i])) continue;
      if (pattern.hasMatch(lines[i])) {
        offenders.add('$rel:${i + 1} ${lines[i].trim()}');
      }
    }
  }
  return offenders;
}

String _rel(File file) => file.path.replaceAll(r'\', '/');

double _luminance(Color color) => color.computeLuminance();

final _edgeInsetsCall = RegExp(
  r'EdgeInsets\.(?:all|symmetric|only|fromLTRB)\(([^()]*)\)',
);

/// The argument expressions of every `EdgeInsets.…(…)` on [line], with any
/// `name:` prefix stripped. Calls containing a nested call are skipped: the
/// flat regex cannot split them reliably, and none exist in this codebase.
List<String> _edgeInsetsValues(String line) {
  final values = <String>[];
  for (final call in _edgeInsetsCall.allMatches(line)) {
    for (final part in call.group(1)!.split(',')) {
      final colon = part.indexOf(':');
      final value = (colon >= 0 ? part.substring(colon + 1) : part).trim();
      if (value.isNotEmpty) values.add(value);
    }
  }
  return values;
}

/// True when [value] is a literal number other than zero, with nothing from
/// the token scales anywhere in the expression.
bool _isBareNumber(String value) {
  if (!RegExp(r'[0-9]').hasMatch(value)) return false;
  if (RegExp(
    r'(?:Spacing|Radii|IconSizes|ControlSizes|Strokes|Measure|FontSizes|'
    r'TouchTarget|WindowChrome)\.',
  ).hasMatch(value)) {
    return false;
  }
  // `0` and `0.0` are on the grid by definition.
  return !RegExp(r'^0(?:\.0+)?$').hasMatch(value);
}
