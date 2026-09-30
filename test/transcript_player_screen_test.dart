import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/transcript_player_screen.dart';
import 'package:transcribe/widgets/transcript_view.dart';
import 'package:transcribe/state/models.dart';

/// Find text inside [RichText] widgets which [find.text] does not match.
///
/// Segment text in [TranscriptView] is rendered via [RichText] inside
/// [_SegmentTile], so we need a custom predicate to locate it.
Finder findRichText(String text) => find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == text,
    );

void main() {
  const segments = [
    TranscriptSegment(
      source: 'mic',
      speaker: 'MIC',
      text: 'Halo semua',
      timestamp: 0,
      duration: 2,
      language: 'id',
      confidence: 0.9,
      isPartial: false,
    ),
  ];

  testWidgets('renders title, transcript, and speed control', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: segments,
        ),
      ),
    );

    expect(find.text('Rapat Q3'), findsOneWidget);
    expect(findRichText('Halo semua'), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);
  });

  testWidgets('shows playback controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: segments,
        ),
      ),
    );

    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
    expect(find.text('1.0x'), findsOneWidget);
  });

  testWidgets('tapping a segment opens edit dialog and saves new text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: segments,
        ),
      ),
    );

    await tester.tap(findRichText('Halo semua'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Transkrip'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Halo semua, selamat pagi');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(findRichText('Halo semua, selamat pagi'), findsOneWidget);
    expect(findRichText('Halo semua'), findsNothing);
  });

  testWidgets('canceling edit dialog keeps original text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: segments,
        ),
      ),
    );

    await tester.tap(findRichText('Halo semua'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'diubah tapi dibatalkan');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(findRichText('Halo semua'), findsOneWidget);
  });

  testWidgets('editing a segment notifies listeners with updated segments', (
    WidgetTester tester,
  ) async {
    List<TranscriptSegment>? updatedSegments;
    await tester.pumpWidget(
      MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: segments,
          onSegmentsChanged: (value) => updatedSegments = value,
        ),
      ),
    );

    await tester.tap(findRichText('Halo semua'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Halo semua, selamat pagi');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(updatedSegments, isNotNull);
    expect(updatedSegments!.single.text, 'Halo semua, selamat pagi');
  });

  testWidgets('transcript view live search filters matching segments', (WidgetTester tester) async {
    const multiSegments = [
      TranscriptSegment(
        source: 'mic',
        speaker: 'MIC',
        text: 'Agenda pertama adalah budgeting',
        timestamp: 0,
        duration: 2,
        language: 'id',
        confidence: 0.9,
        isPartial: false,
      ),
      TranscriptSegment(
        source: 'spk',
        speaker: 'SPK',
        text: 'Agenda kedua adalah roadmap',
        timestamp: 2,
        duration: 2,
        language: 'id',
        confidence: 0.9,
        isPartial: false,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: multiSegments,
        ),
      ),
    );

    expect(findRichText('Agenda pertama adalah budgeting'), findsOneWidget);
    expect(findRichText('Agenda kedua adalah roadmap'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'budgeting');
    // The search box debounces (kTranscriptSearchDebounce) so a 5 000-segment
    // transcript is not re-filtered on every keystroke.
    await tester.pump(kTranscriptSearchDebounce);
    await tester.pumpAndSettle();

    expect(findRichText('Agenda pertama adalah budgeting'), findsOneWidget);
    expect(findRichText('Agenda kedua adalah roadmap'), findsNothing);
    // Search count not shown in new design
  });
}
