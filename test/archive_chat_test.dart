/// "Tanya arsip rapat" (F12), from the Flutter side.
///
/// The Rust side already has its own tests for the FTS5 index and the
/// composed answer. What is only testable here is the part the user
/// actually touches: that retrieval works with no endpoint configured,
/// that asking without one refuses loudly instead of silently degrading
/// to a search, and that a citation carries its timestamp — a cited
/// answer you cannot check is worse than no answer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/screens/archive_chat_screen.dart';
import 'package:transcribe/src/rust/archive.dart' as rust_archive;
import 'package:transcribe/state/archive_chat_model.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';

import 'test_helpers.dart';

/// Two hits in two different meetings, so a citation has somewhere
/// non-trivial to point. The second has no timestamp of its own (-1):
/// it is a summary, not a transcript line.
final _hits = <rust_archive.ArchiveHit>[
  rust_archive.ArchiveHit(
    dirPath: '/lib/20260901-Rapat Anggaran',
    title: 'Rapat Anggaran',
    date: '2026-09-01',
    timestamp: 612.5,
    speaker: 'Peserta 2',
    text: 'Anggaran kuartal depan disetujui sebesar dua miliar rupiah.',
    score: 9.5,
  ),
  rust_archive.ArchiveHit(
    dirPath: '/lib/20260915-Rapat Peluncuran',
    title: 'Rapat Peluncuran',
    date: '2026-09-15',
    timestamp: -1,
    speaker: '',
    text: 'Ringkasan: peluncuran ditunda ke November.',
    score: 4.25,
  ),
];

class _ArchiveBridge extends NoopBridge {
  _ArchiveBridge({this.answer});

  /// Null means "the endpoint failed", which is a different outcome from
  /// "no endpoint configured" and has to look different on screen.
  final rust_archive.ArchiveAnswer? answer;

  int searches = 0;
  int asks = 0;

  @override
  Future<List<rust_archive.ArchiveHit>> archiveSearch({
    required String libraryPath,
    required String question,
    int limit = 12,
  }) async {
    searches++;
    return _hits;
  }

  @override
  Future<rust_archive.ArchiveAnswer> archiveAsk({
    required String libraryPath,
    required String question,
    required SummaryConfig config,
  }) async {
    asks++;
    final a = answer;
    if (a == null) throw StateError('endpoint tidak menjawab');
    return a;
  }
}

/// Settings with a usable summary endpoint, so "Jawab" is allowed.
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

/// The notifier under test, built directly rather than through the
/// provider: the provider's settings arrive from an async load off disk,
/// and what these tests are about is the behaviour given some settings.
({ArchiveChatNotifier notifier, List<(String, int)> recorded}) _notifier(
  _ArchiveBridge bridge, {
  AppSettings? settings,
}) {
  final recorded = <(String, int)>[];
  final notifier = ArchiveChatNotifier(
    bridge,
    () => settings ?? AppSettings.defaults(),
    (endpoint, passages) => recorded.add((endpoint, passages)),
  );
  addTearDown(notifier.dispose);
  return (notifier: notifier, recorded: recorded);
}

