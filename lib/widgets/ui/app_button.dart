/// Buttons. `docs/DESIGN-SYSTEM.md` §6.1 and §6.2.
///
/// Four variants, three sizes, and all six states (default, hover, pressed,
/// focus, disabled, loading) on every one of them. Material's own buttons are
/// themed in `app_theme.dart` so a framework dialog still looks right, but
/// everything the app draws itself comes through here.
library;

import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import 'interactive.dart';

enum AppButtonVariant {
  /// The one action a surface exists for. At most one per surface.
  primary,

  /// Everything else that needs a box: a bordered, neutral button.
  secondary,

  /// Tertiary actions in a crowded row. No border until hovered.
  ghost,

  /// Destructive. Never the default focus of a dialog.
  danger,
}

enum AppButtonSize { sm, md, lg }

extension on AppButtonSize {
  double get height => switch (this) {
    AppButtonSize.sm => ControlSizes.sm,
    AppButtonSize.md => ControlSizes.lg,
    AppButtonSize.lg => ControlSizes.xl,
  };

  double get padding => switch (this) {
    AppButtonSize.sm => Spacing.md,
    AppButtonSize.md => Spacing.lg,
    AppButtonSize.lg => Spacing.xl,
  };

  double get iconSize => switch (this) {
    AppButtonSize.sm => IconSizes.sm,
    AppButtonSize.md => IconSizes.sm,
    AppButtonSize.lg => IconSizes.md,
  };

  TextStyle get textStyle => switch (this) {
    AppButtonSize.sm => AppText.caption.copyWith(fontWeight: FontWeight.w500),
    AppButtonSize.md => AppText.label,
    AppButtonSize.lg => AppText.subheading,
  };
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  });

  /// Shorthand for the one primary action on a surface.
  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AppButtonVariant.danger;

  /// Two words at most. A label that wraps is a broken button.
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Replaces [icon] with a ring and ignores pointers. The label stays, so the
  /// button does not change width mid-request.
  final bool loading;

  final bool expand;
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final enabled = onPressed != null && !loading;

    return Interactive(
      onPressed: enabled ? onPressed : null,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      tooltip: tooltip,
      pressScale: true,
      borderRadius: Radii.mdAll,
      builder: (context, state) {
        final (background, foreground, border) = _palette(context, state);
        return AnimatedContainer(
          duration: motion.fast,
          curve: AppEasing.standard,
          height: size.height,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: size.padding),
          decoration: BoxDecoration(
            color: background,
            borderRadius: Radii.mdAll,
            border: border == null
                ? null
                : Border.all(color: border, width: Strokes.hairline),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                SizedBox(
                  width: size.iconSize,
                  height: size.iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: Strokes.ring,
                    color: foreground,
                  ),
                ),
                Spacing.hSm,
              ] else if (icon != null) ...[
                Icon(icon, size: size.iconSize, color: foreground),
                Spacing.hSm,
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: size.textStyle.c(foreground),
                ),
              ),
              if (trailingIcon != null && !loading) ...[
                Spacing.hXs,
                Icon(trailingIcon, size: size.iconSize, color: foreground),
              ],
            ],
          ),
        );
      },
    );
  }

  /// (background, foreground, border) for the current state.
  (Color, Color, Color?) _palette(BuildContext context, InteractionState s) {
    final colors = context.colors;
    if (s.disabled) {
      return switch (variant) {
        AppButtonVariant.primary || AppButtonVariant.danger => (
          colors.surfacePressed,
          colors.textDisabled,
          null,
        ),
        AppButtonVariant.secondary => (
          Colors.transparent,
          colors.textDisabled,
          colors.borderDisabled,
        ),
        AppButtonVariant.ghost => (
          Colors.transparent,
          colors.textDisabled,
          null,
        ),
      };
    }
    switch (variant) {
      case AppButtonVariant.primary:
        final bg = s.pressed
            ? colors.primaryPressed
            : s.hovered
            ? colors.primaryHover
            : colors.primary;
        return (bg, colors.onPrimary, null);
      case AppButtonVariant.danger:
        final bg = s.pressed
            ? colors.errorPressed
            : s.hovered
            ? colors.errorHover
            : colors.error;
        return (bg, colors.onError, null);
      case AppButtonVariant.secondary:
        final bg = s.pressed
            ? colors.surfacePressed
            : s.hovered
            ? colors.surfaceSunken
            : Colors.transparent;
        return (bg, colors.text, colors.borderInteractive);
      case AppButtonVariant.ghost:
        final bg = s.pressed
            ? colors.surfacePressed
            : s.hovered
            ? colors.surfaceSunken
            : Colors.transparent;
        return (bg, colors.textSecondary, null);
    }
  }
}

/// An icon-only button: a 20 px glyph in a 48x48 hit box.
///
/// [tooltip] is required, not optional. Four unlabelled icons in the header
/// was the audit's first finding about the main screen, and an icon button
/// with no accessible name is the single most common a11y defect there is.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = IconSizes.lg,
    this.color,
    this.danger = false,
    this.selected = false,
    this.loading = false,
    this.focusNode,
    this.badge,
  });

  final IconData icon;

  /// Also used as the semantics label, so the control is never nameless.
  final String tooltip;

  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final bool danger;
  final bool selected;
  final bool loading;
  final FocusNode? focusNode;

  /// A count rendered as a small pill at the top-right. Used by the collapsed
  /// sidebar rail.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final enabled = onPressed != null && !loading;

    return Interactive(
      onPressed: enabled ? onPressed : null,
      enabled: enabled,
      focusNode: focusNode,
      tooltip: tooltip,
      semanticLabel: tooltip,
      selected: selected ? true : null,
      pressScale: true,
      borderRadius: Radii.mdAll,
      builder: (context, state) {
        final Color fg = state.disabled
            ? colors.textDisabled
            : danger
            ? colors.error
            : selected
            ? colors.primaryText
            : (color ?? colors.icon);
        final Color bg = state.pressed
            ? colors.pressedOverlay
            : state.hovered
            ? colors.hoverOverlay
            : selected
            ? colors.primarySubtle
            : Colors.transparent;
        return AnimatedContainer(
          duration: motion.fast,
          curve: AppEasing.standard,
          width: TouchTarget.minimum - Strokes.focusRingOffset * 2,
          height: TouchTarget.minimum - Strokes.focusRingOffset * 2,
          decoration: BoxDecoration(color: bg, borderRadius: Radii.mdAll),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    strokeWidth: Strokes.ring,
                    color: fg,
                  ),
                )
              else
                Icon(icon, size: size, color: fg),
              if (badge != null && badge! > 0)
                Positioned(
                  top: Spacing.xs,
                  right: Spacing.xs,
                  child: _CountDot(count: badge!),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CountDot extends StatelessWidget {
  const _CountDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: IconSizes.sm),
      height: IconSizes.sm,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: Radii.pillAll,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppText.monoMicro.c(colors.onPrimary),
      ),
    );
  }
}
