import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/model_download_card.dart';

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
    final colors = Theme.of(context).extension<AppColorSet>()!;
    final quick = state.quick;
    final accurate = state.accurate;
    final allReady = state.allReady;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selamat datang di Trareon Transcribe',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Aplikasi ini bekerja 100% offline. Kami perlu mengunduh dua model ke perangkat Anda — proses ini hanya terjadi sekali.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 24),
              ModelDownloadCard(
                title: quick.title,
                subtitle: quick.subtitle,
                sizeLabel: quick.size,
                progress: quick.progress,
                status: quick.status,
                errorText: quick.error,
              ),
              const SizedBox(height: 12),
              ModelDownloadCard(
                title: accurate.title,
                subtitle: accurate.subtitle,
                sizeLabel: accurate.size,
                progress: accurate.progress,
                status: accurate.status,
                errorText: accurate.error,
              ),
              const Spacer(),
              if (quick.status == DownloadStatus.error ||
                  accurate.status == DownloadStatus.error)
                TextButton.icon(
                  onPressed: () {
                    if (quick.status == DownloadStatus.error) {
                      onRetryQuick();
                    }
                    if (accurate.status == DownloadStatus.error) {
                      onRetryAccurate();
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Coba lagi'),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: allReady ? onContinue : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  allReady ? 'Mulai menggunakan' : 'Mengunduh...',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                allReady
                    ? 'Siap. Model tidak akan pernah dikirim ke cloud.'
                    : 'Anda boleh menutup aplikasi — unduhan akan dilanjutkan di latar belakang.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
            ],
          ),
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
