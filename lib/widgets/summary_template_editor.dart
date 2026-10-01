/// User-editable summary templates (F8).
///
/// Meetily charges $10/month for six fixed templates; Granola made templates
/// the centre of its product. Both are a prompt and a list of headings, which
/// is cheap to build and expensive to withhold — so this ships free, stored
/// locally with the rest of the settings, and starts from a duplicate of a
/// built-in rather than a blank page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Opens the template manager: list, duplicate, edit, delete.
Future<void> showSummaryTemplateManager(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _TemplateManagerDialog(),
  );
}

class _TemplateManagerDialog extends ConsumerWidget {
  const _TemplateManagerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final templates = settings.summaryTemplates;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: const Text('Template Ringkasan'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buat template sendiri dengan judul bagian dan instruksi Anda. '
                'Disimpan di komputer ini.',
                style: TextStyle(
                  fontSize: FontSizes.caption,
                  color: colors.textTertiary,
                  height: 1.3,
                ),
              ),
              Spacing.gapLg,
              if (templates.isEmpty)
                Text(
                  'Belum ada template buatan sendiri.',
                  style: TextStyle(
                    fontSize: FontSizes.body,
                    color: colors.textSecondary,
                  ),
                )
              else
                for (final template in templates)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(template.name),
                    subtitle: Text(
                      template.headings.isEmpty
                          ? 'Tanpa judul bagian'
                          : template.headings.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: FontSizes.caption,
                        color: colors.textTertiary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ubah ${template.name}',
                          constraints: TouchTarget.constraints,
                          icon: const Icon(Icons.edit_outlined,
                              size: IconSizes.md),
                          onPressed: () async {
                            final edited = await showSummaryTemplateEditor(
                              context,
                              initial: template,
                            );
                            if (edited != null) {
                              await notifier.saveSummaryTemplate(edited);
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Duplikat ${template.name}',
                          constraints: TouchTarget.constraints,
                          icon: const Icon(Icons.copy_outlined,
                              size: IconSizes.md),
                          onPressed: () => notifier.saveSummaryTemplate(
                            CustomSummaryTemplate(
                              id: newTemplateId(),
                              name: '${template.name} (salinan)',
                              instructions: template.instructions,
                              headings: template.headings,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus ${template.name}',
                          constraints: TouchTarget.constraints,
                          icon: Icon(Icons.delete_outline,
                              size: IconSizes.md, color: colors.error),
                          onPressed: () =>
                              notifier.deleteSummaryTemplate(template.id),
                        ),
                      ],
                    ),
                  ),
              Spacing.gapLg,
              Text(
                'Mulai dari template bawaan',
                style: TextStyle(
                  fontSize: FontSizes.caption,
                  fontWeight: FontWeight.w600,
                  color: colors.textTertiary,
                ),
              ),
              Spacing.gapSm,
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  for (final builtin in SummaryTemplate.values)
                    if (builtin != SummaryTemplate.kustom)
                      ActionChip(
                        avatar: const Icon(Icons.add, size: IconSizes.sm),
                        label: Text(summaryTemplateLabel(builtin)),
                        tooltip:
                            'Duplikat "${summaryTemplateLabel(builtin)}" jadi '
                            'template sendiri',
                        onPressed: () async {
                          final headings = await ref
                              .read(rustBridgeProvider)
                              .summaryTemplateHeadings(builtin);
                          if (!context.mounted) return;
                          final created = await showSummaryTemplateEditor(
                            context,
                            initial: CustomSummaryTemplate(
                              id: newTemplateId(),
                              name: '${summaryTemplateLabel(builtin)} (saya)',
                              instructions: '',
                              headings: headings,
                            ),
                          );
                          if (created != null) {
                            await notifier.saveSummaryTemplate(created);
                          }
                        },
                      ),
                  ActionChip(
                    avatar: const Icon(Icons.note_add_outlined,
                        size: IconSizes.sm),
                    label: const Text('Kosong'),
                    tooltip: 'Buat template dari nol',
                    onPressed: () async {
                      final created = await showSummaryTemplateEditor(
                        context,
                        initial: CustomSummaryTemplate(
                          id: newTemplateId(),
                          name: 'Template saya',
                          instructions: '',
                          headings: const [],
                        ),
                      );
                      if (created != null) {
                        await notifier.saveSummaryTemplate(created);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

/// A stable id for a new template. Timestamp-based rather than a hash of the
/// name, so renaming a template does not orphan the sessions that used it.
String newTemplateId() =>
    'tpl-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

/// Edits one template. Returns the edited copy, or `null` on cancel.
Future<CustomSummaryTemplate?> showSummaryTemplateEditor(
  BuildContext context, {
  required CustomSummaryTemplate initial,
}) {
  return showDialog<CustomSummaryTemplate>(
    context: context,
    builder: (_) => _TemplateEditorDialog(initial: initial),
  );
}

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog({required this.initial});

  final CustomSummaryTemplate initial;

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _instructions;
  late final TextEditingController _headings;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _instructions = TextEditingController(text: widget.initial.instructions);
    _headings = TextEditingController(
      text: widget.initial.headings.join('\n'),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    _headings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return AlertDialog(
      backgroundColor: colors.surface,
      title: const Text('Ubah template'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama template',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              Spacing.gapMd,
              TextField(
                controller: _headings,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Judul bagian (satu per baris)',
                  hintText: 'Ringkasan\nKeputusan\nRisiko',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              Spacing.gapMd,
              TextField(
                controller: _instructions,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Instruksi tambahan',
                  hintText: 'mis. Fokus pada risiko anggaran dan sebutkan '
                      'angka persis seperti di transkrip.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              Spacing.gapSm,
              Text(
                'Judul bagian dikirim sebagai daftar berurutan, jadi hasilnya '
                'konsisten dan bisa dipakai untuk mengisi form notulen.',
                style: TextStyle(
                  fontSize: FontSizes.caption,
                  color: colors.textTertiary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              widget.initial.copyWith(
                name: name,
                instructions: _instructions.text.trim(),
                headings: _headings.text
                    .split('\n')
                    .map((h) => h.trim())
                    .where((h) => h.isNotEmpty)
                    .toList(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
