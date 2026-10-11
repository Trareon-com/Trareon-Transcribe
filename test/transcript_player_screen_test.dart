import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/transcript_player_screen.dart';
import 'package:transcribe/state/meeting_templates.dart';
import 'package:transcribe/widgets/transcript_view.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/theme/app_icons.dart';

import 'test_helpers.dart';

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

  testWidgets('renders title, transcript, and speed control', (
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

    expect(find.byIcon(AppIcons.playFilled), findsOneWidget);
    expect(find.byIcon(AppIcons.pauseFilled), findsNothing);
    expect(find.text('1.0x'), findsOneWidget);
  });

  // Editing in the player is inline and keyboard-driven since F20: a
  // click selects the row, Enter opens the editor in place, Enter saves
  // and Esc abandons. The modal "Edit Transkrip" dialog stays only in the
  // live-recording view, which cannot do the structural edits.
  testWidgets('Enter on a selected row edits it in place and saves', (
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
    // No modal: the click selected the row.
    expect(find.text('Edit Transkrip'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Halo semua, selamat pagi',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(findRichText('Halo semua, selamat pagi'), findsOneWidget);
    expect(findRichText('Halo semua'), findsNothing);
  });

  testWidgets('Esc abandons an inline edit', (WidgetTester tester) async {
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
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'diubah tapi dibatalkan',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
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
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Halo semua, selamat pagi',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(updatedSegments, isNotNull);
    expect(updatedSegments!.single.text, 'Halo semua, selamat pagi');
  });

  testWidgets('transcript view live search filters matching segments', (
    WidgetTester tester,
  ) async {
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

  group('save as template (F24)', () {
    const multiSpeakerSegments = [
      TranscriptSegment(
        source: 'mic',
        speaker: 'Budi Santoso',
        text: 'Mari kita mulai.',
        timestamp: 0,
        duration: 2,
        language: 'id',
        confidence: 0.9,
        isPartial: false,
      ),
      TranscriptSegment(
        source: 'speaker',
        speaker: 'Sari Wulandari',
        text: 'Siap.',
        timestamp: 2,
        duration: 1,
        language: 'id',
        confidence: 0.9,
        isPartial: false,
      ),
    ];

    testWidgets(
      'saves the title and renamed speakers as a reusable template',
      (tester) async {
        // Bounded pump()s rather than pumpAndSettle(): this screen's
        // playback position stream keeps scheduling frames and never
        // "settles", the same reason every other test in this file
        // avoids it too.
        await tester.pumpWidget(
          buildTestAppWithOverrides(
            overrides: [
              meetingTemplatesProvider.overrideWith(
                (ref) => MeetingTemplateNotifier(
                  store: InMemoryTemplateStore(),
                ),
              ),
            ],
            child: const TranscriptPlayerScreen(
              title: 'Rapat Anggaran Mingguan',
              durationSeconds: 120,
              segments: multiSpeakerSegments,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byTooltip('Simpan sebagai template rapat'));
        await tester.pump();
        await tester.pump();

        expect(
          find.textContaining('Template "Rapat Anggaran Mingguan" disimpan'),
          findsOneWidget,
        );

        // Let the confirmation toast's dismissal timer expire.
        await tester.pump(const Duration(seconds: 4));
      },
    );
  });
}
