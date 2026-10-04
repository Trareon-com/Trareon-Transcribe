import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/bridge_service.dart';
import '../src/rust/api.dart' as rust_api;
import '../src/rust/export.dart' as rust_ekspor;
import '../state/models.dart';
import '../theme/app_colors.dart';
import 'redaction_preview.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// Records an export in the local audit log, best effort.
///
/// Fire-and-forget: the files are already written, and failing the export
/// because the compliance log could not be appended would be the feature
/// breaking the product it is there to protect.
Future<void> _auditExport(
  String title,
  String outputDir,
  int formatCount,
  PdpSettings pdp,
) async {
  if (!pdp.enabled) return;
  try {
    await rust_api.writeAuditEntry(
      action: AuditAction.sessionExported,
      subject: title,
      destination: outputDir,
      detail: pdp.redacts
          ? '$formatCount format, disamarkan'
          : '$formatCount format',
    );
  } catch (_) {
    // Reported nowhere on purpose; see above.
  }
}

/// Maps a settings-side format name (e.g. 'markdown') to the dialog's short
/// format ID (e.g. 'md'). Falls back to the input unchanged for ids that are
/// already short-form ('txt', 'json', etc.).
String _toDialogFormatId(String settingsFormat) => switch (settingsFormat) {
      'markdown' => 'md',
      _ => settingsFormat,
    };

