import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/widgets/mode_selector.dart';
import 'package:transcribe/widgets/session_sidebar.dart';

import 'test_helpers.dart';

void main() {
  void sizeViewport(WidgetTester tester, [Size size = const Size(1440, 900)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('MainScreen layout', () {
    testWidgets('the session sidebar is permanent, with search and Sesi baru',
        (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Session history used to be behind an unlabelled folder icon.
      expect(find.byType(SessionSidebar), findsOneWidget);
      expect(find.text('Sesi baru'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SessionSidebar),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
        reason: 'the sidebar carries its own search box (Ctrl+L)',
      );
      expect(find.text('Impor berkas'), findsOneWidget);
      expect(find.text('Kelola perpustakaan'), findsOneWidget);
    });

    testWidgets('the empty workspace offers exactly one primary action',
        (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Mulai Rekam'), findsOneWidget);
      // "Ekspor" used to sit next to the record button, enabled, on an
      // empty screen (blueprint §4.2).
      expect(find.text('Ekspor'), findsNothing);
    });

    testWidgets('controls are grouped into Sesi and Perangkat',
        (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('SESI'), findsOneWidget);
      expect(find.text('PERANGKAT'), findsOneWidget);
      expect(find.byType(ModeSelector), findsOneWidget);
      expect(find.text('Mikrofon'), findsWidgets);
      expect(find.text('Suara sistem'), findsWidgets);
      // The quality switch moved out of the title row into session options.
      expect(find.text('Cepat'), findsOneWidget);
    });

    testWidgets('at the 800x600 minimum window both panes still fit',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'no overflow at 800x600');
      expect(find.byType(SessionSidebar), findsOneWidget);
      expect(find.text('Mulai Rekam'), findsOneWidget);
    });

    testWidgets('below the supported minimum the sidebar becomes a drawer',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(SessionSidebar), findsNothing);
      expect(find.byTooltip('Riwayat sesi'), findsOneWidget);

      await tester.tap(find.byTooltip('Riwayat sesi'));
      await tester.pumpAndSettle();
      expect(find.text('Sesi baru'), findsOneWidget);
    });

    testWidgets('renders without overflow at 1280x720 and 1920x1080',
        (WidgetTester tester) async {
      for (final size in [const Size(1280, 720), const Size(1920, 1080)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'overflow at $size');
        expect(find.byType(SessionSidebar), findsOneWidget);
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });

  group('MainScreen widget tests', () {
    testWidgets('starting a session switches button to Stop', (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mulai'));
      await tester.pump();

      expect(find.text('Berhenti'), findsOneWidget);
    });

    testWidgets('settings icon navigates to settings screen', (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pengaturan (Ctrl+,)'));
      await tester.pumpAndSettle();

      expect(find.text('Tema'), findsOneWidget);
    });

    testWidgets('settings screen navigates into Privacy Report', (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pengaturan (Ctrl+,)'));
      await tester.pumpAndSettle();

      // Settings is two panes now: the Privacy Report tile lives under
      // the "Penyiapan & Diagnostik" category.
      await tester.tap(find.text('Penyiapan & Diagnostik'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laporan Privasi'));
      await tester.pumpAndSettle();

      expect(find.text('Laporan Privasi'), findsOneWidget);
    });

    testWidgets('shortcuts panel toggles with Ctrl+/', (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('Pintasan keyboard'), findsWidgets);
      expect(find.text('Cari di riwayat sesi'), findsOneWidget);
    });

    testWidgets('Ctrl+L focuses the sidebar search', (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(SessionSidebar),
          matching: find.byType(TextField),
        ),
      );
      expect(field.focusNode?.hasFocus, isTrue);
    });

    testWidgets('stop without segments does not show confirmation dialog', (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mulai'));
      await tester.pump();
      await tester.tap(find.text('Berhenti'));
      await tester.pumpAndSettle();

      expect(find.text('Berhenti merekam?'), findsNothing);
      expect(find.text('Mulai'), findsOneWidget);
    });

    testWidgets('the footer offers the shortcut hint when idle', (WidgetTester tester) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Ctrl+/ untuk pintasan'), findsOneWidget);
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