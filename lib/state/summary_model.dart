import 'dart:async';
import 'dart:typed_data';

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

  /// Id of the user-authored template in use (F8), or `null` for a built-in.
  ///
  /// Held alongside [template] rather than replacing it: a custom template
  /// *is* `SummaryTemplate.kustom` as far as the engine is concerned, and the
  /// id is what lets the panel re-select the right one and what gets written
  /// to the sidecar so a session records which template produced it.
  final String? customTemplateId;

  final String? error;

  /// True when [text] differs from what was last written to the session's
  /// sidecar — drives the "Simpan" affordance.
  final bool dirty;

  /// "Tindak Lanjut" rows (F6). Editable, and the user's edits win over
  /// anything re-derivable from [text].
  final List<ActionItem> actionItems;

  /// [text] split into lines with each citation resolved to a timestamp
  /// (F7), or null when it has not been computed yet. Empty `lines` means
  /// "computed, and there was nothing to cite" — the panel then renders
  /// the summary as plain text.
  final SummaryProvenance? provenance;

  /// Which window a long-meeting summary is on (F15); null when the
  /// request was a single round trip.
  final MapReduceProgress? progress;

  const SummaryUiState({
    this.status = SummaryStatus.empty,
    this.text = '',
    this.template = SummaryTemplate.notulenRapat,
    this.customTemplateId,
    this.error,
    this.dirty = false,
    this.actionItems = const [],
    this.provenance,
    this.progress,
  });

  /// Citations the engine refused to trust, across the whole summary.
  int get droppedCitations => provenance?.dropped ?? 0;

  SummaryUiState copyWith({
    SummaryStatus? status,
    String? text,
    SummaryTemplate? template,
    Object? customTemplateId = _keep,
    String? error,
    bool clearError = false,
    bool? dirty,
    List<ActionItem>? actionItems,
    Object? provenance = _keep,
    Object? progress = _keep,
  }) {
    return SummaryUiState(
      status: status ?? this.status,
      text: text ?? this.text,
      template: template ?? this.template,
      customTemplateId: customTemplateId == _keep
          ? this.customTemplateId
          : customTemplateId as String?,
      error: clearError ? null : (error ?? this.error),
      dirty: dirty ?? this.dirty,
      actionItems: actionItems ?? this.actionItems,
      provenance: provenance == _keep
          ? this.provenance
          : provenance as SummaryProvenance?,
      progress: progress == _keep
          ? this.progress
          : progress as MapReduceProgress?,
    );
  }
}

/// Sentinel distinguishing "not passed" from "explicitly null".
const Object _keep = Object();

/// Drives one session's summary: generate, edit, save, regenerate.
///
/// Deliberately scoped to a single session (created per player screen) rather
/// than being a global provider — two open sessions must not share one
/// in-flight request or clobber each other's unsaved edits.
class SummaryNotifier extends StateNotifier<SummaryUiState> {
  /// Positional dependencies: initializing formals for private fields can't
  /// be named parameters in Dart.
  ///
  /// [onNetworkRequest] is invoked with the endpoint immediately before the
  /// only outbound request this app makes, so the Privacy Report can show it.
  SummaryNotifier(
    this._bridge,
    this._sessionDirPath, {
    SessionMeta initialMeta = SessionMeta.empty,
    this.onNetworkRequest,
  }) : super(
         SummaryUiState(
           status: initialMeta.hasSummary
               ? SummaryStatus.ready
               : SummaryStatus.empty,
           text: initialMeta.summary,
           template:
               initialMeta.summaryTemplate ?? SummaryTemplate.notulenRapat,
           customTemplateId: initialMeta.summaryCustomTemplateId,
           actionItems: initialMeta.actionItems,
         ),
       );

  final RustBridge _bridge;
  final String _sessionDirPath;

  /// Notified with the endpoint just before each outbound request.
  final void Function(String endpoint)? onNetworkRequest;

  /// Polls the engine's map-reduce progress while a request is in flight.
  Timer? _progressPoll;

  @override
  void dispose() {
    _progressPoll?.cancel();
    super.dispose();
  }

  // ── Tindak lanjut (F6) ──────────────────────────────────────────────

  /// Replaces one row. The user's edit wins over the model's text, so this
  /// also persists — a status ticked to "selesai" that vanishes on close
  /// is worse than no checklist.
  void setActionItem(int index, ActionItem item) {
    if (index < 0 || index >= state.actionItems.length) return;
    final items = [...state.actionItems]..[index] = item;
    state = state.copyWith(actionItems: items);
    unawaited(_saveActionItems());
  }

  void addActionItem() {
    final items = [
      ...state.actionItems,
      ActionItem(
        id: _freshActionId(),
        tugas: '',
        penanggungJawab: '',
        tenggat: '',
        status: ActionStatus.belum,
        segmentIds: Uint32List(0),
      ),
    ];
    state = state.copyWith(actionItems: items);
  }

  void removeActionItem(int index) {
    if (index < 0 || index >= state.actionItems.length) return;
    final items = [...state.actionItems]..removeAt(index);
    state = state.copyWith(actionItems: items);
    unawaited(_saveActionItems());
  }

  /// An id no existing row uses, so the `.ics` UID of an untouched task
  /// stays the same across re-exports.
  String _freshActionId() {
    final used = state.actionItems.map((i) => i.id).toSet();
    for (var n = state.actionItems.length + 1; ; n++) {
      final candidate = 'T$n';
      if (!used.contains(candidate)) return candidate;
    }
  }

