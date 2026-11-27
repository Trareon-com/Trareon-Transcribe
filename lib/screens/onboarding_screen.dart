import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/model_download_card.dart';
import '../widgets/ui/app_button.dart';

/// First-launch onboarding — model download screen.
///
/// Shows progress for the two bundled Whisper models the app actually
/// ships with (see `rust_core/src/model.rs` KNOWN_MODELS, both
/// `is_bundled: true`): `base` (142 MB, used for fast/progressive
/// transcription) and `large-v3-turbo-q5` (548 MB, used for the accurate
/// refine pass). No model identifiers exposed; only Indonesian descriptions.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.state,
    required this.onContinue,
    required this.onRetryQuick,
    required this.onRetryAccurate,
    this.onDownloadNow,
  });

  final OnboardingState state;
  final VoidCallback onContinue;
  final VoidCallback onRetryQuick;
  final VoidCallback onRetryAccurate;

  /// "Unduh sekarang" while the download is postponed (issue #70).
  final VoidCallback? onDownloadNow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final quick = state.quick;
    final accurate = state.accurate;
    final allReady = state.allReady;
    final failed =
        quick.status == DownloadStatus.error ||
        accurate.status == DownloadStatus.error;
    // Nothing is downloading until the user agrees, so neither "Mengunduh"
    // nor a spinner may suggest otherwise.
    final waiting =
        !allReady &&
        (state.phase == OnboardingPhase.awaitingConsent ||
            state.phase == OnboardingPhase.postponed ||
            state.phase == OnboardingPhase.checking);
    final postponed = !allReady && state.phase == OnboardingPhase.postponed;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.xl,
              vertical: Spacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Measure.hero),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The first screen a new user sees names the product.
                  // A misspelling of it once shipped here, which is why
                  // test/product_name_spelling_test.dart guards this line.
                  Text(
                    l10n.onboardingScreenWelcome,
                    textAlign: TextAlign.center,
                    style: AppText.display.c(colors.textStrong),
                  ),
                  Spacing.gapXl,
                  _Steps(current: allReady ? 2 : 1),
                  Spacing.gapXl,
                  Center(
                    child: _Plate(
                      icon: AppIcons.download,
                      badge: allReady ? AppIcons.checkPlain : null,
                    ),
                  ),
                  Spacing.gapLg,
                  Text(
                    allReady
                        ? l10n.onboardingScreenReady
                        : postponed
                        ? l10n.onboardingScreenPostponed
                        : waiting
                        ? l10n.onboardingScreenNeedsDownload
                        : l10n.onboardingScreenDownloading,
                    textAlign: TextAlign.center,
                    style: AppText.title.c(colors.text),
                  ),
                  Spacing.gapSm,
                  Text(
                    allReady
                        ? l10n.onboardingScreenReadyBody
                        : l10n.onboardingScreenOfflineBody,
                    textAlign: TextAlign.center,
                    style: AppText.body.c(colors.textSecondary),
                  ),
                  Spacing.gapXl,
                  ModelDownloadCard(
                    // Read here, not from the state: the state is built
                    // before the saved interface language is loaded.
                    title: l10n.onboardingScreenQuickModelTitle,
                    subtitle: l10n.onboardingScreenQuickModelSubtitle,
                    sizeLabel: quick.size,
                    progress: quick.progress,
                    status: quick.status,
                    errorText: quick.error,
                  ),
                  Spacing.gapMd,
                  ModelDownloadCard(
                    title: l10n.onboardingScreenAccurateModelTitle,
                    subtitle: l10n.onboardingScreenAccurateModelSubtitle,
                    sizeLabel: accurate.size,
                    progress: accurate.progress,
                    status: accurate.status,
                    errorText: accurate.error,
                  ),
                  Spacing.gapXl,
                  if (failed) ...[
                    Center(
                      child: AppButton(
                        label: l10n.onboardingScreenRetry,
                        icon: AppIcons.refresh,
                        onPressed: () {
                          if (quick.status == DownloadStatus.error) {
                            onRetryQuick();
                          }
                          if (accurate.status == DownloadStatus.error) {
                            onRetryAccurate();
                          }
                        },
                      ),
                    ),
                    Spacing.gapMd,
                  ],
                  if (postponed) ...[
                    Center(
                      child: AppButton.primary(
                        label: l10n.onboardingScreenDownloadNow,
                        size: AppButtonSize.lg,
                        icon: AppIcons.download,
                        onPressed: onDownloadNow,
                      ),
                    ),
                    Spacing.gapSm,
                    Center(
                      child: AppButton.ghost(
                        label: l10n.onboardingScreenContinueWithoutModels,
                        onPressed: onContinue,
                      ),
                    ),
                  ] else
                    Center(
                      child: AppButton.primary(
                        label: allReady
                            ? l10n.onboardingScreenStartRecording
                            : waiting
                            ? l10n.onboardingScreenAwaitingConsent
                            : l10n.onboardingScreenDownloadingButton,
                        size: AppButtonSize.lg,
                        loading: !allReady && !failed && !waiting,
                        icon: allReady ? AppIcons.record : null,
                        onPressed: allReady ? onContinue : null,
                      ),
                    ),
                  Spacing.gapSm,
                  Text(
                    allReady
                        ? l10n.onboardingScreenFooterReady
                        : postponed
                        ? l10n.onboardingScreenFooterPostponed
                        : waiting
                        ? l10n.onboardingScreenFooterWaiting
                        : l10n.onboardingScreenFooterDownloading,
                    textAlign: TextAlign.center,
                    style: AppText.caption.c(colors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three steps of first run, as a progress strip.
///
/// Step 1 (permissions) is handled by the setup wizard and the OS prompts the
/// first time a session starts, so it is shown as already behind the user
/// rather than invented here; this screen owns step 2 and announces step 3.
class _Steps extends StatelessWidget {
  const _Steps({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final labels = [
      l10n.onboardingScreenStepPermissions,
      l10n.onboardingScreenStepModel,
      l10n.onboardingScreenStepReady,
    ];
    return Semantics(
      label: l10n.onboardingScreenStepSemantics(
        current + 1,
        labels.length,
        labels[current],
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) Spacing.hSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: Strokes.progress,
                    decoration: BoxDecoration(
                      color: i <= current
                          ? colors.primary
                          : colors.hairlineStrong,
                      borderRadius: Radii.pillAll,
                    ),
                  ),
                  Spacing.gapSm,
                  ExcludeSemantics(
                    child: Text(
                      labels[i],
                      maxLines: 2,
                      style: AppText.micro.c(
                        i <= current ? colors.text : colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The icon composition the hero opens with.
class _Plate extends StatelessWidget {
  const _Plate({required this.icon, this.badge});

  final IconData icon;
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: SizedBox(
        width: Spacing.xxxl + Spacing.xl,
        height: Spacing.xxxl + Spacing.xl,
        child: Stack(
          children: [
            Container(
              width: Spacing.xxxl + Spacing.xl,
              height: Spacing.xxxl + Spacing.xl,
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(color: colors.hairline),
              ),
              child: Icon(
                icon,
                size: IconSizes.hero,
                color: colors.textTertiary,
              ),
            ),
            if (badge != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: Spacing.xl,
                  height: Spacing.xl,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.surface,
                      width: Strokes.focusRing,
                    ),
                  ),
                  child: Icon(
                    badge,
                    size: IconSizes.xs,
                    color: colors.onSuccess,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The first-run flow's steps (issue #70). Downloads only start in
/// [downloading], which is reached through the user's "Unduh sekarang" or a
/// consent they gave on an earlier run.
enum OnboardingPhase { checking, awaitingConsent, postponed, downloading }

/// Pure-data state object for the screen above; lets the state holder be a
/// Riverpod `Notifier` without leaking UI imports.
class OnboardingState {
  const OnboardingState({
    required this.quick,
    required this.accurate,
    this.phase = OnboardingPhase.checking,
  });

  /// Where the first-run flow is: still looking at the disk, waiting for the
  /// user's answer to the download dialog, postponed, or downloading.
  final OnboardingPhase phase;

  /// Progress for the `base` model — used for the fast/progressive pass.
  final DownloadProgress quick;

  /// Progress for the `large-v3-turbo-q5` model — used for the accurate
  /// refine pass.
  final DownloadProgress accurate;

  bool get allReady =>
      quick.status == DownloadStatus.ready &&
      accurate.status == DownloadStatus.ready;

  OnboardingState copyWith({
    DownloadProgress? quick,
    DownloadProgress? accurate,
    OnboardingPhase? phase,
  }) => OnboardingState(
    quick: quick ?? this.quick,
    accurate: accurate ?? this.accurate,
    phase: phase ?? this.phase,
  );

  /// A getter rather than a `const`: the card titles follow the language
  /// the app is showing when the first-run flow starts.
  static OnboardingState get empty => OnboardingState(
    quick: DownloadProgress(
      status: DownloadStatus.idle,
      progress: 0.0,
      title: currentL10n.onboardingScreenQuickModelTitle,
      subtitle: currentL10n.onboardingScreenQuickModelSubtitle,
      size: '142 MB',
    ),
    accurate: DownloadProgress(
      status: DownloadStatus.idle,
      progress: 0.0,
      title: currentL10n.onboardingScreenAccurateModelTitle,
      subtitle: currentL10n.onboardingScreenAccurateModelSubtitle,
      size: '548 MB',
    ),
  );
}

class DownloadProgress {
  const DownloadProgress({
    required this.status,
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.size,
    this.error,
  });

  final DownloadStatus status;
  final double progress;
  final String title;
  final String subtitle;
  final String size;
  final String? error;

  DownloadProgress copyWith({
    DownloadStatus? status,
    double? progress,
    String? title,
    String? subtitle,
    String? size,
    String? error,
  }) {
    return DownloadProgress(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      size: size ?? this.size,
      error: error,
    );
  }
}
