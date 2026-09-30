/// Real system RAM, per platform.
///
/// The setup wizard used to read `sysctl hw.memsize` — macOS only — and
/// otherwise present `cores × 2 GB`, clamped to 4–32 GB, in a row plainly
/// labelled "RAM" (audit A.6, P2). On Linux and Windows that number was a
/// guess shown as a fact, and it drove the model recommendation.
library;

import 'dart:io';

class SystemRam {
  final int megabytes;

  /// True when no platform API answered and [megabytes] is the
  /// cores-based heuristic. The UI must say so rather than present it as
  /// a measurement.
  final bool isEstimate;

  const SystemRam(this.megabytes, {this.isEstimate = false});
}

/// Parses `MemTotal:       16316324 kB` out of `/proc/meminfo`.
/// Returns null when the line is missing or malformed.
int? parseProcMeminfoTotalMb(String contents) {
  for (final line in contents.split('\n')) {
    if (!line.startsWith('MemTotal:')) continue;
    final match = RegExp(r'(\d+)\s*kB', caseSensitive: false).firstMatch(line);
    if (match == null) return null;
    final kb = int.tryParse(match.group(1)!);
    if (kb == null || kb <= 0) return null;
    return (kb / 1024).round();
  }
  return null;
}

/// Cores-based fallback, kept only for platforms that answered nothing.
int estimateRamMbFromCores(int cores) =>
    (cores * 2048).clamp(4096, 32768).toInt();

/// Total physical memory in MB.
Future<SystemRam> detectTotalRam({int? coreCount}) async {
  final cores = coreCount ?? Platform.numberOfProcessors;
  try {
    if (Platform.isLinux) {
      final file = File('/proc/meminfo');
      if (await file.exists()) {
        final mb = parseProcMeminfoTotalMb(await file.readAsString());
        if (mb != null) return SystemRam(mb);
      }
    } else if (Platform.isMacOS) {
      final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
      if (result.exitCode == 0) {
        final bytes = int.tryParse(result.stdout.toString().trim());
        if (bytes != null && bytes > 0) {
          return SystemRam((bytes / (1024 * 1024)).round());
        }
      }
    } else if (Platform.isWindows) {
      // `wmic` is deprecated and absent from recent Windows builds; CIM is
      // the supported route.
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ]);
      if (result.exitCode == 0) {
        final bytes = int.tryParse(result.stdout.toString().trim());
        if (bytes != null && bytes > 0) {
          return SystemRam((bytes / (1024 * 1024)).round());
        }
      }
    }
  } catch (_) {
    // Fall through to the estimate: a wizard that crashes because a
    // shell-out failed is worse than one that says "perkiraan".
  }
  return SystemRam(estimateRamMbFromCores(cores), isEstimate: true);
}
