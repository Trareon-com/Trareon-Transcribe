import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_shortcuts.dart';
import '../theme/app_tokens.dart';
import '../utils/format_time.dart';
import '../utils/speaker_color.dart';
import '../widgets/empty_state.dart';
import 'karaoke_text.dart';
import 'speaker_avatar.dart';
import '../theme/app_icons.dart';
import 'app_toast.dart';
import '../theme/app_typography.dart';
import 'ui/key_hint.dart';

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
/// Width of the speaker column on every transcript row.
///
/// Fits "Pembicara 1" and "Pembicara 2" in full, plus the avatar plate and the
/// rename pencil. It used to be 72, which truncated the default speaker name
/// to "Pe…" on every row in the app.
const double kSpeakerColumnWidth = 148;

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

  // ── Keyboard-first editing (F20) ────────────────────────────────────
  //
  // A notulis correcting a transcript does the same four things for an
  // hour: fix a word, move a line that landed in the wrong speaker's
  // turn, join a sentence the VAD cut in half, split one the decoder ran
  // together. Doing any of them through a dialog and a mouse is the
  // difference between an hour and three. Null disables the shortcut
  // rather than leaving a key that does nothing.

  /// Move the segment at [index] by [delta] places (Ctrl+↑/↓).
  final void Function(int index, int delta)? onMoveSegment;

  /// Join the segment at [index] onto the one before it (Ctrl+M).
  final void Function(int index)? onMergeWithPrevious;

  /// Split the segment at [index] at [cursorOffset] characters
  /// (Ctrl+Shift+S, while editing).
  final void Function(int index, int cursorOffset)? onSplitSegment;

  /// Playhead position in recording seconds, for the karaoke highlight.
  ///
  /// A listenable, and read only by the row that is actually playing: at
  /// 5 000 segments rebuilding the list on every position tick is what
  /// audit A.3-6 was about.
  final ValueListenable<double>? playheadSecs;

  /// Seek to one word's start (click a word to re-listen to it). Null
  /// leaves the per-word spans rendered but inert, which is the live view.
  final void Function(TranscriptWord word)? onSeekToWord;

  /// The uncommitted tail of the live hypothesis, shown greyed under the
  /// last row.
  ///
  /// LocalAgreement-2 only finalises words two consecutive decodes agree
  /// on, so during a live session there is always a clause or two that has
  /// been heard but not confirmed. Showing it greyed is the honest
  /// rendering: before this it was either published as final (and then
  /// silently contradicted) or not shown at all.
  final String tentativeText;

  /// Offer "Tambahkan ke kamus" after an inline edit changed one word.
  ///
  /// `(before, after)` are the two words. Null hides the offer — the
  /// live-recording view has no glossary to add to mid-session.
  final void Function(String before, String after)? onWordCorrected;

  const TranscriptView({
    super.key,
    required this.segments,
    this.revision = 0,
    this.onEdit,
    this.activeSegmentIndex,
    this.onSeekToSegment,
    this.speakerLabels = const {},
    this.onRenameSpeaker,
    this.onMoveSegment,
    this.onMergeWithPrevious,
    this.onSplitSegment,
    this.playheadSecs,
    this.onSeekToWord,
    this.tentativeText = '',
    this.onWordCorrected,
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

  /// Row the keyboard is on, as an index into [TranscriptView.segments].
  ///
  /// Separate from the playing row: reviewing a transcript and listening
  /// to it are different activities, and tying the cursor to the playhead
  /// would drag it away mid-correction.
  int? _selectedIndex;

  /// Row being edited inline, or null. At most one at a time.
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocus = FocusNode(debugLabel: 'transcript-edit');
  final FocusNode _listFocus = FocusNode(debugLabel: 'transcript-list');

  /// "Tinjau": show only the segments the engine was unsure about (F20).
  bool _reviewOnly = false;
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
    final elapsed = last == null
        ? TranscriptView.kAnnounceThrottle
        : now.difference(last);
    if (elapsed >= TranscriptView.kAnnounceThrottle) {
      _announceNow();
      return;
    }
    _announceTimer?.cancel();
    _announceTimer = Timer(
      TranscriptView.kAnnounceThrottle - elapsed,
      _announceNow,
    );
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
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      TextDirection.ltr,
    );
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
    _editController.dispose();
    _editFocus.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  // ── Keyboard-first editing (F20) ──────────────────────────────────────

  /// Positions currently displayed, as segment indices.
  List<int> get _displayed =>
      _matches ?? [for (var i = 0; i < widget.segments.length; i++) i];

  /// Moves the cursor by [delta] display rows.
  void _moveSelection(int delta) {
    final displayed = _displayed;
    if (displayed.isEmpty) return;
    final current = _selectedIndex;
    final position = current == null ? -1 : displayed.indexOf(current);
    final next = position < 0
        // First press lands on the playing row when there is one, which
        // is where the user is looking.
        ? (_activeIndex != null && displayed.contains(_activeIndex)
              ? displayed.indexOf(_activeIndex!)
              : 0)
        : (position + delta).clamp(0, displayed.length - 1);
    setState(() => _selectedIndex = displayed[next]);
    _revealRow(displayed[next]);
  }

  void _startEditing(int index) {
    if (widget.onEdit == null) return;
    _editController.text = widget.segments[index].text;
    _editController.selection = TextSelection.collapsed(
      offset: _editController.text.length,
    );
    setState(() {
      _selectedIndex = index;
      _editingIndex = index;
    });
    _revealRow(index);
    // After the frame, so the field exists to take focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingIndex == index) _editFocus.requestFocus();
    });
  }

  void _commitEdit() {
    final index = _editingIndex;
    if (index == null) return;
    final text = _editController.text;
    setState(() => _editingIndex = null);
    _listFocus.requestFocus();
    // Committed even when unchanged is wasteful; committed when changed
    // is the whole point.
    if (index < widget.segments.length && text != widget.segments[index].text) {
      final before = widget.segments[index].text;
      widget.onEdit?.call(index, text);
      final correction = singleWordCorrection(before, text);
      if (correction != null) {
        widget.onWordCorrected?.call(correction.$1, correction.$2);
      }
    }
  }

  void _cancelEdit() {
    setState(() => _editingIndex = null);
    _listFocus.requestFocus();
  }

  void _moveSelectedSegment(int delta) {
    final index = _selectedIndex;
    if (index == null || widget.onMoveSegment == null) return;
    final target = index + delta;
    if (target < 0 || target >= widget.segments.length) return;
    widget.onMoveSegment!(index, delta);
    setState(() => _selectedIndex = target);
  }

  void _mergeSelected() {
    final index = _selectedIndex;
    if (index == null || index == 0 || widget.onMergeWithPrevious == null) {
      return;
    }
    widget.onMergeWithPrevious!(index);
    // The merged row *is* the previous one now.
    setState(() => _selectedIndex = index - 1);
  }

  void _splitSelected() {
    final index = _editingIndex;
    if (index == null || widget.onSplitSegment == null) return;
    final offset = _editController.selection.baseOffset;
    final text = _editController.text;
    // A split at either end would produce an empty segment, which is
    // worse than refusing.
    if (offset <= 0 || offset >= text.length) return;
    // The edit has to land first, or the split would run against the
    // text as it was before the user corrected it.
    if (text != widget.segments[index].text) {
      widget.onEdit?.call(index, text);
    }
    setState(() => _editingIndex = null);
    widget.onSplitSegment!(index, offset);
    _listFocus.requestFocus();
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
        _moveSelection(1),
    const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveSelection(-1),
    const SingleActivator(LogicalKeyboardKey.enter): () {
      final index = _selectedIndex;
      if (index != null) _startEditing(index);
    },
    const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): () =>
        _moveSelectedSegment(1),
    const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): () =>
        _moveSelectedSegment(-1),
    const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): () =>
        _moveSelectedSegment(1),
    const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): () =>
        _moveSelectedSegment(-1),
    const SingleActivator(LogicalKeyboardKey.keyM, control: true):
        _mergeSelected,
    const SingleActivator(LogicalKeyboardKey.keyM, meta: true): _mergeSelected,
  };

  /// Shortcuts live while a row is being edited. Deliberately few: a text
  /// field eats most keys, and it should.
  Map<ShortcutActivator, VoidCallback> get _editingShortcuts => {
    const SingleActivator(LogicalKeyboardKey.escape): _cancelEdit,
    const SingleActivator(LogicalKeyboardKey.enter): _commitEdit,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
        _splitSelected,
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
        _splitSelected,
  };

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
    if (query.isEmpty && !_reviewOnly) {
      _matches = null;
      return;
    }
    final segments = widget.segments;
    final matches = <int>[];
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      // "Tinjau" narrows to what the engine flagged; the search box then
      // narrows further, rather than the two fighting each other.
      if (_reviewOnly && !segment.lowConfidence) continue;
      if (query.isEmpty ||
          segment.text.toLowerCase().contains(query) ||
          segment.speaker.toLowerCase().contains(query)) {
        matches.add(i);
      }
    }
    _matches = matches;
  }

  /// One row, addressed by its position in the *displayed* list.
  ///
  /// [firstPartialIndex] is the earliest still-partial segment in the whole
  /// transcript (or -1), computed once per build rather than per row.
  /// Refinement runs front-to-back, so that one row is "Diproses" and every
  /// other partial row behind it is merely "Antre" (Sprint 14b, item 10b) —
  /// a transcript with many segments open at once used to show a spinner on
  /// every one of them with no sense of order.
  Widget _buildRow(
    BuildContext context,
    AppColorSet colors,
    int position, {
    required int firstPartialIndex,
  }) {
    final matches = _matches;
    final originalIndex = matches == null ? position : matches[position];
    final seg = widget.segments[originalIndex];
    final isActive = originalIndex == _activeIndex;
    final displaySpeaker = widget.speakerLabels[seg.speaker] ?? seg.speaker;
    final isSelected = originalIndex == _selectedIndex;
    final isEditing = originalIndex == _editingIndex;
    return TranscriptSegmentTile(
      key: isActive ? _activeRowKey : ValueKey(originalIndex),
      segment: seg,
      displaySpeaker: displaySpeaker,
      speakerColor: speakerColor(seg.speaker, colors),
      isActive: isActive,
      isSelected: isSelected,
      isProcessingNow: originalIndex == firstPartialIndex,
      editController: isEditing ? _editController : null,
      editFocusNode: isEditing ? _editFocus : null,
      onSelect: () {
        if (_selectedIndex != originalIndex) {
          setState(() => _selectedIndex = originalIndex);
        }
        _listFocus.requestFocus();
      },
      // Keyboard editing is available exactly when the host screen can
      // apply the structural edits; the live view cannot, and keeps the
      // dialog.
      onStartInlineEdit: _keyboardEditing && widget.onEdit != null
          ? () => _startEditing(originalIndex)
          : null,
      searchQuery: _searchQuery,
      // Only the playing row follows the playhead. Handing every row the
      // notifier would rebuild 5 000 of them on every position tick.
      playheadSecs: isActive ? widget.playheadSecs : null,
      onSeekToWord: widget.onSeekToWord,
      onSeek: widget.onSeekToSegment == null
          ? null
          : () => widget.onSeekToSegment!(originalIndex, seg),
      onEdit: widget.onEdit == null
          ? null
          : (newText) => widget.onEdit!(originalIndex, newText),
      onCopy: () {
        Clipboard.setData(
          ClipboardData(
            text:
                '[${formatDuration(Duration(milliseconds: (seg.timestamp * 1000).round()))}] ${seg.text}',
          ),
        );
        AppToast.show(
          context,
          'Segmen disalin.',
          type: ToastType.success,
          duration: const Duration(seconds: 2),
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
        .map(
          (s) =>
              '[${s.speaker} · ${formatDuration(Duration(milliseconds: (s.timestamp * 1000).round()))}] ${s.text}',
        )
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    AppToast.show(context, 'Transkrip disalin.', type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    if (widget.segments.isEmpty) {
      return EmptyState(
        icon: AppIcons.mic,
        title: 'Belum ada transkrip',
        subtitle:
            'Mulai sesi untuk memulai transkripsi\n'
            'Tekan Mulai atau ${AppShortcuts.startStop.shortcut.label}',
      );
    }

    final matches = _matches;
    final itemCount = matches?.length ?? widget.segments.length;
    final anchor = _anchorIndex.clamp(0, itemCount);

    return CallbackShortcuts(
      bindings: !_keyboardEditing
          ? const {}
          : (_editingIndex != null ? _editingShortcuts : _shortcuts),
      child: Focus(
        focusNode: _listFocus,
        // Not `autofocus`: this widget also hosts a search box, and
        // stealing focus from it as the user types would be worse than
        // asking for one click before the arrow keys work.
        child: Column(
          children: [
            // Search + Toolbar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  bottom: BorderSide(color: colors.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: FontSizes.body,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari…',
                          hintStyle: TextStyle(
                            color: colors.textTertiary,
                            fontSize: FontSizes.body,
                          ),
                          prefixIcon: Icon(
                            AppIcons.search,
                            size: IconSizes.sm,
                            color: colors.textTertiary,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    AppIcons.clear,
                                    size: IconSizes.xs,
                                    color: colors.textTertiary,
                                  ),
                                  onPressed: _clearSearch,
                                  tooltip: 'Bersihkan pencarian',
                                )
                              : null,
                          filled: true,
                          fillColor: colors.chipBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Radii.md),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  Spacing.hSm,
                  // A live region as well as a label: the count is the one piece
                  // of state on this screen that changes on its own, so a screen
                  // reader should re-read it rather than wait to be asked.
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      [
                        _searchQuery.isEmpty
                            ? '${widget.segments.length} segmen'
                            : '$itemCount dari ${widget.segments.length} segmen',
                        if (_partialCount > 0)
                          '$_partialCount sedang diperbaiki',
                      ].join(' · '),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: FontSizes.caption,
                      ),
                    ),
                  ),
                  Spacing.hXs,
                  if (_isPlayerMode)
                    IconButton(
                      tooltip: _followActive
                          ? 'Ikuti pemutaran: aktif'
                          : 'Ikuti pemutaran: mati',
                      icon: Icon(
                        _followActive ? AppIcons.locate : AppIcons.offline,
                        size: IconSizes.md,
                        color: _followActive
                            ? colors.primary
                            : colors.textTertiary,
                      ),
                      onPressed: () {
                        setState(() => _followActive = !_followActive);
                        final active = _activeIndex;
                        if (_followActive && active != null) _revealRow(active);
                      },
                    )
                  else
                    IconButton(
                      tooltip: _autoScroll
                          ? 'Auto-scroll aktif'
                          : 'Auto-scroll mati',
                      icon: Icon(
                        _autoScroll ? AppIcons.scrollToBottom : AppIcons.pause,
                        size: IconSizes.md,
                        color: _autoScroll
                            ? colors.primary
                            : colors.textTertiary,
                      ),
                      onPressed: () =>
                          setState(() => _autoScroll = !_autoScroll),
                    ),
                  if (_lowConfidenceCount > 0 || _reviewOnly)
                    IconButton(
                      tooltip: _reviewOnly
                          ? 'Tinjau: hanya segmen yang perlu diperiksa'
                          : 'Tinjau ($_lowConfidenceCount segmen perlu diperiksa)',
                      icon: Icon(
                        _reviewOnly ? AppIcons.flagFilled : AppIcons.flag,
                        size: IconSizes.md,
                        color: _reviewOnly
                            ? colors.warning
                            : colors.textTertiary,
                      ),
                      onPressed: () => setState(() {
                        _reviewOnly = !_reviewOnly;
                        _rebuildMatches();
                        // The cursor may now be on a hidden row.
                        if (_selectedIndex != null &&
                            !_displayed.contains(_selectedIndex)) {
                          _selectedIndex = null;
                          _editingIndex = null;
                        }
                      }),
                    ),
                  IconButton(
                    tooltip: 'Salin semua',
                    icon: Icon(
                      AppIcons.copy,
                      size: IconSizes.md,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => _copyAllToClipboard(context),
                  ),
                ],
              ),
            ),

            // Transcript list
            Expanded(
              child: itemCount == 0
                  ? (widget.tentativeText.isEmpty
                        ? const EmptyState(
                            icon: AppIcons.searchOff,
                            title: 'Tidak ada segmen cocok',
                          )
                        // Nothing final yet, but the engine has heard
                        // something. An empty state here would read as
                        // "this is not working".
                        : Padding(
                            padding: const EdgeInsets.all(Spacing.md),
                            child: _TentativeLine(
                              text: widget.tentativeText,
                              colors: colors,
                            ),
                          ))
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
                            padding: const EdgeInsets.only(
                              left: Spacing.md,
                              right: Spacing.md,
                              top: Spacing.sm,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildRow(
                                  context,
                                  colors,
                                  anchor - 1 - index,
                                  firstPartialIndex: _firstPartialIndex,
                                ),
                                childCount: anchor,
                              ),
                            ),
                          ),
                          SliverPadding(
                            key: _forwardSliverKey,
                            padding: const EdgeInsets.only(
                              left: Spacing.md,
                              right: Spacing.md,
                              bottom: Spacing.sm,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildRow(
                                  context,
                                  colors,
                                  anchor + index,
                                  firstPartialIndex: _firstPartialIndex,
                                ),
                                childCount: itemCount - anchor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // The uncommitted tail, under the list rather than inside it:
            // it is not a transcript row, it has no timestamp and no
            // speaker, and it replaces itself every couple of seconds.
            if (widget.tentativeText.isNotEmpty && itemCount > 0)
              Padding(
                padding: const EdgeInsets.only(
                  left: Spacing.md,
                  right: Spacing.md,
                  bottom: Spacing.sm,
                ),
                child: _TentativeLine(
                  text: widget.tentativeText,
                  colors: colors,
                ),
              ),
            if (_keyboardEditing && widget.onEdit != null && itemCount > 0)
              _ShortcutHint(colors: colors, editing: _editingIndex != null),
          ],
        ),
      ),
    );
  }

  /// Whether this list offers keyboard editing (F20).
  ///
  /// Keyed off the structural callbacks rather than a flag: a screen that
  /// cannot move or split a segment has no business pretending the keys
  /// work.
  bool get _keyboardEditing =>
      widget.onMoveSegment != null ||
      widget.onMergeWithPrevious != null ||
      widget.onSplitSegment != null;

  /// How many segments the engine flagged as uncertain.
  int get _lowConfidenceCount =>
      widget.segments.where((s) => s.lowConfidence).length;

  /// How many segments a background refine pass has not finished yet
  /// (Sprint 14b, item 10b) — shown once as a count rather than as one
  /// spinner per row.
  int get _partialCount => widget.segments.where((s) => s.isPartial).length;

  /// Index of the earliest segment still partial, or -1 when none are.
  int get _firstPartialIndex => widget.segments.indexWhere((s) => s.isPartial);
}

