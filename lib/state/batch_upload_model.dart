import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../services/bridge_service.dart';
import '../services/session_store.dart';
import 'models.dart';

enum BatchFileStatus { queued, decoding, transcribing, done, error, cancelled }

/// Largest file the import will accept.
///
/// Enforced, not decorative: the drop zone advertises this number, and a
/// limit shown to the user that is never checked is just another untrue
/// statement on screen. Two gigabytes is a three-hour stereo WAV, which is
/// the longest recording this product is designed around.
const int kMaxImportBytes = 2 * 1024 * 1024 * 1024;

/// Why a dropped file was not accepted.
enum RejectionReason { unsupportedFormat, tooLarge }

class RejectedFile {
  final String path;
  final RejectionReason reason;

  const RejectedFile(this.path, this.reason);

  String get filename => p.basename(path);

  String get message => switch (reason) {
    RejectionReason.unsupportedFormat => 'format tidak didukung',
    RejectionReason.tooLarge => 'lebih besar dari batas 2 GB',
  };
}

class BatchFileEntry {
  final String path;
  final String filename;
  final BatchFileStatus status;
  final String? error;

  /// How far the engine is through this file, 0..1. The progressive (HPT)
  /// import used to report nothing at all, so turning Progressive Mode on
  /// froze the progress indicator until the whole file was done.
  final double progress;

  /// Size on disk, shown in the queue so a user who dropped a 1.8 GB file
  /// understands why it is taking a while.
  final int sizeBytes;

  const BatchFileEntry({
    required this.path,
    required this.filename,
    this.status = BatchFileStatus.queued,
    this.error,
    this.progress = 0,
    this.sizeBytes = 0,
  });

  BatchFileEntry copyWith({
    BatchFileStatus? status,
    String? error,
    bool clearError = false,
    double? progress,
  }) {
    return BatchFileEntry(
      path: path,
      filename: filename,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      progress: progress ?? this.progress,
      sizeBytes: sizeBytes,
    );
  }

  bool get isFinished =>
      status == BatchFileStatus.done ||
      status == BatchFileStatus.error ||
      status == BatchFileStatus.cancelled;
}

class BatchUploadNotifier extends StateNotifier<List<BatchFileEntry>> {
  BatchUploadNotifier() : super(const []);

  static const _supportedExtensions = kAudioExtensions;

  /// Paths the user asked to stop. Checked before each file starts; a file
  /// already inside whisper.cpp cannot be interrupted, and pretending
  /// otherwise would be worse than saying so.
  final Set<String> _cancelRequested = <String>{};

  bool _running = false;
  bool get isRunning => _running;

  /// Adds files to the queue. Returns the ones that were not accepted,
  /// each with the reason — the old version returned bare paths and the UI
  /// could only say "N file dilewati".
  List<RejectedFile> addFiles(List<String> paths) {
    final rejected = <RejectedFile>[];
    final accepted = <BatchFileEntry>[];
    final existingPaths = state.map((entry) => entry.path).toSet();

    for (final path in paths) {
      // p.extension/p.basename rather than split('/'), which produced a
      // whole Windows path as the "filename" and mis-read extensions on
      // any path containing a dot in a directory name.
      final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
      if (!_supportedExtensions.contains(ext)) {
        rejected.add(RejectedFile(path, RejectionReason.unsupportedFormat));
        continue;
      }
      if (existingPaths.contains(path) ||
          accepted.any((entry) => entry.path == path)) {
        continue;
      }
      // A file we cannot stat is still queued: the size is only used for
      // the limit and the label, and the real failure (missing, locked,
      // unreadable) belongs to the decoder, which reports it per file.
      var size = 0;
      try {
        size = File(path).statSync().size;
      } catch (_) {
        size = 0;
      }
      if (size > kMaxImportBytes) {
        rejected.add(RejectedFile(path, RejectionReason.tooLarge));
        continue;
      }
      accepted.add(
        BatchFileEntry(path: path, filename: p.basename(path), sizeBytes: size),
      );
    }

    if (accepted.isNotEmpty) {
      state = [...state, ...accepted];
    }
    return rejected;
  }

  /// The entry for [path], or null when the queue was cleared underneath a
  /// running import. This used to be `state.firstWhere(...)`, which throws
  /// a `StateError` and killed the whole batch if the user pressed
  /// "Kosongkan" while it ran (audit B.1-2).
  BatchFileEntry? entryFor(String path) =>
      state.where((e) => e.path == path).firstOrNull;

  void updateStatus(
    String path,
    BatchFileStatus status, {
    String? error,
    double? progress,
  }) {
    state = [
      for (final entry in state)
        if (entry.path == path)
          entry.copyWith(
            status: status,
            error: error,
            clearError: error == null && status != BatchFileStatus.error,
            progress:
                progress ??
                (status == BatchFileStatus.done ? 1.0 : entry.progress),
          )
        else
          entry,
    ];
  }

  void updateProgress(String path, double progress) {
    final entry = entryFor(path);
    if (entry == null || entry.isFinished) return;
    if ((entry.progress - progress).abs() < 0.005) return;
    state = [
      for (final e in state)
        if (e.path == path)
          e.copyWith(progress: progress.clamp(0.0, 1.0))
        else
          e,
    ];
  }

