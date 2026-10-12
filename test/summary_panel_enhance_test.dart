// F11 (Sprint 19) Bagian B — "Enhance": the button in SummaryPanel must
// actually call the notes+transcript merge and render the result, not just
// exist cosmetically. Mocks the backend summary bridge and verifies the UI
// updates from a real widget tree, the same pattern action_items_test.dart
// uses for the citation rendering.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/widgets/summary_panel.dart';

import 'test_helpers.dart';

const TranscriptSegment _segment = TranscriptSegment(
  source: 'mic',
  speaker: 'Saya',
  text: 'kita putuskan pakai Rust',
  timestamp: 0,
  duration: 2,
  language: 'id',
  confidence: 0.9,
  isPartial: false,
);

/// Records what "Enhance" actually sent, and returns a recognisable merged
/// document so the test can tell the real call path from a placeholder.
class _EnhanceBridge extends NoopBridge {
  String? lastPersonalNotes;

  @override
  Future<String> generateSummaryLong({
    required List<TranscriptSegment> segments,
    required SummaryConfig config,
    List<Bookmark> bookmarks = const [],
    String? personalNotes,
  }) async {
    lastPersonalNotes = personalNotes;
    return '## Notulen Gabungan\n- Deadline Jumat (dari catatan Anda)\n'
        '- Pakai Rust (dari transkrip)';
  }
}

List<Override> _summaryEnabled(RustBridge bridge) => [
  rustBridgeProvider.overrideWithValue(bridge),
  settingsProvider.overrideWith((ref) {
    final notifier = SettingsNotifier(bridge);
    notifier.setSummarySettings(
      AppSettings.defaults().summary.copyWith(
        enabled: true,
        baseUrl: 'http://127.0.0.1:11434',
        model: 'qwen2.5:0.5b',
      ),
    );
    return notifier;
  }),
];

void main() {
  testWidgets(
    'menekan Enhance menggabungkan catatan pribadi dengan transkrip dan menampilkan hasilnya',
    (tester) async {
      final bridge = _EnhanceBridge();
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: _summaryEnabled(bridge),
          child: Material(
            child: SingleChildScrollView(
              child: SummaryPanel(
                sessionDirPath: '/tmp/does-not-need-to-exist',
                segments: () => const [_segment],
                initialMeta: const SessionMeta(
                  personalNotes: 'PENTING: deadline Jumat',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The panel starts collapsed; expand it to reach the Enhance button.
      await tester.tap(find.text('Ringkasan AI'));
      await tester.pumpAndSettle();

      expect(find.text('PENTING: deadline Jumat'), findsOneWidget);
      expect(find.text('Enhance'), findsOneWidget);

      // Not `pumpAndSettle`: `enhance()` starts a `Timer.periodic` map-reduce
      // progress poll (same as `generate()`), which never "settles" on its
      // own — a few explicit pumps are enough for the already-resolved
      // bridge call above to land.
      await tester.tap(find.text('Enhance'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        bridge.lastPersonalNotes,
        'PENTING: deadline Jumat',
        reason: 'the Enhance button must send the real personal notes',
      );
      expect(
        find.textContaining('Deadline Jumat (dari catatan Anda)'),
        findsOneWidget,
        reason: 'the merged AI result must actually render in the panel',
      );
      // The raw notes must still be visible, unreplaced, next to the
      // AI output — the brief is explicit that one must not overwrite
      // the other.
      expect(find.text('PENTING: deadline Jumat'), findsOneWidget);
    },
  );

  testWidgets(
    'Enhance tetap berfungsi walau catatan pribadi kosong (fallback ke transkrip saja)',
    (tester) async {
      final bridge = _EnhanceBridge();
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: _summaryEnabled(bridge),
          child: Material(
            child: SingleChildScrollView(
              child: SummaryPanel(
                sessionDirPath: '/tmp/does-not-need-to-exist',
                segments: () => const [_segment],
                initialMeta: SessionMeta.empty,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ringkasan AI'));
      await tester.pumpAndSettle();

      expect(find.text('Enhance'), findsOneWidget);
      await tester.tap(find.text('Enhance'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(bridge.lastPersonalNotes, isNull);
      expect(find.textContaining('Pakai Rust (dari transkrip)'), findsOneWidget);
    },
  );
}
