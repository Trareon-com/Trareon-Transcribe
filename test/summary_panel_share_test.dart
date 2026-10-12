// Sprint 22 celah B: `shareExportedFile` (F21) was wired into
// action_items_panel.dart only. SummaryPanel's "Bagikan" button must write
// the current summary to disk and actually hand it to the same share
// utility, from a real widget tree — not just exist cosmetically.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/widgets/summary_panel.dart';
import 'package:transcribe/widgets/ui/app_button.dart';

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

// The button row (Sunting/Salin/Bagikan/Simpan) only renders when the
// "Ringkasan AI" feature itself is enabled — otherwise the panel shows the
// "fitur ini mati" notice instead. Mirrors summary_panel_enhance_test.dart.
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
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('summary-share-test');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  testWidgets(
    'menekan Bagikan menulis ringkasan ke berkas dan menyerahkannya ke share sheet',
    (tester) async {
      // Real Clipboard.setData hangs in this sandboxed test runner (see
      // share_file.dart's doc comment) — intercept the channel so the
      // fallback path `shareExportedFile` takes on Linux desktop resolves
      // immediately instead of blocking the suite.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.setData' ? null : null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final bridge = NoopBridge();
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: _summaryEnabled(bridge),
          child: Material(
            child: SingleChildScrollView(
              child: SummaryPanel(
                sessionDirPath: tmpDir.path,
                segments: () => const [_segment],
                initialMeta: SessionMeta(
                  summary: 'Ringkasan rapat: pakai Rust untuk engine.',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A non-empty `initialMeta.summary` starts the panel expanded
      // already (`_expanded = widget.initialMeta.hasSummary`), so the
      // button row is reachable without an extra tap.
      expect(find.text('Bagikan'), findsOneWidget);

      // `runAsync`: `_share` does real `dart:io` file writes, which the
      // fake-async zone `testWidgets` otherwise runs in never resolves —
      // the tap would appear to silently do nothing.
      final shared = File(
        '${tmpDir.path}${Platform.pathSeparator}ringkasan-dibagikan.md',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Bagikan'));
        // Poll rather than a fixed delay: a loaded test machine can make a
        // flat sleep too short, which is exactly the flake this avoids.
        for (var i = 0; i < 50 && !shared.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        shared.existsSync(),
        true,
        reason: 'Bagikan has to write the summary out before sharing it',
      );
      expect(
        shared.readAsStringSync(),
        'Ringkasan rapat: pakai Rust untuk engine.',
      );

      // On Linux desktop there is no native share sheet, so this falls back
      // to the clipboard and a toast saying so — the real-share path is
      // exercised on mobile/macOS/Windows builds, not here.
      expect(find.textContaining('disalin'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('tombol Bagikan nonaktif saat ringkasan kosong', (
    tester,
  ) async {
    final bridge = NoopBridge();
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: _summaryEnabled(bridge),
        child: Material(
          child: SingleChildScrollView(
            child: SummaryPanel(
              sessionDirPath: tmpDir.path,
              segments: () => const [_segment],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ringkasan AI'));
    await tester.pumpAndSettle();

    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Bagikan'),
    );
    expect(button.onPressed, isNull);
  });
}