/// The one-line crib for the editing keys.
///
/// On screen rather than in a help dialog: a shortcut nobody knows about
/// is a shortcut nobody uses, and this is the screen where they matter.
class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint({required this.colors, required this.editing});

  final AppColorSet colors;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Text(
        editing
            ? 'Enter simpan · Esc batal · '
                  '${const AppShortcut('S', primary: true, shift: true).label} '
                  'pisah di kursor'
            : '↑↓ pilih · Enter sunting · '
                  '${const AppShortcut('↑↓', primary: true).label} pindahkan · '
                  '${const AppShortcut('M', primary: true).label} gabung ke atas',
        style: TextStyle(fontSize: FontSizes.micro, color: colors.textTertiary),
      ),
    );
  }
}

/// Highlight [query] in [text] using the given [style] for matches.
/// Returns a list of TextSpans.
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

  /// Row the keyboard cursor is on (F20). Drawn differently from
  /// [isActive]: one is "where you are", the other "what is playing",
  /// and they are routinely different rows.
  final bool isSelected;

  /// Non-null while this row is being edited inline; the controller and
  /// focus node belong to the list, so only one row can be editing.
  final TextEditingController? editController;
  final FocusNode? editFocusNode;

  /// Puts the keyboard cursor here without starting an edit.
  final VoidCallback? onSelect;

  /// Starts the inline editor on this row.
  ///
  /// When non-null it replaces the modal edit dialog: a screen that has
  /// keyboard editing should not also pop a dialog on every click, and
  /// two ways to edit one row is one too many. The live-recording view
  /// passes null and keeps the dialog.
  final VoidCallback? onStartInlineEdit;

  /// Playhead position, for the karaoke highlight. Non-null only on the
  /// row that is playing.
  final ValueListenable<double>? playheadSecs;

  /// Seek to one word's start.
  final void Function(TranscriptWord word)? onSeekToWord;

  /// True for the one partial segment currently being refined — the rest of
  /// a session's partial segments are merely queued behind it (Sprint 14b,
  /// item 10b).
  final bool isProcessingNow;

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
    this.isSelected = false,
    this.editController,
    this.editFocusNode,
    this.onSelect,
    this.onStartInlineEdit,
    this.playheadSecs,
    this.onSeekToWord,
    this.isProcessingNow = false,
  });

  bool get _isEditing => editController != null;

  /// The transcript line itself.
  ///
  /// Rebuilt on every playhead tick when this is the playing row and the
  /// segment has word timings — which is the only case where the output
  /// actually changes with position. Everywhere else it is built once.
  Widget _body(AppColorSet colors) {
    final style = AppText.reading.c(colors.text);
    final listenable = playheadSecs;
    if (listenable == null || !segment.hasWordTimings) {
      return KaraokeText(
        words: segment.words,
        fallbackText: segment.text,
        searchQuery: searchQuery,
        baseStyle: style,
        searchHighlight: speakerColor,
        onTapWord: onSeekToWord,
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, position, _) => KaraokeText(
        words: segment.words,
        fallbackText: segment.text,
        searchQuery: searchQuery,
        baseStyle: style,
        searchHighlight: speakerColor,
        positionSecs: position,
        onTapWord: onSeekToWord,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final activeBg = speakerColor.withValues(alpha: isActive ? 0.12 : 0.0);
    final showOutline = isActive || isSelected;
    final activeBorder = isActive
        ? speakerColor
        : (isSelected ? colors.primary : Colors.transparent);
    // No entry animation: `ListView.builder` recycles elements, so the
    // fade-and-slide replayed on every scroll and on every search keystroke
    // (audit A.1-13), and at 5 000 rows it kept a frame permanently
    // scheduled while the user dragged the scrollbar.
    return Semantics(
      label:
          '${segment.speaker} pada ${formatDuration(Duration(milliseconds: (segment.timestamp * 1000).round()))}: ${segment.text}',
      selected: isActive,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Container(
          decoration: BoxDecoration(
            color: activeBg,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: activeBorder.withValues(alpha: showOutline ? 0.5 : 0.0),
              width: showOutline ? 1.5 : 0,
            ),
          ),
          child: InkWell(
            onTap: () {
              // A click puts the keyboard cursor here as well as doing
              // whatever the click already did, so the arrow keys carry
              // on from where the user pointed.
              onSelect?.call();
              if (onSeek != null) {
                onSeek!();
              } else if (onStartInlineEdit == null && onEdit != null) {
                // No keyboard editing here (the live view): the dialog is
                // still the only way to fix a line.
                _openEditDialog(context);
              }
            },
            borderRadius: BorderRadius.circular(Radii.md),
            child: Padding(
              padding: const EdgeInsets.only(
                left: Spacing.md,
                right: Spacing.sm,
                top: Spacing.sm,
                bottom: Spacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline strip (garis vertikal kecil)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(
                      top: Spacing.xs,
                      right: Spacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: speakerColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                  ),
                  // Speaker label + time.
                  //
                  // 120 px, not 72: at 72 every row in the app read
                  // "Pe…" because the default speaker name is "Pembicara 1".
                  SizedBox(
                    width: kSpeakerColumnWidth,
                    child: GestureDetector(
                      onTap: onRename != null
                          ? () => _openRenameDialog(context)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SpeakerAvatar(
                                name: displaySpeaker,
                                color: speakerColor,
                                size: IconSizes.lg,
                              ),
                              Spacing.hSm,
                              Flexible(
                                child: Text(
                                  displaySpeaker,
                                  style: AppText.captionStrong.c(speakerColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (onRename != null) ...[
                                Spacing.hXs,
                                Icon(
                                  AppIcons.edit,
                                  size: IconSizes.xs,
                                  color: speakerColor.withValues(alpha: 0.6),
                                ),
                              ],
                            ],
                          ),
                          Spacing.gapXs,
                          Text(
                            formatDuration(
                              Duration(
                                milliseconds: (segment.timestamp * 1000)
                                    .round(),
                              ),
                            ),
                            style: AppText.monoMicro.c(colors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Spacing.hSm,
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditing)
                          TextField(
                            controller: editController,
                            focusNode: editFocusNode,
                            maxLines: null,
                            style: AppText.reading.c(colors.text),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(Spacing.sm),
                            ),
                          )
                        else
                          // `KaraokeText` renders word by word when the
                          // segment carries word timestamps, and falls
                          // back to one span of plain text when it does
                          // not (every transcript written before Sprint
                          // 4b). It uses `Text.rich` rather than
                          // `RichText` either way: RichText does not merge
                          // DefaultTextStyle, so this text — the most read
                          // text in the whole app — rendered in the
                          // platform fallback face instead of the bundled
                          // Inter until a golden caught it.
                          _body(colors),
                        if (segment.isPartial) ...[
                          Spacing.gapXs,
                          // Only the segment actually being refined gets a
                          // spinner; every other queued one gets a plain
                          // "Antre" label. A transcript with dozens of
                          // partial segments open at once used to show
                          // dozens of identical, meaningless spinners
                          // (Sprint 14b, item 10b).
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isProcessingNow)
                                SizedBox(
                                  width: 9,
                                  height: 9,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.4,
                                    color: colors.primary,
                                  ),
                                )
                              else
                                Icon(
                                  AppIcons.clock,
                                  size: 9,
                                  color: colors.textTertiary,
                                ),
                              Spacing.hXs,
                              Text(
                                isProcessingNow ? 'Diproses…' : 'Antre',
                                style: TextStyle(
                                  fontSize: FontSizes.overline,
                                  color: colors.textTertiary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (segment.lowConfidence) ...[
                          Spacing.gapXs,
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.warning,
                                size: IconSizes.xs,
                                color: colors.warning,
                              ),
                              Spacing.hXs,
                              Text(
                                'Kepercayaan rendah',
                                style: TextStyle(
                                  fontSize: FontSizes.overline,
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
                            icon: Icon(
                              AppIcons.copy,
                              size: IconSizes.sm,
                              color: colors.textTertiary,
                            ),
                            onPressed: onCopy,
                            padding: EdgeInsets.zero,
                            tooltip: 'Salin segmen',
                          ),
                        ),
                      if (onEdit != null)
                        SizedBox.fromSize(
                          size: TouchTarget.minimumSize,
                          child: IconButton(
                            icon: Icon(
                              AppIcons.edit,
                              size: IconSizes.sm,
                              color: colors.textTertiary,
                            ),
                            onPressed:
                                onStartInlineEdit ??
                                () => _openEditDialog(context),
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
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
            Spacing.hSm,
            Text(
              'Edit Transkrip',
              style: TextStyle(color: colors.text, fontSize: FontSizes.title),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 3,
          style: TextStyle(
            color: colors.text,
            fontSize: FontSizes.bodyLarge,
            height: 1.4,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            filled: true,
            fillColor: colors.chipBackground,
            hintText: 'Ketik koreksi transkrip…',
            hintStyle: TextStyle(
              color: colors.textTertiary,
              fontSize: FontSizes.body,
            ),
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
      if (newText != null &&
          newText.trim().isNotEmpty &&
          newText != segment.text) {
        onEdit?.call(newText);
      }
    });
  }

  void _openRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: displaySpeaker);
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
            Spacing.hSm,
            Text(
              'Ganti Nama Pembicara',
              style: TextStyle(color: colors.text, fontSize: FontSizes.title),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.text, fontSize: FontSizes.bodyLarge),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            filled: true,
            fillColor: colors.chipBackground,
            hintText: 'Nama baru…',
            hintStyle: TextStyle(
              color: colors.textTertiary,
              fontSize: FontSizes.body,
            ),
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

/// The greyed "sementara" line: words the engine has heard but has not
/// confirmed.
///
/// LocalAgreement-2 commits a word only once two consecutive decodes agree
/// on it (see `rust_core/src/streaming.rs`). Everything after that prefix
/// is genuinely provisional, and the honest thing to do with it is show it
/// and say so. Before this it was published as final and then silently
/// contradicted by the post-meeting pass.
class _TentativeLine extends StatelessWidget {
  final String text;
  final AppColorSet colors;

  const _TentativeLine({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: false,
      label: 'Sementara, belum final: $text',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: kSpeakerColumnWidth, child: SizedBox.shrink()),
          Spacing.hSm,
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'sementara · ',
                    style: AppText.overline.c(colors.textTertiary),
                  ),
                  TextSpan(
                    text: text,
                    style: AppText.reading
                        .c(colors.textTertiary)
                        .copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one word an edit changed, or `null` when the edit was anything else.
///
/// This is what turns a correction into something the app can learn from
/// ("Tambahkan ke kamus" / "Ganti otomatis selanjutnya"). Deliberately
/// narrow: only an edit that leaves the word count unchanged and differs in
/// exactly one position counts. A user who rewrote a sentence did not teach
/// us a vocabulary item, and offering to add half of it to the kamus would
/// train them to dismiss the offer.
///
/// Returns `(before, after)`.
(String, String)? singleWordCorrection(String before, String after) {
  final from = before.trim().split(RegExp(r'\s+'));
  final to = after.trim().split(RegExp(r'\s+'));
  if (from.length != to.length || from.isEmpty) return null;
  int? changed;
  for (var i = 0; i < from.length; i++) {
    if (from[i] == to[i]) continue;
    if (changed != null) return null;
    changed = i;
  }
  if (changed == null) return null;
  // Punctuation is not a word. "anggaran" -> "anggaran." taught nothing,
  // and a rule keyed on the comma would fire on the wrong word later.
  final strippedFrom = _wordCore(from[changed]);
  final strippedTo = _wordCore(to[changed]);
  if (strippedFrom.isEmpty || strippedTo.isEmpty) return null;
  if (strippedFrom.toLowerCase() == strippedTo.toLowerCase()) return null;
  return (strippedFrom, strippedTo);
}

/// A word without its surrounding punctuation.
String _wordCore(String word) => word.replaceAll(
  RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
  '',
);
