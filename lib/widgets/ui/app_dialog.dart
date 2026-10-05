/// Dialogs, sheets and tabs. `docs/DESIGN-SYSTEM.md` §6.10 and §6.12.
library;

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';
import 'app_surface.dart';
import 'interactive.dart';

/// A dialog with the app's chrome: `xl` radius, hairline, title, scrollable
/// body, right-aligned actions with the primary last.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.actions = const [],
    this.icon,
    this.tone = AppDialogTone.neutral,
    this.width = Measure.dialog,
    this.showClose = true,
  });

  final String title;
  final String? description;
  final Widget child;

  /// Right-aligned, primary last. A destructive dialog never autofocuses the
  /// destructive action.
  final List<Widget> actions;

  final IconData? icon;
  final AppDialogTone tone;
  final double width;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = switch (tone) {
      AppDialogTone.neutral => colors.primaryText,
      AppDialogTone.danger => colors.error,
      AppDialogTone.warning => colors.warning,
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(Spacing.xl),
      child: AppSurface(
        elevation: Elevation.modal,
        radius: Radii.xlAll,
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.xl,
                Spacing.xl,
                Spacing.md,
                Spacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: IconSizes.lg, color: accent),
                    Spacing.hMd,
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: AppText.heading.c(colors.text)),
                        if (description != null) ...[
                          Spacing.gapXs,
                          Text(
                            description!,
                            style: AppText.body.c(colors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showClose)
                    AppIconButton(
                      icon: AppIcons.close,
                      tooltip: 'Tutup',
                      size: IconSizes.md,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                child: child,
              ),
            ),
            if (actions.isNotEmpty) ...[
              // A long form scrolls under this bar, and content sliced by an
              // invisible edge reads as a rendering bug. The hairline makes
              // the action bar a surface of its own, so the cut is deliberate.
              AppHairline(color: colors.hairline),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.xl,
                  Spacing.lg,
                  Spacing.xl,
                  Spacing.lg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) Spacing.hSm,
                      actions[i],
                    ],
                  ],
                ),
              ),
            ] else
              Spacing.gapXl,
          ],
        ),
      ),
    );
  }
}

enum AppDialogTone { neutral, danger, warning }

/// Shows an [AppDialog] with the system's enter transition.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final motion = AppMotion.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Tutup dialog',
    barrierColor: context.colors.scrim,
    transitionDuration: motion.slowest,
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppEasing.decelerate,
        reverseCurve: AppEasing.accelerate,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A confirmation dialog. The destructive action is never the autofocused one.
Future<bool> showAppConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Lanjutkan',
  String cancelLabel = 'Batal',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: title,
      icon: icon,
      tone: destructive ? AppDialogTone.danger : AppDialogTone.neutral,
      width: Measure.dialog,
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.secondary,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        destructive
            ? AppButton.danger(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
              )
            : AppButton.primary(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
              ),
      ],
      child: Text(message, style: AppText.body.c(context.colors.textSecondary)),
    ),
  );
  return result ?? false;
}

/// A bottom sheet: the post-stop integrity summary and the notulen preview.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.actions = const [],
    this.icon,
    this.maxHeightFactor = 0.8,
  });

  final String title;
  final String? description;
  final Widget child;
  final List<Widget> actions;
  final IconData? icon;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle, so the sheet says it can be dismissed by dragging as
          // well as by the close button.
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: Spacing.md),
              width: Spacing.xxxl,
              height: Spacing.xs,
              decoration: BoxDecoration(
                color: colors.hairlineStrong,
                borderRadius: Radii.pillAll,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl,
              Spacing.lg,
              Spacing.md,
              Spacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: IconSizes.lg, color: colors.primaryText),
                  Spacing.hMd,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppText.title.c(colors.text)),
                      if (description != null) ...[
                        Spacing.gapXs,
                        Text(
                          description!,
                          style: AppText.body.c(colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                AppIconButton(
                  icon: AppIcons.close,
                  tooltip: 'Tutup',
                  size: IconSizes.md,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const AppHairline(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.xl),
              child: child,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const AppHairline(),
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) Spacing.hSm,
                    actions[i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows an [AppSheet].
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: context.colors.surfaceModal,
    barrierColor: context.colors.scrim,
    shape: const RoundedRectangleBorder(borderRadius: Radii.xlTop),
    builder: builder,
  );
}

/// Underline tabs.
class AppTabs extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.icons = const [],
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Interactive(
              onPressed: () => onChanged(i),
              borderRadius: Radii.smAll,
              selected: i == selected,
              semanticLabel: labels[i],
              builder: (context, state) {
                final active = i == selected;
                final fg = active
                    ? colors.text
                    : state.hovered
                    ? colors.text
                    : colors.textSecondary;
                return AnimatedContainer(
                  duration: motion.slow,
                  curve: AppEasing.standard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: active ? colors.primary : Colors.transparent,
                        width: Strokes.focusRing,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i < icons.length) ...[
                        Icon(icons[i], size: IconSizes.sm, color: fg),
                        Spacing.hXs,
                      ],
                      Text(
                        labels[i],
                        style: AppText.label.cw(
                          fg,
                          active ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
