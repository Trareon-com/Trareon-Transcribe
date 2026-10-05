import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'ui/app_button.dart';
import 'ui/app_controls.dart';
import 'ui/app_dialog.dart';

/// What the user chose to do with a word they just corrected.
class DictionaryLearning {
  /// Add the corrected spelling to the kamus istilah, so Whisper is biased
  /// towards it on every future recording.
  final bool addToGlossary;

  /// Remember `wrong → right` as an exact replacement, applied to every
  /// future transcript.
  final bool autoReplace;

  const DictionaryLearning({
    required this.addToGlossary,
    required this.autoReplace,
  });

  bool get isEmpty => !addToGlossary && !autoReplace;
}

/// Offers to learn from a one-word correction.
///
/// The pattern Spokenly and VoiceInk both use, and the one Research Round 2
/// §1.1 picks out of Wispr Flow: the second time a user fixes the same word
/// is the moment to ask, because by then they know it is systematic. The
/// two offers do different things and are both worth having:
///
/// * **Tambahkan ke kamus** biases the *decoder* — the term goes into
///   Whisper's `initial_prompt`, so the model becomes likelier to produce
///   it in the first place. This is the better fix, but it only works when
///   the model can plausibly hear the word.
/// * **Ganti otomatis selanjutnya** rewrites the *output* — an exact
///   replacement applied after inference. This is the fix for the words
///   Whisper will never get right, usually a name it hears as a different
///   word entirely.
///
/// Returns `null` when the user dismissed the dialog.
Future<DictionaryLearning?> showDictionaryLearningDialog(
  BuildContext context, {
  required String before,
  required String after,
}) {
  return showDialog<DictionaryLearning>(
    context: context,
    builder: (_) => _DictionaryLearningDialog(before: before, after: after),
  );
}

class _DictionaryLearningDialog extends StatefulWidget {
  final String before;
  final String after;

  const _DictionaryLearningDialog({required this.before, required this.after});

  @override
  State<_DictionaryLearningDialog> createState() =>
      _DictionaryLearningDialogState();
}

class _DictionaryLearningDialogState extends State<_DictionaryLearningDialog> {
  /// Checked by default: adding a term to the kamus cannot make a
  /// transcript wrong, it only makes the right word likelier.
  bool _addToGlossary = true;

  /// Unchecked by default: a replacement rule rewrites text unconditionally
  /// from now on, which is a bigger commitment than a prompt hint and one
  /// the user should make deliberately.
  bool _autoReplace = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppDialog(
      title: 'Ingat koreksi ini?',
      icon: AppIcons.glossary,
      description:
          'Anda mengubah satu kata. Trareon bisa mengingatnya agar '
          'tidak perlu dikoreksi lagi di rapat berikutnya.',
      actions: [
        AppButton(
          label: 'Jangan ingat',
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Simpan',
          variant: AppButtonVariant.primary,
          onPressed: _addToGlossary || _autoReplace
              ? () => Navigator.of(context).pop(
                  DictionaryLearning(
                    addToGlossary: _addToGlossary,
                    autoReplace: _autoReplace,
                  ),
                )
              : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CorrectionRow(before: widget.before, after: widget.after),
          Spacing.gapMd,
          _Option(
            value: _addToGlossary,
            onChanged: (value) => setState(() => _addToGlossary = value),
            label: 'Tambahkan "${widget.after}" ke kamus istilah',
            helper:
                'Mesin pengenal suara diberi tahu istilah ini sebelum '
                'mentranskrip, sehingga lebih mungkin menuliskannya dengan '
                'benar sejak awal.',
          ),
          Spacing.gapSm,
          _Option(
            value: _autoReplace,
            onChanged: (value) => setState(() => _autoReplace = value),
            label:
                'Ganti otomatis "${widget.before}" → "${widget.after}" '
                'selanjutnya',
            helper:
                'Setiap kata "${widget.before}" yang berdiri sendiri akan '
                'ditulis "${widget.after}" di transkrip berikutnya. Bisa '
                'dihapus di Pengaturan → Kamus istilah.',
          ),
          if (!_addToGlossary && !_autoReplace) ...[
            Spacing.gapSm,
            Text(
              'Pilih setidaknya satu agar ada yang disimpan.',
              style: AppText.caption.c(colors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// `salah → benar`, so the user can check the pair before committing to it.
class _CorrectionRow extends StatelessWidget {
  final String before;
  final String after;

  const _CorrectionRow({required this.before, required this.after});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: [
        Text(
          before,
          style: AppText.mono
              .c(colors.textTertiary)
              .copyWith(decoration: TextDecoration.lineThrough),
        ),
        Icon(AppIcons.arrowRight, size: IconSizes.sm, color: colors.icon),
        Text(
          after,
          style: AppText.mono
              .c(colors.primaryText)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// A checkbox with the sentence that explains what it will do.
///
/// [AppCheckbox] carries a label and nothing else, and these two options
/// are indistinguishable from their labels alone — one biases the decoder,
/// the other rewrites the output.
class _Option extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String helper;

  const _Option({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCheckbox(value: value, onChanged: onChanged, label: label),
        Padding(
          padding: const EdgeInsets.only(left: Spacing.xl, top: Spacing.xs),
          child: Text(helper, style: AppText.caption.c(colors.textSecondary)),
        ),
      ],
    );
  }
}
