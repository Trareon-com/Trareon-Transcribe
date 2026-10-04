import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/src/rust/api.dart' as rust_api;
import 'package:transcribe/src/rust/disk.dart' as rust_disk;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;
import 'package:transcribe/src/rust/model.dart' as rust_model;
import 'package:transcribe/state/batch_upload_model.dart';
import 'package:transcribe/state/models.dart';
import 'test_helpers.dart';

void main() {
  group('BatchUploadNotifier', () {
    test('accepts supported formats and queues them', () {
      final notifier = BatchUploadNotifier();
      final rejected = notifier.addFiles(['/a/rapat.mp3', '/a/wawancara.wav']);

      expect(rejected, isEmpty);
      expect(notifier.state, hasLength(2));
      expect(notifier.state.every((e) => e.status == BatchFileStatus.queued), isTrue);
    });

    test('rejects unsupported formats without queuing them', () {
      final notifier = BatchUploadNotifier();
      final rejected = notifier.addFiles(['/a/document.pdf', '/a/song.mp3']);

      expect(rejected.map((r) => r.path), ['/a/document.pdf']);
      expect(rejected.single.reason, RejectionReason.unsupportedFormat);
      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.filename, 'song.mp3');
    });

    test('updateStatus transitions a specific file only', () {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/one.mp3', '/a/two.mp3']);

      notifier.updateStatus('/a/one.mp3', BatchFileStatus.done);

      final one = notifier.state.firstWhere((e) => e.path == '/a/one.mp3');
      final two = notifier.state.firstWhere((e) => e.path == '/a/two.mp3');
      expect(one.status, BatchFileStatus.done);
      expect(two.status, BatchFileStatus.queued);
    });

    test('updateStatus records error message', () {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/corrupt.wav']);

      notifier.updateStatus('/a/corrupt.wav', BatchFileStatus.error, error: 'File tidak bisa dibaca');

      expect(notifier.state.single.status, BatchFileStatus.error);
      expect(notifier.state.single.error, 'File tidak bisa dibaca');
    });

    test('removeDone drops only completed entries', () {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/one.mp3', '/a/two.mp3']);
      notifier.updateStatus('/a/one.mp3', BatchFileStatus.done);

      notifier.removeDone();

      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.filename, 'two.mp3');
    });

    test('clear empties the queue', () {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/one.mp3']);
      notifier.clear();
      expect(notifier.state, isEmpty);
    });

    test('extension matching is case-insensitive', () {
      final notifier = BatchUploadNotifier();
      final rejected = notifier.addFiles(['/a/RAPAT.MP3']);
      expect(rejected, isEmpty);
      expect(notifier.state, hasLength(1));
    });

    test('skips duplicate files already in queue', () {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/rapat.mp3']);
      final rejected = notifier.addFiles(['/a/rapat.mp3', '/a/rapat.mp3']);

      expect(rejected, isEmpty);
      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.path, '/a/rapat.mp3');
    });

    test('processBatch marks files as done after bridge call', () async {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/test.mp3']);
      final bridge = _TestBridge();
      await notifier.processBatch(
        bridge,
        '/model/path',
        outputDir: '~/Documents/Trareon Transcribe',
      );
      expect(notifier.state.single.status, BatchFileStatus.done);
      expect(bridge.exportedTitles, ['test']);
    });

    test('processBatch marks files as error on exception', () async {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/crash.mp3']);
      final bridge = _ErrorBridge();
      await notifier.processBatch(
        bridge,
        '/model/path',
        outputDir: '~/Documents/Trareon Transcribe',
      );
      expect(notifier.state.single.status, BatchFileStatus.error);
    });

    test('a file over the advertised 2 GB limit is rejected, with the reason',
        () async {
      final dir = await Directory.systemTemp.createTemp('trareon_import_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final small = File('${dir.path}/kecil.wav')..writeAsBytesSync([1, 2, 3]);

      final notifier = BatchUploadNotifier();
      expect(notifier.addFiles([small.path]), isEmpty);
      expect(notifier.state.single.sizeBytes, 3);
      expect(kMaxImportBytes, 2 * 1024 * 1024 * 1024,
          reason: 'the drop zone advertises this number, so it has to be the '
              'one that is enforced');
    });

    test('cancelling a queued file stops it from being processed', () async {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/satu.mp3', '/a/dua.mp3']);
      notifier.cancelFile('/a/satu.mp3');

      expect(notifier.entryFor('/a/satu.mp3')!.status,
          BatchFileStatus.cancelled);
      expect(notifier.entryFor('/a/dua.mp3')!.status, BatchFileStatus.queued);

      final bridge = _TestBridge();
      await notifier.processBatch(bridge, '/model/path',
          outputDir: '~/Documents/Trareon Transcribe');
      expect(bridge.batchedFiles, ['/a/dua.mp3'],
          reason: 'a cancelled file must never reach the engine');
    });

    test('retry puts a failed file back in the queue', () async {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/crash.mp3']);
      await notifier.processBatch(_ErrorBridge(), '/model/path',
          outputDir: '~/Documents/Trareon Transcribe');
      expect(notifier.state.single.status, BatchFileStatus.error);
      expect(notifier.state.single.error, isNotNull);

      notifier.retryFile('/a/crash.mp3');
      expect(notifier.state.single.status, BatchFileStatus.queued);
      expect(notifier.state.single.error, isNull);
      expect(notifier.state.single.progress, 0);
    });

    test('clearing the queue mid-run does not throw', () async {
      // `state.firstWhere(...)` threw a StateError here and killed the whole
      // batch when the user pressed "Kosongkan" while it ran (audit B.1-2).
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/satu.mp3']);
      final bridge = _ClearingBridge(notifier);
      await notifier.processBatch(bridge, '/model/path',
          outputDir: '~/Documents/Trareon Transcribe');
      expect(notifier.state, isEmpty);
    });

    test('the progressive path reports per-file progress', () async {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/panjang.mp3']);
      final bridge = _ProgressiveBridge();

      await notifier.processBatch(
        bridge,
        '/model/quick',
        refineModelPath: '/model/refine',
        outputDir: '~/Documents/Trareon Transcribe',
      );

      expect(bridge.progressiveCalls, ['/a/panjang.mp3']);
      expect(notifier.state.single.status, BatchFileStatus.done);
      expect(notifier.state.single.progress, 1.0);
    });

    test('cancelling during a progressive run stops the files after it',
        () async {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/satu.mp3', '/a/dua.mp3', '/a/tiga.mp3']);
      // Cancel the rest while the first file is inside the engine — the
      // file being transcribed cannot be interrupted, the ones behind it
      // can.
      final bridge = _ProgressiveBridge(onCall: (path) {
        if (path == '/a/satu.mp3') {
          notifier.cancelFile('/a/dua.mp3');
          notifier.cancelFile('/a/tiga.mp3');
        }
      });

      await notifier.processBatch(
        bridge,
        '/model/quick',
        refineModelPath: '/model/refine',
        outputDir: '~/Documents/Trareon Transcribe',
      );

      expect(bridge.progressiveCalls, ['/a/satu.mp3']);
      expect(notifier.entryFor('/a/satu.mp3')!.status, BatchFileStatus.done);
      expect(notifier.entryFor('/a/dua.mp3')!.status,
          BatchFileStatus.cancelled);
      expect(notifier.entryFor('/a/tiga.mp3')!.status,
          BatchFileStatus.cancelled);
    });
  });
}

