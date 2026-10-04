import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The product name has been misspelled in shipped UI ("Selamat datang di
/// Traeon Transcribe" on the very first screen a new user sees) and in a
/// config-directory literal inside `doctor.rs`. Both were typos nobody could
/// find without reading every file, so the spelling is now a build gate.
///
/// Documentation under `docs/` is deliberately out of scope: the audit files
/// quote the misspelling as evidence, and rewriting the evidence would defeat
/// the purpose of keeping it.
void main() {
  /// Every misspelling of "Trareon" seen in this repository's history.
  final misspellings = RegExp(r'Traeon|Traereon|Trareron|traeon|traereon');

  const scannedRoots = [
    'lib',
    'test',
    'integration_test',
    'rust_core/src',
    'rust_core/tests',
    'scripts',
    'linux',
    'macos',
    'windows',
    'assets',
  ];

  const scannedExtensions = {
    '.dart',
    '.rs',
    '.sh',
    '.ps1',
    '.yaml',
    '.yml',
    '.json',
    '.cc',
    '.cpp',
    '.h',
    '.cmake',
    '.txt',
    '.desktop',
    '.plist',
    '.xml',
    '.rc',
  };

  bool isScannable(String path) =>
      scannedExtensions.any((ext) => path.endsWith(ext));

  test('no source file misspells the product name', () {
    final offenders = <String>[];

    for (final root in scannedRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!isScannable(entity.path)) continue;
        // This test file names the misspellings on purpose.
        if (entity.path.endsWith('product_name_spelling_test.dart')) continue;
        final lines = entity.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (misspellings.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'the product is spelled "Trareon". Misspellings found:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the onboarding greeting spells the product correctly', () {
    final source = File(
      'lib/screens/onboarding_screen.dart',
    ).readAsStringSync();
    expect(source, contains('Selamat datang di Trareon Transcribe'));
  });
}
