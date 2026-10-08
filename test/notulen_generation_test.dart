/// Pure-logic tests for the Sprint 8 notulen generation helpers:
/// "poin catatan" input conversion and the length-preset table.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/state/notulen_generation.dart';

void main() {
  group('manualNotesToSegments', () {
    test('turns non-empty lines into segments', () {
      final segments = manualNotesToSegments('Poin satu\nPoin dua\n\nPoin tiga');
      expect(segments.length, 3);
      expect(segments[0].text, 'Poin satu');
      expect(segments[1].text, 'Poin dua');
      expect(segments[2].text, 'Poin tiga');
      expect(segments.every((s) => s.speaker == 'Catatan'), isTrue);
      expect(segments.every((s) => !s.isPartial), isTrue);
      // timestamps strictly increasing so chunk_by_time orders them
      // correctly.
      expect(segments[1].timestamp, greaterThan(segments[0].timestamp));
      expect(segments[2].timestamp, greaterThan(segments[1].timestamp));
    });

    test('trims surrounding whitespace on each line', () {
      final segments = manualNotesToSegments('  Rapi  \n\tTab juga\t');
      expect(segments[0].text, 'Rapi');
      expect(segments[1].text, 'Tab juga');
    });

    test('blank input returns an empty list', () {
      expect(manualNotesToSegments('   \n\n  '), isEmpty);
      expect(manualNotesToSegments(''), isEmpty);
    });
  });

  group('kNotulenLengthOptions', () {
    test('has three presets with distinct word targets', () {
      expect(kNotulenLengthOptions.length, 3);
      final targets = kNotulenLengthOptions.map((o) => o.wordTarget).toSet();
      expect(targets.length, 3);
    });

    test('values are distinct', () {
      final values = kNotulenLengthOptions.map((o) => o.value).toSet();
      expect(values.length, 3);
    });
  });
}
