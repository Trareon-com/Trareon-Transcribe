import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/utils/segment_lookup.dart';

import 'fixtures/large_session.dart';

TranscriptSegment seg(double start, double duration, {String source = 'mic'}) =>
    TranscriptSegment(
      source: source,
      speaker: 'A',
      text: 't$start',
      timestamp: start,
      duration: duration,
      language: 'id',
      confidence: 1,
      isPartial: false,
    );

void main() {
  test('an empty transcript has no active row', () {
    expect(SegmentTimeline(const []).indexAt(5), isNull);
    expect(SegmentTimeline.empty.indexAt(5), isNull);
  });

  test('nothing is active before the first segment starts', () {
    final timeline = SegmentTimeline([seg(10, 2), seg(12, 2)]);
    expect(timeline.indexAt(0), isNull);
    expect(timeline.indexAt(9.99), isNull);
    expect(timeline.indexAt(10), 0);
  });

  test('the highlight is sticky across silence between segments', () {
    final timeline = SegmentTimeline([seg(0, 1), seg(30, 1)]);
    // The old predicate required `timestamp + duration > pos`, so the
    // highlight blinked off during every pause in the meeting.
    expect(timeline.indexAt(15), 0);
    expect(timeline.indexAt(30), 1);
    expect(timeline.indexAt(1000), 1);
  });

  test('unsorted input still resolves correctly', () {
    // Live capture interleaves two pipelines: a speaker segment can be
    // appended after a mic segment that starts later.
    final segments = [seg(20, 2, source: 'spk'), seg(0, 2), seg(10, 2)];
    final timeline = SegmentTimeline(segments);
    expect(timeline.indexAt(0), 1);
    expect(timeline.indexAt(11), 2);
    expect(timeline.indexAt(25), 0);
  });

  test('agrees with a linear scan across the whole 3-hour fixture', () {
    final segments = buildBenchmarkSegments();
    final timeline = SegmentTimeline(segments);
    int? linear(double t) {
      int? best;
      var bestStart = double.negativeInfinity;
      for (var i = 0; i < segments.length; i++) {
        final s = segments[i].timestamp;
        if (s <= t && s >= bestStart) {
          bestStart = s;
          best = i;
        }
      }
      return best;
    }

    for (var t = 0.0; t < kBenchmarkDurationSeconds; t += 37.3) {
      expect(timeline.indexAt(t), linear(t), reason: 'at t=$t');
    }
  });

  test('lookups over 5 000 segments are effectively free', () {
    final timeline = SegmentTimeline(buildBenchmarkSegments());
    final sw = Stopwatch()..start();
    for (var i = 0; i < 100000; i++) {
      timeline.indexAt((i % 10800).toDouble());
    }
    sw.stop();
    // ignore: avoid_print
    print('[perf] 100 000 binary-search lookups: ${sw.elapsedMilliseconds}ms');
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}
