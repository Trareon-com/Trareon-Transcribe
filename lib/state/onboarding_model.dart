import 'package:flutter_riverpod/legacy.dart';

import '../screens/onboarding_screen.dart';
import '../services/bridge_service.dart';
import '../src/rust/model.dart' as rust_model;
import '../widgets/model_download_card.dart';
import 'download_consent.dart';
import 'models.dart';
import 'privacy_report_model.dart';
import 'settings_model.dart';

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      return OnboardingNotifier(
        ref.watch(rustBridgeProvider),
        onNetworkRequest: ref
            .read(privacyReportProvider.notifier)
            .recordModelDownload,
        consentStore: const DartPrefsDownloadConsentStore(),
        deferOnMetered: () => ref.read(settingsProvider).deferDownloads,
        onDeferChoice: ref.read(settingsProvider.notifier).setDeferDownloads,
      );
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
  OnboardingNotifier(
    this._bridge, {
    required this.onNetworkRequest,
    required DownloadConsentStore consentStore,
    bool Function()? deferOnMetered,
    this.onDeferChoice,
    bool? Function()? networkIsMetered,
  }) : _consent = consentStore,
       _deferOnMetered = deferOnMetered ?? (() => true),
       _networkIsMetered = networkIsMetered ?? (() => null),
       super(OnboardingState.empty);

  final RustBridge _bridge;
  final DownloadConsentStore _consent;

  /// The saved "Tunda kalau koneksi metered" choice (`deferDownloads`).
  final bool Function() _deferOnMetered;

  /// Persists a new "Tunda kalau koneksi metered" choice from the dialog.
  final Future<void> Function(bool)? onDeferChoice;

  /// `null` until the app can detect a metered connection (blueprint §6.2,
  /// phase 2); [shouldStartDownload] only holds back on a definite `true`.
  final bool? Function() _networkIsMetered;

  /// Invoked with the model id immediately before each download starts, so
  /// the Privacy Report counts it. Required, not optional: this is one of
  /// the app's four outbound paths.
  final void Function(String modelId) onNetworkRequest;

  bool _running = false;

  /// Checks what is already on disk, then downloads what is missing, but
  /// only once the user has agreed to it ([grantConsent], now or on an
  /// earlier run). Without that it stops at
  /// [OnboardingPhase.awaitingConsent] or [OnboardingPhase.postponed] and
  /// nothing leaves the machine.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      final modelsDir = defaultModelsCacheDir();
      _applyCatalogSizes(await _bridge.listAvailableModels(modelsDir));
      await _markInstalled(modelsDir);
      if (state.allReady) {
        state = state.copyWith(phase: OnboardingPhase.downloading);
        return;
      }

      final consent = await _consent.read();
      final mayStart = shouldStartDownload(
        now: DateTime.now(),
        networkIsMetered: _networkIsMetered(),
        consent: consent,
        deferOnMetered: _deferOnMetered(),
      );
      if (!mayStart) {
        state = state.copyWith(
          phase: consent == DownloadConsent.notAsked
              ? OnboardingPhase.awaitingConsent
              : OnboardingPhase.postponed,
        );
        return;
      }
      state = state.copyWith(phase: OnboardingPhase.downloading);

      if (state.quick.status != DownloadStatus.ready) {
        await _ensureDownloaded(
          modelId: _quickModelId,
          modelsDir: modelsDir,
          slot: () => state.quick,
          apply: (p) => state = state.copyWith(quick: p),
        );
      }
      if (state.quick.status == DownloadStatus.ready &&
          state.accurate.status != DownloadStatus.ready) {
        await _ensureDownloaded(
          modelId: _accurateModelId,
          modelsDir: modelsDir,
          slot: () => state.accurate,
          apply: (p) => state = state.copyWith(accurate: p),
        );
      }
    } finally {
      _running = false;
    }
  }

  /// "Unduh sekarang" in the consent dialog: remembers the answer so the
  /// dialog does not come back, saves the metered choice, and downloads.
  Future<void> grantConsent({required bool deferOnMetered}) async {
    await _consent.write(DownloadConsent.granted);
    await onDeferChoice?.call(deferOnMetered);
    await start();
  }

  /// "Nanti": remembers the answer and downloads nothing. The download is
  /// offered again where a model is needed (recording), or from
  /// [OnboardingPhase.postponed] via [grantConsent].
  Future<void> postpone({required bool deferOnMetered}) async {
    await _consent.write(DownloadConsent.postponed);
    await onDeferChoice?.call(deferOnMetered);
    state = state.copyWith(phase: OnboardingPhase.postponed);
  }

  /// Marks models that are already on disk as ready, so neither the dialog
  /// nor its total counts something that will not be downloaded.
  Future<void> _markInstalled(String modelsDir) async {
    if (await _bridge.isModelDownloaded(modelsDir, _quickModelId)) {
      state = state.copyWith(
        quick: state.quick.copyWith(status: DownloadStatus.ready, progress: 1),
      );
    }
    if (await _bridge.isModelDownloaded(modelsDir, _accurateModelId)) {
      state = state.copyWith(
        accurate: state.accurate.copyWith(
          status: DownloadStatus.ready,
          progress: 1,
        ),
      );
    }
  }

  /// What "Unduh sekarang" would fetch: the plan minus what is installed.
  List<DownloadPlanItem> get pendingDownloads => [
    for (final item in kFirstRunDownloadPlan)
      if (!_isReady(item.modelId)) item,
  ];

  bool _isReady(String modelId) => switch (modelId) {
    _quickModelId => state.quick.status == DownloadStatus.ready,
    _accurateModelId => state.accurate.status == DownloadStatus.ready,
    _ => false,
  };

  /// Fills in each card's size label from the catalog's on-disk sizes, once
  /// known (a not-yet-downloaded model reports 0 bytes and is left as-is).
  void _applyCatalogSizes(List<rust_model.ModelInfo> catalog) {
    final quickSize = _sizeLabelFor(catalog, _quickModelId);
    final accurateSize = _sizeLabelFor(catalog, _accurateModelId);
    state = state.copyWith(
      quick: quickSize == null
          ? state.quick
          : state.quick.copyWith(size: quickSize),
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
    state = state.copyWith(
      quick: state.quick.copyWith(
        status: DownloadStatus.idle,
        progress: 0,
        error: null,
      ),
    );
    await start();
  }

  Future<void> retryAccurate() async {
    state = state.copyWith(
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
      onNetworkRequest(modelId);
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
