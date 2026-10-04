import 'package:flutter/material.dart';

import '../src/rust/session.dart' as rust_session;
import '../theme/app_colors.dart';
import '../utils/format_time.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// Indonesian label for a capture source id.
String captureSourceLabel(String source) =>
    source == 'spk' ? 'Audio sistem' : 'Mikrofon';

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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final health = this.health;
    if (health == null || health.channels.where((c) => c.expected).isEmpty) {
      return const SizedBox.shrink();
    }

    final confirmed = allExpectedConfirmed(health);
    final unconfirmed = health.channels
        .where((c) => c.expected && !c.confirmed)
        .map((c) => captureSourceLabel(c.source))
        .toList();
    final wentQuiet = health.channels
        .where((c) => c.expected && c.confirmed && c.silentForSecs >= 60)
        .map((c) => captureSourceLabel(c.source))
        .toList();

    final (icon, color, label) = switch (null) {
      _ when wentQuiet.isNotEmpty => (
        AppIcons.warning,
        colors.error,
        '${wentQuiet.join(' & ')} senyap',
      ),
      _ when confirmed => (
        AppIcons.verified,
        colors.primary,
        'Rekaman terkonfirmasi',
      ),
      _ => (
        AppIcons.waiting,
        colors.textSecondary,
        'Menunggu suara dari ${unconfirmed.join(' & ')}',
      ),
    };

    return Semantics(
      liveRegion: true,
      label: label,
      child: Tooltip(
        message: confirmed
            ? 'Setiap sumber yang diminta sudah menghasilkan suara di atas '
                  'ambang derau.'
            : 'Belum ada suara nyata dari semua sumber yang diminta.',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: IconSizes.xs, color: color),
            Spacing.hXs,
            Text(label, style: TextStyle(color: color, fontSize: FontSizes.micro)),
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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final expected = health.channels.where((c) => c.expected).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Durasi ${formatDurationId(health.elapsedSecs)} · '
          '${health.segmentCount} segmen transkrip',
          style: TextStyle(color: colors.text, fontSize: FontSizes.body),
        ),
        Spacing.gapSm,
        if (expected.isEmpty)
          Text(
            'Tidak ada sumber audio yang diminta untuk sesi ini.',
            style: TextStyle(color: colors.textSecondary, fontSize: FontSizes.caption),
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
                      style: TextStyle(color: colors.error, fontSize: FontSizes.caption),
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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
                ? '${captureSourceLabel(channel.source)}: '
                      '${formatDurationId(channel.secondsCaptured)} terekam, '
                      '${channel.percentSilent.toStringAsFixed(0)}% senyap'
                : '${captureSourceLabel(channel.source)}: tidak ada suara sama '
                      'sekali (${formatDurationId(channel.secondsCaptured)} terekam)',
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
        health.warnings.isEmpty ? 'Sesi selesai' : 'Sesi selesai — ada masalah',
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
              const Text('Transkrip belum tersimpan.'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}
