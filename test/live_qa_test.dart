/// "Tanya Langsung" (Sprint 21): ask a question while a meeting is still
/// recording, answered from the transcript so far.
///
/// The Rust side (`live_qa.rs`) already covers selection and the
/// hallucination-guard prompt. What is only testable here is the Flutter
/// half: that the panel refuses without an endpoint rather than silently
/// doing nothing, that asking reaches the bridge with the live segments
/// and records the outbound request first, and — the lesson from Sprint
/// 7/17's gap — that the tab is actually reachable from `MainScreen`'s
/// real widget tree, and only while a session is recording.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/main_screen.dart';
import 'package:transcribe/src/rust/live_qa.dart' as rust_live_qa;
import 'package:transcribe/theme/app_icons.dart';
import 'package:transcribe/state/live_qa_model.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/widgets/live_qa_panel.dart';
import 'package:transcribe/widgets/personal_notes_panel.dart';

import 'test_helpers.dart';

List<TranscriptSegment> _seg(String text, double timestamp, String speaker) => [
  TranscriptSegment(
    source: 'mic',
    speaker: speaker,
    text: text,
    timestamp: timestamp,
    duration: 3,
    language: 'id',
    confidence: 0.9,
    isPartial: false,
  ),
];

final _transcript = [
  ..._seg('Kita bahas anggaran tahun depan.', 0, 'Saya'),
  ..._seg('Pagu anggaran disepakati naik sepuluh persen.', 30, 'Peserta 1'),
];

class _LiveQaBridge extends NoopBridge {
  _LiveQaBridge({this.answer});

  final rust_live_qa.LiveQaAnswer? answer;
  int asks = 0;
  List<TranscriptSegment>? lastSegments;

  @override
  Future<rust_live_qa.LiveQaAnswer> liveQaAsk({
    required String question,
    required List<TranscriptSegment> segments,
    required SummaryConfig config,
  }) async {
    asks++;
    lastSegments = segments;
    final a = answer;
    if (a == null) throw StateError('endpoint tidak menjawab');
    return a;
  }
}

AppSettings _withEndpoint() {
  final base = AppSettings.defaults();
  return base.copyWith(
    summary: base.summary.copyWith(
      enabled: true,
      baseUrl: 'http://127.0.0.1:11434',
      model: 'qwen2.5:0.5b',
    ),
  );
}

({LiveQaNotifier notifier, List<(String, int)> recorded}) _notifier(
  _LiveQaBridge bridge, {
  AppSettings? settings,
}) {
  final recorded = <(String, int)>[];
  final notifier = LiveQaNotifier(
    bridge,
    () => settings ?? AppSettings.defaults(),
    (endpoint, passages) => recorded.add((endpoint, passages)),
  );
  addTearDown(notifier.dispose);
  return (notifier: notifier, recorded: recorded);
}

Future<ProviderContainer> _pumpRecordingMainScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(buildTestAppWithOverrides(overrides: const []));
  await tester.pump();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(MainScreen)),
  );
  await container.read(sessionProvider.notifier).start();
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  group('notifier', () {
    test('refuses, rather than quietly answering, with no endpoint', () async {
      final bridge = _LiveQaBridge();
      final h = _notifier(bridge); // default settings: summary disabled
      await h.notifier.ask('apa keputusannya', _transcript);

      expect(bridge.asks, 0);
      expect(h.notifier.state.status, LiveQaStatus.failed);
      expect(
        h.notifier.state.turns.single.error,
        contains('memerlukan endpoint ringkasan'),
      );
      expect(h.recorded, isEmpty);
    });

    test('records the outbound request before making it', () async {
      final bridge = _LiveQaBridge(
        answer: rust_live_qa.LiveQaAnswer(
          answer: 'Pagu naik sepuluh persen [K1].',
          sources: [
            rust_live_qa.LiveQaHit(
              timestamp: 30,
              speaker: 'Peserta 1',
              text: 'Pagu anggaran disepakati naik sepuluh persen.',
            ),
          ],
        ),
      );
      final h = _notifier(bridge, settings: _withEndpoint());
      await h.notifier.ask('apa keputusan soal anggaran?', _transcript);

      expect(bridge.asks, 1);
      expect(bridge.lastSegments, _transcript);
      expect(h.recorded, [('http://127.0.0.1:11434', _transcript.length)]);

      final turn = h.notifier.state.turns.single;
      expect(turn.answer, 'Pagu naik sepuluh persen [K1].');
      expect(turn.sources, hasLength(1));
      expect(turn.error, isNull);
    });

    test('an endpoint failure is shown, not swallowed', () async {
      final bridge = _LiveQaBridge(); // liveQaAsk throws
      final h = _notifier(bridge, settings: _withEndpoint());
      await h.notifier.ask('apa keputusannya', _transcript);

      expect(h.notifier.state.status, LiveQaStatus.failed);
      expect(
        h.notifier.state.turns.single.error,
        contains('endpoint tidak menjawab'),
      );
      expect(h.recorded, hasLength(1));
    });
  });

  group('LiveQaPanel widget', () {
    testWidgets('typing a question and pressing Tanya reaches the bridge', (
      tester,
    ) async {
      final bridge = _LiveQaBridge(
        answer: rust_live_qa.LiveQaAnswer(
          answer: 'Pagu naik sepuluh persen [K1].',
          sources: [
            rust_live_qa.LiveQaHit(
              timestamp: 30,
              speaker: 'Peserta 1',
              text: 'Pagu anggaran disepakati naik sepuluh persen.',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: [
            rustBridgeProvider.overrideWithValue(bridge),
            settingsProvider.overrideWith((ref) {
              final notifier = SettingsNotifier(bridge);
              notifier.setSummarySettings(_withEndpoint().summary);
              return notifier;
            }),
          ],
          child: Scaffold(body: LiveQaPanel(segments: _transcript)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'apa keputusan soal anggaran?',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Tanya'));
      await tester.pumpAndSettle();

      expect(bridge.asks, 1);
      expect(bridge.lastSegments, _transcript);
      expect(find.textContaining('Pagu naik sepuluh persen'), findsOneWidget);
      expect(find.text('[K1]'), findsOneWidget);
    });
  });

  group('Tab Tanya Langsung di MainScreen', () {
    testWidgets('panel Tanya Langsung tersedia dari switcher saat merekam', (
      tester,
    ) async {
      await _pumpRecordingMainScreen(tester);

      // Default panel is still the notes panel, with the switcher reachable
      // from its header.
      expect(find.byType(PersonalNotesPanel), findsOneWidget);
      expect(find.byType(LiveQaPanel), findsNothing);
      expect(find.byIcon(AppIcons.moreVertical), findsOneWidget);

      // Discrete `pump`s past the popup menu's open transition, not
      // `pumpAndSettle`: a recording session has a perpetually pulsing
      // indicator (`RecordingDot`), so a settle that waits for every
      // animation to finish — or times out trying — never works here.
      await tester.tap(find.byIcon(AppIcons.moreVertical));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Tanya Langsung'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LiveQaPanel), findsOneWidget);
      expect(find.byType(PersonalNotesPanel), findsNothing);
    });

    testWidgets('switcher panel tidak muncul saat sesi idle', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(buildTestAppWithOverrides(overrides: const []));
      await tester.pump();

      expect(find.byIcon(AppIcons.moreVertical), findsNothing);
      expect(find.byType(LiveQaPanel), findsNothing);
    });
  });
}
