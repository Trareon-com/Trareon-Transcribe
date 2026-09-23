import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/src/rust/audio.dart' as rust_audio;
import 'package:transcribe/src/rust/session.dart' as rust_session;

import 'test_helpers.dart';

/// Bridge that returns a single recoverable session for the recovery-banner test.
class RecoveryBridge extends NoopBridge {
  List<rust_session.SessionRecoverySnapshot> recoveries = const [];

  @override
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions() async =>
      recoveries;
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
          gpuEnabled: false,
          gpuDevice: 0,
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
}