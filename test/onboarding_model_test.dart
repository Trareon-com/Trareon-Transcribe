import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/onboarding_screen.dart';
import 'package:transcribe/state/download_consent.dart';
import 'package:transcribe/state/onboarding_model.dart';
import 'package:transcribe/widgets/model_download_card.dart';

import 'test_helpers.dart';

/// Fake bridge that records download call order and can be configured to
/// fail specific model ids a fixed number of times before succeeding.
class _FakeDownloadBridge extends NoopBridge {
  final List<String> calls = [];
  final Map<String, int> _failuresRemaining;
  final _progressController = StreamController<double>.broadcast();

  _FakeDownloadBridge({
    Map<String, int> failuresRemaining = const {},
    this.installed = const {},
  }) : _failuresRemaining = Map.of(failuresRemaining);

  /// Models already on disk before onboarding starts.
  final Set<String> installed;

  @override
  Future<bool> isModelDownloaded(String modelsDir, String modelId) async =>
      installed.contains(modelId);

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
      final recorded = <String>[];
      final bridge = _FakeDownloadBridge();
      final notifier = OnboardingNotifier(
        bridge,
        onNetworkRequest: recorded.add,
        consentStore: MemoryDownloadConsentStore(DownloadConsent.granted),
      );

      await notifier.start();

