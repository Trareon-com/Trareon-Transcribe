import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/rust_library_loader.dart';
import 'services/tray_service.dart';
import 'src/rust/api.dart' as rust_api;
import 'src/rust/error.dart' show TranscribeError_InvalidInput;
import 'src/rust/frb_generated.dart';
import 'state/models.dart';
import 'state/onboarding_model.dart';
import 'state/settings_model.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(externalLibrary: tryLoadRustCoreLibrary());
  await rust_api.initLogging();

  try {
    await rust_api.acquireInstanceLock();
  } on TranscribeError_InvalidInput catch (e) {
    if (e.field0.contains('already running')) {
      runApp(const _AlreadyRunningApp());
      return;
    }
    rethrow;
  }

  try {
    await TrayService.instance.init();
  } catch (_) {
    // Tray icon is a non-essential convenience; failing to init it
    // (e.g. no system tray available) shouldn't block app startup.
  }

  runApp(const ProviderScope(child: TranscribeApp()));
}

class _AlreadyRunningApp extends StatelessWidget {
  const _AlreadyRunningApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Trareon Transcribe sudah berjalan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hanya satu instance Trareon Transcribe yang bisa berjalan pada saat '
                  'yang sama. Tutup jendela ini dan gunakan instance yang '
                  'sudah terbuka.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// True if the default STT model ('base') exists on disk. Read once at
/// startup; the onboarding screen flips it to true when download completes.
/// Without this check, first-launch users (and anyone whose cached model
/// was removed) would land straight on MainScreen with no model to
/// transcribe with, instead of the download flow.
final modelsReadyProvider = StateProvider<bool>((ref) {
  return isModelAvailable('base');
});

class TranscribeApp extends ConsumerWidget {
  const TranscribeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final modelsReady = ref.watch(modelsReadyProvider);

    return MaterialApp(
      title: 'Trareon Transcribe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (settings.theme) {
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
      },
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeInOut,
      // First-launch routing: when models aren't downloaded yet, show the
      // dedicated onboarding/download screen. The legacy SetupWizardScreen
      // remains reachable from Settings for power users.
      home: modelsReady ? const MainScreen() : const _OnboardingRoute(),
    );
  }
}

/// Hosts [OnboardingScreen], kicks off the real model downloads via
/// [onboardingProvider], and flips [modelsReadyProvider] once the user
/// confirms both models are ready.
class _OnboardingRoute extends ConsumerStatefulWidget {
  const _OnboardingRoute();

  @override
  ConsumerState<_OnboardingRoute> createState() => _OnboardingRouteState();
}

class _OnboardingRouteState extends ConsumerState<_OnboardingRoute> {
  @override
  void initState() {
    super.initState();
    // Deferred to post-frame so the screen paints before the download
    // kicks off. OnboardingNotifier.start() is idempotent/self-guarding,
    // so this is safe even if the widget rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    return OnboardingScreen(
      state: state,
      onContinue: () => ref.read(modelsReadyProvider.notifier).state = true,
      onRetryQuick: notifier.retryQuick,
      onRetryAccurate: notifier.retryAccurate,
    );
  }
}
