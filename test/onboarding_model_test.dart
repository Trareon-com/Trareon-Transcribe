import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/onboarding_model.dart';
import 'package:transcribe/widgets/model_download_card.dart';

import 'test_helpers.dart';

/// Fake bridge that records download call order and can be configured to
/// fail specific model ids a fixed number of times before succeeding.
class _FakeDownloadBridge extends NoopBridge {
  final List<String> calls = [];
  final Map<String, int> _failuresRemaining;
  final _progressController = StreamController<double>.broadcast();

  _FakeDownloadBridge({Map<String, int> failuresRemaining = const {}})
    : _failuresRemaining = Map.of(failuresRemaining);

  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {
    calls.add(modelId);
    _progressController.add(0.5);
    await Future<void>.delayed(Duration.zero);
    final remaining = _failuresRemaining[modelId] ?? 0;
    if (remaining > 0) {
      _failuresRemaining[modelId] = remaining - 1;
      throw Exception('simulated network error');
    }
  }

  @override
  Stream<double> downloadProgress() => _progressController.stream;
}

void main() {
  test(
    'start() downloads base then large-v3-turbo-q5 in order and reaches allReady',
    () async {
      final bridge = _FakeDownloadBridge();
      final notifier = OnboardingNotifier(bridge);

      await notifier.start();

      expect(bridge.calls, ['base', 'large-v3-turbo-q5']);
      expect(notifier.state.quick.status, DownloadStatus.ready);
      expect(notifier.state.accurate.status, DownloadStatus.ready);
      expect(notifier.state.allReady, isTrue);
    },
  );

  test(
    'a failed base download stops before attempting the accurate model',
    () async {
      final bridge = _FakeDownloadBridge(failuresRemaining: {'base': 1});
      final notifier = OnboardingNotifier(bridge);

      await notifier.start();

      expect(bridge.calls, ['base']);
      expect(notifier.state.quick.status, DownloadStatus.error);
      expect(notifier.state.quick.error, isNotNull);
      expect(notifier.state.accurate.status, DownloadStatus.idle);
      expect(notifier.state.allReady, isFalse);
    },
  );

  test('retryQuick clears the error and resumes through both models', () async {
    final bridge = _FakeDownloadBridge(failuresRemaining: {'base': 1});
    final notifier = OnboardingNotifier(bridge);

    await notifier.start();
    expect(notifier.state.quick.status, DownloadStatus.error);

    await notifier.retryQuick();

    expect(bridge.calls, ['base', 'base', 'large-v3-turbo-q5']);
    expect(notifier.state.quick.status, DownloadStatus.ready);
    expect(notifier.state.accurate.status, DownloadStatus.ready);
    expect(notifier.state.allReady, isTrue);
  });

  test(
    'a failed accurate download leaves the already-ready quick model untouched',
    () async {
      final bridge = _FakeDownloadBridge(
        failuresRemaining: {'large-v3-turbo-q5': 1},
      );
      final notifier = OnboardingNotifier(bridge);

      await notifier.start();

      expect(bridge.calls, ['base', 'large-v3-turbo-q5']);
      expect(notifier.state.quick.status, DownloadStatus.ready);
      expect(notifier.state.accurate.status, DownloadStatus.error);

      await notifier.retryAccurate();

      expect(bridge.calls, ['base', 'large-v3-turbo-q5', 'large-v3-turbo-q5']);
      expect(notifier.state.allReady, isTrue);
    },
  );

  test('concurrent start() calls do not double-download', () async {
    final bridge = _FakeDownloadBridge();
    final notifier = OnboardingNotifier(bridge);

    await Future.wait([notifier.start(), notifier.start()]);

    expect(bridge.calls, ['base', 'large-v3-turbo-q5']);
  });
}
