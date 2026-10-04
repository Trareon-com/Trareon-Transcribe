/// "Kelola Pembicara" (F10) and the remembered-name store.
///
/// Merge and rename compose inside the dialog before anything touches
/// the transcript, so what these tests pin is the composition: that two
/// labels merged become one, that a rename onto an existing name is a
/// merge rather than a duplicate, and that what gets remembered is keyed
/// by the *engine's* label — not by the name the user just typed, which
/// would match nothing ever again.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/dart_prefs.dart';
import 'package:transcribe/services/speaker_aliases.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/widgets/speaker_manager_dialog.dart';

TranscriptSegment _seg(
  String speaker,
  double timestamp, {
  double duration = 3,
  bool partial = false,
}) =>
    TranscriptSegment(
      source: 'spk',
      speaker: speaker,
      text: 'kalimat',
      timestamp: timestamp,
      duration: duration,
      language: 'id',
      confidence: 0.9,
      isPartial: partial,
    );

/// The dialog, pumped and ready to drive.
Future<List<SpeakerAction>?> _openManager(
  WidgetTester tester,
  List<TranscriptSegment> segments,
) async {
  List<SpeakerAction>? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await showSpeakerManager(context, segments: segments);
          },
          child: const Text('buka'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('speakersIn', () {
    test('counts segments and seconds, most-spoken first', () {
      final speakers = speakersIn([
        _seg('Peserta 2', 0, duration: 10),
        _seg('Saya', 10, duration: 40),
        _seg('Peserta 2', 50, duration: 5),
      ]);
      expect(speakers.map((s) => s.label), ['Saya', 'Peserta 2']);
      expect(speakers.first.segments, 1);
      expect(speakers.first.seconds, 40);
      expect(speakers.last.segments, 2);
      expect(speakers.last.seconds, 15);
    });

    test('partials do not count towards anyone', () {
      final speakers = speakersIn([
        _seg('Saya', 0, duration: 1),
        _seg('Peserta 2', 1, duration: 100, partial: true),
      ]);
      // A speaker whose only line is a live partial said nothing final.
      expect(speakers.map((s) => s.label), ['Saya']);
    });

    test('an unlabelled segment falls back to its source', () {
      final speakers = speakersIn([_seg('', 0)]);
      expect(speakers.single.label, 'spk');
    });
  });

  group('remembered names', () {
    setUp(() async {
      // DartPrefs is a singleton over a file the test environment has no
      // path for; load() swallows that and starts empty, which is the
      // clean slate these tests want.
      await DartPrefs.instance.load();
      await forgetAllSpeakerAliases();
    });

    test('a name is remembered under the engine label, not the new name',
        () async {
      await rememberSpeakerAlias('Peserta 2', 'Pak Budi');
      expect(readSpeakerAliases(), {'Peserta 2': 'Pak Budi'});
      // Next session: the engine produces "Peserta 2" again, so that is
      // the only key that can match.
      expect(suggestionsFor(['Peserta 2', 'Peserta 3']), {
        'Peserta 2': 'Pak Budi',
      });
      expect(suggestionsFor(['Pak Budi']), isEmpty);
    });

    test('remembering a label as itself forgets it', () async {
      await rememberSpeakerAlias('Peserta 2', 'Pak Budi');
      await rememberSpeakerAlias('Peserta 2', 'Peserta 2');
      expect(readSpeakerAliases(), isEmpty);
    });

    test('a blank name forgets rather than storing an empty string',
        () async {
      await rememberSpeakerAlias('Saya', 'Ibu Sari');
      await rememberSpeakerAlias('Saya', '   ');
      expect(readSpeakerAliases(), isEmpty);
    });

    test('a corrupt prefs value does not stop the player opening', () async {
      DartPrefs.instance.setString(kSpeakerAliasesKey, 'bukan json');
      expect(readSpeakerAliases(), isEmpty);
      DartPrefs.instance.setString(kSpeakerAliasesKey, '{"a": 5, "": "x"}');
      expect(readSpeakerAliases(), isEmpty);
    });
  });

  group('the dialog', () {
    setUp(() async {
      await DartPrefs.instance.load();
      await forgetAllSpeakerAliases();
    });

    testWidgets('merging two speakers returns one merge action',
        (tester) async {
      final segments = [
        _seg('Peserta 2', 0, duration: 30),
        _seg('Peserta 4', 30, duration: 10),
      ];
      await _openManager(tester, segments);

      expect(find.text('Peserta 2'), findsOneWidget);
      expect(find.text('Peserta 4'), findsOneWidget);

      // Merge the smaller one into the larger.
      await tester.tap(find.byTooltip('Gabungkan dengan pembicara lain').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Peserta 2 ('));
      await tester.pumpAndSettle();

      // One row left, and its counts are the sum.
      expect(find.text('Peserta 4'), findsNothing);
      expect(find.textContaining('2 segmen'), findsOneWidget);
      expect(find.textContaining('1 perubahan menunggu'), findsOneWidget);
    });

    testWidgets('merge is unavailable when there is only one speaker',
        (tester) async {
      await _openManager(tester, [_seg('Saya', 0)]);
      final button = tester.widget<IconButton>(
        find.byTooltip('Tidak ada pembicara lain untuk digabung'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Terapkan is disabled until something has changed',
        (tester) async {
      await _openManager(tester, [
        _seg('Saya', 0),
        _seg('Peserta 2', 5),
      ]);
      final apply = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Terapkan'),
      );
      expect(apply.onPressed, isNull);
    });

    testWidgets('a remembered name is offered, not applied', (tester) async {
      await rememberSpeakerAlias('Peserta 2', 'Pak Budi');
      await _openManager(tester, [_seg('Peserta 2', 0)]);

      // Offered…
      expect(
        find.textContaining('Diingat dari rapat sebelumnya: Pak Budi'),
        findsOneWidget,
      );
      // …and the transcript still says what the engine said.
      expect(find.text('Peserta 2'), findsOneWidget);
      expect(find.text('Pak Budi'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Pakai'));
      await tester.pumpAndSettle();
      expect(find.text('Pak Budi'), findsOneWidget);
      expect(find.textContaining('1 perubahan menunggu'), findsOneWidget);
    });

    testWidgets('renaming onto an existing name merges instead of duplicating',
        (tester) async {
      await rememberSpeakerAlias('Peserta 4', 'Pak Budi');
      await _openManager(tester, [
        _seg('Pak Budi', 0, duration: 20),
        _seg('Peserta 4', 20, duration: 10),
      ]);

      await tester.tap(find.widgetWithText(TextButton, 'Pakai'));
      await tester.pumpAndSettle();

      // One "Pak Budi", not two.
      expect(find.text('Pak Budi'), findsOneWidget);
      expect(find.text('Peserta 4'), findsNothing);
      expect(find.textContaining('2 segmen'), findsOneWidget);
    });
  });
}
