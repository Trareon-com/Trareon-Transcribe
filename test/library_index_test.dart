import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/library_index.dart';
import 'package:transcribe/services/session_store.dart';

import 'session_store_test.dart' show seg, writeSessionDir;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('trareon_library_index_test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File indexFile() => File('${root.path}/$kLibraryIndexFilename');

  group('dateFromDirName', () {
    test('reads the exporter date prefix', () {
      expect(dateFromDirName('20260930-Rapat Tim'), '2026-09-30');
    });

    test('is null without a prefix', () {
      expect(dateFromDirName('Rapat Tim'), isNull);
      expect(dateFromDirName('2026-Rapat'), isNull);
    });
  });

  group('loadLibraryIndex', () {
    test('reads title, duration, snippet and audio path', () async {
      await writeSessionDir(
        root,
        '20260930-Rapat Q3',
        segments: [seg('halo', ts: 0), seg('selesai', ts: 8)],
        audioName: 'Rapat Q3.m4a',
      );

      final load = await loadLibraryIndex(root.path);
      expect(load.entries, hasLength(1));
      final entry = load.entries.single;
      expect(entry.title, 'Rapat Q3', reason: 'date prefix must be stripped');
      expect(entry.date, '2026-09-30');
      expect(entry.segmentsCount, 2);
      expect(entry.durationSeconds, 10, reason: 'last timestamp + duration');
      expect(entry.audioPath, endsWith('Rapat Q3.m4a'));
      expect(entry.snippet, 'Saya: halo');
      expect(load.parsedFromDisk, 1);
    });

    test('the sidecar title wins over the folder name', () async {
      await writeSessionDir(
        root,
        '20260930-Sesi 2026-09-30 14-05',
        segments: [seg('halo')],
        meta: const SessionMeta(title: 'Rapat Anggaran'),
      );
      final load = await loadLibraryIndex(root.path);
      expect(load.entries.single.title, 'Rapat Anggaran');
    });

    test('a blank sidecar title falls back to the folder name', () async {
      await writeSessionDir(
        root,
        '20260930-Rapat',
        segments: [seg('halo')],
        meta: const SessionMeta(title: '   '),
      );
      expect((await loadLibraryIndex(root.path)).entries.single.title, 'Rapat');
    });

    test('one unreadable session does not empty the library', () async {
      await writeSessionDir(root, '20260930-Baik', segments: [seg('halo')]);
      final broken = Directory('${root.path}/20260930-Rusak')..createSync();
      File('${broken.path}/transkrip.json').writeAsStringSync('{{{ not json');

      final load = await loadLibraryIndex(root.path);
      expect(load.entries.map((e) => e.title), ['Baik']);
    });

    test('directories with no transcript are skipped', () async {
      Directory('${root.path}/20260930-Kosong').createSync();
      expect((await loadLibraryIndex(root.path)).entries, isEmpty);
    });

    test('a missing library directory is empty, not an error', () async {
      final load = await loadLibraryIndex('${root.path}/does-not-exist');
      expect(load.entries, isEmpty);
    });

    test('newest first, by the directory date and not by mtime', () async {
      await writeSessionDir(root, '20260101-Lama', segments: [seg('a')]);
      await writeSessionDir(root, '20261231-Baru', segments: [seg('b')]);
      // Touching the old session — what renaming or saving a summary does —
      // used to relabel it today and move it to the top (audit A.2-7).
      File('${root.path}/20260101-Lama/transkrip.json')
          .setLastModifiedSync(DateTime.now());

      final load = await loadLibraryIndex(root.path);
      expect(load.entries.map((e) => e.title), ['Baru', 'Lama']);
      expect(load.entries.last.date, '2026-01-01');
    });
  });

  group('the index file', () {
    Future<void> waitForIndex() async {
      for (var i = 0; i < 100; i++) {
        if (indexFile().existsSync()) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('is written on the first load and reused on the second', () async {
      await writeSessionDir(root, '20260930-Rapat', segments: [seg('halo')]);
      expect((await loadLibraryIndex(root.path)).parsedFromDisk, 1);
      await waitForIndex();

      final second = await loadLibraryIndex(root.path);
      expect(second.parsedFromDisk, 0);
      expect(second.entries.single.title, 'Rapat');
    });

    test('a changed transcript invalidates only its own entry', () async {
      await writeSessionDir(root, '20260930-Satu', segments: [seg('satu')]);
      await writeSessionDir(root, '20260930-Dua', segments: [seg('dua')]);
      await loadLibraryIndex(root.path);
      await waitForIndex();

      final file = File('${root.path}/20260930-Satu/transkrip.json');
      file.writeAsStringSync(encodeTranscriptJson([seg('satu diubah')]));

      final reload = await loadLibraryIndex(root.path);
      expect(reload.parsedFromDisk, 1);
      expect(
        reload.entries.firstWhere((e) => e.title == 'Satu').snippet,
        contains('satu diubah'),
      );
    });

    test('a new session is picked up without re-parsing the old ones',
        () async {
      await writeSessionDir(root, '20260930-Satu', segments: [seg('satu')]);
      await loadLibraryIndex(root.path);
      await waitForIndex();

      await writeSessionDir(root, '20261001-Dua', segments: [seg('dua')]);
      final reload = await loadLibraryIndex(root.path);
      expect(reload.parsedFromDisk, 1);
      expect(reload.entries, hasLength(2));
    });

    test('a corrupt index costs one slow open, not the library', () async {
      await writeSessionDir(root, '20260930-Rapat', segments: [seg('halo')]);
      await loadLibraryIndex(root.path);
      await waitForIndex();
      indexFile().writeAsStringSync('{{{ not json');

      final reload = await loadLibraryIndex(root.path);
      expect(reload.entries, hasLength(1));
      expect(reload.parsedFromDisk, 1);
    });

    test('an index from a future version is discarded, not trusted', () async {
      await writeSessionDir(root, '20260930-Rapat', segments: [seg('halo')]);
      indexFile().writeAsStringSync(jsonEncode({
        'version': kLibraryIndexVersion + 1,
        'entries': [
          {'dir': '20260930-Rapat', 'title': 'Judul Palsu'},
        ],
      }));

      final load = await loadLibraryIndex(root.path);
      expect(load.entries.single.title, 'Rapat');
      expect(load.parsedFromDisk, 1);
    });

    test('stores directory names, so moving the library still works',
        () async {
      await writeSessionDir(root, '20260930-Rapat', segments: [seg('halo')]);
      await loadLibraryIndex(root.path);
      await waitForIndex();
      final decoded = jsonDecode(indexFile().readAsStringSync()) as Map;
      final entries = decoded['entries'] as List;
      expect(entries.single['dir'], '20260930-Rapat');
      expect(jsonEncode(decoded), isNot(contains(root.path)));
    });
  });

  group('search', () {
    test('the haystack covers title, first line and summary', () async {
      await writeSessionDir(
        root,
        '20260930-Sesi 2026-09-30 14-05',
        segments: [seg('kita putuskan pakai anggaran cadangan')],
        meta: const SessionMeta(summary: '## Keputusan\n- Pakai Rust'),
      );
      final entry = (await loadLibraryIndex(root.path)).entries.single;
      expect(entry.haystack, contains('anggaran'));
      expect(entry.haystack, contains('rust'));
      expect(entry.haystack, isNot(contains('KEPUTUSAN')),
          reason: 'the haystack is pre-lowercased so search never has to be');
    });

    test('the deep scan finds a word buried in the transcript body',
        () async {
      await writeSessionDir(root, '20260930-Rapat', segments: [
        seg('pembukaan'),
        seg('soal zirkonium', speaker: 'Peserta 1'),
      ]);
      await writeSessionDir(root, '20260930-Lain', segments: [seg('halo')]);
      final entries = (await loadLibraryIndex(root.path)).entries;

      final hits = deepSearchLibrarySync(
        entries.map((e) => e.dirPath).toList(),
        'ZIRKONIUM',
      );
      expect(hits, hasLength(1));
      expect(hits.single.snippet, 'Peserta 1: soal zirkonium');
    });

    test('an empty query scans nothing', () async {
      await writeSessionDir(root, '20260930-Rapat', segments: [seg('halo')]);
      final entries = (await loadLibraryIndex(root.path)).entries;
      final paths = entries.map((e) => e.dirPath).toList();
      expect(deepSearchLibrarySync(paths, '   '), isEmpty);
      expect(await deepSearchLibrary(paths, ''), isEmpty);
    });
  });

  group('loadSessionRecord', () {
    test('returns the full transcript for one session', () async {
      await writeSessionDir(
        root,
        '20260930-Rapat',
        segments: [seg('halo', ts: 0), seg('dunia', ts: 4)],
        audioName: 'Rapat.wav',
      );
      final record = await loadSessionRecord('${root.path}/20260930-Rapat');
      expect(record, isNotNull);
      expect(record!.segments.map((s) => s.text), ['halo', 'dunia']);
      expect(record.audioPath, endsWith('Rapat.wav'));
      expect(record.date, '2026-09-30');
    });

    test('is null for a directory that is not there', () async {
      expect(await loadSessionRecord('${root.path}/nope'), isNull);
    });
  });
}
