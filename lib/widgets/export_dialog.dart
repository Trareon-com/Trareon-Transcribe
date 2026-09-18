import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/bridge_service.dart';
import '../src/rust/export.dart' as rust_ekspor;
import '../state/models.dart';
import '../theme/app_colors.dart';

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
Future<bool> showEksporDialog(
  BuildContext context,
  SessionSummary session, {
  required RustBridge bridge,
  String defaultOutputDir = '',
  String defaultFormat = 'markdown',
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
              Icon(Icons.upload_outlined, color: colors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ekspor "${session.title}"',
                  style: TextStyle(color: colors.text, fontSize: 16, fontWeight: FontWeight.w600),
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
                  Text(
                    'Pilih format ekspor:',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  for (final format in const [
                    ('md', 'Markdown', 'Dengan timestamp & label speaker', Icons.description_outlined),
                    ('txt', 'TXT', 'Plain text tanpa timestamp', Icons.text_snippet_outlined),
                    ('json', 'JSON', 'Full metadata terstruktur', Icons.data_object_outlined),
                    ('srt', 'SRT', 'Subtitle format', Icons.closed_caption_outlined),
                    ('vtt', 'VTT', 'Web subtitle', Icons.language_outlined),
                    ('html', 'HTML', 'Dokumen dengan styling', Icons.web_outlined),
                    ('docx', 'DOCX', 'Microsoft Word document', Icons.article_outlined),
                  ])
                    CheckboxListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(format.$2, style: TextStyle(color: colors.text, fontSize: 14)),
                      subtitle: Text(format.$3, style: TextStyle(color: colors.textTertiary, fontSize: 11)),
                      secondary: Icon(format.$4, size: 18, color: selected.contains(format.$1) ? colors.primary : colors.textTertiary),
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
                  Text(
                    'Semua file dalam 1 folder',
                    style: TextStyle(color: colors.textTertiary, fontSize: 11),
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
              icon: const Icon(Icons.folder_open_outlined, size: 18),
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
            const SizedBox(width: 16),
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
  ];

  try {
    await bridge.exportSession(
      segments: session.segments,
      outputDir: outputDir,
      title: session.title,
      formats: formats,
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ekspor gagal: $e'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }
}
