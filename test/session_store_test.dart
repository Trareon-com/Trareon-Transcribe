import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';

TranscriptSegment seg(String text, {String speaker = 'Saya', double ts = 0}) {
  return TranscriptSegment(
    source: 'mic',
    speaker: speaker,
    text: text,
    timestamp: ts,
    duration: 2,
    language: 'id',
    confidence: 0.9,
    isPartial: false,
  );
}

SessionRecord record({
  String title = 'Rapat Q3',
  List<TranscriptSegment>? segments,
  SessionMeta meta = SessionMeta.empty,
}) {
  return SessionRecord(
    dirPath: '/tmp/20260930-$title',
    title: title,
    date: '2026-09-30',
    segments: segments ?? [seg('halo semua')],
    durationSeconds: 10,
    meta: meta,
  );
}

/// Creates a session folder the way the Rust exporter does: a date-prefixed
/// directory holding a bare segment array as `<title>.json`.
Future<Directory> writeSessionDir(
  Directory root,
  String dirName, {
  required List<TranscriptSegment> segments,
  String transcriptName = 'transkrip.json',
  SessionMeta? meta,
  String? audioName,
}) async {
  final dir = Directory('${root.path}/$dirName')..createSync(recursive: true);
  File('${dir.path}/$transcriptName')
      .writeAsStringSync(encodeTranscriptJson(segments));
  if (meta != null) await writeSessionMeta(dir.path, meta);
  if (audioName != null) File('${dir.path}/$audioName').writeAsStringSync('');
  return dir;
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('trareon_library_test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('titleFromDirName', () {
    test('strips the exporter date prefix', () {
      expect(titleFromDirName('20260930-Rapat Tim'), 'Rapat Tim');
    });

    test('leaves an unprefixed name alone', () {
      expect(titleFromDirName('Rapat Tim'), 'Rapat Tim');
      // A number that isn't an 8-digit date prefix must survive intact.
      expect(titleFromDirName('2026-Rapat'), '2026-Rapat');
    });
  });

  group('sessionMatchesQuery', () {
    test('matches transcript text, not just the title', () {
      // The whole point of full-text search: auto-titled sessions are named
      // "Sesi 2026-09-30 14:05", which nobody searches for.
      final r = record(
        title: 'Sesi 2026-09-30 14:05',
        segments: [seg('kita putuskan pakai anggaran cadangan')],
      );
      expect(sessionMatchesQuery(r, 'anggaran'), isTrue);
      expect(sessionMatchesQuery(r, 'kontrak'), isFalse);
    });

    test('matches the saved summary', () {
      final r = record(
        segments: [seg('halo')],
        meta: const SessionMeta(summary: '## Keputusan\n- Pakai Rust'),
      );
      expect(sessionMatchesQuery(r, 'rust'), isTrue);
    });

    test('is case-insensitive and ignores surrounding whitespace', () {
      final r = record(segments: [seg('Anggaran Tahunan')]);
      expect(sessionMatchesQuery(r, '  ANGGARAN '), isTrue);
    });

    test('an empty query matches everything', () {
      expect(sessionMatchesQuery(record(), ''), isTrue);
      expect(sessionMatchesQuery(record(), '   '), isTrue);
    });
  });

  group('matchingSnippet', () {
    test('returns the first matching transcript line with its speaker', () {
      final r = record(
        segments: [seg('pembukaan'), seg('soal anggaran', speaker: 'Peserta 1')],
      );
      expect(matchingSnippet(r, 'anggaran'), 'Peserta 1: soal anggaran');
    });

    test('is null when only the title matched', () {
      final r = record(title: 'Rapat Q3', segments: [seg('halo')]);
      expect(matchingSnippet(r, 'Q3'), isNull);
    });
  });

  group('SessionMeta', () {
    test('round-trips through JSON', () {
      final meta = SessionMeta(
        title: 'Rapat Tim',
        summary: '## Ringkasan\nHalo',
        summaryTemplate: SummaryTemplate.actionItems,
        summaryGeneratedAt: DateTime.utc(2026, 9, 30, 12),
        language: 'id',
        model: 'large-v3-turbo-q5',
      );
      final decoded = SessionMeta.fromJson(
        jsonDecode(jsonEncode(meta.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.title, 'Rapat Tim');
      expect(decoded.summary, '## Ringkasan\nHalo');
      expect(decoded.summaryTemplate, SummaryTemplate.actionItems);
      expect(decoded.language, 'id');
      expect(decoded.model, 'large-v3-turbo-q5');
      expect(decoded.summaryGeneratedAt, DateTime.utc(2026, 9, 30, 12));
    });

    test('survives missing, wrongly-typed and unknown fields', () {
      // A hand-edited or newer-version sidecar must not make a session
      // unopenable.
      final decoded = SessionMeta.fromJson({
        'title': 42,
        'summary': null,
        'summary_template': 'aTemplateFromTheFuture',
        'summary_generated_at': 'not a date',
        'unknown_key': true,
      });
      expect(decoded.title, isNull);
      expect(decoded.summary, '');
      expect(decoded.summaryTemplate, isNull);
      expect(decoded.summaryGeneratedAt, isNull);
      expect(decoded.hasSummary, isFalse);
    });

    test('hasSummary ignores whitespace-only summaries', () {
      expect(const SessionMeta(summary: '   \n ').hasSummary, isFalse);
      expect(const SessionMeta(summary: 'x').hasSummary, isTrue);
    });
  });

  group('readSessionMeta / writeSessionMeta', () {
    test('round-trips through disk', () async {
      final dir = '${root.path}/session';
      await writeSessionMeta(dir, const SessionMeta(title: 'Rapat', summary: 'X'));
      final read = await readSessionMeta(dir);
      expect(read.title, 'Rapat');
      expect(read.summary, 'X');
    });

    test('a missing or corrupt sidecar yields empty, never an exception', () async {
      expect(await readSessionMeta('${root.path}/nope'), SessionMeta.empty);

      final dir = Directory('${root.path}/broken')..createSync();
      File('${dir.path}/$kMetaFilename').writeAsStringSync('{not json');
      expect((await readSessionMeta(dir.path)).hasSummary, isFalse);

      File('${dir.path}/$kMetaFilename').writeAsStringSync('[1,2,3]');
      expect(await readSessionMeta(dir.path), SessionMeta.empty);
    });
  });

  group('transcript JSON', () {
    test('round-trips every field the exporter writes', () {
      final segments = [
        const TranscriptSegment(
          source: 'spk',
          speaker: 'Peserta 1',
          text: 'halo',
          timestamp: 1.5,
          duration: 2.25,
          language: 'id',
          confidence: 0.87,
          isPartial: false,
          lowConfidence: true,
          avgLogProb: -0.42,
        ),
      ];
      final parsed = parseTranscriptJson(encodeTranscriptJson(segments));
      expect(parsed, hasLength(1));
      expect(parsed.single.speaker, 'Peserta 1');
      expect(parsed.single.timestamp, 1.5);
      expect(parsed.single.lowConfidence, isTrue);
      expect(parsed.single.avgLogProb, -0.42);
    });

    test('non-array JSON parses to an empty list rather than throwing', () {
      expect(parseTranscriptJson('{"not":"an array"}'), isEmpty);
    });
  });

  group('transcriptFileIn', () {
    test('never picks the metadata sidecar as the transcript', () async {
      // The sidecar is JSON too. Picking it would make every summarised
      // session look empty, and saving over it would destroy the summary.
      final dir = await writeSessionDir(
        root,
        '20260930-Rapat',
        segments: [seg('halo')],
        meta: const SessionMeta(summary: 'ringkasan'),
      );
      final file = transcriptFileIn(dir);
      expect(file, isNotNull);
      expect(file!.path.endsWith(kMetaFilename), isFalse);
      expect(parseTranscriptJson(file.readAsStringSync()), hasLength(1));
    });

    test('returns null when there is no transcript', () {
      final dir = Directory('${root.path}/empty')..createSync();
      expect(transcriptFileIn(dir), isNull);
    });
  });

  group('loadSessionLibrary', () {
    test('loads transcript, title, duration and audio path', () async {
      await writeSessionDir(
        root,
        '20260930-Rapat Q3',
        segments: [seg('halo', ts: 0), seg('selesai', ts: 8)],
        audioName: 'Rapat Q3.m4a',
      );

      final sessions = await loadSessionLibrary(root.path);
      expect(sessions, hasLength(1));
      final s = sessions.single;
      expect(s.title, 'Rapat Q3', reason: 'date prefix must be stripped');
      expect(s.segmentsCount, 2);
      expect(s.durationSeconds, 10, reason: 'last timestamp + duration');
      expect(s.audioPath, endsWith('Rapat Q3.m4a'));
    });

    test('the sidecar title wins over the folder name', () async {
      await writeSessionDir(
        root,
        '20260930-Sesi 2026-09-30 14-05',
        segments: [seg('halo')],
        meta: const SessionMeta(title: 'Rapat Anggaran'),
      );
      final sessions = await loadSessionLibrary(root.path);
      expect(sessions.single.title, 'Rapat Anggaran');
    });

    test('a blank sidecar title falls back to the folder name', () async {
      await writeSessionDir(
        root,
        '20260930-Rapat',
        segments: [seg('halo')],
        meta: const SessionMeta(title: '   '),
      );
      expect((await loadSessionLibrary(root.path)).single.title, 'Rapat');
    });

    test('one unreadable session does not empty the library', () async {
      await writeSessionDir(root, '20260930-Baik', segments: [seg('halo')]);
      final broken = Directory('${root.path}/20260930-Rusak')..createSync();
      File('${broken.path}/transkrip.json').writeAsStringSync('{{{ not json');

      final sessions = await loadSessionLibrary(root.path);
      expect(sessions.map((s) => s.title), ['Baik']);
    });

    test('directories with no transcript are skipped', () async {
      Directory('${root.path}/20260930-Kosong').createSync();
      expect(await loadSessionLibrary(root.path), isEmpty);
    });

    test('a missing library directory is empty, not an error', () async {
      expect(await loadSessionLibrary('${root.path}/does-not-exist'), isEmpty);
    });
  });
}
