import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/format_time.dart';
import '../utils/speaker_color.dart';
import '../widgets/empty_state.dart';
import 'speaker_avatar.dart';

/// Scrolling transcript.
///
/// Built for the three-hour meeting it is advertised for: at 5 000 segments
/// the old implementation allocated a complete `(index, segment)` tuple list
/// on **every** build — and three independent 1–5 Hz sources (the elapsed
/// timer, the VU meter, each arriving segment) triggered one (audit A.1-11).
/// Now:
///
/// * the filtered index list is computed once per (segments, query) change
///   and is not allocated at all while the search box is empty;
/// * rows carry a `ValueKey`, so `ListView.builder`'s element recycling
///   stops replaying the entry animation on every scroll (A.1-13);
/// * the playing-row highlight arrives through a [ValueListenable] that
///   only fires when the *row* changes, not on every position tick (A.3-6).
class TranscriptView extends StatefulWidget {
  /// Minimum gap between screen-reader announcements of new transcript rows.
  ///
  /// A live transcript is the only thing on this screen that changes without
  /// the user acting, so a screen reader has to announce it — but it arrives
  /// every two seconds for three hours, and a reader that interrupts itself
  /// that often is worse than silence. Public so the accessibility test can
  /// advance exactly one window.
  static const Duration kAnnounceThrottle = Duration(seconds: 6);

  final List<TranscriptSegment> segments;

  /// Monotonic counter bumped by the owner whenever [segments] changes
  /// *content* without changing length or identity — a refined HPT pass
  /// replacing its quick pass, or a manual edit. Without it the cached
  /// filter results would go stale on exactly those edits.
  final int revision;

  final void Function(int index, String newText)? onEdit;

  /// Index of the row currently being played, or null. A listenable rather
  /// than a plain value so the player can push it from its audio position
  /// stream without rebuilding this widget's parent.
  final ValueListenable<int?>? activeSegmentIndex;

  /// Called when a row is tapped in a player context: seek the audio to the
  /// start of that segment. When null, tapping a row opens the edit dialog
  /// instead (the live-recording behaviour).
  final void Function(int index, TranscriptSegment segment)? onSeekToSegment;

  /// Map of original speaker name → custom label.
  final Map<String, String> speakerLabels;

  /// Called when user renames a speaker (oldName, newName).
  final void Function(String oldName, String newName)? onRenameSpeaker;

  const TranscriptView({
    super.key,
    required this.segments,
    this.revision = 0,
    this.onEdit,
    this.activeSegmentIndex,
    this.onSeekToSegment,
    this.speakerLabels = const {},
    this.onRenameSpeaker,
  });

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

/// How long the search box waits after the last keystroke before filtering.
/// At 5 000 segments an unfiltered pass allocates 5 000 lowercased strings;
/// typing "anggaran" used to do that eight times.
const Duration kTranscriptSearchDebounce = Duration(milliseconds: 250);

class _TranscriptViewState extends State<TranscriptView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  /// Original indices of the rows that match [_searchQuery], or null when
  /// the search box is empty — in which case list position *is* the index
  /// and no list is allocated at all.
  List<int>? _matches;

  /// Tail-follow while recording.
  bool _autoScroll = true;

  /// Follow the playing row while the audio plays. Switched off the moment
  /// the user scrolls by hand, and back on from the toolbar toggle.
  bool _followActive = true;

  /// Row count the last rebuild saw. Compared against instead of
  /// `oldWidget.segments.length` because the notifier now publishes an
  /// unmodifiable *view* over one growing list — old and new widget share
  /// the backing store, so their lengths are always equal.
  int _knownCount = 0;
  int _knownRevision = 0;

  int? _activeIndex;
  final GlobalKey _activeRowKey = GlobalKey();

  /// Displayed position the forward sliver starts at. Everything before it
  /// lives in a second, reverse-growth sliver above the viewport's centre,
  /// so scroll offset 0 always means "row [_anchorIndex] at the top" and
  /// jumping across the meeting costs one screenful of layout instead of
  /// the whole transcript. 0 — the live-recording case — makes the leading
  /// sliver empty, i.e. an ordinary top-anchored list.
  int _anchorIndex = 0;
  static const Key _forwardSliverKey = ValueKey('transcript-forward');

  bool get _isPlayerMode => widget.activeSegmentIndex != null;

