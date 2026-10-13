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
String modelDisplayLabel(String id) {
  return switch (id) {
    'tiny' => 'Ringan',
    'base' => 'Cepat',
    'qwen3-asr-0.6b' => 'Cepat-Eksperimental',
    'small' => 'Sedang',
    'medium' => 'Tinggi',
    'large-v3-turbo' => 'Akurat',
    'large-v3-turbo-q5' => 'Akurat (disarankan)',
    'qwen3-asr-1.7b' => 'Akurat-Eksperimental',
    _ => 'Model terpasang',
  };
}
