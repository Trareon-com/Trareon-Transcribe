import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class UsageStats {
  final int totalSessions;
  final double totalMinutesTranscribed;
  final int totalSegments;
  final Map<String, int> sessionsByMode;

  const UsageStats({
    required this.totalSessions,
    required this.totalMinutesTranscribed,
    required this.totalSegments,
    required this.sessionsByMode,
  });

  factory UsageStats.empty() => const UsageStats(
        totalSessions: 0,
        totalMinutesTranscribed: 0,
        totalSegments: 0,
        sessionsByMode: {},
      );
}

String _sourceModeLabel(String source) => switch (source) {
      'mic' => 'Rapat Offline',
      'spk' => 'Webinar',
      _ => 'Rapat Online',
    };

/// Scans `libraryPath` for session folders (one `.json` transcript per
/// folder) and aggregates them into [UsageStats]. Pulled out as a plain
/// top-level function — separate from the widget's `_loadStats()` — so it
/// can be unit-tested with a plain `test()` instead of `testWidgets()`.
Future<UsageStats> scanUsageStats(String libraryPath) async {
  final resolved = libraryPath.startsWith('~/')
      ? '${Platform.environment['HOME'] ?? ''}${libraryPath.substring(1)}'
      : libraryPath;
  final dir = Directory(resolved);

  if (!dir.existsSync()) {
    return UsageStats.empty();
  }

  var totalSessions = 0;
  var totalMinutes = 0.0;
  var totalSegments = 0;
  final byMode = <String, int>{};

  try {
    for (final entry in dir.listSync()) {
      if (entry is! Directory) continue;
      final files = entry.listSync().whereType<File>().toList();
      final jsonFile = files.where((f) => f.path.endsWith('.json')).firstOrNull;
      if (jsonFile == null) continue;
      try {
        final raw = await jsonFile.readAsString();
        final list = jsonDecode(raw);
        if (list is! List || list.isEmpty) continue;

        totalSessions++;
        totalSegments += list.length;

        final last = list.last as Map<String, dynamic>;
        final lastTs = (last['timestamp'] as num?)?.toDouble() ?? 0;
        final lastDur = (last['duration'] as num?)?.toDouble() ?? 0;
        totalMinutes += (lastTs + lastDur) / 60;

        // Source field ('mic'/'spk') approximates mode
        final first = list.first as Map<String, dynamic>;
        final source = (first['source'] as String?) ?? 'mic';
        final modeLabel = _sourceModeLabel(source);
        byMode[modeLabel] = (byMode[modeLabel] ?? 0) + 1;
      } catch (_) {
        continue;
      }
    }
  } catch (_) {}

  return UsageStats(
    totalSessions: totalSessions,
    totalMinutesTranscribed: totalMinutes,
    totalSegments: totalSegments,
    sessionsByMode: byMode,
  );
}

/// Loads and displays real usage statistics by scanning the library directory.
class UsageDashboardScreen extends StatefulWidget {
  /// Optional library path to scan. When null and [stats] is null, shows empty state.
  final String? libraryPath;

  /// Optional pre-computed stats (used in tests to bypass the async disk scan).
  final UsageStats? stats;

  const UsageDashboardScreen({super.key, this.libraryPath, this.stats});

  @override
  State<UsageDashboardScreen> createState() => _UsageDashboardScreenState();
}

class _UsageDashboardScreenState extends State<UsageDashboardScreen> {
  UsageStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.stats != null) {
      _stats = widget.stats;
      _loading = false;
    } else {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    final rawPath = widget.libraryPath;
    if (rawPath == null || rawPath.isEmpty) {
      setState(() {
        _stats = UsageStats.empty();
        _loading = false;
      });
      return;
    }

    final stats = await scanUsageStats(rawPath);
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistik Penggunaan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final stats = _stats ?? UsageStats.empty();
    final hours = (stats.totalMinutesTranscribed / 60).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik Penggunaan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(label: 'Total Sesi', value: '${stats.totalSessions}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(label: 'Jam Ditranskrip', value: hours),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(label: 'Total Segmen Transkrip', value: '${stats.totalSegments}'),
          const SizedBox(height: 24),
          if (stats.sessionsByMode.isEmpty)
            const Text('Belum ada data sesi tersimpan.')
          else ...[
            Text('Sesi per Mode', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in stats.sessionsByMode.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text('${entry.value} sesi'),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
