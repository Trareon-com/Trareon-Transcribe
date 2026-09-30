import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks network activity since app launch for the Privacy Report screen.
///
/// The app makes zero network calls during transcription by design (see
/// SECURITY.md). There are exactly four things that can talk to the network,
/// every one of them started by an explicit user action:
///
/// 1. downloading a Whisper model ([PrivacyReportNotifier.recordModelDownload])
/// 2. requesting an AI summary ([PrivacyReportNotifier.recordSummaryRequest]),
///    which is off by default and defaults to a loopback endpoint
/// 3. checking for updates ([PrivacyReportNotifier.recordUpdateCheck])
/// 4. opening the releases page in the user's browser
///    ([PrivacyReportNotifier.recordExternalLink])
///
/// The report is only worth anything if that list and the code agree, so
/// `test/privacy_proof_test.dart` asserts that every call site which can
/// initiate one of these records it *first* — the counter was previously
/// pinned at zero by a test asserting `recordModelDownload` had no callers,
/// while the updater quietly contacted raw.githubusercontent.com on every
/// "Cek Pembaruan".
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
  PrivacyReportNotifier()
    : super(PrivacyReportState(networkCallCount: 0, launchedAt: DateTime.now()));

  void _record(String description) {
    state = state.copyWith(
      networkCallCount: state.networkCallCount + 1,
      events: [...state.events, '$description — ${DateTime.now()}'],
    );
  }

  /// Called only from the explicit, user-initiated model download flows
  /// (first-run onboarding and the "Model Akurat/Cepat" dialog) — never
  /// from the transcription pipeline.
  void recordModelDownload(String modelId) {
    _record('Mengunduh model "$modelId" dari huggingface.co');
  }

  /// Called when the user presses "Buat Ringkasan". Records the endpoint so
  /// the report shows *where* the transcript went, not just that something
  /// happened — with a user-configurable endpoint, that is the fact worth
  /// auditing.
  void recordSummaryRequest(String endpoint) {
    _record('Ringkasan AI dikirim ke $endpoint');
  }

  /// Called when the user presses "Cek Pembaruan". Only the version manifest
  /// is fetched; nothing is downloaded or executed.
  void recordUpdateCheck(String endpoint) {
    _record('Memeriksa pembaruan ke $endpoint');
  }

  /// Called when the app hands a URL to the system browser ("Lihat Rilis").
  /// Trareon itself opens no socket here, but the user's machine does, and a
  /// privacy report that omits it would be misleading.
  void recordExternalLink(String url) {
    _record('Membuka $url di peramban');
  }
}

final privacyReportProvider =
    StateNotifierProvider<PrivacyReportNotifier, PrivacyReportState>((ref) {
      return PrivacyReportNotifier();
    });
