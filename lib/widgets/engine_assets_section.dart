import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final String title;

  /// What the user gets. Not what the file is.
  final String subtitle;
  final IconData icon;

  const _Asset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const _vadAsset = _Asset(
  id: 'silero-vad',
  title: 'Gerbang suara neural (Silero)',
  subtitle:
      'Memutuskan bagian mana dari rekaman yang berisi suara manusia. '
      'Tanpa ini Trareon memakai detektor energi sederhana, yang kadang '
      'meloloskan derau ruangan, dan Whisper menjawab derau dengan '
      'kalimat karangan. 0,9 MB.',
  icon: AppIcons.waveform,
);

const _diarizationAssets = [
  _Asset(
    id: 'diarization-segmentation',
    title: 'Segmentasi pembicara (pyannote 3.0)',
    subtitle: 'Menentukan siapa berbicara kapan. 6 MB.',
    icon: AppIcons.people,
  ),
  _Asset(
    id: 'diarization-embedding',
    title: 'Sidik suara pembicara (CAM++)',
    subtitle:
        'Mengenali suara yang sama di bagian rekaman yang berbeda. 28 MB.',
    icon: AppIcons.people,
  ),
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
        '${asset.title} terpasang.',
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
      title: 'Mesin pengenal suara',
      children: [
        _row(_vadAsset),
        const SettingsDivider(),
        SettingsSwitch(
          icon: AppIcons.people,
          label: 'Pemisahan pembicara akurat',
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
            'Unduhan gagal: $_error',
            style: AppText.caption.c(context.colors.error),
          ),
        ],
      ],
    );
  }

  String _diarizationSubtitle(bool enabled, bool ready) {
    if (!enabled) {
      return 'Mati. Memakai pengelompokan akustik sederhana, yang cukup '
          'untuk rapat dua sumber (mikrofon = Anda, sistem = peserta) '
          'tetapi sering memecah satu suara menjadi beberapa pembicara '
          'pada berkas impor.';
    }
    if (!ready) {
      return 'Aktif, tetapi modelnya belum lengkap diunduh. Sementara ini '
          'masih memakai pengelompokan akustik sederhana.';
    }
    return 'Segmentasi pyannote + sidik suara CAM++, seluruhnya di komputer '
        'ini. Dipakai pada impor berkas, transkrip ulang, dan penyelesaian '
        'setelah Stop (bukan pada pratinjau langsung).';
  }

  Widget _row(_Asset asset) {
    final installed = _installed?[asset.id];
    final busy = _downloading == asset.id;
    return SettingsTile(
      icon: asset.icon,
      label: asset.title,
      subtitle: busy
          ? 'Mengunduh… ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
          : switch (installed) {
              null => 'Memeriksa…',
              true => 'Terpasang. ${asset.subtitle}',
              false => 'Belum diunduh. ${asset.subtitle}',
            },
      trailing: switch (installed) {
        true => Icon(
          AppIcons.check,
          size: IconSizes.md,
          color: context.colors.success,
        ),
        _ => AppButton(
          label: busy ? 'Mengunduh…' : 'Unduh',
          variant: AppButtonVariant.secondary,
          onPressed: busy || _downloading != null || installed == null
              ? null
              : () => unawaited(_download(asset)),
        ),
      },
    );
  }
}
