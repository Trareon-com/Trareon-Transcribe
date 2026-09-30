import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../services/session_store.dart';
import 'models.dart';

/// Where a summary panel currently is.
enum SummaryStatus {
  /// No summary yet, or the user cleared it.
  empty,

  /// A request is in flight.
  generating,

  /// A summary exists (generated or hand-edited).
  ready,

  /// The last attempt failed; [SummaryUiState.error] says why.
  failed,
}

class SummaryUiState {
  final SummaryStatus status;
  final String text;
  final SummaryTemplate template;
  final String? error;

  /// True when [text] differs from what was last written to the session's
  /// sidecar — drives the "Simpan" affordance.
  final bool dirty;

  const SummaryUiState({
    this.status = SummaryStatus.empty,
    this.text = '',
    this.template = SummaryTemplate.notulenRapat,
    this.error,
    this.dirty = false,
  });

  SummaryUiState copyWith({
    SummaryStatus? status,
    String? text,
    SummaryTemplate? template,
    String? error,
    bool clearError = false,
    bool? dirty,
  }) {
    return SummaryUiState(
      status: status ?? this.status,
      text: text ?? this.text,
      template: template ?? this.template,
      error: clearError ? null : (error ?? this.error),
      dirty: dirty ?? this.dirty,
    );
  }
}

/// Drives one session's summary: generate, edit, save, regenerate.
///
/// Deliberately scoped to a single session (created per player screen) rather
/// than being a global provider — two open sessions must not share one
/// in-flight request or clobber each other's unsaved edits.
class SummaryNotifier extends StateNotifier<SummaryUiState> {
  /// Positional dependencies: initializing formals for private fields can't
  /// be named parameters in Dart.
  SummaryNotifier(
    this._bridge,
    this._sessionDirPath, {
    SessionMeta initialMeta = SessionMeta.empty,
  }) : super(
         SummaryUiState(
           status: initialMeta.hasSummary
               ? SummaryStatus.ready
               : SummaryStatus.empty,
           text: initialMeta.summary,
           template: initialMeta.summaryTemplate ?? SummaryTemplate.notulenRapat,
         ),
       );

  final RustBridge _bridge;
  final String _sessionDirPath;

  void setTemplate(SummaryTemplate template) {
    state = state.copyWith(template: template);
  }

  void edit(String text) {
    state = state.copyWith(
      text: text,
      dirty: true,
      status: text.trim().isEmpty ? SummaryStatus.empty : SummaryStatus.ready,
      clearError: true,
    );
  }

  /// Requests a summary from the configured endpoint. The only place in the
  /// app that can produce outbound traffic, and only from an explicit tap.
  ///
  /// Refuses rather than silently no-ops when the feature is off or
  /// misconfigured, so the user gets a reason instead of a dead button.
  Future<void> generate({
    required List<TranscriptSegment> segments,
    required AppSettings settings,
  }) async {
    if (!settings.summary.enabled) {
      state = state.copyWith(
        status: SummaryStatus.failed,
        error:
            'Ringkasan AI belum diaktifkan. Nyalakan di Pengaturan → Ringkasan AI.',
      );
      return;
    }
    if (!settings.summary.isUsable) {
      state = state.copyWith(
        status: SummaryStatus.failed,
        error:
            'Endpoint atau model ringkasan belum diisi. Lengkapi di Pengaturan → Ringkasan AI.',
      );
      return;
    }
    if (segments.isEmpty) {
      state = state.copyWith(
        status: SummaryStatus.failed,
        error: 'Transkrip kosong — tidak ada yang bisa diringkas.',
      );
      return;
    }

    state = state.copyWith(status: SummaryStatus.generating, clearError: true);
    try {
      final markdown = await _bridge.generateSummary(
        segments: segments,
        config: settings.summary.toConfig(
          language: settings.language,
          template: state.template,
        ),
      );
      if (!mounted) return;
      state = state.copyWith(
        status: SummaryStatus.ready,
        text: markdown,
        dirty: true,
        clearError: true,
      );
      await save();
    } catch (e) {
      if (!mounted) return;
      // The transcript is untouched by a summary failure; say so, because a
      // red error next to the transcript otherwise reads as data loss.
      state = state.copyWith(
        status: SummaryStatus.failed,
        error: 'Gagal membuat ringkasan (transkrip tetap aman): $e',
      );
    }
  }

  /// Persists the current text into the session's sidecar.
  Future<void> save() async {
    try {
      final existing = await readSessionMeta(_sessionDirPath);
      await writeSessionMeta(
        _sessionDirPath,
        existing.copyWith(
          summary: state.text,
          summaryTemplate: state.template,
          summaryGeneratedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      state = state.copyWith(dirty: false, clearError: true);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: 'Gagal menyimpan ringkasan: $e');
    }
  }
}
