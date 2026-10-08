/// "Tindak Lanjut" (F6) and summary provenance (F7), Flutter side.
///
/// The parsing, the `.ics` and the `.csv` are Rust's and tested there.
/// What these tests cover is the part that only exists here: that an edit
/// to the checklist survives a close, that the exports land next to the
/// session, that a citation jumps the player, and that the notulen takes
/// the reviewed checklist rather than re-parsing the summary prose.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/src/rust/actions.dart' as rust_actions;
import 'package:transcribe/src/rust/provenance.dart' as rust_provenance;
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/state/summary_model.dart';
import 'package:transcribe/widgets/action_items_panel.dart';
import 'package:transcribe/widgets/notulen_dialog.dart';
import 'package:transcribe/widgets/summary_panel.dart';

import 'test_helpers.dart';

/// One transcript line at the moment the fixture citations point at.
const TranscriptSegment Function() _segment = _makeSegment;

TranscriptSegment _makeSegment() => const TranscriptSegment(
  source: 'mic',
  speaker: 'Peserta 2',
  text: 'Anggaran kuartal depan disetujui.',
  timestamp: 612.5,
  duration: 4,
  language: 'id',
  confidence: 0.9,
  isPartial: false,
);

ActionItem _item({
  String id = 'T1',
  String tugas = 'Revisi RAB',
  String pj = 'Budi',
  String tenggat = 'Jumat',
  ActionStatus status = ActionStatus.belum,
  List<int> segments = const [],
}) => ActionItem(
  id: id,
  tugas: tugas,
  penanggungJawab: pj,
  tenggat: tenggat,
  status: status,
  segmentIds: Uint32List.fromList(segments),
);

/// A bridge that records what the exports were handed and returns
/// recognisable content, so the test checks the file that was written
/// rather than re-implementing RFC 5545.
class _ExportBridge extends NoopBridge {
  List<rust_actions.ActionItem>? icsItems;
  List<rust_actions.ActionItem>? csvItems;
  String? calendarName;
  String? today;

  @override
  Future<String> actionItemsToIcs({
    required List<rust_actions.ActionItem> items,
    required String calendarName,
    required String today,
  }) async {
    icsItems = items;
    this.calendarName = calendarName;
    this.today = today;
    return 'BEGIN:VCALENDAR\r\nX-WR-CALNAME:$calendarName\r\nEND:VCALENDAR\r\n';
  }

  @override
  Future<String> actionItemsToCsv(List<rust_actions.ActionItem> items) async {
    csvItems = items;
    return 'tugas,pj\n${items.map((i) => '${i.tugas},${i.penanggungJawab}').join('\n')}\n';
  }
}

/// A bridge whose summary carries citations, for the F7 rendering.
class _CitingBridge extends NoopBridge {
  @override
  Future<rust_provenance.SummaryProvenance> summaryProvenance({
    required String summary,
    required List<TranscriptSegment> segments,
    bool verify = true,
  }) async => const rust_provenance.SummaryProvenance(
    lines: [
      rust_provenance.SummaryLine(
        text: 'Keputusan',
        citations: [],
        isHeading: true,
      ),
      rust_provenance.SummaryLine(
        text: 'Anggaran kuartal depan disetujui.',
        citations: [rust_provenance.Citation(segmentId: 4, timestamp: 612.5)],
        isHeading: false,
      ),
    ],
    dropped: 2,
  );
}

/// A throwaway session directory.
///
/// Created and deleted synchronously: inside `testWidgets` the fake-async
/// zone never completes a real `await` on file I/O, so an awaited
/// `createTemp` there hangs the test until the ten-minute timeout.
Directory _tempSession() {
  final dir = Directory.systemTemp.createTempSync('trareon-actions');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// Waits for a fire-and-forget sidecar write to land.
///
/// The checklist persists itself without the caller awaiting it, which is
/// right for the UI and means a test has to wait for the file rather than
/// for a future it does not hold.
/// The summary panel hides its body behind the "Ringkasan AI" master
/// switch, so a test about rendering has to turn it on.
///
/// Set through the notifier rather than the bridge: `SettingsNotifier`
/// loads from disk via a platform channel a widget test never answers,
/// and a mutator also marks the settings as user-acted so that pending
/// load cannot overwrite them.
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
        withCitations: true,
      ),
    );
    return notifier;
  }),
];

