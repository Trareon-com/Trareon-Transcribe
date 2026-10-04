import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/audio_stream_model.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/state/settings_model.dart';

import 'test_helpers.dart';

/// Bridge whose `startSession` fails the way the engine now does when no
/// audio source can be opened.
class _FailingStartBridge extends NoopBridge {
  static const message =
      'Sesi tidak dapat dimulai: tidak ada sumber audio yang berhasil dibuka. '
      'Mikrofon — `alsa::poll()` returned POLLERR';

  int startAttempts = 0;

  @override
  Future<String> startSession(SessionConfig config) async {
    startAttempts++;
    throw Exception(message);
  }
}

/// Bridge that starts fine but pushes a mid-session capture notice, as the
/// engine does when one stream dies while recording.
class _NoticeBridge extends NoopBridge {
  final notices = StreamController<SessionNotice>.broadcast();

  @override
  Stream<SessionNotice> noticeStream(String sessionId) => notices.stream;
}

void main() {
  /// The GUI bug this guards: the record button sat on "⚡ Memulai..." while
  /// the engine was wedged, so the user had no way to tell a slow start from
  /// a dead one and no way back to idle.
  testWidgets('a failed start returns the button to idle and shows the error', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = _FailingStartBridge();
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mulai Rekam'), findsOneWidget);
    await tester.tap(find.text('Mulai Rekam'));
    await tester.pumpAndSettle();

    expect(bridge.startAttempts, 1);
    expect(
      find.text('Memulai...'),
      findsNothing,
      reason: 'the button must not stay in its busy state after a failure',
    );
    expect(
      find.text('Mulai Rekam'),
      findsOneWidget,
      reason: 'the button must be pressable again',
    );
    expect(
      find.textContaining('tidak ada sumber audio yang berhasil dibuka'),
      findsOneWidget,
      reason: 'the failure reason has to reach the user, not just the log',
    );

    // Let the toast expire; its dismissal timer outlives the assertions.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a mid-session capture failure is surfaced as a toast', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = _NoticeBridge();
    addTearDown(bridge.notices.close);

    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
      ),
    );
    await tester.pumpAndSettle();

    // `pump`, not `pumpAndSettle`: a recording session runs an elapsed-time
    // timer and a pulsing button animation, so the tree never settles.
    await tester.tap(find.text('Mulai Rekam'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Berhenti'),
      findsOneWidget,
      reason: 'session should be recording',
    );

    bridge.notices.add(
      const SessionNotice(
        level: SessionNoticeLevel.error,
        source: 'mic',
        message:
            'Mikrofon berhenti merekam: perangkat audio terus melaporkan error.',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Mikrofon berhenti merekam'), findsOneWidget);

    // Stop the session so no timer outlives the test, then let the toast go.
    await tester.tap(find.text('Berhenti'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  test(
    'a failed start leaves the session model idle, not half-recording',
    () async {
      final bridge = _FailingStartBridge();
      final container = ProviderContainer(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(sessionProvider.notifier).start(),
        throwsA(isA<Exception>()),
      );

      final state = container.read(sessionProvider);
      expect(state.lifecycle, SessionLifecycle.idle);
      expect(
        state.sessionId,
        isNull,
        reason:
            'a session id from a failed start would leak into stop()/export',
      );
      await settingsToSettle();
    },
  );

  test('the notice provider is empty until a session exists', () async {
    final bridge = _NoticeBridge();
    addTearDown(bridge.notices.close);
    final container = ProviderContainer(
      overrides: [rustBridgeProvider.overrideWithValue(bridge)],
    );
    addTearDown(container.dispose);

    // No session id yet: subscribing must not reach the bridge at all, or
    // every app launch would open a stream for a session that doesn't exist.
    expect(container.read(sessionNoticeProvider).valueOrNull, isNull);
    await settingsToSettle();
  });
}

/// `SettingsNotifier` loads asynchronously; disposing the container before
/// that completes makes it write to a disposed notifier and fail the test on
/// an unrelated error.
Future<void> settingsToSettle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));
