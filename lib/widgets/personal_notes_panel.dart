/// F11: the split-screen personal-notes panel shown next to the live
/// transcript while a session is recording.
///
/// This is the whole point of the feature — Granola's moat, per
/// `docs/TRAREON-V1-PRODUCTION-BLUEPRINT.md` §F11 — so the panel has to be
/// visible the moment the user is recording, not buried in a dialog. What
/// is typed here is mirrored into the crash-recovery snapshot (debounced,
/// see `SessionNotifier.setPersonalNotes`) and, once the session stops,
/// into its sidecar — "Enhance" on the session screen is what turns it
/// into a merged document together with the transcript.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'ui/app_field.dart';

class PersonalNotesPanel extends StatefulWidget {
  const PersonalNotesPanel({
    super.key,
    required this.notes,
    required this.onChanged,
    this.trailing,
  });

  /// The notes as currently held in [SessionUiState.personalNotes].
  ///
  /// Only consulted once, at construction: this widget owns its own
  /// [TextEditingController] (the same pattern `_TaskField` in
  /// `notulen_dialog.dart` uses) so that calling [onChanged] on every
  /// keystroke, which flows back here as a new widget instance, cannot
  /// reset the caret mid-sentence.
  final String notes;
  final ValueChanged<String> onChanged;

  /// An optional control placed at the end of the header row — the
  /// "Tanya Langsung" tab switcher (Sprint 21), when this panel and that
  /// one share the same spot. A fixed-width trailing widget next to an
  /// `Expanded` title is what keeps the header from overflowing at the
  /// narrowest supported window, unlike a side-by-side tab row would.
  final Widget? trailing;

  @override
  State<PersonalNotesPanel> createState() => _PersonalNotesPanelState();
}

class _PersonalNotesPanelState extends State<PersonalNotesPanel> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.notes,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.edit, size: IconSizes.sm, color: colors.primary),
              Spacing.hSm,
              Expanded(
                child: Text(
                  'Catatan Pribadi',
                  style: AppText.bodyStrong.c(colors.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          Spacing.gapXs,
          Text(
            'Tersimpan otomatis. Enhance nanti menggabungkannya dengan '
            'transkrip.',
            style: AppText.caption.c(colors.textTertiary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Spacing.gapSm,
          // `Expanded` over `SingleChildScrollView`, not a bare `Expanded`
          // over the field: the field's own minimum height (a label-less
          // row still needs room for its border and padding) can exceed
          // whatever a narrow recording window has left after the header
          // above, and a scroll view turns that into "scrolls" instead of
          // the hard `RenderFlex overflowed` Sprint 19 hit here at 800x600.
          Expanded(
            child: SingleChildScrollView(
              child: AppTextField(
                controller: _controller,
                maxLines: 1000,
                minLines: 3,
                reserveHelperSpace: false,
                placeholder: 'mis. PENTING: deadline Jumat…',
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
