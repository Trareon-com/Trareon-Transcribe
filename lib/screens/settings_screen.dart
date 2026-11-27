import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:url_launcher/url_launcher.dart';

import '../app_version.dart';
import '../services/bridge_service.dart';
import '../services/update_checker.dart';
import '../src/rust/api.dart' as rust_api;
import '../state/enhance_queue_model.dart' show kAccurateModelId;
import '../state/models.dart';
import '../state/quality_profile.dart';
import '../state/privacy_report_model.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/model_labels.dart';
import '../utils/system_specs.dart';
import '../widgets/app_toast.dart';
import '../widgets/model_download_dialog.dart';
import '../widgets/glossary_settings_section.dart';
import '../widgets/notulen_settings_section.dart';
import '../widgets/engine_assets_section.dart';
import '../widgets/pdp_settings_section.dart';
import '../widgets/settings_controls.dart';
import '../widgets/summary_settings_section.dart';
import 'diagnostics_screen.dart';
import 'capabilities_screen.dart';
import 'privacy_report_screen.dart';
import 'setup_wizard_screen.dart';
import 'usage_dashboard_screen.dart';
import '../theme/app_icons.dart';
import '../l10n/l10n.dart';
import '../utils/file_dialogs.dart';

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
  /// Context-free so tests can enumerate it; follows [currentL10n].
  String get label => switch (this) {
    SettingsCategory.tampilan => currentL10n.settingsScreenCategoryAppearance,
    SettingsCategory.modelMode => currentL10n.settingsScreenCategoryModelMode,
    SettingsCategory.audio => currentL10n.settingsScreenCategoryAudio,
    SettingsCategory.kamus => currentL10n.settingsScreenCategoryGlossary,
    SettingsCategory.penyimpanan => currentL10n.settingsScreenCategoryStorage,
    SettingsCategory.ringkasan => currentL10n.settingsScreenCategorySummary,
    SettingsCategory.notulen => currentL10n.settingsScreenCategoryMinutes,
    SettingsCategory.kepatuhan => currentL10n.settingsScreenCategoryCompliance,
    SettingsCategory.penyiapan => currentL10n.settingsScreenCategorySetup,
    SettingsCategory.tentang => currentL10n.settingsScreenCategoryAbout,
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
        title: Text(context.l10n.settingsScreenTitle),
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
              child: Text(context.l10n.settingsScreenDismiss),
            ),
            FilledButton(
              onPressed: () => notifier.retryLastSave(),
              child: Text(context.l10n.settingsScreenRetry),
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

/// Whether the advanced rows are unfolded.
///
/// Session-scoped UI state, not a preference: Mode Sederhana has to be the
/// resting state on every visit, otherwise "simple" only applies until
/// someone reopens Pengaturan (blueprint §8.1).
final settingsAdvancedOpenProvider = StateProvider<bool>((ref) => false);

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

    // Capped and centred, the way macOS System Settings and Linear both do
    // it. A full-bleed settings pane on a 1920 px display puts a toggle a
    // metre from the label it belongs to.
    return ListView(
      key: ValueKey(category),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Measure.settingsPane),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Spacing.gapLg,
                ..._rows(context, ref, settings, notifier, colors),
                Spacing.gapXxl,
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _rows(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    SettingsNotifier notifier,
    AppColorSet colors,
  ) {
    return switch (category) {
      SettingsCategory.tampilan => _tampilan(context, settings, notifier),
      SettingsCategory.modelMode => _modelMode(
        context,
        ref,
        settings,
        notifier,
        colors,
      ),
      SettingsCategory.audio => _audio(context, settings, notifier, ref),
      SettingsCategory.kamus => const [GlossarySettingsSection()],
      SettingsCategory.penyimpanan => _penyimpanan(
        context,
        settings,
        notifier,
        colors,
      ),
      SettingsCategory.ringkasan => [
        SettingsSection(
          title: context.l10n.settingsScreenCategorySummary,
          children: const [SummarySettingsSection()],
        ),
      ],
      SettingsCategory.notulen => const [NotulenDefaultsSection()],
      SettingsCategory.kepatuhan => const [PdpSettingsSection()],
      SettingsCategory.penyiapan => _penyiapan(context, ref),
      SettingsCategory.tentang => _tentang(context, ref, colors),
    };
  }

  List<Widget> _tampilan(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) => [
    SettingsSection(
      title: context.l10n.settingsScreenCategoryAppearance,
      children: [
        SettingsTile(
          icon: AppIcons.appearance,
          label: context.l10n.settingsScreenTheme,
          subtitle: switch (settings.theme) {
            AppThemeMode.system =>
              context.l10n.settingsScreenThemeSystemSubtitle,
            AppThemeMode.light => context.l10n.settingsScreenThemeLightSubtitle,
            AppThemeMode.dark => context.l10n.settingsScreenThemeDarkSubtitle,
          },
          trailing: CompactDropdown<AppThemeMode>(
            value: settings.theme,
            items: AppThemeMode.values,
            labelBuilder: (mode) => _themeLabel(context, mode),
            onChanged: notifier.setTheme,
          ),
        ),
        SettingsTile(
          icon: AppIcons.language,
          label: context.l10n.languageLabel,
          subtitle: context.l10n.languageSubtitle,
          trailing: CompactDropdown<UiLanguage>(
            value: settings.uiLanguage,
            items: UiLanguage.values,
            labelBuilder: (language) => switch (language) {
              UiLanguage.system => context.l10n.languageSystem,
              UiLanguage.indonesian => context.l10n.languageIndonesian,
              UiLanguage.english => context.l10n.languageEnglish,
            },
            onChanged: notifier.setUiLanguage,
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
  ) {
    final advancedOpen = ref.watch(settingsAdvancedOpenProvider);
    return [
    SettingsSection(
      title: context.l10n.settingsScreenCategoryModelMode,
      children: [
        SettingsSwitch(
          icon: AppIcons.tune,
          label: context.l10n.settingsScreenSimpleMode,
          subtitle: settings.simpleMode
              ? context.l10n.settingsScreenSimpleModeOnSubtitle
              : context.l10n.settingsScreenSimpleModeOffSubtitle,
          value: settings.simpleMode,
          onChanged: notifier.setSimpleMode,
        ),
        const SettingsDivider(),
        // "Otomatis" has to be legible, not a black box: this row is the
        // resolver's own words for the current session's audio tuning.
        SettingsTile(
          icon: AppIcons.autoFix,
          label: context.l10n.settingsScreenAutoAudioTuning,
          subtitle: settings.autoAudioTuning
              ? _audioDecisionSubtitle(context, settings)
              : context.l10n.settingsScreenAutoAudioTuningOffSubtitle,
          trailing: TextButton(
            onPressed: settings.autoAudioTuning
                ? () {
                    notifier.setAutoAudioTuning(false);
                    ref.read(settingsAdvancedOpenProvider.notifier).state =
                        true;
                  }
                : () => notifier.setAutoAudioTuning(true),
            child: Text(
              settings.autoAudioTuning
                  ? context.l10n.settingsScreenChangeManually
                  : context.l10n.settingsScreenUseAutomatic,
            ),
          ),
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.model,
          label: context.l10n.settingsScreenDefaultModel,
          subtitle:
              isModelAvailable(
                settings.defaultModel,
                libraryPath: settings.libraryPath,
              )
              ? context.l10n.settingsScreenModelAvailable
              : context.l10n.settingsScreenModelNotDownloaded,
          // settings.defaultModel can be an older/power-user model
          // (e.g. 'tiny') that's still available on disk but outside
          // the kKnownModelIds catalog this dropdown offers (currently
          // 5 tiers: base/small/large-v3-turbo-q5/qwen3-asr-0.6b/
          // qwen3-asr-1.7b) — feeding that straight in as `value` trips
          // DropdownButton's "exactly one matching item" assertion.
          // Clamp for display only.
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
        _ModelAccuracyAndUpgradeRow(settings: settings, notifier: notifier),
        if (!settings.simpleMode || advancedOpen) ...[
        const SettingsDivider(),
        SettingsSwitch(
          icon: AppIcons.speed,
          label: context.l10n.settingsScreenProgressive,
          subtitle: settings.progressiveEnabled
              ? context.l10n.settingsScreenProgressiveOnSubtitle
              : context.l10n.settingsScreenProgressiveOffSubtitle,
          value: settings.progressiveEnabled,
          onChanged: notifier.setProgressiveEnabled,
        ),
        const SettingsDivider(),
        // F5. Off by default: a background pass that silently rewrites a
        // finished transcript is a surprise the user did not ask for.
        SettingsSwitch(
          icon: AppIcons.autoFix,
          label: context.l10n.settingsScreenAutoRetranscribe,
          subtitle: !isModelAvailable(
            kAccurateModelId,
            libraryPath: settings.libraryPath,
          )
              ? context.l10n.settingsScreenAutoRetranscribeMissingSubtitle
              : (settings.autoRetranscribe ?? false)
              ? context.l10n.settingsScreenAutoRetranscribeOnSubtitle
              : context.l10n.settingsScreenAutoRetranscribeOffSubtitle,
          value: settings.autoRetranscribe ?? false,
          onChanged: notifier.setAutoRetranscribe,
        ),
        ],
        if (!settings.simpleMode || advancedOpen) ...[
        const SettingsDivider(),
        SettingsSwitch(
          icon: AppIcons.chip,
          label: context.l10n.settingsScreenGpu,
          subtitle: _gpuSubtitle(context, settings.gpuEnabled),
          value: settings.gpuEnabled,
          onChanged: notifier.setGpuEnabled,
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.meetingRoom,
          label: context.l10n.settingsScreenDefaultMode,
          subtitle: switch (settings.defaultMode) {
            SessionMode.webinar =>
              context.l10n.settingsScreenModeWebinarSubtitle,
            SessionMode.online => context.l10n.settingsScreenModeOnlineSubtitle,
            SessionMode.offline =>
              context.l10n.settingsScreenModeOfflineSubtitle,
          },
          trailing: CompactDropdown<SessionMode>(
            value: settings.defaultMode,
            items: SessionMode.values,
            labelBuilder: (m) => m.label,
            onChanged: notifier.setDefaultMode,
          ),
        ),
        ],
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.translate,
          label: context.l10n.settingsScreenTranscriptionLanguage,
          subtitle: settings.language == null
              ? context.l10n.settingsScreenLanguageAutoSubtitle
              : context.l10n.settingsScreenLanguageForcedSubtitle,
          trailing: CompactDropdown<String?>(
            value: settings.language,
            items: const [null, 'id', 'en'],
            labelBuilder: (s) => s == null
                ? context.l10n.settingsScreenLanguageAuto
                : (s == 'id'
                      ? context.l10n.settingsScreenLanguageIndonesian
                      : context.l10n.languageEnglish),
            onChanged: notifier.setLanguage,
          ),
        ),
        if (settings.simpleMode) ...[
          const SettingsDivider(),
          SettingsTile(
            icon: advancedOpen ? AppIcons.expandLess : AppIcons.expandMore,
            label: advancedOpen
                ? context.l10n.settingsScreenHideAdvanced
                : context.l10n.settingsScreenShowAdvanced,
            subtitle: context.l10n.settingsScreenAdvancedSubtitle,
            trailing: const SizedBox.shrink(),
            onTap: () => ref.read(settingsAdvancedOpenProvider.notifier).state =
                !advancedOpen,
          ),
        ],
      ],
    ),
    Spacing.gapMd,
    SettingsSection(
      title: context.l10n.settingsScreenTranscription,
      children: [
        SettingsTile(
          icon: AppIcons.speed,
          label: context.l10n.settingsScreenSpeedComparison,
          subtitle: context.l10n.settingsScreenSpeedComparisonSubtitle,
          trailing: const SizedBox.shrink(),
        ),
      ],
    ),
    ];
  }

  /// The resolver's own words for the audio tuning this build will use.
  ///
  /// No measurement is wired yet (blueprint §5, fase 2), so the honest answer
  /// is the conservative branch. Saying that out loud is better than implying
  /// the app already listened to the room.
  String _audioDecisionSubtitle(BuildContext context, AppSettings settings) {
    final profile = resolveQualityProfile(
      measurement: null,
      gpuAvailable: gpu?.available ?? false,
      refineModelInstalled: settings.progressiveEnabled,
      tuningSource: TuningSource.auto,
      userNoiseReduction: settings.noiseReduction,
      userAgc: settings.agcEnabled,
      userVad: settings.vadEnabled,
    );
    final l10n = context.l10n;
    final on = l10n.settingsScreenStateOn;
    final off = l10n.settingsScreenStateOff;
    final nr = settings.noiseReduction ? on : off;
    final agc = settings.agcEnabled ? on : off;
    return l10n.settingsScreenAudioDecision(profile.reason, nr, agc);
  }

  /// Says what the machine will actually do, not what the switch is set to.
  String _gpuSubtitle(BuildContext context, bool enabled) {
    final l10n = context.l10n;
    final capability = gpu;
    if (capability == null) {
      return enabled
          ? l10n.settingsScreenGpuUnknownOnSubtitle
          : l10n.settingsScreenGpuCpuSubtitle;
    }
    if (!capability.available) {
      return l10n.settingsScreenGpuNotCompiledSubtitle;
    }
    return enabled
        ? l10n.settingsScreenGpuOnSubtitle(capability.backend)
        : l10n.settingsScreenGpuAvailableOffSubtitle(capability.backend);
  }

  List<Widget> _audio(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
    WidgetRef ref,
  ) {
    final advancedOpen = ref.watch(settingsAdvancedOpenProvider);
    final folded = settings.simpleMode && !advancedOpen;
    return [
    // The downloadable engine assets go first: whether the neural VAD is
    // installed decides what "Abaikan jeda sunyi" below actually does.
    const EngineAssetsSection(),
    if (folded)
      SettingsSection(
        title: context.l10n.settingsScreenCategoryAudio,
        children: [
          SettingsTile(
            icon: AppIcons.autoFix,
            label: context.l10n.settingsScreenDecidedAutomatically,
            subtitle: _audioDecisionSubtitle(context, settings),
            trailing: TextButton(
              onPressed: () =>
                  ref.read(settingsAdvancedOpenProvider.notifier).state = true,
              child: Text(context.l10n.settingsScreenChangeManually),
            ),
          ),
        ],
      )
    else
    SettingsSection(
      title: context.l10n.settingsScreenCategoryAudio,
      children: [
        SettingsSwitch(
          icon: AppIcons.waveform,
          label: context.l10n.settingsScreenVad,
          subtitle: settings.vadEnabled
              ? context.l10n.settingsScreenVadOnSubtitle
              : context.l10n.settingsScreenVadOffSubtitle,
          value: settings.vadEnabled,
          onChanged: notifier.setVadEnabled,
        ),
        const SettingsDivider(),
        // F17. Deliberately described as a trade-off rather than an
        // improvement: on already-clean speech it can cost a word,
        // and whether it helps is a property of the room.
        SettingsSwitch(
          icon: AppIcons.noise,
          label: context.l10n.settingsScreenNoiseReduction,
          subtitle: settings.noiseReduction
              ? context.l10n.settingsScreenNoiseReductionOnSubtitle
              : context.l10n.settingsScreenNoiseReductionOffSubtitle,
          value: settings.noiseReduction,
          onChanged: notifier.setNoiseReduction,
        ),
        const SettingsDivider(),
        // Sprint 22 celah A: engine selalu menjalankan ini sejak Sprint
        // 14a, tapi tak ada kontrolnya di UI sampai sekarang.
        SettingsSwitch(
          icon: AppIcons.gainControl,
          label: context.l10n.settingsScreenAgc,
          subtitle: settings.agcEnabled
              ? context.l10n.settingsScreenAgcOnSubtitle
              : context.l10n.settingsScreenAgcOffSubtitle,
          value: settings.agcEnabled,
          onChanged: notifier.setAgcEnabled,
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.spatialAudio,
          label: context.l10n.settingsScreenDedup,
          subtitle: settings.defaultMode == SessionMode.online
              ? context.l10n.settingsScreenDedupOnlineSubtitle
              : context.l10n.settingsScreenDedupOtherSubtitle,
          trailing: InfoBadge(message: context.l10n.settingsScreenDedupInfo),
        ),
        const SettingsDivider(),
        SettingsSwitch(
          icon: AppIcons.timer,
          label: context.l10n.settingsScreenAutoStop,
          subtitle: settings.autoStopMinutes != null
              ? context.l10n.settingsScreenAutoStopOnSubtitle(
                  settings.autoStopMinutes!,
                )
              : context.l10n.settingsScreenAutoStopOffSubtitle,
          value: settings.autoStopMinutes != null,
          onChanged: (v) => notifier.setAutoStopMinutes(v ? 5 : null),
        ),
        if (settings.autoStopMinutes != null) ...[
          const SettingsDivider(),
          SettingsTile(
            icon: AppIcons.timer10,
            label: context.l10n.settingsScreenAutoStopDelay,
            trailing: CompactDropdown<int>(
              value: settings.autoStopMinutes!,
              items: const [1, 2, 3, 5, 10, 15],
              labelBuilder: (m) => context.l10n.settingsScreenMinutes(m),
              onChanged: notifier.setAutoStopMinutes,
            ),
          ),
        ],
      ],
    ),
    ];
  }

  List<Widget> _penyimpanan(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
    AppColorSet colors,
  ) => [
    SettingsSection(
      title: context.l10n.settingsScreenOutputStorage,
      children: [
        Builder(
          builder: (context) => SettingsTile(
            icon: AppIcons.folder,
            label: context.l10n.settingsScreenOutputFolder,
            subtitle: settings.libraryPath,
            trailing: Icon(
              AppIcons.chevronRight,
              color: colors.textTertiary,
              size: IconSizes.md,
            ),
            onTap: () async {
              final dir = await pickDirectoryPath(
                dialogTitle: context.l10n.settingsScreenPickOutputFolder,
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
          label: context.l10n.settingsScreenDefaultExportFormat,
          subtitle: context.l10n.settingsScreenDefaultExportFormatSubtitle,
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
      title: context.l10n.settingsScreenCategorySetup,
      children: [
        SettingsTile(
          icon: AppIcons.health,
          label: context.l10n.settingsScreenDiagnostics,
          subtitle: context.l10n.settingsScreenDiagnosticsSubtitle,
          trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
          onTap: () => openDiagnostics(context),
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.guide,
          label: context.l10n.settingsScreenRerunSetup,
          subtitle: context.l10n.settingsScreenRerunSetupSubtitle,
          trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
          onTap: () => openSetupWizard(context),
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.privacy,
          label: context.l10n.settingsScreenPrivacyReport,
          subtitle: context.l10n.settingsScreenPrivacyReportSubtitle,
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
          label: context.l10n.settingsScreenCapabilities,
          subtitle: context.l10n.settingsScreenCapabilitiesSubtitle,
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
              label: context.l10n.settingsScreenUsageDashboard,
              subtitle: context.l10n.settingsScreenUsageDashboardSubtitle,
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
      title: context.l10n.settingsScreenCategoryAbout,
      children: [
        SettingsTile(
          icon: AppIcons.update,
          label: context.l10n.settingsScreenCheckUpdate,
          subtitle: context.l10n.settingsScreenCheckUpdateSubtitle(kAppVersion),
          trailing: const Icon(AppIcons.chevronRight, size: IconSizes.md),
          onTap: () => _checkForUpdate(context, ref),
        ),
        const SettingsDivider(),
        SettingsTile(
          icon: AppIcons.info,
          label: context.l10n.settingsScreenAboutTrareon,
          subtitle: context.l10n.settingsScreenTagline,
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
            title: Text(context.l10n.settingsScreenUpdateAvailableTitle),
            content: Text(
              context.l10n.settingsScreenUpdateAvailableBody(
                info.latestVersion,
                info.currentVersion,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.settingsScreenLater),
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
                child: Text(context.l10n.settingsScreenViewRelease),
              ),
            ],
          ),
        );
      } else {
        AppToast.show(
          context,
          context.l10n.settingsScreenUpToDate,
          type: ToastType.success,
        );
      }
    } on UpdateCheckException catch (e) {
      if (context.mounted) {
        AppToast.show(context, '$e', type: ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          context.l10n.settingsScreenUpdateCheckFailed('$e'),
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
        context.l10n.settingsScreenBrowserFailed(url),
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
        Text(context.l10n.settingsScreenTagline),
        Spacing.gapLg,
        Text(context.l10n.settingsScreenBuiltWith),
      ],
    );
  }
}

/// Shows the current default model's FLEURS-id accuracy figure and, when
/// Rust's `recommend_default_model` (the single source of truth also used
/// by the setup wizard) disagrees with the saved choice, an opt-in
/// "Tingkatkan akurasi" offer — Sprint 14a items 5 and 6. Never changes
/// `defaultModel` on its own: an existing `base` user who already
/// dismissed the offer must not be asked again every time they open
/// Settings, and must never have their model swapped without tapping it.
/// Whether Settings should offer to switch the default model to the one
/// the hardware check recommends.
///
/// That recommendation only ranks the whisper tiers, so it never offers to
/// "upgrade" away from an Eksperimental (Qwen3-ASR) pick: Akurat-Eksperimental
/// is the more accurate model (FLEURS-id WER 5.3% vs 8.1%), and both
/// Eksperimental tiers are a deliberate opt-in.
bool shouldOfferDefaultModelUpgrade({
  required String currentModel,
  required String recommendedModel,
  required bool dismissed,
  required bool recommendedInstalled,
}) =>
    recommendedModel != currentModel &&
    !isExperimentalModel(currentModel) &&
    !dismissed &&
    recommendedInstalled;

class _ModelAccuracyAndUpgradeRow extends ConsumerWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;

  const _ModelAccuracyAndUpgradeRow({
    required this.settings,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bridge = ref.read(rustBridgeProvider);
    return FutureBuilder<_ModelAdvice>(
      future: _loadAdvice(bridge),
      builder: (context, snapshot) {
        final advice = snapshot.data;
        if (advice == null) return const SizedBox.shrink();
        final colors =
            Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
        final showOffer = shouldOfferDefaultModelUpgrade(
          currentModel: settings.defaultModel,
          recommendedModel: advice.recommended,
          dismissed: settings.defaultModelUpgradeDismissed,
          recommendedInstalled: isModelAvailable(
            advice.recommended,
            libraryPath: settings.libraryPath,
          ),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (advice.currentLabel != null)
                Text(
                  advice.currentLabel!,
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: FontSizes.caption,
                  ),
                ),
              if (showOffer) ...[
                Spacing.gapXs,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.settingsScreenUpgradeOffer(
                          modelDisplayLabel(advice.recommended),
                        ),
                        style: TextStyle(
                          color: colors.text,
                          fontSize: FontSizes.caption,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          notifier.setDefaultModel(advice.recommended),
                      child: Text(context.l10n.settingsScreenUpgradeAccuracy),
                    ),
                    TextButton(
                      onPressed: notifier.dismissDefaultModelUpgradeOffer,
                      child: Text(context.l10n.settingsScreenNotNow),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<_ModelAdvice> _loadAdvice(RustBridge bridge) async {
    final ram = await detectTotalRam();
    final recommended = await bridge.recommendDefaultModel(ram.megabytes);
    final currentLabel = await bridge.modelAccuracyLabel(settings.defaultModel);
    return _ModelAdvice(recommended: recommended, currentLabel: currentLabel);
  }
}

class _ModelAdvice {
  final String recommended;
  final String? currentLabel;

  const _ModelAdvice({required this.recommended, this.currentLabel});
}

String _themeLabel(BuildContext context, AppThemeMode mode) => switch (mode) {
  AppThemeMode.light => context.l10n.settingsScreenThemeLight,
  AppThemeMode.dark => context.l10n.settingsScreenThemeDark,
  AppThemeMode.system => context.l10n.settingsScreenThemeSystem,
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
