import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ToastType { info, success, error }

class AppToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _current?.remove();
    final overlay = Overlay.of(context);
    final colors = Theme.of(context).extension<AppColorSet>()!;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        colors: colors,
        onDismiss: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
        duration: duration,
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final AppColorSet colors;
  final VoidCallback onDismiss;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.colors,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconData = switch (widget.type) {
      ToastType.success => Icons.check_circle_outline,
      ToastType.error => Icons.error_outline,
      ToastType.info => Icons.info_outline,
    };
    final iconColor = switch (widget.type) {
      ToastType.success => const Color(0xFF2E7D32),
      ToastType.error => const Color(0xFFD32F2F),
      ToastType.info => widget.colors.primary,
    };

    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              color: widget.colors.surfaceElevated,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.of(context).size.width - 64).clamp(200, 480),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iconData, size: 16, color: iconColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.colors.text,
                        ),
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
