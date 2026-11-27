import 'package:material_ui/material_ui.dart';

import '../state/download_consent.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'ui/app_button.dart';
import 'ui/app_controls.dart';
import 'ui/app_dialog.dart';

/// The user's answer to [showDownloadConsentDialog].
class DownloadConsentAnswer {
  const DownloadConsentAnswer({
    required this.downloadNow,
    required this.deferOnMetered,
  });

  /// "Unduh sekarang" (true) or "Nanti" (false).
  final bool downloadNow;

  /// The "Tunda kalau koneksi metered" checkbox, saved either way.
  final bool deferOnMetered;
}

/// Asks once, before anything downloads, whether the first-run models may be
/// fetched now (issue #70). Lists each component with its size and the
/// total, so the user knows what the download will cost before agreeing.
///
/// Not dismissible by tapping outside: the answer decides whether the app
/// reaches the network, so it has to be one of the two buttons. Closing it
/// any other way counts as "Nanti".
Future<DownloadConsentAnswer> showDownloadConsentDialog({
  required BuildContext context,
  required List<DownloadPlanItem> items,
  required bool initialDeferOnMetered,
}) async {
  final answer = await showAppDialog<DownloadConsentAnswer>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DownloadConsentDialog(
      items: items,
      initialDeferOnMetered: initialDeferOnMetered,
    ),
  );
  return answer ??
      DownloadConsentAnswer(
        downloadNow: false,
        deferOnMetered: initialDeferOnMetered,
      );
}

class DownloadConsentDialog extends StatefulWidget {
  const DownloadConsentDialog({
    super.key,
    required this.items,
    required this.initialDeferOnMetered,
  });

  final List<DownloadPlanItem> items;
  final bool initialDeferOnMetered;

  @override
  State<DownloadConsentDialog> createState() => _DownloadConsentDialogState();
}

class _DownloadConsentDialogState extends State<DownloadConsentDialog> {
  late bool _deferOnMetered = widget.initialDeferOnMetered;

  void _answer(bool downloadNow) => Navigator.of(context).pop(
    DownloadConsentAnswer(
      downloadNow: downloadNow,
      deferOnMetered: _deferOnMetered,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = totalMegabytes(widget.items);

    return AppDialog(
      icon: AppIcons.download,
      title: 'Unduh model transkripsi?',
      description:
          'Trareon bekerja offline, jadi modelnya perlu ada di perangkat ini. '
          'Unduhan hanya sekali dan tercatat di Laporan Privasi.',
      showClose: false,
      actions: [
        AppButton.ghost(label: 'Nanti', onPressed: () => _answer(false)),
        AppButton.primary(
          label: 'Unduh sekarang',
          icon: AppIcons.download,
          onPressed: () => _answer(true),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Spacing.gapMd,
          for (final item in widget.items)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.label, style: AppText.body.c(colors.text)),
                  ),
                  Text(
                    '±${item.megabytes} MB',
                    style: AppText.body.c(colors.textSecondary),
                  ),
                ],
              ),
            ),
          Divider(color: colors.hairline, height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: AppText.title.c(colors.textStrong),
                ),
              ),
              Text(
                '±$total MB',
                key: const Key('download-consent-total'),
                style: AppText.title.c(colors.textStrong),
              ),
            ],
          ),
          Spacing.gapMd,
          AppCheckbox(
            value: _deferOnMetered,
            onChanged: (v) => setState(() => _deferOnMetered = v),
            label: 'Tunda kalau koneksi metered',
          ),
          Spacing.gapMd,
        ],
      ),
    );
  }
}
