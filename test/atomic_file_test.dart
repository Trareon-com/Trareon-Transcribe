import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/utils/atomic_file.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('trareon_atomic_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  File fileIn(String name) => File('${dir.path}${Platform.pathSeparator}$name');

  test('writes the contents and leaves no temp file behind', () async {
    final target = fileIn('transcript.json');
    await writeStringAtomic(target, '{"a":1}');

    expect(await target.readAsString(), '{"a":1}');
    final leftovers = dir
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((name) => name.endsWith('.tmp'));
    expect(leftovers, isEmpty);
  });

  test('replaces an existing file completely, not partially', () async {
    final target = fileIn('transcript.json');
    await target.writeAsString('a' * 5000);
    await writeStringAtomic(target, 'short');

    expect(await target.readAsString(), 'short');
    expect(await target.length(), 5);
  });

  test('round-trips non-ASCII as UTF-8 on every platform', () async {
    final target = fileIn('transcript.json');
    const text = 'Rapat anggaran — Ibu Sití “menyetujui” 🎙';
    await writeStringAtomic(target, text);

    expect(await target.readAsString(), text);
    expect(await target.readAsBytes(), utf8.encode(text));
  });

  test('creates the target directory when it is missing', () async {
    final target = File(
      '${dir.path}${Platform.pathSeparator}baru'
      '${Platform.pathSeparator}transcript.json',
    );
    await writeStringAtomic(target, 'isi');
    expect(await target.readAsString(), 'isi');
  });

  /// The whole point: a write that fails must not have destroyed what was
  /// already there. Simulated by making the target a directory, so the
  /// rename cannot land.
  test('a failed write leaves the previous file intact', () async {
    final target = fileIn('transcript.json');
    await target.writeAsString('versi lama');

    final blocker = Directory('${target.path}.$pid.tmp');
    await blocker.create();
    addTearDown(() async {
      if (await blocker.exists()) await blocker.delete(recursive: true);
    });

    await expectLater(
      writeStringAtomic(target, 'versi baru'),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      await target.readAsString(),
      'versi lama',
      reason: 'a failed save must not also lose the last good save',
    );
  });

  test('propagates failures rather than swallowing them', () async {
    final target = File('/nonexistent-root-xyz/transcript.json');
    await expectLater(
      writeStringAtomic(target, 'isi'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('writeBytesAtomic handles binary payloads', () async {
    final target = fileIn('blob.bin');
    final bytes = List<int>.generate(512, (i) => i % 256);
    await writeBytesAtomic(target, bytes);
    expect(await target.readAsBytes(), bytes);
  });
}
