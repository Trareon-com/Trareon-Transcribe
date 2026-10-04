import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/flight_recorder_service.dart';
import 'services/rust_library_loader.dart';
import 'services/tray_service.dart';
import 'services/window_service.dart';
import 'src/rust/api.dart' as rust_api;
import 'src/rust/error.dart' show TranscribeError_InvalidInput;
import 'src/rust/frb_generated.dart';
import 'state/models.dart';
import 'state/onboarding_model.dart';
import 'state/settings_model.dart';
import 'theme/app_icons.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'widgets/setup_overlay.dart';

/// Smallest window the layout is designed to survive, and the size a first
/// launch opens at. Both live in `WindowSizes` so the layout tests and the
/// design system cannot disagree with the runtime about them.
///
/// macOS enforces a minimum from the app bundle; Linux and Windows had none,
/// so a user could drag the window down to nothing and lose the record button
/// off the edge.
const Size kMinimumWindowSize = WindowSizes.minimum;

/// Indonesian-first locale resolution. Flutter's default
/// `basicLocaleListResolution` falls back to `supportedLocales.first`, which
/// `flutter gen-l10n` emits alphabetically — English. For an Indonesian-first
/// product the fallback for an unknown system locale must be Indonesian, not
/// English (audit item 26). Matches on language code; country/script are not
/// used because neither locale is region-specific.
Locale resolveLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  const fallback = Locale('id');
  for (final want in preferred ?? const <Locale>[]) {
    for (final have in supported) {
      if (have.languageCode == want.languageCode) return have;
    }
  }
  return supported.any((l) => l.languageCode == fallback.languageCode)
      ? fallback
      : (supported.isNotEmpty ? supported.first : fallback);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Geometry, minimum size and platform chrome, plus the saved size and
  // position from last launch (see services/window_service.dart).
  await configureWindow();
  WindowGeometryRecorder.instance.install();
  await RustLib.init(externalLibrary: tryLoadRustCoreLibrary());
  await rust_api.initLogging();
  // The flight recorder has existed in the engine since the first release
  // and nothing ever called it, so no user could produce a log (audit
  // item 27). Metadata only — see flight_recorder_service.dart.
  await FlightRecorder.instance.init();

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveLocale,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.info, size: IconSizes.hero),
                    Spacing.gapLg,
                    Text(
                      l10n.alreadyRunningTitle,
                      style: const TextStyle(
                        fontSize: FontSizes.title,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Spacing.gapSm,
                    Text(l10n.alreadyRunningBody, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        },
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveLocale,
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
      // dedicated onboarding/download screen. SetupWizardScreen is reached
      // from Settings → "Jalankan Ulang Penyiapan".
      //
      // SetupOverlay runs doctor.rs after the first frame and only blocks
      // on a hard failure; warnings become a banner over the app.
      home: SetupOverlay(
        child: modelsReady ? const MainScreen() : const _OnboardingRoute(),
      ),
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
