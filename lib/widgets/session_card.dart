import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';

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
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final durStr = _formatDuration(durationSeconds);

    return Card(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.mic_outlined, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 12),

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
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasSummary) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Punya ringkasan AI',
                            child: Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: colors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(date),
                          style: TextStyle(color: colors.textTertiary, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 12, color: colors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          durStr,
                          style: TextStyle(color: colors.textTertiary, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.chat_bubble_outline, size: 12, color: colors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '$segmentsCount segmen',
                          style: TextStyle(color: colors.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                    if (matchSnippet != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        matchSnippet!,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
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
                  icon: Icon(Icons.drive_file_rename_outline,
                      size: 18, color: colors.textTertiary),
                  tooltip: 'Ganti nama',
                  onPressed: onRename,
                ),
              IconButton(
                icon: Icon(Icons.upload_outlined, size: 18, color: colors.textTertiary),
                tooltip: 'Ekspor',
                onPressed: onExport,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: colors.textTertiary),
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
