/// Permanent benchmark for the transcript list at the workload the product
/// is sold for: a 5 000-segment, three-hour meeting.
///
/// Two kinds of assertion live here on purpose:
///
/// * **Structural** — how many rows are materialised, and how the cost of a
///   frame scales from a 40-segment transcript to a 5 000-segment one.
///   Expressed as ratios measured on the same machine in the same run, so
///   they hold on any hardware and are the real regression guards.
/// * **Absolute timings** — printed (`[perf] …`) so the sprint report can
///   quote real numbers, and asserted only against deliberately loose
///   ceilings. A tight absolute budget under `flutter test` would be a
///   flaky test, not a performance gate: the test binding builds widgets
///   far slower than a release build.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/widgets/transcript_view.dart';

import '../support/large_session.dart';

/// Size of the control transcript the 5 000-segment numbers are compared
/// against. Small enough that no plausible implementation struggles.
const int kControlSegmentCount = 40;

/// How much more a frame may cost at 5 000 segments than at 40. A
/// per-frame cost that is independent of transcript length lands near 1×;
/// the old "rebuild a tuple list of every segment on every build" lands
/// above 100×. 6× leaves ample room for cache effects and GC noise.
const double kScaleBudget = 6.0;

class _Stats {
  _Stats(this.label, List<int> micros)
    : n = micros.length,
      avg = micros.reduce((a, b) => a + b) / micros.length,
      p95 = (([...micros]
        ..sort())[(micros.length * 0.95).floor().clamp(0, micros.length - 1)]),
      max = ([...micros]..sort()).last;

  final String label;
  final int n;
  final double avg;
  final int p95;
  final int max;

  @override
  String toString() =>
      '$label: n=$n avg=${(avg / 1000).toStringAsFixed(2)}ms '
      'p95=${(p95 / 1000).toStringAsFixed(2)}ms '
      'max=${(max / 1000).toStringAsFixed(2)}ms';

  void report() => debugPrint('[perf] $this');
}

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: <ThemeExtension<dynamic>>[AppColors.light]),
  home: Scaffold(body: child),
);

