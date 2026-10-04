/// The app's single notification system. `docs/DESIGN-SYSTEM.md` §6.11.
///
/// `SnackBar` and `ScaffoldMessenger` are banned in `lib/` by
/// `test/design_lint_test.dart`: two notification systems in one app means two
/// visual languages, two dismiss behaviours, and a user who learns neither.
///
/// Toasts stack newest-first up to three, announce themselves as a live
/// region, and never auto-dismiss when they carry an error: a failure the user
/// did not read is a failure they will hit again.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'ui/app_button.dart';
import 'ui/app_surface.dart';

enum ToastType { info, success, error, warning }

/// How many toasts may be on screen at once. A fourth drops the oldest.
const int kMaxToasts = 3;

class AppToast {
  AppToast._();

  static final List<ToastHandle> _live = [];
  static OverlayEntry? _host;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // A failure stays until it is dismissed; everything else goes on a timer,
    // longer when there is an action to reach for.
    final life =
        duration ??
        (type == ToastType.error
            ? Duration.zero
            : actionLabel != null
            ? const Duration(seconds: 6)
            : const Duration(seconds: 3));

    final handle = ToastHandle(
      message: message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    _live.insert(0, handle);
    while (_live.length > kMaxToasts) {
      _live.removeLast().timer?.cancel();
    }
    if (life > Duration.zero) {
      handle.timer = Timer(life, () => dismiss(handle));
    }
    _ensureHost(overlay);
    _host?.markNeedsBuild();
  }

  static void dismiss(ToastHandle handle) {
    handle.timer?.cancel();
    _live.remove(handle);
    if (_live.isEmpty) {
      _host?.remove();
      _host = null;
    } else {
      _host?.markNeedsBuild();
    }
  }

  /// Clears every toast. Used by tests and when the app tears down.
  static void clear() {
    for (final handle in _live) {
      handle.timer?.cancel();
    }
    _live.clear();
    _host?.remove();
    _host = null;
  }

  static void _ensureHost(OverlayState overlay) {
    if (_host != null) return;
    _host = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: Spacing.xxl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final handle in _live.reversed)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: _Toast(
                  key: ValueKey(handle),
                  handle: handle,
                  onDismiss: () => dismiss(handle),
                ),
              ),
          ],
        ),
      ),
    );
    overlay.insert(_host!);
  }
}

/// One live toast.
class ToastHandle {
  ToastHandle({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final ToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  Timer? timer;
}

class _Toast extends StatefulWidget {
  const _Toast({super.key, required this.handle, required this.onDismiss});

  final ToastHandle handle;
  final VoidCallback onDismiss;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final handle = widget.handle;

    final (icon, tint) = switch (handle.type) {
      ToastType.success => (AppIcons.check, colors.success),
      ToastType.error => (AppIcons.error, colors.error),
      ToastType.warning => (AppIcons.warning, colors.warning),
      ToastType.info => (AppIcons.info, colors.info),
    };

    Widget body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Measure.toast),
        child: AppSurface(
          elevation: Elevation.modal,
          radius: Radii.lgAll,
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.md,
            Spacing.sm,
            Spacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: IconSizes.md, color: tint),
              ),
              Spacing.hSm,
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    handle.message,
                    style: AppText.body.c(colors.text),
                  ),
                ),
              ),
              if (handle.actionLabel != null) ...[
                Spacing.hSm,
                AppButton.ghost(
                  label: handle.actionLabel!,
                  size: AppButtonSize.sm,
                  onPressed: () {
                    handle.onAction?.call();
                    widget.onDismiss();
                  },
                ),
              ] else ...[
                Spacing.hXs,
                AppIconButton(
                  icon: AppIcons.close,
                  tooltip: 'Tutup pemberitahuan',
                  size: IconSizes.xs,
                  onPressed: widget.onDismiss,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // A toast appears without the user acting and may disappear on a timer, so
    // a screen reader has to be told about it while it is still on screen.
    body = Semantics(liveRegion: true, container: true, child: body);

    if (motion.reduced) return body;

    final curved = CurvedAnimation(parent: _c, curve: AppEasing.decelerate);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(curved),
        child: body,
      ),
    );
  }
}
