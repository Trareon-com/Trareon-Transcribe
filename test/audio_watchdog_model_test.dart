import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/audio_watchdog_model.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/state/settings_model.dart';

import 'test_helpers.dart';

/// Bridge whose vuMeterStream is driven manually by the test via [vuController].
class _FakeVuBridge extends NoopBridge {
  final vuController = StreamController<VuLevel>.broadcast();

  @override
  Stream<VuLevel> vuMeterStream(String sessionId) => vuController.stream;
}

void main() {
  test('warns after the delay when no signal arrives on an enabled source', () async {
    final bridge = _FakeVuBridge();
    final container = ProviderContainer(
      overrides: [
        rustBridgeProvider.overrideWithValue(bridge),
        audioWatchdogProvider.overrideWith(
          (ref) => AudioWatchdogNotifier(ref, silenceWarningDelay: const Duration(milliseconds: 30)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(audioWatchdogProvider, (_, _) {}); // force provider init

    await container.read(sessionProvider.notifier).start();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(container.read(audioWatchdogProvider), isNotNull);
  });

  test('does not warn once real signal has been seen', () async {
    final bridge = _FakeVuBridge();
    final container = ProviderContainer(
      overrides: [
        rustBridgeProvider.overrideWithValue(bridge),
        audioWatchdogProvider.overrideWith(
          (ref) => AudioWatchdogNotifier(ref, silenceWarningDelay: const Duration(milliseconds: 30)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(audioWatchdogProvider, (_, _) {});

    await container.read(sessionProvider.notifier).start();
    bridge.vuController.add(const VuLevel(micLevel: 0.4, speakerLevel: 0.0));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(container.read(audioWatchdogProvider), isNull);
  });

  test('does not warn once the session has stopped', () async {
    final bridge = _FakeVuBridge();
    final container = ProviderContainer(
      overrides: [
        rustBridgeProvider.overrideWithValue(bridge),
        audioWatchdogProvider.overrideWith(
          (ref) => AudioWatchdogNotifier(ref, silenceWarningDelay: const Duration(milliseconds: 30)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(audioWatchdogProvider, (_, _) {});

    await container.read(sessionProvider.notifier).start();
    await container.read(sessionProvider.notifier).stop();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(container.read(audioWatchdogProvider), isNull);
  });

  test('acknowledge() clears the warning', () async {
    final bridge = _FakeVuBridge();
    final container = ProviderContainer(
      overrides: [
        rustBridgeProvider.overrideWithValue(bridge),
        audioWatchdogProvider.overrideWith(
          (ref) => AudioWatchdogNotifier(ref, silenceWarningDelay: const Duration(milliseconds: 30)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(audioWatchdogProvider, (_, _) {});

    await container.read(sessionProvider.notifier).start();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(container.read(audioWatchdogProvider), isNotNull);

    container.read(audioWatchdogProvider.notifier).acknowledge();
    expect(container.read(audioWatchdogProvider), isNull);
  });
}
