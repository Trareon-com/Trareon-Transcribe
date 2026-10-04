import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/src/rust/audio.dart' as rust_audio;
import 'package:transcribe/src/rust/session.dart' as rust_session;

import 'test_helpers.dart';

/// Bridge whose session launches do not complete until the test says so, so
/// the window between "launch requested" and "lifecycle == recording" is
/// held open on purpose — that window is where the race lived.
class _SlowLaunchBridge extends NoopBridge {
  final List<SessionConfig> started = [];
  final List<String> recovered = [];
  final Completer<void> release = Completer<void>();

  @override
  Future<String> startSession(SessionConfig config) async {
    started.add(config);
    await release.future;
    return 'session-${started.length}';
  }

  @override
  Future<rust_session.RecoveredSession> recoverSession(
    rust_session.SessionRecoverySnapshot snapshot,
  ) async {
    recovered.add(snapshot.sessionId);
    await release.future;
    return rust_session.RecoveredSession(
      sessionId: 'recovered-${recovered.length}',
      segments: const [],
      resumeOffsetSecs: 0,
      micAudioSecs: 0,
      speakerAudioSecs: 0,
    );
  }
}

void main() {
  test('a double-tapped Mulai starts exactly one Rust session', () async {
    final bridge = _SlowLaunchBridge();
    final notifier = SessionNotifier(
      bridge,
      SessionMode.online,
      modelPathForId('tiny'),
    );
    addTearDown(notifier.dispose);

    // Both calls are issued before either finishes — a double-click, or
    // Ctrl+R held down. `lifecycle` is still `idle` for the second one, so
    // the lifecycle check alone let it through and a second live Rust
    // session was spawned. The first then had no id anywhere in Dart: its
    // capture threads and registry entry kept recording until app exit.
    final first = notifier.start();
    final second = notifier.start();

    bridge.release.complete();
    await Future.wait([first, second]);

    expect(
      bridge.started.length,
      1,
      reason: 'the second call must be refused while the first is in flight',
    );
    expect(notifier.state.lifecycle, SessionLifecycle.recording);
    expect(notifier.state.sessionId, 'session-1');
  });

  test('recovering twice in a row recovers exactly one session', () async {
    final bridge = _SlowLaunchBridge();
    final notifier = SessionNotifier(
      bridge,
      SessionMode.online,
      modelPathForId('tiny'),
    );
    addTearDown(notifier.dispose);
    final snapshot = recoverySnapshot('crash-1');

    final first = notifier.recoverFromSnapshot(snapshot);
    final second = notifier.recoverFromSnapshot(snapshot);

    bridge.release.complete();
    final results = await Future.wait([first, second]);

    expect(bridge.recovered.length, 1);
    expect(results.where((r) => r != null).length, 1);
    expect(notifier.state.sessionId, 'recovered-1');
  });

  test('a start and a recovery racing each other produce one session', () async {
    final bridge = _SlowLaunchBridge();
    final notifier = SessionNotifier(
      bridge,
      SessionMode.online,
      modelPathForId('tiny'),
    );
    addTearDown(notifier.dispose);

    final start = notifier.start();
    final recover = notifier.recoverFromSnapshot(recoverySnapshot('crash-1'));

    bridge.release.complete();
    await start;
    expect(await recover, isNull, reason: 'the recovery must stand down');

    expect(bridge.started.length, 1);
    expect(
      bridge.recovered,
      isEmpty,
      reason: 'recovering over a starting session orphans its Rust capture',
    );
  });

  test('a failed start leaves the app able to try again', () async {
    final notifier = SessionNotifier(
      _ThrowingStartBridge(),
      SessionMode.online,
      modelPathForId('tiny'),
    );
    addTearDown(notifier.dispose);

    await expectLater(notifier.start(), throwsA(isA<StateError>()));
    // The guard is cleared in a `finally`, so the retry is not locked out.
    await expectLater(notifier.start(), throwsA(isA<StateError>()));
  });
}

class _ThrowingStartBridge extends NoopBridge {
  @override
  Future<String> startSession(SessionConfig config) async =>
      throw StateError('no audio source could be opened');
}

rust_session.SessionRecoverySnapshot recoverySnapshot(String id) =>
    rust_session.SessionRecoverySnapshot(
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
        glossary: kEmptyGlossary,
      ),
      startedAtUnixMs: BigInt.from(1700000000000),
      lastSplitAtUnixMs: BigInt.from(1700000000000),
      segmentsCount: 0,
      title: 'Rapat Anggaran',
      updatedAtUnixMs: BigInt.from(1700000000000),
      elapsedSecs: 0,
      micCounters: rust_session.ChannelCounters(
        totalSamples: BigInt.zero,
        voicedSamples: BigInt.zero,
      ),
      speakerCounters: rust_session.ChannelCounters(
        totalSamples: BigInt.zero,
        voicedSamples: BigInt.zero,
      ),
    );
