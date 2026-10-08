import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/src/rust/api.dart' as rust_api;
import 'package:transcribe/src/rust/export/notulen.dart' as rust_notulen;
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/theme/app_icons.dart';
import 'package:transcribe/widgets/notulen_dialog.dart';
import 'package:transcribe/widgets/settings_controls.dart';
import 'package:transcribe/widgets/ui/app_button.dart';
import 'package:transcribe/widgets/ui/app_chip.dart';
import 'package:transcribe/widgets/ui/app_controls.dart';
import 'package:transcribe/widgets/ui/app_dialog.dart';
import 'package:transcribe/widgets/ui/app_field.dart';

import 'test_helpers.dart';

/// Turns on the AI summary feature so `_generate`'s usability guard does
/// not refuse before the fake bridge is ever called — the same pattern
/// `action_items_test.dart` uses for the same guard on the summary path.
List<Override> _summaryEnabled(RustBridge bridge) => [
  rustBridgeProvider.overrideWithValue(bridge),
  settingsProvider.overrideWith((ref) {
    final notifier = SettingsNotifier(bridge);
    final base = AppSettings.defaults();
    notifier.setSummarySettings(
      base.summary.copyWith(
        enabled: true,
        baseUrl: 'http://127.0.0.1:11434',
        model: 'qwen2.5:0.5b',
      ),
    );
    return notifier;
  }),
];

/// Fails every generation attempt, so the dialog's error/retry path can be
/// exercised without a real LLM endpoint.
class _FailingNotulenBridge extends NoopBridge {
  int attempts = 0;

  @override
  Future<rust_api.NotulenHasil> generateNotulen({
    required SummaryConfig config,
    required NotulenTemplate template,
    required List<TranscriptSegment> segments,
    required List<Bookmark> bookmarks,
    required rust_notulen.NotulenForm base,
    required NotulenLength panjang,
    String? konteksDokumen,
  }) async {
    attempts++;
    throw Exception('endpoint tidak terjangkau');
  }
}

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

  Future<void> open(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    // The default 800x600 test surface is below the app's own 900x600
    // minimum, and the form is long: without a real window the rows under
    // test are off-screen rather than merely scrolled out of view.
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: overrides,
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
    expect(find.byType(CompactDropdown<NotulenTemplate>), findsOneWidget);
    expect(find.byType(AppCheckbox), findsOneWidget);

    // The Material widgets the restyle replaced must not come back: they
    // carry their own type scale and their own focus treatment.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(SegmentedButton<NotulenTemplate>), findsNothing);
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

  testWidgets('switching to the ringkas template hides the kop surat fields', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Nomor Notulen'), findsOneWidget);

    await tester.tap(find.byType(CompactDropdown<NotulenTemplate>));
    await tester.pumpAndSettle();
    // The closed button also renders its own label, so the menu entry is
    // the last match.
    await tester.tap(find.text('Notulen Ringkas').last);
    await tester.pumpAndSettle();

    expect(find.text('Nomor Notulen'), findsNothing);
    expect(find.text('Instansi (kop surat)'), findsNothing);
  });

  testWidgets('a berita acara asks for the parties and keeps the kop', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byType(CompactDropdown<NotulenTemplate>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berita Acara').last);
    await tester.pumpAndSettle();

    // A berita acara is a formal naskah, so the nomor stays…
    expect(find.text('Nomor Notulen'), findsOneWidget);
    // …and it is the one template that needs para pihak. `skipOffstage`
    // because the section sits below the fold of the test viewport.
    // `AppGroupLabel` upper-cases, and `skipOffstage` because the
    // section sits below the fold of the test viewport.
    expect(find.text('PARA PIHAK', skipOffstage: false), findsOneWidget);
    // Peserta is replaced, not added to: a name in both lists would be
    // printed twice.
    expect(find.text('PESERTA', skipOffstage: false), findsNothing);
    // The add control is an icon button: its label lives in the tooltip and
    // the semantics node ("never nameless"), not in a Text widget.
    final semantics = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel('Tambah pihak'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the picker explains the selected template', (tester) async {
    await open(tester);

    // The engine's own description, so the picker cannot promise a layout
    // the renderer does not produce.
    expect(
      find.textContaining('Notula lengkap sesuai Tata Naskah Dinas'),
      findsOneWidget,
    );

    await tester.tap(find.byType(CompactDropdown<NotulenTemplate>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berita Acara').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Naskah pembuktian'), findsOneWidget);
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

  testWidgets('poin catatan mode shows a notes field and hides it in session '
      'mode', (tester) async {
    await open(tester);

    expect(
      find.text(
        'Tempel atau ketik butir-butir catatan rapat, satu poin per baris.',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Poin catatan'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Tempel atau ketik butir-butir catatan rapat, satu poin per baris.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Transkrip sesi'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Tempel atau ketik butir-butir catatan rapat, satu poin per baris.',
      ),
      findsNothing,
    );
  });

  testWidgets('selecting a length preset updates the dropdown value', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Sedang'), findsOneWidget);

    await tester.tap(find.byType(CompactDropdown<NotulenLength>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lengkap').last);
    await tester.pumpAndSettle();

    expect(find.text('Lengkap'), findsOneWidget);
    expect(find.text('Sedang'), findsNothing);
  });

  testWidgets('generation error shows a Coba lagi button that retries', (
    tester,
  ) async {
    final bridge = _FailingNotulenBridge();
    await open(tester, overrides: _summaryEnabled(bridge));

    await tester.tap(find.text('Buat Otomatis'));
    await tester.pumpAndSettle();

    expect(bridge.attempts, 1);
    expect(find.textContaining('Gagal membuat notulen otomatis'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    // Same inputs replayed, no form reset — the retry just calls the
    // generator again rather than rebuilding the request from scratch.
    expect(bridge.attempts, 2);
    expect(find.text('Coba lagi'), findsOneWidget);
  });
}
