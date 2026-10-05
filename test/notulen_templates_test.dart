/// The Dart template table must match the engine's.
///
/// `lib/state/notulen_templates.dart` duplicates
/// `NotulenTemplate::{label, description, document_title, jenis_naskah,
/// is_formal}` so the picker can be built synchronously. Duplication is
/// only safe when it is checked: `rust_core`'s
/// `the_template_table_dart_copies_is_current` writes and verifies
/// `test/fixtures/notulen_templates.json`, and this reads the same file.
///
/// A label changed on one side and not the other would show the user a
/// name for a layout the renderer does not produce.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/src/rust/notulen.dart';
import 'package:transcribe/state/notulen_templates.dart';

void main() {
  late List<Map<String, dynamic>> fixture;

  setUpAll(() {
    final file = File('test/fixtures/notulen_templates.json');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'regenerate with: cd rust_core && TRAREON_DUMP_PROMPTS=1 '
          'cargo test --lib notulen::tests',
    );
    fixture = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
  });

  test('the Dart table has one entry per engine template, in order', () {
    expect(
      kNotulenTemplates.map((info) => info.id).toList(),
      fixture.map((row) => row['id']).toList(),
    );
    // Every enum value is covered, so the picker can never be asked to
    // render a template it has no entry for.
    expect(kNotulenTemplates.length, NotulenTemplate.values.length);
  });

  test('every label, description and flag matches the engine', () {
    for (final row in fixture) {
      final info = kNotulenTemplates.firstWhere((i) => i.id == row['id']);
      expect(info.label, row['label'], reason: '${row['id']} label');
      expect(
        info.description,
        row['description'],
        reason: '${row['id']} description',
      );
      expect(
        info.documentTitle,
        row['document_title'],
        reason: '${row['id']} document title',
      );
      expect(
        info.jenisNaskah,
        row['jenis_naskah'],
        reason: '${row['id']} jenis naskah',
      );
      expect(info.formal, row['formal'], reason: '${row['id']} formal');
    }
  });

  test('the extension resolves every enum value', () {
    for (final template in NotulenTemplate.values) {
      expect(template.label, isNotEmpty);
      expect(template.jenisNaskah, isNotEmpty);
      expect(template.info.template, template);
    }
  });

  test('only the ringkas layout drops the formal apparatus', () {
    expect(NotulenTemplate.ringkas.isFormal, isFalse);
    for (final template in [
      NotulenTemplate.dinas,
      NotulenTemplate.risalah,
      NotulenTemplate.beritaAcara,
    ]) {
      expect(template.isFormal, isTrue, reason: '$template');
    }
  });

  test('labels and document titles are distinct', () {
    expect(
      kNotulenTemplates.map((info) => info.label).toSet().length,
      kNotulenTemplates.length,
    );
    expect(
      kNotulenTemplates.map((info) => info.documentTitle).toSet().length,
      kNotulenTemplates.length,
    );
  });

  test('every required section the engine names is in Indonesian', () {
    for (final row in fixture) {
      final sections = (row['required_sections'] as List).cast<String>();
      expect(sections, isNotEmpty, reason: '${row['id']}');
      // The three sections the whole engine is built on.
      expect(sections, contains('Tindak Lanjut'), reason: '${row['id']}');
      expect(
        sections.any((s) => s == 'Keputusan' || s == 'Kesepakatan'),
        isTrue,
        reason: '${row['id']} has no decisions section',
      );
    }
  });
}
