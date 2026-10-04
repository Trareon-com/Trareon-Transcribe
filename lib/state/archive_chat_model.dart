/// "Tanya arsip rapat" (F12) — state for the archive chat.
///
/// Two halves with very different privacy properties, and the model
/// keeps them visibly apart:
///
/// * **Retrieval** runs against a local SQLite FTS5 index and never
///   leaves the machine. It is useful on its own — the hit list is a
///   ranked, cited answer to "where did we discuss this".
/// * **The composed answer** goes to the configured summary endpoint,
///   carrying only the retrieved passages. It is recorded in the Privacy
///   Report and refused outright when the summary feature is off.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../services/library_index.dart';
import '../services/session_store.dart';
import '../src/rust/archive.dart' as rust_archive;
import 'models.dart';
import 'privacy_report_model.dart';
import 'settings_model.dart';

enum ArchiveChatStatus { idle, searching, asking, done, failed }

/// One exchange, kept so the pane reads as a conversation rather than a
/// search box that forgets.
@immutable
class ArchiveTurn {
  const ArchiveTurn({
    required this.question,
    this.answer = '',
    this.sources = const [],
    this.error,
  });

  final String question;
  final String answer;
  final List<rust_archive.ArchiveHit> sources;
  final String? error;

  ArchiveTurn copyWith({
    String? answer,
    List<rust_archive.ArchiveHit>? sources,
    String? error,
  }) => ArchiveTurn(
    question: question,
    answer: answer ?? this.answer,
    sources: sources ?? this.sources,
    error: error ?? this.error,
  );
}

@immutable
class ArchiveChatState {
  const ArchiveChatState({
    this.status = ArchiveChatStatus.idle,
    this.turns = const [],
    this.indexing = false,
    this.indexedSessions = 0,
  });

  final ArchiveChatStatus status;
  final List<ArchiveTurn> turns;

  /// True while the index is catching up with the library.
  final bool indexing;
  final int indexedSessions;

  bool get busy =>
      status == ArchiveChatStatus.searching || status == ArchiveChatStatus.asking;

  ArchiveChatState copyWith({
    ArchiveChatStatus? status,
    List<ArchiveTurn>? turns,
    bool? indexing,
    int? indexedSessions,
  }) => ArchiveChatState(
    status: status ?? this.status,
    turns: turns ?? this.turns,
    indexing: indexing ?? this.indexing,
    indexedSessions: indexedSessions ?? this.indexedSessions,
  );
}

class ArchiveChatNotifier extends StateNotifier<ArchiveChatState> {
  ArchiveChatNotifier(this._bridge, this._settings, this._onNetworkRequest)
      : super(const ArchiveChatState());

  final RustBridge _bridge;
  final AppSettings Function() _settings;

  /// Records the outbound request in the Privacy Report *before* it is
  /// made. `privacy_proof_test.dart` checks that this runs first.
  final void Function(String endpoint, int passageCount) _onNetworkRequest;

  String get _libraryPath => resolveTilde(_settings().libraryPath);

  /// Brings the index up to date with the library.
  ///
  /// Only sessions whose transcript changed are re-read, so a warm
  /// library costs one `SELECT` per session and no parsing at all.
  Future<int> reindex(List<LibraryEntry> entries) async {
    if (state.indexing) return 0;
    state = state.copyWith(indexing: true);
    var indexed = 0;
    try {
      for (final entry in entries) {
        final file = transcriptFileIn(directoryFor(entry.dirPath));
        if (file == null) continue;
        final stat = file.statSync();
        final size = stat.size;
        final mtime = stat.modified.millisecondsSinceEpoch;
        final stale = await _bridge.archiveIsStale(
          libraryPath: _libraryPath,
          dirPath: entry.dirPath,
          transcriptSize: size,
          transcriptModifiedMs: mtime,
        );
        if (!stale) continue;
        final segments = parseTranscriptJson(await file.readAsString());
        final meta = await readSessionMeta(entry.dirPath);
        await _bridge.archiveIndexSession(
          libraryPath: _libraryPath,
          dirPath: entry.dirPath,
          title: entry.title,
          date: entry.date,
          segments: segments,
          summary: meta.summary,
          transcriptSize: size,
          transcriptModifiedMs: mtime,
        );
        indexed++;
      }
    } catch (e) {
      debugPrint('archive reindex failed: $e');
    } finally {
      if (mounted) {
        state = state.copyWith(
          indexing: false,
          indexedSessions: state.indexedSessions + indexed,
        );
      }
    }
    return indexed;
  }

