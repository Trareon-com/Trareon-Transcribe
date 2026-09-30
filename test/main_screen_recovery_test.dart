import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/src/rust/audio.dart' as rust_audio;
import 'package:transcribe/src/rust/session.dart' as rust_session;

import 'test_helpers.dart';

/// Bridge serving a fixed set of recoverable sessions, and recording what
/// the UI asked it to do with them.
class RecoveryBridge extends NoopBridge {
  List<rust_session.RecoverableSession> recoveries = const [];
  final List<String> deleted = [];
  final List<String> recovered = [];

  @override
  Future<List<rust_session.RecoverableSession>> listRecoverableSessions() async =>
      recoveries;

  @override
  Future<void> deleteRecoverableSession(String sessionId) async {
    deleted.add(sessionId);
  }

  @override
  Future<rust_session.RecoveredSession> recoverSession(
    rust_session.SessionRecoverySnapshot snapshot,
  ) async {
    recovered.add(snapshot.sessionId);
    return rust_session.RecoveredSession(
      sessionId: snapshot.sessionId,
      segments: const [],
      resumeOffsetSecs: 5400,
      micAudioSecs: 5400,
      speakerAudioSecs: 0,
    );
  }
}

rust_session.RecoverableSession recoverable({
  required String id,
  required String title,
  int segmentCount = 42,
  double micAudioSecs = 5400,
  double durationSecs = 5400,
}) {
  return rust_session.RecoverableSession(
    snapshot: rust_session.SessionRecoverySnapshot(
      sessionId: id,
      config: const rust_audio.SessionConfig(
        micEnabled: true,
        speakerEnabled: false,
        mode: rust_audio.SessionMode.offline,
        modelPath: 'models/tiny.gguf',
        hptMode: rust_audio.HptMode.auto,
        gpuEnabled: false,
        gpuDevice: 0,
        vadEnabled: true,
        audioToDisk: true,
      ),
      startedAtUnixMs: BigInt.from(1700000000000),
      lastSplitAtUnixMs: BigInt.from(1700000000000),
      segmentsCount: segmentCount,
      title: title,
      updatedAtUnixMs: BigInt.from(1700000000000 + 5400000),
      elapsedSecs: durationSecs,
    ),
    title: title,
    startedAtUnixMs: BigInt.from(1700000000000),
    updatedAtUnixMs: BigInt.from(1700000000000 + 5400000),
    durationSecs: durationSecs,
    segmentCount: segmentCount,
    micAudioSecs: micAudioSecs,
    speakerAudioSecs: 0,
  );
}

/// Lets the toast's dismiss delay expire and tears the tree down, so the
/// capture-health poll timer a recovered session starts is disposed
/// rather than reported as a leaked pending timer.
Future<void> settleAndDispose(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> pumpMain(WidgetTester tester, RecoveryBridge bridge) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    buildTestAppWithOverrides(
      overrides: [rustBridgeProvider.overrideWithValue(bridge)],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the banner says what is recoverable, not just how many', (
    WidgetTester tester,
  ) async {
    final bridge = RecoveryBridge()
      ..recoveries = [recoverable(id: 'crash-1', title: 'Rapat Anggaran')];

    await pumpMain(tester, bridge);

    // The old banner said "Ada 1 sesi yang bisa dipulihkan" while
    // recovering nothing at all.
    expect(find.textContaining('42 segmen transkrip'), findsOneWidget);
    expect(find.textContaining('1 jam 30 menit audio'), findsOneWidget);
    expect(find.text('Lihat & pulihkan'), findsOneWidget);
  });

  testWidgets('the dialog lists each session with its own contents', (
    WidgetTester tester,
  ) async {
    final bridge = RecoveryBridge()
      ..recoveries = [
        recoverable(id: 'crash-1', title: 'Rapat Anggaran'),
        recoverable(
          id: 'crash-2',
          title: 'Webinar Sore',
          segmentCount: 3,
          micAudioSecs: 0,
          durationSecs: 120,
        ),
      ];

    await pumpMain(tester, bridge);
    await tester.tap(find.text('Lihat & pulihkan'));
    await tester.pumpAndSettle();

    expect(find.text('Rapat Anggaran'), findsOneWidget);
    expect(find.text('Webinar Sore'), findsOneWidget);
    expect(find.textContaining('42 segmen transkrip'), findsOneWidget);
    expect(find.textContaining('tanpa rekaman audio'), findsOneWidget);
    // Per-session actions, not one button acting on the first entry.
    expect(find.text('Pulihkan'), findsNWidgets(2));
    expect(find.text('Hapus'), findsNWidgets(2));
    await tester.tap(find.text('Nanti saja'));
    await tester.pumpAndSettle();
  });

  testWidgets('Hapus deletes that session and drops it from the list', (
    WidgetTester tester,
  ) async {
    final bridge = RecoveryBridge()
      ..recoveries = [
        recoverable(id: 'crash-1', title: 'Rapat Anggaran'),
        recoverable(id: 'crash-2', title: 'Webinar Sore'),
      ];

    await pumpMain(tester, bridge);
    await tester.tap(find.text('Lihat & pulihkan'));
    await tester.pumpAndSettle();
    // Second tile's delete button.
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();

    expect(bridge.deleted, ['crash-2']);
    await tester.tap(find.text('Lihat & pulihkan'));
    await tester.pumpAndSettle();
    expect(find.text('Webinar Sore'), findsNothing);
    expect(find.text('Rapat Anggaran'), findsOneWidget);
    await tester.tap(find.text('Nanti saja'));
    await settleAndDispose(tester);
  });

  testWidgets('Pulihkan restores the session the user picked', (
    WidgetTester tester,
  ) async {
    final bridge = RecoveryBridge()
      ..recoveries = [
        recoverable(id: 'crash-1', title: 'Rapat Anggaran'),
        recoverable(id: 'crash-2', title: 'Webinar Sore'),
      ];

    await pumpMain(tester, bridge);
    await tester.tap(find.text('Lihat & pulihkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pulihkan').last);
    await tester.pump();
    await tester.pump();

    // Not `crash-1`: the old banner always acted on the first entry.
    expect(bridge.recovered, ['crash-2']);
    await settleAndDispose(tester);
  });

  testWidgets('a session with nothing left is flagged rather than promised', (
    WidgetTester tester,
  ) async {
    final bridge = RecoveryBridge()
      ..recoveries = [
        recoverable(
          id: 'crash-empty',
          title: 'Sesi Kosong',
          segmentCount: 0,
          micAudioSecs: 0,
          durationSecs: 8,
        ),
      ];

    await pumpMain(tester, bridge);
    expect(
      find.textContaining('tanpa transkrip atau audio yang tersisa'),
      findsOneWidget,
    );

    await tester.tap(find.text('Lihat & pulihkan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('transkrip kosong'), findsOneWidget);
    await tester.tap(find.text('Nanti saja'));
    await tester.pumpAndSettle();
  });
}
