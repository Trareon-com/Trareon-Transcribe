import 'package:flutter/material.dart';

import '../src/rust/session.dart' as rust_session;
import '../theme/app_colors.dart';
import '../utils/format_time.dart';

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
        Icons.warning_amber_rounded,
        colors.error,
        '${wentQuiet.join(' & ')} senyap',
      ),
      _ when confirmed => (
        Icons.verified_outlined,
        colors.primary,
        'Rekaman terkonfirmasi',
      ),
      _ => (
        Icons.hourglass_empty,
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
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
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
          style: TextStyle(color: colors.text, fontSize: 13),
        ),
        const SizedBox(height: 10),
        if (expected.isEmpty)
          Text(
            'Tidak ada sumber audio yang diminta untuk sesi ini.',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          )
        else
          for (final channel in expected) ...[
            _ChannelRow(channel: channel),
            const SizedBox(height: 6),
          ],
        if (health.warnings.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final warning in health.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 15, color: colors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(color: colors.error, fontSize: 12),
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
          delivered ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 16,
          color: delivered ? colors.primary : colors.error,
        ),
        const SizedBox(width: 6),
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
              fontSize: 12,
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
              const SizedBox(height: 10),
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
