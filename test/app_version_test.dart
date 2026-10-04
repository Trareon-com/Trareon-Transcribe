import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/app_version.dart';

/// Three places state the app's version: [kAppVersion] (what the updater
/// compares and the About dialog shows), `pubspec.yaml` (what the binary is
/// built as) and the `VERSION` manifest (what an installed copy fetches to
/// decide whether it is out of date). They disagreed — 0.1.0 vs 1.0.0 vs
/// 0.1.0 — so "Cek Pembaruan" could not report correctly in either
/// direction. This is the gate that keeps them together.
void main() {
  String pubspecVersion() {
    final line = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    // "version: 1.0.0+1" -> "1.0.0"
    return line.split(':')[1].trim().split('+').first;
  }

  test('kAppVersion matches pubspec.yaml', () {
    expect(kAppVersion, pubspecVersion());
  });

  test('the VERSION manifest matches pubspec.yaml', () {
    expect(File('VERSION').readAsStringSync().trim(), pubspecVersion());
  });

  test('kAppVersion is a plain semantic version', () {
    expect(kAppVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });

  test('the outbound URLs are https and point at the project', () {
    for (final url in [kReleasesUrl, kVersionManifestUrl]) {
      expect(url, startsWith('https://'));
      expect(url, contains('Trareon-com/Transcribe'));
    }
  });
}
