/// Position → transcript-row lookup for the audio-synced player.
///
/// The player used to find the playing row with
/// `segments.lastIndexWhere((s) => s.timestamp <= pos && …)` on every
/// position tick — O(n) at 5–10 Hz, i.e. ~50 000 comparisons a second on a
/// 5 000-segment meeting (audit A.3-6). [SegmentTimeline] pays O(n log n)
/// once per transcript and answers each tick in O(log n).
library;

import '../state/models.dart';

class SegmentTimeline {
  /// Positions into the original segment list, ordered by start time.
  final List<int> _order;

  /// `_starts[i]` is the start time of `_order[i]`. Kept as a separate
  /// flat list so the binary search touches one contiguous array.
  final List<double> _starts;

  SegmentTimeline._(this._order, this._starts);

  /// Builds a timeline over [segments].
  ///
  /// The list is sorted rather than assumed sorted: live capture interleaves
  /// the mic and speaker pipelines, which can emit a speaker segment with an
  /// earlier timestamp than a mic segment already appended, and an imported
  /// or hand-edited transcript carries no ordering guarantee at all. A
  /// binary search over an unsorted array silently returns the wrong row.
  factory SegmentTimeline(List<TranscriptSegment> segments) {
    final order = List<int>.generate(segments.length, (i) => i, growable: false);
    order.sort((a, b) {
      final cmp = segments[a].timestamp.compareTo(segments[b].timestamp);
      return cmp != 0 ? cmp : a.compareTo(b);
    });
    final starts = List<double>.generate(
      order.length,
      (i) => segments[order[i]].timestamp,
      growable: false,
    );
    return SegmentTimeline._(order, starts);
  }

  static final SegmentTimeline empty = SegmentTimeline._(const [], const []);

  int get length => _order.length;

  /// Index (into the original list) of the row playing at [seconds], or
  /// `null` before the first segment starts.
  ///
  /// Sticky across gaps: the last row that has started stays highlighted
  /// through the silence before the next one. The previous predicate
  /// required `timestamp + duration > pos`, so the highlight blinked off
  /// during every pause in the meeting.
  int? indexAt(double seconds) {
    if (_order.isEmpty || seconds < _starts.first) return null;
    var lo = 0;
    var hi = _starts.length - 1;
    var found = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_starts[mid] <= seconds) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return _order[found];
  }
}
