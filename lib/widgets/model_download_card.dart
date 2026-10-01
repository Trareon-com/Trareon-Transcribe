import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(status), size: 18, color: _colorFor(status, colors)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              Text(
                sizeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status == DownloadStatus.ready ? 1.0 : progress,
              minHeight: 6,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation(_colorFor(status, colors)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            errorText ?? _statusText(),
            style: TextStyle(
              fontSize: 11,
              color: errorText != null ? colors.error : colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(DownloadStatus s) => switch (s) {
        DownloadStatus.downloading => Icons.downloading,
        DownloadStatus.ready => Icons.check_circle_outline,
        DownloadStatus.error => Icons.error_outline,
        DownloadStatus.idle => Icons.cloud_download_outlined,
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
        DownloadStatus.error => 'Gagal — coba lagi',
      };
}

enum DownloadStatus { idle, downloading, ready, error }