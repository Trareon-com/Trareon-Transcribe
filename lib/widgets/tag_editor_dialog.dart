/// Session folders/tags (F20).
///
/// Tags rather than folders on disk. A rapat is routinely both
/// "Anggaran" and "Mingguan", and a directory can only be in one place;
/// moving sessions between folders would also break every stored path —
/// the audio, the exports, the archive index. So they live in the
/// sidecar, the sidebar filters on them, and nothing on disk moves.
///
/// Tags already in the library are offered as chips, because the failure
/// mode of free-text tags is "Anggaran", "anggaran" and "Anggran" all
/// existing as separate filters.
library;

import 'package:flutter/material.dart';

import '../services/library_index.dart' show normaliseTags;
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_icons.dart';

/// Opens the editor. Returns the new tag list, or null if cancelled.
Future<List<String>?> showTagEditor(
  BuildContext context, {
  required List<String> current,
  required List<String> known,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _TagEditorDialog(current: current, known: known),
  );
}

class _TagEditorDialog extends StatefulWidget {
  const _TagEditorDialog({required this.current, required this.known});

  final List<String> current;
  final List<String> known;

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  late List<String> _tags;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = normaliseTags(widget.current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    setState(() {
      _tags = normaliseTags([..._tags, tag]);
      _controller.clear();
    });
  }

  void _remove(String tag) {
    setState(() => _tags = _tags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    // Tags elsewhere in the library that this session does not have, so
    // the user reuses a spelling instead of inventing one.
    final suggestions = normaliseTags(widget.known)
        .where((tag) =>
            !_tags.any((t) => t.toLowerCase() == tag.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Tag sesi'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tag dipakai untuk memfilter daftar sesi di bilah kiri. '
              'Tidak ada berkas yang dipindahkan.',
              style: TextStyle(
                fontSize: FontSizes.caption,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            Spacing.gapMd,
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Tambah tag',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(AppIcons.add, size: IconSizes.sm),
                  tooltip: 'Tambah',
                  onPressed: () => _add(_controller.text),
                ),
              ),
              onSubmitted: _add,
            ),
            Spacing.gapMd,
            if (_tags.isEmpty)
              Text(
                'Sesi ini belum punya tag.',
                style: TextStyle(
                  fontSize: FontSizes.caption,
                  color: colors.textTertiary,
                ),
              )
            else
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: [
                  for (final tag in _tags)
                    InputChip(
                      label: Text(tag, style: const TextStyle(fontSize: FontSizes.caption)),
                      onDeleted: () => _remove(tag),
                      deleteIcon: const Icon(AppIcons.close, size: IconSizes.xs),
                    ),
                ],
              ),
            if (suggestions.isNotEmpty) ...[
              Spacing.gapMd,
              Text(
                'Tag lain di perpustakaan',
                style: TextStyle(
                  fontSize: FontSizes.micro,
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: [
                  for (final tag in suggestions)
                    ActionChip(
                      label: Text(tag, style: const TextStyle(fontSize: FontSizes.caption)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _add(tag),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_tags),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
