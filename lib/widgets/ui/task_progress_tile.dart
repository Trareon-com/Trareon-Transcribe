/// Shared progress UI for any operation that can run longer than a few
/// seconds (Sprint 14b, item 10). One component, two things it has to
/// handle:
///
/// * [ProgressGate] hides the indicator until it has been needed
///   continuously for a few seconds, so a fast operation never flickers one
///   on screen only to remove it a frame later.
/// * [TaskProgressTile] is the indicator itself: determinate (a percentage
///   and, once known, a time remaining) when the underlying operation can
///   report a fraction, indeterminate (a spinner and a stage name, e.g.
///   "Memuat model…") when it cannot.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_tokens.dart';

/// How a tracked task is currently doing.
enum TaskRunState { queued, running, done, failed, cancelled }

/// Shows [builder]'s output only once [active] has been continuously true
/// for [threshold] (default 3 s — the product rule this sprint sets for
/// "long enough to need an indicator"). Going inactive hides it immediately;
/// a brief glimpse of "it finished" is fine, a brief glimpse of "it started"
/// before snapping away reads as a glitch.
class ProgressGate extends StatefulWidget {
  const ProgressGate({
    super.key,
    required this.active,
    required this.builder,
    this.threshold = const Duration(seconds: 3),
  });

  final bool active;
  final Duration threshold;
  final WidgetBuilder builder;

  @override
  State<ProgressGate> createState() => _ProgressGateState();
}

class _ProgressGateState extends State<ProgressGate> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _arm();
  }

  @override
  void didUpdateWidget(covariant ProgressGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _arm();
    } else if (!widget.active && oldWidget.active) {
      _timer?.cancel();
      _timer = null;
      if (_visible) setState(() => _visible = false);
    }
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(widget.threshold, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return widget.builder(context);
  }
}

/// One row: what is running, how far along it is, and — while it is still
/// running — a way to cancel it. Indonesian text throughout, per the product
/// rule this sprint sets for every progress surface.
class TaskProgressTile extends StatelessWidget {
  const TaskProgressTile({
    super.key,
    required this.title,
    this.stage,
    this.progress,
    this.etaLabel,
    this.state = TaskRunState.running,
    this.statusOverride,
    this.onCancel,
    this.onDismiss,
  });

  /// What is being worked on, e.g. a session title or a filename.
  final String title;

  /// Human stage name for the running state, e.g. "Memuat model",
  /// "Mentranskripsi". `null` falls back to a generic "Memproses".
  final String? stage;

  /// `0.0..=1.0`, or `null` for an indeterminate (spinner-only) task.
  final double? progress;

  /// Pre-formatted remaining-time label, e.g. "sisa 2 menit" — formatting
  /// (and the "not worth showing yet" threshold) is the caller's call, since
  /// it already has one for its own domain (completion/enhance progress,
  /// batch file import, …).
  final String? etaLabel;

  final TaskRunState state;

  /// Overrides the generated status line — for a specific failure reason or
  /// a custom "done" message. `null` uses a generic one per [state].
  final String? statusOverride;

  /// `null` hides the cancel button — not every task can be interrupted
  /// mid-flight. Shown only while [state] is [TaskRunState.running].
  final VoidCallback? onCancel;

  /// Clears a finished (usually failed) task from view. Shown instead of
  /// [onCancel] once [state] is no longer running.
  final VoidCallback? onDismiss;

  String get _statusLine {
    if (statusOverride != null) return statusOverride!;
    return switch (state) {
      TaskRunState.failed => 'Gagal.',
      TaskRunState.cancelled => 'Dibatalkan.',
      TaskRunState.done => 'Selesai.',
      TaskRunState.queued => 'Menunggu antrean.',
      TaskRunState.running => _runningLine,
    };
  }

  String get _runningLine {
    final stage = this.stage ?? 'Memproses';
    final progress = this.progress;
    if (progress == null) return '$stage…';
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    final eta = etaLabel;
    return '$stage… $percent%${eta == null ? '' : ' — $eta'}';
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final statusLine = _statusLine;
    return Semantics(
      label: '$title: $statusLine',
      liveRegion: state == TaskRunState.running || state == TaskRunState.queued,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: IconSizes.sm,
            height: IconSizes.sm,
            child: switch (state) {
              TaskRunState.running => CircularProgressIndicator(
                strokeWidth: 2,
                // Determinate the moment a fraction is known: a task that
                // can run for an hour must never look stuck behind a
                // spinner that never moves.
                value: progress?.clamp(0.0, 1.0),
              ),
              TaskRunState.failed => Icon(
                AppIcons.error,
                size: IconSizes.sm,
                color: colors.error,
              ),
              TaskRunState.done => Icon(
                AppIcons.check,
                size: IconSizes.sm,
                color: colors.success,
              ),
              TaskRunState.cancelled => Icon(
                AppIcons.block,
                size: IconSizes.sm,
                color: colors.textTertiary,
              ),
              TaskRunState.queued => Icon(
                AppIcons.clock,
                size: IconSizes.sm,
                color: colors.textTertiary,
              ),
            },
          ),
          Spacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: FontSizes.caption,
                    color: colors.text,
                  ),
                ),
                Text(
                  statusLine,
                  style: TextStyle(
                    fontSize: FontSizes.micro,
                    color: state == TaskRunState.failed
                        ? colors.error
                        : colors.textTertiary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (onCancel != null &&
              (state == TaskRunState.running || state == TaskRunState.queued))
            Tooltip(
              message: 'Batalkan',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                constraints: TouchTarget.constraints,
                icon: Icon(
                  AppIcons.stopCircle,
                  size: IconSizes.md,
                  color: colors.textSecondary,
                ),
                onPressed: onCancel,
              ),
            )
          else if (onDismiss != null &&
              state != TaskRunState.running &&
              state != TaskRunState.queued)
            Tooltip(
              message: 'Sembunyikan',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                constraints: TouchTarget.constraints,
                icon: Icon(
                  AppIcons.close,
                  size: IconSizes.md,
                  color: colors.textSecondary,
                ),
                onPressed: onDismiss,
              ),
            ),
        ],
      ),
    );
  }
}
