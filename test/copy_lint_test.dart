import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Copy rules from `docs/DESIGN-SYSTEM.md` §10, enforced mechanically.
///
/// The em-dash is the single most recognisable "written by a model" tell there
/// is, and 38 of them had accumulated in the Indonesian UI copy. Indonesian
/// punctuation does not use it at all: a comma, a colon or a full stop is
/// always the right answer. `...` typed as three periods is the other one; the
/// app bundles a font with a real ellipsis glyph.
void main() {
  group('no em-dash in user-visible copy', () {
    test('Dart string literals in lib/', () {
      final offenders = <String>[];
      for (final file in _dartSources()) {
        final lines = _lines(file);
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isComment(line)) continue;
          for (final text in _stringLiterals(line)) {
            if (text.contains('—') || text.contains('–')) {
              offenders.add('${_rel(file)}:${i + 1} ${text.trim()}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Use a comma, a colon, a full stop or parentheses. '
            'DESIGN-SYSTEM.md §10. Offenders:\n  ${offenders.join('\n  ')}',
      );
    });

    test('ARB message strings', () {
      final offenders = <String>[];
      for (final file in Directory(
        'lib/l10n',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.arb'))) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is! Map<String, dynamic>) continue;
        decoded.forEach((key, value) {
          if (key.startsWith('@')) return;
          if (value is! String) return;
          if (value.contains('—') || value.contains('–')) {
            offenders.add('${_rel(file)} $key: $value');
          }
        });
      }
      expect(offenders, isEmpty, reason: offenders.join('\n  '));
    });
  });

  group('ellipsis is the glyph, not three periods', () {
    test('Dart string literals in lib/', () {
      final offenders = <String>[];
      for (final file in _dartSources()) {
        final lines = _lines(file);
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isComment(line)) continue;
          for (final text in _stringLiterals(line)) {
            // `..` is Dart's cascade and `...` its spread; neither appears
            // inside a string literal, so a run of three periods in one is
            // always typed punctuation.
            if (text.contains('...')) {
              offenders.add('${_rel(file)}:${i + 1} ${text.trim()}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Use the ellipsis character. Offenders:\n  ${offenders.join('\n  ')}',
      );
    });
  });

  group('the scan would catch a violation', () {
    test('its own patterns work', () {
      expect(_stringLiterals("const x = 'halo';").single, "'halo'");
      expect(
        _stringLiterals("Text('Mulai — sekarang')").single.contains('—'),
        isTrue,
      );
      expect(_isComment('  // Mulai — sekarang'), isTrue);
      expect(_isComment("  Text('Mulai');"), isFalse);
    });

    test('it reads a representative set of files', () {
      final files = _dartSources().map(_rel).toList();
      expect(files.length, greaterThan(40));
      expect(files, contains('lib/screens/main_screen.dart'));
    });
  });
}

/// Dart string literals on one line. Two patterns rather than one
/// alternation, because a single raw literal cannot hold both quote
/// characters and still terminate.
final _singleQuoted = RegExp(r"'(?:[^'\\\n]|\\.)*'");
final _doubleQuoted = RegExp(r'"(?:[^"\\\n]|\\.)*"');

Iterable<String> _stringLiterals(String line) sync* {
  for (final m in _singleQuoted.allMatches(line)) {
    yield m.group(0)!;
  }
  for (final m in _doubleQuoted.allMatches(line)) {
    yield m.group(0)!;
  }
}

bool _isComment(String line) => line.trimLeft().startsWith('//');

List<String> _lines(File file) {
  try {
    return file.readAsLinesSync();
  } catch (_) {
    return const [];
  }
}

Iterable<File> _dartSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // Generated: the bridge and the localisation delegates are not hand copy.
        .where((f) => !_rel(f).startsWith('lib/src/rust/'))
        .where((f) => !_rel(f).startsWith('lib/l10n/generated/'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

String _rel(File file) => file.path.replaceAll(r'\', '/');
