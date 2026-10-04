/// The scrubber in the transcript player. `docs/DESIGN-SYSTEM.md` §7.3.
///
/// It looks like an audio waveform and it behaves like one, but it is not
/// drawn from audio samples: decoding a three-hour WAV to get peaks would cost
/// more than the whole screen, and inventing peaks would be fabricated data in
/// a production UI. Each bar is instead the fraction of its time slice that
/// the transcript actually covers with speech, which is real information the
/// app already has and is arguably more useful: the gaps are where nobody was
/// talking, and that is what somebody scrubbing a meeting is looking for.
///
/// Named for what it is, so nobody later "improves" it into a fake waveform.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

/// One span of speech on the timeline.
@immutable
class SpeechSpan {
  const SpeechSpan({required this.start, required this.end});

  final double start;
  final double end;

  double get duration => math.max(0, end - start);
}

class SpeechTimeline extends StatefulWidget {
  const SpeechTimeline({
    super.key,
    required this.spans,
    required this.totalSeconds,
    required this.positionSeconds,
    this.onSeek,
    this.height = Spacing.xxl,
    this.bars = 120,
    this.semanticLabel,
  });

  final List<SpeechSpan> spans;
  final double totalSeconds;
  final double positionSeconds;

  /// Null disables scrubbing, which is what a session with no audio on disk
  /// gets. The bars still render: where people spoke is worth seeing even
  /// when the recording cannot be played.
  final ValueChanged<double>? onSeek;

  final double height;
  final int bars;
  final String? semanticLabel;

  @override
  State<SpeechTimeline> createState() => _SpeechTimelineState();
}

class _SpeechTimelineState extends State<SpeechTimeline> {
  double? _dragSeconds;

  /// Per-bar coverage, 0 to 1. Recomputed only when the inputs change, not on
  /// every position tick: the position stream runs at 5-10 Hz and this is the
  /// only expensive part of the widget.
  late List<double> _coverage = _computeCoverage();

  @override
  void didUpdateWidget(SpeechTimeline old) {
    super.didUpdateWidget(old);
    if (old.spans != widget.spans ||
        old.totalSeconds != widget.totalSeconds ||
        old.bars != widget.bars) {
      _coverage = _computeCoverage();
    }
  }

  List<double> _computeCoverage() {
    final total = widget.totalSeconds;
    final count = widget.bars;
    if (total <= 0 || count <= 0) return List.filled(math.max(count, 0), 0);
    final slice = total / count;
    final covered = List<double>.filled(count, 0);
    for (final span in widget.spans) {
      if (span.duration <= 0) continue;
      final first = (span.start / slice).floor().clamp(0, count - 1);
      final last = (span.end / slice).ceil().clamp(0, count);
      for (var i = first; i < last; i++) {
        final sliceStart = i * slice;
        final sliceEnd = sliceStart + slice;
        final overlap =
            math.min(span.end, sliceEnd) - math.max(span.start, sliceStart);
        if (overlap > 0) covered[i] += overlap;
      }
    }
    return [for (final value in covered) (value / slice).clamp(0.0, 1.0)];
  }

  void _seekFromLocal(double dx, double width) {
    if (widget.onSeek == null || width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragSeconds = fraction * widget.totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shown = _dragSeconds ?? widget.positionSeconds;
    final progress = widget.totalSeconds <= 0
        ? 0.0
        : (shown / widget.totalSeconds).clamp(0.0, 1.0);

    return Semantics(
      label: widget.semanticLabel ?? 'Garis waktu rekaman',
      value: '${(progress * 100).round()} persen',
      slider: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return MouseRegion(
            cursor: widget.onSeek == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _seekFromLocal(d.localPosition.dx, width),
              onTapUp: (_) => _commit(),
              onHorizontalDragUpdate: (d) =>
                  _seekFromLocal(d.localPosition.dx, width),
              onHorizontalDragEnd: (_) => _commit(),
              child: SizedBox(
                height: widget.height,
                child: CustomPaint(
                  painter: _TimelinePainter(
                    coverage: _coverage,
                    progress: progress,
                    played: colors.primary,
                    unplayed: colors.hairlineStrong,
                    playhead: colors.primary,
                    enabled: widget.onSeek != null,
                    disabled: colors.textDisabled,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _commit() {
    final seconds = _dragSeconds;
    if (seconds == null) return;
    setState(() => _dragSeconds = null);
    widget.onSeek?.call(seconds);
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.coverage,
    required this.progress,
    required this.played,
    required this.unplayed,
    required this.playhead,
    required this.enabled,
    required this.disabled,
  });

  final List<double> coverage;
  final double progress;
  final Color played;
  final Color unplayed;
  final Color playhead;
  final bool enabled;
  final Color disabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (coverage.isEmpty || size.width <= 0) return;
    final slot = size.width / coverage.length;
    final barWidth = math.max(1.0, slot - 1);
    final playedUntil = size.width * progress;
    final mid = size.height / 2;

    for (var i = 0; i < coverage.length; i++) {
      final x = i * slot;
      // A floor, so a silent stretch still reads as a timeline rather than as
      // a gap in the control.
      final amplitude = math.max(
        Strokes.level,
        size.height * (0.18 + 0.82 * coverage[i]),
      );
      final isPlayed = x + barWidth / 2 <= playedUntil;
      final paint = Paint()
        ..color = !enabled
            ? disabled
            : isPlayed
            ? played
            : unplayed;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, mid - amplitude / 2, barWidth, amplitude),
          const Radius.circular(Radii.pill),
        ),
        paint,
      );
    }

    if (!enabled) return;
    final head = Paint()..color = playhead;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (playedUntil - Strokes.focusRing / 2).clamp(
            0.0,
            size.width - Strokes.focusRing,
          ),
          0,
          Strokes.focusRing,
          size.height,
        ),
        const Radius.circular(Radii.pill),
      ),
      head,
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.progress != progress ||
      old.coverage != coverage ||
      old.enabled != enabled ||
      old.played != played;
}

/// Convenience: the spans a transcript implies.
List<SpeechSpan> speechSpansOf(
  Iterable<({double timestamp, double duration})> segments,
) => [
  for (final segment in segments)
    SpeechSpan(
      start: segment.timestamp,
      // A segment with no recorded duration still happened; give it a
      // minimum so it is visible on the timeline.
      end: segment.timestamp + math.max(segment.duration, 0.5),
    ),
];
