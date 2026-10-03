import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/widgets/animated_record_button.dart';
import 'package:transcribe/widgets/empty_state.dart';
import 'package:transcribe/widgets/mode_selector.dart';

import 'test_helpers.dart';

/// 800x600 is the app's smallest supported window (see `linux/`/`macos/`
/// minimum window size). Controls that run off the right edge there are
/// invisible *and* unclickable, with no scroll affordance to hint at it —
/// the toolbar used to lose "Pengeras Suara" behind Ekspor exactly this way
/// (b01465a). These tests pin the guarantee to the layout Sprint 2 shipped
/// rather than to that commit's specific widget tree.
void main() {
  /// Fails if any part of [finder]'s widget is outside the window, or if
  /// the frame reported an overflow.
  void expectFullyOnScreen(
    WidgetTester tester,
    Finder finder,
    String label,
  ) {
    expect(finder, findsOneWidget, reason: '$label must be in the tree');
    final rect = tester.getRect(finder);
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      rect.left >= -0.01 &&
          rect.top >= -0.01 &&
          rect.right <= window.width + 0.01 &&
          rect.bottom <= window.height + 0.01,
      isTrue,
      reason: '$label is clipped: $rect does not fit in $window',
    );
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(800, 600),
    Size(900, 700),
    Size(1024, 768),
  ]) {
    testWidgets(
      'every control stays on screen and clickable at ${size.width.toInt()}x'
      '${size.height.toInt()}',
      (WidgetTester tester) async {
        await pumpAt(tester, size);

        // The record button is the one action the screen exists for.
        expectFullyOnScreen(
          tester,
          find.byType(AnimatedRecordButton),
          'the record button',
        );
        expectFullyOnScreen(tester, find.byType(ModeSelector), 'the mode selector');
        // Both device toggles, not just the microphone: the system-audio
        // one (then labelled "Pengeras Suara") is the one that used to
        // disappear off the right edge behind Ekspor.
        expectFullyOnScreen(tester, find.text('Mikrofon'), 'the microphone toggle');
        expectFullyOnScreen(
          tester,
          find.text('Suara sistem'),
          'the speaker toggle',
        );

        // A hit test that lands on the record button, rather than on
        // whatever is painted over it.
        await tester.tap(find.byType(AnimatedRecordButton), warnIfMissed: true);
        await tester.pump();

        // `pumpAndSettle` does not fail on overflow, it only prints; this is
        // what actually fails the test if a Row/Wrap overflowed.
        expect(
          tester.takeException(),
          isNull,
          reason: 'no layout overflow at $size',
        );
      },
    );
  }

  group('EmptyState in a short pane', () {
    Future<void> pumpIn(WidgetTester tester, double height) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 540,
                height: height,
                child: const EmptyState(
                  icon: Icons.mic_none_outlined,
                  title: 'Belum ada transkrip',
                  subtitle:
                      'Transkrip akan muncul di sini begitu ada suara yang '
                      'terdeteksi dan selesai diproses.',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('fits a 140px pane without overflowing', (tester) async {
      // 140px is what the transcript pane gets at 800x600 while a session
      // is starting. The full-size layout needs ~220px.
      await pumpIn(tester, 140);
      expect(tester.takeException(), isNull);
      expect(find.text('Belum ada transkrip'), findsOneWidget);
    });

    testWidgets('keeps the glyph when there is room for it', (tester) async {
      await pumpIn(tester, 400);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
      expect(find.text('Belum ada transkrip'), findsOneWidget);
    });

    testWidgets('scrolls rather than clipping a very short pane', (tester) async {
      await pumpIn(tester, 40);
      expect(tester.takeException(), isNull);
      // Reachable by scrolling instead of painted over the edge.
      expect(find.byType(Scrollable), findsOneWidget);
    });

    testWidgets('survives being given unbounded height', (tester) async {
      // No current caller does this — they all sit in an Expanded — but a
      // scroll view with an unbounded height throws outright, which would
      // be a worse failure than the overflow this fix is about.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Belum ada sesi tersimpan',
                  subtitle: 'Sesi transkripsi akan muncul di sini',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Belum ada sesi tersimpan'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
    });
  });
}
