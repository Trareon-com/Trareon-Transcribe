/// The audit-log viewer (F13).
///
/// A compliance record nobody can read is a file, not a control. This is
/// the one place the user can see what the app did with their meeting
/// data, newest first, with the destination for the acts that moved it
/// somewhere.
///
/// It shows metadata only, because that is all the log holds — no
/// transcript text ever reaches it.
library;

import 'package:flutter/material.dart';

import '../src/rust/api.dart' as rust_api;
import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_icons.dart';

Future<void> showAuditLogDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const Dialog(child: AuditLogView()),
  );
}

class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key, this.entries});

  /// Supplied by tests; `null` reads the real log.
  final List<AuditEntry>? entries;

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  List<AuditEntry>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.entries != null) {
      _entries = widget.entries;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      // 500 is enough to cover years of ordinary use and bounded enough
      // that a log someone scripted into is still openable.
      final entries = await rust_api.readAuditLog(limit: 500);
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final entries = _entries;
    return SizedBox(
      width: 700,
      height: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Icon(AppIcons.history, color: colors.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Log audit',
                      style: TextStyle(
                        fontSize: FontSizes.title,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch ((entries, _error)) {
              (_, final String error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Text(
                      'Log audit tidak bisa dibaca: $error',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ),
              (null, _) => const Center(child: CircularProgressIndicator()),
              (final List<AuditEntry> list, _) when list.isEmpty => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Text(
                      'Belum ada catatan. Log terisi saat sesi dibuat, '
                      'transkrip diekspor, atau data dihapus.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textTertiary),
                    ),
                  ),
                ),
              (final List<AuditEntry> list, _) => ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) =>
                      _AuditRow(entry: list[index], colors: colors),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry, required this.colors});

  final AuditEntry entry;
  final AppColorSet colors;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(_iconFor(entry.action), size: IconSizes.md, color: colors.primary),
      title: Text(
        '${auditActionLabel(entry.action)} — ${entry.subject}',
        style: TextStyle(fontSize: FontSizes.body, color: colors.text),
      ),
      subtitle: Text(
        [
          formatAuditTime(entry.atUnixMs),
          entry.actor,
          if (entry.destination.isNotEmpty) '→ ${entry.destination}',
          if (entry.detail.isNotEmpty) entry.detail,
        ].join(' · '),
        style: TextStyle(fontSize: FontSizes.micro, color: colors.textTertiary),
      ),
    );
  }

  IconData _iconFor(AuditAction action) => switch (action) {
    AuditAction.sessionCreated => AppIcons.dot,
    AuditAction.sessionExported => AppIcons.upload,
    AuditAction.summarySent => AppIcons.cloudUpload,
    AuditAction.sessionDeleted => AppIcons.folderDelete,
    AuditAction.audioDeleted => AppIcons.audioTrack,
    AuditAction.transcriptDeleted => AppIcons.delete,
    AuditAction.consentAcknowledged => AppIcons.announce,
    AuditAction.redactionApplied => AppIcons.hide,
    AuditAction.retentionApplied => AppIcons.clock,
    AuditAction.auditExported => AppIcons.table,
  };
}

/// Indonesian label for an action.
///
/// Dart-side rather than a bridge call per row: the viewer renders
/// hundreds of rows and a round trip each would make scrolling stutter.
/// Kept in sync with `AuditAction::label` by
/// `test/audit_log_view_test.dart`, which walks every variant.
String auditActionLabel(AuditAction action) => switch (action) {
  AuditAction.sessionCreated => 'Sesi dibuat',
  AuditAction.sessionExported => 'Transkrip diekspor',
  AuditAction.summarySent => 'Ringkasan dikirim ke endpoint',
  AuditAction.sessionDeleted => 'Sesi dihapus',
  AuditAction.audioDeleted => 'Audio dihapus',
  AuditAction.transcriptDeleted => 'Transkrip dihapus',
  AuditAction.consentAcknowledged => 'Pemberitahuan perekaman disampaikan',
  AuditAction.redactionApplied => 'Penyamaran data pribadi diterapkan',
  AuditAction.retentionApplied => 'Kebijakan retensi dijalankan',
  AuditAction.auditExported => 'Log audit diekspor',
};

/// `DD/MM/YYYY HH:MM` in local time, without a bridge round trip.
String formatAuditTime(BigInt atUnixMs) {
  final time = DateTime.fromMillisecondsSinceEpoch(atUnixMs.toInt());
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.day)}/${two(time.month)}/${time.year} '
      '${two(time.hour)}:${two(time.minute)}';
}
