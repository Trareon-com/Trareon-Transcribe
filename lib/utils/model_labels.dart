import '../l10n/l10n.dart';

/// Label UI generik untuk model — nama model TIDAK boleh terekspos ke user.
///
/// `qwen3-asr-0.6b`/`qwen3-asr-1.7b` (2026-10-13): CrispASR "Eksperimental"
/// tiers, labeled consistently with the 6-card setup wizard
/// (`_ModelChoiceStep` in setup_wizard_screen.dart) — this function is the
/// ONE place every other screen (Settings dropdown, file upload zone,
/// session controls, retranscribe dialog, player screen) gets a model's
/// display name from, so a label added only in the wizard would leave
/// these two ids falling through to the generic 'Model terpasang' bucket
/// everywhere else.
///
/// No `BuildContext` here (it is also handed to `labelBuilder`s directly),
/// so the label follows [currentL10n].
String modelDisplayLabel(String id) {
  final l10n = currentL10n;
  return switch (id) {
    'tiny' => l10n.modelLabelsLight,
    'base' => l10n.modelLabelsFast,
    'qwen3-asr-0.6b' => l10n.modelLabelsFastExperimental,
    'small' => l10n.modelLabelsMedium,
    'medium' => l10n.modelLabelsHigh,
    'large-v3-turbo' => l10n.modelLabelsAccurate,
    'large-v3-turbo-q5' => l10n.modelLabelsAccurateRecommended,
    'qwen3-asr-1.7b' => l10n.modelLabelsAccurateExperimental,
    _ => l10n.modelLabelsInstalled,
  };
}
