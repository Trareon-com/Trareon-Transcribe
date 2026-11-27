/// Penyiapan model AI (Ollama) pertama kali (Sprint 7 Item 2, disambungkan
/// ke UI di Sprint 20).
///
/// Lima langkah: deteksi Ollama (`llmDetect`) → panduan pasang per OS
/// (`llmInstallGuide`) kalau tidak terdeteksi → profil perangkat keras +
/// rekomendasi (`llmHardware`/`llmRecommend`) → pilih dari katalog
/// (`llmCatalogue`, default `llmDefaultModel`) → unduh dengan progres nyata
/// (`llmPullModel` + `readLlmPullProgress`). Dibuka otomatis dari
/// [SummaryPanel] saat Ollama tidak terdeteksi, atau manual dari Pengaturan
/// → Ringkasan AI.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../src/rust/api.dart' as rust_api;
import '../src/rust/summary.dart' show OllamaStatus;
import '../state/models.dart';
import '../state/privacy_report_model.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/app_toast.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_feedback.dart';
import '../widgets/ui/app_surface.dart';

enum _Step { deteksi, pasang, katalog, unduh, selesai }

/// Membuka wizard sebagai halaman penuh. Mengembalikan tag model yang
/// berhasil diunduh dan disetel, atau `null` kalau pengguna membatalkan.
Future<String?> openLlmSetupWizard(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(builder: (_) => const LlmSetupWizardScreen()),
  );
}

class LlmSetupWizardScreen extends ConsumerStatefulWidget {
  const LlmSetupWizardScreen({super.key});

  @override
  ConsumerState<LlmSetupWizardScreen> createState() =>
      _LlmSetupWizardScreenState();
}

class _LlmSetupWizardScreenState extends ConsumerState<LlmSetupWizardScreen> {
  _Step _step = _Step.deteksi;
  String get _baseUrl => ref.read(settingsProvider).summary.baseUrl.isEmpty
      ? 'http://localhost:11434'
      : ref.read(settingsProvider).summary.baseUrl;

  bool _busy = true;
  Object? _error;

  OllamaStatus? _status;
  InstallGuide? _installGuide;
  HardwareProfile? _hardware;
  Recommendation? _recommendation;
  List<ModelOption> _catalogue = const [];
  ModelOption? _selected;

  bool _pulling = false;
  PullProgress? _pullProgress;
  Timer? _pullPoll;

  @override
  void initState() {
    super.initState();
    unawaited(_detect());
  }

  @override
  void dispose() {
    _pullPoll?.cancel();
    super.dispose();
  }

