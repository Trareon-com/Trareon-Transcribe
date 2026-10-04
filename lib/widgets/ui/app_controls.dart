/// Segmented control, switch, menu. `docs/DESIGN-SYSTEM.md` §6.4 to §6.6.
library;

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import 'app_surface.dart';
import 'interactive.dart';
import 'key_hint.dart';

/// One option in an [AppSegmented].
@immutable
class AppSegment<T> {
  const AppSegment({
    required this.value,
    required this.label,
    this.icon,
    this.semanticLabel,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// A fuller sentence for a screen reader, where the visible label is a
  /// two-word abbreviation.
  final String? semanticLabel;
}

/// A segmented control.
///
/// The selected segment is a lifted tile on a sunken track, not an accent
/// fill: a three-way selector painted in the brand colour makes the accent the
/// loudest thing on the screen, and the accent is supposed to be scarce.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.expand = false,
    this.semanticLabel,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;

    Widget track = Container(
      height: ControlSizes.lg,
      padding: const EdgeInsets.all(Spacing.xs / 2 + 1),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final segment in segments)
            _Segment<T>(
              segment: segment,
              selected: segment.value == selected,
              enabled: enabled,
              expand: expand,
              motion: motion,
              onPressed: () => onChanged(segment.value),
            ),
        ],
      ),
    );

    if (!enabled) {
      track = Opacity(opacity: 0.5, child: track);
    }

    return Semantics(label: semanticLabel, container: true, child: track);
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.enabled,
    required this.expand,
    required this.motion,
    required this.onPressed,
  });

  final AppSegment<T> segment;
  final bool selected;
  final bool enabled;
  final bool expand;
  final AppMotion motion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = Interactive(
      onPressed: enabled ? onPressed : null,
      enabled: enabled,
      borderRadius: Radii.smAll,
      showFocusRing: true,
      semanticLabel: segment.semanticLabel ?? segment.label,
      selected: selected,
      builder: (context, state) {
        final fg = !enabled
            ? colors.textDisabled
            : selected
            ? colors.text
            : state.hovered
            ? colors.text
            : colors.textSecondary;
        return AnimatedContainer(
          duration: motion.slow,
          curve: AppEasing.standard,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          height: ControlSizes.lg - Spacing.sm - 2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? colors.surface
                : state.hovered
                ? colors.hoverOverlay
                : Colors.transparent,
            borderRadius: Radii.smAll,
            boxShadow: selected ? colors.shadowRaised : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segment.icon != null) ...[
                Icon(segment.icon, size: IconSizes.xs, color: fg),
                const SizedBox(width: Spacing.sm - 2),
              ],
              Text(
                segment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.cw(
                  fg,
                  selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
    return expand ? Expanded(child: content) : content;
  }
}

/// A toggle. 36x20 pill track, 16 px thumb.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// What the toggle controls, as a screen reader should read it. Required:
  /// a bare switch with no name is the most common a11y defect in a settings
  /// screen.
  final String semanticLabel;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final on = enabled && onChanged != null;

    return Interactive(
      onPressed: on ? () => onChanged!(!value) : null,
      enabled: on,
      borderRadius: Radii.pillAll,
      semanticLabel: semanticLabel,
      isButton: false,
      toggled: value,
      builder: (context, state) {
        final trackColor = !on
            ? colors.surfacePressed
            : value
            ? (state.hovered ? colors.primaryHover : colors.primary)
            : (state.hovered ? colors.borderInteractive : colors.surfaceSunken);
        return AnimatedContainer(
          duration: motion.fast,
          curve: AppEasing.standard,
          width: ControlSizes.switchWidth,
          height: ControlSizes.switchHeight,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: Radii.pillAll,
            border: Border.all(
              color: value && on ? Colors.transparent : colors.borderInteractive,
            ),
          ),
          child: AnimatedAlign(
            duration: motion.base,
            curve: AppEasing.standard,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs / 2),
              child: Container(
                width: IconSizes.sm,
                height: IconSizes.sm,
                decoration: BoxDecoration(
                  color: !on
                      ? colors.textDisabled
                      : value
                      ? colors.onPrimary
                      : colors.surface,
                  shape: BoxShape.circle,
                  boxShadow: colors.shadowRaised,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A checkbox with its label, sharing one hit target.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
    this.strikeWhenChecked = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final bool enabled;

  /// Action items read better struck through once done.
  final bool strikeWhenChecked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final on = enabled && onChanged != null;

    return Interactive(
      onPressed: on ? () => onChanged!(!value) : null,
      enabled: on,
      borderRadius: Radii.smAll,
      isButton: false,
      toggled: value,
      semanticLabel: label,
      builder: (context, state) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: state.active ? colors.hoverOverlay : Colors.transparent,
          borderRadius: Radii.smAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: motion.fast,
              curve: AppEasing.standard,
              width: IconSizes.md,
              height: IconSizes.md,
              decoration: BoxDecoration(
                color: value && on ? colors.primary : Colors.transparent,
                borderRadius: Radii.xsAll,
                border: Border.all(
                  color: !on
                      ? colors.borderDisabled
                      : value
                      ? colors.primary
                      : colors.borderInteractive,
                  width: Strokes.focusRing,
                ),
              ),
              child: value
                  ? Icon(
                      AppIcons.checkPlain,
                      size: IconSizes.xs,
                      color: colors.onPrimary,
                    )
                  : null,
            ),
            Spacing.hSm,
            Flexible(
              child: Text(
                label,
                style: AppText.body.c(
                  !on
                      ? colors.textDisabled
                      : value && strikeWhenChecked
                      ? colors.textTertiary
                      : colors.text,
                ).copyWith(
                  decoration: value && strikeWhenChecked
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in an [AppMenu].
@immutable
class AppMenuEntry<T> {
  const AppMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.shortcut,
    this.checked,
    this.danger = false,
    this.enabled = true,
  });

  /// A non-selectable section heading.
  const AppMenuEntry.header(this.label)
    : value = null,
      icon = null,
      shortcut = null,
      checked = null,
      danger = false,
      enabled = false;

  final T? value;
  final String label;
  final IconData? icon;
  final AppShortcut? shortcut;

  /// Non-null turns the row into a checkable item with a leading check column.
  final bool? checked;

  final bool danger;
  final bool enabled;

  bool get isHeader => value == null && checked == null;
}

/// A dropdown menu anchored under its child.
class AppMenu<T> extends StatelessWidget {
  const AppMenu({
    super.key,
    required this.entries,
    required this.onSelected,
    required this.child,
    required this.tooltip,
    this.enabled = true,
  });

  final List<AppMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final Widget child;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopupMenuButton<T>(
      enabled: enabled,
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(0, Spacing.xs),
      splashRadius: 0,
      color: colors.surfaceOverlay,
      elevation: 0,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final entry in entries)
          if (entry.isHeader)
            PopupMenuItem<T>(
              enabled: false,
              height: ControlSizes.sm,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: AppGroupLabel(entry.label),
            )
          else
            PopupMenuItem<T>(
              value: entry.value,
              enabled: entry.enabled,
              height: ControlSizes.md,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              child: _MenuRow<T>(entry: entry),
            ),
      ],
      child: child,
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.entry});

  final AppMenuEntry<T> entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = !entry.enabled
        ? colors.textDisabled
        : entry.danger
        ? colors.error
        : colors.text;
    return Row(
      children: [
        if (entry.checked != null)
          SizedBox(
            width: IconSizes.lg,
            child: entry.checked!
                ? Icon(
                    AppIcons.checkPlain,
                    size: IconSizes.sm,
                    color: colors.primaryText,
                  )
                : null,
          )
        else if (entry.icon != null) ...[
          Icon(entry.icon, size: IconSizes.sm, color: fg),
          Spacing.hSm,
        ],
        Expanded(
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.c(fg),
          ),
        ),
        if (entry.shortcut != null) ...[
          Spacing.hLg,
          KeyHint(entry.shortcut!),
        ],
      ],
    );
  }
}
