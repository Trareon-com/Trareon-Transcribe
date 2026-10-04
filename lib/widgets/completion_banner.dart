/// "Menyelesaikan transkrip… 34%" (ITEM 0).
///
/// A session whose live pass fell behind the meeting is not finished when
/// Stop is pressed — the stretches the worker never reached are still being
/// transcribed from the saved WAV. This is the one place that says so, and
/// it has to be visible wherever the user looks at that session, because
/// the alternative is a transcript that silently gains paragraphs while
/// they read it and a user who never learns why.
///
/// Shows nothing at all once the work is done.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/enhance_queue_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class CompletionBanner extends ConsumerWidget {
  const CompletionBanner({super.key, required this.sessionDirPath});

  final String sessionDirPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref
        .watch(enhanceQueueProvider)
        .completionJobsFor(sessionDirPath);
    if (jobs.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final running = jobs
        .where((j) => j.status == EnhanceJobStatus.running)
        .toList();
    final fraction = running.isEmpty
        ? null
        : running.map((j) => j.progress).reduce((a, b) => a + b) /
            running.length;

    return Material(
      color: colors.primary.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: IconSizes.sm,
              height: IconSizes.sm,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: (fraction ?? 0) > 0 ? fraction : null,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  completionStatusLine(jobs),
                  style: TextStyle(color: colors.text, fontSize: FontSizes.caption),
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Text(
              'Transkrip terisi sendiri; ekspor sekarang akan belum lengkap.',
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: FontSizes.micro,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "belum selesai" marker for a session row in the library.
///
/// The library's job is to say which meetings exist; this says which of
/// them the app is not finished with. Without it a session that is still
/// missing five minutes looks exactly like one that is complete.
class IncompleteBadge extends StatelessWidget {
  const IncompleteBadge({super.key, this.fraction});

  /// Speech coverage, when known, so the badge can be specific.
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final percent = fraction == null
        ? null
        : (fraction!.clamp(0.0, 1.0) * 100).round();
    final label = percent == null
        ? 'Belum selesai'
        : 'Belum selesai · $percent%';
    return Tooltip(
      message: 'Masih ada audio yang belum ditranskripsi. Transkrip akan '
          'dilengkapi otomatis di latar belakang.',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.16),
          borderRadius: Radii.smAll,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: FontSizes.micro,
            fontWeight: FontWeight.w600,
            color: colors.warning,
          ),
        ),
      ),
    );
  }
}