  // ── Screen-reader live region ─────────────────────────────────────────
  //
  // A live transcript is the one thing on this screen that changes without
  // the user doing anything, so it is the one thing a screen reader has to
  // announce. It also arrives every two seconds for three hours, which is
  // why the announcement is throttled and summarised rather than read
  // verbatim: a reader that is still speaking segment 40 when segment 60
  // arrives is useless, and interrupting itself every two seconds is worse.

  DateTime? _lastAnnouncedAt;
  int _announcedCount = 0;
  Timer? _announceTimer;

  /// Queues an announcement for the rows that arrived since the last one.
  ///
  /// Never announces mid-recording text more than once per
  /// [kAnnounceThrottle]; the trailing timer guarantees the *last* batch is
  /// announced even if it arrives during a quiet period.
  void _scheduleAnnouncement() {
    final now = DateTime.now();
    final last = _lastAnnouncedAt;
    final elapsed =
        last == null ? TranscriptView.kAnnounceThrottle : now.difference(last);
    if (elapsed >= TranscriptView.kAnnounceThrottle) {
      _announceNow();
      return;
    }
    _announceTimer?.cancel();
    _announceTimer =
        Timer(TranscriptView.kAnnounceThrottle - elapsed, _announceNow);
  }

  void _announceNow() {
    _announceTimer?.cancel();
    _announceTimer = null;
    if (!mounted) return;
    final total = widget.segments.length;
    final added = total - _announcedCount;
    if (added <= 0) return;
    _announcedCount = total;
    _lastAnnouncedAt = DateTime.now();
    final latest = widget.segments.last;
    // The newest line in full plus a count, rather than every missed line:
    // the transcript itself is navigable, so this is the "something happened"
    // signal, not a substitute for reading it.
    final message = added == 1
        ? '${latest.speaker}: ${latest.text}'
        : '$added baris baru. Terakhir, ${latest.speaker}: ${latest.text}';
    // An announcement rather than a `liveRegion` node: a node only
    // re-announces when it is rebuilt *and* visible, and this has to speak
    // for rows that are already scrolled out of view.
    SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _knownCount = widget.segments.length;
    _knownRevision = widget.revision;
    // Rows already present when the view appeared are not news: without this
    // seed, resuming a recovered session would announce "51 baris baru" the
    // first time a single new row arrived.
    _announcedCount = _knownCount;
    final active = widget.activeSegmentIndex;
    if (active != null) {
      _activeIndex = active.value;
      active.addListener(_onActiveIndexChanged);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    const threshold = 50.0;
    final atBottom = pos.maxScrollExtent - pos.pixels < threshold;
    if (!_isPlayerMode && _autoScroll != atBottom) {
      setState(() => _autoScroll = atBottom);
    }
  }

  /// Fires at most once per played segment (~0.5 Hz), not once per audio
  /// position tick — the player derives the index with a binary search and
  /// a [ValueNotifier] swallows repeated identical values.
  void _onActiveIndexChanged() {
    final next = widget.activeSegmentIndex?.value;
    if (next == _activeIndex) return;
    setState(() => _activeIndex = next);
    if (_followActive && next != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealRow(next));
    }
  }