  Future<void> _detect() async {
    setState(() {
      _busy = true;
      _error = null;
      _step = _Step.deteksi;
    });
    try {
      final status = await rust_api.llmDetect(baseUrl: _baseUrl);
      if (!mounted) return;
      if (status.tersedia) {
        setState(() {
          _status = status;
          _busy = false;
        });
        await _loadRekomendasi();
      } else {
        final os = await rust_api.currentOs();
        final guide = await rust_api.llmInstallGuide(os: os);
        if (!mounted) return;
        setState(() {
          _status = status;
          _installGuide = guide;
          _step = _Step.pasang;
          _busy = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
      });
    }
  }

  Future<void> _loadRekomendasi() async {
    setState(() => _busy = true);
    try {
      final hardware = await rust_api.llmHardware();
      final recommendation = await rust_api.llmRecommend(hardware: hardware);
      final catalogue = await rust_api.llmCatalogue();
      final defaultTag = await rust_api.llmDefaultModel();
      if (!mounted) return;
      setState(() {
        _hardware = hardware;
        _recommendation = recommendation;
        _catalogue = catalogue;
        _selected = catalogue.firstWhere(
          (m) => m.tag == recommendation.model.tag,
          orElse: () => catalogue.firstWhere(
            (m) => m.tag == defaultTag,
            orElse: () => recommendation.model,
          ),
        );
        _step = _Step.katalog;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
      });
    }
  }

  Future<void> _pull() async {
    final model = _selected;
    if (model == null) return;
    setState(() {
      _step = _Step.unduh;
      _pulling = true;
      _pullProgress = null;
      _error = null;
    });
    _startPullPoll();
    try {
      await rust_api.llmPullModel(baseUrl: _baseUrl, model: model.tag);
      if (!mounted) return;
      await ref
          .read(settingsProvider.notifier)
          .setSummarySettings(
            ref
                .read(settingsProvider)
                .summary
                .copyWith(
                  provider: SummaryProvider.ollama,
                  baseUrl: _baseUrl,
                  model: model.tag,
                ),
          );
      if (!mounted) return;
      setState(() {
        _pulling = false;
        _step = _Step.selesai;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pulling = false;
        _error = e;
      });
    } finally {
      _stopPullPoll();
    }
  }

  void _startPullPoll() {
    _pullPoll?.cancel();
    _pullPoll = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      try {
        final progress = await rust_api.readLlmPullProgress();
        if (!mounted) return;
        setState(() => _pullProgress = progress);
      } catch (_) {
        // Progres hanya dekorasi; kegagalan membaca progres tidak boleh
        // menggagalkan unduhan.
      }
    });
  }

  void _stopPullPoll() {
    _pullPoll?.cancel();
    _pullPoll = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        title: Text(context.l10n.llmSetupWizardScreenTitle),
        automaticallyImplyLeading: !_pulling,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: _busy
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.xl),
                    child: AppProgressRing(),
                  ),
                )
              : _body(colors),
        ),
      ),
    );
  }

  Widget _body(AppColorSet colors) {
    if (_error != null) {
      return _ErrorCard(
        error: _error!,
        onRetry: _step == _Step.unduh ? _pull : _detect,
      );
    }
    return switch (_step) {
      _Step.deteksi => const SizedBox.shrink(),
      _Step.pasang => _pasangStep(colors),
      _Step.katalog => _katalogStep(colors),
      _Step.unduh => _unduhStep(colors),
      _Step.selesai => _selesaiStep(colors),
    };
  }

  Widget _pasangStep(AppColorSet colors) {
    final guide = _installGuide;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _status?.pesan ?? l10n.llmSetupWizardScreenNotDetected,
          style: AppText.body.c(colors.textSecondary),
        ),
        Spacing.gapLg,
        if (guide != null) ...[
          Text(
            l10n.llmSetupWizardScreenInstallOn(guide.sistem),
            style: AppText.title,
          ),
          Spacing.gapMd,
          for (var i = 0; i < guide.langkah.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Text(
                '${i + 1}. ${guide.langkah[i]}',
                style: AppText.body.c(colors.text),
              ),
            ),
          if (guide.perintah.isNotEmpty) ...[
            Spacing.gapSm,
            AppSurface(
              padding: const EdgeInsets.all(Spacing.md),
              child: SelectableText(
                guide.perintah,
                style: AppText.mono.c(colors.text),
              ),
            ),
          ],
          Spacing.gapMd,
          AppButton(
            label: l10n.llmSetupWizardScreenOpenLink(guide.tautan),
            icon: AppIcons.link,
            onPressed: () {
              ref.read(privacyReportProvider.notifier).recordExternalLink(
                    guide.tautan,
                  );
              launchUrl(
                Uri.parse(guide.tautan),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
        Spacing.gapLg,
        AppButton.primary(
          label: l10n.llmSetupWizardScreenInstalledRecheck,
          icon: AppIcons.refresh,
          onPressed: _detect,
        ),
      ],
    );
  }

  Widget _katalogStep(AppColorSet colors) {
    final recommendation = _recommendation;
    final hardware = _hardware;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hardware != null)
          Text(
            hardware.vramGb > 0
                ? l10n.llmSetupWizardScreenHardwareWithVram(
                    hardware.ramGb.toStringAsFixed(1),
                    hardware.cpuThreads,
                    hardware.vramGb.toStringAsFixed(1),
                  )
                : l10n.llmSetupWizardScreenHardware(
                    hardware.ramGb.toStringAsFixed(1),
                    hardware.cpuThreads,
                  ),
            style: AppText.body.c(colors.textSecondary),
          ),
        if (recommendation != null) ...[
          Spacing.gapSm,
          Text(recommendation.alasan, style: AppText.body.c(colors.text)),
          if (recommendation.terlaluKecil) ...[
            Spacing.gapSm,
            Text(
              l10n.llmSetupWizardScreenBelowMinimum,
              style: AppText.caption.c(colors.warning),
            ),
          ],
        ],
        Spacing.gapLg,
        Text(l10n.llmSetupWizardScreenChooseModel, style: AppText.title),
        Spacing.gapSm,
        for (final model in _catalogue)
          _ModelCard(
            model: model,
            selected: _selected?.tag == model.tag,
            onTap: () => setState(() => _selected = model),
          ),
        Spacing.gapLg,
        AppButton.primary(
          label: l10n.llmSetupWizardScreenDownload(_selected?.label ?? ''),
          icon: AppIcons.download,
          onPressed: _selected == null ? null : _pull,
        ),
      ],
    );
  }

  Widget _unduhStep(AppColorSet colors) {
    final progress = _pullProgress;
    final ratio = progress != null && progress.totalBytes > BigInt.zero
        ? progress.selesaiBytes.toDouble() / progress.totalBytes.toDouble()
        : null;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.llmSetupWizardScreenDownloading(_selected?.label ?? ''),
          style: AppText.title,
        ),
        Spacing.gapMd,
        AppLinearProgress(
          value: ratio,
          semanticLabel:
              progress?.label ?? l10n.llmSetupWizardScreenDownloadingShort,
        ),
        Spacing.gapSm,
        Text(
          progress?.label ?? l10n.llmSetupWizardScreenPreparing,
          style: AppText.caption.c(colors.textSecondary),
        ),
      ],
    );
  }

  Widget _selesaiStep(AppColorSet colors) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AppIcons.checkFilled, color: colors.success),
            Spacing.hSm,
            Text(l10n.llmSetupWizardScreenReady, style: AppText.title),
          ],
        ),
        Spacing.gapSm,
        Text(
          l10n.llmSetupWizardScreenReadyBody(_selected?.label ?? ''),
          style: AppText.body.c(colors.textSecondary),
        ),
        Spacing.gapLg,
        AppButton.primary(
          label: l10n.llmSetupWizardScreenDone,
          onPressed: () {
            final tag = _selected?.tag;
            if (!mounted) return;
            Navigator.of(context).pop(tag);
            AppToast.show(
              context,
              l10n.llmSetupWizardScreenReadyToast(_selected?.label ?? ''),
              type: ToastType.success,
            );
          },
        ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final ModelOption model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AppSurface(
          padding: const EdgeInsets.all(Spacing.md),
          borderColor: selected ? colors.primary : null,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.label, style: AppText.body.c(colors.text)),
                    Spacing.gapXs,
                    Text(
                      context.l10n.llmSetupWizardScreenModelMeta(
                        model.tag,
                        model.unduhGb.toStringAsFixed(1),
                        model.konteks,
                      ),
                      style: AppText.caption.c(colors.textTertiary),
                    ),
                    Spacing.gapXs,
                    Text(
                      model.catatan,
                      style: AppText.caption.c(colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  AppIcons.checkFilled,
                  color: colors.primary,
                  size: IconSizes.md,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.llmSetupWizardScreenError('$error'),
          style: AppText.body.c(colors.error),
        ),
        Spacing.gapMd,
        AppButton(
          label: context.l10n.llmSetupWizardScreenRetry,
          icon: AppIcons.refresh,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