      expect(bridge.calls, ['base', 'large-v3-turbo-q5']);
      // Every download reports itself to the Privacy Report first.
      expect(recorded, ['base', 'large-v3-turbo-q5']);
      expect(notifier.state.quick.status, DownloadStatus.ready);
      expect(notifier.state.accurate.status, DownloadStatus.ready);
      expect(notifier.state.allReady, isTrue);
    },
  );

  test(
    'a failed base download stops before attempting the accurate model',
    () async {
      final recorded = <String>[];
      final bridge = _FakeDownloadBridge(failuresRemaining: {'base': 1});
      final notifier = OnboardingNotifier(
        bridge,
        onNetworkRequest: recorded.add,
        consentStore: MemoryDownloadConsentStore(DownloadConsent.granted),
      );

      await notifier.start();

      expect(bridge.calls, ['base']);
      expect(notifier.state.quick.status, DownloadStatus.error);
      expect(notifier.state.quick.error, isNotNull);
      expect(notifier.state.accurate.status, DownloadStatus.idle);
      expect(notifier.state.allReady, isFalse);
    },
  );

  test('retryQuick clears the error and resumes through both models', () async {
    final recorded = <String>[];
    final bridge = _FakeDownloadBridge(failuresRemaining: {'base': 1});
    final notifier = OnboardingNotifier(
      bridge,
      onNetworkRequest: recorded.add,
      consentStore: MemoryDownloadConsentStore(DownloadConsent.granted),
    );

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
      final recorded = <String>[];
      final bridge = _FakeDownloadBridge(
        failuresRemaining: {'large-v3-turbo-q5': 1},
      );
      final notifier = OnboardingNotifier(
        bridge,
        onNetworkRequest: recorded.add,
        consentStore: MemoryDownloadConsentStore(DownloadConsent.granted),
      );

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
    final recorded = <String>[];
    final bridge = _FakeDownloadBridge();
    final notifier = OnboardingNotifier(
      bridge,
      onNetworkRequest: recorded.add,
      consentStore: MemoryDownloadConsentStore(DownloadConsent.granted),
    );

    await Future.wait([notifier.start(), notifier.start()]);

    expect(bridge.calls, ['base', 'large-v3-turbo-q5']);
  });

  group('download consent (issue #70)', () {
    test('without an answer nothing downloads and the dialog is due', () async {
      final recorded = <String>[];
      final bridge = _FakeDownloadBridge();
      final notifier = OnboardingNotifier(
        bridge,
        onNetworkRequest: recorded.add,
        consentStore: MemoryDownloadConsentStore(),
      );

      await notifier.start();

      expect(bridge.calls, isEmpty);
      expect(recorded, isEmpty);
      expect(notifier.state.phase, OnboardingPhase.awaitingConsent);
      expect(
        notifier.pendingDownloads.map((i) => i.modelId),
        ['base', 'large-v3-turbo-q5'],
      );
    });

    test('"Nanti" downloads nothing and is remembered', () async {
      final recorded = <String>[];
      final bridge = _FakeDownloadBridge();
      final store = MemoryDownloadConsentStore();
      final deferChoices = <bool>[];
      final notifier = OnboardingNotifier(
        bridge,
        onNetworkRequest: recorded.add,
        consentStore: store,
        onDeferChoice: (v) async => deferChoices.add(v),
      );

      await notifier.start();
      await notifier.postpone(deferOnMetered: false);

      expect(bridge.calls, isEmpty);
      expect(recorded, isEmpty);
      expect(store.consent, DownloadConsent.postponed);
      expect(deferChoices, [false]);
      expect(notifier.state.phase, OnboardingPhase.postponed);

      // A later launch does not ask again and still downloads nothing.
      final again = OnboardingNotifier(
        bridge,
        onNetworkRequest: recorded.add,
        consentStore: store,
      );
      await again.start();
      expect(bridge.calls, isEmpty);
      expect(again.state.phase, OnboardingPhase.postponed);
    });

    test('"Unduh sekarang" downloads and the dialog never returns', () async {
      final recorded = <String>[];
      final bridge = _FakeDownloadBridge();
      final store = MemoryDownloadConsentStore();
      final notifier = OnboardingNotifier(
        bridge,
        onNetworkRequest: recorded.add,
        consentStore: store,
      );

      await notifier.start();
      await notifier.grantConsent(deferOnMetered: true);

      expect(store.consent, DownloadConsent.granted);
      expect(bridge.calls, ['base', 'large-v3-turbo-q5']);
      expect(recorded, ['base', 'large-v3-turbo-q5']);
      expect(notifier.state.allReady, isTrue);
    });

    test('installed models are not asked about or counted', () async {
      final bridge = _FakeDownloadBridge(installed: {'base'});
      final notifier = OnboardingNotifier(
        bridge,
        onNetworkRequest: (_) {},
        consentStore: MemoryDownloadConsentStore(),
      );

      await notifier.start();

      expect(notifier.state.quick.status, DownloadStatus.ready);
      expect(
        notifier.pendingDownloads.map((i) => i.modelId),
        ['large-v3-turbo-q5'],
      );
    });

    test('everything installed skips the dialog entirely', () async {
      final bridge = _FakeDownloadBridge(
        installed: {'base', 'large-v3-turbo-q5'},
      );
      final notifier = OnboardingNotifier(
        bridge,
        onNetworkRequest: (_) {},
        consentStore: MemoryDownloadConsentStore(),
      );

      await notifier.start();

      expect(notifier.state.allReady, isTrue);
      expect(notifier.state.phase, isNot(OnboardingPhase.awaitingConsent));
      expect(bridge.calls, isEmpty);
    });
  });

  group('shouldStartDownload', () {
    final now = DateTime(2026, 11, 27);

    test('needs a granted consent', () {
      for (final consent in [
        DownloadConsent.notAsked,
        DownloadConsent.postponed,
      ]) {
        expect(
          shouldStartDownload(
            now: now,
            networkIsMetered: false,
            consent: consent,
            deferOnMetered: false,
          ),
          isFalse,
        );
      }
    });

    test('holds back only on a known metered network when asked to', () {
      bool decide(bool? metered, bool defer) => shouldStartDownload(
        now: now,
        networkIsMetered: metered,
        consent: DownloadConsent.granted,
        deferOnMetered: defer,
      );
      expect(decide(true, true), isFalse);
      expect(decide(true, false), isTrue);
      expect(decide(false, true), isTrue);
      // Phase 1 cannot detect metered connections; unknown must not block.
      expect(decide(null, true), isTrue);
    });

    test('the first-run plan totals both models', () {
      expect(totalMegabytes(kFirstRunDownloadPlan), 690);
    });
  });
}
