/// Notulen Resmi (F2) — the office-level fields, set once per unit kerja.
///
/// The notulen form asks for eleven things the audio cannot supply. Four of
/// them are properties of the office, not of the meeting (instansi, unit
/// kerja, usual room, who the notulis is), so they belong in Settings and get
/// prefilled into every export. The rest stay on the form.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_toast.dart';
import 'settings_controls.dart';

class NotulenDefaultsSection extends ConsumerStatefulWidget {
  const NotulenDefaultsSection({super.key});

  @override
  ConsumerState<NotulenDefaultsSection> createState() =>
      _NotulenDefaultsSectionState();
}

class _NotulenDefaultsSectionState
    extends ConsumerState<NotulenDefaultsSection> {
  late final TextEditingController _unitKerja;
  late final TextEditingController _tempat;
  late final TextEditingController _notulis;

  @override
  void initState() {
    super.initState();
    final notulen = ref.read(settingsProvider).notulen;
    _unitKerja = TextEditingController(text: notulen.unitKerja);
    _tempat = TextEditingController(text: notulen.tempat);
    _notulis = TextEditingController(text: notulen.notulis);
  }

  @override
  void dispose() {
    _unitKerja.dispose();
    _tempat.dispose();
    _notulis.dispose();
    super.dispose();
  }

  /// Saves on focus loss rather than on every keystroke: each write goes
  /// through Rust to the settings file, and a per-character save would mean a
  /// file write per letter typed.
  Future<void> _save() async {
    final current = ref.read(settingsProvider).notulen;
    await ref.read(settingsProvider.notifier).setNotulenDefaults(
          current.copyWith(
            unitKerja: _unitKerja.text.trim(),
            tempat: _tempat.text.trim(),
            notulis: _notulis.text.trim(),
          ),
        );
  }

  Future<void> _pickKopSurat() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pilih gambar kop surat (PNG)',
      type: FileType.custom,
      allowedExtensions: const ['png'],
    );
    final path = picked?.files.singleOrNull?.path;
    if (path == null) return;
    // The DOCX media part is written as a .png, so a JPEG picked through a
    // "All files" dialog would produce a document Word refuses to render.
    // Checking the magic bytes here means the user finds out now, not after
    // emailing the notulen.
    try {
      final head = await File(path).openRead(0, 8).first;
      const pngMagic = [137, 80, 78, 71, 13, 10, 26, 10];
      final isPng = head.length >= 8 &&
          List.generate(8, (i) => head[i]).toString() == pngMagic.toString();
      if (!isPng) {
        if (mounted) {
          AppToast.show(
            context,
            'Kop surat harus berupa berkas PNG.',
            type: ToastType.error,
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Tidak bisa membaca berkas: $e',
            type: ToastType.error);
      }
      return;
    }
    final current = ref.read(settingsProvider).notulen;
    await ref
        .read(settingsProvider.notifier)
        .setNotulenDefaults(current.copyWith(kopSuratPath: path));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notulen = settings.notulen;
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSection(
          title: 'Notulen Resmi',
          children: [
            Padding(
              padding: Spacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Isian yang sama di setiap rapat. Dipakai otomatis saat '
                    'Anda membuat Notulen Rapat.',
                    style: TextStyle(
                      fontSize: FontSizes.caption,
                      color: colors.textTertiary,
                      height: 1.3,
                    ),
                  ),
                  Spacing.gapMd,
                  Focus(
                    onFocusChange: (focused) {
                      if (!focused) _save();
                    },
                    child: Column(
                      children: [
                        TextField(
                          controller: _unitKerja,
                          decoration: const InputDecoration(
                            labelText: 'Instansi / Unit Kerja',
                            hintText: 'mis. Direktorat Jenderal Anggaran',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        Spacing.gapMd,
                        TextField(
                          controller: _tempat,
                          decoration: const InputDecoration(
                            labelText: 'Tempat/Media yang biasa dipakai',
                            hintText: 'mis. Ruang Rapat Lt. 5 / Zoom',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        Spacing.gapMd,
                        TextField(
                          controller: _notulis,
                          decoration: const InputDecoration(
                            labelText: 'Nama notulis',
                            hintText: 'Nama Anda, untuk blok tanda tangan',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Spacing.gapMd,
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined, size: IconSizes.md),
                      label: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.image_outlined,
              label: 'Kop surat',
              subtitle: notulen.kopSuratPath.isEmpty
                  ? 'Belum dipilih. Tanpa gambar, kop ditulis sebagai teks '
                      'dari nama instansi di atas.'
                  : notulen.kopSuratPath,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (notulen.kopSuratPath.isNotEmpty)
                    IconButton(
                      tooltip: 'Hapus kop surat',
                      constraints: TouchTarget.constraints,
                      icon: const Icon(Icons.delete_outline,
                          size: IconSizes.md),
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .setNotulenDefaults(
                            notulen.copyWith(kopSuratPath: ''),
                          ),
                    ),
                  IconButton(
                    tooltip: 'Pilih gambar kop surat',
                    constraints: TouchTarget.constraints,
                    icon: const Icon(Icons.folder_open_outlined,
                        size: IconSizes.md),
                    onPressed: _pickKopSurat,
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
