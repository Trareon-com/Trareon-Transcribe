/// Chips, badges and status pills. `docs/DESIGN-SYSTEM.md` §6.7 and §6.16.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import 'interactive.dart';

/// Static metadata. Not interactive, not a filter.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.icon, this.mono = false});

  final String label;
  final IconData? icon;

  /// For a timestamp or an ID.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: ControlSizes.sm - Spacing.xs,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: Radii.smAll,
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: IconSizes.xs, color: colors.textTertiary),
            const SizedBox(width: Spacing.xs + 2),
          ],
          Text(
            label,
            style: (mono ? AppText.monoMicro : AppText.micro).c(
              colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A selectable tag.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    return Interactive(
      onPressed: () => onSelected(!selected),
      borderRadius: Radii.smAll,
      selected: selected,
      semanticLabel: label,
      builder: (context, state) => AnimatedContainer(
        duration: motion.fast,
        curve: AppEasing.standard,
        height: ControlSizes.sm - Spacing.xs,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? colors.primarySubtle
              : state.active
              ? colors.surfacePressed
              : colors.surfaceSunken,
          borderRadius: Radii.smAll,
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.35)
                : colors.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: IconSizes.xs,
                color: selected ? colors.primaryText : colors.textTertiary,
              ),
              const SizedBox(width: Spacing.xs + 2),
            ],
            Text(
              label,
              style: AppText.micro.c(
                selected ? colors.primaryText : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a status badge means.
enum AppStatus { neutral, success, warning, danger, info, recording, accent }

extension on AppStatus {
  (Color fill, Color ink) resolve(AppColorSet c) => switch (this) {
    AppStatus.neutral => (c.surfaceSunken, c.textSecondary),
    AppStatus.success => (c.successSubtle, c.success),
    AppStatus.warning => (c.warningSubtle, c.warning),
    AppStatus.danger => (c.errorSubtle, c.error),
    AppStatus.info => (c.infoSubtle, c.info),
    AppStatus.recording => (c.recordingSubtle, c.recording),
    AppStatus.accent => (c.primarySubtle, c.primaryText),
  };
}

/// A semantic status pill: a wash, a glyph or dot, and a word.
///
/// Colour is never the only carrier: every badge has text, and the recording
/// badge also has a different shape (a filled dot) from the danger badge
/// (a triangle glyph).
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.status = AppStatus.neutral,
    this.icon,
    this.dot = false,
  });

  final String label;
  final AppStatus status;
  final IconData? icon;

  /// Renders a 6 px filled dot instead of a glyph. Only for live state.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (fill, ink) = status.resolve(colors);
    return Container(
      height: ControlSizes.sm - Spacing.xs,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      decoration: BoxDecoration(color: fill, borderRadius: Radii.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: Spacing.sm - 2,
              height: Spacing.sm - 2,
              decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
            ),
            const SizedBox(width: Spacing.xs + 2),
          ] else if (icon != null) ...[
            Icon(icon, size: IconSizes.xs, color: ink),
            const SizedBox(width: Spacing.xs + 2),
          ],
          Text(label, style: AppText.micro.c(ink)),
        ],
      ),
    );
  }
}

/// A live recording dot with a calm breathing ring.
///
/// The one continuous animation in the app, and the reason it exists is the
/// category's biggest complaint: a capture that silently is not recording.
/// Under reduce motion the ring holds at its resting radius.
class RecordingDot extends StatefulWidget {
  const RecordingDot({super.key, this.size = Spacing.sm, this.live = true});

  final double size;
  final bool live;

  @override
  State<RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.breathe,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RecordingDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final allowed = widget.live && AppMotion.of(context).allowLoops;
    if (allowed && !_c.isAnimating) {
      _c.repeat();
    } else if (!allowed && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final core = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.live ? colors.recording : colors.textTertiary,
        shape: BoxShape.circle,
      ),
    );
    if (!widget.live) return core;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_c.value);
        return SizedBox(
          width: widget.size * 2.4,
          height: widget.size * 2.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A ring, not a glow: a blurred halo on a dark surface is the
              // "AI tell" §9.A bans, and this has to look like instrumentation.
              Container(
                width: widget.size * (1 + 1.4 * t),
                height: widget.size * (1 + 1.4 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.recording.withValues(alpha: 0.35 * (1 - t)),
                    width: Strokes.hairline,
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: core,
    );
  }
}
