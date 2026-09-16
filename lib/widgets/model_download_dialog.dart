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
  bool _started = false;
  String _status = '';

  Future<void> _startDownload() async {
    if (_downloading || _started) return;
    setState(() {
      _downloading = true;
      _started = true;
      _status = 'Mengunduh ${widget.displayName}...';
    });

    try {
      await widget.bridge.downloadModel(
        widget.modelsDir,
        widget.modelId,
      );
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
            _downloading
                ? 'Mengunduh ${widget.displayName}...'
                : '${widget.displayName} belum diunduh. Apakah Anda ingin mengunduh sekarang?',
            style: TextStyle(color: colors.textSecondary),
          ),
          if (_downloading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_status, style: TextStyle(color: colors.textTertiary, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
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