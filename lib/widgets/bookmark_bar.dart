/// Bookmarks during recording (F9) — the button, the hotkey's feedback, and
/// the list of markers already dropped.
///
/// A notulis' actual job during a three-hour rapat is *flagging*: "that was
/// the decision", "follow this up". Before this existed the app offered no way
/// to do it, so people wrote wall-clock times on paper and hunted for them
/// afterwards. One keystroke (Ctrl+B) drops a marker; the note is optional
/// precisely because stopping to type is what this replaces.
library;

import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/format_time.dart';

/// Asks for the optional one-line note on a bookmark.
///
/// Opened *after* the marker is already placed, so the timestamp is the moment
/// the user pressed the key, not the moment they finished typing.
Future<String?> showBookmarkNoteDialog(
  BuildContext context, {
  required double timestamp,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Catatan untuk ${formatTimestamp(timestamp)}'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Catatan (opsional)',
          hintText: 'mis. keputusan penting, tindak lanjut',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Lewati'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Simpan'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// The "Tandai" button plus the markers dropped so far.
class BookmarkBar extends StatelessWidget {
  const BookmarkBar({
    super.key,
    required this.bookmarks,
    required this.live,
    required this.onAdd,
    required this.onAddWithNote,
    required this.onRemove,
    required this.onEditNote,
  });

  final List<Bookmark> bookmarks;

  /// Whether a session is recording or paused. The button is disabled
  /// otherwise: a marker needs a recording to point into.
  final bool live;
  final VoidCallback onAdd;
  final VoidCallback onAddWithNote;
  final void Function(Bookmark) onRemove;
  final void Function(Bookmark) onEditNote;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    if (!live && bookmarks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tooltip(
                message: 'Tandai poin penting di posisi sekarang (Ctrl+B)',
                child: OutlinedButton.icon(
                  onPressed: live ? onAdd : null,
                  icon: const Icon(Icons.bookmark_add_outlined,
                      size: IconSizes.md),
                  label: const Text('Tandai'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Tooltip(
                message: 'Tandai dan tulis catatan',
                child: IconButton(
                  onPressed: live ? onAddWithNote : null,
                  constraints: TouchTarget.constraints,
                  icon: const Icon(Icons.edit_note, size: IconSizes.lg),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    bookmarks.isEmpty
                        ? 'Belum ada poin yang ditandai.'
                        : '${bookmarks.length} poin ditandai.',
                    style: TextStyle(
                      fontSize: FontSizes.caption,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (bookmarks.isNotEmpty) ...[
            Spacing.gapSm,
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final bookmark in bookmarks)
                  InputChip(
                    avatar: Icon(
                      Icons.bookmark,
                      size: IconSizes.sm,
                      color: colors.primary,
                    ),
                    label: Text(
                      bookmark.note.trim().isEmpty
                          ? formatTimestamp(bookmark.timestamp)
                          : '${formatTimestamp(bookmark.timestamp)} · '
                              '${bookmark.note.trim()}',
                    ),
                    tooltip: 'Klik untuk ubah catatan',
                    onPressed: () => onEditNote(bookmark),
                    onDeleted: () => onRemove(bookmark),
                    deleteButtonTooltipMessage:
                        'Hapus tanda ${formatTimestamp(bookmark.timestamp)}',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
