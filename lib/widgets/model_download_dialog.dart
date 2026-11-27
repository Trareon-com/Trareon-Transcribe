import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../services/bridge_service.dart';
import '../state/privacy_report_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

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
  ConsumerState<_ModelDownloadDialog> createState() =>
      _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends ConsumerState<_ModelDownloadDialog> {
  bool _downloading = false;
  String _status = currentL10n.modelDownloadDialogDownloading;
  double _progress = 0.0;
  Stream<double>? _progressStream;
  StreamSubscription<double>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    // After the first frame: the download records itself in the Privacy
    // Report, and Riverpod refuses provider writes while the dialog is
    // still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startDownload();
    });
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _status = context.l10n.modelDownloadDialogDownloadingName(
        widget.displayName,
      );
    });

    try {
      // Counted before the request leaves, so the Privacy Report can never
      // understate what this dialog did.
      ref
          .read(privacyReportProvider.notifier)
          .recordModelDownload(widget.modelId);
      // Start download in background
      final downloadFuture = widget.bridge.downloadModel(
        widget.modelsDir,
        widget.modelId,
      );

      // Listen to progress stream
      _progressStream = widget.bridge.downloadProgress();
      _progressSubscription = _progressStream!.listen(
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _status = context.l10n.modelDownloadDialogDownloadingProgress(
                widget.displayName,
                (progress * 100).toInt(),
              );
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _downloading = false;
              _status = context.l10n.modelDownloadDialogFailed('$error');
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
          _status = context.l10n.modelDownloadDialogFailed('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final l10n = context.l10n;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        l10n.modelDownloadDialogTitle(widget.displayName),
        style: TextStyle(color: colors.text),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.modelDownloadDialogPrompt(widget.displayName),
            style: TextStyle(color: colors.textSecondary),
          ),
          if (_downloading) ...[
            Spacing.gapLg,
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
            Spacing.gapSm,
            Text(
              _status,
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: FontSizes.caption,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(
            l10n.actionCancel,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        if (!_downloading)
          FilledButton(
            onPressed: _startDownload,
            child: Text(l10n.modelDownloadDialogDownload),
          ),
      ],
    );
  }
}
