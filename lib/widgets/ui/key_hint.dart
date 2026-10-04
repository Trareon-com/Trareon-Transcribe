/// Keyboard shortcut hints, rendered as keycaps. `docs/DESIGN-SYSTEM.md`
/// §6.17, and the shortcut table itself in `lib/theme/app_shortcuts.dart`.
///
/// Platform-aware by construction: the same [AppShortcut] renders `⌘ R` on
/// macOS and `Ctrl R` everywhere else, so the hint, the menu-bar item and the
/// actual key binding cannot drift apart.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

/// Whether this build renders macOS key symbols. Overridable so widget tests
/// and goldens can pin both renderings without a real macOS host.
bool get usesCommandKey => _forcedMac ?? (!kIsWeb && Platform.isMacOS);
bool? _forcedMac;

@visibleForTesting
set debugForceCommandKey(bool? value) => _forcedMac = value;

/// One shortcut, described once.
@immutable
class AppShortcut {
  const AppShortcut(
    this.key, {
    this.primary = false,
    this.shift = false,
    this.alt = false,
  });

  /// The key as the user reads it: `R`, `,`, `/`, `Enter`.
  final String key;

  /// The platform's primary modifier: Command on macOS, Control elsewhere.
  final bool primary;

  final bool shift;
  final bool alt;

  /// The caps to render, in the order a keyboard reads them.
  List<String> get caps => [
    if (primary) (usesCommandKey ? '⌘' : 'Ctrl'),
    if (shift) (usesCommandKey ? '⇧' : 'Shift'),
    if (alt) (usesCommandKey ? '⌥' : 'Alt'),
    key,
  ];

  /// A flat label for a tooltip or a semantics string. macOS stacks the
  /// symbols with no separator the way the system menu bar does; everywhere
  /// else they are joined with a plus.
  String get label => caps.join(usesCommandKey ? '' : '+');
}

/// Renders an [AppShortcut] as keycaps.
class KeyHint extends StatelessWidget {
  const KeyHint(this.shortcut, {super.key, this.muted = true});

  final AppShortcut shortcut;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    // Excluded from semantics: a screen reader announcing "command R" after
    // every button label is noise, and the action's own name already carries
    // the meaning. The binding itself stays reachable.
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final cap in shortcut.caps) ...[
            if (cap != shortcut.caps.first)
              const SizedBox(width: Spacing.xs / 2),
            _Cap(cap, muted: muted),
          ],
        ],
      ),
    );
  }
}

class _Cap extends StatelessWidget {
  const _Cap(this.text, {required this.muted});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: ControlSizes.sm - Spacing.sm,
      constraints: const BoxConstraints(minWidth: ControlSizes.sm - Spacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs + 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: Radii.xsAll,
        border: Border.all(color: colors.hairline),
      ),
      child: Text(
        text,
        style: AppText.monoMicro.c(
          muted ? colors.textTertiary : colors.textSecondary,
        ),
      ),
    );
  }
}

/// A label with its shortcut, for a menu row or a footer hint.
class KeyHintRow extends StatelessWidget {
  const KeyHintRow({super.key, required this.label, required this.shortcut});

  final String label;
  final AppShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.body.c(colors.text))),
          Spacing.hMd,
          KeyHint(shortcut),
        ],
      ),
    );
  }
}
