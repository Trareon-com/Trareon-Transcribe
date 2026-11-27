import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/models.dart';
import '../state/privacy_report_model.dart';
import '../state/settings_model.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'app_toast.dart';
import 'settings_controls.dart';
import 'ui/app_button.dart';

/// One downloadable engine asset that is not a transcription model.
///
/// The Silero voice-activity model and the two speaker-diarization models
/// are not choices — they are capabilities that are either installed or
/// not. They do not belong in the model dropdown (nobody picks a 28 MB
/// speaker-embedding network as their transcriber), but they do need a
/// visible, explicit download affordance: the app does not fetch anything
/// the user has not asked for, and the Privacy Report has to be able to
/// account for every byte that crosses the network.
class _Asset {
  final String id;

  /// What the user gets. Not what the file is.
  final IconData icon;

  const _Asset({required this.id, required this.icon});

  String title(AppLocalizations l10n) => switch (id) {
    'silero-vad' => l10n.engineAssetsSectionVadTitle,
    'diarization-segmentation' => l10n.engineAssetsSectionSegmentationTitle,
    _ => l10n.engineAssetsSectionEmbeddingTitle,
  };

  String subtitle(AppLocalizations l10n) => switch (id) {
    'silero-vad' => l10n.engineAssetsSectionVadSubtitle,
    'diarization-segmentation' => l10n.engineAssetsSectionSegmentationSubtitle,
    _ => l10n.engineAssetsSectionEmbeddingSubtitle,
  };
}

const _vadAsset = _Asset(id: 'silero-vad', icon: AppIcons.waveform);

const _diarizationAssets = [
  _Asset(id: 'diarization-segmentation', icon: AppIcons.people),
  _Asset(id: 'diarization-embedding', icon: AppIcons.people),
];

/// Settings rows for the engine assets: the VAD gate and the optional
/// accurate speaker separation.
class EngineAssetsSection extends ConsumerStatefulWidget {
  const EngineAssetsSection({super.key});

  @override
  ConsumerState<EngineAssetsSection> createState() =>
      _EngineAssetsSectionState();
}

class _EngineAssetsSectionState extends ConsumerState<EngineAssetsSection> {
  /// `assetId -> installed`. Null until the first probe finishes, so the UI
  /// says "memeriksa…" instead of claiming the asset is missing.
  Map<String, bool>? _installed;

  /// Asset currently downloading, or null.
  String? _downloading;
  double _progress = 0;
  StreamSubscription<double>? _progressSub;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_probe());
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  String get _modelsDir {
    final libraryPath = ref.read(settingsProvider).libraryPath;
    return libraryPath.isEmpty ? defaultModelsCacheDir() : libraryPath;
  }

  Future<void> _probe() async {
    final bridge = ref.read(rustBridgeProvider);
    final dir = _modelsDir;
    final result = <String, bool>{};
    for (final asset in [_vadAsset, ..._diarizationAssets]) {
      try {
        result[asset.id] = await bridge.isModelDownloaded(dir, asset.id);
      } catch (_) {
        // An engine that cannot answer is not an engine that says "no".
        result[asset.id] = false;
      }
    }
    if (mounted) setState(() => _installed = result);
  }

  Future<void> _download(_Asset asset) async {
    if (_downloading != null) return;
    final bridge = ref.read(rustBridgeProvider);
    setState(() {
      _downloading = asset.id;
      _progress = 0;
      _error = null;
    });
    // Recorded before the request, not after: the Privacy Report exists to
    // account for what the app did, including an attempt that failed.
    ref.read(privacyReportProvider.notifier).recordModelDownload(asset.id);
    _progressSub?.cancel();
    _progressSub = bridge.downloadProgress().listen((value) {
      if (mounted) setState(() => _progress = value);
    });
    try {
      await bridge.downloadModel(_modelsDir, asset.id);
      // Re-apply the settings so the engine picks the new file up now
      // rather than on the next launch: the paths it reads live in process
      // globals that `saveSettings` refreshes.
      await ref.read(settingsProvider.notifier).reapply();
      if (!mounted) return;
      AppToast.show(
        context,
        context.l10n.engineAssetsSectionInstalledToast(
          asset.title(context.l10n),
        ),
        type: ToastType.success,
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      await _progressSub?.cancel();
      _progressSub = null;
      if (mounted) {
        setState(() {
          _downloading = null;
          _progress = 0;
        });
      }
      await _probe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final diarizationReady = _diarizationAssets.every(
      (asset) => _installed?[asset.id] == true,
    );

    return SettingsSection(
      title: context.l10n.engineAssetsSectionTitle,
      children: [
        _row(_vadAsset),
        const SettingsDivider(),
        SettingsSwitch(
          icon: AppIcons.people,
          label: context.l10n.engineAssetsSectionDiarizationLabel,
          subtitle: _diarizationSubtitle(
            settings.neuralDiarization,
            diarizationReady,
          ),
          value: settings.neuralDiarization,
          onChanged: notifier.setNeuralDiarization,
        ),
        for (final asset in _diarizationAssets) ...[
          const SettingsDivider(),
          _row(asset),
        ],
        if (_error != null) ...[
          Spacing.gapSm,
          Text(
            context.l10n.engineAssetsSectionDownloadFailed(_error!),
            style: AppText.caption.c(context.colors.error),
          ),
        ],
      ],
    );
  }

  String _diarizationSubtitle(bool enabled, bool ready) {
    if (!enabled) {
      return context.l10n.engineAssetsSectionDiarizationOff;
    }
    if (!ready) {
      return context.l10n.engineAssetsSectionDiarizationIncomplete;
    }
    return context.l10n.engineAssetsSectionDiarizationReady;
  }

  Widget _row(_Asset asset) {
    final installed = _installed?[asset.id];
    final busy = _downloading == asset.id;
    final l10n = context.l10n;
    return SettingsTile(
      icon: asset.icon,
      label: asset.title(l10n),
      subtitle: busy
          ? l10n.engineAssetsSectionDownloadingPercent(
              (_progress * 100).clamp(0, 100).toStringAsFixed(0),
            )
          : switch (installed) {
              null => l10n.engineAssetsSectionChecking,
              true => l10n.engineAssetsSectionInstalled(asset.subtitle(l10n)),
              false => l10n.engineAssetsSectionNotDownloaded(
                asset.subtitle(l10n),
              ),
            },
      trailing: switch (installed) {
        true => Icon(
          AppIcons.check,
          size: IconSizes.md,
          color: context.colors.success,
        ),
        _ => AppButton(
          label: busy
              ? l10n.engineAssetsSectionDownloading
              : l10n.engineAssetsSectionDownload,
          variant: AppButtonVariant.secondary,
          onPressed: busy || _downloading != null || installed == null
              ? null
              : () => unawaited(_download(asset)),
        ),
      },
    );
  }
}
