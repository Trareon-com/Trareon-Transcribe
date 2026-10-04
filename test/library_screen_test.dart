import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/library_screen.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/theme/app_icons.dart';

void main() {
  testWidgets('empty library shows placeholder message', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada sesi tersimpan'), findsOneWidget);
  });

  testWidgets('lists sessions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const sessions = [
      SessionSummary(
        id: '1',
        title: 'Rapat Q3',
        date: '2026-07-25',
        durationSeconds: 1800,
        segmentsCount: 42,
        segments: [
          TranscriptSegment(
            source: 'mic', speaker: 'MIC', text: 'Halo semua',
            timestamp: 0, duration: 2, language: 'id', confidence: 0.9, isPartial: false,
          ),
        ],
      ),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));
    await tester.pumpAndSettle();

    expect(find.text('Rapat Q3'), findsOneWidget);
    expect(find.text('30 menit'), findsOneWidget);
    expect(find.text('42 segmen'), findsOneWidget);
  });

  testWidgets('search filters sessions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const sessions = [
      SessionSummary(id: '1', title: 'Rapat Q3', date: '2026-07-25', durationSeconds: 1800, segmentsCount: 1),
      SessionSummary(id: '2', title: 'Standup Harian', date: '2026-07-25', durationSeconds: 600, segmentsCount: 5),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Rapat');
    await tester.pumpAndSettle();

    expect(find.text('Rapat Q3'), findsOneWidget);
    expect(find.text('Standup Harian'), findsNothing);
  });

  testWidgets('delete session shows undo snackbar', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const sessions = [
      SessionSummary(id: '1', title: 'Rapat Q3', date: '2026-07-25', durationSeconds: 1800, segmentsCount: 1),
    ];
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(sessions: sessions)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();

    expect(find.textContaining('dihapus'), findsOneWidget);
    expect(find.text('Urungkan'), findsOneWidget);
  });

  test('buildSessionShareText produces correct output', () {
    const session = SessionSummary(
      id: '1',
      title: 'Rapat Q3',
      date: '2026-07-25',
      durationSeconds: 1800,
      segmentsCount: 2,
      segments: [
        TranscriptSegment(
          source: 'mic', speaker: 'MIC', text: 'Halo semua',
          timestamp: 0, duration: 2, language: 'id', confidence: 0.9, isPartial: false,
        ),
      ],
    );
    final text = buildSessionShareText(session);
    expect(text, contains('MIC: Halo semua'));
    expect(text, contains('Rapat Q3'));
    expect(text, contains('2026-07-25'));
  });
}
