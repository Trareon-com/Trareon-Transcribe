/// Synthetic "three hour meeting" fixture.
///
/// Every performance claim in Sprint 2 is measured against this one shape:
/// **5 000 segments spanning 3 hours**, which is what a real 3-hour rapat
/// produces at roughly one utterance every two seconds. Before this existed
/// the app had never been run against its own target workload, so the
/// quadratic ingestion and the full-list rebuild in the transcript view were
/// invisible in every test and obvious the moment a real meeting ran long.
///
/// The generator is deterministic (fixed seed, no clock, no I/O): a
/// benchmark that produced different data on every run could not be
/// compared between commits.
///
/// This lives in `test/support/`, not `test/fixtures/`, on purpose:
/// `test/fixtures/` holds *generated* artifacts (the WAV files written by
/// `cargo run --bin gen_fixtures`) and is therefore gitignored. Hand-written
/// test sources placed there analyze fine locally and break CI with
/// `uri_does_not_exist`, because the file never reaches the remote.
/// `test/tracked_sources_test.dart` now enforces that.
library;

import 'dart:convert';
import 'dart:io';

import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';

/// Segment count of the canonical fixture. Matches the audit's target
/// workload (`docs/UX-FEATURE-AUDIT.md` A.1-11).
const int kBenchmarkSegmentCount = 5000;

/// Wall-clock span of the canonical fixture, in seconds (3 hours).
const double kBenchmarkDurationSeconds = 3 * 60 * 60;

/// Session count the library benchmark loads (audit exit criterion:
/// "library open with 200 sessions under 500 ms").
const int kBenchmarkSessionCount = 200;

/// Word pool for the synthetic transcript. Indonesian meeting vocabulary so
/// that search benchmarks hit realistic match densities rather than either
/// zero or everything.
const List<String> _words = [
  'rapat',
  'anggaran',
  'laporan',
  'tindak',
  'lanjut',
  'keputusan',
  'peserta',
  'notulen',
  'agenda',
  'evaluasi',
  'kuartal',
  'target',
  'kendala',
  'koordinasi',
  'dokumen',
  'jadwal',
  'presentasi',
  'usulan',
  'anggota',
  'divisi',
];

const List<String> _speakers = ['Pembicara 1', 'Pembicara 2', 'Pembicara 3', 'Pembicara 4'];

/// Deterministic 32-bit mixer — `dart:math`'s `Random(seed)` is also
/// deterministic, but an explicit mixer keeps the fixture identical across
/// Dart SDK versions, which a regression benchmark depends on.
int _mix(int x) {
  var v = (x * 0x27d4eb2d) & 0x7fffffff;
  v ^= v >> 15;
  v = (v * 0x85ebca6b) & 0x7fffffff;
  v ^= v >> 13;
  return v;
}

/// Builds [count] segments spread evenly over [totalSeconds].
///
/// Every segment gets a distinct `(source, timestamp)` pair, so the HPT
/// merge key (`TranscriptSegment.segmentKey`) is unique per row — the
/// ingestion benchmark measures appends, not accidental replacements.
List<TranscriptSegment> buildBenchmarkSegments({
  int count = kBenchmarkSegmentCount,
  double totalSeconds = kBenchmarkDurationSeconds,
  int seed = 7,
}) {
  final step = totalSeconds / count;
  return List<TranscriptSegment>.generate(count, (i) {
    final r = _mix(seed + i);
    final wordCount = 6 + r % 9;
    final text = List<String>.generate(
      wordCount,
      (w) => _words[_mix(r + w) % _words.length],
    ).join(' ');
    return TranscriptSegment(
      source: i.isEven ? 'mic' : 'spk',
      speaker: _speakers[r % _speakers.length],
      text: text,
      timestamp: double.parse((i * step).toStringAsFixed(2)),
      duration: double.parse((step * 0.9).toStringAsFixed(2)),
      language: 'id',
      confidence: 0.6 + (r % 40) / 100.0,
      isPartial: false,
      lowConfidence: r % 23 == 0,
      avgLogProb: -0.1 - (r % 50) / 100.0,
    );
  }, growable: false);
}

/// A single benchmark session's on-disk shape: the exporter's bare segment
/// array plus the metadata sidecar, exactly as [loadSessionLibrary] expects.
Future<void> writeBenchmarkSession(
  Directory libraryDir, {
  required String title,
  required DateTime date,
  int segmentCount = 40,
  int seed = 7,
}) async {
  final stamp =
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
  final dir = Directory('${libraryDir.path}${Platform.pathSeparator}$stamp-$title');
  await dir.create(recursive: true);
  final segments = buildBenchmarkSegments(
    count: segmentCount,
    totalSeconds: segmentCount * 2.16,
    seed: seed,
  );
  await File('${dir.path}${Platform.pathSeparator}$title.json')
      .writeAsString(encodeTranscriptJson(segments));
  await File('${dir.path}${Platform.pathSeparator}$kMetaFilename').writeAsString(
    jsonEncode(SessionMeta(title: title, language: 'id', model: 'base').toJson()),
  );
}

/// Writes [sessions] benchmark sessions into a fresh temp directory and
/// returns it. The caller owns the directory and must delete it.
Future<Directory> writeBenchmarkLibrary({
  int sessions = kBenchmarkSessionCount,
  int segmentsPerSession = 40,
}) async {
  final root = await Directory.systemTemp.createTemp('trareon_bench_lib_');
  for (var i = 0; i < sessions; i++) {
    await writeBenchmarkSession(
      root,
      title: 'Rapat ${i.toString().padLeft(3, '0')}',
      date: DateTime(2026, 1, 1).add(Duration(days: i)),
      segmentCount: segmentsPerSession,
      seed: 7 + i * 31,
    );
  }
  return root;
}
