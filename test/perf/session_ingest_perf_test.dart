/// Permanent benchmark for live segment ingestion (audit A.1-12).
///
/// The old `_onTranscriptSegment` did a linear `indexWhere` over every
/// segment received so far and then copied the whole list. Over a
/// 5 000-segment meeting that is ~12.5 M comparisons plus ~12.5 M element
/// copies, on the UI isolate, while Whisper saturates the CPU.
///
/// The structural assertion is the one that matters: ingesting 4× the
/// segments must cost ~4× the time, not ~16×. It is measured as a *ratio*
/// of two runs on the same machine, so it holds on any hardware.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';

import '../fixtures/large_session.dart';
import '../test_helpers.dart';

/// Feeds a caller-controlled, *synchronous* transcript stream, so the
/// benchmark measures ingestion rather than event-loop scheduling.
class _StreamBridge extends NoopBridge {
  final StreamController<TranscriptSegment> controller =
      StreamController<TranscriptSegment>(sync: true);

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) =>
      controller.stream;
}

Future<int> _ingest(int count) async {
  final bridge = _StreamBridge();
  final notifier = SessionNotifier(
    bridge,
    SessionMode.online,
    'models/ggml-base.bin',
  );
  addTearDown(notifier.dispose);
  await notifier.start();
  final segments = buildBenchmarkSegments(
    count: count,
    totalSeconds: count * 2.16,
  );
  final sw = Stopwatch()..start();
  for (final segment in segments) {
    bridge.controller.add(segment);
  }
  sw.stop();
  expect(notifier.state.segments.length, count);
  expect(notifier.state.segments.last.text, segments.last.text);
  await bridge.controller.close();
  return sw.elapsedMicroseconds;
}

void main() {
  test('ingesting 5 000 segments is linear, not quadratic', () async {
    // Warm the JIT so the first (smaller) run is not unfairly penalised,
    // which would make a quadratic implementation look linear.
    await _ingest(200);

    final small = await _ingest(1250);
    final large = await _ingest(kBenchmarkSegmentCount);
    final ratio = large / small.clamp(1, 1 << 30);
    // ignore: avoid_print
    print('[perf] ingest 1250 = ${(small / 1000).toStringAsFixed(2)}ms, '
        '5000 = ${(large / 1000).toStringAsFixed(2)}ms, ratio = '
        '${ratio.toStringAsFixed(2)}× for 4× the segments');

    expect(
      ratio,
      lessThan(10),
      reason: 'a 4× longer meeting must not cost 16× as much to ingest — '
          'that is the O(n²) the map index removed',
    );
    expect(
      large,
      lessThan(2 * 1000 * 1000),
      reason: 'three hours of transcript must ingest in well under 2 s total',
    );
  });

  test('an HPT refine pass replaces its quick pass in O(1)', () async {
    final bridge = _StreamBridge();
    final notifier = SessionNotifier(
      bridge,
      SessionMode.online,
      'models/ggml-base.bin',
    );
    addTearDown(notifier.dispose);
    await notifier.start();

    final quick = buildBenchmarkSegments(count: kBenchmarkSegmentCount);
    for (final segment in quick) {
      bridge.controller.add(
        TranscriptSegment(
          source: segment.source,
          speaker: segment.speaker,
          text: 'cepat: ${segment.text}',
          timestamp: segment.timestamp,
          duration: segment.duration,
          language: segment.language,
          confidence: segment.confidence,
          isPartial: true,
        ),
      );
    }
    expect(notifier.state.segments, hasLength(kBenchmarkSegmentCount));
    expect(notifier.state.segments.first.isPartial, isTrue);

    // Refine the *first* segment: with a linear scan this is the cheap end,
    // with a map it is the same cost as any other. Refining the last one is
    // the pathological case for the old code.
    final sw = Stopwatch()..start();
    bridge.controller.add(quick.last);
    sw.stop();

    expect(notifier.state.segments, hasLength(kBenchmarkSegmentCount),
        reason: 'a refine must replace in place, never append a duplicate');
    expect(notifier.state.segments.last.isPartial, isFalse);
    expect(notifier.state.segments.last.text, quick.last.text);
    expect(notifier.state.segments.first.text, startsWith('cepat: '));
    // ignore: avoid_print
    print('[perf] refine of the 5000th row: ${sw.elapsedMicroseconds}µs');
    expect(sw.elapsedMicroseconds, lessThan(50000));

    // A late partial must still never clobber a refined row.
    bridge.controller.add(
      TranscriptSegment(
        source: quick.last.source,
        speaker: quick.last.speaker,
        text: 'partial telat',
        timestamp: quick.last.timestamp,
        duration: quick.last.duration,
        language: 'id',
        confidence: 0.5,
        isPartial: true,
      ),
    );
    expect(notifier.state.segments.last.text, quick.last.text);
    await bridge.controller.close();
  });

  test('the revision counter changes on an in-place edit', () async {
    final bridge = _StreamBridge();
    final notifier = SessionNotifier(
      bridge,
      SessionMode.online,
      'models/ggml-base.bin',
    );
    addTearDown(notifier.dispose);
    notifier.setSegments(buildBenchmarkSegments(count: 10));
    final before = notifier.state.revision;
    final lengthBefore = notifier.state.segments.length;

    notifier.editTranscriptSegment(3, 'teks baru');

    expect(notifier.state.segments.length, lengthBefore,
        reason: 'an edit changes neither length nor list identity, so the '
            'revision is the only signal the UI can cache against');
    expect(notifier.state.revision, greaterThan(before));
    expect(notifier.state.segments[3].text, 'teks baru');
  });
}
