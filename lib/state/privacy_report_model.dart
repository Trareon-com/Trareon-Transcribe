import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks network activity since app launch for the Privacy Report screen.
///
/// The app makes zero network calls during transcription by design (see
/// SECURITY.md). There are exactly two legitimate sources of increments,
/// both explicitly user-initiated:
///
/// 1. downloading a Whisper model ([PrivacyReportNotifier.recordModelDownload])
/// 2. requesting an AI summary ([PrivacyReportNotifier.recordSummaryRequest]),
///    which is off by default and defaults to a loopback endpoint
///
/// Anything else touching this counter would be a privacy regression worth
/// flagging loudly.
class PrivacyReportState {
  final int networkCallCount;
  final DateTime launchedAt;
  final List<String> events;

  const PrivacyReportState({
    required this.networkCallCount,
    required this.launchedAt,
    this.events = const [],
  });

  PrivacyReportState copyWith({int? networkCallCount, List<String>? events}) {
    return PrivacyReportState(
      networkCallCount: networkCallCount ?? this.networkCallCount,
      launchedAt: launchedAt,
      events: events ?? this.events,
    );
  }
}

class PrivacyReportNotifier extends StateNotifier<PrivacyReportState> {
  PrivacyReportNotifier() : super(PrivacyReportState(networkCallCount: 0, launchedAt: DateTime.now()));

  /// Called only from the explicit, user-initiated model download flow —
  /// never from the transcription pipeline.
  void recordModelDownload(String modelId) {
    state = state.copyWith(
      networkCallCount: state.networkCallCount + 1,
      events: [...state.events, 'Mengunduh model — ${DateTime.now()}'],
    );
  }

  /// Called when the user presses "Buat Ringkasan". Records the endpoint so
  /// the report shows *where* the transcript went, not just that something
  /// happened — with a user-configurable endpoint, that is the fact worth
  /// auditing.
  void recordSummaryRequest(String endpoint) {
    state = state.copyWith(
      networkCallCount: state.networkCallCount + 1,
      events: [
        ...state.events,
        'Ringkasan AI dikirim ke $endpoint — ${DateTime.now()}',
      ],
    );
  }
}

final privacyReportProvider = StateNotifierProvider<PrivacyReportNotifier, PrivacyReportState>((ref) {
  return PrivacyReportNotifier();
});
