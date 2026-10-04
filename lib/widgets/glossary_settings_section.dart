/// Kamus Istilah (F3) — the settings pane for the custom vocabulary.
///
/// Indonesian meetings are full of acronyms Whisper has never heard
/// (`PPBJ`, `SPBE`, `UU PDP`, `Kemenkeu`, `RKAKL`). Listing them here biases
/// Whisper's decoding toward the right spelling and, optionally, repairs
/// near-misses afterwards.
///
/// Two things this pane is careful about:
///
/// * **The prompt budget is visible.** Whisper keeps only 224 prompt tokens
///   and an over-long prompt measurably degrades output, so the pane shows
///   "N dari M istilah dipakai" rather than silently dropping the tail of the
///   user's list.
/// * **Import/export is plain text.** A unit kerja's vocabulary lives in a
///   spreadsheet somewhere; `.txt` and `.csv` both import, and the first
///   column is the term.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/api.dart' as rust_api;
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/atomic_file.dart';
import 'app_toast.dart';
import 'settings_controls.dart';
import '../theme/app_icons.dart';

/// Terms a brand-new install is offered, as chips to tap rather than a
/// prefilled list — a glossary the user did not choose is a glossary they
/// cannot debug. All are from the public-sector vocabulary the blueprint
/// names.
const List<String> kGlossarySuggestions = [
  'PPBJ',
  'SPBE',
  'UU PDP',
  'Kemenkeu',
  'Musrenbang',
  'RKAKL',
  'DIPA',
  'SPPD',
  'e-Katalog',
  'Notulen',
];

class GlossarySettingsSection extends ConsumerStatefulWidget {
  const GlossarySettingsSection({super.key});

  @override
  ConsumerState<GlossarySettingsSection> createState() =>
      _GlossarySettingsSectionState();
}