  /// Brings row [originalIndex] into view.
  ///
  /// Two cases, and the difference matters enormously at 5 000 rows:
  ///
  /// * **Nearby** (the row is already realised — which is every step of
  ///   ordinary playback, because the next row is inside the cache extent):
  ///   `ensureVisible`, smooth and cheap.
  /// * **Far** (a manual seek across the meeting): scrolling there is not an
  ///   option. `RenderSliverList` walks children from the one it already has,
  ///   so `jumpTo` across 4 000 variable-height rows *builds all 4 000* —
  ///   measured at 20 s on this hardware. Instead the anchor moves and the
  ///   viewport is re-centred on it, which builds one screenful. See
  ///   [_anchorIndex].
  void _revealRow(int originalIndex) {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _positionOf(originalIndex);
    if (position < 0) return;

    final rowContext = _activeRowKey.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        alignment: 0.35,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      return;
    }
    _anchorAt(position);
  }

  /// Position of [originalIndex] within the currently displayed list.
  int _positionOf(int originalIndex) =>
      _matches == null ? originalIndex : _matches!.indexOf(originalIndex);

  /// Re-centres the viewport so that displayed position [position] is at the
  /// top of the forward sliver, with a couple of rows of context above it.
  void _anchorAt(int position) {
    final anchor = (position - 2).clamp(0, position);
    setState(() => _anchorIndex = anchor);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      // Offset 0 is, by construction, the first row of the forward sliver.
      _scrollController.jumpTo(0);
      final ctx = _activeRowKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.25);
    });
  }

  @override
  void didUpdateWidget(TranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldActive = oldWidget.activeSegmentIndex;
    final newActive = widget.activeSegmentIndex;
    if (!identical(oldActive, newActive)) {
      oldActive?.removeListener(_onActiveIndexChanged);
      newActive?.addListener(_onActiveIndexChanged);
      _activeIndex = newActive?.value;
    }

    final count = widget.segments.length;
    final contentChanged =
        count != _knownCount || widget.revision != _knownRevision;
    if (contentChanged && _searchQuery.isNotEmpty) _rebuildMatches();
    // Only while recording: in the player the user is driving, and an
    // unprompted announcement would fight with their own navigation.
    if (!_isPlayerMode && count > _knownCount) _scheduleAnnouncement();
    if (_autoScroll && !_isPlayerMode && count > _knownCount) {
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
    _knownCount = count;
    _knownRevision = widget.revision;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _announceTimer?.cancel();
    widget.activeSegmentIndex?.removeListener(_onActiveIndexChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(kTranscriptSearchDebounce, () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim().toLowerCase();
        _rebuildMatches();
      });
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _matches = null;
      _anchorIndex = 0;
    });
  }

  void _rebuildMatches() {
    // Positions change meaning when the filter does, so the anchor — which
    // is a *position*, not a segment index — has to go back to the top.
    _anchorIndex = 0;
    final query = _searchQuery;
    if (query.isEmpty) {
      _matches = null;
      return;
    }
    final segments = widget.segments;
    final matches = <int>[];
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.text.toLowerCase().contains(query) ||
          segment.speaker.toLowerCase().contains(query)) {
        matches.add(i);
      }
    }
    _matches = matches;
  }

  /// One row, addressed by its position in the *displayed* list.
  Widget _buildRow(BuildContext context, AppColorSet colors, int position) {
    final matches = _matches;
    final originalIndex = matches == null ? position : matches[position];
    final seg = widget.segments[originalIndex];
    final isActive = originalIndex == _activeIndex;
    final displaySpeaker = widget.speakerLabels[seg.speaker] ?? seg.speaker;
    return TranscriptSegmentTile(
      key: isActive ? _activeRowKey : ValueKey(originalIndex),
      segment: seg,
      displaySpeaker: displaySpeaker,
      speakerColor: speakerColor(seg.speaker, colors),
      isActive: isActive,
      searchQuery: _searchQuery,
      onSeek: widget.onSeekToSegment == null
          ? null
          : () => widget.onSeekToSegment!(originalIndex, seg),
      onEdit: widget.onEdit == null
          ? null
          : (newText) => widget.onEdit!(originalIndex, newText),
      onCopy: () {
        Clipboard.setData(ClipboardData(
          text:
              '[${formatDuration(Duration(milliseconds: (seg.timestamp * 1000).round()))}] ${seg.text}',
        ));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Segmen disalin',
                style: TextStyle(fontSize: 12, color: colors.text)),
            duration: const Duration(seconds: 1),
            backgroundColor: colors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onRename: widget.onRenameSpeaker == null
          ? null
          : (newName) => widget.onRenameSpeaker!(seg.speaker, newName),
    );
  }

  void _copyAllToClipboard(BuildContext context) {
    if (widget.segments.isEmpty) return;
    final text = widget.segments
        .map((s) =>
            '[${s.speaker} · ${formatDuration(Duration(milliseconds: (s.timestamp * 1000).round()))}] ${s.text}')
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

    final matches = _matches;
    final itemCount = matches?.length ?? widget.segments.length;
    final anchor = _anchorIndex.clamp(0, itemCount);

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
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: colors.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari...',
                      hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
                      prefixIcon: Icon(Icons.search, size: 16, color: colors.textTertiary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 14, color: colors.textTertiary),
                              onPressed: _clearSearch,
                              tooltip: 'Bersihkan pencarian',
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
              // A live region as well as a label: the count is the one piece
              // of state on this screen that changes on its own, so a screen
              // reader should re-read it rather than wait to be asked.
              Semantics(
                liveRegion: true,
                child: Text(
                  _searchQuery.isEmpty
                      ? '${widget.segments.length} segmen'
                      : '$itemCount dari ${widget.segments.length} segmen',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              if (_isPlayerMode)
                IconButton(
                  tooltip: _followActive
                      ? 'Ikuti pemutaran: aktif'
                      : 'Ikuti pemutaran: mati',
                  icon: Icon(
                    _followActive ? Icons.my_location : Icons.location_disabled,
                    size: 18,
                    color: _followActive ? colors.primary : colors.textTertiary,
                  ),
                  onPressed: () {
                    setState(() => _followActive = !_followActive);
                    final active = _activeIndex;
                    if (_followActive && active != null) _revealRow(active);
                  },
                )
              else
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
          child: itemCount == 0
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Tidak ada segmen cocok',
                )
              : NotificationListener<UserScrollNotification>(
                  // A hand-scroll during playback means "stop dragging me
                  // back to the playhead" — the same contract the live
                  // tail-follow has always had.
                  onNotification: (_) {
                    if (_isPlayerMode && _followActive) {
                      setState(() => _followActive = false);
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    center: _forwardSliverKey,
                    slivers: [
                      // Rows above the anchor, laid out upwards. Empty
                      // (childCount 0) whenever the anchor is 0.
                      SliverPadding(
                        padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildRow(context, colors, anchor - 1 - index),
                            childCount: anchor,
                          ),
                        ),
                      ),
                      SliverPadding(
                        key: _forwardSliverKey,
                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildRow(context, colors, anchor + index),
                            childCount: itemCount - anchor,
                          ),
                        ),
                      ),
                    ],
                  ),
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

