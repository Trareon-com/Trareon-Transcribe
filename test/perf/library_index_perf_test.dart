/// Permanent benchmark for the library's two-phase load (audit A.2-3/4/5).
///
/// Exit criterion from the sprint plan: **opening a library of 200 sessions
/// is under 500 ms.** That is asserted here against a real temp-directory
/// corpus, not a mock.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/library_index.dart';
import 'package:transcribe/services/session_store.dart';

import '../fixtures/large_session.dart';

/// The exit criterion, in milliseconds.
const int kLibraryOpenBudgetMs = 500;

void main() {
  late Directory library;

  setUpAll(() async {
    final sw = Stopwatch()..start();
    library = await writeBenchmarkLibrary();
    sw.stop();
    debugPrint('[perf] wrote $kBenchmarkSessionCount session fixtures in '
        '${sw.elapsedMilliseconds}ms');
  });

  tearDownAll(() {
    if (library.existsSync()) library.deleteSync(recursive: true);
  });

  test('a warm open of 200 sessions is under 500 ms', () async {
    // Cold: no index file yet, so every session is parsed once. This is the
    // cost the *old* code paid on every single open.
    final cold = Stopwatch()..start();
    final first = await loadLibraryIndex(library.path);
    cold.stop();
    expect(first.entries, hasLength(kBenchmarkSessionCount));
    expect(first.parsedFromDisk, kBenchmarkSessionCount);
    debugPrint('[perf] cold library open (index build): '
        '${cold.elapsedMilliseconds}ms');

    // The index is written best-effort in the background; give it a moment.
    for (var i = 0; i < 50; i++) {
      if (File('${library.path}/$kLibraryIndexFilename').existsSync()) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(File('${library.path}/$kLibraryIndexFilename').existsSync(), isTrue);

    final warm = Stopwatch()..start();
    final second = await loadLibraryIndex(library.path);
    warm.stop();
    debugPrint('[perf] warm library open (index hit): '
        '${warm.elapsedMilliseconds}ms');

    expect(second.entries, hasLength(kBenchmarkSessionCount));
    expect(
      second.parsedFromDisk,
      0,
      reason: 'a warm open must not re-parse a single transcript',
    );
    expect(
      warm.elapsedMilliseconds,
      lessThan(kLibraryOpenBudgetMs),
      reason: 'sprint exit criterion: 200 sessions open in under '
          '${kLibraryOpenBudgetMs}ms (took ${warm.elapsedMilliseconds}ms)',
    );
    expect(warm.elapsedMilliseconds, lessThan(cold.elapsedMilliseconds));
  });

  test('a stale entry is re-derived, the rest are not', () async {
    await loadLibraryIndex(library.path);
    for (var i = 0; i < 50; i++) {
      if (File('${library.path}/$kLibraryIndexFilename').existsSync()) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    // Edit one transcript the way the player's autosave would.
    final target = (await loadLibraryIndex(library.path)).entries.first;
    final transcript = transcriptFileIn(Directory(target.dirPath))!;
    final segments = parseTranscriptJson(await transcript.readAsString());
    await transcript.writeAsString(encodeTranscriptJson([
      segments.first.copyWith(text: 'kata kunci yang sangat khas'),
      ...segments.skip(1),
    ]));

    final reload = await loadLibraryIndex(library.path);
    expect(reload.parsedFromDisk, 1,
        reason: 'only the session whose transcript changed may be re-parsed');
    final updated =
        reload.entries.firstWhere((e) => e.dirPath == target.dirPath);
    expect(updated.snippet, contains('kata kunci yang sangat khas'));
  });

  test('search over the index is instant; the deep scan finds the rest',
      () async {
    final load = await loadLibraryIndex(library.path);
    final entries = load.entries;

    // Index-level match: title only, no disk access at all.
    final sw = Stopwatch()..start();
    var matches = 0;
    for (var i = 0; i < 100; i++) {
      matches = entries.where((e) => e.haystack.contains('rapat 01')).length;
    }
    sw.stop();
    debugPrint('[perf] 100 index-level searches over '
        '${entries.length} sessions: ${sw.elapsedMilliseconds}ms');
    expect(matches, greaterThan(0));
    expect(sw.elapsedMilliseconds, lessThan(kLibraryOpenBudgetMs));

    // A word that only exists inside one transcript body: the index cannot
    // answer it, so the deep scan must.
    final target = entries[7];
    final transcript = transcriptFileIn(Directory(target.dirPath))!;
    final segments = parseTranscriptJson(await transcript.readAsString());
    await transcript.writeAsString(encodeTranscriptJson([
      ...segments.take(20),
      segments[20].copyWith(text: 'pembahasan tentang zirkonium'),
      ...segments.skip(21),
    ]));

    final refreshed = (await loadLibraryIndex(library.path)).entries;
    expect(
      refreshed.where((e) => e.haystack.contains('zirkonium')),
      isEmpty,
      reason: 'the word is deep in the transcript, not in the index',
    );

    final deepSw = Stopwatch()..start();
    final hits = deepSearchLibrarySync(
      refreshed.map((e) => e.dirPath).toList(),
      'zirkonium',
    );
    deepSw.stop();
    debugPrint('[perf] deep scan of ${refreshed.length} transcripts: '
        '${deepSw.elapsedMilliseconds}ms');
    expect(hits, hasLength(1));
    expect(hits.single.dirPath, target.dirPath);
    expect(hits.single.snippet, contains('zirkonium'));
  });

  test('the isolate-backed deep search returns the same answer', () async {
    final entries = (await loadLibraryIndex(library.path)).entries;
    final hits = await deepSearchLibrary(
      entries.map((e) => e.dirPath).toList(),
      'zirkonium',
    );
    expect(hits, hasLength(1));
    expect(hits.single.snippet, contains('zirkonium'));
  });

  test('opening one session parses only that session', () async {
    final entries = (await loadLibraryIndex(library.path)).entries;
    final sw = Stopwatch()..start();
    final record = await loadSessionRecord(entries.first.dirPath);
    sw.stop();
    debugPrint('[perf] phase-2 load of one session: ${sw.elapsedMilliseconds}ms');
    expect(record, isNotNull);
    expect(record!.segments, isNotEmpty);
    expect(sw.elapsedMilliseconds, lessThan(kLibraryOpenBudgetMs));
  });

  test('the date comes from the directory prefix, not the mtime', () async {
    final entries = (await loadLibraryIndex(library.path)).entries;
    // Fixtures are dated 2026-01-01 onwards; the files were written today.
    expect(entries.last.date, '2026-01-01');
    expect(entries.first.date, startsWith('2026-'));
    expect(
      entries.first.date.compareTo(entries.last.date),
      greaterThan(0),
      reason: 'newest first',
    );
  });
}
