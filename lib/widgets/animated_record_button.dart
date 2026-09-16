import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedRecordButton extends StatefulWidget {
  final bool isRecording;
  final bool isPaused;
  final VoidCallback onPressed;
  // True while stop() is awaiting the save — without this the button just
  // sits there with no feedback (still says "Berhenti", no spinner) for
  // however long the export takes, which reads as a frozen app on a
  // session with a large pending-transcription backlog.
  final bool isBusy;
  const AnimatedRecordButton({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.onPressed,
    this.isBusy = false,
  });
  @override State<AnimatedRecordButton> createState() => _AnimatedRecordButtonState();
}

class _AnimatedRecordButtonState extends State<AnimatedRecordButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    if (widget.isRecording && !widget.isPaused) _pulse.repeat(reverse: true);
  }
  @override void didUpdateWidget(AnimatedRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldPulse = widget.isRecording && !widget.isPaused;
    if (shouldPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!shouldPulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.animateTo(0);
    }
  }
  @override void dispose() { _pulse.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>()!;
    final isActive = widget.isRecording;
    return ScaleTransition(scale: _scale, child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive ? AppColors.recordingDot : colors.primary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isActive ? [BoxShadow(color: AppColors.recordingDot.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 2)] : null,
      ),
      child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(10),
        child: InkWell(borderRadius: BorderRadius.circular(10), onTap: widget.isBusy ? null : widget.onPressed,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.isBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                Icon(isActive ? (widget.isPaused ? Icons.play_arrow : Icons.stop) : Icons.mic, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(widget.isBusy ? 'Menyimpan...' : (isActive ? (widget.isPaused ? 'Lanjutkan' : 'Berhenti') : 'Mulai'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ])))),
    ));
  }
}