void _sizeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  late List<TranscriptSegment> big;
  late List<TranscriptSegment> small;

  setUpAll(() {
    big = buildBenchmarkSegments();
    small = buildBenchmarkSegments(
      count: kControlSegmentCount,
      totalSeconds: kControlSegmentCount * 2.16,
    );
  });

  testWidgets('5 000 segments materialise only the visible rows', (
    tester,
  ) async {
    _sizeViewport(tester);

    final firstBuild = Stopwatch()..start();
    await tester.pumpWidget(_host(TranscriptView(segments: big)));
    await tester.pump();
    firstBuild.stop();
    debugPrint(
      '[perf] first build of ${big.length} segments: '
      '${firstBuild.elapsedMilliseconds}ms',
    );

    expect(find.text('5000 segmen'), findsOneWidget);
    final built = tester.widgetList(find.byType(TranscriptSegmentTile)).length;
    debugPrint('[perf] rows materialised at rest: $built');
    expect(
      built,
      lessThan(60),
      reason: 'the list must lazily build ~a viewport of rows, not 5 000',
    );
    expect(firstBuild.elapsedMilliseconds, lessThan(4000));
  });

  testWidgets('scroll frame cost does not grow with transcript length', (
    tester,
  ) async {
    _sizeViewport(tester);

    Future<_Stats> measure(
      String label,
      List<TranscriptSegment> segments,
    ) async {
      await tester.pumpWidget(
        _host(TranscriptView(key: ValueKey(label), segments: segments)),
      );
      await tester.pump();
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -900),
        2000,
      );
      final frames = <int>[];
      for (var i = 0; i < 40; i++) {
        final sw = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 16));
        sw.stop();
        frames.add(sw.elapsedMicroseconds);
      }
      await tester.pumpAndSettle();
      return _Stats(label, frames)..report();
    }

    final control = await measure('scroll @$kControlSegmentCount', small);
    final loaded = await measure('scroll @${big.length}', big);
    final scale = loaded.avg / control.avg;
    debugPrint('[perf] scroll scale factor: ${scale.toStringAsFixed(2)}×');
    expect(
      scale,
      lessThan(kScaleBudget),
      reason:
          'scrolling a 3-hour transcript must cost the same per frame '
          'as scrolling a 90-second one — $control vs $loaded',
    );
  });

  testWidgets('a parent rebuild does not walk the whole transcript', (
    tester,
  ) async {
    _sizeViewport(tester);

    // Mirrors the live screen: the elapsed timer, the VU meter and each
    // arriving segment all rebuild the transcript's parent, ~5 times a
    // second, for hours (audit A.1-11).
    Future<_Stats> measure(
      String label,
      List<TranscriptSegment> segments,
    ) async {
      var revision = 0;
      late StateSetter setOuter;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            key: ValueKey(label),
            builder: (context, setState) {
              setOuter = setState;
              return TranscriptView(segments: segments, revision: revision);
            },
          ),
        ),
      );
      await tester.pump();
      final frames = <int>[];
      for (var i = 0; i < 40; i++) {
        setOuter(() => revision = revision); // same data, new build
        final sw = Stopwatch()..start();
        await tester.pump();
        sw.stop();
        frames.add(sw.elapsedMicroseconds);
      }
      return _Stats(label, frames)..report();
    }

    final control = await measure('rebuild @$kControlSegmentCount', small);
    final loaded = await measure('rebuild @${big.length}', big);
    final scale = loaded.avg / control.avg;
    debugPrint(
      '[perf] parent-rebuild scale factor: ${scale.toStringAsFixed(2)}×',
    );
    expect(scale, lessThan(kScaleBudget), reason: '$control vs $loaded');
  });

  testWidgets('search over 5 000 segments is debounced and responsive', (
    tester,
  ) async {
    _sizeViewport(tester);

    await tester.pumpWidget(_host(TranscriptView(segments: big)));
    await tester.pump();

    // Type the query character by character, the way a user does. Each
    // keystroke must stay cheap: only the last one may filter.
    const query = 'anggaran';
    final keystrokes = <int>[];
    for (var i = 1; i <= query.length; i++) {
      await tester.enterText(find.byType(TextField), query.substring(0, i));
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 20));
      sw.stop();
      keystrokes.add(sw.elapsedMicroseconds);
    }
    _Stats('keystroke @${big.length}', keystrokes).report();

    final filterSw = Stopwatch()..start();
    await tester.pump(kTranscriptSearchDebounce);
    await tester.pumpAndSettle();
    filterSw.stop();
    debugPrint(
      '[perf] filter pass @${big.length}: '
      '${filterSw.elapsedMilliseconds}ms',
    );

    expect(find.textContaining('dari 5000 segmen'), findsOneWidget);
    expect(filterSw.elapsedMilliseconds, lessThan(2000));
  });

  testWidgets('position ticks that do not change the row are free', (
    tester,
  ) async {
    _sizeViewport(tester);

    final active = ValueNotifier<int?>(null);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      _host(
        TranscriptView(
          segments: big,
          activeSegmentIndex: active,
          onSeekToSegment: (_, _) {},
        ),
      ),
    );
    await tester.pump();

    active.value = 12;
    await tester.pumpAndSettle();
    final ticks = <int>[];
    for (var i = 0; i < 100; i++) {
      final sw = Stopwatch()..start();
      active.value = 12; // the audio moved, the row did not
      await tester.pump();
      sw.stop();
      ticks.add(sw.elapsedMicroseconds);
    }
    final stats = _Stats('unchanged position tick @${big.length}', ticks)
      ..report();
    expect(
      stats.avg,
      lessThan(2000),
      reason:
          'a repeated identical value must not schedule a frame at '
          'all — $stats',
    );
  });

  testWidgets('seeking across the meeting reveals the playing row', (
    tester,
  ) async {
    _sizeViewport(tester);

    final active = ValueNotifier<int?>(null);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      _host(
        TranscriptView(
          segments: big,
          activeSegmentIndex: active,
          onSeekToSegment: (_, _) {},
        ),
      ),
    );
    await tester.pump();

    // A manual seek to hour two. Jumping a `ListView.builder` there builds
    // every intervening row (measured: 20 s); the anchored viewport must
    // not.
    final sw = Stopwatch()..start();
    active.value = 4200;
    await tester.pumpAndSettle();
    sw.stop();
    debugPrint(
      '[perf] reveal row 4200 of ${big.length}: '
      '${sw.elapsedMilliseconds}ms',
    );

    final activeTiles = tester
        .widgetList<TranscriptSegmentTile>(find.byType(TranscriptSegmentTile))
        .where((t) => t.isActive)
        .toList();
    expect(
      activeTiles,
      hasLength(1),
      reason: 'the active row must be scrolled into view',
    );
    expect(activeTiles.single.segment.text, big[4200].text);
    expect(sw.elapsedMilliseconds, lessThan(3000));

    // And playback continues smoothly from there.
    active.value = 4201;
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<TranscriptSegmentTile>(find.byType(TranscriptSegmentTile))
          .where((t) => t.isActive)
          .single
          .segment
          .text,
      big[4201].text,
    );
  });

  testWidgets('tapping a row seeks the audio to that segment', (tester) async {
    _sizeViewport(tester);

    final active = ValueNotifier<int?>(null);
    addTearDown(active.dispose);
    final seeks = <double>[];
    await tester.pumpWidget(
      _host(
        TranscriptView(
          segments: big,
          activeSegmentIndex: active,
          onSeekToSegment: (index, segment) => seeks.add(segment.timestamp),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TranscriptSegmentTile).at(2));
    await tester.pump();
    expect(seeks, [big[2].timestamp]);
  });
}
