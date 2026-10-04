/// Surfaces: cards, panels, hairlines. `docs/DESIGN-SYSTEM.md` §2.7 and §6.8.
///
/// The rule the whole system rests on: hairlines before boxes, boxes before
/// shadows. In dark mode there are no shadows at all above elevation 1, and
/// depth is a surface ladder instead.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

/// Where a surface sits in the ladder.
enum Elevation {
  /// No border, no shadow. Content directly on the canvas.
  flat,

  /// 1 px hairline on [AppColorSet.surface].
  hairline,

  /// A panel genuinely lifted off the surface.
  raised,

  /// Menus, popovers.
  overlay,

  /// Dialogs, sheets, toasts, the floating player bar.
  modal,
}

extension ElevationSurface on Elevation {
  Color fill(AppColorSet colors) => switch (this) {
    Elevation.flat => Colors.transparent,
    Elevation.hairline => colors.surface,
    Elevation.raised => colors.surfaceRaised,
    Elevation.overlay => colors.surfaceOverlay,
    Elevation.modal => colors.surfaceModal,
  };

  List<BoxShadow> shadow(AppColorSet colors) => switch (this) {
    Elevation.flat || Elevation.hairline => const [],
    Elevation.raised => colors.shadowRaised,
    Elevation.overlay => colors.shadowOverlay,
    Elevation.modal => colors.shadowModal,
  };

  Color? border(AppColorSet colors) => switch (this) {
    Elevation.flat => null,
    Elevation.hairline ||
    Elevation.raised ||
    Elevation.overlay => colors.hairline,
    Elevation.modal => colors.hairlineStrong,
  };
}

/// A container at a named elevation.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.elevation = Elevation.hairline,
    this.radius = Radii.lgAll,
    this.padding,
    this.width,
    this.height,
    this.borderColor,
    this.fill,
    this.clip = false,
  });

  final Widget child;
  final Elevation elevation;
  final BorderRadius radius;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  /// Overrides the elevation's border, for a selected or semantic state.
  final Color? borderColor;

  /// Overrides the elevation's fill.
  final Color? fill;

  final bool clip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = borderColor ?? elevation.border(colors);
    return Container(
      width: width,
      height: height,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: fill ?? elevation.fill(colors),
        borderRadius: radius,
        border: border == null
            ? null
            : Border.all(color: border, width: Strokes.hairline),
        boxShadow: elevation.shadow(colors),
      ),
      child: child,
    );
  }
}

/// A card: `lg` radius, hairline, `lg` padding, with an optional header row.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.elevation = Elevation.hairline,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.selected = false,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Elevation elevation;
  final EdgeInsets padding;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final header = title;
    return AppSurface(
      elevation: elevation,
      borderColor: selected ? colors.primary : null,
      fill: selected ? colors.primarySubtle : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.sm,
                Spacing.md,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, Spacing.hSm],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          header,
                          style: AppText.heading.c(colors.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: Spacing.xs / 2),
                          Text(
                            subtitle!,
                            style: AppText.caption.c(colors.textTertiary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            AppHairline(color: colors.hairline),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A 1 px rule. Named so nobody reaches for `Divider` and gets Material's
/// 16 px of vertical space for free.
class AppHairline extends StatelessWidget {
  const AppHairline({
    super.key,
    this.color,
    this.indent = 0,
    this.strong = false,
  });

  final Color? color;
  final double indent;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: SizedBox(
        height: Strokes.hairline,
        child: ColoredBox(
          color: color ?? (strong ? colors.hairlineStrong : colors.hairline),
        ),
      ),
    );
  }
}

/// A vertical 1 px rule, for splitting a row.
class AppVerticalHairline extends StatelessWidget {
  const AppVerticalHairline({super.key, this.height, this.color});

  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: Strokes.hairline,
      height: height ?? Spacing.lg,
      child: ColoredBox(color: color ?? colors.hairline),
    );
  }
}

/// A group of settings rows under one heading. The Settings pane is built
/// entirely out of these.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.icon,
  });

  final String title;
  final String? description;
  final IconData? icon;

  /// Rendered hairline-separated. Use [AppSettingRow] for each.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Spacing.xs, bottom: Spacing.sm),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: IconSizes.sm, color: colors.textTertiary),
                Spacing.hSm,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppText.heading.c(colors.text)),
                    if (description != null) ...[
                      const SizedBox(height: Spacing.xs / 2),
                      Text(
                        description!,
                        style: AppText.caption.c(colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        AppSurface(
          radius: Radii.lgAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) AppHairline(color: colors.hairline),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row inside an [AppSectionCard]: a label, a helper line that says what
/// the current value *means*, and the control.
class AppSettingRow extends StatelessWidget {
  const AppSettingRow({
    super.key,
    required this.label,
    this.helper,
    this.control,
    this.below,
    this.status,
    this.icon,
  });

  final String label;

  /// Dynamic: it describes the current value, not the setting. "Transkripsi
  /// memakai CPU" rather than "Akselerasi GPU".
  final String? helper;

  final Widget? control;

  /// Rendered full width under the label and control, for a control that is
  /// too wide to sit on the right (a path picker, a text area).
  final Widget? below;

  /// Inline status, which is where a settings result belongs. A toast for
  /// "tersimpan" on a settings toggle is noise.
  final Widget? status;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: IconSizes.md, color: colors.textTertiary),
                Spacing.hMd,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: AppText.subheading.c(colors.text)),
                    if (helper != null) ...[
                      const SizedBox(height: Spacing.xs / 2),
                      Text(
                        helper!,
                        style: AppText.caption.c(colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              if (control != null) ...[Spacing.hLg, control!],
            ],
          ),
          if (status != null) ...[Spacing.gapSm, status!],
          if (below != null) ...[Spacing.gapMd, below!],
        ],
      ),
    );
  }
}

/// The small upper-case label above a control group (`SESI`, `PERANGKAT`).
///
/// At most one per visual group, and never above a section headline: an
/// eyebrow over every heading is the most recognisable templated rhythm there
/// is (design-taste §4.7).
class AppGroupLabel extends StatelessWidget {
  const AppGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text.toUpperCase(),
      style: AppText.overline.c(colors.textTertiary),
    );
  }
}
