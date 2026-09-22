import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../services/bridge_service.dart';
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

  static const _supportedExtensions = {
    'wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac', 'opus', 'mp4', 'mov', 'mkv',
  };

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

  /// Process all queued files through the Rust engine sequentially and,
  /// when transcription succeeds, export the segments into the library
  /// directory so the result becomes visible in the Sesi tab.
  Future<void> processBatch(
    RustBridge bridge,
    String modelPath, {
    required String outputDir,
    String? language,
  }) async {
    final paths = state
        .where((e) => e.status == BatchFileStatus.queued)
        .map((e) => e.path)
        .toList();
    if (paths.isEmpty) return;

    for (final path in paths) {
      updateStatus(path, BatchFileStatus.transcribing);
      // Small delay so the UI can update before blocking on transcription
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        final results = await bridge.batchTranscribeFiles(
          modelPath: modelPath,
          files: [path],
          language: language,
        );
        if (results.isNotEmpty && results.first.segments.isNotEmpty) {
          final result = results.first;
          final title = result.filename.replaceFirst(RegExp(r'\.[^.]+$'), '');
          final exportedFiles = await bridge.exportSession(
            segments: result.segments.map((segment) {
              return TranscriptSegment(
                source: segment.source,
                speaker: segment.speaker,
                text: segment.text,
                timestamp: segment.timestamp,
                duration: segment.duration,
                language: segment.language,
                confidence: segment.confidence,
                isPartial: segment.isPartial,
              );
            }).toList(),
            outputDir: resolveTilde(outputDir),
            title: title.isEmpty ? result.filename : title,
          );
          updateStatus(path, BatchFileStatus.done);
          if (exportedFiles.isNotEmpty) {
            try {
              // The Rust export writes into a date-prefixed, sanitized
              // subfolder that doesn't match a naively-computed path, so the
              // audio copy must land next to the files the export actually
              // wrote.
              final sessionDir = File(exportedFiles.first.path).parent;
              await sessionDir.create(recursive: true);
              final sourceAudio = File(path);
              if (await sourceAudio.exists()) {
                final ext = path.contains('.') ? '.${path.split('.').last}' : '.wav';
                await sourceAudio.copy('${sessionDir.path}/${title.isEmpty ? result.filename : title}$ext');
              }
            } catch (_) {}
          }
        } else {
          updateStatus(path, BatchFileStatus.error, error: 'No speech detected');
        }
      } catch (e) {
        updateStatus(path, BatchFileStatus.error, error: e.toString());
      }
    }
  }
}

final batchUploadProvider = StateNotifierProvider<BatchUploadNotifier, List<BatchFileEntry>>((ref) {
  return BatchUploadNotifier();
});
