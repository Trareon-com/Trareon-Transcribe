import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Semantics(
        label: widget.totalSessions > 0
            ? 'Penyimpanan: ${widget.totalSessions} sesi tersimpan'
            : 'Penyimpanan: belum ada sesi tersimpan',
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.storage_outlined, size: 14, color: colors.textTertiary),
            ),
            const SizedBox(width: 6),
            FutureBuilder<int>(
              future: _bytesFuture,
              builder: (context, snapshot) {
                final sessionLabel = widget.totalSessions > 0
                    ? '${widget.totalSessions} sesi'
                    : 'Belum ada sesi';
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData &&
                    snapshot.data! > 0) {
                  return Text(
                    '$sessionLabel · ${_formatBytes(snapshot.data!)}',
                    style: TextStyle(color: colors.textTertiary, fontSize: 12),
                  );
                }
                return Text(
                  sessionLabel,
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                );
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.chipBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.totalSessions > 0 ? '📁 ${widget.totalSessions}' : '📂 Kosong',
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
