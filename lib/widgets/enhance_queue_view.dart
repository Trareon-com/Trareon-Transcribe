/// "Perhalus transkrip" progress (F5), as shown in the session sidebar.
///
/// The background accurate pass is the thing that makes the quick-model
/// compromise acceptable, so it has to be *visible*: a user who sees nothing
/// assumes the transcript they have is final. Each row names the session, says
/// what is happening, and can be cancelled.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/enhance_queue_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class EnhanceQueueView extends ConsumerWidget {
  const EnhanceQueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(enhanceQueueProvider);
    final notifier = ref.read(enhanceQueueProvider.notifier);
    final jobs = queue.visible;
    if (jobs.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_motion_outlined,
                  size: IconSizes.sm, color: colors.primary),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  'Memperhalus transkrip',
                  style: TextStyle(
                    fontSize: FontSizes.caption,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
              if (jobs.length > 1)
                Tooltip(
                  message: 'Batalkan semua',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: TouchTarget.constraints,
                    icon: Icon(Icons.cancel_outlined,
                        size: IconSizes.md, color: colors.textSecondary),
                    onPressed: notifier.cancelAll,
                  ),
                ),
            ],
          ),
          if (queue.paused)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                'Ditunda selama ada rekaman berjalan.',
                style: TextStyle(
                  fontSize: FontSizes.micro,
                  color: colors.textTertiary,
                ),
              ),
            ),
          for (final job in jobs) ...[
            Spacing.gapSm,
            Semantics(
              liveRegion: job.status == EnhanceJobStatus.running,
              child: Row(
                children: [
                  SizedBox(
                    width: IconSizes.sm,
                    height: IconSizes.sm,
                    child: switch (job.status) {
                      EnhanceJobStatus.running =>
                        const CircularProgressIndicator(strokeWidth: 2),
                      EnhanceJobStatus.failed => Icon(Icons.error_outline,
                          size: IconSizes.sm, color: colors.error),
                      _ => Icon(Icons.schedule,
                          size: IconSizes.sm, color: colors.textTertiary),
                    },
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: FontSizes.caption,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          switch (job.status) {
                            EnhanceJobStatus.running =>
                              'Memakai model akurat… transkrip lama tetap '
                                  'aman sampai selesai.',
                            EnhanceJobStatus.failed =>
                              job.error ?? 'Gagal. Transkrip lama dipakai.',
                            _ => 'Menunggu antrean.',
                          },
                          style: TextStyle(
                            fontSize: FontSizes.micro,
                            color: job.status == EnhanceJobStatus.failed
                                ? colors.error
                                : colors.textTertiary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: job.status == EnhanceJobStatus.failed
                        ? 'Sembunyikan'
                        : 'Batalkan',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: TouchTarget.constraints,
                      icon: Icon(
                        job.status == EnhanceJobStatus.failed
                            ? Icons.close
                            : Icons.stop_circle_outlined,
                        size: IconSizes.md,
                        color: colors.textSecondary,
                      ),
                      onPressed: () => job.status == EnhanceJobStatus.failed
                          ? notifier.dismiss(job.directoryPath)
                          : notifier.cancel(job.directoryPath),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
