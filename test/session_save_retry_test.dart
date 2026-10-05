import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';

import 'test_helpers.dart';

/// A failed auto-save on Stop used to be a three-second toast over a
/// transcript still sitting in memory, with no way to write it out short
/// of guessing that "Ekspor" would do it. These cover the retry path the
/// persistent banner drives.
class _FlakyExportBridge extends NoopBridge {
  _FlakyExportBridge({this.failuresRemaining = 0, this.hasAudio = true});

  int failuresRemaining;

  /// Whether the session captured anything worth placing.
  final bool hasAudio;
  final List<String> exportDirs = [];
  final List<String> audioDirs = [];

  @override
  Future<List<rust_export.ExportedFile>> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
      rust_export.ExportFormat.txt,
      rust_export.ExportFormat.json,
    ],
  }) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw const FileSystemException('disk penuh');
    }
    exportDirs.add(outputDir);
    return [
      rust_export.ExportedFile(
        filename: 'transcript.json',
        path:
            '$outputDir${Platform.pathSeparator}sesi'
            '${Platform.pathSeparator}transcript.json',
        sizeBytes: BigInt.from(10),
      ),
    ];
  }

  @override
  Future<List<rust_export.ExportedFile>> exportSessionAudio({
    required String sessionId,
    required String outputDir,
    required String title,
  }) async {
    audioDirs.add(outputDir);
    if (!hasAudio) return [];
    return [
      rust_export.ExportedFile(
        filename: 'mic.wav',
        path:
            '$outputDir${Platform.pathSeparator}sesi'
            '${Platform.pathSeparator}mic.wav',
        sizeBytes: BigInt.from(1024),
      ),
    ];
  }
}

/// Fails both exports on the first attempt, as a broken library path
/// would.
class _UnwritableFirstBridge extends _FlakyExportBridge {
  _UnwritableFirstBridge() : super(failuresRemaining: 1);

  bool _audioFailed = false;

  @override
  Future<List<rust_export.ExportedFile>> exportSessionAudio({
    required String sessionId,
    required String outputDir,
    required String title,
  }) async {
    audioDirs.add(outputDir);
    if (!_audioFailed) {
      _audioFailed = true;
      throw const FileSystemException('disk penuh');
    }
    return [];
  }
}

SessionNotifier notifierWith(RustBridge bridge) =>
    SessionNotifier(bridge, SessionMode.online, 'models/tiny.bin');

TranscriptSegment segment(String text) => TranscriptSegment(
  source: 'mic',
  speaker: 'MIC',
  text: text,
  timestamp: 0,
  duration: 1,
  language: 'id',
  confidence: 0.9,
  isPartial: false,
  lowConfidence: false,
  words: const [],
);

Future<void> stopWithSegments(
  SessionNotifier notifier, {
  required bool expectFailure,
}) async {
  notifier.state = notifier.state.copyWith(
    lifecycle: SessionLifecycle.recording,
    sessionId: 'sesi-1',
    sessionTitle: 'Rapat Anggaran',
  );
  notifier.setSegments([segment('halo')]);
  if (expectFailure) {
    await expectLater(notifier.stop(), throwsA(isA<TranscribeSaveError>()));
  } else {
    await notifier.stop();
  }
}

