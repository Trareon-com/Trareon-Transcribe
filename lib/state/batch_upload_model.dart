import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../services/bridge_service.dart';
import '../services/session_store.dart';
import 'models.dart';

enum BatchFileStatus { queued, decoding, transcribing, done, error }

class BatchFileEntry {
  final String path;
  final String filename;
  final BatchFileStatus status;
  final String? error;

  const BatchFileEntry({
    required this.path,
    required this.filename,
    this.status = BatchFileStatus.queued,
    this.error,
  });

  BatchFileEntry copyWith({BatchFileStatus? status, String? error}) {
    return BatchFileEntry(
      path: path,
      filename: filename,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

class BatchUploadNotifier extends StateNotifier<List<BatchFileEntry>> {
  BatchUploadNotifier() : super(const []);

  static const _supportedExtensions = kAudioExtensions;

  /// Returns the paths that were rejected as unsupported formats.
  List<String> addFiles(List<String> paths) {
    final rejected = <String>[];
    final accepted = <BatchFileEntry>[];
    final existingPaths = state.map((entry) => entry.path).toSet();

    for (final path in paths) {
      final ext = path.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) {
        rejected.add(path);
        continue;
      }
      if (existingPaths.contains(path) || accepted.any((entry) => entry.path == path)) {
        continue;
      }
      accepted.add(BatchFileEntry(path: path, filename: path.split('/').last));
    }

    if (accepted.isNotEmpty) {
      state = [...state, ...accepted];
    }
    return rejected;
  }

  void updateStatus(String path, BatchFileStatus status, {String? error}) {
    state = [
      for (final entry in state)
        if (entry.path == path) entry.copyWith(status: status, error: error) else entry,
    ];
  }

  void clear() {
    state = const [];
  }

  void removeDone() {
    state = state.where((e) => e.status != BatchFileStatus.done).toList();
  }

  /// Transcribes every queued file and exports each result into the library
  /// so it appears in the Sesi tab.
  ///
  /// The whole queue goes to the engine in a single call: loading the model is
  /// the expensive step (~550 MB for the accurate model), and the previous
  /// one-call-per-file loop paid it once per file. Per-file status comes from
  /// polling the engine's progress snapshot instead.
  ///
  /// When [refineModelPath] is set, each file is run through the two-pass
  /// (HPT) path and the refined segments are kept — this is what the
  /// "Progressive Mode" setting means for imports, which previously ignored it.
  Future<void> processBatch(
    RustBridge bridge,
    String modelPath, {
    required String outputDir,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    String? refineModelPath,
    String? modelId,
  }) async {
    final paths = state
        .where((e) => e.status == BatchFileStatus.queued)
        .map((e) => e.path)
        .toList();
    if (paths.isEmpty) return;

    if (refineModelPath != null) {
      await _processProgressive(
        bridge,
        paths,
        quickModelPath: modelPath,
        refineModelPath: refineModelPath,
        outputDir: outputDir,
        language: language,
        gpuEnabled: gpuEnabled,
        gpuDevice: gpuDevice,
        modelId: modelId,
      );
      return;
    }

    for (final path in paths) {
      updateStatus(path, BatchFileStatus.transcribing);
    }

    // Poll engine-side progress so long files show real movement instead of
    // a spinner that sits still until the entire batch returns.
    final poller = Stream.periodic(const Duration(milliseconds: 400)).listen((
      _,
    ) async {
      final progress = await bridge.batchProgress();
      if (progress == null) return;
      final index = progress.fileIndex;
      if (index < paths.length) {
        updateStatus(paths[index], BatchFileStatus.transcribing);
      }
    });

    try {
      final outcomes = await bridge.batchTranscribeFiles(
        modelPath: modelPath,
        files: paths,
        language: language,
        gpuEnabled: gpuEnabled,
        gpuDevice: gpuDevice,
      );

      for (final outcome in outcomes) {
        final path = outcome.path.isNotEmpty ? outcome.path : outcome.filename;
        final result = outcome.result;
        if (result == null || result.segments.isEmpty) {
          updateStatus(
            path,
            BatchFileStatus.error,
            error: outcome.error ?? 'Tidak ada ucapan terdeteksi',
          );
          continue;
        }
        await _saveResult(
          bridge: bridge,
          sourcePath: path,
          filename: result.filename,
          segments: result.segments.map(fromRustSegment).toList(),
          outputDir: outputDir,
          language: language ?? result.language,
          modelId: modelId,
        );
      }

      // Anything the engine never reported on (it stopped early) must not be
      // left showing "Transkripsi" forever.
      for (final path in paths) {
        final entry = state.firstWhere((e) => e.path == path);
        if (entry.status == BatchFileStatus.transcribing) {
          updateStatus(
            path,
            BatchFileStatus.error,
            error: 'Proses berhenti sebelum file ini selesai',
          );
        }
      }
    } catch (e) {
      for (final path in paths) {
        final entry = state.firstWhere((e) => e.path == path);
        if (entry.status == BatchFileStatus.transcribing) {
          updateStatus(path, BatchFileStatus.error, error: e.toString());
        }
      }
    } finally {
      await poller.cancel();
    }
  }

  /// Two-pass import. `progressive_transcribe_file` handles one file at a
  /// time, so this loops — but the refined pass is what gets saved, matching
  /// what live recording does with Progressive Mode on.
  Future<void> _processProgressive(
    RustBridge bridge,
    List<String> paths, {
    required String quickModelPath,
    required String refineModelPath,
    required String outputDir,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    String? modelId,
  }) async {
    for (final path in paths) {
      updateStatus(path, BatchFileStatus.transcribing);
      try {
        final result = await bridge.progressiveTranscribeFile(
          quickModelPath: quickModelPath,
          refineModelPath: refineModelPath,
          path: path,
          language: language,
          gpuEnabled: gpuEnabled,
          gpuDevice: gpuDevice,
        );
        if (result.refinedSegments.isEmpty) {
          updateStatus(
            path,
            BatchFileStatus.error,
            error: 'Tidak ada ucapan terdeteksi',
          );
          continue;
        }
        await _saveResult(
          bridge: bridge,
          sourcePath: path,
          filename: result.filename,
          segments: result.refinedSegments.map(fromRustSegment).toList(),
          outputDir: outputDir,
          language: language ?? result.language,
          modelId: modelId,
        );
      } catch (e) {
        updateStatus(path, BatchFileStatus.error, error: e.toString());
      }
    }
  }

  /// Exports one transcribed file into the library and copies the source
  /// audio next to it, so the session is immediately playable and
  /// re-transcribable.
  Future<void> _saveResult({
    required RustBridge bridge,
    required String sourcePath,
    required String filename,
    required List<TranscriptSegment> segments,
    required String outputDir,
    String? language,
    String? modelId,
  }) async {
    final title = filename.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final safeTitle = title.isEmpty ? filename : title;
    final exportedFiles = await bridge.exportSession(
      segments: segments,
      outputDir: resolveTilde(outputDir),
      title: safeTitle,
    );
    updateStatus(sourcePath, BatchFileStatus.done);
    if (exportedFiles.isEmpty) return;

    try {
      // The Rust export writes into a date-prefixed, sanitized subfolder that
      // doesn't match a naively-computed path, so the audio copy and the
      // sidecar must land next to the files the export actually wrote.
      final sessionDir = File(exportedFiles.first.path).parent;
      await sessionDir.create(recursive: true);
      final sourceAudio = File(sourcePath);
      if (await sourceAudio.exists()) {
        final ext = sourcePath.contains('.')
            ? '.${sourcePath.split('.').last}'
            : '.wav';
        await sourceAudio.copy(
          '${sessionDir.path}${Platform.pathSeparator}$safeTitle$ext',
        );
      }
      await writeSessionMeta(
        sessionDir.path,
        SessionMeta(title: safeTitle, language: language, model: modelId),
      );
    } catch (_) {
      // Bookkeeping only — the transcript itself is already on disk.
    }
  }
}

final batchUploadProvider = StateNotifierProvider<BatchUploadNotifier, List<BatchFileEntry>>((ref) {
  return BatchUploadNotifier();
});
