import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/privacy_report_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

class PrivacyReportScreen extends ConsumerStatefulWidget {
  const PrivacyReportScreen({super.key});

  @override
  ConsumerState<PrivacyReportScreen> createState() =>
      _PrivacyReportScreenState();
}

class _PrivacyReportScreenState extends ConsumerState<PrivacyReportScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(privacyReportProvider);
    final elapsed = DateTime.now().difference(report.launchedAt);
    final isClean = report.networkCallCount == 0;
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.privacyReportScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          Card(
            color: isClean ? colors.success.withValues(alpha: 0.1) : null,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(
                children: [
                  Icon(
                    isClean ? AppIcons.verifiedUser : AppIcons.warning,
                    color: isClean ? colors.success : colors.warning,
                    size: IconSizes.hero,
                  ),
                  Spacing.hLg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.privacyReportScreenNetworkCalls(
                            report.networkCallCount,
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          context.l10n.privacyReportScreenSessionRunning(
                            _formatDuration(elapsed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Spacing.gapLg,
          // The log comes before the explanation: what actually happened on
          // this machine is the point of the screen, and it used to sit
          // under a screenful of prose.
          if (report.events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Text(context.l10n.privacyReportScreenNoActivity),
            )
          else ...[
            Text(
              context.l10n.privacyReportScreenHistory,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final event in report.events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Text('• $event'),
              ),
          ],
          Spacing.gapLg,
          Text(context.l10n.privacyReportScreenExplanation),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final l10n = context.l10n;
    if (h > 0) return l10n.privacyReportScreenDurationHours(h, m);
    if (m > 0) return l10n.privacyReportScreenDurationMinutes(m, s);
    return l10n.privacyReportScreenDurationSeconds(s);
  }
}
