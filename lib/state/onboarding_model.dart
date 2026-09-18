import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/onboarding_screen.dart';
import '../services/bridge_service.dart';
import '../src/rust/model.dart' as rust_model;
import '../widgets/model_download_card.dart';
import 'models.dart';
import 'settings_model.dart';

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      return OnboardingNotifier(ref.watch(rustBridgeProvider));
    });

/// Which two catalog entries onboarding downloads — `base` for the
/// fast/progressive pass, `large-v3-turbo-q5` for the accurate refine pass.
/// This choice is a product decision, not catalog data; everything else
/// about these models (size, availability) comes from the Rust catalog.
const _quickModelId = 'base';
const _accurateModelId = 'large-v3-turbo-q5';

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
      final modelsDir = defaultModelsCacheDir();
      _applyCatalogSizes(await _bridge.listAvailableModels(modelsDir));

      if (state.quick.status != DownloadStatus.ready) {
        await _ensureDownloaded(
          modelId: _quickModelId,
          modelsDir: modelsDir,
          slot: () => state.quick,
          apply: (p) =>
              state = OnboardingState(quick: p, accurate: state.accurate),
        );
      }
      if (state.quick.status == DownloadStatus.ready &&
          state.accurate.status != DownloadStatus.ready) {
        await _ensureDownloaded(
          modelId: _accurateModelId,
          modelsDir: modelsDir,
          slot: () => state.accurate,
          apply: (p) =>
              state = OnboardingState(quick: state.quick, accurate: p),
        );
      }
    } finally {
      _running = false;
    }
  }

  /// Fills in each card's size label from the catalog's on-disk sizes, once
  /// known (a not-yet-downloaded model reports 0 bytes and is left as-is).
  void _applyCatalogSizes(List<rust_model.ModelInfo> catalog) {
    final quickSize = _sizeLabelFor(catalog, _quickModelId);
    final accurateSize = _sizeLabelFor(catalog, _accurateModelId);
    state = OnboardingState(
      quick: quickSize == null ? state.quick : state.quick.copyWith(size: quickSize),
      accurate: accurateSize == null
          ? state.accurate
          : state.accurate.copyWith(size: accurateSize),
    );
  }

  String? _sizeLabelFor(List<rust_model.ModelInfo> catalog, String modelId) {
    for (final model in catalog) {
      if (model.id == modelId && model.sizeBytes > BigInt.zero) {
        return _formatBytes(model.sizeBytes);
      }
    }
    return null;
  }

  /// Skips the download entirely when the catalog already has the file on
  /// disk (e.g. a previous run completed it), instead of re-downloading.
  Future<void> _ensureDownloaded({
    required String modelId,
    required String modelsDir,
    required DownloadProgress Function() slot,
    required void Function(DownloadProgress) apply,
  }) async {
    if (await _bridge.isModelDownloaded(modelsDir, modelId)) {
      apply(slot().copyWith(status: DownloadStatus.ready, progress: 1.0));
      return;
    }
    await _download(modelId: modelId, slot: slot, apply: apply);
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

/// Formats a byte count from the catalog as a whole-number MB/GB label
/// (e.g. `142 MB`), matching the style of the labels this replaces.
String _formatBytes(BigInt bytes) {
  const bytesPerMb = 1024 * 1024;
  final megabytes = bytes.toDouble() / bytesPerMb;
  if (megabytes >= 1024) {
    return '${(megabytes / 1024).toStringAsFixed(1)} GB';
  }
  return '${megabytes.toStringAsFixed(0)} MB';
}