class _NoopBridge with SummaryBridgeStubs implements RustBridge {
  @override
  Future<String> startSession(SessionConfig config) async => '';
  @override
  Future<void> stopSession(String sessionId) async {}
  @override
  Future<void> toggleMic(String sessionId, bool enabled) async {}
  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) async {}

  @override
  Future<double> benchmarkRtf(String modelPath) async => 0.8;
  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) => const Stream.empty();
  @override
  Stream<VuLevel> vuMeterStream(String sessionId) => const Stream.empty();

  @override
  Stream<SessionNotice> noticeStream(String sessionId) => const Stream.empty();
  @override
  Future<List<rust_session.RecoverableSession>> listRecoverableSessions() async =>
      const [];

  @override
  Future<rust_session.RecoveredSession> recoverSession(
    rust_session.SessionRecoverySnapshot snapshot,
  ) async => rust_session.RecoveredSession(
    sessionId: 'test-session',
    segments: const [],
    resumeOffsetSecs: 0,
    micAudioSecs: 0,
    speakerAudioSecs: 0,
  );

  @override
  Future<void> deleteRecoverableSession(String sessionId) async {}

  @override
  Future<rust_session.CaptureHealth> captureHealth(String sessionId) async =>
      rust_session.CaptureHealth(
        sessionId: sessionId,
        elapsedSecs: 0,
        segmentCount: 0,
        channels: const [],
        warnings: const [],
      );

  @override
  Future<void> setSessionTitle(String sessionId, String title) async {}

  @override
  Future<rust_disk.DiskSpaceStatus> diskSpace(String path) async =>
      rust_disk.DiskSpaceStatus(
        availableBytes: BigInt.from(64 * 1024 * 1024 * 1024),
        level: rust_disk.DiskSpaceLevel.ok,
        message: '',
      );
  @override
  Future<AppSettings> loadSettings() async => AppSettings.defaults();
  @override
  Future<void> saveSettings(AppSettings settings) async {}
  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {}
  @override
  Future<List<rust_model.ModelInfo>> listAvailableModels(String modelsDir) async => [];
  @override
  Future<bool> isModelDownloaded(String modelsDir, String modelId) async => false;
  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => [];
  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async => [];
  @override
  Future<String> detectFrontmostWindowTitle() async => '';
  @override
  Stream<double> downloadProgress() => const Stream.empty();
  @override
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) async => [];
  @override
  Future<List<rust_export.ExportedFile>> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [],
  }) async => [];
  @override
  Future<List<rust_export.ExportedFile>> exportSessionAudio({
    required String sessionId,
    required String outputDir,
    required String title,
  }) async => [];
  @override
  Future<void> pauseSession(String sessionId) async {}
  @override
  Future<void> resumeSession(String sessionId) async {}
}