void main() {
  testWidgets('Cari works with no endpoint configured and cites its sources', (
    tester,
  ) async {
    final bridge = _ArchiveBridge();
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: const ArchiveChatScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'anggaran kuartal depan');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cari'));
    await tester.pumpAndSettle();

    expect(bridge.searches, 1);
    // Retrieval must not have touched the networked path at all.
    expect(bridge.asks, 0);
    expect(find.text('Kutipan'), findsOneWidget);
    expect(find.text('[K1]'), findsOneWidget);
    expect(find.text('[K2]'), findsOneWidget);
    // A real timestamp is rendered as a time; a summary hit (-1) says so
    // instead of rendering a nonsense negative clock.
    expect(
      find.textContaining('Rapat Anggaran (2026-09-01) · [10:12]'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Rapat Peluncuran (2026-09-15) · ringkasan'),
      findsOneWidget,
    );
  });

  testWidgets('a citation opens its meeting at the moment it came from', (
    tester,
  ) async {
    final bridge = _ArchiveBridge();
    final jumps = <(String, double)>[];
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: ArchiveChatScreen(
          onOpenSession: (dirPath, timestamp) =>
              jumps.add((dirPath, timestamp)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'anggaran');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cari'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('[K1]'));
    await tester.pumpAndSettle();
    expect(jumps, [('/lib/20260901-Rapat Anggaran', 612.5)]);

    // A summary hit has no timestamp of its own; it must land at the
    // start rather than at a negative position.
    await tester.tap(find.text('[K2]'));
    await tester.pumpAndSettle();
    expect(jumps.last, ('/lib/20260915-Rapat Peluncuran', 0.0));
  });

  test(
    'Jawab refuses, rather than quietly searching, with no endpoint',
    () async {
      final bridge = _ArchiveBridge();
      final h = _notifier(bridge); // default settings: summary disabled
      await h.notifier.ask('apa keputusannya');

      expect(bridge.asks, 0);
      // Not even retrieval: the user pressed the button that sends data
      // somewhere, so the refusal has to come before anything happens.
      expect(bridge.searches, 0);
      expect(h.notifier.state.status, ArchiveChatStatus.failed);
      expect(
        h.notifier.state.turns.single.error,
        contains('memerlukan endpoint ringkasan'),
      );
      expect(h.recorded, isEmpty);
    },
  );

  test('Cari needs no endpoint and sends nothing', () async {
    final bridge = _ArchiveBridge();
    final h = _notifier(bridge);
    await h.notifier.search('anggaran');

    expect(bridge.searches, 1);
    expect(h.notifier.state.turns.single.sources, hasLength(2));
    expect(h.recorded, isEmpty);
  });

  test('Jawab records the outbound request before making it', () async {
    final bridge = _ArchiveBridge(
      answer: rust_archive.ArchiveAnswer(
        answer: 'Anggaran disetujui dua miliar [K1].',
        sources: _hits,
      ),
    );
    final h = _notifier(bridge, settings: _withEndpoint());
    await h.notifier.ask('apa keputusannya');

    expect(bridge.asks, 1);
    // The passage count is the point of recording this separately from a
    // summary: it is how many past meetings' text left the machine.
    expect(h.recorded, [('http://127.0.0.1:11434', 2)]);

    final turn = h.notifier.state.turns.single;
    expect(turn.answer, 'Anggaran disetujui dua miliar [K1].');
    expect(turn.sources, hasLength(2));
    expect(turn.error, isNull);
  });

  test('an endpoint failure is shown, not swallowed', () async {
    final bridge = _ArchiveBridge(); // archiveAsk throws
    final h = _notifier(bridge, settings: _withEndpoint());
    await h.notifier.ask('apa keputusannya');

    expect(h.notifier.state.status, ArchiveChatStatus.failed);
    expect(
      h.notifier.state.turns.single.error,
      contains('endpoint tidak menjawab'),
    );
    // Recorded even though it failed: the request did leave the machine,
    // and a Privacy Report that only logs successes understates that.
    expect(h.recorded, hasLength(1));
  });

  test('an empty index answers plainly without calling the endpoint', () async {
    final bridge = _EmptyArchiveBridge();
    final h = _notifier(bridge, settings: _withEndpoint());
    await h.notifier.ask('apa keputusannya');

    expect(bridge.asks, 0);
    expect(h.recorded, isEmpty);
    expect(
      h.notifier.state.turns.single.answer,
      'Tidak ditemukan di arsip rapat.',
    );
  });
}

/// A library that is indexed but holds nothing matching.
class _EmptyArchiveBridge extends _ArchiveBridge {
  @override
  Future<List<rust_archive.ArchiveHit>> archiveSearch({
    required String libraryPath,
    required String question,
    int limit = 12,
  }) async {
    searches++;
    return const [];
  }
}
