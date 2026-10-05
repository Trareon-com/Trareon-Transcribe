import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/widgets/summary_template_editor.dart';

import 'test_helpers.dart';

/// F8: user-editable summary templates.
///
/// The Rust side already proves a custom template's instruction reaches the
/// prompt and survives a settings round-trip. What was untested is the part
/// the user actually touches: that duplicating a template produces a second
/// one rather than overwriting the first, that editing saves under the *same*
/// id, that deleting removes only the one asked for, and that a saved
/// template turns up in the summary panel's picker.
void main() {
  /// Pumps [child] with a settings notifier backed by [initial] templates.
  Future<SettingsNotifier> pumpManager(
    WidgetTester tester, {
    List<CustomSummaryTemplate> initial = const [],
  }) async {
    // Seeded through the notifier, not through the bridge.
    //
    // `SettingsNotifier._load()` starts with `DartPrefs.instance.load()`,
    // which awaits `getApplicationSupportDirectory()` — a platform channel
    // with no handler in a widget test, so it never completes and the
    // notifier never picks up what the bridge holds. Going through
    // `saveSummaryTemplate` also sets the notifier's `_userActed` flag, so a
    // load that did somehow land later would bail instead of clobbering the
    // fixture.
    final container = ProviderContainer(
      overrides: [rustBridgeProvider.overrideWithValue(NoopBridge())],
    );
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);
    for (final template in initial) {
      await notifier.saveSummaryTemplate(template);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSummaryTemplateManager(context),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    return notifier;
  }

  CustomSummaryTemplate template({
    String id = 'tpl-1',
    String name = 'Notulen Dinas saya',
    List<String> headings = const ['Pembahasan', 'Keputusan'],
  }) => CustomSummaryTemplate(
    id: id,
    name: name,
    instructions: 'Tulis ringkas dan formal.',
    headings: headings,
  );

  testWidgets('a custom template is listed with its section headings', (
    tester,
  ) async {
    await pumpManager(tester, initial: [template()]);

    expect(find.text('Notulen Dinas saya'), findsOneWidget);
    expect(find.text('Pembahasan · Keputusan'), findsOneWidget);
    expect(find.text('Belum ada template buatan sendiri.'), findsNothing);
  });

  testWidgets('the empty state says so rather than showing a blank list', (
    tester,
  ) async {
    await pumpManager(tester);
    expect(find.text('Belum ada template buatan sendiri.'), findsOneWidget);
  });

  testWidgets('duplicating adds a second template instead of replacing it', (
    tester,
  ) async {
    final notifier = await pumpManager(tester, initial: [template()]);

    await tester.tap(find.byTooltip('Duplikat Notulen Dinas saya'));
    await tester.pumpAndSettle();

    final saved = notifier.state.summaryTemplates;
    expect(saved.length, 2, reason: 'the original must survive the copy');
    expect(
      saved.map((t) => t.name),
      containsAll(['Notulen Dinas saya', 'Notulen Dinas saya (salinan)']),
    );
    // A copy sharing the original's id would overwrite it on the next save.
    expect(saved[0].id, isNot(saved[1].id));
    // The copy carries the instructions over — a duplicate that lost them
    // would be a blank template with a familiar name.
    expect(saved[1].instructions, 'Tulis ringkas dan formal.');
    expect(saved[1].headings, ['Pembahasan', 'Keputusan']);
  });

  testWidgets(
    'editing saves under the same id, so there is still one template',
    (tester) async {
      final notifier = await pumpManager(tester, initial: [template()]);

      await tester.tap(find.byTooltip('Ubah Notulen Dinas saya'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama template'),
        'Notulen Ringkas saya',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Judul bagian (satu per baris)'),
        'Pembahasan\nTindak Lanjut',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final saved = notifier.state.summaryTemplates;
      expect(saved.length, 1, reason: 'an edit must not fork the template');
      expect(saved.single.id, 'tpl-1');
      expect(saved.single.name, 'Notulen Ringkas saya');
      expect(saved.single.headings, ['Pembahasan', 'Tindak Lanjut']);
    },
  );

  testWidgets('cancelling the editor changes nothing', (tester) async {
    final notifier = await pumpManager(tester, initial: [template()]);

    await tester.tap(find.byTooltip('Ubah Notulen Dinas saya'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama template'),
      'jangan disimpan',
    );
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(notifier.state.summaryTemplates.single.name, 'Notulen Dinas saya');
  });

  testWidgets('deleting removes only the template asked for', (tester) async {
    final notifier = await pumpManager(
      tester,
      initial: [
        template(id: 'tpl-1', name: 'Pertama'),
        template(id: 'tpl-2', name: 'Kedua'),
      ],
    );

    await tester.tap(find.byTooltip('Hapus Pertama'));
    await tester.pumpAndSettle();

    expect(notifier.state.summaryTemplates.map((t) => t.id), ['tpl-2']);
  });

  testWidgets('a built-in can be duplicated into an editable copy', (
    tester,
  ) async {
    final notifier = await pumpManager(tester);

    // "Mulai dari template bawaan" offers one chip per built-in.
    final chip = find.byTooltip(
      'Duplikat "Notulen Rapat" jadi template sendiri',
    );
    expect(
      chip,
      findsOneWidget,
      reason: 'the official notulen template is the one buyers ask for',
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // The editor opens prefilled; saving it stores the new template.
    expect(find.text('Simpan'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(notifier.state.summaryTemplates.length, 1);
    expect(notifier.state.summaryTemplates.single.name, 'Notulen Rapat (saya)');
  });

  testWidgets('a template created from nothing starts with a usable name', (
    tester,
  ) async {
    final notifier = await pumpManager(tester);

    await tester.tap(find.byTooltip('Buat template dari nol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(notifier.state.summaryTemplates.single.name, 'Template saya');
  });
}
