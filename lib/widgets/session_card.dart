import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// Card widget for displaying a session summary in the library list.
class SessionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final double durationSeconds;
  final int segmentsCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback? onRename;

  /// Shows the "Ringkasan" badge when this session has a saved AI summary.
  final bool hasSummary;

  /// Transcript line that matched the current search, shown under the
  /// metadata row so a full-text hit explains *why* the session matched.
  final String? matchSnippet;

  const SessionCard({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.date,
    this.durationSeconds = 0,
    this.segmentsCount = 0,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
    this.onRename,
    this.hasSummary = false,
    this.matchSnippet,
  });

  String _formatDuration(double seconds) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    if (h > 0) return '${h}j ${m}m';
    return '$m menit';
  }

  static const _indonesianMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String _formatDate(String isoDate) {
    try {
      final parts = isoDate.split('-');
      if (parts.length != 3) return isoDate;
      final year = parts[0];
      final monthIndex = int.parse(parts[1]) - 1;
      final day = parts[2];
      if (monthIndex < 0 || monthIndex > 11) return isoDate;
      return '$day ${_indonesianMonths[monthIndex]} $year';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final durStr = _formatDuration(durationSeconds);

    return Card(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(
                  AppIcons.mic,
                  color: colors.primary,
                  size: IconSizes.lg,
                ),
              ),
              Spacing.hMd,

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: FontSizes.bodyLarge,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasSummary) ...[
                          Spacing.hSm,
                          Tooltip(
                            message: 'Punya ringkasan AI',
                            child: Icon(
                              AppIcons.enhance,
                              size: IconSizes.xs,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Spacing.gapXs,
                    Row(
                      children: [
                        Icon(
                          AppIcons.calendar,
                          size: IconSizes.xs,
                          color: colors.textTertiary,
                        ),
                        Spacing.hXs,
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: FontSizes.caption,
                          ),
                        ),
                        Spacing.hMd,
                        Icon(
                          AppIcons.clock,
                          size: IconSizes.xs,
                          color: colors.textTertiary,
                        ),
                        Spacing.hXs,
                        Text(
                          durStr,
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: FontSizes.caption,
                          ),
                        ),
                        Spacing.hMd,
                        Icon(
                          AppIcons.segments,
                          size: IconSizes.xs,
                          color: colors.textTertiary,
                        ),
                        Spacing.hXs,
                        Text(
                          '$segmentsCount segmen',
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: FontSizes.caption,
                          ),
                        ),
                      ],
                    ),
                    if (matchSnippet != null) ...[
                      Spacing.gapXs,
                      Text(
                        matchSnippet!,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: FontSizes.caption,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              if (onRename != null)
                IconButton(
                  icon: Icon(
                    AppIcons.rename,
                    size: IconSizes.md,
                    color: colors.textTertiary,
                  ),
                  tooltip: 'Ganti nama',
                  onPressed: onRename,
                ),
              IconButton(
                icon: Icon(
                  AppIcons.upload,
                  size: IconSizes.md,
                  color: colors.textTertiary,
                ),
                tooltip: 'Ekspor',
                onPressed: onExport,
              ),
              IconButton(
                icon: Icon(
                  AppIcons.delete,
                  size: IconSizes.md,
                  color: colors.textTertiary,
                ),
                tooltip: 'Hapus',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Creates a [SessionCard] from a [SessionSummary] model.
class SessionCardFromSummary extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback? onRename;
  final bool hasSummary;
  final String? matchSnippet;

  const SessionCardFromSummary({
    super.key,
    required this.session,
    required this.onTap,
    required this.onExport,
    required this.onDelete,
    this.onRename,
    this.hasSummary = false,
    this.matchSnippet,
  });

  @override
  Widget build(BuildContext context) {
    return SessionCard(
      title: session.title,
      subtitle: session.date,
      date: session.date,
      durationSeconds: session.durationSeconds,
      segmentsCount: session.segmentsCount,
      onTap: onTap,
      onDelete: onDelete,
      onExport: onExport,
      onRename: onRename,
      hasSummary: hasSummary,
      matchSnippet: matchSnippet,
    );
  }
}
