import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/theme/app_icons.dart';
import 'package:transcribe/widgets/notulen_dialog.dart';
import 'package:transcribe/widgets/ui/app_button.dart';
import 'package:transcribe/widgets/ui/app_chip.dart';
import 'package:transcribe/widgets/ui/app_controls.dart';
import 'package:transcribe/widgets/ui/app_dialog.dart';
import 'package:transcribe/widgets/ui/app_field.dart';

import 'test_helpers.dart';

/// The notulen preview, sprint 5: the sixth signature screen is built from the
/// component kit, and the controls the restyle replaced still do their job.
void main() {
  const saved = NotulenFormData(
    instansi: 'Dinas Komunikasi dan Informatika',
    judul: 'Rapat Koordinasi Triwulan',
    hari: 'Kamis',
    tanggal: '1 Oktober 2026',
    waktu: '09.05 - 11.30 WIB',
    agenda: ['Pagu indikatif', 'Jadwal penyerapan'],
    keputusan: ['Menyusun jadwal penyerapan mingguan'],
    tindakLanjut: [
      NotulenTask(
        tugas: 'Menyiapkan draf jadwal',
        penanggungJawab: 'Bagian Perencanaan',
        tenggat: '9 Oktober 2026',
      ),
    ],
  );

  Future<void> open(WidgetTester tester) async {
    // The default 800x600 test surface is below the app's own 900x600
    // minimum, and the form is long: without a real window the rows under
    // test are off-screen rather than merely scrolled out of view.
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: const [],
        child: Builder(
          builder: (context) => Material(
            child: Center(
              child: AppButton.primary(
                label: 'Buka',
                onPressed: () => showNotulenDialog(
                  context,
                  session: const SessionSummary(
                    id: 's',
                    title: 'Rapat Koordinasi Triwulan',
                    date: '2026-10-01',
                    segmentsCount: 6,
                    durationSeconds: 2460,
                  ),
                  recordedAt: DateTime(2026, 10, 1, 9, 5),
                  summary: '',
                  bookmarks: const [],
                  saved: saved,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('the form is built from the kit, not from Material', (
    tester,
  ) async {
    await open(tester);

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byType(AppTextField), findsWidgets);
    expect(find.byType(AppSegmented<NotulenVariant>), findsOneWidget);
    expect(find.byType(AppCheckbox), findsOneWidget);

    // The Material widgets the restyle replaced must not come back: they
    // carry their own type scale and their own focus treatment.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(SegmentedButton<NotulenVariant>), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('an agenda chip can be dismissed, and says what it removes', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('1. Pagu indikatif'), findsOneWidget);
    expect(find.text('2. Jadwal penyerapan'), findsOneWidget);

    final chip = find.ancestor(
      of: find.text('1. Pagu indikatif'),
      matching: find.byType(AppChip),
    );
    expect(tester.widget<AppChip>(chip).deleteTooltip, 'Hapus Pagu indikatif');

    final dismiss = find.descendant(
      of: chip,
      matching: find.byIcon(AppIcons.close),
    );
    expect(dismiss, findsOneWidget);
    await tester.ensureVisible(dismiss);
    await tester.pumpAndSettle();
    await tester.tap(dismiss);
    await tester.pumpAndSettle();

    expect(find.text('1. Pagu indikatif'), findsNothing);
    // The remaining item is renumbered rather than keeping a stale index.
    expect(find.text('1. Jadwal penyerapan'), findsOneWidget);
  });

  testWidgets('switching the variant hides the kop surat fields', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Nomor Notulen'), findsOneWidget);

    await tester.tap(find.text('Notulen Ringkas'));
    await tester.pumpAndSettle();

    expect(find.text('Nomor Notulen'), findsNothing);
    expect(find.text('Instansi (kop surat)'), findsNothing);
  });

  testWidgets('a tindak lanjut cell keeps its caret while typing', (
    tester,
  ) async {
    await open(tester);

    final cell = find.descendant(
      of: find.widgetWithText(AppTextField, 'Menyiapkan draf jadwal'),
      matching: find.byType(EditableText),
    );
    expect(cell, findsOneWidget);
    final controller = tester.widget<EditableText>(cell).controller;

    await tester.enterText(cell, 'Menyiapkan draf jadwal penyerapan');
    await tester.pumpAndSettle();

    // The table is rebuilt from the task list on every keystroke, so a cell
    // rebuilt from `initialValue` would reset the field and lose the caret.
    expect(controller.text, 'Menyiapkan draf jadwal penyerapan');
    expect(
      controller.selection.baseOffset,
      'Menyiapkan draf jadwal penyerapan'.length,
    );
  });
}
