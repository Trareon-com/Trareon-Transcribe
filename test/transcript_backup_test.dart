import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';

/// "Transkrip Ulang" replaced the transcript in place: an hour of hand
/// corrections destroyed by one button, with no backup and no undo.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('trareon_backup_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  List<TranscriptSegment> segments(List<String> texts) => [
    for (var i = 0; i < texts.length; i++)
      TranscriptSegment(
        source: 'mic',
        speaker: 'MIC',
        text: texts[i],
        timestamp: i * 3.0,
        duration: 2,
        language: 'id',
        confidence: 0.9,
        isPartial: false,
        lowConfidence: false,
      ),
  ];

  test('no backup exists before a re-transcribe', () async {
    expect(transcriptBackupIn(dir.path), isNull);
    expect(await readTranscriptBackup(dir.path), isNull);
  });

  test('a backup round-trips the corrected transcript', () async {
    final corrected = segments(['halo semua', 'terima kasih']);
    await backupTranscript(dir.path, corrected);

    expect(transcriptBackupIn(dir.path), isNotNull);
    final restored = await readTranscriptBackup(dir.path);
    expect(restored, isNotNull);
    expect(restored!.map((s) => s.text), ['halo semua', 'terima kasih']);
    expect(restored.first.timestamp, 0);
    expect(restored.last.timestamp, 3);
  });

  /// The backup is JSON in the same directory, and `transcriptFileIn`
  /// picks "the first .json that isn't the sidecar" — so without an
  /// explicit exclusion, the backup could be loaded *as* the transcript
  /// and quietly resurrect pre-correction text.
  test('the backup is never mistaken for the transcript', () async {
    await backupTranscript(dir.path, segments(['versi lama']));
    expect(
      transcriptFileIn(dir),
      isNull,
      reason: 'only the backup exists; there is no transcript yet',
    );

    final transcript = File(
      '${dir.path}${Platform.pathSeparator}transcript.json',
    );
    await transcript.writeAsString(
      encodeTranscriptJson(segments(['versi baru'])),
    );
    await writeSessionMeta(dir.path, const SessionMeta(title: 'Rapat'));

    final found = transcriptFileIn(dir);
    expect(found, isNotNull);
    expect(
      parseTranscriptJson(await found!.readAsString()).first.text,
      'versi baru',
    );
  });

  test('a corrupt backup reads as absent rather than throwing', () async {
    await File(
      '${dir.path}${Platform.pathSeparator}$kTranscriptBackupFilename',
    ).writeAsString('not json at all');
    expect(await readTranscriptBackup(dir.path), isNull);
  });

  test('an empty backup is not offered as a restore', () async {
    await backupTranscript(dir.path, const []);
    expect(
      await readTranscriptBackup(dir.path),
      isNull,
      reason: 'restoring an empty transcript is worse than not offering it',
    );
  });

  test('backing up again replaces the previous copy', () async {
    await backupTranscript(dir.path, segments(['pertama']));
    await backupTranscript(dir.path, segments(['kedua']));
    final restored = await readTranscriptBackup(dir.path);
    expect(restored!.map((s) => s.text), ['kedua']);
  });

  test('a backup failure is raised, not swallowed', () async {
    await expectLater(
      backupTranscript('/nonexistent-root-xyz/session', segments(['x'])),
      throwsA(isA<FileSystemException>()),
    );
  });
}
