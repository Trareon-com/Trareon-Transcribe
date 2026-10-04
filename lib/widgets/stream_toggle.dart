import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Which capture source a [StreamToggle] controls.
///
/// An enum, not a string, because the widget used to derive its screen-reader
/// announcement by comparing `label` against the English literals `'Mic'` and
/// `'Speaker'` — so the moment the visible label was translated to Indonesian
/// (which is the whole point of the product) every toggle fell through to the
/// generic branch and announced its own English key (audit A.12).
enum StreamSource {
  mic,

  /// System audio, i.e. what the speakers are playing.
  speaker;

  /// The visible chip label, in Indonesian.
  String get label => switch (this) {
    StreamSource.mic => 'Mikrofon',
    StreamSource.speaker => 'Suara sistem',
  };

  /// What a screen reader announces, including the on/off state.
  String announcement({required bool enabled}) {
    final state = enabled ? 'aktif' : 'nonaktif';
    return switch (this) {
      StreamSource.mic => 'Mikrofon $state',
      StreamSource.speaker => 'Pengeras suara $state',
    };
  }
}

class StreamToggle extends StatelessWidget {
  final StreamSource source;
  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const StreamToggle({
    super.key,
    required this.source,
    required this.enabled,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Semantics(
      label: source.announcement(enabled: enabled),
      toggled: enabled,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!enabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.15)
                : colors.chipBackground,
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(
              color: enabled ? accent.withValues(alpha: 0.4) : colors.border,
              width: enabled ? 1.5 : 1,
            ),
          ),
          // The chip's own text is excluded from the semantics tree: with it
          // merged in, a screen reader read "Mikrofon aktif, Mikrofon, HIDUP"
          // — the same fact three times. The one sentence above is the whole
          // announcement.
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? accent : colors.textTertiary,
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                Spacing.hSm,
                Text(
                  source.label,
                  style: TextStyle(
                    color: enabled ? accent : colors.textSecondary,
                    fontSize: FontSizes.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacing.hSm,
                Text(
                  enabled ? 'HIDUP' : 'MATI',
                  style: TextStyle(
                    color: enabled ? accent : colors.textTertiary,
                    fontSize: FontSizes.overline,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppFonts.mono,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
