import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';

import 'test_helpers.dart';

/// Kamus istilah (F3), Dart side: the list the user edits, and the config it
/// turns into for a session.
void main() {
  group('dedupeTerms', () {
    test('drops blanks and case-insensitive duplicates, keeping order', () {
      expect(
        dedupeTerms(['  PPBJ ', 'ppbj', '', '   ', 'SPBE', 'Kemenkeu', 'spbe']),
        ['PPBJ', 'SPBE', 'Kemenkeu'],
      );
    });

    test('is a no-op on an already-clean list', () {
      const clean = ['PPBJ', 'SPBE'];
      expect(dedupeTerms(clean), clean);
    });

    test('keeps the first spelling of a duplicated term', () {
      // The user typed "Kemenkeu" first, so that is the spelling the prompt
      // and the post-correction should use.
      expect(dedupeTerms(['Kemenkeu', 'KEMENKEU']), ['Kemenkeu']);
    });
  });

  group('GlossarySettings.toConfig', () {
    test('puts session terms ahead of the global list', () {
      const settings = GlossarySettings(
        enabled: true,
        terms: ['Kemenkeu', 'SPBE'],
        postCorrection: true,
        replacements: [],
      );
      final config = settings.toConfig(sessionTerms: ['Pak Budi']);
      expect(config.sessionTerms, ['Pak Budi']);
      expect(config.globalTerms, ['Kemenkeu', 'SPBE']);
      expect(config.postCorrection, isTrue);
    });

    test('a disabled glossary yields nothing at all', () {
      const settings = GlossarySettings(
        enabled: false,
        terms: ['Kemenkeu'],
        postCorrection: true,
        replacements: [],
      );
      final config = settings.toConfig(sessionTerms: ['Pak Budi']);
      expect(config.sessionTerms, isEmpty);
      expect(config.globalTerms, isEmpty);
      expect(
        config.postCorrection,
        isFalse,
        reason:
            'post-correction without terms would be a silent no-op, but '
            'reporting it as on is still a lie',
      );
    });

    test('the shipped default is on but empty, so it changes nothing', () {
      final config = kDefaultGlossarySettings.toConfig();
      expect(kDefaultGlossarySettings.enabled, isTrue);
      expect(config.globalTerms, isEmpty);
      expect(config.sessionTerms, isEmpty);
    });
  });

  group('SettingsNotifier glossary setters', () {
    test(
      'adding, removing and replacing terms persists through the bridge',
      () async {
        final bridge = NoopBridge();
        final notifier = SettingsNotifier(bridge);
        // Let the initial async _load() settle before acting.
        await Future<void>.delayed(Duration.zero);

        await notifier.addGlossaryTerm('  PPBJ ');
        await notifier.addGlossaryTerm('ppbj');
        expect(
          notifier.state.glossary.terms,
          ['PPBJ'],
          reason:
              'a duplicate must not take a second slot of the prompt '
              'budget',
        );

        await notifier.addGlossaryTerm('Kemenkeu');
        await notifier.removeGlossaryTerm('ppbj');
        expect(notifier.state.glossary.terms, ['Kemenkeu']);

        // Round-trips through the bridge, which is what persistence means here.
        expect((await bridge.loadSettings()).glossary.terms, ['Kemenkeu']);
      },
    );

    test('toggling the switches leaves the term list alone', () async {
      final notifier = SettingsNotifier(NoopBridge());
      await Future<void>.delayed(Duration.zero);
      await notifier.setGlossaryTerms(['SPBE', 'DIPA']);

      await notifier.setGlossaryEnabled(false);
      expect(notifier.state.glossary.terms, ['SPBE', 'DIPA']);
      expect(notifier.state.glossary.enabled, isFalse);

      await notifier.setGlossaryPostCorrection(false);
      expect(notifier.state.glossary.terms, ['SPBE', 'DIPA']);
      expect(notifier.state.glossary.postCorrection, isFalse);
    });
  });

  group('custom summary templates', () {
    test('saving by id replaces rather than appending', () async {
      final notifier = SettingsNotifier(NoopBridge());
      await Future<void>.delayed(Duration.zero);

      const first = CustomSummaryTemplate(
        id: 'tpl-1',
        name: 'Notulen + Risiko',
        instructions: 'Tambahkan risiko.',
        headings: ['Pembahasan', 'Risiko'],
      );
      await notifier.saveSummaryTemplate(first);
      await notifier.saveSummaryTemplate(first.copyWith(name: 'Dengan Risiko'));

      expect(notifier.state.summaryTemplates.length, 1);
      expect(notifier.state.summaryTemplates.single.name, 'Dengan Risiko');
      expect(notifier.state.summaryTemplates.single.headings, [
        'Pembahasan',
        'Risiko',
      ], reason: 'renaming must not discard the headings');

      await notifier.deleteSummaryTemplate('tpl-1');
      expect(notifier.state.summaryTemplates, isEmpty);
    });
  });

  group('notulen office defaults', () {
    test('survive a save and keep the fields not being edited', () async {
      final notifier = SettingsNotifier(NoopBridge());
      await Future<void>.delayed(Duration.zero);

      await notifier.setNotulenDefaults(
        kDefaultNotulenDefaults.copyWith(unitKerja: 'DJA', notulis: 'Budi'),
      );
      await notifier.setNotulenDefaults(
        notifier.state.notulen.copyWith(kopSuratPath: '/tmp/kop.png'),
      );

      final saved = notifier.state.notulen;
      expect(saved.unitKerja, 'DJA');
      expect(saved.notulis, 'Budi');
      expect(saved.kopSuratPath, '/tmp/kop.png');
    });
  });

  group('auto re-transcribe preference', () {
    test('null, true and false are three distinct, persisted states', () async {
      final notifier = SettingsNotifier(NoopBridge());
      await Future<void>.delayed(Duration.zero);

      expect(
        notifier.state.autoRetranscribe,
        isNull,
        reason: 'the default is "decide from the model that was used"',
      );

      await notifier.setAutoRetranscribe(true);
      expect(notifier.state.autoRetranscribe, isTrue);

      await notifier.setAutoRetranscribe(false);
      expect(notifier.state.autoRetranscribe, isFalse);

      await notifier.setAutoRetranscribe(null);
      expect(notifier.state.autoRetranscribe, isNull);
    });
  });
}
