import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/onboarding_screen.dart';
import '../services/bridge_service.dart';
import '../widgets/model_download_card.dart';
import 'models.dart';
import 'settings_model.dart';

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      return OnboardingNotifier(ref.watch(rustBridgeProvider));
    });

/// Drives the two bundled-model downloads (`base` then `large-v3-turbo-q5`)
/// shown on [OnboardingScreen]. Sequential, not parallel: the underlying
/// Rust download tracker (`DOWNLOAD_PROGRESS`) is a single global slot, so
/// concurrent downloads would scramble each other's progress.
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._bridge) : super(OnboardingState.empty);

  final RustBridge _bridge;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      if (state.quick.status != DownloadStatus.ready) {
        await _download(
          modelId: 'base',
          slot: () => state.quick,
          apply: (p) =>
              state = OnboardingState(quick: p, accurate: state.accurate),
        );
      }
      if (state.quick.status == DownloadStatus.ready &&
          state.accurate.status != DownloadStatus.ready) {
        await _download(
          modelId: 'large-v3-turbo-q5',
          slot: () => state.accurate,
          apply: (p) =>
              state = OnboardingState(quick: state.quick, accurate: p),
        );
      }
    } finally {
      _running = false;
    }
  }

  Future<void> retryQuick() async {
    state = OnboardingState(
      quick: state.quick.copyWith(
        status: DownloadStatus.idle,
        progress: 0,
        error: null,
      ),
      accurate: state.accurate,
    );
    await start();
  }

  Future<void> retryAccurate() async {
    state = OnboardingState(
      quick: state.quick,
      accurate: state.accurate.copyWith(
        status: DownloadStatus.idle,
        progress: 0,
        error: null,
      ),
    );
    await start();
  }

  Future<void> _download({
    required String modelId,
    required DownloadProgress Function() slot,
    required void Function(DownloadProgress) apply,
  }) async {
    apply(
      slot().copyWith(
        status: DownloadStatus.downloading,
        progress: 0,
        error: null,
      ),
    );

    final subscription = _bridge.downloadProgress().listen((ratio) {
      apply(slot().copyWith(progress: ratio.clamp(0.0, 1.0)));
    });

    try {
      await _bridge.downloadModel(defaultModelsCacheDir(), modelId);
      apply(slot().copyWith(status: DownloadStatus.ready, progress: 1.0));
    } catch (e) {
      apply(
        slot().copyWith(
          status: DownloadStatus.error,
          error: 'Gagal mengunduh: $e',
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }
}
