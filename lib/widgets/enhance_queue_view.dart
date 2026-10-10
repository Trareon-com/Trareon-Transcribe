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
import '../theme/app_icons.dart';
import 'ui/task_progress_tile.dart';

class EnhanceQueueView extends ConsumerWidget {
  const EnhanceQueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(enhanceQueueProvider);
    final notifier = ref.read(enhanceQueueProvider.notifier);
    final jobs = queue.visible;
    if (jobs.isEmpty) return const SizedBox.shrink();

    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
              Icon(
                AppIcons.enhanceQueue,
                size: IconSizes.sm,
                color: colors.primary,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  // Completion is a repair, enhancement is a polish. The
                  // heading has to say which, because only one of them
                  // means the transcript is currently incomplete.
                  jobs.any((j) => j.kind == EnhanceJobKind.complete)
                      ? 'Menyelesaikan transkrip'
                      : 'Memperhalus transkrip',
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
                    icon: Icon(
                      AppIcons.cancel,
                      size: IconSizes.md,
                      color: colors.textSecondary,
                    ),
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
            // The shared progress component (Sprint 14b, item 10): the same
            // determinate/indeterminate tile every other long operation in
            // the app uses, so the user learns one visual language for
            // "something is happening" rather than one per feature.
            TaskProgressTile(
              title: job.title,
              state: switch (job.status) {
                EnhanceJobStatus.running => TaskRunState.running,
                EnhanceJobStatus.failed => TaskRunState.failed,
                EnhanceJobStatus.done => TaskRunState.done,
                EnhanceJobStatus.cancelled => TaskRunState.cancelled,
                EnhanceJobStatus.queued => TaskRunState.queued,
              },
              stage: switch (job.kind) {
                EnhanceJobKind.complete =>
                  'Menyelesaikan ${sourceLabel(job.source)}',
                EnhanceJobKind.enhance => job.stage ?? 'Memproses',
              },
              progress: job.status == EnhanceJobStatus.running
                  ? job.progress
                  : null,
              etaLabel: job.etaSecs >= 5
                  ? 'sisa ${formatEta(job.etaSecs)}'
                  : null,
              statusOverride: switch (job.status) {
                EnhanceJobStatus.failed =>
                  job.error ?? 'Gagal. Transkrip lama dipakai.',
                EnhanceJobStatus.queued =>
                  job.kind == EnhanceJobKind.complete
                      ? 'Menunggu antrean, ada audio yang belum '
                            'ditranskripsi.'
                      : 'Menunggu antrean.',
                _ => null,
              },
              onCancel:
                  job.status == EnhanceJobStatus.queued ||
                      job.status == EnhanceJobStatus.running
                  ? () => notifier.cancel(job.directoryPath)
                  : null,
              onDismiss: job.status == EnhanceJobStatus.failed
                  ? () => notifier.dismiss(job.directoryPath)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
