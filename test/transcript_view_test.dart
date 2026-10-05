import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/widgets/transcript_view.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/theme/app_colors.dart';

void main() {
  testWidgets('TranscriptView renders segments and filters search', (
    tester,
  ) async {
    final segments = [
      const TranscriptSegment(
        source: 'mic',
        speaker: 'A',
        text: 'Halo',
        timestamp: 0.0,
        duration: 1.0,
        language: 'id',
        confidence: 1.0,
        isPartial: false,
      ),
      const TranscriptSegment(
        source: 'mic',
        speaker: 'B',
        text: 'Hello',
        timestamp: 1.5,
        duration: 1.0,
        language: 'en',
        confidence: 1.0,
        isPartial: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[AppColors.light],
        ),
        home: Scaffold(body: TranscriptView(segments: segments)),
      ),
    );
    // Clear any exception from didUpdateWidget's animateTo before layout;
    // then settle so post-frame callbacks complete.
    await tester.pump();
    tester.takeException();
    await tester.pumpAndSettle();
    // Speaker labels + avatar initials render twice per segment.
    expect(find.text('2 segmen'), findsOneWidget);
    expect(find.text('A'), findsNWidgets(2));
    expect(find.text('B'), findsNWidgets(2));

    // Test Search — filter hides non-matching segments
    await tester.enterText(find.byType(TextField), 'Halo');
    await tester.pump(kTranscriptSearchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNWidgets(2));
    expect(find.text('B'), findsNothing);
  });

  group('tail "sementara" (LocalAgreement-2)', () {
    const committed = TranscriptSegment(
      source: 'mic',
      speaker: 'A',
      text: 'Selamat pagi semuanya',
      timestamp: 0.0,
      duration: 1.0,
      language: 'id',
      confidence: 1.0,
      isPartial: false,
    );

    Widget wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: <ThemeExtension<dynamic>>[AppColors.light]),
      home: Scaffold(body: child),
    );

    testWidgets('uncommitted words render, labelled as provisional', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const TranscriptView(
            segments: [committed],
            tentativeText: 'kita bahas anggaran',
          ),
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pumpAndSettle();

      // The marker and the words are two spans of one `Text.rich`, so the
      // assertion is on the line they build together: the words are shown
      // — withholding them would make the live preview lag the speaker by
      // a whole hypothesis — and they are marked, because the policy may
      // still contradict them.
      expect(
        find.text('sementara · kita bahas anggaran', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('an empty tail shows no provisional line at all', (
      tester,
    ) async {
      // What fixed chunking sends on every commit, and what the LA2 path
      // sends at an utterance end. A stale "sementara" row left behind
      // after the words were committed would read as a duplicate line.
      await tester.pumpWidget(
        wrap(const TranscriptView(segments: [committed], tentativeText: '')),
      );
      await tester.pump();
      tester.takeException();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('sementara · ', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('the provisional tail is announced as not final', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          const TranscriptView(
            segments: [committed],
            tentativeText: 'kita bahas anggaran',
          ),
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pumpAndSettle();

      // A screen-reader user must not be told a provisional word is
      // transcript text; the distinction is invisible to them otherwise.
      //
      // Matched as a pattern rather than an exact label: this node merges
      // with its neighbours, so the exact-string form of the finder reads
      // the merged label and never matches.
      expect(
        find.bySemanticsLabel(
          RegExp(r'Sementara, belum final: kita bahas anggaran'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
