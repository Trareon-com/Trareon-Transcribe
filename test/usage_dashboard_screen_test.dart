import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/usage_dashboard_screen.dart';

void main() {
  test('scans real session folders under libraryPath instead of showing an empty state', () async {
    // Regression test: settings_side_panel.dart used to construct
    // UsageDashboardScreen() with no libraryPath at all, so this disk scan
    // never ran in production — the dashboard always showed "0 sesi" even
    // with real completed sessions on disk. Unit-tests scanUsageStats()
    // directly (plain test(), not testWidgets()) since pumping a widget
    // through a real async disk read here is unnecessary indirection for
    // what is otherwise pure I/O + aggregation logic.
    final tempDir = await Directory.systemTemp.createTemp('usage-dashboard-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final sessionDir = Directory('${tempDir.path}/20260917-Sesi Test')..createSync();
    File('${sessionDir.path}/Sesi Test.json').writeAsStringSync(
      jsonEncode([
        {'source': 'mic', 'timestamp': 0, 'duration': 2},
        {'source': 'mic', 'timestamp': 10, 'duration': 5},
      ]),
    );

    final stats = await scanUsageStats(tempDir.path);

    expect(stats.totalSessions, 1);
    expect(stats.totalSegments, 2);
    expect(stats.sessionsByMode, {'Rapat Offline': 1});
  });

  test('scanUsageStats returns empty stats for a missing directory', () async {
    final stats = await scanUsageStats('/nonexistent/path/${DateTime.now().microsecondsSinceEpoch}');

    expect(stats.totalSessions, 0);
    expect(stats.totalSegments, 0);
  });

  testWidgets('shows zero state by default', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: UsageDashboardScreen()));

    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('Belum ada data sesi tersimpan.'), findsOneWidget);
  });

  testWidgets('renders provided stats', (WidgetTester tester) async {
    const stats = UsageStats(
      totalSessions: 12,
      totalMinutesTranscribed: 150,
      totalSegments: 340,
      sessionsByMode: {'Rapat Online': 8, 'Webinar': 4},
    );
    await tester.pumpWidget(const MaterialApp(home: UsageDashboardScreen(stats: stats)));

    expect(find.text('12'), findsOneWidget);
    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('340'), findsOneWidget);
    expect(find.text('Rapat Online'), findsOneWidget);
    expect(find.text('8 sesi'), findsOneWidget);
  });
}
