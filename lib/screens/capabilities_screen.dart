/// "Apa jalan di mana" (F14).
///
/// The Privacy Report answers "what has this app sent, this session?".
/// This screen answers the question before it: "what *could* it send,
/// and what is on right now?" — every capability, where its work
/// happens, and why it is off when it is.
///
/// The rows come from `rust_core/src/capabilities.rs`, which
/// `rust_core/src/privacy.rs` checks against the source: a row claiming
/// to be local whose module contains a network primitive fails the
/// build. So this is not a page of marketing copy that happens to sit
/// next to the code — it is the same list the gate enforces.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../src/rust/capabilities.dart' as rust_capabilities;
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';

/// The capability table for the current settings.
///
/// A `FutureProvider` keyed on the settings, so flipping a switch in
/// Pengaturan and coming back here shows the new answer rather than a
/// cached one.
final capabilitiesProvider = FutureProvider<List<rust_capabilities.Capability>>(
  (ref) {
    final settings = ref.watch(settingsProvider);
    return ref.read(rustBridgeProvider).describeCapabilities(settings);
  },
);

class CapabilitiesScreen extends ConsumerWidget {
  const CapabilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final rows = ref.watch(capabilitiesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        foregroundColor: colors.text,
        elevation: 0,
        title: Text(
          context.l10n.capabilitiesScreenTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Text(
              context.l10n.capabilitiesScreenLoadFailed('$error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error),
            ),
          ),
        ),
        data: (capabilities) => ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            _Intro(colors: colors, capabilities: capabilities),
            Spacing.gapMd,
            for (final capability in capabilities)
              _CapabilityRow(
                key: ValueKey(capability.id),
                capability: capability,
                colors: colors,
              ),
          ],
        ),
      ),
    );
  }
}

/// Label for where a capability runs, in [l10n] (default: the language the
/// app is showing).
String runsAtLabel(rust_capabilities.RunsAt runsAt, {AppLocalizations? l10n}) {
  final strings = l10n ?? currentL10n;
  return switch (runsAt) {
    rust_capabilities.RunsAt.local => strings.capabilitiesScreenRunsLocal,
    rust_capabilities.RunsAt.summaryEndpoint =>
      strings.capabilitiesScreenRunsEndpoint,
    rust_capabilities.RunsAt.internet => strings.capabilitiesScreenRunsInternet,
  };
}

class _Intro extends StatelessWidget {
  const _Intro({required this.colors, required this.capabilities});

  final AppColorSet colors;
  final List<rust_capabilities.Capability> capabilities;

  @override
  Widget build(BuildContext context) {
    final networked = capabilities
        .where((c) => c.runsAt != rust_capabilities.RunsAt.local)
        .toList();
    final activeNetworked = networked.where((c) => c.enabled).length;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.capabilitiesScreenLocalCount(
              capabilities.length - networked.length,
              capabilities.length,
            ),
            style: TextStyle(
              fontSize: FontSizes.bodyLarge,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          Spacing.gapSm,
          Text(
            l10n.capabilitiesScreenNetworked(networked.length, activeNetworked),
            style: TextStyle(
              fontSize: FontSizes.caption,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          Spacing.gapSm,
          Text(
            l10n.capabilitiesScreenSourceNote,
            style: TextStyle(
              fontSize: FontSizes.micro,
              color: colors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    super.key,
    required this.capability,
    required this.colors,
  });

  final rust_capabilities.Capability capability;
  final AppColorSet colors;

  @override
  Widget build(BuildContext context) {
    final local = capability.runsAt == rust_capabilities.RunsAt.local;
    // Colour carries the privacy-relevant distinction (local vs not),
    // never the on/off state: a networked feature being off is good news
    // and must not be painted as a warning.
    final placeColor = local ? colors.primary : colors.warning;
    final l10n = context.l10n;

    return Semantics(
      label: l10n.capabilitiesScreenRowSemantics(
        capability.name,
        runsAtLabel(capability.runsAt, l10n: l10n),
        capability.enabled
            ? l10n.capabilitiesScreenActive
            : l10n.capabilitiesScreenInactive,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.mdAll,
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  local ? AppIcons.computer : AppIcons.cloud,
                  size: IconSizes.md,
                  color: placeColor,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    capability.name,
                    style: TextStyle(
                      fontSize: FontSizes.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
                _StatusChip(enabled: capability.enabled, colors: colors),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: IconSizes.md + Spacing.sm,
                top: Spacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    capability.detail,
                    style: TextStyle(
                      fontSize: FontSizes.caption,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  Spacing.gapSm,
                  Row(
                    children: [
                      Text(
                        l10n.capabilitiesScreenRunsAt,
                        style: TextStyle(
                          fontSize: FontSizes.micro,
                          color: colors.textTertiary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          capability.whereLabel,
                          style: TextStyle(
                            fontSize: FontSizes.micro,
                            color: placeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (capability.disabledReason.isNotEmpty) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      capability.disabledReason,
                      style: TextStyle(
                        fontSize: FontSizes.micro,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: Spacing.xs),
                  // The module is what makes the claim checkable; shown
                  // so a reader can go and look.
                  Text(
                    l10n.capabilitiesScreenCode(capability.module),
                    style: TextStyle(
                      fontSize: FontSizes.micro,
                      color: colors.textTertiary,
                      fontFamily: AppFonts.mono,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.enabled, required this.colors});

  final bool enabled;
  final AppColorSet colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: enabled
            ? colors.primary.withValues(alpha: 0.12)
            : colors.chipBackground,
        borderRadius: Radii.smAll,
      ),
      child: Text(
        enabled
            ? context.l10n.capabilitiesScreenActive
            : context.l10n.capabilitiesScreenInactive,
        style: TextStyle(
          fontSize: FontSizes.micro,
          fontWeight: FontWeight.w600,
          color: enabled ? colors.primary : colors.textTertiary,
        ),
      ),
    );
  }
}
