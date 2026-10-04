/// The design-system gallery: every component in the kit, in every state it
/// is specified to have, on one surface.
///
/// Test-only on purpose. A developer screen shipped inside the app is a
/// surface nobody maintains and a user can reach by accident; the gallery's
/// job is to be the subject of a golden, so it lives next to the goldens.
///
/// `docs/DESIGN-SYSTEM.md` §6 is what this renders.
library;

import 'package:flutter/material.dart';

import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/theme/app_icons.dart';
import 'package:transcribe/theme/app_shortcuts.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/theme/app_tokens.dart';
import 'package:transcribe/theme/app_typography.dart';
import 'package:transcribe/widgets/record_button.dart';
import 'package:transcribe/widgets/ui/app_button.dart';
import 'package:transcribe/widgets/ui/app_chip.dart';
import 'package:transcribe/widgets/ui/app_controls.dart';
import 'package:transcribe/widgets/ui/app_dialog.dart';
import 'package:transcribe/widgets/ui/app_feedback.dart';
import 'package:transcribe/widgets/ui/app_field.dart';
import 'package:transcribe/widgets/ui/app_list_row.dart';
import 'package:transcribe/widgets/ui/app_surface.dart';
import 'package:transcribe/widgets/ui/key_hint.dart';

class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  final _search = TextEditingController(text: 'anggaran');
  final _field = TextEditingController(text: 'Rapat Koordinasi Triwulan');
  int _segment = 1;
  bool _toggle = true;
  bool _checked = true;
  int _tab = 0;

  @override
  void dispose() {
    _search.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Komponen', style: AppText.display.c(colors.textStrong)),
            Spacing.gapXl,

            _Section(
              label: 'Tipografi',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Display 28', style: AppText.display.c(colors.text)),
                  Text('Title 20', style: AppText.title.c(colors.text)),
                  Text('Heading 16', style: AppText.heading.c(colors.text)),
                  Text(
                    'Subheading 14',
                    style: AppText.subheading.c(colors.text),
                  ),
                  Text(
                    'Reading 14, kolom bacaan transkrip',
                    style: AppText.reading.c(colors.text),
                  ),
                  Text('Body 13', style: AppText.body.c(colors.text)),
                  Text(
                    'Caption 12',
                    style: AppText.caption.c(colors.textSecondary),
                  ),
                  Text(
                    'Micro 11 · 1234567890',
                    style: AppText.micro.c(colors.textTertiary),
                  ),
                  const AppGroupLabel('Overline 10'),
                  Text('00:41:07', style: AppText.monoTimer.c(colors.text)),
                ],
              ),
            ),

            _Section(
              label: 'Tombol',
              child: Wrap(
                spacing: Spacing.md,
                runSpacing: Spacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton.primary(label: 'Simpan', onPressed: () {}),
                  AppButton(
                    label: 'Ekspor',
                    icon: AppIcons.download,
                    onPressed: () {},
                  ),
                  AppButton.ghost(label: 'Batal', onPressed: () {}),
                  AppButton.danger(
                    label: 'Hapus',
                    icon: AppIcons.delete,
                    onPressed: () {},
                  ),
                  const AppButton.primary(label: 'Nonaktif'),
                  const AppButton.primary(label: 'Memuat', loading: true),
                  AppButton(
                    label: 'Kecil',
                    size: AppButtonSize.sm,
                    onPressed: () {},
                  ),
                  AppButton.primary(
                    label: 'Besar',
                    size: AppButtonSize.lg,
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            _Section(
              label: 'Tombol ikon dan pintasan',
              child: Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppIconButton(
                    icon: AppIcons.settings,
                    tooltip: 'Pengaturan',
                    onPressed: () {},
                  ),
                  AppIconButton(
                    icon: AppIcons.bookmarkAdd,
                    tooltip: 'Tandai',
                    onPressed: () {},
                  ),
                  AppIconButton(
                    icon: AppIcons.delete,
                    tooltip: 'Hapus',
                    danger: true,
                    onPressed: () {},
                  ),
                  AppIconButton(
                    icon: AppIcons.history,
                    tooltip: 'Riwayat',
                    badge: 12,
                    onPressed: () {},
                  ),
                  const AppIconButton(
                    icon: AppIcons.refresh,
                    tooltip: 'Nonaktif',
                  ),
                  KeyHint(AppShortcuts.startStop.shortcut),
                  KeyHint(AppShortcuts.toggleSidebar.shortcut),
                ],
              ),
            ),

            _Section(
              label: 'Masukan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: Measure.hero,
                    child: AppTextField(
                      controller: _field,
                      label: 'Judul sesi',
                      helper: 'Dipakai sebagai nama berkas ekspor.',
                      prefixIcon: AppIcons.edit,
                    ),
                  ),
                  Spacing.gapMd,
                  SizedBox(
                    width: Measure.hero,
                    child: AppTextField(
                      label: 'Folder perpustakaan',
                      placeholder: 'Contoh: ~/TrareonTranscribe',
                      error: 'Folder itu tidak bisa ditulis.',
                      prefixIcon: AppIcons.folder,
                      mono: true,
                    ),
                  ),
                  Spacing.gapMd,
                  SizedBox(
                    width: Measure.sidebar,
                    child: AppSearchField(
                      controller: _search,
                      onChanged: (_) {},
                      placeholder: 'Cari sesi…',
                      shortcut: AppShortcuts.searchSessions.shortcut,
                    ),
                  ),
                ],
              ),
            ),

            _Section(
              label: 'Pilihan',
              child: Wrap(
                spacing: Spacing.lg,
                runSpacing: Spacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppSegmented<int>(
                    selected: _segment,
                    onChanged: (v) => setState(() => _segment = v),
                    segments: const [
                      AppSegment(
                        value: 0,
                        label: 'Rapat Offline',
                        icon: AppIcons.mic,
                      ),
                      AppSegment(
                        value: 1,
                        label: 'Rapat Online',
                        icon: AppIcons.meetingRoom,
                      ),
                      AppSegment(
                        value: 2,
                        label: 'Webinar',
                        icon: AppIcons.systemAudio,
                      ),
                    ],
                  ),
                  AppSwitch(
                    value: _toggle,
                    semanticLabel: 'Mikrofon',
                    onChanged: (v) => setState(() => _toggle = v),
                  ),
                  const AppSwitch(
                    value: false,
                    semanticLabel: 'Nonaktif',
                    enabled: false,
                    onChanged: null,
                  ),
                  AppCheckbox(
                    value: _checked,
                    label: 'Kirim draf notulen ke pimpinan',
                    strikeWhenChecked: true,
                    onChanged: (v) => setState(() => _checked = v),
                  ),
                ],
              ),
            ),

            _Section(
              label: 'Status',
              child: Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const AppChip(label: '41 menit  128 segmen', mono: true),
                  AppFilterChip(
                    label: 'Anggaran',
                    icon: AppIcons.tag,
                    selected: true,
                    onSelected: (_) {},
                  ),
                  AppFilterChip(
                    label: 'Mingguan',
                    icon: AppIcons.tag,
                    selected: false,
                    onSelected: (_) {},
                  ),
                  const AppStatusBadge(
                    label: 'Merekam',
                    status: AppStatus.recording,
                    dot: true,
                  ),
                  const AppStatusBadge(
                    label: 'Ada ringkasan',
                    status: AppStatus.success,
                    icon: AppIcons.shortText,
                  ),
                  const AppStatusBadge(
                    label: 'Ditranskrip ulang',
                    status: AppStatus.info,
                    icon: AppIcons.enhance,
                  ),
                  const AppStatusBadge(
                    label: 'Satu kanal sunyi',
                    status: AppStatus.warning,
                    icon: AppIcons.warning,
                  ),
                  const AppStatusBadge(
                    label: 'Gagal disimpan',
                    status: AppStatus.danger,
                    icon: AppIcons.error,
                  ),
                  const RecordingDot(),
                ],
              ),
            ),

            _Section(
              label: 'Progres',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: Measure.hero,
                    child: const AppLinearProgress(value: 0.62),
                  ),
                  Spacing.gapMd,
                  Row(
                    children: [
                      const AppProgressRing(value: 0.62),
                      Spacing.hMd,
                      const AppProgressRing(size: IconSizes.xl),
                      Spacing.hMd,
                      SizedBox(
                        width: Measure.sidebar,
                        child: LevelMeter(
                          level: 0.48,
                          color: colors.success,
                          semanticLabel: 'Level mikrofon',
                        ),
                      ),
                    ],
                  ),
                  Spacing.gapMd,
                  SizedBox(
                    width: Measure.hero,
                    child: LiveWaveform(level: 0.5, color: colors.primary),
                  ),
                ],
              ),
            ),

            _Section(
              label: 'Tombol rekam',
              child: Wrap(
                spacing: Spacing.md,
                runSpacing: Spacing.md,
                children: [
                  RecordButton(
                    isRecording: false,
                    isPaused: false,
                    onPressed: () {},
                  ),
                  RecordButton(
                    isRecording: true,
                    isPaused: false,
                    onPressed: () {},
                  ),
                  RecordButton(
                    isRecording: true,
                    isPaused: true,
                    onPressed: () {},
                  ),
                  RecordButton(
                    large: true,
                    isRecording: false,
                    isPaused: false,
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            _Section(
              label: 'Permukaan',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: Measure.summaryPanel,
                    child: AppCard(
                      title: 'Rapat Koordinasi Triwulan',
                      subtitle: '4 Oktober 2026 · 41 menit',
                      actions: [
                        AppIconButton(
                          icon: AppIcons.more,
                          tooltip: 'Opsi',
                          size: IconSizes.md,
                          onPressed: () {},
                        ),
                      ],
                      child: Text(
                        'Pembahasan pagu indikatif dan jadwal penyerapan '
                        'triwulan berikutnya.',
                        style: AppText.body.c(colors.textSecondary),
                      ),
                    ),
                  ),
                  Spacing.hLg,
                  Expanded(
                    child: AppSectionCard(
                      title: 'Audio & Suara',
                      description: 'Perangkat yang dipakai saat merekam.',
                      icon: AppIcons.waveform,
                      children: [
                        AppSettingRow(
                          label: 'Lewati jeda sunyi',
                          helper: 'Bagian tanpa suara tidak ikut ditranskrip.',
                          control: AppSwitch(
                            value: true,
                            semanticLabel: 'Lewati jeda sunyi',
                            onChanged: (_) {},
                          ),
                        ),
                        AppSettingRow(
                          label: 'Hapus suara ganda',
                          helper:
                              'Suara yang terdengar di dua kanal '
                              'disatukan.',
                          control: AppSwitch(
                            value: false,
                            semanticLabel: 'Hapus suara ganda',
                            onChanged: (_) {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _Section(
              label: 'Baris daftar',
              child: SizedBox(
                width: Measure.sidebar,
                child: Column(
                  children: [
                    const AppListGroupHeader(label: 'Hari ini'),
                    AppListRow(
                      title: 'Rapat Koordinasi Triwulan',
                      subtitle: 'Selamat pagi, kita mulai dengan pagu…',
                      selected: true,
                      onTap: () {},
                      badges: const [
                        AppChip(label: '41 mnt  128 segmen', mono: true),
                        AppStatusBadge(
                          label: 'Ada ringkasan',
                          status: AppStatus.success,
                        ),
                      ],
                    ),
                    AppListRow(
                      title: 'Evaluasi SPBE',
                      subtitle: 'Terima kasih sudah hadir tepat waktu…',
                      onTap: () {},
                      badges: const [
                        AppChip(label: '18 mnt  52 segmen', mono: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            _Section(
              label: 'Tab, kerangka dan keadaan kosong',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTabs(
                    labels: const ['Transkrip', 'Ringkasan', 'Tindak lanjut'],
                    icons: const [
                      AppIcons.article,
                      AppIcons.shortText,
                      AppIcons.checklist,
                    ],
                    selected: _tab,
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                  Spacing.gapLg,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: Measure.sidebar,
                        child: AppSkeletonList(rows: 3),
                      ),
                      Spacing.hLg,
                      const Expanded(
                        child: SizedBox(
                          height: 220,
                          child: AppEmptyState(
                            icon: AppIcons.searchOff,
                            badgeIcon: AppIcons.search,
                            title: 'Tidak ada yang cocok',
                            message:
                                'Coba kata kunci lain atau lepaskan '
                                'filter tag.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _Section(
              label: 'Skala warna',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Swatches(
                    colors: colors.isDark
                        ? TrareonRamp.darkNeutralScale
                        : TrareonRamp.lightNeutralScale,
                  ),
                  Spacing.gapSm,
                  const _Swatches(colors: TrareonRamp.accentScale),
                  Spacing.gapSm,
                  _Swatches(
                    colors: [
                      colors.success,
                      colors.warning,
                      colors.error,
                      colors.info,
                      colors.recording,
                    ],
                  ),
                  Spacing.gapSm,
                  _Swatches(colors: colors.speakerPalette),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.heading.c(colors.text)),
          Spacing.gapXs,
          AppHairline(color: colors.hairline),
          Spacing.gapMd,
          child,
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final color in colors)
          Container(
            width: Spacing.xxl,
            height: Spacing.xl,
            margin: const EdgeInsets.only(right: Spacing.xs),
            decoration: BoxDecoration(
              color: color,
              borderRadius: Radii.xsAll,
              border: Border.all(color: context.colors.hairline),
            ),
          ),
      ],
    );
  }
}
