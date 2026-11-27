import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../src/rust/session.dart' as rust_session;
import '../state/audio_watchdog_model.dart';
import '../theme/app_colors.dart';
import '../utils/format_time.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// User-facing label for a capture source id.
String captureSourceLabel(BuildContext context, String source) =>
    source == 'spk'
    ? context.l10n.captureHealthViewSourceSystem
    : context.l10n.captureHealthViewSourceMic;

/// Whether every source the user asked for has delivered real audio.
///
/// Deliberately not "a stream is open": the failure this whole feature
/// exists for is a microphone that was open all meeting and recorded
/// nothing. A VU meter twitching at the noise floor looks identical.
bool allExpectedConfirmed(rust_session.CaptureHealth health) {
  final expected = health.channels.where((c) => c.expected).toList();
  return expected.isNotEmpty && expected.every((c) => c.confirmed);
}

/// Compact live badge next to the VU meters: "Rekaman terkonfirmasi" once
/// every expected source has been above the noise floor, "Menunggu suara…"
/// until then, and a warning when a source has gone quiet.
class CaptureConfirmationBadge extends StatelessWidget {
  const CaptureConfirmationBadge({super.key, required this.health});

  final rust_session.CaptureHealth? health;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final health = this.health;
    if (health == null || health.channels.where((c) => c.expected).isEmpty) {
      return const SizedBox.shrink();
    }

    final confirmed = allExpectedConfirmed(health);
    final unconfirmed = health.channels
        .where((c) => c.expected && !c.confirmed)
        .map((c) => captureSourceLabel(context, c.source))
        .toList();
    final wentQuiet = health.channels
        .where((c) => c.expected && c.confirmed && c.silentForSecs >= 60)
        .map((c) => captureSourceLabel(context, c.source))
        .toList();

    final (icon, color, label) = switch (null) {
      _ when wentQuiet.isNotEmpty => (
        AppIcons.warning,
        colors.error,
        context.l10n.captureHealthViewWentSilent(wentQuiet.join(' & ')),
      ),
      _ when confirmed => (
        AppIcons.verified,
        colors.primary,
        context.l10n.captureHealthViewConfirmed,
      ),
      _ => (
        AppIcons.waiting,
        colors.textSecondary,
        context.l10n.captureHealthViewWaiting(unconfirmed.join(' & ')),
      ),
    };

    return Semantics(
      liveRegion: true,
      label: label,
      child: Tooltip(
        message: confirmed
            ? context.l10n.captureHealthViewConfirmedTooltip
            : context.l10n.captureHealthViewUnconfirmedTooltip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: IconSizes.xs, color: color),
            Spacing.hXs,
            Text(
              label,
              style: TextStyle(color: color, fontSize: FontSizes.micro),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small permanent marker (mic icon with a dot) that replaces the old
/// yellow banner for a no-audio/permission problem (Sprint 14b, item 8).
///
/// The toast itself now auto-dismisses after 8-12 s, which is the point —
/// but the underlying condition (no mic permission, a dead source) usually
/// outlives the toast, and the user needs *some* durable way to tell the
/// problem is still open without the screen staying covered. This sits next
/// to [CaptureConfirmationBadge] and stays as long as
/// [audioHealthIndicatorProvider] is true, regardless of whether the last
/// toast was dismissed or cooled down.
class AudioHealthIndicator extends ConsumerWidget {
  const AudioHealthIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(audioHealthIndicatorProvider);
    if (!active) return const SizedBox.shrink();
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final label = context.l10n.captureHealthViewAudioIssue;
    return Semantics(
      label: label,
      child: Tooltip(
        message: context.l10n.captureHealthViewAudioIssueTooltip(label),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(AppIcons.mic, size: IconSizes.sm, color: colors.textSecondary),
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: colors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown after Stop. Says per channel how long it recorded, how much of
/// that was silence, and — in red, first — which expected channel produced
/// nothing at all.
class CaptureIntegritySummary extends StatelessWidget {
  const CaptureIntegritySummary({super.key, required this.health});

  final rust_session.CaptureHealth health;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final expected = health.channels.where((c) => c.expected).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.captureHealthViewSummary(
            formatDurationId(health.elapsedSecs),
            health.segmentCount,
          ),
          style: TextStyle(color: colors.text, fontSize: FontSizes.body),
        ),
        Spacing.gapSm,
        if (expected.isEmpty)
          Text(
            context.l10n.captureHealthViewNoSources,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: FontSizes.caption,
            ),
          )
        else
          for (final channel in expected) ...[
            _ChannelRow(channel: channel),
            Spacing.gapSm,
          ],
        if (health.warnings.isNotEmpty) ...[
          Spacing.gapSm,
          for (final warning in health.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.error, size: IconSizes.sm, color: colors.error),
                  Spacing.hSm,
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        color: colors.error,
                        fontSize: FontSizes.caption,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel});

  final rust_session.ChannelCapture channel;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final delivered = channel.confirmed;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          delivered ? AppIcons.check : AppIcons.cancel,
          size: IconSizes.sm,
          color: delivered ? colors.primary : colors.error,
        ),
        Spacing.hSm,
        Expanded(
          child: Text(
            delivered
                ? context.l10n.captureHealthViewChannelOk(
                    captureSourceLabel(context, channel.source),
                    formatDurationId(channel.secondsCaptured),
                    channel.percentSilent.toStringAsFixed(0),
                  )
                : context.l10n.captureHealthViewChannelSilent(
                    captureSourceLabel(context, channel.source),
                    formatDurationId(channel.secondsCaptured),
                  ),
            style: TextStyle(
              color: delivered ? colors.textSecondary : colors.error,
              fontSize: FontSizes.caption,
            ),
          ),
        ),
      ],
    );
  }
}

/// Modal shown at Stop. Only appears when there is something to say — a
/// clean session with every channel confirmed gets the usual toast.
Future<void> showCaptureIntegrityDialog(
  BuildContext context,
  rust_session.CaptureHealth health, {
  required bool saved,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        health.warnings.isEmpty
            ? context.l10n.captureHealthViewSessionDone
            : context.l10n.captureHealthViewSessionDoneIssues,
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CaptureIntegritySummary(health: health),
            if (!saved) ...[
              Spacing.gapSm,
              Text(context.l10n.captureHealthViewNotSaved),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.captureHealthViewClose),
        ),
      ],
    ),
  );
}
