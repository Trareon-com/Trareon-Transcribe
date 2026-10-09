import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/widgets/session_sidebar.dart';
import 'package:transcribe/widgets/ui/key_hint.dart';

import 'test_helpers.dart';

/// [NoopBridge] with a controllable `transcriptStream`, so a test can make
/// a session carry a real segment and exercise the stop-confirmation
/// dialog (A7) rather than the empty-session "stop with nothing to lose"
/// path, which is all [NoopBridge] alone can reach.
class _SegmentBridge extends NoopBridge {
  final segmentController = StreamController<TranscriptSegment>.broadcast();

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) =>
      segmentController.stream;
}

void main() {
  void sizeViewport(WidgetTester tester, [Size size = const Size(1440, 900)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('MainScreen layout', () {
    testWidgets('the session sidebar is permanent, with search and Sesi baru', (
      WidgetTester tester,
    ) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Session history used to be behind an unlabelled folder icon.
      expect(find.byType(SessionSidebar), findsOneWidget);
      expect(find.text('Sesi Baru'), findsOneWidget);
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

    testWidgets('the empty workspace offers exactly one primary action', (
      WidgetTester tester,
    ) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Mulai Rekam'), findsOneWidget);
      // "Ekspor" used to sit next to the record button, enabled, on an
      // empty screen (blueprint §4.2).
      expect(find.text('Ekspor'), findsNothing);
    });

    testWidgets('the idle hero explains each capture mode', (
      WidgetTester tester,
    ) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Sprint 5: the idle screen is a hero, so the mode decision is three
      // explained cards rather than a segmented control buried in a nine
      // control toolbar, and the capture chips sit under them.
      for (final mode in ['Rapat Offline', 'Rapat Online', 'Webinar']) {
        expect(find.text(mode), findsOneWidget);
      }
      expect(
        find.text('Zoom, Meet atau Teams. Mikrofon dan suara sistem.'),
        findsOneWidget,
        reason: 'each mode card says what it actually captures',
      );
      expect(find.text('Mikrofon'), findsWidgets);
      expect(find.text('Suara sistem'), findsWidgets);
    });

    testWidgets(
      'at 800x600, below the supported minimum, both panes still fit',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow at 800x600',
        );
        expect(find.byType(SessionSidebar), findsOneWidget);
        expect(find.text('Mulai Rekam'), findsOneWidget);
      },
    );

    testWidgets('below the supported minimum the sidebar becomes a drawer', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(SessionSidebar), findsNothing);
      expect(find.byTooltip('Riwayat sesi'), findsOneWidget);

      await tester.tap(find.byTooltip('Riwayat sesi'));
      await tester.pumpAndSettle();
      expect(find.text('Sesi Baru'), findsOneWidget);
    });

    testWidgets('renders without overflow at 1280x720 and 1920x1080', (
      WidgetTester tester,
    ) async {
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
    testWidgets('starting a session switches button to Stop', (
      WidgetTester tester,
    ) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mulai Rekam'));
      await tester.pump();

      expect(find.text('Berhenti'), findsOneWidget);
    });

    testWidgets('settings icon navigates to settings screen', (
      WidgetTester tester,
    ) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Settings is a destination in the sidebar footer now, next to the
      // other three; it lost its place in the brand row because two icon
      // buttons there truncated the wordmark.
      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();

      expect(find.text('Tema'), findsOneWidget);
    });

    testWidgets('settings screen navigates into Privacy Report', (
      WidgetTester tester,
    ) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Settings is a destination in the sidebar footer now, next to the
      // other three; it lost its place in the brand row because two icon
      // buttons there truncated the wordmark.
      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();

      // Settings is two panes now: the Privacy Report tile lives under
      // the "Penyiapan & Diagnostik" category.
      await tester.tap(find.text('Penyiapan & Diagnostik'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laporan Privasi'));
      await tester.pumpAndSettle();

      expect(find.text('Laporan Privasi'), findsOneWidget);
    });

    testWidgets('shortcuts panel toggles with Ctrl+/', (
      WidgetTester tester,
    ) async {
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

    testWidgets('Ctrl+L focuses the sidebar search', (
      WidgetTester tester,
    ) async {
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

    testWidgets('stop without segments does not show confirmation dialog', (
      WidgetTester tester,
    ) async {
      sizeViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mulai Rekam'));
      await tester.pump();
      await tester.tap(find.text('Berhenti'));
      await tester.pumpAndSettle();

      expect(find.text('Berhenti merekam?'), findsNothing);
      expect(find.text('Mulai Rekam'), findsOneWidget);
    });

    testWidgets(
      'the stop-confirmation dialog is operable from the keyboard (A7)',
      (WidgetTester tester) async {
        sizeViewport(tester);
        final bridge = _SegmentBridge();
        await tester.pumpWidget(
          buildTestAppWithOverrides(
            overrides: [rustBridgeProvider.overrideWithValue(bridge)],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mulai Rekam'));
        await tester.pump();
        // A real segment, so stopping asks for confirmation.
        bridge.segmentController.add(
          const TranscriptSegment(
            source: 'MIC',
            speaker: 'MIC',
            text: 'Halo dunia',
            timestamp: 0,
            duration: 1,
            language: 'id',
            confidence: 0.9,
            isPartial: false,
          ),
        );
        await tester.pump();

        // Not `pumpAndSettle`: recording's own pulse animation keeps
        // repeating behind the modal dialog (stopping is still pending the
        // user's confirmation), which `pumpAndSettle` would wait on
        // forever. A couple of pumps are enough to settle the dialog's own
        // entrance transition.
        await tester.tap(find.text('Berhenti'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Berhenti merekam?'), findsOneWidget);

        // Enter confirms: the primary action is autofocused.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Berhenti merekam?'), findsNothing);
        expect(find.text('Mulai Rekam'), findsOneWidget);
      },
    );

    testWidgets('Esc cancels the stop-confirmation dialog (A7)', (
      WidgetTester tester,
    ) async {
      sizeViewport(tester);
      final bridge = _SegmentBridge();
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mulai Rekam'));
      await tester.pump();
      bridge.segmentController.add(
        const TranscriptSegment(
          source: 'MIC',
          speaker: 'MIC',
          text: 'Halo dunia',
          timestamp: 0,
          duration: 1,
          language: 'id',
          confidence: 0.9,
          isPartial: false,
        ),
      );
      await tester.pump();

      // Not `pumpAndSettle` anywhere in this test: the recording pulse
      // animation keeps running throughout (this scenario never actually
      // stops the session), which `pumpAndSettle` would wait on forever.
      await tester.tap(find.text('Berhenti'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Berhenti merekam?'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Cancelled: the dialog is gone and the session is still recording.
      expect(find.text('Berhenti merekam?'), findsNothing);
      expect(find.text('Berhenti'), findsOneWidget);
    });

    testWidgets('the footer offers the shortcut hint when idle', (
      WidgetTester tester,
    ) async {
      sizeViewport(tester);
      // The keycap text is platform-aware (⌘ on macOS, Ctrl elsewhere) —
      // see `lib/widgets/ui/key_hint.dart`. Pinned to the non-macOS
      // rendering here so this assertion is about the app's own logic, not
      // about which OS happens to be running the test suite: before this
      // fix, running `flutter test` on a macOS host made this fail because
      // the real `Platform.isMacOS` flipped the caps to '⌘'.
      debugForceCommandKey = false;
      addTearDown(() => debugForceCommandKey = null);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // The hint is the action name plus real keycaps, built from the one
      // shortcut table, so it cannot name a binding the app does not have.
      expect(find.text('Pintasan'), findsOneWidget);
      expect(find.text('Ctrl'), findsWidgets);
      expect(find.text('/'), findsWidgets);
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
