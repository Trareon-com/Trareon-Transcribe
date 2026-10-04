import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// One model row in the onboarding download list.
///
/// Renders: name (Indonesian), size, progress bar, status text.
/// No model identifier is exposed — just the human description.
class ModelDownloadCard extends StatelessWidget {
  const ModelDownloadCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sizeLabel,
    required this.progress,
    required this.status,
    this.errorText,
  });

  final String title;
  final String subtitle;
  final String sizeLabel;
  final double progress; // 0.0–1.0
  final DownloadStatus status;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>()!;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconFor(status),
                size: IconSizes.md,
                color: _colorFor(status, colors),
              ),
              Spacing.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: FontSizes.body,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    Spacing.gapXs,
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: FontSizes.micro,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                sizeLabel,
                style: TextStyle(
                  fontSize: FontSizes.micro,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          Spacing.gapSm,
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xs),
            child: LinearProgressIndicator(
              value: status == DownloadStatus.ready ? 1.0 : progress,
              minHeight: 6,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation(_colorFor(status, colors)),
            ),
          ),
          Spacing.gapSm,
          Text(
            errorText ?? _statusText(),
            style: TextStyle(
              fontSize: FontSizes.micro,
              color: errorText != null ? colors.error : colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(DownloadStatus s) => switch (s) {
    DownloadStatus.downloading => AppIcons.downloading,
    DownloadStatus.ready => AppIcons.check,
    DownloadStatus.error => AppIcons.error,
    DownloadStatus.idle => AppIcons.cloudDownload,
  };

  Color _colorFor(DownloadStatus s, AppColorSet c) => switch (s) {
    DownloadStatus.ready => c.success,
    DownloadStatus.error => c.error,
    _ => c.primary,
  };

  String _statusText() => switch (status) {
    DownloadStatus.idle => 'Belum diunduh',
    DownloadStatus.downloading =>
      '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
    DownloadStatus.ready => 'Siap',
    DownloadStatus.error => 'Gagal, coba lagi',
  };
}

enum DownloadStatus { idle, downloading, ready, error }
