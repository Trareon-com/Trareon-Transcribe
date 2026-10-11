import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/session_archive_service.dart';
import 'package:transcribe/services/session_store.dart';

import 'test_helpers.dart';

/// Fake import: instead of actually unzipping, writes whatever files the
/// test configured directly into `destinationDir` — the Rust-side zip
/// mechanics already have their own unit tests
/// (`rust_core/src/session_archive.rs`); this exercises only the Dart-side
/// orchestration (validate-then-move, conflict resolution).
class _FakeImportBridge extends NoopBridge {
  _FakeImportBridge(this.filesToWrite);

  /// Relative filename -> contents. Empty means "the zip had nothing in
  /// it" (an empty/bogus archive).
  final Map<String, String> filesToWrite;

  /// Set to simulate the Rust side rejecting an unreadable/corrupt zip.
  Object? throwsOnImport;

  @override
  Future<List<String>> importSessionArchive({
    required String archivePath,
    required String destinationDir,
  }) async {
    if (throwsOnImport != null) throw throwsOnImport!;
    for (final entry in filesToWrite.entries) {
      await File(
        '$destinationDir${Platform.pathSeparator}${entry.key}',
      ).writeAsString(entry.value);
    }
    return filesToWrite.keys.toList();
  }
}

void main() {
  group('sanitizeArchiveName', () {
    test('replaces characters illegal on some platform with underscore', () {
      expect(sanitizeArchiveName('Rapat: Q3/2026?'), 'Rapat_ Q3_2026_');
    });

    test('strips trailing dots and spaces (Windows drops them silently)', () {
      expect(sanitizeArchiveName('Rapat Tim.  '), 'Rapat Tim');
    });

    test('falls back to a default name when nothing is left', () {
      expect(sanitizeArchiveName('   '), 'sesi');
    });
  });

  group('archiveFilenameFor', () {
    test('prefixes the date when present', () {
      expect(
        archiveFilenameFor(title: 'Rapat Q3', date: '2026-07-25'),
        '20260725-Rapat Q3.zip',
      );
    });

    test('omits the date prefix when there is none', () {
      expect(archiveFilenameFor(title: 'Rapat Q3', date: ''), 'Rapat Q3.zip');
    });
  });

  group('extractAndValidateSessionArchive', () {
    late Directory library;

    setUp(() async {
      library = await Directory.systemTemp.createTemp('trareon-lib-');
    });

    tearDown(() async {
      if (await library.exists()) await library.delete(recursive: true);
    });

    test('accepts a valid session and reads its sidecar title', () async {
      final bridge = _FakeImportBridge({
        'transkrip.json': '[]',
        'trareon-session.json': '{"version":1,"title":"Rapat Tim"}',
      });

      final validated = await extractAndValidateSessionArchive(
        bridge,
        '/fake/path/to/archive.zip',
        library.path,
      );

      expect(validated.meta.title, 'Rapat Tim');
      expect(validated.suggestedDirName, 'Rapat Tim');
      expect(await validated.tempDir.exists(), isTrue);
    });

    test('falls back to the archive filename with no title', () async {
      final bridge = _FakeImportBridge({'transkrip.json': '[]'});

      final validated = await extractAndValidateSessionArchive(
        bridge,
        '/fake/path/to/Rapat Mingguan.zip',
        library.path,
      );

      expect(validated.suggestedDirName, 'Rapat Mingguan');
    });

    test(
      'rejects an archive with no transcript and leaves nothing behind',
      () async {
        final bridge = _FakeImportBridge({
          'trareon-session.json': '{"version":1,"title":"Bukan Sesi"}',
        });

        await expectLater(
          extractAndValidateSessionArchive(
            bridge,
            '/fake/path/bukan-sesi.zip',
            library.path,
          ),
          throwsA(isA<InvalidSessionArchiveException>()),
        );

        expect(
          library.listSync(),
          isEmpty,
          reason: 'a rejected import must not leave a scratch folder behind',
        );
      },
    );

    test(
      'rejects an empty archive and leaves nothing behind',
      () async {
        final bridge = _FakeImportBridge(const {});

        await expectLater(
          extractAndValidateSessionArchive(
            bridge,
            '/fake/path/empty.zip',
            library.path,
          ),
          throwsA(isA<InvalidSessionArchiveException>()),
        );
        expect(library.listSync(), isEmpty);
      },
    );

    test(
      'surfaces a corrupt/unreadable zip as InvalidSessionArchiveException '
      'and leaves nothing behind',
      () async {
        final bridge = _FakeImportBridge(const {})
          ..throwsOnImport = Exception('not a zip file');

        await expectLater(
          extractAndValidateSessionArchive(
            bridge,
            '/fake/path/corrupt.zip',
            library.path,
          ),
          throwsA(isA<InvalidSessionArchiveException>()),
        );
        expect(library.listSync(), isEmpty);
      },
    );
  });

  group('finalizeSessionImport', () {
    late Directory library;

    setUp(() async {
      library = await Directory.systemTemp.createTemp('trareon-lib-');
    });

    tearDown(() async {
      if (await library.exists()) await library.delete(recursive: true);
    });

    Future<ValidatedSessionImport> buildValidated(String suggestedName) async {
      final tempDir = await Directory(
        '${library.path}/.scratch-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      await File('${tempDir.path}/transkrip.json').writeAsString('[]');
      return ValidatedSessionImport(
        tempDir: tempDir,
        meta: SessionMeta.empty,
        suggestedDirName: suggestedName,
      );
    }

    test('moves the scratch dir into place when there is no conflict',
        () async {
      final validated = await buildValidated('Rapat Baru');
      final result = await finalizeSessionImport(
        validated,
        library.path,
        onConflict: () =>
            fail('onConflict must not be asked when there is no clash'),
      );

      expect(result, '${library.path}/Rapat Baru');
      expect(
        File('${library.path}/Rapat Baru/transkrip.json').existsSync(),
        isTrue,
      );
      expect(await validated.tempDir.exists(), isFalse);
    });

    test('skip: removes the scratch dir and leaves the existing one alone',
        () async {
      final existing = Directory('${library.path}/Rapat Lama')..createSync();
      File('${existing.path}/marker.txt').writeAsStringSync('lama');

      final validated = await buildValidated('Rapat Lama');
      final result = await finalizeSessionImport(
        validated,
        library.path,
        onConflict: () async => SessionImportConflictChoice.skip,
      );

      expect(result, isNull);
      expect(await validated.tempDir.exists(), isFalse);
      expect(File('${existing.path}/marker.txt').readAsStringSync(), 'lama');
    });

    test('duplicate: writes under a "(2)" suffixed name', () async {
      Directory('${library.path}/Rapat Lama').createSync();

      final validated = await buildValidated('Rapat Lama');
      final result = await finalizeSessionImport(
        validated,
        library.path,
        onConflict: () async => SessionImportConflictChoice.duplicate,
      );

      expect(result, '${library.path}/Rapat Lama (2)');
      expect(Directory('${library.path}/Rapat Lama').existsSync(), isTrue);
      expect(
        Directory('${library.path}/Rapat Lama (2)').existsSync(),
        isTrue,
      );
    });

    test('overwrite: replaces the existing session entirely', () async {
      final existing = Directory('${library.path}/Rapat Lama')..createSync();
      File('${existing.path}/marker.txt').writeAsStringSync('lama');

      final validated = await buildValidated('Rapat Lama');
      final result = await finalizeSessionImport(
        validated,
        library.path,
        onConflict: () async => SessionImportConflictChoice.overwrite,
      );

      expect(result, '${library.path}/Rapat Lama');
      expect(File('${existing.path}/marker.txt').existsSync(), isFalse);
      expect(
        File('${library.path}/Rapat Lama/transkrip.json').existsSync(),
        isTrue,
      );
    });
  });
}