class _GlossarySettingsSectionState
    extends ConsumerState<GlossarySettingsSection> {
  final _termController = TextEditingController();
  rust_api.GlossaryPromptInfo? _prompt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPrompt());
  }

  @override
  void dispose() {
    _termController.dispose();
    super.dispose();
  }

  /// Asks the engine what the current list would actually send, so the
  /// "N dari M" counter and the preview come from the same code the
  /// transcriber uses rather than a Dart re-implementation of the budget.
  Future<void> _refreshPrompt() async {
    final settings = ref.read(settingsProvider);
    try {
      final info = await ref
          .read(rustBridgeProvider)
          .glossaryPromptPreview(glossary: settings.glossary.toConfig());
      if (mounted) setState(() => _prompt = info);
    } catch (_) {
      // The counter falls back to the plain term count; a preview that cannot
      // be computed must not block editing the list.
      if (mounted) setState(() => _prompt = null);
    }
  }

  Future<void> _addTyped() async {
    final raw = _termController.text.trim();
    if (raw.isEmpty) return;
    // One paste of several lines or a comma-separated list is the common
    // case, so split rather than storing "A, B, C" as one term.
    final terms = raw
        .split(RegExp(r'[,\n;]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty);
    _termController.clear();
    await ref.read(settingsProvider.notifier).setGlossaryTerms([
      ...ref.read(settingsProvider).glossary.terms,
      ...terms,
    ]);
    await _refreshPrompt();
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Impor kamus istilah',
      type: FileType.custom,
      allowedExtensions: const ['txt', 'csv', 'tsv'],
    );
    final path = picked?.files.singleOrNull?.path;
    if (path == null) return;
    try {
      final content = await File(path).readAsString();
      final parsed = await ref
          .read(rustBridgeProvider)
          .parseGlossaryFile(content);
      if (parsed.isEmpty) {
        if (mounted) {
          AppToast.show(
            context,
            'Tidak ada istilah di berkas itu.',
            type: ToastType.error,
          );
        }
        return;
      }
      final before = ref.read(settingsProvider).glossary.terms;
      await ref.read(settingsProvider.notifier).setGlossaryTerms([
        ...before,
        ...parsed,
      ]);
      final added =
          ref.read(settingsProvider).glossary.terms.length - before.length;
      await _refreshPrompt();
      if (mounted) {
        AppToast.show(
          context,
          '$added istilah baru ditambahkan dari ${parsed.length} baris.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Gagal mengimpor: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _export({required bool csv}) async {
    final terms = ref.read(settingsProvider).glossary.terms;
    if (terms.isEmpty) return;
    final extension = csv ? 'csv' : 'txt';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan kamus istilah',
      fileName: 'kamus-istilah.$extension',
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (path == null) return;
    try {
      final content = await ref
          .read(rustBridgeProvider)
          .renderGlossaryFile(terms, csv: csv);
      // Same atomic temp+rename every other persisted file in the app uses:
      // a truncated glossary export is a silently incomplete backup.
      await writeStringAtomic(File(path), content);
      if (mounted) {
        AppToast.show(
          context,
          '${terms.length} istilah diekspor ke $path',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Gagal mengekspor: $e', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final glossary = settings.glossary;
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    final suggestions = kGlossarySuggestions
        .where(
          (s) => !glossary.terms.any((t) => t.toLowerCase() == s.toLowerCase()),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSection(
          title: 'Kamus Istilah',
          children: [
            SettingsSwitch(
              icon: AppIcons.glossary,
              label: 'Pakai kamus istilah',
              subtitle: glossary.enabled
                  ? 'Istilah di bawah dibisikkan ke mesin transkripsi supaya '
                        'singkatan dan nama lembaga tidak salah tulis.'
                  : 'Mesin transkripsi menebak sendiri semua istilah.',
              value: glossary.enabled,
              onChanged: (value) async {
                await notifier.setGlossaryEnabled(value);
                await _refreshPrompt();
              },
            ),
            const SettingsDivider(),
            SettingsSwitch(
              icon: AppIcons.autoFix,
              label: 'Perbaiki ejaan yang mirip',
              subtitle: glossary.postCorrection
                  ? 'Kata yang hampir sama dengan istilah di kamus '
                        'diperbaiki setelah transkripsi. Kata lain tidak '
                        'disentuh.'
                  : 'Hasil transkripsi dibiarkan apa adanya.',
              value: glossary.postCorrection,
              onChanged: notifier.setGlossaryPostCorrection,
            ),
          ],
        ),
        Spacing.gapMd,
        SettingsSection(
          title: 'Daftar Istilah (${glossary.terms.length})',
          children: [
            Padding(
              padding: Spacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _termController,
                          decoration: const InputDecoration(
                            labelText: 'Tambah istilah',
                            hintText: 'mis. PPBJ, Kemenkeu, Pak Budi Santoso',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addTyped(),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      SizedBox(
                        height: TouchTarget.minimum,
                        child: FilledButton.icon(
                          onPressed: _addTyped,
                          icon: const Icon(AppIcons.add, size: IconSizes.md),
                          label: const Text('Tambah'),
                        ),
                      ),
                    ],
                  ),
                  Spacing.gapMd,
                  _PromptBudget(
                    info: _prompt,
                    termCount: glossary.terms.length,
                  ),
                  if (glossary.terms.isNotEmpty) ...[
                    Spacing.gapMd,
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: [
                        for (final term in glossary.terms)
                          Semantics(
                            label: 'Istilah $term',
                            button: true,
                            child: InputChip(
                              label: Text(term),
                              onDeleted: () async {
                                await notifier.removeGlossaryTerm(term);
                                await _refreshPrompt();
                              },
                              deleteButtonTooltipMessage: 'Hapus $term',
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (suggestions.isNotEmpty) ...[
                    Spacing.gapLg,
                    Text(
                      'Saran istilah umum',
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
                        for (final suggestion in suggestions)
                          ActionChip(
                            avatar: const Icon(
                              AppIcons.add,
                              size: IconSizes.sm,
                            ),
                            label: Text(suggestion),
                            tooltip: 'Tambahkan $suggestion ke kamus',
                            onPressed: () async {
                              await notifier.addGlossaryTerm(suggestion);
                              await _refreshPrompt();
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SettingsDivider(),
            Padding(
              padding: Spacing.card,
              child: Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: _import,
                    icon: const Icon(AppIcons.fileUpload, size: IconSizes.md),
                    label: const Text('Impor .txt / .csv'),
                  ),
                  OutlinedButton.icon(
                    onPressed: glossary.terms.isEmpty
                        ? null
                        : () => _export(csv: false),
                    icon: const Icon(AppIcons.fileDownload, size: IconSizes.md),
                    label: const Text('Ekspor .txt'),
                  ),
                  OutlinedButton.icon(
                    onPressed: glossary.terms.isEmpty
                        ? null
                        : () => _export(csv: true),
                    icon: const Icon(AppIcons.table, size: IconSizes.md),
                    label: const Text('Ekspor .csv'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "18 dari 40 istilah dipakai", plus the exact text that would be sent.
class _PromptBudget extends StatelessWidget {
  const _PromptBudget({required this.info, required this.termCount});

  final rust_api.GlossaryPromptInfo? info;
  final int termCount;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    if (termCount == 0) {
      return Text(
        'Belum ada istilah. Tanpa kamus, mesin transkripsi menebak sendiri.',
        style: TextStyle(
          fontSize: FontSizes.caption,
          color: colors.textTertiary,
        ),
      );
    }
    final used = info?.termsUsed ?? termCount;
    final total = info?.termsTotal ?? termCount;
    final overflowing = used < total;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            overflowing ? AppIcons.warning : AppIcons.checkFilled,
            size: IconSizes.sm,
            color: overflowing ? colors.warning : colors.success,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              overflowing
                  ? '$used dari $total istilah dipakai, daftar terlalu '
                        'panjang untuk dibisikkan sekaligus. Istilah paling '
                        'atas yang dibuang; pindahkan yang penting ke atas atau '
                        'kurangi daftarnya.'
                  : 'Semua $total istilah dipakai.',
              style: TextStyle(
                fontSize: FontSizes.caption,
                color: overflowing ? colors.warning : colors.textTertiary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
