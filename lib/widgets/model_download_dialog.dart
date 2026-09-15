import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bridge_service.dart';
import '../theme/app_colors.dart';

Future<bool> showModelDownloadDialog({
  required BuildContext context,
  required RustBridge bridge,
  required String modelId,
  required String modelsDir,
  required String displayName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ModelDownloadDialog(
      modelId: modelId,
      displayName: displayName,
      bridge: bridge,
      modelsDir: modelsDir,
    ),
  );
  return result ?? false;
}

class _ModelDownloadDialog extends ConsumerStatefulWidget {
  final String modelId;
  final String displayName;
  final RustBridge bridge;
  final String modelsDir;

  const _ModelDownloadDialog({
    required this.modelId,
    required this.displayName,
    required this.bridge,
    required this.modelsDir,
  });

  @override
  ConsumerState<_ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends ConsumerState<_ModelDownloadDialog> {
  bool _downloading = false;
  String _status = 'Mengunduh...';
  double _progress = 0.0;
  Stream<double>? _progressStream;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _status = 'Mengunduh ${widget.displayName}...';
    });

    try {
      // Start download in background
      final downloadFuture = widget.bridge.downloadModel(
        widget.modelsDir,
        widget.modelId,
      );

      // Listen to progress stream
      _progressStream = widget.bridge.downloadProgress();
      _progressStream!.listen(
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _status = 'Mengunduh ${widget.displayName}... ${(progress * 100).toInt()}%';
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _downloading = false;
              _status = 'Gagal mengunduh: $error';
            });
          }
        },
        onDone: () {
          // Progress stream completed, download should be done
        },
      );

      await downloadFuture;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _status = 'Gagal mengunduh: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        'Unduh ${widget.displayName}',
        style: TextStyle(color: colors.text),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.displayName} belum diunduh. Apakah Anda ingin mengunduh sekarang?',
            style: TextStyle(color: colors.textSecondary),
          ),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
            const SizedBox(height: 8),
            Text(_status, style: TextStyle(color: colors.textTertiary, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(false),
          child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
        ),
        if (!_downloading)
          FilledButton(
            onPressed: _startDownload,
            child: const Text('Unduh'),
          ),
      ],
    );
  }
}