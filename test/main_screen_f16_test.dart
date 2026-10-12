// F16 UI wiring (Sprint 18): verifies the "Terdeteksi rapat" and
// "Tidak ada suara" dialogs actually appear in MainScreen's real widget
// tree — not just that the underlying provider/notifier logic works in
// isolation, which is what Sprint 17 left unverified.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/main_screen.dart';
import 'package:transcribe/src/rust/meeting_detect.dart' as rust_meeting_detect;
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/state/silence_auto_stop_model.dart';

import 'test_helpers.dart';

/// Returns a fixed [rust_meeting_detect.DetectedMeeting] on every poll until
/// told otherwise, so the test controls exactly when the "meeting" appears
/// and disappears.
class _MeetingDetectBridge extends NoopBridge {
  rust_meeting_detect.DetectedMeeting? meeting;

  @override
  Future<rust_meeting_detect.DetectedMeeting?> detectMeetingWindow() async =>
      meeting;
}

/// Lets a test push a [SilenceAutoStopWarning] straight into the provider
/// without waiting out the real silence threshold and grace period.
class _FakeSilenceAutoStopNotifier extends SilenceAutoStopNotifier {
  _FakeSilenceAutoStopNotifier(super.ref);

  bool continueCalled = false;

  void forceWarning(SilenceAutoStopWarning warning) => state = warning;

  void forceCleared() => state = null;

  @override
  void continueRecording() {
    continueCalled = true;
    super.continueRecording();
  }
}

Future<void> _pumpMainScreen(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(buildTestAppWithOverrides(overrides: overrides));
  await tester.pump();
}

void main() {
  group('F16a - deteksi rapat otomatis', () {
    testWidgets(
      'dialog "Terdeteksi rapat" muncul begitu window rapat terdeteksi',
      (tester) async {
        final bridge = _MeetingDetectBridge()
          ..meeting = const rust_meeting_detect.DetectedMeeting(
            app: 'Zoom',
            windowId: 'win-1',
          );

        await _pumpMainScreen(
          tester,
          overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        );

        // Nothing until the poll interval elapses.
        expect(find.text('Rapat terdeteksi'), findsNothing);

        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        await tester.pump();

        expect(find.text('Rapat terdeteksi'), findsOneWidget);
        expect(
          find.textContaining('Terdeteksi rapat (Zoom)'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('"Mulai Rekam" pada dialog benar-benar memulai sesi rekam', (
      tester,
    ) async {
      final bridge = _MeetingDetectBridge()
        ..meeting = const rust_meeting_detect.DetectedMeeting(
          app: 'Google Meet',
          windowId: 'win-2',
        );

      await _pumpMainScreen(
        tester,
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      await tester.pump();

      final dialogStartButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Mulai Rekam'),
      );
      expect(dialogStartButton, findsOneWidget);
      await tester.tap(dialogStartButton);
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainScreen)),
      );
      expect(
        container.read(sessionProvider).lifecycle,
        SessionLifecycle.recording,
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      '"Abaikan" tidak menawarkan lagi untuk window yang sama selama masih terdeteksi',
      (tester) async {
        final bridge = _MeetingDetectBridge()
          ..meeting = const rust_meeting_detect.DetectedMeeting(
            app: 'Zoom',
            windowId: 'win-3',
          );

        await _pumpMainScreen(
          tester,
          overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        await tester.pump();

        expect(find.text('Rapat terdeteksi'), findsOneWidget);
        await tester.tap(find.text('Abaikan'));
        await tester.pump();
        await tester.pump();

        // Window is still "open" (same windowId) on the next few polls —
        // must not be offered again.
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();

        expect(find.text('Rapat terdeteksi'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('F16b - peringatan auto-stop sunyi', () {
    testWidgets(
      'dialog "Tidak ada suara" muncul saat silenceAutoStopProvider berubah non-null',
      (tester) async {
        late _FakeSilenceAutoStopNotifier fakeNotifier;
        final bridge = NoopBridge();

        await _pumpMainScreen(
          tester,
          overrides: [
            rustBridgeProvider.overrideWithValue(bridge),
            silenceAutoStopProvider.overrideWith((ref) {
              fakeNotifier = _FakeSilenceAutoStopNotifier(ref);
              return fakeNotifier;
            }),
          ],
        );

        expect(find.text('Tidak ada suara'), findsNothing);

        fakeNotifier.forceWarning(
          SilenceAutoStopWarning(5, DateTime.now().add(const Duration(minutes: 1))),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Tidak ada suara'), findsOneWidget);
        expect(find.textContaining('5 menit'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('"Lanjutkan" memanggil continueRecording() dan menutup dialog', (
      tester,
    ) async {
      late _FakeSilenceAutoStopNotifier fakeNotifier;
      final bridge = NoopBridge();

      await _pumpMainScreen(
        tester,
        overrides: [
          rustBridgeProvider.overrideWithValue(bridge),
          silenceAutoStopProvider.overrideWith((ref) {
            fakeNotifier = _FakeSilenceAutoStopNotifier(ref);
            return fakeNotifier;
          }),
        ],
      );

      fakeNotifier.forceWarning(
        SilenceAutoStopWarning(5, DateTime.now().add(const Duration(minutes: 1))),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Tidak ada suara'), findsOneWidget);

      await tester.tap(find.text('Lanjutkan'));
      await tester.pump();
      await tester.pump();

      expect(fakeNotifier.continueCalled, isTrue);
      expect(find.text('Tidak ada suara'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'dialog menutup sendiri saat suara kembali sebelum pengguna menekan apa pun',
      (tester) async {
        late _FakeSilenceAutoStopNotifier fakeNotifier;
        final bridge = NoopBridge();

        await _pumpMainScreen(
          tester,
          overrides: [
            rustBridgeProvider.overrideWithValue(bridge),
            silenceAutoStopProvider.overrideWith((ref) {
              fakeNotifier = _FakeSilenceAutoStopNotifier(ref);
              return fakeNotifier;
            }),
          ],
        );

        fakeNotifier.forceWarning(
          SilenceAutoStopWarning(5, DateTime.now().add(const Duration(minutes: 1))),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Tidak ada suara'), findsOneWidget);

        // Sound resumed on its own: the notifier clears the warning without
        // the user tapping anything.
        fakeNotifier.forceCleared();
        await tester.pump();
        await tester.pump();

        expect(find.text('Tidak ada suara'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
