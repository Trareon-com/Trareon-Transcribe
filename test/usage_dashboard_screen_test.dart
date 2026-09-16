import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/usage_dashboard_screen.dart';

void main() {
  testWidgets('scans real session folders under libraryPath instead of showing an empty state', (
    WidgetTester tester,
  ) async {
    // Regression test: settings_side_panel.dart used to construct
    // UsageDashboardScreen() with no libraryPath at all, so this disk scan
    // never ran in production — the dashboard always showed "0 sesi" even
    // with real completed sessions on disk.
    final tempDir = await Directory.systemTemp.createTemp('usage-dashboard-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final sessionDir = Directory('${tempDir.path}/20260917-Sesi Test')..createSync();
    File('${sessionDir.path}/Sesi Test.json').writeAsStringSync(
      jsonEncode([
        {'source': 'mic', 'timestamp': 0, 'duration': 2},
        {'source': 'mic', 'timestamp': 10, 'duration': 5},
      ]),
    );

    await tester.pumpWidget(MaterialApp(home: UsageDashboardScreen(libraryPath: tempDir.path)));
    // Not pumpAndSettle(): the loading state renders an indeterminate
    // CircularProgressIndicator, which animates forever and never "settles".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('1'), findsOneWidget); // Total Sesi
    expect(find.text('2'), findsOneWidget); // Total Segmen Transkrip
    expect(find.text('Rapat Offline'), findsOneWidget);
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
