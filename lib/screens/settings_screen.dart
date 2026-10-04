import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_version.dart';
import '../services/update_checker.dart';
import '../src/rust/api.dart' as rust_api;
import '../state/models.dart';
import '../state/privacy_report_model.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/model_labels.dart';
import '../widgets/app_toast.dart';
import '../widgets/model_download_dialog.dart';
import '../widgets/glossary_settings_section.dart';
import '../widgets/notulen_settings_section.dart';
import '../widgets/pdp_settings_section.dart';
import '../widgets/settings_controls.dart';
import '../widgets/summary_settings_section.dart';
import 'diagnostics_screen.dart';
import 'capabilities_screen.dart';
import 'privacy_report_screen.dart';
import 'setup_wizard_screen.dart';
import 'usage_dashboard_screen.dart';
import '../theme/app_icons.dart';

/// Below this width the category rail becomes a horizontal chip strip.
/// Two panes still fit at the app's 800 px minimum window (232 px rail +
/// 568 px of content); a narrower window than that is a resize in
/// progress, and a rail there would squeeze the content to nothing.
const double kSettingsTwoPaneMinWidth = 640;

enum SettingsCategory {
  tampilan,
  modelMode,
  audio,
  kamus,
  penyimpanan,
  ringkasan,
  notulen,
  kepatuhan,
  penyiapan,
  tentang,
}

/// Named (not anonymous) so tests can enumerate the panes: the text-scaling
/// gate walks every category, and a pane nobody opens is a pane nobody
/// notices is broken.
extension SettingsCategoryLabel on SettingsCategory {
  String get label => switch (this) {
    SettingsCategory.tampilan => 'Tampilan',
    SettingsCategory.modelMode => 'Model & Mode',
    SettingsCategory.audio => 'Audio & Suara',
    SettingsCategory.kamus => 'Kamus Istilah',
    SettingsCategory.penyimpanan => 'Penyimpanan',
    SettingsCategory.ringkasan => 'Ringkasan AI',
    SettingsCategory.notulen => 'Notulen Resmi',
    SettingsCategory.kepatuhan => 'Kepatuhan PDP',
    SettingsCategory.penyiapan => 'Penyiapan & Diagnostik',
    SettingsCategory.tentang => 'Tentang',
  };

  IconData get icon => switch (this) {
    SettingsCategory.tampilan => AppIcons.appearance,
    SettingsCategory.modelMode => AppIcons.model,
    SettingsCategory.audio => AppIcons.waveform,
    SettingsCategory.kamus => AppIcons.glossary,
    SettingsCategory.penyimpanan => AppIcons.folder,
    SettingsCategory.ringkasan => AppIcons.enhance,
    SettingsCategory.notulen => AppIcons.document,
    SettingsCategory.kepatuhan => AppIcons.verifiedUser,
    SettingsCategory.penyiapan => AppIcons.health,
    SettingsCategory.tentang => AppIcons.info,
  };
}

