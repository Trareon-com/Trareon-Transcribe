import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/session_store.dart';
import '../utils/atomic_file.dart';
import '../utils/model_labels.dart';
import '../utils/segment_lookup.dart';
import '../state/enhance_queue_model.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/bookmark_bar.dart';
import '../widgets/completion_banner.dart';
import '../widgets/export_dialog.dart';
import '../widgets/notulen_dialog.dart';
import '../widgets/retranscribe_dialog.dart';
import '../widgets/summary_panel.dart';
import '../widgets/transcript_view.dart';

/// Playback speeds offered by the player. 0.75× is the slowest useful speed
/// for re-listening to an unclear passage; below that Indonesian speech
/// stops being easier to follow, it just takes longer.
const List<double> kPlaybackSpeeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// How far the ←/→ keys jump. Matches what every review-oriented player
/// (Otter, tl;dv) binds them to; J/L take the coarser 10 s step.
const double kArrowSeekSeconds = 5;
const double kJlSeekSeconds = 10;

class TranscriptPlayerScreen extends ConsumerStatefulWidget {
  final String title;
  final double durationSeconds;
  final List<TranscriptSegment> segments;
  final String? audioPath;
  final ValueChanged<List<TranscriptSegment>>? onSegmentsChanged;

  /// Session directory. Required for the summary sidecar and re-transcribe;
  /// when null (e.g. a live session not yet saved) both are hidden rather
  /// than offered and then failing on save.
  final String? sessionDirPath;

  /// Sidecar contents, so the summary panel opens with the saved summary
  /// instead of flashing empty while it re-reads the file.
  final SessionMeta meta;

  /// What the back button does. Null means "pop the route", which is what
  /// it always did; the main screen embeds this player in its workspace
  /// instead of pushing it, and there closing means clearing the
  /// selection rather than popping anything.
  final VoidCallback? onClose;

  /// Where to land when the screen opens, in seconds.
  ///
  /// A citation — from "Tanya arsip rapat" (F12) or a summary bullet in
  /// another session (F7) — names a moment, not just a meeting, and
  /// dumping the user at 0:00 of a two-hour recording loses exactly the
  /// thing the citation was for.
  final double? initialSeekSeconds;

  const TranscriptPlayerScreen({
    super.key,
    required this.title,
    required this.durationSeconds,
    required this.segments,
    this.audioPath,
    this.onSegmentsChanged,
    this.sessionDirPath,
    this.meta = SessionMeta.empty,
    this.onClose,
    this.initialSeekSeconds,
  });

  @override
  ConsumerState<TranscriptPlayerScreen> createState() => _TranscriptPlayerScreenState();
}

class _TranscriptPlayerScreenState extends ConsumerState<TranscriptPlayerScreen> {
  /// Playback position, in seconds.
  ///
  /// A [ValueNotifier] rather than `setState`: `audioplayers` emits at
  /// 5–10 Hz and each tick used to rebuild the whole screen including the
  /// full transcript list (audit A.3-6). Only the seek bar and the clock
  /// listen to it now.
  final ValueNotifier<double> _position = ValueNotifier<double>(0);

  /// Row currently being played. Derived from [_position] with a binary
  /// search, so it only notifies when the row actually changes (~0.5 Hz).
  final ValueNotifier<int?> _activeIndex = ValueNotifier<int?>(null);

  final ValueNotifier<bool> _playing = ValueNotifier<bool>(false);

  double _speed = 1.0;
  late List<TranscriptSegment> _segments;
  late SegmentTimeline _timeline;

  /// Bumped whenever [_segments] changes in place, so [TranscriptView] can
  /// invalidate its cached search results.
  int _revision = 0;