  /// Rows with an empty `tugas` are dropped: an untouched blank row the
  /// user added and then ignored is not a task.
  Future<void> _saveActionItems() async {
    final items = [
      for (final item in state.actionItems)
        if (item.tugas.trim().isNotEmpty) item,
    ];
    try {
      final existing = await readSessionMeta(_sessionDirPath);
      await writeSessionMeta(
        _sessionDirPath,
        existing.copyWith(actionItems: items),
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: 'Gagal menyimpan tindak lanjut: $e');
    }
  }

  // ── Provenans (F7) ──────────────────────────────────────────────────

  /// Resolves the summary's `[#n]` markers against [segments].
  ///
  /// Recomputed rather than stored: the transcript is editable, and a
  /// citation cached against an older numbering would point at the wrong
  /// line — which is exactly the failure a citation is supposed to make
  /// impossible.
  Future<void> refreshProvenance(List<TranscriptSegment> segments) async {
    if (state.text.trim().isEmpty || segments.isEmpty) {
      if (!mounted) return;
      state = state.copyWith(provenance: null);
      return;
    }
    try {
      final parsed = await _bridge.summaryProvenance(
        summary: state.text,
        segments: segments,
      );
      if (!mounted) return;
      state = state.copyWith(provenance: parsed);
    } catch (_) {
      // A summary that cannot be parsed into citations still renders as
      // text; this is a presentation nicety, not the artifact.
      if (!mounted) return;
      state = state.copyWith(provenance: null);
    }
  }

  void setTemplate(SummaryTemplate template) {
    state = state.copyWith(template: template, customTemplateId: null);
  }

  /// Selects a user-authored template (F8). The engine still receives
  /// `SummaryTemplate.kustom`; the id only identifies which instructions to
  /// send and which template the session was summarised with.
  void setCustomTemplate(String id) {
    state = state.copyWith(
      template: SummaryTemplate.kustom,
      customTemplateId: id,
    );
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
    List<Bookmark> bookmarks = const [],
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
        error: 'Transkrip kosong, tidak ada yang bisa diringkas.',
      );
      return;
    }

    state = state.copyWith(status: SummaryStatus.generating, clearError: true);
    // A user-authored template's instruction is composed by the engine, so the
    // headings are spelled out the same way every time.
    var config = settings.summary.toConfig(
      language: settings.language,
      template: state.template,
    );
    final custom = settings.summaryTemplates
        .where((t) => t.id == state.customTemplateId)
        .firstOrNull;
    if (custom != null) {
      try {
        final instruction = await _bridge.composeSummaryInstruction(
          instructions: custom.instructions,
          headings: custom.headings,
        );
        config = SummaryConfig(
          provider: config.provider,
          baseUrl: config.baseUrl,
          apiKey: config.apiKey,
          model: config.model,
          template: SummaryTemplate.kustom,
          customPrompt: instruction,
          language: config.language,
          timeoutSecs: config.timeoutSecs,
          withCitations: config.withCitations,
          withActionItems: config.withActionItems,
        );
      } catch (e) {
        if (!mounted) return;
        state = state.copyWith(
          status: SummaryStatus.failed,
          error: 'Template "${custom.name}" tidak bisa dipakai: $e',
        );
        return;
      }
    }
    onNetworkRequest?.call(settings.summary.baseUrl);
    _startProgressPoll();
    try {
      // The long path (F15) falls back to a single request whenever the
      // transcript fits the model's budget, so it is a superset of
      // `generateSummary` rather than a different mode the user has to
      // choose. Before this, a three-hour meeting was summarised from a
      // truncated middle without saying so.
      final markdown = await _bridge.generateSummaryLong(
        segments: segments,
        config: config,
        bookmarks: bookmarks,
      );
      if (!mounted) return;
      // F6: lift the checklist out, then drop the machine-readable block
      // so the user does not read the same tasks twice.
      var text = markdown;
      var items = state.actionItems;
      if (config.withActionItems) {
        final parsed = await _bridge.parseActionItems(markdown);
        if (parsed.isNotEmpty) {
          items = parsed;
          text = await _bridge.stripActionItemsBlock(markdown);
        }
      }
      if (!mounted) return;
      state = state.copyWith(
        status: SummaryStatus.ready,
        text: text,
        actionItems: items,
        dirty: true,
        clearError: true,
      );
      await save();
      await refreshProvenance(segments);
    } catch (e) {
      if (!mounted) return;
      // The transcript is untouched by a summary failure; say so, because a
      // red error next to the transcript otherwise reads as data loss.
      state = state.copyWith(
        status: SummaryStatus.failed,
        error: 'Gagal membuat ringkasan (transkrip tetap aman): $e',
      );
    } finally {
      _stopProgressPoll();
    }
  }

  /// Mirrors the engine's map-reduce progress into the UI.
  ///
  /// Polled rather than streamed because the engine publishes it into a
  /// static the FFI can read cheaply; a three-hour meeting is around
  /// eighteen round trips and a panel that shows nothing for twenty
  /// minutes reads as a hang.
  void _startProgressPoll() {
    _progressPoll?.cancel();
    _progressPoll = Timer.periodic(const Duration(milliseconds: 700), (
      _,
    ) async {
      try {
        final progress = await _bridge.summaryProgress();
        if (!mounted) return;
        state = state.copyWith(progress: progress);
      } catch (_) {
        // Progress is decoration; losing it must not fail the summary.
      }
    });
  }

  void _stopProgressPoll() {
    _progressPoll?.cancel();
    _progressPoll = null;
    if (mounted) state = state.copyWith(progress: null);
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
          summaryCustomTemplateId: state.customTemplateId,
          summaryGeneratedAt: DateTime.now(),
          actionItems: [
            for (final item in state.actionItems)
              if (item.tugas.trim().isNotEmpty) item,
          ],
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
