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
}
