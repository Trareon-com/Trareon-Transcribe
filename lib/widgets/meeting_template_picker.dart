/// F24: "Mulai dari template" — picking (or creating) a meeting setup
/// template before a new session starts.
///
/// Deliberately separate from `notulen_dialog.dart`: that dialog edits the
/// *document* a finished session produces, this one edits the *setup* a
/// session starts with.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/meeting_templates.dart';
import '../state/models.dart' show SessionMode;
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'ui/app_button.dart';
import 'ui/app_dialog.dart';
import 'ui/app_field.dart';

/// Shows the picker. Returns the chosen template, or `null` if the user
/// dismissed the dialog without picking one.
Future<MeetingTemplate?> showMeetingTemplatePicker(BuildContext context) {
  return showDialog<MeetingTemplate>(
    context: context,
    builder: (_) => const _TemplatePickerDialog(),
  );
}

String _modeLabel(AppLocalizations l10n, SessionMode mode) => switch (mode) {
  SessionMode.webinar => l10n.meetingTemplatePickerModeWebinar,
  SessionMode.online => l10n.meetingTemplatePickerModeOnline,
  SessionMode.offline => l10n.meetingTemplatePickerModeOffline,
};

String _languageLabel(AppLocalizations l10n, String? language) =>
    switch (language) {
      'id' => l10n.meetingTemplatePickerLanguageIndonesian,
      'en' => l10n.meetingTemplatePickerLanguageEnglish,
      _ => l10n.meetingTemplatePickerLanguageAuto,
    };

class _TemplatePickerDialog extends ConsumerStatefulWidget {
  const _TemplatePickerDialog();

  @override
  ConsumerState<_TemplatePickerDialog> createState() =>
      _TemplatePickerDialogState();
}

class _TemplatePickerDialogState
    extends ConsumerState<_TemplatePickerDialog> {
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    ref.read(meetingTemplatesProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final templates = ref.watch(meetingTemplatesProvider);

    if (_creating) {
      return _TemplateEditorDialog(
        onSaved: (template) {
          if (!mounted) return;
          Navigator.of(context).pop(template);
        },
        onCancel: () => setState(() => _creating = false),
      );
    }

    return AppDialog(
      title: l10n.meetingTemplatePickerTitle,
      icon: AppIcons.event,
      description: templates.isEmpty
          ? l10n.meetingTemplatePickerEmptyDescription
          : l10n.meetingTemplatePickerDescription,
      actions: [
        AppButton(
          label: l10n.actionCancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final template in templates)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _TemplateRow(
                template: template,
                onUse: () => Navigator.of(context).pop(template),
                onDelete: () => ref
                    .read(meetingTemplatesProvider.notifier)
                    .remove(template.id),
              ),
            ),
          Spacing.gapSm,
          AppButton(
            label: l10n.meetingTemplatePickerCreate,
            variant: AppButtonVariant.secondary,
            icon: AppIcons.add,
            onPressed: () => setState(() => _creating = true),
          ),
          if (templates.isEmpty) ...[
            Spacing.gapSm,
            Text(
              l10n.meetingTemplatePickerOptionalNote,
              style: AppText.caption.c(colors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.onUse,
    required this.onDelete,
  });

  final MeetingTemplate template;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final parts = [
      _modeLabel(l10n, template.mode),
      _languageLabel(l10n, template.language),
      if (template.participants.isNotEmpty)
        l10n.meetingTemplatePickerParticipantCount(
          template.participants.length,
        ),
      if (template.agenda.isNotEmpty)
        l10n.meetingTemplatePickerAgendaCount(template.agenda.length),
    ];
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  template.name,
                  style: AppText.body.c(colors.text).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  parts.join(' · '),
                  style: AppText.caption.c(colors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.meetingTemplatePickerDelete,
            icon: Icon(AppIcons.close, size: IconSizes.sm, color: colors.textTertiary),
            onPressed: onDelete,
          ),
          AppButton(
            label: l10n.meetingTemplatePickerUse,
            variant: AppButtonVariant.primary,
            onPressed: onUse,
          ),
        ],
      ),
    );
  }
}

/// Minimal creation form: a name, line-per-entry peserta/agenda, a mode
/// choice, and a bahasa choice — the same three bahasa choices
/// `SessionOptionsMenu` offers per-session, so a template can only ever
/// express a setup the app can otherwise reach by hand.
class _TemplateEditorDialog extends ConsumerStatefulWidget {
  const _TemplateEditorDialog({required this.onSaved, required this.onCancel});

  final ValueChanged<MeetingTemplate> onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<_TemplateEditorDialog> createState() =>
      _TemplateEditorDialogState();
}

class _TemplateEditorDialogState
    extends ConsumerState<_TemplateEditorDialog> {
  final _name = TextEditingController();
  final _participants = TextEditingController();
  final _agenda = TextEditingController();
  SessionMode _mode = SessionMode.online;
  String? _language;

  @override
  void dispose() {
    _name.dispose();
    _participants.dispose();
    _agenda.dispose();
    super.dispose();
  }

  List<String> _lines(String text) => text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final canSave = _name.text.trim().isNotEmpty;
    final l10n = context.l10n;
    return AppDialog(
      title: l10n.meetingTemplatePickerNewTitle,
      icon: AppIcons.add,
      actions: [
        AppButton(
          label: l10n.actionCancel,
          variant: AppButtonVariant.ghost,
          onPressed: widget.onCancel,
        ),
        AppButton(
          label: l10n.actionSave,
          variant: AppButtonVariant.primary,
          onPressed: canSave
              ? () {
                  final template = MeetingTemplate(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: _name.text.trim(),
                    participants: _lines(_participants.text),
                    agenda: _lines(_agenda.text),
                    language: _language,
                    mode: _mode,
                  );
                  ref.read(meetingTemplatesProvider.notifier).upsert(template);
                  widget.onSaved(template);
                }
              : null,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _name,
            placeholder: l10n.meetingTemplatePickerNamePlaceholder,
            onChanged: (_) => setState(() {}),
          ),
          Spacing.gapSm,
          AppTextField(
            controller: _participants,
            placeholder: l10n.meetingTemplatePickerParticipantsPlaceholder,
            maxLines: 3,
          ),
          Spacing.gapSm,
          AppTextField(
            controller: _agenda,
            placeholder: l10n.meetingTemplatePickerAgendaPlaceholder,
            maxLines: 3,
          ),
          Spacing.gapSm,
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<SessionMode>(
                  initialValue: _mode,
                  isDense: true,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: l10n.meetingTemplatePickerModeLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final mode in SessionMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(
                          _modeLabel(l10n, mode),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (mode) =>
                      setState(() => _mode = mode ?? _mode),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _language,
                  isDense: true,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: l10n.meetingTemplatePickerLanguageLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.meetingTemplatePickerLanguageAuto),
                    ),
                    DropdownMenuItem(
                      value: 'id',
                      child: Text(l10n.meetingTemplatePickerLanguageIndonesian),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(l10n.meetingTemplatePickerLanguageEnglish),
                    ),
                  ],
                  onChanged: (language) =>
                      setState(() => _language = language),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
