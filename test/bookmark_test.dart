import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';

import 'test_helpers.dart';

/// Bookmarks (F9): placed during a recording, round-tripped through the
/// sidecar, and never silently moved.
void main() {
  group('SessionNotifier bookmarks', () {
    SessionNotifier notifier() => SessionNotifier(
      NoopBridge(),
      SessionMode.offline,
      'models/ggml-base.bin',
    );

    test('an idle session cannot be marked', () {
      final session = notifier();
      // A marker needs a recording to point into; silently placing one at
      // 0 s would create a bookmark for a meeting that never happened.
      expect(session.addBookmark(), isNull);
      expect(session.state.bookmarks, isEmpty);
    });

    test('markers land in timestamp order regardless of insertion order',
        () async {
      final session = notifier();
      await session.start();

      session.addBookmark(note: 'pertama');
      session.addBookmark(note: 'kedua');
      // Both land at ~0 s in a test, so assert the ordering invariant rather
      // than exact values.
      final bookmarks = session.state.bookmarks;
      expect(bookmarks.length, 2);
      for (var i = 1; i < bookmarks.length; i++) {
        expect(
          bookmarks[i].timestamp,
          greaterThanOrEqualTo(bookmarks[i - 1].timestamp),
        );
      }
      expect(bookmarks.map((b) => b.note), containsAll(['pertama', 'kedua']));
    });

    test('the note is optional and trimmed', () async {
      final session = notifier();
      await session.start();
      final bookmark = session.addBookmark(note: '   ');
      expect(bookmark!.note, isEmpty);

      session.setBookmarkNote(bookmark.timestamp, '  keputusan penting  ');
      expect(session.state.bookmarks.single.note, 'keputusan penting');
    });

    test('a marker can be removed by its timestamp', () async {
      final session = notifier();
      await session.start();
      final bookmark = session.addBookmark()!;
      session.removeBookmark(bookmark.timestamp);
      expect(session.state.bookmarks, isEmpty);
    });

    test('starting a new session clears the previous meeting markers',
        () async {
      final session = notifier();
      await session.start();
      session.addBookmark(note: 'rapat pertama');
      expect(session.state.bookmarks, isNotEmpty);

      await session.stop();
      await session.start();
      expect(
        session.state.bookmarks,
        isEmpty,
        reason: 'carrying markers over would point them at timestamps that no '
            'longer exist',
      );
    });
  });

  group('sidecar round-trip', () {
    test('bookmarks survive a write and come back sorted', () async {
      final dir = await Directory.systemTemp.createTemp('trareon-bookmark-');
      try {
        await writeSessionMeta(
          dir.path,
          const SessionMeta(
            title: 'Rapat',
            bookmarks: [
              Bookmark(timestamp: 312.5, note: 'keputusan'),
              Bookmark(timestamp: 65.0, note: ''),
            ],
          ),
        );
        final meta = await readSessionMeta(dir.path);
        expect(meta.bookmarks.map((b) => b.timestamp), [65.0, 312.5]);
        expect(meta.bookmarks.last.note, 'keputusan');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('a session with no bookmarks writes no bookmarks key', () async {
      final dir = await Directory.systemTemp.createTemp('trareon-bookmark-');
      try {
        await writeSessionMeta(dir.path, const SessionMeta(title: 'Rapat'));
        final raw = await File(
          '${dir.path}${Platform.pathSeparator}$kMetaFilename',
        ).readAsString();
        expect(raw.contains('bookmarks'), isFalse);
        expect((await readSessionMeta(dir.path)).bookmarks, isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('a hand-edited sidecar cannot inject a nonsense marker', () async {
      final dir = await Directory.systemTemp.createTemp('trareon-bookmark-');
      try {
        await File('${dir.path}${Platform.pathSeparator}$kMetaFilename')
            .writeAsString('''
{
  "version": 1,
  "title": "Rapat",
  "bookmarks": [
    {"timestamp": -5, "note": "sebelum rekaman"},
    {"note": "tanpa waktu"},
    "bukan objek",
    {"timestamp": 10.5, "note": "sah"}
  ]
}
''');
        final meta = await readSessionMeta(dir.path);
        expect(meta.bookmarks.length, 1);
        expect(meta.bookmarks.single.timestamp, 10.5);
        expect(meta.bookmarks.single.note, 'sah');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