  /// Stops one file. A queued file leaves the queue immediately; a file
  /// already being transcribed is marked so the run stops before the next
  /// one rather than pretending whisper.cpp can be interrupted.
  void cancelFile(String path) {
    final entry = entryFor(path);
    if (entry == null || entry.isFinished) return;
    _cancelRequested.add(path);
    updateStatus(path, BatchFileStatus.cancelled);
  }

  /// Puts a failed or cancelled file back in the queue.
  void retryFile(String path) {
    _cancelRequested.remove(path);
    state = [
      for (final entry in state)
        if (entry.path == path)
          entry.copyWith(
            status: BatchFileStatus.queued,
            clearError: true,
            progress: 0,
          )
        else
          entry,
    ];
  }

  void clear() {
    _cancelRequested.clear();
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
  /// "Progressive Mode" setting means for imports.
  Future<void> processBatch(
    RustBridge bridge,
    String modelPath, {
    required String outputDir,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    String? refineModelPath,
    String? modelId,
    int speakerHint = 0,
  }) async {
    final paths = state
        .where((e) => e.status == BatchFileStatus.queued)
        .map((e) => e.path)
        .toList();
    if (paths.isEmpty) return;
    _running = true;
    try {
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
          speakerHint: speakerHint,
        );
        return;
      }
      await _processSinglePass(
        bridge,
        paths,
        modelPath: modelPath,
        outputDir: outputDir,
        language: language,
        gpuEnabled: gpuEnabled,
        gpuDevice: gpuDevice,
        modelId: modelId,
        speakerHint: speakerHint,
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _processSinglePass(
    RustBridge bridge,
    List<String> paths, {
    required String modelPath,
    required String outputDir,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    String? modelId,
    int speakerHint = 0,
  }) async {
    for (final path in paths) {
      updateStatus(path, BatchFileStatus.transcribing, progress: 0);
    }

    // Poll engine-side progress so long files show real movement instead of
    // a spinner that sits still until the entire batch returns.
    final poller = _startProgressPoller(bridge, () => paths);

    try {
      final outcomes = await bridge.batchTranscribeFiles(
        modelPath: modelPath,
        files: paths,
        language: language,
        gpuEnabled: gpuEnabled,
        gpuDevice: gpuDevice,
        speakerHint: speakerHint,
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
      _failStragglers(paths, 'Proses berhenti sebelum file ini selesai');
    } catch (e) {
      _failStragglers(paths, e.toString());
    } finally {
      await poller.cancel();
    }
  }

  /// Marks every still-running file in [paths] as failed. Tolerant of the
  /// queue having been cleared while the engine worked.
  void _failStragglers(List<String> paths, String message) {
    for (final path in paths) {
      final entry = entryFor(path);
      if (entry == null) continue;
      if (entry.status == BatchFileStatus.transcribing ||
          entry.status == BatchFileStatus.decoding) {
        updateStatus(path, BatchFileStatus.error, error: message);
      }
    }
  }

  StreamSubscription<void> _startProgressPoller(
    RustBridge bridge,
    List<String> Function() paths,
  ) {
    return Stream<void>.periodic(const Duration(milliseconds: 400)).listen((
      _,
    ) async {
      final snapshot = await bridge.batchProgress();
      if (snapshot == null) return;
      final current = paths();
      final index = snapshot.fileIndex;
      if (index >= current.length) return;
      final path = current[index];
      final entry = entryFor(path);
      if (entry == null || entry.isFinished) return;
      if (entry.status != BatchFileStatus.transcribing) {
        updateStatus(
          path,
          BatchFileStatus.transcribing,
          progress: snapshot.progress,
        );
      } else {
        updateProgress(path, snapshot.progress);
      }
    });
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
    int speakerHint = 0,
  }) async {
    for (final path in paths) {
      if (_cancelRequested.remove(path)) {
        updateStatus(path, BatchFileStatus.cancelled);
        continue;
      }
      updateStatus(path, BatchFileStatus.transcribing, progress: 0);
      // The engine publishes the same snapshot the single-model path
      // does, for the one file it is on.
      final poller = _startProgressPoller(bridge, () => [path]);
      try {
        final result = await bridge.progressiveTranscribeFile(
          quickModelPath: quickModelPath,
          refineModelPath: refineModelPath,
          path: path,
          language: language,
          gpuEnabled: gpuEnabled,
          gpuDevice: gpuDevice,
          speakerHint: speakerHint,
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
      } finally {
        await poller.cancel();
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
    final title = p.basenameWithoutExtension(filename);
    final safeTitle = title.isEmpty ? filename : title;
    final exportedFiles = await bridge.exportSession(
      segments: segments,
      outputDir: resolveTilde(outputDir),
      title: safeTitle,
    );
    updateStatus(sourcePath, BatchFileStatus.done, progress: 1);
    if (exportedFiles.isEmpty) return;

    try {
      // The Rust export writes into a date-prefixed, sanitized subfolder that
      // doesn't match a naively-computed path, so the audio copy and the
      // sidecar must land next to the files the export actually wrote.
      final sessionDir = File(exportedFiles.first.path).parent;
      await sessionDir.create(recursive: true);
      final sourceAudio = File(sourcePath);
      if (await sourceAudio.exists()) {
        final ext = p.extension(sourcePath).isEmpty
            ? '.wav'
            : p.extension(sourcePath);
        await sourceAudio.copy(p.join(sessionDir.path, '$safeTitle$ext'));
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

final batchUploadProvider =
    StateNotifierProvider<BatchUploadNotifier, List<BatchFileEntry>>((ref) {
      return BatchUploadNotifier();
    });
