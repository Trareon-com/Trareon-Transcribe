/// Sprint 8: input-source and length-preset helpers for the notulen
/// dialog — kept pure and separate from the dialog widget so they're
/// testable without pumping a dialog.
library;

import 'models.dart';

/// One length preset the dropdown offers, mirroring `NotulenLength` on the
/// Rust side (`rust_core/src/notulen/mod.rs`) by hand, the same pattern
/// `notulen_templates.dart` uses for `NotulenTemplate`.
class NotulenLengthOption {
  const NotulenLengthOption({
    required this.value,
    required this.label,
    required this.wordTarget,
  });

  final NotulenLength value;
  final String label;
  final int wordTarget;
}

const List<NotulenLengthOption> kNotulenLengthOptions = [
  NotulenLengthOption(
    value: NotulenLength.ringkas,
    label: 'Ringkas',
    wordTarget: 250,
  ),
  NotulenLengthOption(
    value: NotulenLength.sedang,
    label: 'Sedang',
    wordTarget: 1000,
  ),
  NotulenLengthOption(
    value: NotulenLength.lengkap,
    label: 'Lengkap',
    wordTarget: 3000,
  ),
];

/// Turns typed/pasted "Poin catatan" text into the same `TranscriptSegment`
/// shape the session transcript uses, one non-blank line per segment, so
/// it can flow through the existing notulen map-reduce path unchanged.
///
/// Timestamps are a small strictly-increasing fake clock (one second per
/// line): `chunk_by_time` and the numbered-transcript renderer both order
/// segments by timestamp, so real wall-clock time would be meaningless
/// here but monotonic ordering still matters.
List<TranscriptSegment> manualNotesToSegments(String notes) {
  final lines = notes
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return [
    for (var i = 0; i < lines.length; i++)
      TranscriptSegment(
        source: 'catatan',
        speaker: 'Catatan',
        text: lines[i],
        timestamp: i.toDouble(),
        duration: 1.0,
        language: 'id',
        confidence: 1.0,
        isPartial: false,
      ),
  ];
}