void main() {
  test('a successful save leaves nothing pending', () async {
    final bridge = _FlakyExportBridge();
    final notifier = notifierWith(bridge);
    addTearDown(notifier.dispose);

    await stopWithSegments(notifier, expectFailure: false);

    expect(notifier.hasUnsavedTranscript, isFalse);
    expect(bridge.exportDirs, hasLength(1));
    expect(bridge.audioDirs, hasLength(1));
  });

  test('a failed save keeps the transcript pending and retryable', () async {
    final bridge = _FlakyExportBridge(failuresRemaining: 1);
    final notifier = notifierWith(bridge);
    addTearDown(notifier.dispose);

    await stopWithSegments(notifier, expectFailure: true);

    expect(notifier.hasUnsavedTranscript, isTrue);
    expect(
      notifier.state.segments,
      hasLength(1),
      reason: 'the transcript must stay in memory for the retry',
    );

    await notifier.retrySave();

    expect(notifier.hasUnsavedTranscript, isFalse);
    expect(bridge.exportDirs, hasLength(1));
    expect(
      bridge.audioDirs,
      hasLength(1),
      reason:
          'the audio was already placed by the failed attempt and must '
          'not be claimed twice',
    );
  });

  test('retrySave can write somewhere else entirely', () async {
    final bridge = _FlakyExportBridge(failuresRemaining: 1);
    final notifier = notifierWith(bridge);
    addTearDown(notifier.dispose);

    await stopWithSegments(notifier, expectFailure: true);
    await notifier.retrySave(outputDir: '/tmp/lokasi-lain');

    expect(bridge.exportDirs, ['/tmp/lokasi-lain']);
    expect(
      bridge.audioDirs,
      [resolveTilde(kDefaultLibraryPath)],
      reason:
          'the audio landed on the first attempt; only the transcript '
          'still needed a home',
    );
  });

  /// When the library path itself is the problem, the audio export fails
  /// too — so "Simpan ke folder lain" has to rescue both.
  test(
    'a retry elsewhere also places audio the first attempt could not',
    () async {
      final bridge = _UnwritableFirstBridge();
      final notifier = notifierWith(bridge);
      addTearDown(notifier.dispose);

      await stopWithSegments(notifier, expectFailure: true);
      expect(bridge.audioDirs, hasLength(1), reason: 'attempted, and failed');

      await notifier.retrySave(outputDir: '/tmp/lokasi-lain');
      expect(bridge.audioDirs.last, '/tmp/lokasi-lain');
    },
  );

  test('a retry that fails again stays pending', () async {
    final bridge = _FlakyExportBridge(failuresRemaining: 2);
    final notifier = notifierWith(bridge);
    addTearDown(notifier.dispose);

    await stopWithSegments(notifier, expectFailure: true);
    await expectLater(
      notifier.retrySave(),
      throwsA(isA<TranscribeSaveError>()),
    );
    expect(notifier.hasUnsavedTranscript, isTrue);

    await notifier.retrySave();
    expect(notifier.hasUnsavedTranscript, isFalse);
  });

  test('retrySave does nothing when there is nothing pending', () async {
    final bridge = _FlakyExportBridge();
    final notifier = notifierWith(bridge);
    addTearDown(notifier.dispose);

    await notifier.retrySave();
    expect(bridge.exportDirs, isEmpty);
  });

  test('a session with no segments is not reported as unsaved', () async {
    final bridge = _FlakyExportBridge(hasAudio: false);
    final notifier = notifierWith(bridge);
    addTearDown(notifier.dispose);

    notifier.state = notifier.state.copyWith(
      lifecycle: SessionLifecycle.recording,
      sessionId: 'sesi-kosong',
    );
    await notifier.stop();

    expect(notifier.hasUnsavedTranscript, isFalse);
    expect(
      bridge.exportDirs,
      isEmpty,
      reason: 'nothing captured and nothing transcribed leaves no folder',
    );
  });

  /// Whisper can lag far behind capture on a slow machine, so stopping
  /// before the first segment is finalized is an ordinary outcome — and
  /// the recording is all there. The audio used to be discarded in
  /// exactly that case.
  test('audio is saved even when no segment was transcribed', () async {
    final bridge = _FlakyExportBridge();
    final notifier = notifierWith(bridge);
    addTearDown(notifier.dispose);

    notifier.state = notifier.state.copyWith(
      lifecycle: SessionLifecycle.recording,
      sessionId: 'sesi-tanpa-transkrip',
      sessionTitle: 'Rapat Lambat',
    );
    await notifier.stop();

    expect(bridge.audioDirs, hasLength(1));
    expect(
      bridge.exportDirs,
      hasLength(1),
      reason:
          'an empty transcript still gets written, so the session is '
          'visible in the library and can be re-transcribed later',
    );
  });

  test('the audio is placed before the transcript export can fail', () async {
    final bridge = _FlakyExportBridge(failuresRemaining: 1);
    final notifier = notifierWith(bridge);
    addTearDown(notifier.dispose);

    await stopWithSegments(notifier, expectFailure: true);

    expect(
      bridge.audioDirs,
      hasLength(1),
      reason:
          'a failed transcript save must not also strand the audio in '
          'the recovery directory',
    );
  });
}
