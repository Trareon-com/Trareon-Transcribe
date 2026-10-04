/// Dense list rows. `docs/DESIGN-SYSTEM.md` §6.9.
///
/// No Material ink splash: a three-hour meeting produces thousands of
/// transcript rows and a session list of hundreds, and a ripple per row is
/// visibly janky. Hover is a 120 ms surface tint instead.
library;

import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import 'interactive.dart';

class AppListRow extends StatefulWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.meta,
    this.leading,
    this.badges = const [],
    this.actions = const [],
    this.onTap,
    this.selected = false,
    this.dense = false,
    this.semanticLabel,
  });

  final String title;

  /// One line of context: a snippet of the first segment, a path, a date.
  final String? subtitle;

  /// Right-aligned figures: a duration, a count. Rendered tabular.
  final String? meta;

  final Widget? leading;

  /// Status pills, shown under the title.
  final List<Widget> badges;

  /// Revealed on hover and on focus. Always also reachable by keyboard: the
  /// actions follow the row in traversal order rather than being hidden from
  /// it.
  final List<Widget> actions;

  final VoidCallback? onTap;
  final bool selected;
  final bool dense;
  final String? semanticLabel;

  @override
  State<AppListRow> createState() => _AppListRowState();
}

class _AppListRowState extends State<AppListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final showActions = widget.actions.isNotEmpty && _hovered;

    return Interactive(
      onPressed: widget.onTap,
      borderRadius: Radii.mdAll,
      selected: widget.selected,
      semanticLabel: widget.semanticLabel,
      onHoverChanged: (value) => setState(() => _hovered = value),
      builder: (context, state) => AnimatedContainer(
        duration: motion.fast,
        curve: AppEasing.standard,
        constraints: BoxConstraints(
          minHeight: widget.dense ? ControlSizes.rowMd : ControlSizes.rowLg,
        ),
        decoration: BoxDecoration(
          color: widget.selected
              ? colors.primarySubtle
              : state.pressed
              ? colors.surfacePressed
              : state.hovered
              ? colors.hoverOverlay
              : Colors.transparent,
          borderRadius: Radii.mdAll,
        ),
        child: Row(
          children: [
            // A 2 px accent rail on the selected row, so selection survives a
            // greyscale screenshot and a colour-blind reader.
            AnimatedContainer(
              duration: motion.fast,
              width: Strokes.selectionRail,
              height: widget.dense ? ControlSizes.sm : ControlSizes.md,
              decoration: BoxDecoration(
                color: widget.selected ? colors.primary : Colors.transparent,
                borderRadius: Radii.pillAll,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.sm + 2,
                  vertical: widget.dense ? Spacing.sm : Spacing.sm + 2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.leading != null) ...[
                      widget.leading!,
                      Spacing.hSm,
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.subheading.cw(
                              widget.selected ? colors.primaryText : colors.text,
                              widget.selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: Spacing.xs / 2),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.micro.c(colors.textTertiary),
                            ),
                          ],
                          if (widget.badges.isNotEmpty) ...[
                            const SizedBox(height: Spacing.xs + 2),
                            Wrap(
                              spacing: Spacing.xs,
                              runSpacing: Spacing.xs,
                              children: widget.badges,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.meta != null && !showActions) ...[
                      Spacing.hSm,
                      Text(
                        widget.meta!,
                        style: AppText.monoMicro.c(colors.textTertiary),
                      ),
                    ],
                    if (showActions) ...[Spacing.hXs, ...widget.actions],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sticky group header in a grouped list (`Hari ini`, `Kemarin`, …).
class AppListGroupHeader extends StatelessWidget {
  const AppListGroupHeader({super.key, required this.label, this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        Spacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppText.overline.c(colors.textTertiary),
          ),
          if (count != null) ...[
            Spacing.hSm,
            Text('$count', style: AppText.monoMicro.c(colors.textDisabled)),
          ],
        ],
      ),
    );
  }
}
