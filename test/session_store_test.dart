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
  File(
    '${dir.path}/$transcriptName',
  ).writeAsStringSync(encodeTranscriptJson(segments));
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
      await writeSessionMeta(
        dir,
        const SessionMeta(title: 'Rapat', summary: 'X'),
      );
      final read = await readSessionMeta(dir);
      expect(read.title, 'Rapat');
      expect(read.summary, 'X');
    });

    test(
      'a missing or corrupt sidecar yields empty, never an exception',
      () async {
        expect(await readSessionMeta('${root.path}/nope'), SessionMeta.empty);

        final dir = Directory('${root.path}/broken')..createSync();
        File('${dir.path}/$kMetaFilename').writeAsStringSync('{not json');
        expect((await readSessionMeta(dir.path)).hasSummary, isFalse);

        File('${dir.path}/$kMetaFilename').writeAsStringSync('[1,2,3]');
        expect(await readSessionMeta(dir.path), SessionMeta.empty);
      },
    );
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
}