/// Dialog for selecting ekspor formats and output directory.
/// Returns true if the ekspor was initiated, false if cancelled.
///
/// [defaultFormat] is the format name from settings (e.g. 'markdown', 'txt').
/// The corresponding checkbox will be pre-selected; others remain unchecked.
/// [summary] is the session's saved AI summary (Markdown). When non-empty it
/// leads the Markdown/TXT/HTML/DOCX output; SRT/VTT/JSON are unaffected.
Future<bool> showEksporDialog(
  BuildContext context,
  SessionSummary session, {
  required RustBridge bridge,
  String defaultOutputDir = '',
  String defaultFormat = 'markdown',
  String summary = '',
  List<Bookmark> bookmarks = const [],
  bool incomplete = false,
  PdpSettings pdp = kDefaultPdpSettings,
}) async {
  final defaultId = _toDialogFormatId(defaultFormat);
  final selected = <String>{defaultId};

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setState) {
        final colors = Theme.of(dialogCtx).extension<AppColorSet>() ?? AppColors.light;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Row(
            children: [
              Icon(AppIcons.upload, color: colors.primary, size: IconSizes.lg),
              Spacing.hSm,
              Expanded(
                child: Text(
                  'Ekspor "${session.title}"',
                  style: TextStyle(color: colors.text, fontSize: FontSizes.title, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exporting mid-completion is allowed — waiting an hour
                  // for a file you need now is not a kindness — but the
                  // user has to know the document is not the whole meeting.
                  if (incomplete)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(AppIcons.warning,
                              size: IconSizes.sm, color: colors.warning),
                          Spacing.hSm,
                          Expanded(
                            child: Text(
                              'Transkrip sesi ini belum lengkap — masih ada '
                              'audio yang sedang ditranskripsi. Hasil ekspor '
                              'sekarang akan kehilangan bagian itu.',
                              style: TextStyle(
                                  color: colors.warning, fontSize: FontSizes.micro, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Pilih format ekspor:',
                    style: TextStyle(color: colors.textSecondary, fontSize: FontSizes.body),
                  ),
                  Spacing.gapSm,
                  for (final format in const [
                    ('md', 'Markdown', 'Dengan waktu & nama pembicara', AppIcons.document),
                    ('txt', 'TXT', 'Teks biasa tanpa waktu', AppIcons.textSnippet),
                    ('json', 'JSON', 'Data lengkap untuk program lain', AppIcons.json),
                    ('srt', 'SRT', 'Takarir untuk pemutar video', AppIcons.captions),
                    ('vtt', 'VTT', 'Takarir untuk web', AppIcons.language),
                    ('html', 'HTML', 'Halaman web yang sudah ditata', AppIcons.web),
                    ('docx', 'DOCX', 'Dokumen Microsoft Word', AppIcons.article),
                    ('pdf', 'PDF', 'Dokumen siap cetak, font ikut disertakan', AppIcons.pdf),
                    ('csv', 'CSV', 'Tabel per segmen untuk spreadsheet', AppIcons.table),
                  ])
                    CheckboxListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(format.$2, style: TextStyle(color: colors.text, fontSize: FontSizes.bodyLarge)),
                      subtitle: Text(format.$3, style: TextStyle(color: colors.textTertiary, fontSize: FontSizes.micro)),
                      secondary: Icon(format.$4, size: IconSizes.md, color: selected.contains(format.$1) ? colors.primary : colors.textTertiary),
                      value: selected.contains(format.$1),
                      activeColor: colors.primary,
                      checkColor: colors.onPrimary,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selected.add(format.$1);
                          } else {
                            selected.remove(format.$1);
                          }
                        });
                      },
                    ),
                  const Divider(height: 16),
                  if (bookmarks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Row(
                        children: [
                          Icon(AppIcons.bookmark,
                              size: IconSizes.xs, color: colors.primary),
                          Spacing.hSm,
                          Expanded(
                            child: Text(
                              '${bookmarks.length} poin penting disertakan '
                              'sebagai bagian "Poin Penting"',
                              style:
                                  TextStyle(color: colors.primary, fontSize: FontSizes.micro),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (summary.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Row(
                        children: [
                          Icon(AppIcons.enhance,
                              size: IconSizes.xs, color: colors.primary),
                          Spacing.hSm,
                          Expanded(
                            child: Text(
                              'Ringkasan AI disertakan di Markdown, TXT, HTML & DOCX',
                              style: TextStyle(color: colors.primary, fontSize: FontSizes.micro),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (pdp.redacts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(AppIcons.hide,
                              size: IconSizes.xs, color: colors.primary),
                          Spacing.hSm,
                          Expanded(
                            child: Text(
                              'Mode Kepatuhan PDP aktif: data pribadi akan '
                              'disamarkan di file hasil ekspor. Transkrip '
                              'tersimpan tidak berubah.',
                              style:
                                  TextStyle(color: colors.primary, fontSize: FontSizes.micro),
                            ),
                          ),
                          TextButton(
                            onPressed: () => showRedactionPreview(
                              dialogCtx,
                              segments: session.segments,
                              config: pdp.activeRedaction,
                            ),
                            child: const Text('Pratinjau'),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Semua file dalam 1 folder',
                    style: TextStyle(color: colors.textTertiary, fontSize: FontSizes.micro),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton.icon(
              onPressed: selected.isEmpty ? null : () => Navigator.of(dialogCtx).pop(true),
              icon: const Icon(AppIcons.folderOpen, size: IconSizes.md),
              label: const Text('Pilih Folder'),
            ),
          ],
        );
      },
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  final outputDir = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Pilih folder ekspor untuk "${session.title}"',
    initialDirectory: defaultOutputDir.isNotEmpty ? defaultOutputDir : null,
  );
  if (outputDir == null || !context.mounted) return false;

  // Tampilkan loading dialog selama ekspor
  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).extension<AppColorSet>()?.surface ?? AppColors.light.surface,
        content: Row(
          children: [
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            Spacing.hLg,
            Text('Mengekspor ${selected.length} format...'),
          ],
        ),
      ),
    );
  }

  final formats = <rust_ekspor.ExportFormat>[
    if (selected.contains('md')) rust_ekspor.ExportFormat.markdown,
    if (selected.contains('txt')) rust_ekspor.ExportFormat.txt,
    if (selected.contains('json')) rust_ekspor.ExportFormat.json,
    if (selected.contains('srt')) rust_ekspor.ExportFormat.srt,
    if (selected.contains('vtt')) rust_ekspor.ExportFormat.vtt,
    if (selected.contains('html')) rust_ekspor.ExportFormat.html,
    if (selected.contains('docx')) rust_ekspor.ExportFormat.docx,
    if (selected.contains('pdf')) rust_ekspor.ExportFormat.pdf,
    if (selected.contains('csv')) rust_ekspor.ExportFormat.csv,
  ];

  try {
    // Redaction happens here, on the way out, and only here. Rewriting
    // the stored transcript would take evidence the user cannot get back.
    final outgoing = pdp.redacts
        ? (await rust_api.redactSegments(
            segments: session.segments.map(toRustSegment).toList(),
            config: pdp.activeRedaction,
          )).map(fromRustSegment).toList()
        : session.segments;
    await bridge.exportSessionWithSummary(
      segments: outgoing,
      outputDir: outputDir,
      title: session.title,
      summary: summary,
      bookmarks: bookmarks,
      formats: formats,
    );
    // Auditable because it is the moment the data leaves the app. The
    // entry records the destination and the format count, never the text.
    unawaited(_auditExport(session.title, outputDir, formats.length, pdp));
    // Tutup loading dialog
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ekspor berhasil ke: $outputDir'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    // Tutup loading dialog
    Navigator.of(context, rootNavigator: true).pop();
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ekspor gagal: $e'),
        backgroundColor: colors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }
}
