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
import '../theme/app_icons.dart';

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

/// Marker ticks drawn above the player's seek bar.
///
/// A tick is 3 px wide inside a 24 px hit area — below the 48 px minimum, and
/// deliberately so: a tick's position *is* its meaning, and widening it would
/// put the marker somewhere other than where the user placed it. Every tick
/// has an equivalent ≥48 px control in [BookmarkJumpList], which is the
/// accessible path to the same action, and each tick carries a Semantics
/// label so a screen reader announces it.
class BookmarkTicks extends StatelessWidget {
  const BookmarkTicks({
    super.key,
    required this.bookmarks,
    required this.maxSeconds,
    required this.onJump,
  });

  final List<Bookmark> bookmarks;
  final double maxSeconds;
  final void Function(Bookmark) onJump;

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty || maxSeconds <= 0) {
      return const SizedBox(height: 0);
    }
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              for (final bookmark in bookmarks)
                Positioned(
                  left:
                      ((bookmark.timestamp / maxSeconds).clamp(0.0, 1.0) *
                                  width -
                              12)
                          .clamp(0.0, width - 24),
                  top: 0,
                  child: Semantics(
                    button: true,
                    label:
                        'Poin ditandai pada '
                        '${formatTimestamp(bookmark.timestamp)}'
                        '${bookmark.note.trim().isEmpty ? '' : ', ${bookmark.note.trim()}'}',
                    child: Tooltip(
                      message: bookmark.note.trim().isEmpty
                          ? formatTimestamp(bookmark.timestamp)
                          : '${formatTimestamp(bookmark.timestamp)} · '
                                '${bookmark.note.trim()}',
                      child: InkWell(
                        onTap: () => onJump(bookmark),
                        child: SizedBox(
                          width: 24,
                          height: 14,
                          child: Center(
                            child: Container(
                              width: 3,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: Radii.smAll,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The jump list: one ≥48 px row per marker, with its note and a delete.
class BookmarkJumpList extends StatelessWidget {
  const BookmarkJumpList({
    super.key,
    required this.bookmarks,
    required this.onJump,
    required this.onRemove,
    required this.onEditNote,
  });

  final List<Bookmark> bookmarks;
  final void Function(Bookmark) onJump;
  final void Function(Bookmark) onRemove;
  final void Function(Bookmark) onEditNote;

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) return const SizedBox.shrink();
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final bookmark in bookmarks)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TouchTarget.minimum),
            // Tap jumps — that is what a reviewer wants nine times out of ten
            // — and a long press edits the note. Both are named in the
            // tooltip, so neither is a hidden gesture.
            child: GestureDetector(
              onLongPress: () => onEditNote(bookmark),
              child: InputChip(
                avatar: Icon(
                  AppIcons.bookmarkFilled,
                  size: IconSizes.sm,
                  color: colors.primary,
                ),
                label: Text(
                  bookmark.note.trim().isEmpty
                      ? formatTimestamp(bookmark.timestamp)
                      : '${formatTimestamp(bookmark.timestamp)} · '
                            '${bookmark.note.trim()}',
                ),
                tooltip:
                    'Klik: lompat ke ${formatTimestamp(bookmark.timestamp)} · '
                    'Tahan: ubah catatan',
                onPressed: () => onJump(bookmark),
                onDeleted: () => onRemove(bookmark),
                deleteButtonTooltipMessage:
                    'Hapus tanda ${formatTimestamp(bookmark.timestamp)}',
              ),
            ),
          ),
      ],
    );
  }
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
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
                  icon: const Icon(AppIcons.bookmarkAdd, size: IconSizes.md),
                  label: const Text('Tandai'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Tooltip(
                message: 'Tandai dan tulis catatan',
                child: IconButton(
                  onPressed: live ? onAddWithNote : null,
                  constraints: TouchTarget.constraints,
                  icon: const Icon(AppIcons.editNote, size: IconSizes.lg),
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
                      AppIcons.bookmarkFilled,
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
