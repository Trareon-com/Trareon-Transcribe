/// Mode Kepatuhan UU PDP (F13) — the settings pane.
///
/// Four duties from UU No. 27/2022, one pane:
///
/// * **Penyamaran** — which categories of personal data to mask on export,
///   plus the names only this user can know about. Masking happens on a
///   copy; the stored transcript is never rewritten.
/// * **Retensi** — separate limits for audio and transcript, previewed
///   and confirmed before anything is deleted. Never automatic.
/// * **Log audit** — the local, append-only record, viewable and
///   exportable as CSV.
/// * **Pemberitahuan** — the sentence the notulis pastes into the meeting
///   chat before pressing record.
///
/// The master switch is the point: with it off nothing here changes what
/// the app does. A compliance mode that quietly started deleting
/// recordings after an update would be a worse problem than the one it
/// solves.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../src/rust/api.dart' as rust_api;
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_toast.dart';
import 'audit_log_view.dart';
import 'settings_controls.dart';
import '../theme/app_icons.dart';
import '../utils/file_dialogs.dart';

/// Retention periods offered, in days. `0` is "simpan selamanya" and must
/// stay the default — the switch that deletes a user's recordings is not
/// one to turn on for them.
const List<int> kRetentionChoices = [0, 7, 30, 90, 180, 365, 730];

/// [l10n] defaults to [currentL10n] so the label can be computed without a
/// `BuildContext`; widgets pass `context.l10n`.
String retentionLabel(int days, [AppLocalizations? l10n]) {
  final strings = l10n ?? currentL10n;
  return switch (days) {
    0 => strings.pdpSettingsSectionRetentionForever,
    90 => strings.pdpSettingsSectionRetentionDaysMonths(90, 3),
    180 => strings.pdpSettingsSectionRetentionDaysMonths(180, 6),
    365 => strings.pdpSettingsSectionRetentionYears(1),
    730 => strings.pdpSettingsSectionRetentionYears(2),
    _ => strings.pdpSettingsSectionRetentionDays(days),
  };
}

class PdpSettingsSection extends ConsumerStatefulWidget {
  const PdpSettingsSection({super.key});

  @override
  ConsumerState<PdpSettingsSection> createState() => _PdpSettingsSectionState();
}

class _PdpSettingsSectionState extends ConsumerState<PdpSettingsSection> {
  final _nameController = TextEditingController();
  late final TextEditingController _consentController;
  String _defaultNotice = '';

  @override
  void initState() {
    super.initState();
    _consentController = TextEditingController(
      text: ref.read(settingsProvider).pdp.consentText,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDefaultNotice());
  }

