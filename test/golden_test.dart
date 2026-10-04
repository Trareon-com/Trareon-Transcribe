@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/onboarding_screen.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/widgets/model_download_card.dart'
    show DownloadStatus;
import 'package:transcribe/screens/settings_screen.dart';
import 'package:transcribe/screens/transcript_player_screen.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/theme/app_theme.dart';

import 'support/component_gallery.dart';
import 'support/golden_fonts.dart';
import 'test_helpers.dart';

/// Golden tests for the component kit and the signature screens, in light and
/// dark at 1280x800. `docs/DESIGN-SYSTEM.md` §12.
///
/// Run with `flutter test --update-goldens test/golden_test.dart` after a
/// deliberate design change, and read the diff before committing it: that
/// diff is the design review.
///
/// They render the bundled Inter and JetBrains Mono rather than the harness's
/// placeholder font, so they actually regress on type (see
/// `support/golden_fonts.dart`). Text rasterisation differs slightly between
/// host platforms, so these carry the `golden` tag and CI runs
/// `flutter test --exclude-tags golden`; they are a local design gate, not a
/// cross-platform pixel gate.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    _stubAudioPlayers();
  });

  const window = Size(1280, 800);

  /// Renders [app] with reduce motion on.
  ///
  /// This is not a shortcut: the app has three continuous animations (the
  /// record pulse, the skeleton shimmer and the live waveform), so
  /// `pumpAndSettle` never returns with motion enabled. Reduce motion is also
  /// the state the design system promises is a complete, static frame, so
  /// pinning it is pinning a real guarantee rather than dodging one.
  Widget still(Widget app) => MediaQuery(
    data: const MediaQueryData(disableAnimations: true, size: window),
    child: app,
  );

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget app, {
    Size size = window,
    Future<void> Function(WidgetTester tester)? drive,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The transcript player constructs an AudioPlayer as it builds, and
    // audioplayers opens a per-instance event channel whose name carries a
    // fresh UUID, so it cannot be stubbed by name. There is no audio plugin
    // behind a widget test; the golden is about layout, so the plugin's
    // complaint is swallowed and everything else still fails the test.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(still(app));
    // Fixed pumps rather than pumpAndSettle: see `still` above.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    if (drive != null) {
      await drive(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  /// Wraps a bare screen in the app's theme, for the screens that are pushed
  /// rather than being the home route.
  Widget themed(Widget child, ThemeMode mode) => ProviderScope(
    overrides: [rustBridgeProvider.overrideWithValue(NoopBridge())],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: child,
    ),
  );

  for (final (suffix, mode) in <(String, ThemeMode)>[
    ('light', ThemeMode.light),
    ('dark', ThemeMode.dark),
  ]) {
    group(suffix, () {
      testWidgets('component gallery', (tester) async {
        await shoot(
          tester,
          'gallery-$suffix',
          themed(const ComponentGallery(), mode),
          // Tall enough for the whole kit in one frame: a gallery that has to
          // be scrolled is a gallery whose lower half never gets reviewed.
          size: const Size(1280, 2600),
        );
      });

      testWidgets('main screen, idle', (tester) async {
        await shoot(tester, 'main-idle-$suffix', buildTestApp(themeMode: mode));
      });

      testWidgets('main screen, recording', (tester) async {
        await shoot(
          tester,
          'main-recording-$suffix',
          buildTestApp(themeMode: mode),
          drive: (tester) async {
            await tester.tap(find.text('Mulai Rekam'));
            await tester.pump();
          },
        );
      });

      testWidgets('transcript player', (tester) async {
        await shoot(
          tester,
          'player-$suffix',
          themed(
            TranscriptPlayerScreen(
              title: 'Rapat Koordinasi Triwulan',
              durationSeconds: 2460,
              segments: _segments,
            ),
            mode,
          ),
        );
      });

      testWidgets('settings', (tester) async {
        await shoot(
          tester,
          'settings-$suffix',
          themed(const SettingsScreen(), mode),
        );
      });

      testWidgets('onboarding', (tester) async {
        await shoot(
          tester,
          'onboarding-$suffix',
          themed(
            OnboardingScreen(
              state: const OnboardingState(
                quick: DownloadProgress(
                  status: DownloadStatus.ready,
                  progress: 1,
                  title: 'Model Cepat',
                  subtitle: 'Teks muncul lebih dulu saat rapat berjalan.',
                  size: '142 MB',
                ),
                accurate: DownloadProgress(
                  status: DownloadStatus.downloading,
                  progress: 0.42,
                  title: 'Model Akurat',
                  subtitle: 'Dipakai untuk memperhalus transkrip setelahnya.',
                  size: '548 MB',
                ),
              ),
              onContinue: () {},
              onRetryQuick: () {},
              onRetryAccurate: () {},
            ),
            mode,
          ),
        );
      });
    });
  }
}

/// A short, real-shaped transcript. Indonesian meeting speech with two
/// speakers, so the speaker colours, the mono timestamps and the reading
/// measure are all exercised.
final _segments = <TranscriptSegment>[
  _seg(
    'Pembicara 1',
    'Selamat pagi, kita mulai rapat koordinasi triwulan ketiga.',
    0,
  ),
  _seg(
    'Pembicara 1',
    'Agenda pertama adalah pagu indikatif dan penyerapan anggaran.',
    4.6,
  ),
  _seg(
    'Pembicara 2',
    'Baik, penyerapan sampai akhir September berada di angka enam puluh '
        'delapan persen.',
    9.2,
  ),
  _seg(
    'Pembicara 2',
    'Sisanya terkonsentrasi di belanja modal yang kontraknya baru selesai '
        'bulan lalu.',
    15.8,
  ),
  _seg(
    'Pembicara 1',
    'Berarti kita perlu jadwal penyerapan mingguan sampai akhir tahun.',
    22.4,
  ),
  _seg(
    'Pembicara 2',
    'Setuju. Saya siapkan draf jadwalnya dan kirim sebelum Jumat.',
    28.0,
  ),
];

TranscriptSegment _seg(String speaker, String text, double at) =>
    TranscriptSegment(
      source: 'mic',
      speaker: speaker,
      text: text,
      timestamp: at,
      duration: 4,
      language: 'id',
      confidence: 0.93,
      isPartial: false,
    );

/// Satisfies the `audioplayers` plugin's platform channels.
///
/// The transcript player creates an `AudioPlayer` as soon as it builds, and a
/// widget test has no plugin behind it. Without these stubs the player golden
/// fails on a MissingPluginException before it has drawn anything.
void _stubAudioPlayers() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      return switch (call.method) {
        'getDuration' || 'getCurrentPosition' => 0,
        _ => null,
      };
    });
  }
  for (final name in [
    'xyz.luan/audioplayers/events',
    'xyz.luan/audioplayers.global/events',
  ]) {
    messenger.setMockStreamHandler(
      EventChannel(name),
      MockStreamHandler.inline(
        onListen: (arguments, sink) => sink.endOfStream(),
      ),
    );
  }
}
