import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;
import 'package:transcribe/src/rust/model.dart' as rust_model;
import 'package:transcribe/state/batch_upload_model.dart';
import 'package:transcribe/state/models.dart';

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

      expect(rejected, ['/a/document.pdf']);
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
  });
}

class _NoopBridge implements RustBridge {
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
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions() async => [];
  @override
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async => '';
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
  Future<List<rust_stt_file.TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
  }) async => [];
  @override
  Future<List<rust_export.ExportedFile>> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [],
  }) async => [];
  @override
  Future<void> exportSessionAudio({
    required String sessionId,
    required String outputDir,
    required String title,
  }) async {}
  @override
  Future<void> pauseSession(String sessionId) async {}
  @override
  Future<void> resumeSession(String sessionId) async {}
}

class _TestBridge extends _NoopBridge {
  final List<String> exportedTitles = [];

  @override
  Future<List<rust_stt_file.TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
  }) async {
    return [
      rust_stt_file.TranscribeFileResult(
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
  Future<List<rust_stt_file.TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
  }) async {
    throw Exception('engine failure');
  }
}
