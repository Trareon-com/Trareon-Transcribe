import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/l10n/generated/app_localizations.dart';
import 'package:transcribe/screens/usage_dashboard_screen.dart';

/// Localisation-wrapped `MaterialApp`, with the delegates bound explicitly.
///
/// `testWidgets` starts with an empty [Localizations] scope and `AppBar`
/// asserts that `MaterialLocalizations` is present in it. `MaterialApp` from
/// `package:material_ui` happens to append its own
/// `DefaultMaterialLocalizations` today, but that is a property of the
/// package/SDK pair, not of this screen — which is what #64 was about (the
/// assert fired on Flutter 3.47.4, not on 3.50.1). Binding the delegates
/// here makes the wrapper deterministic instead of riding on that default.
///
/// The delegates are material_ui's own, not `flutter_localizations`':
/// `material_ui` is a fork and exports a *different* `GlobalMaterialLocalizations`
/// (its `MaterialLocalizations` is a different class), so a
/// `flutter_localizations` delegate would not satisfy the assert for these
/// widgets. `AppLocalizations.delegate` is added so the app's own strings
/// resolve too, as they do in `lib/main.dart`.
Widget _appWithLocalizations(Widget home) => MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    ...GlobalMaterialLocalizations.delegates,
    AppLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  test(
    'scans real session folders under libraryPath instead of showing an empty state',
    () async {
      // Regression test: settings_side_panel.dart used to construct
      // UsageDashboardScreen() with no libraryPath at all, so this disk scan
      // never ran in production — the dashboard always showed "0 sesi" even
      // with real completed sessions on disk. Unit-tests scanUsageStats()
      // directly (plain test(), not testWidgets()) since pumping a widget
      // through a real async disk read here is unnecessary indirection for
      // what is otherwise pure I/O + aggregation logic.
      final tempDir = await Directory.systemTemp.createTemp(
        'usage-dashboard-test-',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final sessionDir = Directory('${tempDir.path}/20260917-Sesi Test')
        ..createSync();
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
    },
  );

  test('scanUsageStats returns empty stats for a missing directory', () async {
    final stats = await scanUsageStats(
      '/nonexistent/path/${DateTime.now().microsecondsSinceEpoch}',
    );

    expect(stats.totalSessions, 0);
    expect(stats.totalSegments, 0);
  });

  testWidgets('shows zero state by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      _appWithLocalizations(const UsageDashboardScreen()),
    );

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
    await tester.pumpWidget(
      _appWithLocalizations(const UsageDashboardScreen(stats: stats)),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('340'), findsOneWidget);
    expect(find.text('Rapat Online'), findsOneWidget);
    expect(find.text('8 sesi'), findsOneWidget);
  });
}
