/// The record button. `docs/DESIGN-SYSTEM.md` §7.1 and §8.3.
///
/// This is the one control the whole product is about, and the one continuous
/// animation in the app lives here: while a session runs the button carries a
/// calm breathing ring. It exists because a capture that has silently stopped
/// recording is the category's biggest complaint (blueprint §2, NEW), and a
/// still button cannot tell the user the difference.
///
/// Under reduce motion the ring holds at its resting radius and the button is
/// otherwise identical.
library;

import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'ui/interactive.dart';

class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.onPressed,
    this.isBusy = false,
    this.busyLabel = 'Menyimpan…',
    this.large = false,
  });

  final bool isRecording;
  final bool isPaused;
  final VoidCallback onPressed;

  /// True while start() or stop() is in flight. Without it the button sits
  /// there with no feedback for however long that takes: a large pending
  /// backlog on stop, or an unanswered native permission dialog on start,
  /// which can hang indefinitely.
  final bool isBusy;

  final String busyLabel;

  /// The hero variant on the idle screen: taller, with more presence.
  final bool large;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Motion.breathe,
  );

  bool get _shouldPulse =>
      widget.isRecording && !widget.isPaused && !widget.isBusy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RecordButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final allowed = _shouldPulse && AppMotion.of(context).allowLoops;
    if (allowed && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!allowed && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final active = widget.isRecording;

    final label = widget.isBusy
        ? widget.busyLabel
        : active
        ? (widget.isPaused ? 'Lanjutkan' : 'Berhenti')
        : 'Mulai Rekam';
    final semantics = widget.isBusy
        ? widget.busyLabel
        : active
        ? (widget.isPaused ? 'Lanjutkan rekaman' : 'Berhenti merekam')
        : 'Mulai merekam';

    final icon = widget.isBusy
        ? null
        : active
        ? (widget.isPaused ? AppIcons.play : AppIcons.stop)
        : AppIcons.record;

    final height = widget.large ? ControlSizes.xl : ControlSizes.lg;
    final fill = active ? colors.recording : colors.primary;
    final ink = active ? colors.onRecording : colors.onPrimary;

    Widget button = Interactive(
      onPressed: widget.isBusy ? null : widget.onPressed,
      enabled: !widget.isBusy,
      borderRadius: Radii.mdAll,
      pressScale: true,
      semanticLabel: semantics,
      builder: (context, state) {
        final bg = state.disabled
            ? colors.surfacePressed
            : state.pressed
            ? (active ? colors.errorPressed : colors.primaryPressed)
            : state.hovered
            ? (active ? colors.errorHover : colors.primaryHover)
            : fill;
        return AnimatedContainer(
          duration: motion.fast,
          curve: AppEasing.standard,
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: widget.large ? Spacing.xl : Spacing.lg,
          ),
          decoration: BoxDecoration(color: bg, borderRadius: Radii.mdAll),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isBusy)
                SizedBox(
                  width: IconSizes.sm,
                  height: IconSizes.sm,
                  child: CircularProgressIndicator(
                    strokeWidth: Strokes.ring,
                    color: state.disabled ? colors.textDisabled : ink,
                  ),
                )
              else
                Icon(
                  icon,
                  size: widget.large ? IconSizes.md : IconSizes.sm,
                  color: state.disabled ? colors.textDisabled : ink,
                ),
              Spacing.hSm,
              Text(
                label,
                style: (widget.large ? AppText.subheading : AppText.label).c(
                  state.disabled ? colors.textDisabled : ink,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!_shouldPulse) return button;

    // A ring that expands and fades, not a blurred glow: the glow is the
    // "AI tell" §9.A bans, and this has to read as instrumentation.
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_pulse.value);
        return CustomPaint(
          painter: _PulseRingPainter(
            progress: _pulse.isAnimating ? t : 0,
            color: colors.recording,
            radius: Radii.md,
          ),
          child: child,
        );
      },
      child: button,
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  const _PulseRingPainter({
    required this.progress,
    required this.color,
    required this.radius,
  });

  final double progress;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final spread = Spacing.sm * progress;
    final rect = Rect.fromLTWH(
      -spread,
      -spread,
      size.width + spread * 2,
      size.height + spread * 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Strokes.hairline
      ..color = color.withValues(alpha: 0.4 * (1 - progress));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius + spread)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.progress != progress || old.color != color;
}
