import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/state/models.dart';

void main() {
  group('effectiveSessionLanguage', () {
    // Sprint 14a item 11: "audio berbahasa Inggris muncul di sesi berbahasa
    // Indonesia (bahasa dikunci)" — a fresh install (no explicit global
    // override) must not force Indonesian on Rapat Online/Webinar.
    test('a fresh install (no global override) is Otomatis for Online', () {
      expect(
        effectiveSessionLanguage(
          globalLanguage: null,
          mode: SessionMode.online,
        ),
        isNull,
      );
    });

    test('a fresh install (no global override) is Otomatis for Webinar', () {
      expect(
        effectiveSessionLanguage(
          globalLanguage: null,
          mode: SessionMode.webinar,
        ),
        isNull,
      );
    });

    test(
      'a fresh install (no global override) stays Indonesia for Offline',
      () {
        expect(
          effectiveSessionLanguage(
            globalLanguage: null,
            mode: SessionMode.offline,
          ),
          'id',
        );
      },
    );

    test('an explicit global choice always wins, in every mode', () {
      for (final mode in SessionMode.values) {
        expect(
          effectiveSessionLanguage(globalLanguage: 'en', mode: mode),
          'en',
        );
      }
    });

    test('a pre-14a install that always wrote "id" keeps meaning id', () {
      expect(
        effectiveSessionLanguage(globalLanguage: 'id', mode: SessionMode.online),
        'id',
      );
    });
  });

  group('shouldOfferAutoLanguage', () {
    TranscriptSegment seg(String language) => TranscriptSegment(
      source: 'mic',
      speaker: 'Speaker 1',
      text: 'halo',
      timestamp: 0,
      duration: 1,
      language: language,
      confidence: 0.9,
      isPartial: false,
    );

    // Sprint 14a item 11: a mixed ID/EN fixture — a session forced to
    // Indonesian where a guest keeps answering in English.
    final mixedIdEnFixture = [
      seg('id'),
      seg('id'),
      seg('en'),
      seg('en'),
      seg('en'),
      seg('en'),
    ];

    test('offers the switch when most recent segments mismatch', () {
      expect(
        shouldOfferAutoLanguage(
          currentLanguage: 'id',
          segments: mixedIdEnFixture,
        ),
        isTrue,
      );
    });

    test('says nothing when the session is already Otomatis', () {
      expect(
        shouldOfferAutoLanguage(
          currentLanguage: null,
          segments: mixedIdEnFixture,
        ),
        isFalse,
      );
    });

    test('says nothing when segments mostly match the forced language', () {
      final mostlyId = [seg('id'), seg('id'), seg('id'), seg('id'), seg('en')];
      expect(
        shouldOfferAutoLanguage(currentLanguage: 'id', segments: mostlyId),
        isFalse,
      );
    });

    test('says nothing before there is enough evidence', () {
      expect(
        shouldOfferAutoLanguage(
          currentLanguage: 'id',
          segments: [seg('en'), seg('en')],
        ),
        isFalse,
      );
    });

    test('ignores segments with no detected language at all', () {
      final noLanguageInfo = [seg(''), seg(''), seg(''), seg('')];
      expect(
        shouldOfferAutoLanguage(
          currentLanguage: 'id',
          segments: noLanguageInfo,
        ),
        isFalse,
      );
    });

    test('only looks at the most recent window, not the whole session', () {
      // 20 mismatched segments followed by enough matching ones to fill
      // the recent window — an early-meeting language switch that has
      // since settled must not keep triggering the offer.
      final settled = [
        ...List.generate(20, (_) => seg('en')),
        ...List.generate(kLanguageOfferWindow, (_) => seg('id')),
      ];
      expect(
        shouldOfferAutoLanguage(currentLanguage: 'id', segments: settled),
        isFalse,
      );
    });
  });
}
