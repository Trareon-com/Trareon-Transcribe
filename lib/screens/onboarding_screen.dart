import 'package:flutter/material.dart';

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
  });

  final OnboardingState state;
  final VoidCallback onContinue;
  final VoidCallback onRetryQuick;
  final VoidCallback onRetryAccurate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quick = state.quick;
    final accurate = state.accurate;
    final allReady = state.allReady;
    final failed =
        quick.status == DownloadStatus.error ||
        accurate.status == DownloadStatus.error;

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
                    'Selamat datang di Trareon Transcribe',
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
                    allReady ? 'Siap merekam' : 'Mengunduh model',
                    textAlign: TextAlign.center,
                    style: AppText.title.c(colors.text),
                  ),
                  Spacing.gapSm,
                  Text(
                    allReady
                        ? 'Kedua model sudah ada di perangkat ini. '
                              'Transkripsi berjalan sepenuhnya offline.'
                        : 'Trareon bekerja 100% offline, jadi modelnya perlu '
                              'ada di perangkat Anda. Hanya sekali.',
                    textAlign: TextAlign.center,
                    style: AppText.body.c(colors.textSecondary),
                  ),
                  Spacing.gapXl,
                  ModelDownloadCard(
                    title: quick.title,
                    subtitle: quick.subtitle,
                    sizeLabel: quick.size,
                    progress: quick.progress,
                    status: quick.status,
                    errorText: quick.error,
                  ),
                  Spacing.gapMd,
                  ModelDownloadCard(
                    title: accurate.title,
                    subtitle: accurate.subtitle,
                    sizeLabel: accurate.size,
                    progress: accurate.progress,
                    status: accurate.status,
                    errorText: accurate.error,
                  ),
                  Spacing.gapXl,
                  if (failed) ...[
                    Center(
                      child: AppButton(
                        label: 'Coba Lagi',
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
                  Center(
                    child: AppButton.primary(
                      label: allReady ? 'Mulai Merekam' : 'Mengunduh…',
                      size: AppButtonSize.lg,
                      loading: !allReady && !failed,
                      icon: allReady ? AppIcons.record : null,
                      onPressed: allReady ? onContinue : null,
                    ),
                  ),
                  Spacing.gapSm,
                  Text(
                    allReady
                        ? 'Model tidak akan pernah dikirim ke mana pun.'
                        : 'Anda boleh menutup aplikasi, unduhan dilanjutkan '
                              'di latar belakang.',
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

  static const _labels = [
    'Izin mikrofon & audio sistem',
    'Pilih model',
    'Siap rekam',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label:
          'Langkah ${current + 1} dari ${_labels.length}: '
          '${_labels[current]}',
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
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
                      _labels[i],
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

/// Pure-data state object for the screen above; lets the state holder be a
/// Riverpod `Notifier` without leaking UI imports.
class OnboardingState {
  const OnboardingState({required this.quick, required this.accurate});

  /// Progress for the `base` model — used for the fast/progressive pass.
  final DownloadProgress quick;

  /// Progress for the `large-v3-turbo-q5` model — used for the accurate
  /// refine pass.
  final DownloadProgress accurate;

  bool get allReady =>
      quick.status == DownloadStatus.ready &&
      accurate.status == DownloadStatus.ready;

  static const empty = OnboardingState(
    quick: DownloadProgress(
      status: DownloadStatus.idle,
      progress: 0.0,
      title: 'Model Cepat',
      subtitle: 'Transkripsi cepat, akurasi Bahasa Indonesia maksimal',
      size: '142 MB',
    ),
    accurate: DownloadProgress(
      status: DownloadStatus.idle,
      progress: 0.0,
      title: 'Model Akurat',
      subtitle:
          'Menyempurnakan transkrip di latar belakang, akurasi global terbaik',
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
