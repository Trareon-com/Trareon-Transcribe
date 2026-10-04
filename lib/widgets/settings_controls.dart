/// Shared building blocks for the settings panes.
///
/// Extracted from the old single-column side panel so the two-pane layout
/// (blueprint §4.5) can compose the same rows without duplicating them.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Spacing.xs, bottom: Spacing.sm),
          // A heading, so a screen reader can jump between settings groups
          // instead of reading the whole pane top to bottom.
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: FontSizes.caption,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: colors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.divider,
      indent: 56,
      endIndent: 16,
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: IconSizes.lg, color: colors.textSecondary),
            Spacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: FontSizes.bodyLarge,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    Spacing.gapXs,
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: FontSizes.caption,
                        color: colors.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Flexible(fit: FlexFit.loose, child: trailing),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitch({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    // One node per row: a reader announcing the icon, then the label, then the
    // helper text, then "switch" is four stops for one decision.
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: IconSizes.lg,
                color: colors.textSecondary,
              ),
            ),
            Spacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: FontSizes.bodyLarge,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                    ),
                  ),
                  Spacing.gapXs,
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: FontSizes.caption,
                      color: colors.textTertiary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: colors.primary,
              activeTrackColor: colors.primary.withValues(alpha: 0.3),
              inactiveThumbColor: colors.textTertiary,
              inactiveTrackColor: colors.border,
            ),
          ],
        ),
      ),
    );
  }
}

class CompactDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const CompactDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    labelBuilder(item),
                    style: TextStyle(
                      fontSize: FontSizes.body,
                      color: colors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
          dropdownColor: colors.surface,
          icon: Icon(
            AppIcons.chevronDown,
            size: IconSizes.md,
            color: colors.textSecondary,
          ),
          style: TextStyle(fontSize: FontSizes.body, color: colors.text),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
    );
  }
}

class InfoBadge extends StatelessWidget {
  final String message;

  const InfoBadge({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return InkWell(
      onTap: () => _showInfoDialog(context, colors),
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.info, size: IconSizes.xs, color: colors.primary),
            Spacing.hXs,
            Text(
              'Penjelasan',
              style: TextStyle(
                fontSize: FontSizes.micro,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, AppColorSet colors) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Informasi', style: TextStyle(color: colors.text)),
        content: Text(message, style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }
}
