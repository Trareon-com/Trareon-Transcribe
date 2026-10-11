/// F24: "Mulai dari template" — picking (or creating) a meeting setup
/// template before a new session starts.
///
/// Deliberately separate from `notulen_dialog.dart`: that dialog edits the
/// *document* a finished session produces, this one edits the *setup* a
/// session starts with.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

String _modeLabel(SessionMode mode) => switch (mode) {
  SessionMode.webinar => 'Webinar',
  SessionMode.online => 'Rapat online',
  SessionMode.offline => 'Rapat tatap muka',
};

String _languageLabel(String? language) => switch (language) {
  'id' => 'Indonesia',
  'en' => 'Inggris',
  _ => 'Otomatis',
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
      title: 'Mulai dari template',
      icon: AppIcons.event,
      description: templates.isEmpty
          ? 'Belum ada template tersimpan. Buat satu agar judul, peserta, '
                'agenda, bahasa, dan mode rapat yang sering dipakai tidak '
                'perlu diisi ulang setiap kali.'
          : 'Pilih template untuk mengisi judul, mode, dan bahasa sesi '
                'secara otomatis.',
      actions: [
        AppButton(
          label: 'Batal',
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
            label: 'Buat template baru',
            variant: AppButtonVariant.secondary,
            icon: AppIcons.add,
            onPressed: () => setState(() => _creating = true),
          ),
          if (templates.isEmpty) ...[
            Spacing.gapSm,
            Text(
              'Template tidak wajib. "Rapat baru" tetap memulai sesi '
              'kosong seperti biasa.',
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
    final parts = [
      _modeLabel(template.mode),
      _languageLabel(template.language),
      if (template.participants.isNotEmpty)
        '${template.participants.length} peserta',
      if (template.agenda.isNotEmpty) '${template.agenda.length} agenda',
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
            tooltip: 'Hapus template',
            icon: Icon(AppIcons.close, size: IconSizes.sm, color: colors.textTertiary),
            onPressed: onDelete,
          ),
          AppButton(
            label: 'Pakai',
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
    return AppDialog(
      title: 'Template baru',
      icon: AppIcons.add,
      actions: [
        AppButton(
          label: 'Batal',
          variant: AppButtonVariant.ghost,
          onPressed: widget.onCancel,
        ),
        AppButton(
          label: 'Simpan',
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
            placeholder: 'Nama template, mis. "Rapat Mingguan Tim"',
            onChanged: (_) => setState(() {}),
          ),
          Spacing.gapSm,
          AppTextField(
            controller: _participants,
            placeholder: 'Peserta default (satu nama per baris)',
            maxLines: 3,
          ),
          Spacing.gapSm,
          AppTextField(
            controller: _agenda,
            placeholder: 'Agenda default (satu poin per baris)',
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
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Mode',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final mode in SessionMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(
                          _modeLabel(mode),
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
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Bahasa',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Otomatis')),
                    DropdownMenuItem(value: 'id', child: Text('Indonesia')),
                    DropdownMenuItem(value: 'en', child: Text('Inggris')),
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
