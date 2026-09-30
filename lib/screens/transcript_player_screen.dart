import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/session_store.dart';
import '../utils/model_labels.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../widgets/export_dialog.dart';
import '../widgets/retranscribe_dialog.dart';
import '../widgets/summary_panel.dart';
import '../widgets/transcript_view.dart';

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

  const TranscriptPlayerScreen({
    super.key,
    required this.title,
    required this.durationSeconds,
    required this.segments,
    this.audioPath,
    this.onSegmentsChanged,
    this.sessionDirPath,
    this.meta = SessionMeta.empty,
  });

  @override
  ConsumerState<TranscriptPlayerScreen> createState() => _TranscriptPlayerScreenState();
}

class _TranscriptPlayerScreenState extends ConsumerState<TranscriptPlayerScreen> {
  double _positionSeconds = 0;
  double _speed = 1.0;
  bool _playing = false;
  late List<TranscriptSegment> _segments;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  Duration? _duration;
  String? _error;
  Timer? _persistDebounce;

  /// Latest saved summary, kept here so "Ekspor" can lead the Markdown/DOCX
  /// with it without re-reading the sidecar.
  late String _summary;

  static const _speedOptions = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _segments = List.of(widget.segments);
    _summary = widget.meta.summary;
    _initPlayer();
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
      if (mounted) setState(() { _duration = duration; });
      _positionSub = _player.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() {
          _positionSeconds = position.inMilliseconds / 1000.0;
        });
      });
      _playerStateSub = _player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() {
          _playing = state == PlayerState.playing;
        });
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
    widget.onSegmentsChanged?.call(List.unmodifiable(_segments));
    _schedulePersist();
  }

  void _renameSpeaker(String oldLabel, String newLabel) {
    setState(() {
      _segments = _segments
          .map((s) =>
              s.speaker == oldLabel ? s.copyWith(speaker: newLabel) : s)
          .toList();
    });
    widget.onSegmentsChanged?.call(List.unmodifiable(_segments));
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

  Future<void> _persistSegments() async {
    final dirPath = _sessionDirPath;
    if (dirPath == null) return;
    try {
      final sessionDir = Directory(dirPath);
      // transcriptFileIn() skips the metadata sidecar — it is also JSON, and
      // overwriting it with a segment array would drop the saved summary.
      final jsonFile =
          transcriptFileIn(sessionDir) ??
          File('${sessionDir.path}${Platform.pathSeparator}transcript.json');
      await jsonFile.writeAsString(encodeTranscriptJson(_segments));
    } catch (e) {
      debugPrint('_persistSegments error: $e');
    }
  }

  /// Replaces the transcript with a re-run over the same audio, then persists
  /// it. The summary is deliberately left alone: it may have been edited by
  /// hand, and silently discarding it would be worse than letting the user
  /// press "Buat Ulang" themselves.
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

    setState(() => _segments = result.segments);
    widget.onSegmentsChanged?.call(List.unmodifiable(_segments));
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
          '(${modelDisplayLabel(result.modelId)}).',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(double secs) {
    final m = (secs / 60).floor();
    final s = (secs % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlayback() async {
    if (widget.audioPath == null) return;
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.setPlaybackRate(_speed);
        if (_positionSeconds > 0) {
          await _player.seek(Duration(milliseconds: (_positionSeconds * 1000).round()));
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
    try {
      await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
      if (!mounted) return;
      setState(() => _positionSeconds = seconds);
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
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final maxSeconds = (widget.durationSeconds > 0
            ? widget.durationSeconds
            : (_duration?.inMilliseconds ?? 0) / 1000.0)
        .toDouble()
        .clamp(1.0, double.infinity);

    // Find the active segment index based on current playback position
    final activeIndex = _positionSeconds > 0
        ? _segments.lastIndexWhere(
            (s) => s.timestamp <= _positionSeconds && (s.timestamp + s.duration) > _positionSeconds)
        : -1;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        foregroundColor: colors.text,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          if (_sessionDirPath != null)
            SummaryPanel(
              sessionDirPath: _sessionDirPath!,
              segments: () => _segments,
              initialMeta: widget.meta,
              onSummaryChanged: (text) => setState(() => _summary = text),
            ),

          // Transcript
          Expanded(
            child: TranscriptView(
              segments: _segments,
              onEdit: _editSegment,
              onRenameSpeaker: _renameSpeaker,
              activeSegmentIndex: activeIndex >= 0 ? activeIndex : null,
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
                // Seek slider
                Row(
                  children: [
                    Text(_formatTime(_positionSeconds),
                      style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _positionSeconds.clamp(0.0, maxSeconds).toDouble(),
                        max: maxSeconds,
                        activeColor: colors.primary,
                        onChanged: widget.audioPath == null ? null : (v) => setState(() => _positionSeconds = v),
                        onChangeEnd: widget.audioPath == null ? null : _seekTo,
                      ),
                    ),
                    Text(_formatTime(maxSeconds),
                      style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  ],
                ),

                // Play controls + speed
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Skip back 10s
                    IconButton(
                      iconSize: 24,
                      icon: const Icon(Icons.replay_10),
                      color: colors.textSecondary,
                      onPressed: widget.audioPath == null
                          ? null
                          : () => _seekTo((_positionSeconds - 10).clamp(0, maxSeconds)),
                      tooltip: 'Mundur 10 detik',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      iconSize: 40,
                      icon: Icon(
                        _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: colors.primary,
                      ),
                      onPressed: widget.audioPath == null ? null : _togglePlayback,
                    ),
                    const SizedBox(width: 8),
                    // Skip forward 10s
                    IconButton(
                      iconSize: 24,
                      icon: const Icon(Icons.forward_10),
                      color: colors.textSecondary,
                      onPressed: widget.audioPath == null
                          ? null
                          : () => _seekTo((_positionSeconds + 10).clamp(0, maxSeconds)),
                      tooltip: 'Maju 10 detik',
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
                        items: _speedOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _speed = v);
                            unawaited(_player.setPlaybackRate(v));
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // Export button row
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.audioPath != null && _sessionDirPath != null) ...[
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
                      const SizedBox(width: 8),
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
    final defaultDir = Platform.isMacOS
        ? '$home/Documents/TrareonTranscribe'
        : Platform.isWindows
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
    );
  }
}
