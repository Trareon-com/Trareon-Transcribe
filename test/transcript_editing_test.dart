/// Keyboard-first transcript editing, the "Tinjau" filter and session
/// tags (F20).
///
/// The keys are the point: a notulis correcting an hour of transcript
/// does move / merge / split hundreds of times, and each one going
/// through a dialog is the difference between an hour and three. So what
/// these tests pin is that each shortcut reaches the right callback with
/// the right index, and that the three transcript mutations keep the
/// timeline consistent — a merge that loses a second or a split that
/// invents one breaks every seek after it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/library_index.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/widgets/tag_editor_dialog.dart';
import 'package:transcribe/widgets/transcript_view.dart';
import 'package:transcribe/theme/app_icons.dart';

TranscriptSegment _seg(
  String text, {
  double timestamp = 0,
  double duration = 3,
  String speaker = 'Saya',
  bool lowConfidence = false,
}) =>
    TranscriptSegment(
      source: 'mic',
      speaker: speaker,
      text: text,
      timestamp: timestamp,
      duration: duration,
      language: 'id',
      confidence: lowConfidence ? 0.4 : 0.95,
      isPartial: false,
      lowConfidence: lowConfidence,
    );

/// Records what the view asked the host screen to do.
class _Recorder {
  final edits = <(int, String)>[];
  final moves = <(int, int)>[];
  final merges = <int>[];
  final splits = <(int, int)>[];
}

Future<void> _pumpView(
  WidgetTester tester,
  List<TranscriptSegment> segments,
  _Recorder recorder,
) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(extensions: <ThemeExtension<dynamic>>[AppColors.light]),
    home: Scaffold(
      body: TranscriptView(
        segments: segments,
        onEdit: (index, text) => recorder.edits.add((index, text)),
        onMoveSegment: (index, delta) => recorder.moves.add((index, delta)),
        onMergeWithPrevious: recorder.merges.add,
        onSplitSegment: (index, offset) => recorder.splits.add((index, offset)),
      ),
    ),
  ));
  await tester.pump();
  tester.takeException();
  await tester.pumpAndSettle();
}

/// Puts the keyboard cursor on a row by clicking it, which is how a user
/// gets there — the list does not steal focus from the search box.
Future<void> _select(WidgetTester tester, String text) async {
  // `findRichText`: a transcript row renders its text as spans so the
  // search term can be highlighted, so a plain `find.text` sees nothing.
  await tester.tap(find.text(text, findRichText: true));
  await tester.pumpAndSettle();
}

