import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/widgets/karaoke_text.dart';
import 'package:transcribe/widgets/transcript_view.dart';

TranscriptWord _word(
  String text,
  double start,
  double end, [
  double prob = 0.9,
]) => TranscriptWord(word: text, start: start, end: end, prob: prob);

TranscriptSegment _segment({
  List<TranscriptWord> words = const [],
  String text = 'Selamat pagi semuanya',
}) => TranscriptSegment(
  source: 'mic',
  speaker: 'Saya',
  text: text,
  timestamp: 10,
  duration: 3,
  language: 'id',
  confidence: 0.9,
  isPartial: false,
  words: words,
);

void main() {
  group('TranscriptWord', () {
    test('contains is half-open so adjacent words never both match', () {
      // Two words that touch at 1.0 must not both be "the current word",
      // or the karaoke highlight covers two at once on every boundary.
      final first = _word('satu', 0.5, 1.0);
      final second = _word('dua', 1.0, 1.5);
      expect(first.contains(1.0), isFalse);
      expect(second.contains(1.0), isTrue);
      expect(first.contains(0.5), isTrue);
      expect(second.contains(1.5), isFalse);
    });

    test('an interpolated word makes no confidence claim', () {
      // prob 0 means "not measured" (see stt::words::interpolate_words),
      // and underlining every such word would underline whole transcripts.
      expect(_word('satu', 0, 1, 0).isLowConfidence, isFalse);
      expect(_word('satu', 0, 1, 0.3).isLowConfidence, isTrue);
      expect(_word('satu', 0, 1, kLowWordProb).isLowConfidence, isFalse);
      expect(_word('satu', 0, 1, 0.95).isLowConfidence, isFalse);
    });
  });

  group('TranscriptSegment word timings', () {
    test('wordAt finds the word being spoken', () {
      final segment = _segment(
        words: [_word('Selamat', 10, 10.5), _word('pagi', 10.5, 11)],
      );
      expect(segment.hasWordTimings, isTrue);
      expect(segment.wordAt(10.2)?.word, 'Selamat');
      expect(segment.wordAt(10.7)?.word, 'pagi');
      expect(segment.wordAt(99), isNull);
    });

    test('a segment without word timings reports so rather than guessing', () {
      expect(_segment().hasWordTimings, isFalse);
      expect(_segment().wordAt(10.2), isNull);
    });

    test('editing the text drops the word spans', () {
      // The words the user typed were never aligned to the audio. Keeping
      // the old spans would highlight the wrong word and seek to the wrong
      // place — silently, which is the worst kind.
      final segment = _segment(words: [_word('Selamat', 10, 10.5)]);
      expect(segment.copyWith(text: 'Selamat siang').words, isEmpty);
      // Renaming the speaker changes nothing about the audio.
      expect(segment.copyWith(speaker: 'Pak Budi').words, hasLength(1));
      // And a no-op "edit" is not an edit.
      expect(segment.copyWith(text: segment.text).words, hasLength(1));
    });
  });

  group('transcript.json round-trip', () {
    test('word spans survive a save and a reload', () {
      final segments = [
        _segment(
          words: [
            _word('Selamat', 10, 10.5, 0.95),
            _word('pagi', 10.5, 11.0, 0.42),
          ],
        ),
      ];
      final parsed = parseTranscriptJson(encodeTranscriptJson(segments));
      expect(parsed.single.words, hasLength(2));
      expect(parsed.single.words[1].word, 'pagi');
      expect(parsed.single.words[1].start, 10.5);
      expect(parsed.single.words[1].prob, closeTo(0.42, 1e-9));
      expect(parsed.single.words[1].isLowConfidence, isTrue);
    });

    test('a transcript written before Sprint 4b still loads', () {
      // The compatibility that matters: `words` is absent from every
      // transcript the app wrote before this sprint.
      const legacy = '''
      [{"source":"mic","speaker":"Saya","text":"halo","timestamp":1.0,
        "duration":2.0,"language":"id","confidence":0.9,
        "is_partial":false,"low_confidence":false,"avg_log_prob":-0.3}]
      ''';
      final parsed = parseTranscriptJson(legacy);
      expect(parsed, hasLength(1));
      expect(parsed.single.words, isEmpty);
      expect(parsed.single.hasWordTimings, isFalse);
    });

    test('a segment with no words omits the key rather than writing []', () {
      // Keeps the file the same shape it has always had for the sessions
      // that have no word timings.
      expect(encodeTranscriptJson([_segment()]), isNot(contains('"words"')));
    });

    test('malformed word entries are skipped, not fatal', () {
      const broken = '''
      [{"source":"mic","speaker":"Saya","text":"halo","timestamp":1.0,
        "duration":2.0,"language":"id","confidence":0.9,
        "is_partial":false,"low_confidence":false,
        "words":[{"start":1.0,"end":1.5},"bukan objek",
                 {"word":"halo","start":1.0,"end":1.5,"prob":0.8}]}]
      ''';
      final parsed = parseTranscriptJson(broken);
      expect(parsed.single.words, hasLength(1));
      expect(parsed.single.words.single.word, 'halo');
    });
  });

  group('singleWordCorrection', () {
    test('a one-word substitution is learnable', () {
      expect(
        singleWordCorrection('Tim Peka sudah rapat', 'Tim PPBJ sudah rapat'),
        ('Peka', 'PPBJ'),
      );
    });

    test('a rewritten sentence teaches nothing', () {
      // Offering to add half a rewritten sentence to the kamus would
      // train the user to dismiss the offer.
      expect(singleWordCorrection('satu dua tiga', 'empat lima enam'), isNull);
      expect(singleWordCorrection('satu dua', 'satu dua tiga'), isNull);
      expect(singleWordCorrection('satu dua tiga', 'satu tiga'), isNull);
    });

    test('an unchanged line is not a correction', () {
      expect(singleWordCorrection('satu dua', 'satu dua'), isNull);
      expect(singleWordCorrection('', ''), isNull);
    });

    test('punctuation alone is not a correction', () {
      // "anggaran" -> "anggaran." taught nothing, and a rule keyed on the
      // comma would fire on the wrong word later.
      expect(singleWordCorrection('soal anggaran', 'soal anggaran.'), isNull);
      expect(singleWordCorrection('soal anggaran', 'soal "anggaran"'), isNull);
    });

    test('surrounding punctuation is stripped from the learned pair', () {
      expect(singleWordCorrection('kata "Peka" itu', 'kata "PPBJ" itu'), (
        'Peka',
        'PPBJ',
      ));
    });

    test('whitespace changes do not shift the word index', () {
      expect(singleWordCorrection('Tim   Peka  rapat', 'Tim PPBJ rapat'), (
        'Peka',
        'PPBJ',
      ));
    });
  });

  group('KaraokeText', () {
    Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

    testWidgets('renders plain text when there are no word timings', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          KaraokeText(
            words: const [],
            fallbackText: 'Selamat pagi semuanya',
            baseStyle: const TextStyle(fontSize: 14),
            searchHighlight: Colors.amber,
          ),
        ),
      );
      expect(find.text('Selamat pagi semuanya'), findsOneWidget);
    });

    testWidgets('a tapped word reports its own start time', (tester) async {
      TranscriptWord? tapped;
      await tester.pumpWidget(
        host(
          KaraokeText(
            words: [_word('Selamat', 10, 10.5), _word('pagi', 10.5, 11)],
            fallbackText: 'Selamat pagi',
            baseStyle: const TextStyle(fontSize: 14),
            searchHighlight: Colors.amber,
            onTapWord: (word) => tapped = word,
          ),
        ),
      );
      // Tapping the very start of the line lands on the first word.
      final text = find.byType(RichText).first;
      await tester.tapAt(tester.getTopLeft(text) + const Offset(4, 8));
      await tester.pump();
      expect(tapped?.word, 'Selamat');
      expect(tapped?.start, 10);
    });

    testWidgets('the rendered line reads back as the whole sentence', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          KaraokeText(
            words: [
              _word('Selamat', 10, 10.5),
              _word('pagi', 10.5, 11),
              _word('semuanya.', 11, 11.6, 0.3),
            ],
            fallbackText: 'ignored',
            baseStyle: const TextStyle(fontSize: 14),
            searchHighlight: Colors.amber,
            positionSecs: 10.7,
          ),
        ),
      );
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      expect(
        rich.text.toPlainText(),
        'Selamat pagi semuanya.',
        reason: 'word spans must join back into readable text',
      );
    });
  });
}
