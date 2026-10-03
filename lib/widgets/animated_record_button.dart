import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class AnimatedRecordButton extends StatefulWidget {
  final bool isRecording;
  final bool isPaused;
  final VoidCallback onPressed;
  // True while start()/stop() is in flight — without this the button just
  // sits there with no feedback (still says "Mulai"/"Berhenti", no spinner)
  // for however long that takes: a large pending-transcription backlog on
  // stop, or an unanswered native permission dialog (e.g. first-ever
  // Webinar/system-audio capture) on start, which can hang indefinitely.
  final bool isBusy;
  final String busyLabel;
  const AnimatedRecordButton({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.onPressed,
    this.isBusy = false,
    this.busyLabel = 'Menyimpan...',
  });
  @override
  State<AnimatedRecordButton> createState() => _AnimatedRecordButtonState();
}

class _AnimatedRecordButtonState extends State<AnimatedRecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    if (widget.isRecording && !widget.isPaused) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AnimatedRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldPulse = widget.isRecording && !widget.isPaused;
    if (shouldPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!shouldPulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.animateTo(0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>()!;
    final isActive = widget.isRecording;
    final label = widget.isBusy
        ? widget.busyLabel
        : isActive
        ? (widget.isPaused ? 'Lanjutkan rekaman' : 'Berhenti merekam')
        : 'Mulai merekam';
    return Semantics(
      button: true,
      enabled: !widget.isBusy,
      label: label,
      excludeSemantics: true,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive ? colors.recording : colors.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: colors.recording.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.isBusy ? null : widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isBusy)
                      SizedBox(
                        width: IconSizes.sm,
                        height: IconSizes.sm,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary),
                      )
                    else
                      Icon(
                        isActive ? (widget.isPaused ? Icons.play_arrow : Icons.stop) : Icons.mic,
                        color: colors.onPrimary,
                        size: IconSizes.sm,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isBusy
                          ? widget.busyLabel
                          : (isActive ? (widget.isPaused ? 'Lanjutkan' : 'Berhenti') : 'Mulai'),
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: FontSizes.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