  Future<void> forget(String dirPath) async {
    try {
      await _bridge.archiveForgetSession(
        libraryPath: _libraryPath,
        dirPath: dirPath,
      );
    } catch (e) {
      debugPrint('archive forget failed: $e');
    }
  }

  /// Retrieval only — no network, no model, no endpoint required.
  Future<void> search(String question) async {
    if (question.trim().isEmpty || state.busy) return;
    final turn = ArchiveTurn(question: question.trim());
    state = state.copyWith(
      status: ArchiveChatStatus.searching,
      turns: [...state.turns, turn],
    );
    try {
      final hits = await _bridge.archiveSearch(
        libraryPath: _libraryPath,
        question: question.trim(),
        limit: 12,
      );
      _finishTurn(
        turn.copyWith(
          sources: hits,
          answer: hits.isEmpty ? 'Tidak ditemukan di arsip rapat.' : '',
        ),
        ArchiveChatStatus.done,
      );
    } catch (e) {
      _finishTurn(turn.copyWith(error: '$e'), ArchiveChatStatus.failed);
    }
  }

  /// Retrieval, then a composed answer from the configured endpoint.
  ///
  /// Refuses rather than silently falling back to retrieval-only when
  /// the summary feature is off: the user pressed the button that sends
  /// data somewhere, and quietly not sending it is as confusing as
  /// quietly sending it.
  Future<void> ask(String question) async {
    if (question.trim().isEmpty || state.busy) return;
    final settings = _settings();
    final turn = ArchiveTurn(question: question.trim());
    if (!settings.summary.isUsable) {
      state = state.copyWith(
        status: ArchiveChatStatus.failed,
        turns: [
          ...state.turns,
          turn.copyWith(
            error: 'Jawaban otomatis memerlukan endpoint ringkasan yang '
                'sudah diatur di Pengaturan → Ringkasan AI. Pencarian '
                'arsip tetap bisa dipakai tanpa itu.',
          ),
        ],
      );
      return;
    }
    state = state.copyWith(
      status: ArchiveChatStatus.searching,
      turns: [...state.turns, turn],
    );
    try {
      final hits = await _bridge.archiveSearch(
        libraryPath: _libraryPath,
        question: question.trim(),
        limit: 12,
      );
      if (hits.isEmpty) {
        _finishTurn(
          turn.copyWith(answer: 'Tidak ditemukan di arsip rapat.'),
          ArchiveChatStatus.done,
        );
        return;
      }
      if (!mounted) return;
      state = state.copyWith(status: ArchiveChatStatus.asking);
      // Recorded before the request, not after: a report written only on
      // success understates what left the machine.
      _onNetworkRequest(settings.summary.baseUrl, hits.length);
      final answer = await _bridge.archiveAsk(
        libraryPath: _libraryPath,
        question: question.trim(),
        config: settings.summary.toConfig(language: settings.language),
      );
      _finishTurn(
        turn.copyWith(answer: answer.answer, sources: answer.sources),
        ArchiveChatStatus.done,
      );
    } catch (e) {
      _finishTurn(turn.copyWith(error: '$e'), ArchiveChatStatus.failed);
    }
  }

  void _finishTurn(ArchiveTurn turn, ArchiveChatStatus status) {
    if (!mounted) return;
    final turns = [...state.turns];
    if (turns.isNotEmpty) turns[turns.length - 1] = turn;
    state = state.copyWith(status: status, turns: turns);
  }

  void clear() {
    state = ArchiveChatState(indexedSessions: state.indexedSessions);
  }
}

final archiveChatProvider =
    StateNotifierProvider<ArchiveChatNotifier, ArchiveChatState>((ref) {
  return ArchiveChatNotifier(
    ref.read(rustBridgeProvider),
    () => ref.read(settingsProvider),
    (endpoint, passages) => ref
        .read(privacyReportProvider.notifier)
        .recordArchiveQuestion(endpoint, passages),
  );
});
