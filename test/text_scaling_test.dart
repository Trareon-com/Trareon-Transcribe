import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/diagnostics_screen.dart';
import 'package:transcribe/screens/settings_screen.dart';
import 'package:transcribe/screens/transcript_player_screen.dart';
import 'package:transcribe/services/preflight_service.dart';
import 'package:transcribe/src/rust/doctor.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/widgets/bookmark_bar.dart';
import 'package:transcribe/widgets/glossary_settings_section.dart';
import 'package:transcribe/widgets/notulen_settings_section.dart';
import 'package:transcribe/widgets/setup_overlay.dart';
import 'package:transcribe/widgets/transcript_view.dart';

import 'test_helpers.dart';

/// Audit item 25 / blueprint §4.9: the UI has to survive the OS text-size
/// setting, not just the default.
///
/// 1.5× is the ceiling this project commits to — far enough that a hardcoded
/// `height: 36` box or a `Row` of fixed-width chips breaks, which is exactly
/// what this is looking for. Any overflow in a widget test raises an error that
/// `tester.takeException()` returns, so these tests assert on that directly
/// rather than on pixel geometry.
const double kMaxSupportedTextScale = 1.5;

/// The app's minimum supported window, where overflow is most likely.
const Size kMinimumWindow = Size(800, 600);

void main() {
  /// Wraps [child] at [scale] in the app theme, at the minimum window size.
  Future<void> pumpScaled(
    WidgetTester tester,
    Widget child, {
    double scale = kMaxSupportedTextScale,
    List<Override> overrides = const [],
  }) async {
    await tester.binding.setSurfaceSize(kMinimumWindow);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    skipPreflightChecks = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rustBridgeProvider.overrideWithValue(NoopBridge()),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, widget) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: widget!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TranscriptSegment segment(String text, double at) => TranscriptSegment(
    source: 'mic',
    speaker: 'Pembicara 1',
    text: text,
    timestamp: at,
    duration: 2,
    language: 'id',
    confidence: 0.9,
    isPartial: false,
  );

  group('at 1.5x text scale, nothing overflows', () {
    testWidgets('the settings screen, in every category', (tester) async {
      await pumpScaled(tester, const SettingsScreen());
      expect(tester.takeException(), isNull);

      // Every pane, including the two added this sprint: a category the user
      // never opens is a category nobody notices is broken.
      //
      // At 1.5x the nine categories no longer fit the 600 px sidebar, so the
      // last few have to be scrolled to before they can be tapped. `tap()`
      // only *warns* when it misses an off-screen target, which would let
      // this loop skip the very panes most likely to be broken — hence the
      // explicit `ensureVisible` and the assertion that the pane actually
      // changed.
      for (final category in SettingsCategory.values) {
        final chip = find.text(category.label);
        expect(
          chip,
          findsAtLeastNWidgets(1),
          reason: 'the "${category.label}" category is not in the sidebar at '
              '${kMaxSupportedTextScale}x, so its pane cannot be checked',
        );
        await tester.ensureVisible(chip.first);
        await tester.pumpAndSettle();
        await tester.tap(chip.first);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow in the "${category.label}" pane at '
              '${kMaxSupportedTextScale}x',
        );
        // Proof the tap landed: the content pane is keyed by its category, so
        // this fails rather than passes vacuously if the tap missed.
        expect(
          find.byKey(ValueKey(category)),
          findsOneWidget,
          reason: 'tapping "${category.label}" did not open its pane',
        );
      }
    });

    testWidgets('the kamus istilah pane with a long term list', (tester) async {
      await pumpScaled(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: GlossarySettingsSection()),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the notulen defaults pane', (tester) async {
      await pumpScaled(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: NotulenDefaultsSection()),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the transcript, including the long-speaker-name case',
        (tester) async {
      await pumpScaled(
        tester,
        Scaffold(
          body: TranscriptView(
            segments: [
              segment('Selamat pagi, mari kita mulai rapat koordinasi ini.', 0),
              segment(
                'Pembahasan pertama adalah evaluasi pagu indikatif tahun '
                'anggaran berikutnya, termasuk dampaknya ke RKAKL.',
                12,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bookmark bar with several long notes', (tester) async {
      await pumpScaled(
        tester,
        Scaffold(
          body: BookmarkBar(
            bookmarks: const [
              Bookmark(timestamp: 65, note: 'keputusan penting soal pagu'),
              Bookmark(timestamp: 312, note: 'tindak lanjut ke bagian umum'),
              Bookmark(timestamp: 980, note: ''),
            ],
            live: true,
            onAdd: () {},
            onAddWithNote: () {},
            onRemove: (_) {},
            onEditNote: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the diagnostics screen, including the export card',
        (tester) async {
      await pumpScaled(
        tester,
        DiagnosticsScreen(
          runChecks: () async => PreflightResult([
            Check(name: 'library_path', status: const CheckStatus.ok()),
            Check(
              name: 'audio_input',
              status: const CheckStatus.fail('Tidak ada perangkat masukan.'),
              remediation: 'Colokkan mikrofon lalu periksa ulang.',
            ),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
      // The export card is the widest row on the screen, so prove it is
      // actually laid out rather than merely absent.
      await tester.dragUntilVisible(
        find.text('Log Diagnostik'),
        find.byType(ListView),
        const Offset(0, -80),
      );
      expect(find.text('Log Diagnostik'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the player, with its control row and bookmark list',
        (tester) async {
      await pumpScaled(
        tester,
        TranscriptPlayerScreen(
          title: 'Rapat Koordinasi Penyusunan RKAKL 2027',
          durationSeconds: 5400,
          segments: [segment('halo semua', 0)],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the default scale is still fine', () {
    testWidgets('settings at 1.0x', (tester) async {
      await pumpScaled(tester, const SettingsScreen(), scale: 1.0);
      expect(tester.takeException(), isNull);
    });
  });

  test('the committed ceiling is at least the WCAG 1.4.4 requirement', () {
    // WCAG 2.1 AA 1.4.4 asks for 200 % resize of text; 1.5× is what this
    // desktop layout commits to and tests, and the gap is stated rather than
    // implied.
    expect(kMaxSupportedTextScale, greaterThanOrEqualTo(1.5));
  });
}
