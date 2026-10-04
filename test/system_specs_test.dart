import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/utils/system_specs.dart';

void main() {
  group('parseProcMeminfoTotalMb', () {
    test('reads MemTotal from a real /proc/meminfo layout', () {
      const contents = '''
MemTotal:       16316324 kB
MemFree:         1234567 kB
MemAvailable:    8765432 kB
''';
      expect(parseProcMeminfoTotalMb(contents), 15934);
    });

    test('is null when MemTotal is absent or malformed', () {
      expect(parseProcMeminfoTotalMb('MemFree: 100 kB'), isNull);
      expect(parseProcMeminfoTotalMb('MemTotal:  banyak sekali'), isNull);
      expect(parseProcMeminfoTotalMb('MemTotal: 0 kB'), isNull);
      expect(parseProcMeminfoTotalMb(''), isNull);
    });
  });

  test('the cores heuristic stays inside plausible bounds', () {
    expect(estimateRamMbFromCores(1), 4096);
    expect(estimateRamMbFromCores(4), 8192);
    expect(estimateRamMbFromCores(64), 32768);
  });

  test('on Linux the reading is real, not the cores heuristic', () async {
    // The whole point of the fix: the wizard used to show `cores × 2 GB`
    // as a fact on every platform except macOS (audit A.6, P2).
    if (!Platform.isLinux || !File('/proc/meminfo').existsSync()) return;
    final ram = await detectTotalRam();
    expect(ram.isEstimate, isFalse);
    expect(ram.megabytes, greaterThan(0));
    expect(
      ram.megabytes,
      parseProcMeminfoTotalMb(File('/proc/meminfo').readAsStringSync()),
    );
  });
}