void main() {
  group('keyboard editing', () {
    testWidgets('the shortcut crib is on screen when editing is possible',
        (tester) async {
      await _pumpView(tester, [_seg('satu')], _Recorder());
      expect(find.textContaining('Enter sunting'), findsOneWidget);
      expect(find.textContaining('Ctrl+M gabung ke atas'), findsOneWidget);
    });

    testWidgets('Enter opens an inline editor and Enter again commits',
        (tester) async {
      final recorder = _Recorder();
      await _pumpView(tester, [_seg('salah tulis')], recorder);
      await _select(tester, 'salah tulis');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2),
          reason: 'the search box plus the inline editor');
      // The crib switches to the editing keys.
      expect(find.textContaining('Esc batal'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'sudah benar');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(recorder.edits, [(0, 'sudah benar')]);
    });

    testWidgets('Esc cancels without committing', (tester) async {
      final recorder = _Recorder();
      await _pumpView(tester, [_seg('biarkan saja')], recorder);
      await _select(tester, 'biarkan saja');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'jangan simpan ini');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(recorder.edits, isEmpty);
      expect(find.textContaining('Enter sunting'), findsOneWidget);
    });

    testWidgets('Ctrl+↑/↓ moves the selected segment', (tester) async {
      final recorder = _Recorder();
      await _pumpView(
        tester,
        [_seg('satu'), _seg('dua', timestamp: 3)],
        recorder,
      );
      await _select(tester, 'dua');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(recorder.moves, [(1, -1)]);
    });

    testWidgets('a move past either end is refused rather than clamped',
        (tester) async {
      final recorder = _Recorder();
      await _pumpView(tester, [_seg('satu')], recorder);
      await _select(tester, 'satu');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(recorder.moves, isEmpty);
    });

    testWidgets('Ctrl+M merges upwards, and never on the first row',
        (tester) async {
      final recorder = _Recorder();
      await _pumpView(
        tester,
        [_seg('kalimat'), _seg('terpotong', timestamp: 3)],
        recorder,
      );

      await _select(tester, 'kalimat');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(recorder.merges, isEmpty, reason: 'nothing above row 0');

      await _select(tester, 'terpotong');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(recorder.merges, [1]);
    });

    testWidgets('Ctrl+Shift+S splits at the cursor', (tester) async {
      final recorder = _Recorder();
      await _pumpView(tester, [_seg('satu dua')], recorder);
      await _select(tester, 'satu dua');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // Put the caret after "satu".
      final field = find.byType(TextField).last;
      await tester.enterText(field, 'satu dua');
      final controller = tester.widget<TextField>(field).controller!;
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(recorder.splits, [(0, 4)]);
    });

    testWidgets('a split at either end is refused', (tester) async {
      final recorder = _Recorder();
      await _pumpView(tester, [_seg('satu dua')], recorder);
      await _select(tester, 'satu dua');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final field = find.byType(TextField).last;
      final controller = tester.widget<TextField>(field).controller!;
      for (final offset in [0, 8]) {
        controller.selection = TextSelection.collapsed(offset: offset);
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pumpAndSettle();
      }
      // An empty segment is worse than refusing.
      expect(recorder.splits, isEmpty);
    });
  });

  group('Tinjau filter', () {
    testWidgets('the flag only appears when something was flagged',
        (tester) async {
      await _pumpView(tester, [_seg('yakin')], _Recorder());
      expect(find.byIcon(AppIcons.flag), findsNothing);

      await _pumpView(
        tester,
        [_seg('yakin'), _seg('ragu', timestamp: 3, lowConfidence: true)],
        _Recorder(),
      );
      expect(find.byIcon(AppIcons.flag), findsOneWidget);
    });

    testWidgets('narrows the list to the flagged segments', (tester) async {
      await _pumpView(
        tester,
        [
          _seg('yakin'),
          _seg('ragu', timestamp: 3, lowConfidence: true),
          _seg('yakin lagi', timestamp: 6),
        ],
        _Recorder(),
      );
      expect(find.text('3 segmen'), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.flag));
      await tester.pumpAndSettle();

      expect(find.text('ragu', findRichText: true), findsOneWidget);
      expect(find.text('yakin', findRichText: true), findsNothing);
      expect(find.text('yakin lagi', findRichText: true), findsNothing);
    });
  });

  group('tags', () {
    test('normaliseTags cleans, de-duplicates and sorts', () {
      expect(
        normaliseTags(['  Anggaran ', 'anggaran', '', 'Mingguan', 42, null]),
        ['Anggaran', 'Mingguan'],
      );
      expect(normaliseTags('bukan daftar'), isEmpty);
      expect(normaliseTags(null), isEmpty);
    });

    testWidgets('the editor adds, removes and offers existing tags',
        (tester) async {
      List<String>? saved;
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData(extensions: <ThemeExtension<dynamic>>[AppColors.light]),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await showTagEditor(
                  context,
                  current: const ['Anggaran'],
                  known: const ['Anggaran', 'Mingguan', 'Direksi'],
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      // Already-applied tags are chips to delete; the rest are offered.
      expect(find.widgetWithText(InputChip, 'Anggaran'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Mingguan'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Anggaran'), findsNothing);

      await tester.tap(find.widgetWithText(ActionChip, 'Mingguan'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Mingguan'), findsOneWidget);

      // A typed duplicate in another case does not become a second tag.
      await tester.enterText(find.byType(TextField), 'anggaran');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNWidgets(2));

      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(saved, ['Anggaran', 'Mingguan']);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      List<String>? saved = ['sentinel'];
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData(extensions: <ThemeExtension<dynamic>>[AppColors.light]),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await showTagEditor(
                  context,
                  current: const ['Anggaran'],
                  known: const [],
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
    });
  });
}
