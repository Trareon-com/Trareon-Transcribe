import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

int _computeBytesSync(String path) {
  int total = 0;
  try {
    for (final e in Directory(path).listSync(recursive: true)) {
      if (e is File) total += e.statSync().size;
    }
  } catch (_) {}
  return total;
}

/// Shows session count and real disk usage for the library directory.
class StorageBar extends StatefulWidget {
  final int totalSessions;
  final String? libraryPath;

  const StorageBar({super.key, this.totalSessions = 0, this.libraryPath});

  @override
  State<StorageBar> createState() => _StorageBarState();
}

class _StorageBarState extends State<StorageBar> {
  Future<int>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _computeUsedBytes(widget.libraryPath);
  }

  @override
  void didUpdateWidget(StorageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.libraryPath != widget.libraryPath ||
        oldWidget.totalSessions != widget.totalSessions) {
      _bytesFuture = _computeUsedBytes(widget.libraryPath);
    }
  }

  Future<int> _computeUsedBytes(String? libraryPath) {
    if (libraryPath == null) return Future.value(0);
    if (!Directory(libraryPath).existsSync()) return Future.value(0);
    return compute(_computeBytesSync, libraryPath);
  }

  String _formatBytes(AppLocalizations l10n, int bytes) {
    if (bytes < 1024 * 1024) {
      return l10n.bytesKb((bytes / 1024).toStringAsFixed(0));
    } else if (bytes < 1024 * 1024 * 1024) {
      return l10n.bytesMb((bytes / (1024 * 1024)).toStringAsFixed(1));
    } else {
      return l10n.bytesGb((bytes / (1024 * 1024 * 1024)).toStringAsFixed(1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      child: Semantics(
        label: l10n.storageTooltip(widget.totalSessions),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                AppIcons.storage,
                size: IconSizes.xs,
                color: colors.textTertiary,
              ),
            ),
            Spacing.hSm,
            FutureBuilder<int>(
              future: _bytesFuture,
              builder: (context, snapshot) {
                final sessionLabel = l10n.storageSessionCount(
                  widget.totalSessions,
                );
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData &&
                    snapshot.data! > 0) {
                  return Text(
                    l10n.storageSummary(
                      sessionLabel,
                      _formatBytes(l10n, snapshot.data!),
                    ),
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: FontSizes.caption,
                    ),
                  );
                }
                return Text(
                  sessionLabel,
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: FontSizes.caption,
                  ),
                );
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.chipBackground,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Text(
                widget.totalSessions > 0
                    ? l10n.storageCountCompact(widget.totalSessions)
                    : l10n.storageEmptyCompact,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: FontSizes.micro,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
