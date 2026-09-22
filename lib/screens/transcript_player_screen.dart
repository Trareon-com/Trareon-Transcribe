import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../widgets/export_dialog.dart';
import '../widgets/transcript_view.dart';

class TranscriptPlayerScreen extends ConsumerStatefulWidget {
  final String title;
  final double durationSeconds;
  final List<TranscriptSegment> segments;
  final String? audioPath;
  final ValueChanged<List<TranscriptSegment>>? onSegmentsChanged;

  const TranscriptPlayerScreen({
    super.key,
    required this.title,
    required this.durationSeconds,
    required this.segments,
    this.audioPath,
    this.onSegmentsChanged,
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

  static const _speedOptions = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _segments = List.of(widget.segments);
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

  Future<void> _persistSegments() async {
    if (widget.audioPath == null) return;
    try {
      final sessionDir = File(widget.audioPath!).parent;
      // Find existing .json file or default to transcript.json
      final existing = sessionDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .firstOrNull;
      final jsonFile = existing ?? File('${sessionDir.path}/transcript.json');
      final json = jsonEncode(_segments.map((s) => {
        'source': s.source,
        'speaker': s.speaker,
        'text': s.text,
        'timestamp': s.timestamp,
        'duration': s.duration,
        'language': s.language,
        'confidence': s.confidence,
        'is_partial': s.isPartial,
      }).toList());
      await jsonFile.writeAsString(json);
    } catch (e) {
      debugPrint('_persistSegments error: $e');
    }
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
                      style: const TextStyle(color: AppColors.warning, fontSize: 12),
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
    final summary = SessionSummary(
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
      summary,
      bridge: bridge,
      defaultOutputDir: defaultDir,
      defaultFormat: settings.defaultExportFormat,
    );
  }
}
