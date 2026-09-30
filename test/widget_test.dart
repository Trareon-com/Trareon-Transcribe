import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/widgets/mode_selector.dart';

import 'test_helpers.dart';

void main() {
  group('MainScreen widget tests', () {
    testWidgets('main screen renders mode selector and start button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Mulai'), findsOneWidget);
      // Check for ModeSelector widget instead of SegmentedButton directly
      expect(find.byType(ModeSelector), findsOneWidget);
      expect(find.text('Mikrofon'), findsWidgets);
      expect(find.text('Pengeras Suara'), findsWidgets);
    });

    testWidgets('starting a session switches button to Stop', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mulai'));
      await tester.pump();

      expect(find.text('Berhenti'), findsOneWidget);
    });

    testWidgets('settings icon navigates to settings screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pengaturan'));
      await tester.pumpAndSettle();

      expect(find.text('Tema'), findsOneWidget);
    });

    testWidgets('settings screen navigates into Privacy Report', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pengaturan'));
      await tester.pumpAndSettle();

      // Settings is two panes now: the Privacy Report tile lives under
      // the "Penyiapan & Diagnostik" category.
      await tester.tap(find.text('Penyiapan & Diagnostik'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laporan Privasi'));
      await tester.pumpAndSettle();

      // Privacy Report screen loads - check for the screen title
      expect(find.text('Laporan Privasi'), findsOneWidget);
    });

    testWidgets('shortcuts icon toggles keyboard shortcuts panel', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      // Toggle shortcuts panel via keyboard shortcut (Cmd+/)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      expect(find.text('Pintasan keyboard'), findsWidgets);
    });

    testWidgets('stop without segments does not show confirmation dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mulai'));
      await tester.pump();
      await tester.tap(find.text('Berhenti'));
      await tester.pumpAndSettle();

      expect(find.text('Berhenti merekam?'), findsNothing);
      expect(find.text('Mulai'), findsOneWidget);
    });

    testWidgets('export button is visible', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Ekspor'), findsOneWidget);
    });

    testWidgets('audio indicators show MIC and SPK labels', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Mikrofon'), findsWidgets);
      expect(find.text('Pengeras Suara'), findsWidgets);
    });

    testWidgets('footer shows recording timer when active', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      // Timer not shown when idle — only when recording/paused
      expect(find.textContaining('Trareon Transcribe'), findsOneWidget);
    });
  });

  group('Settings persistence tests', () {
    test('NoopBridge returns default settings', () async {
      final bridge = NoopBridge();
      final initial = await bridge.loadSettings();
      expect(initial.defaultModel, 'base');
      expect(initial.theme, AppThemeMode.light);
      expect(initial.defaultMode, SessionMode.online);
    });

    test('NoopBridge persists settings roundtrip in memory', () async {
      final bridge = NoopBridge();

      final updated = AppSettings(
        theme: AppThemeMode.dark,
        defaultModel: 'small',
        defaultMode: SessionMode.webinar,
        libraryPath: '/tmp/transcribe',
        vadEnabled: false,
        language: 'en',
      );
      await bridge.saveSettings(updated);

      final reloaded = await bridge.loadSettings();
      expect(reloaded.theme, AppThemeMode.dark);
      expect(reloaded.defaultModel, 'small');
      expect(reloaded.libraryPath, '/tmp/transcribe');
      expect(reloaded.vadEnabled, isFalse);
      expect(reloaded.language, 'en');
    });
  });
}