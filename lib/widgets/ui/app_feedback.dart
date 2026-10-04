/// Loading, empty and progress states. `docs/DESIGN-SYSTEM.md` §6.13 to §6.15.
///
/// These are the states LLM-written UI forgets: a pane that shows a bare
/// spinner while it loads, an empty list that renders as nothing at all, a
/// download with no percentage. All three were in this app.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';

/// A shape-matched placeholder block with a shimmer sweep.
///
/// Shape-matched, not a spinner: the point of a skeleton is that the layout
/// does not jump when the content arrives.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = ControlSizes.sm - Spacing.md,
    this.radius = Radii.smAll,
  });

  /// A line of text at [AppText.body].
  const AppSkeleton.line({super.key, this.width})
    : height = FontSizes.body,
      radius = Radii.xsAll;

  /// A circular avatar plate.
  const AppSkeleton.circle({super.key, double size = IconSizes.xl})
    : width = size,
      height = size,
      radius = Radii.pillAll;

  final double? width;
  final double height;
  final BorderRadius radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allowed = AppMotion.of(context).allowLoops;
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
    final base = colors.surfaceSunken;
    final highlight = colors.surfacePressed;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.radius,
              gradient: _c.isAnimating
                  ? LinearGradient(
                      begin: Alignment(-1 - 2 * (1 - t), 0),
                      end: Alignment(1 - 2 * (1 - t), 0),
                      colors: [base, highlight, base],
                      stops: const [0.35, 0.5, 0.65],
                    )
                  : null,
              color: _c.isAnimating ? null : base,
            ),
          );
        },
      ),
    );
  }
}

/// A list of skeleton rows, for a pane that is loading a session list.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.rows = 5, this.showSnippet = true});

  final int rows;
  final bool showSnippet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton.line(width: 180.0 - (i % 3) * 28),
                if (showSnippet) ...[
                  Spacing.gapSm,
                  AppSkeleton.line(width: 120.0 + (i % 2) * 40),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A composed empty state: an icon plate with a badged second glyph, a
/// heading, at most 20 words of explanation, and at most one action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.badgeIcon,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.tone = AppEmptyTone.neutral,
  });

  final IconData icon;
  final String title;
  final String message;

  /// A second, smaller glyph badged on the plate: a search glyph with a slash
  /// for "no results", a plus for "nothing here yet".
  final IconData? badgeIcon;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Drops the plate and tightens the spacing, for a short pane.
  final bool compact;

  final AppEmptyTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = switch (tone) {
      AppEmptyTone.neutral => colors.textTertiary,
      AppEmptyTone.error => colors.error,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Measure.hero),
        child: Padding(
          padding: EdgeInsets.all(compact ? Spacing.lg : Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                _Plate(icon: icon, badgeIcon: badgeIcon, accent: accent),
                Spacing.gapLg,
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.heading.c(colors.text),
              ),
              Spacing.gapSm,
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body.c(colors.textSecondary),
              ),
              if (actionLabel != null && onAction != null) ...[
                Spacing.gapLg,
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: AppButtonVariant.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum AppEmptyTone { neutral, error }

class _Plate extends StatelessWidget {
  const _Plate({required this.icon, required this.badgeIcon, required this.accent});

  final IconData icon;
  final IconData? badgeIcon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: SizedBox(
        width: Spacing.xxxl + Spacing.xl,
        height: Spacing.xxxl + Spacing.xl,
        child: Stack(
          children: [
            Container(
              width: Spacing.xxxl + Spacing.xl,
              height: Spacing.xxxl + Spacing.xl,
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(color: colors.hairline),
              ),
              child: Icon(icon, size: IconSizes.hero, color: accent),
            ),
            if (badgeIcon != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: Spacing.xl,
                  height: Spacing.xl,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.hairline),
                  ),
                  child: Icon(
                    badgeIcon,
                    size: IconSizes.sm,
                    color: colors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A 4 px linear progress bar. Determinate wherever a percentage exists.
class AppLinearProgress extends StatelessWidget {
  const AppLinearProgress({
    super.key,
    this.value,
    this.color,
    this.height = Strokes.progress,
    this.semanticLabel,
  });

  /// Null means indeterminate.
  final double? value;
  final Color? color;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semanticLabel,
      value: value == null ? null : '${(value! * 100).round()} persen',
      child: ClipRRect(
        borderRadius: Radii.pillAll,
        child: LinearProgressIndicator(
          value: value,
          minHeight: height,
          color: color ?? colors.primary,
          backgroundColor: colors.isDark
              ? colors.surfaceModal
              : colors.borderDisabled,
        ),
      ),
    );
  }
}

/// A progress ring. Used inside buttons and beside queue rows.
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    this.value,
    this.size = IconSizes.lg,
    this.color,
    this.semanticLabel,
  });

  final double? value;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semanticLabel,
      value: value == null ? null : '${(value! * 100).round()} persen',
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: Strokes.ring,
          color: color ?? colors.primary,
          backgroundColor: colors.isDark
              ? colors.surfaceModal
              : colors.borderDisabled,
        ),
      ),
    );
  }
}

/// A live audio level meter.
///
/// Not a progress bar: it has no filled background track beyond the hairline,
/// because a big grey track with a partial fill is dashboard clutter and this
/// has to read as instrumentation. The follow is 80 ms so it tracks speech
/// without flickering, and it keeps updating under reduce motion because the
/// level is data, not decoration.
class LevelMeter extends StatelessWidget {
  const LevelMeter({
    super.key,
    required this.level,
    required this.color,
    this.height = Strokes.level,
    this.semanticLabel,
  });

  /// 0 to 1.
  final double level;
  final Color color;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semanticLabel,
      value: '${(level.clamp(0.0, 1.0) * 100).round()} persen',
      child: ClipRRect(
        borderRadius: Radii.pillAll,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: colors.hairlineStrong),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: level.clamp(0.0, 1.0)),
                duration: Motion.instant,
                curve: AppEasing.decelerate,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: math.max(value, 0.0),
                  child: ColoredBox(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stack of vertical level bars: the recording screen's live waveform.
///
/// Fed from the same VU level the meter uses, keeping a short rolling history
/// so the shape reads as audio rather than as a bouncing bar.
class LiveWaveform extends StatefulWidget {
  const LiveWaveform({
    super.key,
    required this.level,
    required this.color,
    this.bars = 32,
    this.height = Spacing.xxl,
    this.live = true,
  });

  final double level;
  final Color color;
  final int bars;
  final double height;
  final bool live;

  @override
  State<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform> {
  late List<double> _history = List.filled(widget.bars, 0);

  @override
  void didUpdateWidget(LiveWaveform old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level || old.live != widget.live) {
      _history = [..._history.skip(1), widget.live ? widget.level : 0.0];
    }
    if (old.bars != widget.bars) {
      _history = List.filled(widget.bars, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < _history.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.75),
                  child: AnimatedContainer(
                    duration: Motion.instant,
                    curve: AppEasing.decelerate,
                    height: math.max(
                      Strokes.level,
                      widget.height * _history[i].clamp(0.0, 1.0),
                    ),
                    decoration: BoxDecoration(
                      color: _history[i] < 0.02
                          ? colors.hairlineStrong
                          : widget.color,
                      borderRadius: Radii.pillAll,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