  Future<void> _loadDefaultNotice() async {
    try {
      final text = await rust_api.defaultConsentNotice();
      if (mounted) setState(() => _defaultNotice = text);
    } catch (_) {
      // The placeholder is cosmetic; the engine supplies the real text at
      // use time either way.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _consentController.dispose();
    super.dispose();
  }

  PdpSettings get _pdp => ref.read(settingsProvider).pdp;

  void _update(PdpSettings next) {
    ref.read(settingsProvider.notifier).setPdp(next);
  }

  @override
  Widget build(BuildContext context) {
    final pdp = ref.watch(settingsProvider).pdp;
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSection(
          title: l10n.pdpSettingsSectionTitle,
          children: [
            SettingsSwitch(
              icon: AppIcons.verifiedUser,
              label: l10n.pdpSettingsSectionEnable,
              subtitle: l10n.pdpSettingsSectionEnableSubtitle,
              value: pdp.enabled,
              onChanged: (value) => _update(_pdp.copyWith(enabled: value)),
            ),
          ],
        ),
        if (pdp.enabled) ...[
          Spacing.gapMd,
          _redactionSection(pdp, colors),
          Spacing.gapMd,
          _retentionSection(pdp, colors),
          Spacing.gapMd,
          _consentSection(pdp, colors),
          Spacing.gapMd,
          _auditSection(colors),
        ],
      ],
    );
  }

  // ── Penyamaran ────────────────────────────────────────────────────────

  Widget _redactionSection(PdpSettings pdp, AppColorSet colors) {
    final redaction = pdp.redaction;
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.pdpSettingsSectionRedactionTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.md,
            Spacing.lg,
            Spacing.xs,
          ),
          child: Text(
            l10n.pdpSettingsSectionRedactionIntro,
            style: TextStyle(
              fontSize: FontSizes.caption,
              color: colors.textTertiary,
              height: 1.4,
            ),
          ),
        ),
        for (final entry
            in <(String, String, bool, RedactionConfig Function(bool))>[
              (
                l10n.pdpSettingsSectionNik,
                l10n.pdpSettingsSectionNikHint,
                redaction.nik,
                (v) => redaction.copyWith(nik: v),
              ),
              (
                l10n.pdpSettingsSectionNpwp,
                l10n.pdpSettingsSectionNpwpHint,
                redaction.npwp,
                (v) => redaction.copyWith(npwp: v),
              ),
              (
                l10n.pdpSettingsSectionPhone,
                l10n.pdpSettingsSectionPhoneHint,
                redaction.phone,
                (v) => redaction.copyWith(phone: v),
              ),
              (
                l10n.pdpSettingsSectionEmail,
                l10n.pdpSettingsSectionEmailHint,
                redaction.email,
                (v) => redaction.copyWith(email: v),
              ),
              (
                l10n.pdpSettingsSectionBankAccount,
                l10n.pdpSettingsSectionBankAccountHint,
                redaction.bankAccount,
                (v) => redaction.copyWith(bankAccount: v),
              ),
            ])
          CheckboxListTile(
            dense: true,
            value: entry.$3,
            onChanged: (value) =>
                _update(_pdp.copyWith(redaction: entry.$4(value ?? false))),
            title: Text(
              entry.$1,
              style: TextStyle(
                fontSize: FontSizes.bodyLarge,
                color: colors.text,
              ),
            ),
            subtitle: Text(
              entry.$2,
              style: TextStyle(
                fontSize: FontSizes.micro,
                color: colors.textTertiary,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        const SettingsDivider(),
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pdpSettingsSectionNamesTitle,
                style: TextStyle(
                  fontSize: FontSizes.bodyLarge,
                  fontWeight: FontWeight.w500,
                  color: colors.text,
                ),
              ),
              Spacing.gapXs,
              Text(
                l10n.pdpSettingsSectionNamesIntro,
                style: TextStyle(
                  fontSize: FontSizes.micro,
                  color: colors.textTertiary,
                ),
              ),
              Spacing.gapSm,
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText: l10n.pdpSettingsSectionNameHint,
                      ),
                      onSubmitted: (_) => _addName(),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  FilledButton(
                    onPressed: _addName,
                    child: Text(l10n.pdpSettingsSectionAdd),
                  ),
                ],
              ),
              if (redaction.names.isNotEmpty) ...[
                Spacing.gapSm,
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: [
                    for (final name in redaction.names)
                      Chip(
                        label: Text(name),
                        onDeleted: () => _update(
                          _pdp.copyWith(
                            redaction: redaction.copyWith(
                              names: [
                                for (final other in redaction.names)
                                  if (other != name) other,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _addName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final existing = _pdp.redaction.names;
    if (existing.any((other) => other.toLowerCase() == name.toLowerCase())) {
      _nameController.clear();
      return;
    }
    _update(
      _pdp.copyWith(
        redaction: _pdp.redaction.copyWith(names: [...existing, name]),
      ),
    );
    _nameController.clear();
  }

  // ── Retensi ───────────────────────────────────────────────────────────

  Widget _retentionSection(PdpSettings pdp, AppColorSet colors) {
    final retention = pdp.retention;
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.pdpSettingsSectionRetentionTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.md,
            Spacing.lg,
            Spacing.xs,
          ),
          child: Text(
            l10n.pdpSettingsSectionRetentionIntro,
            style: TextStyle(
              fontSize: FontSizes.caption,
              color: colors.textTertiary,
              height: 1.4,
            ),
          ),
        ),
        _retentionDropdown(
          label: l10n.pdpSettingsSectionDeleteAudioAfter,
          value: retention.audioDays,
          colors: colors,
          onChanged: (days) => _update(
            _pdp.copyWith(retention: retention.copyWith(audioDays: days)),
          ),
        ),
        _retentionDropdown(
          label: l10n.pdpSettingsSectionDeleteTranscriptAfter,
          value: retention.transcriptDays,
          colors: colors,
          onChanged: (days) => _update(
            _pdp.copyWith(retention: retention.copyWith(transcriptDays: days)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.lg,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed:
                  retention.audioDays == 0 && retention.transcriptDays == 0
                  ? null
                  : _previewRetention,
              icon: const Icon(AppIcons.factCheck, size: IconSizes.md),
              label: Text(l10n.pdpSettingsSectionPreviewRetention),
            ),
          ),
        ),
      ],
    );
  }

  Widget _retentionDropdown({
    required String label,
    required int value,
    required AppColorSet colors,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: FontSizes.bodyLarge,
                color: colors.text,
              ),
            ),
          ),
          DropdownButton<int>(
            value: kRetentionChoices.contains(value) ? value : 0,
            items: [
              for (final days in kRetentionChoices)
                DropdownMenuItem(
                  value: days,
                  child: Text(retentionLabel(days, context.l10n)),
                ),
            ],
            onChanged: (days) => onChanged(days ?? 0),
          ),
        ],
      ),
    );
  }

  Future<void> _previewRetention() async {
    final settings = ref.read(settingsProvider);
    try {
      final plan = await rust_api.previewRetention(
        libraryPath: resolveTilde(settings.libraryPath),
        policy: settings.pdp.retention,
      );
      if (!mounted) return;
      final summary = await rust_api.describeRetentionPlan(plan: plan);
      if (!mounted) return;
      final items = [...plan.sessionsToDelete, ...plan.audioToDelete];
      if (items.isEmpty) {
        AppToast.show(context, summary);
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.pdpSettingsSectionRetentionDialogTitle),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary),
                const SizedBox(height: Spacing.md),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in plan.sessionsToDelete)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            AppIcons.folderDelete,
                            size: IconSizes.md,
                          ),
                          title: Text(item.title),
                          subtitle: Text(
                            context.l10n.pdpSettingsSectionWholeSessionAge(
                              item.ageDays,
                            ),
                          ),
                        ),
                      for (final item in plan.audioToDelete)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            AppIcons.audioTrack,
                            size: IconSizes.md,
                          ),
                          title: Text(item.title),
                          subtitle: Text(
                            context.l10n.pdpSettingsSectionAudioOnlyAge(
                              item.ageDays,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  context.l10n.pdpSettingsSectionCannotUndo,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.pdpSettingsSectionDeleteNow),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final outcome = await rust_api.applyRetention(plan: plan);
      if (!mounted) return;
      AppToast.show(
        context,
        outcome.failed.isEmpty
            ? context.l10n.pdpSettingsSectionRetentionApplied(
                outcome.deleted.length,
              )
            : context.l10n.pdpSettingsSectionRetentionPartial(
                outcome.deleted.length,
                outcome.failed.length,
              ),
        type: outcome.failed.isEmpty ? ToastType.success : ToastType.error,
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          context.l10n.pdpSettingsSectionRetentionPreviewFailed('$e'),
          type: ToastType.error,
        );
      }
    }
  }

  // ── Pemberitahuan ────────────────────────────────────────────────────

  Widget _consentSection(PdpSettings pdp, AppColorSet colors) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.pdpSettingsSectionConsentTitle,
      children: [
        SettingsSwitch(
          icon: AppIcons.announce,
          label: l10n.pdpSettingsSectionConsentReminder,
          subtitle: l10n.pdpSettingsSectionConsentReminderSubtitle,
          value: pdp.consentReminder,
          onChanged: (value) => _update(_pdp.copyWith(consentReminder: value)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _consentController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: l10n.pdpSettingsSectionConsentTextLabel,
                  hintText: _defaultNotice,
                  // The tokens are what the engine substitutes, so they stay
                  // literal in every language.
                  helperText: l10n.pdpSettingsSectionConsentTextHelper(
                    '{judul}',
                    '{tanggal}',
                  ),
                  helperMaxLines: 2,
                ),
                onChanged: (text) => _update(_pdp.copyWith(consentText: text)),
              ),
              Spacing.gapSm,
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _copyNotice,
                  icon: const Icon(AppIcons.copy, size: IconSizes.md),
                  label: Text(l10n.pdpSettingsSectionCopyNotice),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copyNotice() async {
    try {
      final now = DateTime.now();
      final text = await rust_api.consentNoticeText(
        template: _pdp.consentText,
        title: 'rapat ini',
        date: '${now.day}/${now.month}/${now.year}',
      );
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        AppToast.show(context, context.l10n.pdpSettingsSectionNoticeCopied);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          context.l10n.pdpSettingsSectionCopyFailed('$e'),
          type: ToastType.error,
        );
      }
    }
  }

  // ── Log audit ────────────────────────────────────────────────────────

  Widget _auditSection(AppColorSet colors) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.pdpSettingsSectionAuditTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.md,
            Spacing.lg,
            Spacing.xs,
          ),
          child: Text(
            l10n.pdpSettingsSectionAuditIntro,
            style: TextStyle(
              fontSize: FontSizes.caption,
              color: colors.textTertiary,
              height: 1.4,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.xs,
            Spacing.lg,
            Spacing.lg,
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => showAuditLogDialog(context),
                icon: const Icon(AppIcons.history, size: IconSizes.md),
                label: Text(l10n.pdpSettingsSectionViewLog),
              ),
              const SizedBox(width: Spacing.sm),
              OutlinedButton.icon(
                onPressed: _exportAuditLog,
                icon: const Icon(AppIcons.download, size: IconSizes.md),
                label: Text(l10n.pdpSettingsSectionExportCsv),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportAuditLog() async {
    final directory = await pickDirectoryPath(
      dialogTitle: context.l10n.pdpSettingsSectionSaveAuditDialogTitle,
    );
    if (directory == null || !mounted) return;
    try {
      final path = await rust_api.exportAuditLog(
        destination: '$directory/log-audit-trareon.csv',
      );
      if (mounted) {
        AppToast.show(context, context.l10n.pdpSettingsSectionAuditSaved(path));
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          context.l10n.pdpSettingsSectionAuditExportFailed('$e'),
          type: ToastType.error,
        );
      }
    }
  }
}
