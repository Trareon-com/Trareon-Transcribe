import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/src/rust/audio.dart' as rust_audio;
import 'package:transcribe/src/rust/session.dart' as rust_session;

import 'test_helpers.dart';

/// Bridge that returns a single recoverable session for the recovery-banner test.
class RecoveryBridge extends NoopBridge {
  List<rust_session.SessionRecoverySnapshot> recoveries = const [];
  Object? recoverSessionError;

  @override
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions() async =>
      recoveries;

  @override
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async {
    final error = recoverSessionError;
    if (error != null) throw error;
    return 'test-session';
  }
}

void main() {
  testWidgets('recovery banner shows when sessions are recoverable', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = RecoveryBridge();
    bridge.recoveries = [
      rust_session.SessionRecoverySnapshot(
        sessionId: 'crash-1',
        config: rust_audio.SessionConfig(
          micEnabled: true,
          speakerEnabled: false,
          mode: rust_audio.SessionMode.offline,
          modelPath: 'models/tiny.gguf',
          hptMode: rust_audio.HptMode.auto,
          vadEnabled: true,
          sampleRate: 16000,
          chunkDurationSecs: 30,
        ),
        startedAtUnixMs: BigInt.zero,
        lastSplitAtUnixMs: BigInt.zero,
        segmentsCount: 1,
      ),
    ];

    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          rustBridgeProvider.overrideWithValue(bridge),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('sesi yang bisa dipulihkan'), findsOneWidget);
    expect(find.text('Pulihkan'), findsOneWidget);
  });

  testWidgets('a failed recovery shows an error toast instead of crashing silently',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = RecoveryBridge();
    bridge.recoveries = [
      rust_session.SessionRecoverySnapshot(
        sessionId: 'crash-1',
        config: rust_audio.SessionConfig(
          micEnabled: true,
          speakerEnabled: false,
          mode: rust_audio.SessionMode.offline,
          modelPath: 'models/missing.gguf',
          hptMode: rust_audio.HptMode.auto,
          vadEnabled: true,
          sampleRate: 16000,
          chunkDurationSecs: 30,
        ),
        startedAtUnixMs: BigInt.zero,
        lastSplitAtUnixMs: BigInt.zero,
        segmentsCount: 1,
      ),
    ];
    bridge.recoverSessionError = Exception('model file not found');

    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          rustBridgeProvider.overrideWithValue(bridge),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pulihkan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // toast show animation

    expect(find.textContaining('Gagal memulihkan sesi'), findsOneWidget);
    // The banner must still offer the session for another attempt — a
    // failed recovery silently removing it would lose it for good.
    expect(find.text('Pulihkan'), findsOneWidget);

    // Drain the toast's auto-dismiss timer so no pending Timer remains when
    // the test ends (AppToast schedules Future.delayed(duration, _dismiss)).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}