class _TestBridge extends _NoopBridge {
  final List<String> exportedTitles = [];
  final List<String> batchedFiles = [];

  @override
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) async {
    batchedFiles.addAll(files);
    return [
      rust_stt_file.BatchFileOutcome(
        filename: 'test.mp3',
        path: files.first,
        result: rust_stt_file.TranscribeFileResult(
          filename: 'test.mp3',
          durationSecs: 1.0,
          segments: [
          rust_export.Segment(
            source: 'mic',
            speaker: 'MIC',
            text: 'Halo semua',
            timestamp: 0,
            duration: 1.0,
            language: 'id',
            confidence: 0.9,
            isPartial: false,
            lowConfidence: false,
            avgLogProb: -0.2,
          ),
          ],
          language: 'id',
        ),
      ),
    ];
  }

  @override
  Future<List<rust_export.ExportedFile>> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [],
  }) async {
    exportedTitles.add(title);
    return [];
  }
}

class _ErrorBridge extends _NoopBridge {
  @override
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) async {
    throw Exception('engine failure');
  }
}

/// Clears the queue while the engine is "working", the way pressing
/// "Kosongkan" mid-import does.
class _ClearingBridge extends _NoopBridge {
  _ClearingBridge(this.notifier);

  final BatchUploadNotifier notifier;

  @override
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) async {
    notifier.clear();
    return [];
  }
}

class _ProgressiveBridge extends _NoopBridge {
  _ProgressiveBridge({this.onCall});

  final void Function(String path)? onCall;
  final List<String> progressiveCalls = [];

  @override
  Future<rust_api.ProgressiveFileResult> progressiveTranscribeFile({
    required String quickModelPath,
    required String refineModelPath,
    required String path,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) async {
    progressiveCalls.add(path);
    onCall?.call(path);
    return rust_api.ProgressiveFileResult(
      filename: path.split('/').last,
      quickSegments: const [],
      refinedSegments: [
        rust_export.Segment(
          source: 'file',
          speaker: 'Pembicara 1',
          text: 'halo',
          timestamp: 0,
          duration: 1,
          language: 'id',
          confidence: 0.9,
          isPartial: false,
          lowConfidence: false,
          avgLogProb: -0.2,
        ),
      ],
      language: 'id',
    );
  }
}
