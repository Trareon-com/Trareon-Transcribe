import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../utils/model_labels.dart';
import '../theme/app_tokens.dart';

/// Outcome of a successful re-transcription.
class RetranscribeResult {
  const RetranscribeResult({
    required this.segments,
    required this.modelId,
    required this.language,
  });

  final List<TranscriptSegment> segments;
  final String modelId;

  /// `null` means auto-detect.
  final String? language;
}

/// "Transkrip Ulang": re-runs an existing session's audio through a different
/// model or language.
///
/// Returns `null` when cancelled or when transcription produced nothing — the
/// caller keeps the existing transcript in both cases, so a failed re-run can
/// never lose the original. The old transcript is only replaced once new
/// segments are actually in hand.
Future<RetranscribeResult?> showRetranscribeDialog(
  BuildContext context, {
  required String audioPath,
  String? currentModel,
  String? currentLanguage,
}) {
  return showDialog<RetranscribeResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RetranscribeDialog(
      audioPath: audioPath,
      currentModel: currentModel,
      currentLanguage: currentLanguage,
    ),
  );
}

class _RetranscribeDialog extends ConsumerStatefulWidget {
  const _RetranscribeDialog({
    required this.audioPath,
    this.currentModel,
    this.currentLanguage,
  });

  final String audioPath;
  final String? currentModel;
  final String? currentLanguage;

  @override
  ConsumerState<_RetranscribeDialog> createState() => _RetranscribeDialogState();
}

class _RetranscribeDialogState extends ConsumerState<_RetranscribeDialog> {
  late String _modelId;
  String? _language;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    // Default to the *accurate* model when it's available: re-transcribing is
    // almost always an attempt to improve on a fast first pass.
    final preferred = isModelAvailable(
      'large-v3-turbo-q5',
      libraryPath: settings.libraryPath,
    )
        ? 'large-v3-turbo-q5'
        : settings.defaultModel;
    _modelId = widget.currentModel == preferred
        ? preferred
        : (availableModelIds(settings.libraryPath).contains(preferred)
              ? preferred
              : settings.defaultModel);
    _language = widget.currentLanguage ?? settings.language;
  }

  /// Model ids whose file actually exists — offering one that isn't installed
  /// would just fail at load time with a path error.
  List<String> availableModelIds(String libraryPath) => [
    for (final id in kKnownModelIds)
      if (isModelAvailable(id, libraryPath: libraryPath)) id,
  ];

  Future<void> _run() async {
    final settings = ref.read(settingsProvider);
    final bridge = ref.read(rustBridgeProvider);
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final results = await bridge.batchTranscribeFiles(
        modelPath: modelPathForId(_modelId, libraryPath: settings.libraryPath),
        files: [widget.audioPath],
        language: _language,
        gpuEnabled: settings.gpuEnabled,
        gpuDevice: settings.gpuDevice,
      );
      final outcome = results.firstOrNull;
      final segments =
          outcome?.result?.segments.map(fromRustSegment).toList() ??
          const <TranscriptSegment>[];
      if (!mounted) return;
      if (segments.isEmpty) {
        setState(() {
          _running = false;
          // Distinguish "engine failed" from "nothing to hear" — the fix is
          // different, and either way the old transcript is kept.
          _error = outcome?.error != null
              ? 'Gagal transkrip ulang: ${outcome!.error}. '
                    'Transkrip lama tetap dipertahankan.'
              : 'Tidak ada ucapan terdeteksi. Transkrip lama tetap dipertahankan.';
        });
        return;
      }
      Navigator.of(context).pop(
        RetranscribeResult(
          segments: segments,
          modelId: _modelId,
          language: _language,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = 'Gagal transkrip ulang (transkrip lama tetap aman): $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final settings = ref.watch(settingsProvider);
    final models = availableModelIds(settings.libraryPath);

    return AlertDialog(
      backgroundColor: colors.surface,
      title: const Text('Transkrip Ulang'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio asli akan ditranskrip ulang. Transkrip lama diganti hanya '
              'kalau proses berhasil.',
              style: TextStyle(color: colors.textSecondary, fontSize: FontSizes.caption),
            ),
            Spacing.gapMd,
            DropdownButtonFormField<String>(
              initialValue: models.contains(_modelId) ? _modelId : models.firstOrNull,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Kualitas model',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final id in models)
                  DropdownMenuItem(value: id, child: Text(modelDisplayLabel(id))),
              ],
              onChanged: _running
                  ? null
                  : (v) {
                      if (v != null) setState(() => _modelId = v);
                    },
            ),
            Spacing.gapMd,
            DropdownButtonFormField<String?>(
              initialValue: _language,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Bahasa',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Deteksi otomatis')),
                DropdownMenuItem(value: 'id', child: Text('Indonesia')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: _running ? null : (v) => setState(() => _language = v),
            ),
            if (models.isEmpty) ...[
              Spacing.gapMd,
              Text(
                'Tidak ada model terpasang.',
                style: TextStyle(color: colors.error, fontSize: FontSizes.caption),
              ),
            ],
            if (_running) ...[
              Spacing.gapLg,
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  Spacing.hMd,
                  Expanded(
                    child: Text(
                      'Memproses… ini bisa memakan waktu untuk rekaman panjang.',
                      style: TextStyle(color: colors.textSecondary, fontSize: FontSizes.caption),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              Spacing.gapMd,
              Text(
                _error!,
                style: TextStyle(color: colors.error, fontSize: FontSizes.caption),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _running || models.isEmpty ? null : _run,
          child: const Text('Mulai'),
        ),
      ],
    );
  }
}
