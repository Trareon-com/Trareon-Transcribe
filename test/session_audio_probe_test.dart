// Issue #69: before a session starts, the microphone is measured and the
// quality resolver's noise-reduction / AGC decision is applied to it.

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/quality_profile.dart';
import 'package:transcribe/state/session_model.dart';

import 'test_helpers.dart';

class _ProbeBridge extends NoopBridge {
  _ProbeBridge(this.measurement, {this.throws = false});

  final AudioMeasurement? measurement;
  final bool throws;
  final probes = <int>[];
  final tunings = <({bool nr, bool agc})>[];
  bool startedAfterProbe = false;

  @override
  Future<AudioMeasurement?> probeAudioInput(
    String? deviceName,
    int millis,
  ) async {
    probes.add(millis);
    if (throws) throw Exception('no device');
    return measurement;
  }

  @override
  Future<void> setSessionAudioTuning({
    required bool noiseReduction,
    required bool agc,
  }) async => tunings.add((nr: noiseReduction, agc: agc));

  @override
  Future<String> startSession(SessionConfig config) async {
    startedAfterProbe = probes.isNotEmpty;
    return super.startSession(config);
  }
}

SessionNotifier _notifier(_ProbeBridge bridge, {bool auto = true}) {
  final notifier = SessionNotifier(
    bridge,
    SessionMode.offline,
    modelPathForId('tiny'),
  );
  notifier.syncDefaultSettings(
    AppSettings.defaults().copyWith(
      defaultMode: SessionMode.offline,
      autoAudioTuning: auto,
    ),
  );
  return notifier;
}

void main() {
  test(
    'a noisy room turns noise reduction on before the session starts',
    () async {
      final bridge = _ProbeBridge(
        const AudioMeasurement(snrDb: 8, peakDbfs: -12),
      );
      final notifier = _notifier(bridge);

      await notifier.start();

      expect(bridge.probes, [SessionNotifier.probeMillis]);
      expect(bridge.startedAfterProbe, isTrue);
      expect(bridge.tunings.single.nr, isTrue);
      expect(notifier.state.probingAudio, isFalse);
      expect(notifier.state.lifecycle, SessionLifecycle.recording);
    },
  );

  test('a clean room leaves noise reduction and AGC off', () async {
    final bridge = _ProbeBridge(
      const AudioMeasurement(snrDb: 32, peakDbfs: -18),
    );
    await _notifier(bridge).start();
    expect(bridge.tunings.single, (nr: false, agc: false));
  });

  test('a failed probe still starts the session, conservatively', () async {
    final bridge = _ProbeBridge(null, throws: true);
    final notifier = _notifier(bridge);

    await notifier.start();

    expect(notifier.state.lifecycle, SessionLifecycle.recording);
    expect(bridge.tunings.single, (nr: false, agc: false));
  });

  test('manual tuning is never overridden by a probe', () async {
    final bridge = _ProbeBridge(
      const AudioMeasurement(snrDb: 8, peakDbfs: -12),
    );
    await _notifier(bridge, auto: false).start();
    expect(bridge.probes, isEmpty);
    expect(bridge.tunings, isEmpty);
  });
}
