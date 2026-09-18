import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';
import '../utils/format_time.dart';
import '../utils/speaker_color.dart';
import '../widgets/empty_state.dart';
import 'speaker_avatar.dart';

class TranscriptView extends StatefulWidget {
  final List<TranscriptSegment> segments;
  final void Function(int index, String newText)? onEdit;

  /// If non-null, the segment at this index is visually highlighted
  /// as the "currently playing" segment in the player.
  final int? activeSegmentIndex;

  /// Map of original speaker name → custom label.
  final Map<String, String> speakerLabels;

  /// Called when user renames a speaker (oldName, newName).
  final void Function(String oldName, String newName)? onRenameSpeaker;

  const TranscriptView({
    super.key,
    required this.segments,
    this.onEdit,
    this.activeSegmentIndex,
    this.speakerLabels = const {},
    this.onRenameSpeaker,
  });

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    const threshold = 50.0;
    final atBottom = pos.maxScrollExtent - pos.pixels < threshold;
    if (_autoScroll != atBottom) {
      setState(() => _autoScroll = atBottom);
    }
  }

  @override
  void didUpdateWidget(TranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.segments.length > oldWidget.segments.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _copyAllToClipboard(BuildContext context) {
    if (widget.segments.isEmpty) return;
    final text = widget.segments
        .map((s) => '[${s.speaker} · ${formatDuration(Duration(milliseconds: (s.timestamp * 1000).round()))}] ${s.text}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transkrip disalin ke clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    if (widget.segments.isEmpty) {
      return const EmptyState(
        icon: Icons.mic_none_outlined,
        title: 'Belum ada transkrip',
        subtitle: 'Mulai sesi untuk memulai transkripsi\nTekan Mulai atau Ctrl+R (⌘R)',
      );
    }

    return Column(
      children: [
        // Search + Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: colors.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari...',
                      hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
                      prefixIcon: Icon(Icons.search, size: 16, color: colors.textTertiary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 14, color: colors.textTertiary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.chipBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.segments.length} segmen',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: _autoScroll ? 'Auto-scroll aktif' : 'Auto-scroll mati',
                icon: Icon(
                  _autoScroll ? Icons.vertical_align_bottom : Icons.pause_circle_outline,
                  size: 18,
                  color: _autoScroll ? colors.primary : colors.textTertiary,
                ),
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
              IconButton(
                tooltip: 'Salin semua',
                icon: Icon(Icons.copy_outlined, size: 18, color: colors.textSecondary),
                onPressed: () => _copyAllToClipboard(context),
              ),
            ],
          ),
        ),

        // Transcript list
        Expanded(
          child: Builder(
            builder: (context) {
              final query = _searchQuery.trim().toLowerCase();
              final items = query.isEmpty
                  ? [for (var i = 0; i < widget.segments.length; i++) (i, widget.segments[i])]
                  : [
                      for (var i = 0; i < widget.segments.length; i++)
                        if (widget.segments[i].text.toLowerCase().contains(query) ||
                            widget.segments[i].speaker.toLowerCase().contains(query))
                          (i, widget.segments[i]),
                    ];

              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: query.isNotEmpty ? 'Tidak ada segmen cocok' : 'Belum ada transkrip',
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final (originalIndex, seg) = items[index];
                  final displaySpeaker = widget.speakerLabels[seg.speaker] ?? seg.speaker;
                  return _SegmentTile(
                    segment: seg,
                    displaySpeaker: displaySpeaker,
                    speakerColor: speakerColor(seg.speaker, colors),
                    isActive: widget.activeSegmentIndex != null && originalIndex == widget.activeSegmentIndex,
                    searchQuery: query,
                    onEdit: widget.onEdit == null
                        ? null
                        : (newText) => widget.onEdit!(originalIndex, newText),
                    onCopy: () {
                      Clipboard.setData(ClipboardData(
                        text: '[${formatDuration(Duration(milliseconds: (seg.timestamp * 1000).round()))}] ${seg.text}',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Segmen disalin', style: TextStyle(fontSize: 12, color: colors.text)),
                          duration: Duration(seconds: 1),
                          backgroundColor: colors.surface,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onRename: widget.onRenameSpeaker == null
                        ? null
                        : (newName) => widget.onRenameSpeaker!(seg.speaker, newName),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Highlight [query] in [text] using the given [style] for matches.
/// Returns a list of TextSpans.
List<TextSpan> _highlightText(String text, String query, TextStyle baseStyle, Color highlightColor) {
  if (query.isEmpty) return [TextSpan(text: text, style: baseStyle)];

  final lower = text.toLowerCase();
  final results = <TextSpan>[];
  int start = 0;

  while (true) {
    final idx = lower.indexOf(query, start);
    if (idx == -1) {
      results.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }
    if (idx > start) {
      results.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
    }
    results.add(TextSpan(
      text: text.substring(idx, idx + query.length),
      style: baseStyle.copyWith(
        backgroundColor: highlightColor.withValues(alpha: 0.4),
        fontWeight: FontWeight.w600,
      ),
    ));
    start = idx + query.length;
  }
  return results;
}

class _SegmentTile extends StatelessWidget {
  final TranscriptSegment segment;
  final String displaySpeaker;
  final Color speakerColor;
  final bool isActive;
  final String searchQuery;
  final ValueChanged<String>? onEdit;
  final VoidCallback? onCopy;
  final ValueChanged<String>? onRename;

  const _SegmentTile({
    required this.segment,
    required this.displaySpeaker,
    required this.speakerColor,
    this.isActive = false,
    this.searchQuery = '',
    this.onEdit,
    this.onCopy,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final activeBg = speakerColor.withValues(alpha: isActive ? 0.12 : 0.0);
    final activeBorder = isActive ? speakerColor : Colors.transparent;

    return Semantics(
      label: '${segment.speaker} pada ${formatDuration(Duration(milliseconds: (segment.timestamp * 1000).round()))}: ${segment.text}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 12),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: activeBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: activeBorder.withValues(alpha: isActive ? 0.5 : 0.0),
                width: isActive ? 1.5 : 0,
              ),
            ),
            child: InkWell(
              onTap: onEdit != null ? () => _openEditDialog(context) : null,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: EdgeInsets.only(
                  left: isActive ? 12 : 16,
                  right: 8,
                  top: 10,
                  bottom: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline strip (garis vertikal kecil)
                    Container(
                      width: 3,
                      height: 16,
                      margin: const EdgeInsets.only(top: 3, right: 10),
                      decoration: BoxDecoration(
                        color: speakerColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Speaker label + time
                    SizedBox(
                      width: 72,
                      child: GestureDetector(
                        onTap: onRename != null
                            ? () => _openRenameDialog(context)
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SpeakerAvatar(name: displaySpeaker, color: speakerColor, size: 22),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    displaySpeaker,
                                    style: TextStyle(
                                      color: speakerColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (onRename != null) ...[
                                  const SizedBox(width: 2),
                                  Icon(Icons.edit_outlined, size: 10, color: speakerColor.withValues(alpha: 0.5)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatDuration(Duration(milliseconds: (segment.timestamp * 1000).round())),
                              style: TextStyle(
                                color: colors.textTertiary,
                                fontSize: 10,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: _highlightText(
                                segment.text,
                                searchQuery,
                                TextStyle(
                                  color: colors.text,
                                  fontSize: 14,
                                  height: 1.45,
                                  letterSpacing: 0.1,
                                ),
                                speakerColor,
                              ),
                            ),
                          ),
                          if (segment.isPartial) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 9,
                                  height: 9,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.4,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Memperbaiki…',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.textTertiary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (segment.lowConfidence) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 12,
                                  color: const Color(0xFFD97706),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Kepercayaan rendah',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: const Color(0xFFD97706),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Action buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onCopy != null)
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              icon: Icon(Icons.copy_outlined, size: 16, color: colors.textTertiary),
                              onPressed: onCopy,
                              padding: EdgeInsets.zero,
                              tooltip: 'Salin segmen',
                            ),
                          ),
                        if (onEdit != null)
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              icon: Icon(Icons.edit_outlined, size: 16, color: colors.textTertiary),
                              onPressed: () => _openEditDialog(context),
                              padding: EdgeInsets.zero,
                              tooltip: 'Edit',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openEditDialog(BuildContext context) {
    final controller = TextEditingController(text: segment.text);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: speakerColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('Edit Transkrip', style: TextStyle(color: colors.text, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 3,
          style: TextStyle(color: colors.text, fontSize: 14, height: 1.4),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: colors.chipBackground,
            hintText: 'Ketik koreksi transkrip...',
            hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ).then((newText) {
      if (newText != null && newText.trim().isNotEmpty && newText != segment.text) {
        onEdit?.call(newText);
      }
    });
  }

  void _openRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: displaySpeaker);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: speakerColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('Ganti Nama Speaker', style: TextStyle(color: colors.text, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.text, fontSize: 14),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: colors.chipBackground,
            hintText: 'Nama baru...',
            hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ).then((newName) {
      if (newName != null && newName.trim().isNotEmpty) {
        onRename?.call(newName.trim());
      }
    });
  }
}