/// One transcript row. Public so the 5 000-segment benchmark can assert
/// that only the visible handful is ever materialised.
class TranscriptSegmentTile extends StatelessWidget {
  final TranscriptSegment segment;
  final String displaySpeaker;
  final Color speakerColor;
  final bool isActive;
  final String searchQuery;
  final ValueChanged<String>? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onSeek;
  final ValueChanged<String>? onRename;

  const TranscriptSegmentTile({
    super.key,
    required this.segment,
    required this.displaySpeaker,
    required this.speakerColor,
    this.isActive = false,
    this.searchQuery = '',
    this.onEdit,
    this.onCopy,
    this.onSeek,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final activeBg = speakerColor.withValues(alpha: isActive ? 0.12 : 0.0);
    final activeBorder = isActive ? speakerColor : Colors.transparent;
    // No entry animation: `ListView.builder` recycles elements, so the
    // fade-and-slide replayed on every scroll and on every search keystroke
    // (audit A.1-13), and at 5 000 rows it kept a frame permanently
    // scheduled while the user dragged the scrollbar.
    return Semantics(
      label:
          '${segment.speaker} pada ${formatDuration(Duration(milliseconds: (segment.timestamp * 1000).round()))}: ${segment.text}',
      selected: isActive,
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
            onTap: onSeek ?? (onEdit != null ? () => _openEditDialog(context) : null),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 12,
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
                              fontFeatures: const [FontFeature.tabularFigures()],
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
                                color: colors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Kepercayaan rendah',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.warning,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Action buttons.
                  //
                  // Side by side rather than stacked, and a full
                  // [TouchTarget.minimum] square each: at 32 px these were the
                  // only two targets in the app below the WCAG 2.2 AA 2.5.8
                  // floor, and stacking two 48 px boxes would have made every
                  // transcript row 96 px tall. The icon stays at 16 px, so the
                  // row looks the same — it is the hit area that grew.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onCopy != null)
                        SizedBox.fromSize(
                          size: TouchTarget.minimumSize,
                          child: IconButton(
                            icon: Icon(Icons.copy_outlined, size: 16, color: colors.textTertiary),
                            onPressed: onCopy,
                            padding: EdgeInsets.zero,
                            tooltip: 'Salin segmen',
                          ),
                        ),
                      if (onEdit != null)
                        SizedBox.fromSize(
                          size: TouchTarget.minimumSize,
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
            Text('Ganti Nama Pembicara',
                style: TextStyle(color: colors.text, fontSize: 16)),
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