/// Settings, in two panes (blueprint §4.5).
///
/// The old screen was a single ~380 px column inside a full-width window,
/// leaving about 70 % of it empty, with every section stacked into one
/// long scroll. It also swallowed every save error — see
/// [SettingsSaveFailure] — so a setting that did not persist looked
/// exactly like one that did.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsCategory _category = SettingsCategory.tampilan;

  /// What this build can actually do for GPU inference. Read once; it is
  /// a property of the binary, not of the session.
  rust_api.GpuCapability? _gpu;

  @override
  void initState() {
    super.initState();
    _loadGpuCapability();
  }

  Future<void> _loadGpuCapability() async {
    try {
      final capability = await rust_api.gpuCapability();
      if (mounted) setState(() => _gpu = capability);
    } catch (_) {
      // The engine could not be asked; the helper text falls back to the
      // generic wording rather than inventing a backend name.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final failure = ref.watch(settingsSaveFailureProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: colors.headerBackground,
        foregroundColor: colors.text,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (failure != null) _SaveFailureBanner(failure: failure),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= kSettingsTwoPaneMinWidth;
                final content = _CategoryContent(
                  category: _category,
                  gpu: _gpu,
                );
                if (!wide) {
                  return Column(
                    children: [
                      _CategoryChips(
                        selected: _category,
                        onSelected: (c) => setState(() => _category = c),
                      ),
                      Expanded(child: content),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 232,
                      child: _CategoryRail(
                        selected: _category,
                        onSelected: (c) => setState(() => _category = c),
                      ),
                    ),
                    VerticalDivider(width: 1, color: colors.divider),
                    Expanded(child: content),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveFailureBanner extends ConsumerWidget {
  const _SaveFailureBanner({required this.failure});

  final SettingsSaveFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final notifier = ref.read(settingsProvider.notifier);
    return Material(
      color: colors.error.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            Icon(AppIcons.error, color: colors.error, size: IconSizes.md),
            Spacing.hSm,
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  failure.userMessage,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: FontSizes.caption,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                notifier.dismissSaveFailure();
                ref.read(settingsSaveFailureProvider.notifier).state = null;
              },
              child: const Text('Abaikan'),
            ),
            FilledButton(
              onPressed: () => notifier.retryLastSave(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.selected, required this.onSelected});

  final SettingsCategory selected;
  final ValueChanged<SettingsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return ListView(
      padding: const EdgeInsets.symmetric(
        vertical: Spacing.md,
        horizontal: Spacing.sm,
      ),
      children: [
        for (final category in SettingsCategory.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Material(
              color: category == selected
                  ? colors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: () => onSelected(category),
                child: Padding(
                  // 10 rather than 12: the tenth category (Kepatuhan PDP)
                  // pushed the rail past the 600 px minimum window, and a
                  // settings pane you have to scroll a rail to reach is
                  // one people do not find.
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        category.icon,
                        size: IconSizes.md,
                        color: category == selected
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      Spacing.hSm,
                      Expanded(
                        child: Text(
                          category.label,
                          style: TextStyle(
                            fontSize: FontSizes.bodyLarge,
                            fontWeight: category == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: category == selected
                                ? colors.primary
                                : colors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final SettingsCategory selected;
  final ValueChanged<SettingsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        children: [
          for (final category in SettingsCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: ChoiceChip(
                label: Text(category.label),
                selected: category == selected,
                onSelected: (_) => onSelected(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryContent extends ConsumerWidget {
  const _CategoryContent({required this.category, required this.gpu});

  final SettingsCategory category;
  final rust_api.GpuCapability? gpu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return ListView(
      key: ValueKey(category),
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.lg,
        Spacing.lg,
        Spacing.xxxl,
      ),
      children: switch (category) {
        SettingsCategory.tampilan => _tampilan(settings, notifier),
        SettingsCategory.modelMode => _modelMode(
          context,
          ref,
          settings,
          notifier,
          colors,
        ),
        SettingsCategory.audio => _audio(settings, notifier),
        SettingsCategory.kamus => const [GlossarySettingsSection()],
        SettingsCategory.penyimpanan => _penyimpanan(
          settings,
          notifier,
          colors,
        ),
        SettingsCategory.ringkasan => const [
          SettingsSection(
            title: 'Ringkasan AI',
            children: [SummarySettingsSection()],
          ),
        ],
        SettingsCategory.notulen => const [NotulenDefaultsSection()],
        SettingsCategory.kepatuhan => const [PdpSettingsSection()],
        SettingsCategory.penyiapan => _penyiapan(context, ref),
        SettingsCategory.tentang => _tentang(context, ref, colors),
      },
    );
  }

  List<Widget> _tampilan(AppSettings settings, SettingsNotifier notifier) => [
    SettingsSection(
      title: 'Tampilan',
      children: [
        SettingsTile(
          icon: AppIcons.appearance,
          label: 'Tema',
          subtitle: switch (settings.theme) {
            AppThemeMode.system =>
              'Mengikuti tema sistem operasi Anda saat ini.',
            AppThemeMode.light => 'Selalu terang, apa pun tema sistem.',
            AppThemeMode.dark => 'Selalu gelap, apa pun tema sistem.',
          },
          trailing: CompactDropdown<AppThemeMode>(
            value: settings.theme,
            items: AppThemeMode.values,
            labelBuilder: _themeLabel,
            onChanged: notifier.setTheme,
          ),
        ),
      ],
    ),
  ];

  List<Widget> _modelMode(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    SettingsNotifier notifier,
    AppColorSet colors,
  ) => [
    SettingsSection(
      title: 'Model & Mode',
      children: [
        SettingsTile(
          icon: AppIcons.model,
          label: 'Model default',
          subtitle:
              isModelAvailable(
                settings.defaultModel,
                libraryPath: settings.libraryPath,
              )
              ? 'Tersedia di komputer ini.'
              : 'Belum diunduh. Pilih untuk mengunduhnya.',
          // settings.defaultModel can be an older/power-user model
          // (e.g. 'tiny') that's still available on disk but outside
          // the 2-model catalog this dropdown offers — feeding that
          // straight in as `value` trips DropdownButton's "exactly one
          // matching item" assertion. Clamp for display only.
          trailing: CompactDropdown<String>(
            value: kKnownModelIds.contains(settings.defaultModel)
                ? settings.defaultModel
                : kKnownModelIds.first,
            items: kKnownModelIds,
            labelBuilder: modelDisplayLabel,
            onChanged: (modelId) async {
              if (isModelAvailable(
                modelId,
                libraryPath: settings.libraryPath,
              )) {
                await notifier.setDefaultModel(modelId);
                return;
              }
              // This used to tell the user to "Selesaikan Setup Wizard
              // terlebih dahulu" — a wizard with no route into it from
              // anywhere in the app. Offer the download instead.
              final downloaded = await showModelDownloadDialog(
                context: context,
                bridge: ref.read(rustBridgeProvider),
                modelId: modelId,
                modelsDir: resolveTilde(settings.libraryPath),
                displayName: modelDisplayLabel(modelId),
              );
              if (downloaded) await notifier.setDefaultModel(modelId);
            },
          ),
        ),
        const SettingsDivider(),
        SettingsSwitch(
          icon: AppIcons.speed,
          label: 'Cepat dulu, lalu diperhalus',
          subtitle: settings.progressiveEnabled
              ? 'Teks muncul cepat, lalu diperbaiki sendiri dengan model '
                    'yang lebih teliti.'
              : 'Pakai satu model saja. Teks muncul sekali, sudah final.',
          value: settings.progressiveEnabled,
          onChanged: notifier.setProgressiveEnabled,
        ),
        const SettingsDivider(),
        SettingsSwitch(
          icon: AppIcons.chip,
          label: 'Akselerasi GPU',
          subtitle: _gpuSubtitle(settings.gpuEnabled),
          value: settings.gpuEnabled,
          onChanged: notifier.setGpuEnabled,
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.meetingRoom,
          label: 'Mode default',
          subtitle: switch (settings.defaultMode) {
            SessionMode.webinar => 'Mikrofon mati, suara sistem direkam.',
            SessionMode.online => 'Mikrofon dan suara sistem direkam.',
            SessionMode.offline => 'Hanya mikrofon yang direkam.',
          },
          trailing: CompactDropdown<SessionMode>(
            value: settings.defaultMode,
            items: SessionMode.values,
            labelBuilder: (m) => m.label,
            onChanged: notifier.setDefaultMode,
          ),
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.translate,
          label: 'Bahasa',
          subtitle: settings.language == null
              ? 'Bahasa dideteksi otomatis per segmen.'
              : 'Dipaksa ke satu bahasa, lebih akurat kalau rapatnya '
                    'memang satu bahasa.',
          trailing: CompactDropdown<String?>(
            value: settings.language,
            items: const [null, 'id', 'en'],
            labelBuilder: (s) => s == null
                ? 'Deteksi otomatis'
                : (s == 'id' ? 'Indonesia' : 'English'),
            onChanged: notifier.setLanguage,
          ),
        ),
      ],
    ),
    Spacing.gapMd,
    SettingsSection(
      title: 'Transkripsi',
      children: [
        SettingsTile(
          icon: AppIcons.speed,
          label: 'Perbandingan Kecepatan',
          subtitle:
              'Bahasa Indonesia: ringan 3 detik · cepat 10 detik · '
              'akurat 56 detik untuk tiap 1 menit audio.\n'
              'Model akurat disarankan untuk rapat dan wawancara.',
          trailing: const SizedBox.shrink(),
        ),
      ],
    ),
  ];

  /// Says what the machine will actually do, not what the switch is set to.
  String _gpuSubtitle(bool enabled) {
    final capability = gpu;
    if (capability == null) {
      return enabled
          ? 'Akan memakai GPU bila build ini mendukungnya.'
          : 'Transkripsi memakai CPU.';
    }
    if (!capability.available) {
      return 'Build ini dikompilasi tanpa dukungan GPU, jadi transkripsi '
          'tetap memakai CPU meski sakelar ini aktif.';
    }
    return enabled
        ? 'Transkripsi memakai GPU (${capability.backend}).'
        : 'GPU (${capability.backend}) tersedia, tapi transkripsi memakai CPU.';
  }

  List<Widget> _audio(AppSettings settings, SettingsNotifier notifier) => [
    SettingsSection(
      title: 'Audio & Suara',
      children: [
        SettingsSwitch(
          icon: AppIcons.waveform,
          label: 'Abaikan jeda sunyi',
          subtitle: settings.vadEnabled
              ? 'Bagian yang sunyi dilewati, jadi transkripsi lebih cepat. '
                    'Berlaku mulai sesi berikutnya.'
              : 'Semua audio ditranskrip, termasuk bagian yang sunyi.',
          value: settings.vadEnabled,
          onChanged: notifier.setVadEnabled,
        ),
        const SettingsDivider(),
        // F17. Deliberately described as a trade-off rather than an
        // improvement: on already-clean speech it can cost a word,
        // and whether it helps is a property of the room.
        SettingsSwitch(
          icon: AppIcons.noise,
          label: 'Pengurangan derau (RNNoise)',
          subtitle: settings.noiseReduction
              ? 'Derau ruangan (kipas, AC, lalu lintas) ditekan '
                    'sebelum transkripsi. Berlaku mulai potongan audio '
                    'berikutnya.'
              : 'Mati. Nyalakan bila ruangan Anda berisik; pada '
                    'rekaman yang sudah bersih ini bisa menghilangkan '
                    'satu-dua konsonan.',
          value: settings.noiseReduction,
          onChanged: notifier.setNoiseReduction,
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.spatialAudio,
          label: 'Hapus suara ganda',
          subtitle: settings.defaultMode == SessionMode.online
              ? 'Aktif di mode Rapat Online: duplikasi MIC/SPK dibuang.'
              : 'Hanya berlaku di mode Rapat Online.',
          trailing: const InfoBadge(
            message:
                'Membandingkan kemiripan audio dari mikrofon dan '
                'pengeras suara, lalu menghapus yang terdengar dua kali.',
          ),
        ),
        const SettingsDivider(),
        SettingsSwitch(
          icon: AppIcons.timer,
          label: 'Berhenti sendiri saat sunyi',
          subtitle: settings.autoStopMinutes != null
              ? 'Berhenti setelah ${settings.autoStopMinutes} menit tanpa suara.'
              : 'Rekaman berjalan sampai Anda menghentikannya sendiri.',
          value: settings.autoStopMinutes != null,
          onChanged: (v) => notifier.setAutoStopMinutes(v ? 5 : null),
        ),
        if (settings.autoStopMinutes != null) ...[
          const SettingsDivider(),
          SettingsTile(
            icon: AppIcons.timer10,
            label: 'Lama sunyi sebelum berhenti',
            trailing: CompactDropdown<int>(
              value: settings.autoStopMinutes!,
              items: const [1, 2, 3, 5, 10, 15],
              labelBuilder: (m) => '$m menit',
              onChanged: notifier.setAutoStopMinutes,
            ),
          ),
        ],
      ],
    ),
  ];

  List<Widget> _penyimpanan(
    AppSettings settings,
    SettingsNotifier notifier,
    AppColorSet colors,
  ) => [
    SettingsSection(
      title: 'Output & Penyimpanan',
      children: [
        Builder(
          builder: (context) => SettingsTile(
            icon: AppIcons.folder,
            label: 'Folder output',
            subtitle: settings.libraryPath,
            trailing: Icon(
              AppIcons.chevronRight,
              color: colors.textTertiary,
              size: IconSizes.md,
            ),
            onTap: () async {
              final dir = await FilePicker.platform.getDirectoryPath(
                dialogTitle: 'Pilih folder output',
                initialDirectory: settings.libraryPath,
              );
              if (dir != null && dir != settings.libraryPath) {
                await notifier.setLibraryPath(dir);
              }
            },
          ),
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.saveAs,
          label: 'Format ekspor default',
          subtitle: 'Format yang sudah tercentang saat dialog Ekspor dibuka.',
          trailing: CompactDropdown<String>(
            value: settings.defaultExportFormat,
            items: const [
              'markdown',
              'txt',
              'json',
              'srt',
              'vtt',
              'html',
              'docx',
            ],
            labelBuilder: (f) => f,
            onChanged: notifier.setDefaultExportFormat,
          ),
        ),
      ],
    ),
  ];

  List<Widget> _penyiapan(BuildContext context, WidgetRef ref) => [
    SettingsSection(
      title: 'Penyiapan & Diagnostik',
      children: [
        SettingsTile(
          icon: AppIcons.health,
          label: 'Diagnostik',
          subtitle:
              'Periksa folder, model, mikrofon dan ruang disk. '
              'Semuanya lokal.',
          trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
          onTap: () => openDiagnostics(context),
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.guide,
          label: 'Jalankan Ulang Penyiapan',
          subtitle:
              'Pilih ulang mikrofon, pengeras suara dan model, '
              'lalu uji suara.',
          trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
          onTap: () => openSetupWizard(context),
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.privacy,
          label: 'Laporan Privasi',
          subtitle: 'Apa yang pernah keluar dari komputer ini.',
          trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => PrivacyReportScreen()),
          ),
        ),
        const SettingsDivider(),
        // Next to the Privacy Report because they answer two halves
        // of one question: that one is "what has it sent?", this one
        // is "what could it send, and what is on?".
        SettingsTile(
          icon: AppIcons.hierarchy,
          label: 'Apa Jalan di Mana',
          subtitle:
              'Setiap kemampuan, tempatnya berjalan, dan '
              'statusnya sekarang.',
          trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CapabilitiesScreen()),
          ),
        ),
        const SettingsDivider(),
        Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(settingsProvider);
            return SettingsTile(
              icon: AppIcons.analytics,
              label: 'Dasbor Penggunaan',
              subtitle: 'Berapa lama Anda merekam, per minggu.',
              trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  // Without libraryPath the screen can't scan any
                  // session folder and always shows the "belum ada
                  // data" empty state, even with real sessions on disk.
                  builder: (_) => UsageDashboardScreen(
                    libraryPath: resolveTilde(settings.libraryPath),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  ];

  List<Widget> _tentang(
    BuildContext context,
    WidgetRef ref,
    AppColorSet colors,
  ) => [
    SettingsSection(
      title: 'Tentang',
      children: [
        SettingsTile(
          icon: AppIcons.update,
          label: 'Cek Pembaruan',
          subtitle:
              'Versi saat ini $kAppVersion. Memeriksa pembaruan '
              'menghubungi GitHub dan dicatat di Laporan Privasi.',
          trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
          onTap: () => _checkForUpdate(context, ref),
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.info,
          label: 'Tentang Trareon',
          subtitle: 'Transkripsi offline, privasi terjamin.',
          trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
          onTap: () => _showAboutDialog(context),
        ),
      ],
    ),
  ];

  Future<void> _checkForUpdate(BuildContext context, WidgetRef ref) async {
    final privacy = ref.read(privacyReportProvider.notifier);
    final update = UpdateChecker(onNetworkRequest: privacy.recordUpdateCheck);
    // checkForUpdate() throws UpdateCheckException on any network failure
    // (no internet, timeout, DNS, ...); uncaught, the tap did nothing
    // visible at all.
    try {
      final info = await update.checkForUpdate();
      if (!context.mounted) return;
      if (info.isUpdateAvailable) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Pembaruan Tersedia'),
            content: Text(
              'Versi ${info.latestVersion} tersedia (saat ini ${info.currentVersion}).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openReleasePage(
                    context,
                    info.downloadUrl ?? kReleasesUrl,
                    privacy,
                  );
                },
                child: const Text('Lihat Rilis'),
              ),
            ],
          ),
        );
      } else {
        AppToast.show(context, 'Sudah versi terbaru.', type: ToastType.success);
      }
    } on UpdateCheckException catch (e) {
      if (context.mounted) {
        AppToast.show(context, '$e', type: ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Gagal memeriksa pembaruan: $e',
          type: ToastType.error,
        );
      }
    }
  }

  /// Hands the releases page to the system browser. Recorded in the Privacy
  /// Report before the handoff: Trareon opens no socket here, but the user's
  /// machine does, and a report that omitted it would be misleading.
  Future<void> _openReleasePage(
    BuildContext context,
    String url,
    PrivacyReportNotifier privacy,
  ) async {
    privacy.recordExternalLink(url);
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      AppToast.show(
        context,
        'Tidak bisa membuka peramban. Buka $url secara manual.',
        type: ToastType.error,
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Trareon Transcribe',
      applicationVersion: kAppVersion,
      applicationIcon: Icon(
        AppIcons.mic,
        size: IconSizes.hero,
        color:
            Theme.of(context).extension<AppColorSet>()?.primary ??
            AppColors.light.primary,
      ),
      children: [
        const Text('Transkripsi offline, privasi terjamin.'),
        Spacing.gapLg,
        const Text('Dibangun dengan Flutter + Rust'),
      ],
    );
  }
}

String _themeLabel(AppThemeMode mode) => switch (mode) {
  AppThemeMode.light => 'Terang',
  AppThemeMode.dark => 'Gelap',
  AppThemeMode.system => 'Sistem',
};

/// Opens the setup wizard as a full page. It has 935 lines of tested UI and
/// contains the only device picker and audio test in the app; until now
/// nothing in `lib/` imported it (audit A.6-1).
Future<void> openSetupWizard(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (routeContext) => SetupWizardScreen(
        onFinished: () => Navigator.of(routeContext).pop(),
        onCancel: () => Navigator.of(routeContext).pop(),
      ),
    ),
  );
}