  final AudioPlayer _player = AudioPlayer();
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'transcript-player');
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  Duration? _duration;
  String? _error;
  Timer? _persistDebounce;

  /// Set when saving an edit failed. Persistent, with a retry: this used
  /// to be a `debugPrint`, so an edit the user watched appear on screen
  /// was silently never written.
  String? _saveError;
  bool _retryingSave = false;

  /// Whether a pre-"Transkrip Ulang" copy exists to restore from.
  bool _hasBackup = false;

  /// Latest saved summary, kept here so "Ekspor" can lead the Markdown/DOCX
  /// with it without re-reading the sidecar.
  late String _summary;

  /// Markers from the recording (F9), editable here too: reviewing is when a
  /// notulis realises which moments actually mattered.
  late List<Bookmark> _bookmarks;

  /// The notulen form as last filled in, so reopening the dialog does not
  /// present an empty form.
  NotulenFormData? _notulenForm;

  @override
  void initState() {
    super.initState();
    _segments = List.of(widget.segments);
    _timeline = SegmentTimeline(_segments);
    // Highlight the cited line before the audio is even loaded, so the
    // jump is visible on a session whose audio was deleted by the
    // retention policy (F13) as well as on one that still has it.
    final jump = widget.initialSeekSeconds;
    if (jump != null && jump > 0) {
      _position.value = jump;
      _activeIndex.value = _timeline.indexAt(jump);
    }
    _summary = widget.meta.summary;
    _bookmarks = List.of(widget.meta.bookmarks);
    _notulenForm = widget.meta.notulen;
    _refreshBackupAvailability();
    _initPlayer();
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────

  /// Persists the sidecar fields this screen owns (bookmarks, notulen form).
  ///
  /// Best effort and separate from [_persistSegments]: the transcript is the
  /// primary artifact and must not fail to save because a marker did.
  Future<void> _persistMeta() async {
    final dirPath = _sessionDirPath;
    if (dirPath == null) return;
    try {
      final existing = await readSessionMeta(dirPath);
      await writeSessionMeta(
        dirPath,
        existing.copyWith(bookmarks: _bookmarks, notulen: _notulenForm),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saveError = 'Tanda poin gagal disimpan: $e');
      }
    }
  }

  void _addBookmarkHere() {
    final bookmark = Bookmark(timestamp: _position.value, note: '');
    setState(() {
      _bookmarks = [..._bookmarks, bookmark]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    unawaited(_persistMeta());
  }

  void _removeBookmark(Bookmark bookmark) {
    setState(() {
      _bookmarks = _bookmarks
          .where((b) => b.timestamp != bookmark.timestamp)
          .toList();
    });
    unawaited(_persistMeta());
  }

  Future<void> _editBookmarkNote(Bookmark bookmark) async {
    final note = await showBookmarkNoteDialog(
      context,
      timestamp: bookmark.timestamp,
      initial: bookmark.note,
    );
    if (note == null || !mounted) return;
    setState(() {
      _bookmarks = [
        for (final b in _bookmarks)
          if (b.timestamp == bookmark.timestamp)
            Bookmark(timestamp: b.timestamp, note: note.trim())
          else
            b,
      ];
    });
    unawaited(_persistMeta());
  }

  // ── Notulen resmi (F2) ────────────────────────────────────────────────

  Future<void> _openNotulen() async {
    final session = SessionSummary(
      id: _sessionDirPath ?? widget.title,
      title: widget.title,
      date: DateTime.now().toIso8601String().substring(0, 10),
      segmentsCount: _segments.length,
      segments: _segments,
      durationSeconds: widget.durationSeconds,
    );
    final saved = await showNotulenDialog(
      context,
      session: session,
      recordedAt: _recordedAt,
      summary: _summary,
      bookmarks: _bookmarks,
      saved: _notulenForm,
    );
    if (saved == null || !mounted) return;
    setState(() => _notulenForm = saved);
    await _persistMeta();
  }

  /// When the meeting happened, for the notulen's hari/tanggal fields.
  ///
  /// Taken from the session folder's name (`YYYYMMDD-…`), which the exporter
  /// writes, falling back to the directory's modification time and finally to
  /// now — a notulen dated today for a meeting from last week is a document
  /// the secretariat would have to correct by hand.
  DateTime get _recordedAt {
    final dirPath = _sessionDirPath;
    if (dirPath != null) {
      final name = dirPath.split(Platform.pathSeparator).last;
      final match = RegExp(r'^(\d{4})(\d{2})(\d{2})-').firstMatch(name);
      if (match != null) {
        final parsed = DateTime.tryParse(
          '${match.group(1)}-${match.group(2)}-${match.group(3)}',
        );
        if (parsed != null) {
          // Keep the time of day from the folder's mtime when we have it.
          try {
            final stat = Directory(dirPath).statSync();
            return DateTime(
              parsed.year,
              parsed.month,
              parsed.day,
              stat.modified.hour,
              stat.modified.minute,
            );
          } catch (_) {
            return parsed;
          }
        }
      }
    }
    return DateTime.now();
  }

  void _refreshBackupAvailability() {
    final dirPath = _sessionDirPath;
    final hasBackup = dirPath != null && transcriptBackupIn(dirPath) != null;
    if (hasBackup == _hasBackup) return;
    if (mounted) {
      setState(() => _hasBackup = hasBackup);
    } else {
      _hasBackup = hasBackup;
    }
  }

  /// Re-derives everything that depends on the segment list after an edit,
  /// a rename, a re-transcribe or a restore.
  void _onSegmentsMutated() {
    _timeline = SegmentTimeline(_segments);
    _revision++;
    _activeIndex.value = _timeline.indexAt(_position.value);
    widget.onSegmentsChanged?.call(List.unmodifiable(_segments));
  }

  Future<void> _initPlayer() async {
    if (widget.audioPath == null) {
      setState(() => _error = 'File audio sumber tidak tersedia untuk diputar.');
      return;
    }
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      await _player.setPlaybackRate(_speed);
      await _player.setSourceDeviceFile(widget.audioPath!);
      final duration = await _player.getDuration();
      if (mounted) setState(() => _duration = duration);
      // Before the position subscription, not after: the player's first
      // tick is 0:00 and would otherwise drag the highlight back off the
      // cited line.
      if (_position.value > 0) await _seekTo(_position.value);
      _positionSub = _player.onPositionChanged.listen((position) {
        final seconds = position.inMilliseconds / 1000.0;
        _position.value = seconds;
        _activeIndex.value = _timeline.indexAt(seconds);
      });
      _playerStateSub = _player.onPlayerStateChanged.listen((state) {
        _playing.value = state == PlayerState.playing;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _editSegment(int index, String newText) {
    setState(() {
      _segments[index] = _segments[index].copyWith(text: newText);
    });
    _onSegmentsMutated();
    _schedulePersist();
  }

  void _renameSpeaker(String oldLabel, String newLabel) {
    setState(() {
      _segments = _segments
          .map((s) =>
              s.speaker == oldLabel ? s.copyWith(speaker: newLabel) : s)
          .toList();
    });
    _onSegmentsMutated();
    _schedulePersist();
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), _persistSegments);
  }

  /// Resolves the session directory. Prefers the explicit path; falls back to
  /// the audio file's parent for callers that only know where the audio is.
  String? get _sessionDirPath =>
      widget.sessionDirPath ??
      (widget.audioPath != null ? File(widget.audioPath!).parent.path : null);

  /// Writes the edited transcript back over the exported `*.json`.
  ///
  /// Atomic (temp + rename in the same directory): this fires on a 400 ms
  /// debounce after every keystroke-driven edit, so an interrupted write
  /// used to be able to truncate the file the edit was improving. A
  /// failure is surfaced, not `debugPrint`ed.
  Future<void> _persistSegments({String? toDirectory}) async {
    final dirPath = toDirectory ?? _sessionDirPath;
    if (dirPath == null) return;
    try {
      final sessionDir = Directory(dirPath);
      // transcriptFileIn() skips the metadata sidecar and the re-transcribe
      // backup — both are JSON too, and overwriting either would cost the
      // saved summary or the undo copy.
      final jsonFile = (toDirectory == null ? transcriptFileIn(sessionDir) : null) ??
          File('${sessionDir.path}${Platform.pathSeparator}transcript.json');
      await writeStringAtomic(jsonFile, encodeTranscriptJson(_segments));
      if (mounted && _saveError != null) setState(() => _saveError = null);
    } catch (e) {
      if (!mounted) {
        debugPrint('_persistSegments error: $e');
        return;
      }
      setState(
        () => _saveError = 'Perubahan transkrip gagal disimpan ke $dirPath: $e',
      );
    }
  }

  Future<void> _retrySave({bool elsewhere = false}) async {
    String? directory;
    if (elsewhere) {
      directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Simpan transkrip ke folder lain',
        initialDirectory: _sessionDirPath,
      );
      if (directory == null) return;
    }
    if (!mounted) return;
    setState(() => _retryingSave = true);
    await _persistSegments(toDirectory: directory);
    if (!mounted) return;
    setState(() => _retryingSave = false);
    if (_saveError == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transkrip tersimpan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Replaces the transcript with a re-run over the same audio, then persists
  /// it. The summary is deliberately left alone: it may have been edited by
  /// hand, and silently discarding it would be worse than letting the user
  /// press "Buat Ulang" themselves.
  ///
  /// The current transcript is copied aside first. Re-transcribing used to
  /// overwrite hand corrections outright — an hour of careful editing
  /// destroyed by one button, with no undo and no backup.
  Future<void> _retranscribe() async {
    final audioPath = widget.audioPath;
    final dirPath = _sessionDirPath;
    if (audioPath == null || dirPath == null) return;

    final result = await showRetranscribeDialog(
      context,
      audioPath: audioPath,
      currentModel: widget.meta.model,
      currentLanguage: widget.meta.language,
    );
    if (result == null || !mounted) return;

    // Before anything is replaced. A backup that fails must stop the
    // replacement, not proceed without it.
    try {
      await backupTranscript(dirPath, _segments);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _saveError =
            'Transkrip lama gagal dicadangkan ($e), jadi transkrip ulang '
            'dibatalkan. Transkrip Anda tidak diubah.',
      );
      return;
    }
    if (!mounted) return;
    _refreshBackupAvailability();

    setState(() => _segments = result.segments);
    _onSegmentsMutated();
    await _persistSegments();
    try {
      final existing = await readSessionMeta(dirPath);
      await writeSessionMeta(
        dirPath,
        existing.copyWith(model: result.modelId, language: result.language),
      );
    } catch (_) {
      // Sidecar bookkeeping only — the transcript itself is already saved.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Transkrip diperbarui: ${result.segments.length} segmen '
          '(${modelDisplayLabel(result.modelId)}). Versi sebelumnya '
          'dicadangkan.',
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Pulihkan',
          onPressed: _restoreBackup,
        ),
      ),
    );
  }

  /// Puts back the transcript "Transkrip Ulang" replaced.
  Future<void> _restoreBackup() async {
    final dirPath = _sessionDirPath;
    if (dirPath == null) return;
    final restored = await readTranscriptBackup(dirPath);
    if (!mounted) return;
    if (restored == null) {
      setState(() => _saveError = 'Cadangan transkrip tidak bisa dibaca.');
      return;
    }
    setState(() => _segments = restored);
    _onSegmentsMutated();
    await _persistSegments();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transkrip sebelum transkrip ulang dipulihkan '
            '(${restored.length} segmen).'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(double secs) {
    final total = secs.isFinite && secs > 0 ? secs : 0.0;
    final h = (total / 3600).floor();
    final m = ((total % 3600) / 60).floor();
    final s = (total % 60).floor();
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    // A three-hour recording needs the hour field; "180:14" is unreadable.
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  double get _maxSeconds => (widget.durationSeconds > 0
          ? widget.durationSeconds
          : (_duration?.inMilliseconds ?? 0) / 1000.0)
      .toDouble()
      .clamp(1.0, double.infinity);

  Future<void> _togglePlayback() async {
    if (widget.audioPath == null) return;
    try {
      if (_playing.value) {
        await _player.pause();
      } else {
        await _player.setPlaybackRate(_speed);
        if (_position.value > 0) {
          await _player.seek(
            Duration(milliseconds: (_position.value * 1000).round()),
          );
        }
        await _player.resume();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _seekTo(double seconds) async {
    if (widget.audioPath == null) return;
    final target = seconds.clamp(0.0, _maxSeconds).toDouble();
    // Move the highlight immediately rather than waiting for the player's
    // next position tick — clicking a line should feel instant.
    _position.value = target;
    _activeIndex.value = _timeline.indexAt(target);
    try {
      await _player.seek(Duration(milliseconds: (target * 1000).round()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _seekBy(double deltaSeconds) => unawaited(_seekTo(_position.value + deltaSeconds));

  /// Click a transcript line → hear it. The core review loop for a long
  /// recording, and the single most-requested thing missing from the app
  /// (blueprint F1).
  void _seekToSegment(int index, TranscriptSegment segment) {
    unawaited(_seekTo(segment.timestamp));
  }

  Future<void> _setSpeed(double value) async {
    setState(() => _speed = value);
    try {
      await _player.setPlaybackRate(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _keyboardFocus.dispose();
    _position.dispose();
    _activeIndex.dispose();
    _playing.dispose();
    _player.dispose();
    super.dispose();
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            unawaited(_togglePlayback()),
        const SingleActivator(LogicalKeyboardKey.keyK): () =>
            unawaited(_togglePlayback()),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seekBy(-kArrowSeekSeconds),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seekBy(kArrowSeekSeconds),
        const SingleActivator(LogicalKeyboardKey.keyJ): () =>
            _seekBy(-kJlSeekSeconds),
        const SingleActivator(LogicalKeyboardKey.keyL): () =>
            _seekBy(kJlSeekSeconds),
      };

  /// Pulls the transcript back off disk after a background pass rewrote it.
  ///
  /// The completion pass (ITEM 0) writes directly to the session's JSON, so
  /// a player left open while it runs would otherwise keep showing the
  /// 8-second transcript the live pass produced, with no way to see the
  /// recovered text short of closing and reopening the session. Edits in
  /// flight are not clobbered: `_persistSegments` runs on a 400 ms debounce
  /// and the reload only happens when a pass finishes.
  Future<void> _reloadFromDisk() async {
    final dirPath = _sessionDirPath;
    if (dirPath == null) return;
    try {
      final file = transcriptFileIn(Directory(dirPath));
      if (file == null) return;
      final segments = parseTranscriptJson(await file.readAsString());
      if (!mounted || segments.isEmpty) return;
      setState(() {
        _segments
          ..clear()
          ..addAll(segments);
        _revision++;
      });
    } catch (e) {
      debugPrint('transcript reload failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final maxSeconds = _maxSeconds;
    final hasAudio = widget.audioPath != null;

    final dirPath = _sessionDirPath;
    if (dirPath != null) {
      ref.listen<EnhanceQueueState>(enhanceQueueProvider, (previous, next) {
        final wasRunning = previous?.isCompletingSession(dirPath) ?? false;
        if (wasRunning && !next.isCompletingSession(dirPath)) {
          unawaited(_reloadFromDisk());
        }
      });
    }

    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(
        focusNode: _keyboardFocus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.headerBackground,
            foregroundColor: colors.text,
            title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                widget.onClose != null
                    ? Icons.close
                    : Icons.arrow_back_ios_new,
                size: 20,
              ),
              onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
              tooltip: widget.onClose != null ? 'Tutup sesi' : 'Kembali',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.keyboard_outlined, size: 20),
                tooltip: 'Pintasan: Spasi putar/jeda · ←/→ 5 detik · J/K/L 10 detik',
                onPressed: () => _showShortcutHelp(context, colors),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_saveError != null)
                Material(
                  color: colors.error.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colors.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _saveError!,
                              style: TextStyle(color: colors.text, fontSize: 12),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _retryingSave
                              ? null
                              : () => _retrySave(elsewhere: true),
                          child: const Text('Simpan ke folder lain'),
                        ),
                        FilledButton(
                          onPressed: _retryingSave ? null : () => _retrySave(),
                          child: Text(_retryingSave ? 'Menyimpan…' : 'Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_sessionDirPath != null)
                CompletionBanner(sessionDirPath: _sessionDirPath!),
              if (_sessionDirPath != null)
                SummaryPanel(
                  sessionDirPath: _sessionDirPath!,
                  segments: () => _segments,
                  initialMeta: widget.meta,
                  bookmarks: _bookmarks,
                  onSummaryChanged: (text) => setState(() => _summary = text),
                ),

              // Transcript
              Expanded(
                child: TranscriptView(
                  segments: _segments,
                  revision: _revision,
                  onEdit: _editSegment,
                  onRenameSpeaker: _renameSpeaker,
                  activeSegmentIndex: _activeIndex,
                  onSeekToSegment: hasAudio ? _seekToSegment : null,
                ),
              ),

              // Player controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: Column(
                  children: [
                    if (_error != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _error!,
                          style: TextStyle(color: colors.error, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    BookmarkTicks(
                      bookmarks: _bookmarks,
                      maxSeconds: maxSeconds,
                      onJump: (bookmark) => unawaited(
                        _seekTo(bookmark.timestamp),
                      ),
                    ),
                    // Seek slider — the only part of the screen that follows
                    // the 5–10 Hz position stream.
                    ValueListenableBuilder<double>(
                      valueListenable: _position,
                      builder: (context, seconds, _) => Row(
                        children: [
                          Text(_formatTime(seconds),
                              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: seconds.clamp(0.0, maxSeconds).toDouble(),
                              max: maxSeconds,
                              activeColor: colors.primary,
                              onChanged: hasAudio
                                  ? (v) => _position.value = v
                                  : null,
                              onChangeEnd: hasAudio ? _seekTo : null,
                            ),
                          ),
                          Text(_formatTime(maxSeconds),
                              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),

                    // Play controls + speed
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 24,
                          icon: const Icon(Icons.replay_10),
                          color: colors.textSecondary,
                          onPressed: hasAudio ? () => _seekBy(-kJlSeekSeconds) : null,
                          tooltip: 'Mundur 10 detik (J)',
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<bool>(
                          valueListenable: _playing,
                          builder: (context, playing, _) => IconButton(
                            iconSize: 40,
                            icon: Icon(
                              playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: colors.primary,
                            ),
                            tooltip: playing ? 'Jeda (Spasi)' : 'Putar (Spasi)',
                            onPressed: hasAudio ? _togglePlayback : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          iconSize: 24,
                          icon: const Icon(Icons.forward_10),
                          color: colors.textSecondary,
                          onPressed: hasAudio ? () => _seekBy(kJlSeekSeconds) : null,
                          tooltip: 'Maju 10 detik (L)',
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: colors.chipBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: DropdownButton<double>(
                            value: _speed,
                            isDense: true,
                            underline: const SizedBox(),
                            dropdownColor: colors.surface,
                            style: TextStyle(color: colors.text, fontSize: 13),
                            items: kPlaybackSpeeds
                                .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) unawaited(_setSpeed(v));
                            },
                          ),
                        ),
                      ],
                    ),

                    if (_bookmarks.isNotEmpty) ...[
                      Spacing.gapSm,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: BookmarkJumpList(
                          bookmarks: _bookmarks,
                          onJump: (bookmark) =>
                              unawaited(_seekTo(bookmark.timestamp)),
                          onRemove: _removeBookmark,
                          onEditNote: (bookmark) =>
                              unawaited(_editBookmarkNote(bookmark)),
                        ),
                      ),
                    ],

                    // Export button row
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: [
                        if (hasAudio)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.bookmark_add_outlined,
                                size: IconSizes.sm),
                            label: const Text(
                              'Tandai di sini',
                              style: TextStyle(fontSize: FontSizes.body),
                            ),
                            onPressed: _addBookmarkHere,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.textSecondary,
                              side: BorderSide(color: colors.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: Radii.smAll,
                              ),
                            ),
                          ),
                        FilledButton.icon(
                          icon: const Icon(Icons.description_outlined,
                              size: IconSizes.sm),
                          label: const Text(
                            'Notulen Rapat',
                            style: TextStyle(fontSize: FontSizes.body),
                          ),
                          onPressed: () => unawaited(_openNotulen()),
                        ),
                        if (_hasBackup) ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text(
                              'Pulihkan cadangan',
                              style: TextStyle(fontSize: 13),
                            ),
                            onPressed: _restoreBackup,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.textSecondary,
                              side: BorderSide(color: colors.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                        if (hasAudio && _sessionDirPath != null) ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text(
                              'Transkrip Ulang',
                              style: TextStyle(fontSize: 13),
                            ),
                            onPressed: _retranscribe,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.primary,
                              side: BorderSide(
                                color: colors.primary.withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_outlined, size: 16),
                          label: const Text('Ekspor', style: TextStyle(fontSize: 13)),
                          onPressed: () => _exportTranscript(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShortcutHelp(BuildContext context, AppColorSet colors) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Pintasan pemutar'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spasi atau K — putar / jeda'),
            SizedBox(height: 6),
            Text('← / → — mundur / maju 5 detik'),
            SizedBox(height: 6),
            Text('J / L — mundur / maju 10 detik'),
            SizedBox(height: 6),
            Text('Klik baris transkrip — lompat ke waktu itu'),
            SizedBox(height: 6),
            Text('Klik tanda di garis waktu — lompat ke poin yang ditandai'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTranscript(BuildContext context) async {
    final sessionSummary = SessionSummary(
      id: widget.title,
      title: widget.title,
      date: DateTime.now().toIso8601String().substring(0, 10),
      segmentsCount: _segments.length,
      segments: _segments,
      durationSeconds: widget.durationSeconds,
    );
    if (!context.mounted) return;

    // Determine default output dir per platform
    final home = Platform.environment['HOME']
        ?? Platform.environment['USERPROFILE']
        ?? '/tmp';
    final defaultDir = Platform.isWindows
        ? '$home\\Documents\\TrareonTranscribe'
        : '$home/Documents/TrareonTranscribe';

    final bridge = ref.read(rustBridgeProvider);
    final settings = ref.read(settingsProvider);
    await showEksporDialog(
      context,
      sessionSummary,
      bridge: bridge,
      defaultOutputDir: defaultDir,
      defaultFormat: settings.defaultExportFormat,
      summary: _summary,
      bookmarks: _bookmarks,
      incomplete: _sessionDirPath != null &&
          ref.read(enhanceQueueProvider).isCompletingSession(_sessionDirPath!),
      pdp: settings.pdp,
    );
  }
}