Future<SessionMeta> _metaWhenWritten(
  String dirPath,
  bool Function(SessionMeta) until,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final meta = await readSessionMeta(dirPath);
    if (until(meta)) return meta;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return readSessionMeta(dirPath);
}

void main() {
  group('status labels', () {
    test('every Dart label is the one Rust writes into the exports', () {
      // Read rather than mirrored by hand: the `.ics` and `.csv` come
      // from Rust, so a status that reads "Belum" on screen and "Belum
      // mulai" in the file is a bug the user finds in a spreadsheet.
      final rust = File('rust_core/src/actions.rs').readAsStringSync();
      for (final status in ActionStatus.values) {
        final label = actionStatusLabel(status);
        expect(
          rust,
          contains('=> "$label"'),
          reason:
              'ActionStatus.${status.name} renders "$label" in Dart, '
              'which rust_core/src/actions.rs does not produce',
        );
      }
      // And the four are distinct — a switch that returned one string for
      // two states would satisfy the check above.
      expect(
        ActionStatus.values.map(actionStatusLabel).toSet(),
        hasLength(ActionStatus.values.length),
      );
    });
  });

  group('sidecar', () {
    test('an edited checklist survives a close and reopen', () async {
      final dir = _tempSession();
      await writeSessionMeta(
        dir.path,
        SessionMeta(
          summary: '# Ringkasan',
          actionItems: [
            _item(status: ActionStatus.selesai, segments: [4, 9]),
            _item(id: 'T2', tugas: 'Kirim notulen', pj: 'Sari', tenggat: ''),
          ],
        ),
      );

      final reloaded = await readSessionMeta(dir.path);
      expect(reloaded.actionItems, hasLength(2));
      expect(reloaded.actionItems.first.status, ActionStatus.selesai);
      expect(reloaded.actionItems.first.segmentIds, [4, 9]);
      expect(reloaded.actionItems.last.penanggungJawab, 'Sari');
      expect(reloaded.actionItems.last.tenggat, '');
    });

    test('a hand-edited sidecar cannot make a session unopenable', () async {
      final dir = _tempSession();
      final file = File('${dir.path}/$kMetaFilename');
      await file.writeAsString('''
{
  "version": 1,
  "action_items": [
    {"tugas": "Tugas sah", "status": "entah-apa", "segments": [2, -5, "x"]},
    {"pj": "tanpa tugas"},
    "bukan objek",
    {"tugas": "   "}
  ]
}
''');
      final meta = await readSessionMeta(dir.path);
      // One survivor: the row with a task. An unknown status falls back
      // to "belum" rather than dropping the task.
      expect(meta.actionItems, hasLength(1));
      expect(meta.actionItems.single.tugas, 'Tugas sah');
      expect(meta.actionItems.single.status, ActionStatus.belum);
      expect(meta.actionItems.single.segmentIds, [2]);
      expect(meta.actionItems.single.id, isNotEmpty);
    });

    test('blank rows are not persisted', () async {
      final dir = _tempSession();
      final provider = StateNotifierProvider<SummaryNotifier, SummaryUiState>((
        ref,
      ) {
        return SummaryNotifier(
          NoopBridge(),
          dir.path,
          initialMeta: SessionMeta(summary: 'x', actionItems: [_item()]),
        );
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(provider.notifier);

      notifier.addActionItem();
      expect(container.read(provider).actionItems, hasLength(2));
      // Saving happens on a real edit, not on adding an empty row.
      notifier.setActionItem(0, _item(status: ActionStatus.berjalan));

      final meta = await _metaWhenWritten(
        dir.path,
        (m) => m.actionItems.isNotEmpty,
      );
      expect(meta.actionItems, hasLength(1));
      expect(meta.actionItems.single.status, ActionStatus.berjalan);
    });

    test('a new row never reuses an existing id', () async {
      final dir = _tempSession();
      final provider = StateNotifierProvider<SummaryNotifier, SummaryUiState>((
        ref,
      ) {
        return SummaryNotifier(
          NoopBridge(),
          dir.path,
          initialMeta: SessionMeta(
            summary: 'x',
            // Ids that are not 1..n, which is what a model's JSON
            // actually looks like after the user deletes a row.
            actionItems: [
              _item(id: 'T2'),
              _item(id: 'T3', tugas: 'Lain'),
            ],
          ),
        );
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(provider.notifier).addActionItem();
      final ids = container.read(provider).actionItems.map((i) => i.id);
      expect(ids.toSet(), hasLength(3), reason: 'ids must stay unique');
    });
  });

  group('panel', () {
    testWidgets('ticking a task writes it to the sidecar', (tester) async {
      final dir = _tempSession();
      final provider = StateNotifierProvider<SummaryNotifier, SummaryUiState>((
        ref,
      ) {
        return SummaryNotifier(
          NoopBridge(),
          dir.path,
          initialMeta: SessionMeta(summary: 'x', actionItems: [_item()]),
        );
      });

      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: const [],
          child: Material(
            child: ActionItemsPanel(
              provider: provider,
              sessionTitle: 'Rapat Anggaran',
              sessionDirPath: dir.path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tindak Lanjut'), findsOneWidget);
      expect(find.text('0/1 selesai'), findsOneWidget);

      // Inside runAsync: the tick persists itself with real file I/O,
      // and the fake-async zone a widget test runs in never completes an
      // awaited `File.rename`.
      final meta = await tester.runAsync(() async {
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        return _metaWhenWritten(
          dir.path,
          (m) => m.actionItems.any((i) => i.status == ActionStatus.selesai),
        );
      });
      await tester.pumpAndSettle();

      expect(find.text('1/1 selesai'), findsOneWidget);
      expect(meta!.actionItems.single.status, ActionStatus.selesai);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('exports land next to the session', (tester) async {
      final dir = _tempSession();
      final bridge = _ExportBridge();
      final provider = StateNotifierProvider<SummaryNotifier, SummaryUiState>((
        ref,
      ) {
        return SummaryNotifier(
          bridge,
          dir.path,
          initialMeta: SessionMeta(
            summary: 'x',
            actionItems: [
              _item(),
              _item(id: 'T2', tugas: '   '),
            ],
          ),
        );
      });

      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: [rustBridgeProvider.overrideWithValue(bridge)],
          child: Material(
            child: ActionItemsPanel(
              provider: provider,
              sessionTitle: 'Rapat Anggaran',
              sessionDirPath: dir.path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Same reason as the tick above: the export is real file I/O. It is
      // awaited through [actionItemExportSettled] rather than polled for:
      // this used to spin for the file for two seconds and then carry on
      // regardless, so on a loaded CPU the Rust call plus atomic write were
      // still in flight and the failure surfaced further down as a
      // missing-file or un-settled-tree error. Awaiting the export itself is
      // exact at any speed.
      await tester.runAsync(() async {
        actionItemExportSettled = null; // so isNotNull below means this tap
        await tester.tap(find.widgetWithText(OutlinedButton, 'Ekspor .ics'));
        await tester.pump();
        expect(
          actionItemExportSettled,
          isNotNull,
          reason: 'tapping Ekspor .ics must start an export',
        );
        await actionItemExportSettled;
      });
      await tester.pumpAndSettle();

      final ics = File('${dir.path}/tindak-lanjut.ics');
      expect(ics.existsSync(), isTrue);
      expect(ics.readAsStringSync(), contains('BEGIN:VCALENDAR'));
      // The blank row is not a task and must not reach a calendar.
      expect(bridge.icsItems, hasLength(1));
      expect(bridge.calendarName, contains('Rapat Anggaran'));
      expect(bridge.today, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

      await tester.runAsync(() async {
        actionItemExportSettled = null; // so isNotNull below means this tap
        await tester.tap(find.widgetWithText(OutlinedButton, 'Ekspor CSV'));
        await tester.pump();
        expect(
          actionItemExportSettled,
          isNotNull,
          reason: 'tapping Ekspor CSV must start an export',
        );
        await actionItemExportSettled;
      });
      await tester.pumpAndSettle();

      final csv = File('${dir.path}/tindak-lanjut.csv');
      expect(csv.existsSync(), isTrue);
      expect(csv.readAsStringSync(), contains('Revisi RAB'));
      expect(bridge.csvItems, hasLength(1));

      // Let the "disimpan" toast expire: its dismissal timer outlives the
      // widget tree otherwise, which a widget test treats as a leak.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('a cited task jumps the player to the line it came from', (
      tester,
    ) async {
      final dir = _tempSession();
      final jumps = <int>[];
      final provider = StateNotifierProvider<SummaryNotifier, SummaryUiState>((
        ref,
      ) {
        return SummaryNotifier(
          NoopBridge(),
          dir.path,
          initialMeta: SessionMeta(
            summary: 'x',
            actionItems: [
              _item(segments: [4]),
            ],
          ),
        );
      });

      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: const [],
          child: Material(
            child: ActionItemsPanel(
              provider: provider,
              sessionTitle: 'Rapat Anggaran',
              sessionDirPath: dir.path,
              onSeekToSegment: jumps.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('[#4]'));
      await tester.pumpAndSettle();
      // The model numbers segments from 1, the player indexes from 0.
      expect(jumps, [3]);
    });
  });

  group('provenance (F7)', () {
    testWidgets('each cited line is a link that seeks the player', (
      tester,
    ) async {
      final seeks = <double>[];
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: _summaryEnabled(_CitingBridge()),
          child: Material(
            child: SingleChildScrollView(
              child: SummaryPanel(
                sessionDirPath: '/tmp/does-not-need-to-exist',
                segments: () => [_segment()],
                initialMeta: const SessionMeta(
                  summary: '# Keputusan\n- ya [#4]',
                ),
                onSeekToTimestamp: seeks.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anggaran kuartal depan disetujui.'), findsOneWidget);
      // The chip is the timestamp, because that is what the user is about
      // to hear.
      await tester.tap(find.text('[10:12]'));
      await tester.pumpAndSettle();
      expect(seeks, [612.5]);
    });

    testWidgets('dropped citations are reported, not hidden', (tester) async {
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: _summaryEnabled(_CitingBridge()),
          child: Material(
            child: SingleChildScrollView(
              child: SummaryPanel(
                sessionDirPath: '/tmp/does-not-need-to-exist',
                segments: () => [_segment()],
                initialMeta: const SessionMeta(
                  summary: '# Keputusan\n- ya [#4]',
                ),
                onSeekToTimestamp: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 rujukan dibuang'),
        findsOneWidget,
        reason:
            'a model that cites lines the transcript lacks is guessing, '
            'and the user has to be told before signing the notulen',
      );
    });
  });

  group('notulen (F6)', () {
    test('takes the reviewed checklist over the re-parsed summary', () {
      final form = buildNotulenPrefill(
        title: 'Rapat Anggaran',
        recordedAt: DateTime(2026, 10, 2, 9),
        durationSeconds: 3600,
        defaults: AppSettings.defaults().notulen,
        segments: const [],
        draft: const NotulenDraft(
          peserta: [],
          pembahasan: '',
          keputusan: [],
          tindakLanjut: [
            TindakLanjut(
              tugas: 'Dari prosa ringkasan',
              penanggungJawab: '',
              tenggat: '',
            ),
          ],
        ),
        actionItems: [
          _item(),
          _item(
            id: 'T2',
            tugas: 'Tugas yang dibatalkan',
            status: ActionStatus.dibatalkan,
          ),
          _item(id: 'T3', tugas: '  '),
        ],
      );

      // Only the live, non-blank row: a document that lists a dropped
      // task next to live ones reads as an instruction to do it.
      expect(form.tindakLanjut, hasLength(1));
      expect(form.tindakLanjut.single.tugas, 'Revisi RAB');
      expect(form.tindakLanjut.single.penanggungJawab, 'Budi');
    });

    test('falls back to the summary draft when there is no checklist', () {
      final form = buildNotulenPrefill(
        title: 'Rapat Anggaran',
        recordedAt: DateTime(2026, 10, 2, 9),
        durationSeconds: 3600,
        defaults: AppSettings.defaults().notulen,
        segments: const [],
        draft: const NotulenDraft(
          peserta: [],
          pembahasan: '',
          keputusan: [],
          tindakLanjut: [
            TindakLanjut(
              tugas: 'Dari prosa ringkasan',
              penanggungJawab: 'Sari',
              tenggat: 'Senin',
            ),
          ],
        ),
      );

      expect(form.tindakLanjut.single.tugas, 'Dari prosa ringkasan');
    });
  });
}
