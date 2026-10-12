/// "Tanya Langsung" (Sprint 21) — state for questions asked while a
/// meeting is still recording.
///
/// Deliberately separate from [archive_chat_model.dart]'s state even
/// though both end up at the same summary endpoint: the archive answers
/// from an indexed library of past meetings, this answers from whatever
/// the live pipeline already holds for the session in progress. There is
/// no retrieval step here — the whole point is that the corpus is one
/// small, ungrowing-at-query-time snapshot, not something to search.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../src/rust/live_qa.dart' as rust_live_qa;
import 'models.dart';
import 'privacy_report_model.dart';
import 'settings_model.dart';

enum LiveQaStatus { idle, asking, done, failed }

/// One exchange, kept so the panel reads as a short conversation.
@immutable
class LiveQaTurn {
  const LiveQaTurn({
    required this.question,
    this.answer = '',
    this.sources = const [],
    this.error,
  });

  final String question;
  final String answer;
  final List<rust_live_qa.LiveQaHit> sources;
  final String? error;

  LiveQaTurn copyWith({
    String? answer,
    List<rust_live_qa.LiveQaHit>? sources,
    String? error,
  }) => LiveQaTurn(
    question: question,
    answer: answer ?? this.answer,
    sources: sources ?? this.sources,
    error: error ?? this.error,
  );
}

@immutable
class LiveQaState {
  const LiveQaState({this.status = LiveQaStatus.idle, this.turns = const []});

  final LiveQaStatus status;
  final List<LiveQaTurn> turns;

  bool get busy => status == LiveQaStatus.asking;

  LiveQaState copyWith({LiveQaStatus? status, List<LiveQaTurn>? turns}) =>
      LiveQaState(status: status ?? this.status, turns: turns ?? this.turns);
}

class LiveQaNotifier extends StateNotifier<LiveQaState> {
  LiveQaNotifier(this._bridge, this._settings, this._onNetworkRequest)
    : super(const LiveQaState());

  final RustBridge _bridge;
  final AppSettings Function() _settings;

  /// Records the outbound request in the Privacy Report *before* it is
  /// made. `privacy_proof_test.dart` checks that this runs first.
  final void Function(String endpoint, int passageCount) _onNetworkRequest;

  /// Asks `question` against a snapshot of `segments` taken right now.
  ///
  /// Refuses rather than silently answering nothing when the summary
  /// feature is off — the user pressed the button that sends data
  /// somewhere, and quietly not sending it is as confusing as quietly
  /// sending it. (See the equivalent refusal in `ArchiveChatNotifier.ask`.)
  Future<void> ask(String question, List<TranscriptSegment> segments) async {
    if (question.trim().isEmpty || state.busy) return;
    final settings = _settings();
    final turn = LiveQaTurn(question: question.trim());
    if (!settings.summary.isUsable) {
      state = state.copyWith(
        status: LiveQaStatus.failed,
        turns: [
          ...state.turns,
          turn.copyWith(
            error:
                'Tanya Langsung memerlukan endpoint ringkasan yang sudah '
                'diatur di Pengaturan → Ringkasan AI.',
          ),
        ],
      );
      return;
    }
    state = state.copyWith(
      status: LiveQaStatus.asking,
      turns: [...state.turns, turn],
    );
    try {
      _onNetworkRequest(settings.summary.baseUrl, segments.length);
      final answer = await _bridge.liveQaAsk(
        question: question.trim(),
        segments: segments,
        config: settings.summary.toConfig(language: settings.language),
      );
      _finishTurn(
        turn.copyWith(answer: answer.answer, sources: answer.sources),
        LiveQaStatus.done,
      );
    } catch (e) {
      _finishTurn(turn.copyWith(error: '$e'), LiveQaStatus.failed);
    }
  }

  void _finishTurn(LiveQaTurn turn, LiveQaStatus status) {
    if (!mounted) return;
    final turns = [...state.turns];
    if (turns.isNotEmpty) turns[turns.length - 1] = turn;
    state = state.copyWith(status: status, turns: turns);
  }

  /// Called when a session stops, so a new session does not inherit
  /// questions asked about the previous one.
  void clear() {
    state = const LiveQaState();
  }
}

final liveQaProvider = StateNotifierProvider<LiveQaNotifier, LiveQaState>((
  ref,
) {
  return LiveQaNotifier(
    ref.read(rustBridgeProvider),
    () => ref.read(settingsProvider),
    (endpoint, passages) => ref
        .read(privacyReportProvider.notifier)
        .recordLiveQaQuestion(endpoint, passages),
  );
});
