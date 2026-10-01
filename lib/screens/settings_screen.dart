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
import '../widgets/settings_controls.dart';
import '../widgets/summary_settings_section.dart';
import 'diagnostics_screen.dart';
import 'privacy_report_screen.dart';
import 'setup_wizard_screen.dart';
import 'usage_dashboard_screen.dart';

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
  penyiapan,
  tentang,
}

extension on SettingsCategory {
  String get label => switch (this) {
        SettingsCategory.tampilan => 'Tampilan',
        SettingsCategory.modelMode => 'Model & Mode',
        SettingsCategory.audio => 'Audio & Suara',
        SettingsCategory.kamus => 'Kamus Istilah',
        SettingsCategory.penyimpanan => 'Penyimpanan',
        SettingsCategory.ringkasan => 'Ringkasan AI',
        SettingsCategory.notulen => 'Notulen Resmi',
        SettingsCategory.penyiapan => 'Penyiapan & Diagnostik',
        SettingsCategory.tentang => 'Tentang',
      };

  IconData get icon => switch (this) {
        SettingsCategory.tampilan => Icons.palette_outlined,
        SettingsCategory.modelMode => Icons.psychology_outlined,
        SettingsCategory.audio => Icons.graphic_eq_outlined,
        SettingsCategory.kamus => Icons.menu_book_outlined,
        SettingsCategory.penyimpanan => Icons.folder_outlined,
        SettingsCategory.ringkasan => Icons.auto_awesome_outlined,
        SettingsCategory.notulen => Icons.description_outlined,
        SettingsCategory.penyiapan => Icons.health_and_safety_outlined,
        SettingsCategory.tentang => Icons.info_outlined,
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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final notifier = ref.read(settingsProvider.notifier);
    return Material(
      color: colors.error.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  failure.userMessage,
                  style: TextStyle(color: colors.text, fontSize: 12),
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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      children: [
        for (final category in SettingsCategory.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: category == selected
                  ? colors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelected(category),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        category.icon,
                        size: 18,
                        color: category == selected
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          category.label,
                          style: TextStyle(
                            fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final category in SettingsCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return ListView(
      key: ValueKey(category),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: switch (category) {
        SettingsCategory.tampilan => _tampilan(settings, notifier),
        SettingsCategory.modelMode =>
          _modelMode(context, ref, settings, notifier, colors),
        SettingsCategory.audio => _audio(settings, notifier),
        SettingsCategory.kamus => const [GlossarySettingsSection()],
        SettingsCategory.penyimpanan => _penyimpanan(settings, notifier, colors),
        SettingsCategory.ringkasan => const [
            SettingsSection(
              title: 'Ringkasan AI',
              children: [SummarySettingsSection()],
            ),
          ],
        SettingsCategory.notulen => const [NotulenDefaultsSection()],
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
              icon: Icons.palette_outlined,
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
  ) =>
      [
        SettingsSection(
          title: 'Model & Mode',
          children: [
            SettingsTile(
              icon: Icons.psychology_outlined,
              label: 'Model default',
              subtitle: isModelAvailable(settings.defaultModel,
                      libraryPath: settings.libraryPath)
                  ? 'Tersedia di komputer ini.'
                  : 'Belum diunduh — pilih untuk mengunduhnya.',
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
                  if (isModelAvailable(modelId,
                      libraryPath: settings.libraryPath)) {
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
              icon: Icons.speed_outlined,
              label: 'Progressive Mode',
              subtitle: settings.progressiveEnabled
                  ? 'Mulai cepat → sempurnakan jadi akurat di latar belakang'
                  : 'Gunakan satu model saja (lebih cepat)',
              value: settings.progressiveEnabled,
              onChanged: notifier.setProgressiveEnabled,
            ),
            const SettingsDivider(),
            SettingsSwitch(
              icon: Icons.memory_outlined,
              label: 'Akselerasi GPU',
              subtitle: _gpuSubtitle(settings.gpuEnabled),
              value: settings.gpuEnabled,
              onChanged: notifier.setGpuEnabled,
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.meeting_room_outlined,
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
              icon: Icons.translate_outlined,
              label: 'Bahasa',
              subtitle: settings.language == null
                  ? 'Bahasa dideteksi otomatis per segmen.'
                  : 'Dipaksa ke satu bahasa — lebih akurat kalau rapatnya '
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
        const SizedBox(height: 12),
        SettingsSection(
          title: 'Transkripsi',
          children: [
            SettingsTile(
              icon: Icons.speed_outlined,
              label: 'Perbandingan Kecepatan',
              subtitle:
                  'Bahasa Indonesia: ringan 3s · cepat 10s · akurat 56s per 1 menit audio.\n'
                  'Model akurat disarankan untuk meeting & wawancara.',
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
              icon: Icons.graphic_eq_outlined,
              label: 'VAD (deteksi suara)',
              subtitle: settings.vadEnabled
                  ? 'Jeda sunyi dilewati, jadi transkripsi lebih cepat. '
                      'Berlaku mulai sesi berikutnya.'
                  : 'Semua audio ditranskrip, termasuk jeda sunyi.',
              value: settings.vadEnabled,
              onChanged: notifier.setVadEnabled,
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.spatial_audio_outlined,
              label: 'Echo Dedupe',
              subtitle: settings.defaultMode == SessionMode.online
                  ? 'Aktif di mode Rapat Online: duplikasi MIC/SPK dibuang.'
                  : 'Hanya berlaku di mode Rapat Online.',
              trailing: const InfoBadge(
                message:
                    'Membandingkan kemiripan audio dari mikrofon dan speaker, '
                    'lalu menghapus duplikat.',
              ),
            ),
            const SettingsDivider(),
            SettingsSwitch(
              icon: Icons.timer_outlined,
              label: 'Auto-Stop saat diam',
              subtitle: settings.autoStopMinutes != null
                  ? 'Berhenti setelah ${settings.autoStopMinutes} menit tanpa suara'
                  : 'Rekaman berjalan sampai Anda menghentikannya sendiri.',
              value: settings.autoStopMinutes != null,
              onChanged: (v) => notifier.setAutoStopMinutes(v ? 5 : null),
            ),
            if (settings.autoStopMinutes != null) ...[
              const SettingsDivider(),
              SettingsTile(
                icon: Icons.timer_10_outlined,
                label: 'Durasi diam',
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
  ) =>
      [
        SettingsSection(
          title: 'Output & Penyimpanan',
          children: [
            Builder(
              builder: (context) => SettingsTile(
                icon: Icons.folder_outlined,
                label: 'Folder output',
                subtitle: settings.libraryPath,
                trailing:
                    Icon(Icons.chevron_right, color: colors.textTertiary, size: 18),
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
              icon: Icons.save_alt_outlined,
              label: 'Format ekspor default',
              subtitle: 'Format yang sudah tercentang saat dialog Ekspor dibuka.',
              trailing: CompactDropdown<String>(
                value: settings.defaultExportFormat,
                items: const ['markdown', 'txt', 'json', 'srt', 'vtt', 'html', 'docx'],
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
              icon: Icons.health_and_safety_outlined,
              label: 'Diagnostik',
              subtitle: 'Periksa folder, model, mikrofon dan ruang disk. '
                  'Semuanya lokal.',
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => openDiagnostics(context),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.assistant_direction_outlined,
              label: 'Jalankan Ulang Penyiapan',
              subtitle: 'Pilih ulang mikrofon, pengeras suara dan model, '
                  'lalu uji suara.',
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => openSetupWizard(context),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Laporan Privasi',
              subtitle: 'Apa yang pernah keluar dari komputer ini.',
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PrivacyReportScreen()),
              ),
            ),
            const SettingsDivider(),
            Consumer(
              builder: (context, ref, _) {
                final settings = ref.watch(settingsProvider);
                return SettingsTile(
                  icon: Icons.analytics_outlined,
                  label: 'Dasbor Penggunaan',
                  subtitle: 'Berapa lama Anda merekam, per minggu.',
                  trailing: const Icon(Icons.chevron_right, size: 18),
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
  ) =>
      [
        SettingsSection(
          title: 'Tentang',
          children: [
            SettingsTile(
              icon: Icons.system_update_alt_outlined,
              label: 'Cek Pembaruan',
              subtitle: 'Versi saat ini $kAppVersion. Memeriksa pembaruan '
                  'menghubungi GitHub dan dicatat di Laporan Privasi.',
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _checkForUpdate(context, ref),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.info_outlined,
              label: 'Tentang Trareon',
              subtitle: 'Transkripsi offline, privasi terjamin.',
              trailing: const Icon(Icons.chevron_right, size: 18),
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
        AppToast.show(context, 'Gagal memeriksa pembaruan: $e',
            type: ToastType.error);
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
        Icons.mic,
        size: IconSizes.hero,
        color: Theme.of(context).extension<AppColorSet>()?.primary ??
            AppColors.light.primary,
      ),
      children: [
        const Text('Transkripsi offline, privasi terjamin.'),
        const SizedBox(height: 16),
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
