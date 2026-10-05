import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../services/flight_recorder_service.dart';
import '../services/session_store.dart';
import 'enhance_queue_model.dart';
import '../src/rust/audio.dart' as rust_audio;
import '../src/rust/export.dart' as rust_export;
import '../src/rust/session.dart' as rust_session;
import 'models.dart';
import 'settings_model.dart';

enum SessionLifecycle { idle, recording, paused, stopped }

/// Thrown by [SessionNotifier.stop] when the session stopped cleanly but
/// the transcript failed to export — distinct from other stop() failures
/// so the UI can show a save-specific message instead of a generic one.
class TranscribeSaveError implements Exception {
  TranscribeSaveError(this.message);
  final String message;

  @override
  String toString() => message;
}

class SessionUiState {
  final SessionLifecycle lifecycle;
  final String? sessionId;
  final SessionConfig config;

  /// Live, unmodifiable view over the notifier's segment list.
  ///
  /// Deliberately a *view*, not a copy: at one segment every two seconds a
  /// three-hour meeting produces 5 000 of them, and copying the whole list
  /// per arrival made ingestion O(n²) on the UI isolate while Whisper was
  /// already saturating the CPU (audit A.1-12). Consumers must treat it as
  /// a snapshot only within a single frame — use [revision] to detect
  /// changes rather than comparing list identity or length.
  final List<TranscriptSegment> segments;

  /// Bumped on every mutation of [segments], including in-place text
  /// replacement (a refined HPT pass overwriting its quick pass), which
  /// changes neither the list identity nor its length.
  final int revision;

  final String sessionTitle;
  final double elapsedSeconds;

  /// Markers dropped during the meeting (F9), sorted by timestamp.
  ///
  /// A notulis' real workflow is *flagging* while the meeting runs — "this is
  /// the decision", "follow up on this" — and before this existed nothing in
  /// the app let them do it.
  final List<Bookmark> bookmarks;

  /// Glossary terms added for this meeting only, on top of the global list.
  /// Highest priority when the `initial_prompt` budget cannot hold
  /// everything.
  final List<String> sessionGlossaryTerms;

  /// The live hypothesis' uncommitted tail, shown greyed under the
  /// transcript. Empty when there is nothing provisional.
  ///
  /// Not part of [segments] and never counted in [revision]: it is one
  /// changing string, not a transcript row, and LocalAgreement-2 may
  /// replace it on the next decode.
  final String tentativeText;

  const SessionUiState({
    required this.lifecycle,
    required this.config,
    this.sessionId,
    this.segments = const [],
    this.revision = 0,
    this.sessionTitle = '',
    this.elapsedSeconds = 0,
    this.bookmarks = const [],
    this.sessionGlossaryTerms = const [],
    this.tentativeText = '',
  });

  /// Average confidence across current segments, or null if there are none
  /// yet — callers should show a placeholder rather than a fabricated value.
  double? get averageConfidence {
    if (segments.isEmpty) return null;
    final sum = segments.fold<double>(0, (acc, s) => acc + s.confidence);
    return sum / segments.length;
  }

  SessionUiState copyWith({
    SessionLifecycle? lifecycle,
    String? sessionId,
    SessionConfig? config,
    List<TranscriptSegment>? segments,
    int? revision,
    String? sessionTitle,
    double? elapsedSeconds,
    List<Bookmark>? bookmarks,
    List<String>? sessionGlossaryTerms,
    String? tentativeText,
  }) {
    return SessionUiState(
      lifecycle: lifecycle ?? this.lifecycle,
      sessionId: sessionId ?? this.sessionId,
      config: config ?? this.config,
      segments: segments ?? this.segments,
      revision: revision ?? this.revision,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      bookmarks: bookmarks ?? this.bookmarks,
      sessionGlossaryTerms: sessionGlossaryTerms ?? this.sessionGlossaryTerms,
      tentativeText: tentativeText ?? this.tentativeText,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionUiState> {
  final RustBridge _bridge;

  /// Every write to [state] goes through here so lifecycle transitions can
  /// notify the enhance queue in one place instead of six.
  @override
  set state(SessionUiState value) {
    super.state = value;
    _notifyLiveChanged();
  }

  StreamSubscription<TranscriptSegment>? _transcriptSub;
  StreamSubscription<String>? _tentativeSub;
  Timer? _autoStopTimer;
  Timer? _elapsedTimer;
  DateTime? _recordingStartedAt;
  int? _autoStopMinutes;

  /// Synchronous re-entrancy guard for [start] and [recoverFromSnapshot].
  ///
  /// Both only set `lifecycle` to `recording` *after* their awaits, so the
  /// lifecycle check cannot see a launch that is already in flight. Set
  /// before the first await and cleared in a `finally`, so a failed start
  /// still leaves the app able to try again.
  bool _launching = false;
  String _libraryPath = kDefaultLibraryPath;
  // Recorded into the session's metadata sidecar on stop, so the library and
  // "Transkrip Ulang" know what produced the transcript.
  String? _language;
  String _modelId = 'base';

  SessionNotifier(
    this._bridge,
    SessionMode initialMode,
    String initialModelPath,
  ) : super(
        SessionUiState(
          lifecycle: SessionLifecycle.idle,
          config: SessionConfig.forMode(initialMode, initialModelPath),
        ),
      );

  void _resetAutoStopTimer() {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    final minutes = _autoStopMinutes;
    if (minutes == null || minutes <= 0) return;
    if (state.lifecycle != SessionLifecycle.recording) return;
    _autoStopTimer = Timer(Duration(minutes: minutes), () {
      _autoStopTimer = null;
      if (state.lifecycle == SessionLifecycle.recording) {
        stop();
      }
    });
  }

  static bool _isBlankAudio(TranscriptSegment s) =>
      s.text.trim() == '[BLANK_AUDIO]';

  /// Backing store for [SessionUiState.segments]. Appended to in place; the
  /// state object publishes an unmodifiable *view* of it.
  final List<TranscriptSegment> _segments = <TranscriptSegment>[];

  /// `segmentKey → position in [_segments]`. This is what makes ingestion
  /// O(1): finding the row an HPT refine pass belongs to used to be a
  /// linear `indexWhere` over every segment received so far, so the cost of
  /// a meeting grew with its square (audit A.1-12).
  final Map<String, int> _segmentIndexByKey = <String, int>{};

  int _revision = 0;

  List<TranscriptSegment> get _segmentsView => UnmodifiableListView(_segments);

  /// Publishes [_segments] with a fresh [SessionUiState.revision].
  void _publishSegments() {
    _revision++;
    state = state.copyWith(segments: _segmentsView, revision: _revision);
  }

  /// Replaces the whole transcript (session start, crash recovery) and
  /// rebuilds the key index. First-seen position wins on a duplicate key,
  /// mirroring `journal::replay` on the Rust side.
  void _loadSegments(Iterable<TranscriptSegment> next) {
    _segments
      ..clear()
      ..addAll(next);
    _segmentIndexByKey.clear();
    for (var i = 0; i < _segments.length; i++) {
      _segmentIndexByKey.putIfAbsent(_segments[i].segmentKey, () => i);
    }
    _revision++;
  }

  /// Replaces the whole transcript.
  ///
  /// The notifier owns the segment list now (that is what makes ingestion
  /// O(1)), so seeding it through `state = state.copyWith(segments: …)`
  /// would leave the key index empty and the next arriving segment would
  /// append to nothing. Callers that hydrate a session from outside the
  /// live stream — and tests — go through here.
  void setSegments(List<TranscriptSegment> segments) {
    _loadSegments(segments);
    state = state.copyWith(segments: _segmentsView, revision: _revision);
  }

  void _onTranscriptSegment(TranscriptSegment segment) {
    if (_isBlankAudio(segment)) return;
    final key = segment.segmentKey;
    final index = _segmentIndexByKey[key];
    if (index != null) {
      // HPT: refined (final) text replaces the partial quick pass. A new
      // partial NEVER overwrites an already-refined row — the accurate
      // pass is authoritative.
      if (!segment.isPartial || _segments[index].isPartial) {
        _segments[index] = segment;
        _publishSegments();
      }
    } else {
      _segmentIndexByKey[key] = _segments.length;
      _segments.add(segment);
      _publishSegments();
    }
    _resetAutoStopTimer();
  }

  void _subscribeToLiveStreams(String sessionId) {
    _transcriptSub = _bridge
        .transcriptStream(sessionId)
        .listen(_onTranscriptSegment);
    _tentativeSub = _bridge.tentativeStream(sessionId).listen((text) {
      if (state.tentativeText == text) return;
      state = state.copyWith(tentativeText: text);
    });
    _recordingStartedAt ??= DateTime.now();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _recordingStartedAt;
      if (started != null) {
        state = state.copyWith(
          elapsedSeconds: DateTime.now()
              .difference(started)
              .inSeconds
              .toDouble(),
        );
      }
    });
  }

  void _cancelLiveStreams() {
    _transcriptSub?.cancel();
    _transcriptSub = null;
    _tentativeSub?.cancel();
    _tentativeSub = null;
    // Nothing is provisional once the stream is gone, and leaving the last
    // tail on screen would read as transcript.
    if (state.tentativeText.isNotEmpty) {
      state = state.copyWith(tentativeText: '');
    }
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void seedRecovery(rust_session.SessionRecoverySnapshot snapshot) {
    final recovered = SessionConfig(
      micEnabled: snapshot.config.micEnabled,
      speakerEnabled: snapshot.config.speakerEnabled,
      mode: switch (snapshot.config.mode) {
        rust_audio.SessionMode.webinar => SessionMode.webinar,
        rust_audio.SessionMode.online => SessionMode.online,
        rust_audio.SessionMode.offline => SessionMode.offline,
      },
      modelPath: snapshot.config.modelPath,
      vadEnabled: snapshot.config.vadEnabled,
    );
    state = state.copyWith(config: recovered);
  }

  /// Restores a crashed session: its transcript, its audio and its clock.
  ///
  /// `segments: []` used to be hardcoded here, which is how a two-hour
  /// meeting came back empty from a banner promising it could be
  /// recovered. Returns the recovered session so the caller can tell the
  /// user what actually came back.
  Future<rust_session.RecoveredSession?> recoverFromSnapshot(
    rust_session.SessionRecoverySnapshot snapshot,
  ) async {
    // Same guard as start(): without it, recovering while a session is
    // already recording (e.g. a previous recovery, or the user pressing
    // Mulai first) silently orphans that session's Rust-side capture —
    // its registry entry and audio threads keep running with nothing left
    // to stop them — while this one clobbers the visible state.
    if (_launching ||
        state.lifecycle == SessionLifecycle.recording ||
        state.lifecycle == SessionLifecycle.paused) {
      return null;
    }
    _launching = true;
    try {
      seedRecovery(snapshot);
      final recovered = await _bridge.recoverSession(snapshot);
      _loadSegments(recovered.segments.map(fromRustSegment));
      state = state.copyWith(
        lifecycle: SessionLifecycle.recording,
        sessionId: recovered.sessionId,
        segments: _segmentsView,
        revision: _revision,
        sessionTitle: snapshot.title.isNotEmpty
            ? snapshot.title
            : state.sessionTitle,
      );
      // The elapsed timer continues from where the crashed run left off
      // rather than restarting at 00:00 — the audio and transcript did.
      _recordingStartedAt = DateTime.now().subtract(
        Duration(milliseconds: (recovered.resumeOffsetSecs * 1000).round()),
      );
      _subscribeToLiveStreams(recovered.sessionId);
      _mirrorTitleToSnapshot();
      _resetAutoStopTimer();
      return recovered;
    } finally {
      _launching = false;
    }
  }

  Future<void> start() async {
    // Guard against double-start. The lifecycle check alone is not enough:
    // lifecycle only flips to `recording` after the awaits below, so a
    // second call arriving inside that window — a double-click on Mulai, or
    // Ctrl+R held down — passed the check and started a *second* live Rust
    // session. The first one was then orphaned: its capture threads and
    // registry entry kept running with no id left in Dart to stop them, so
    // it recorded to disk until the app exited. `_launching` is set
    // synchronously, before the first await, which is what closes the gap.
    if (_launching ||
        state.lifecycle == SessionLifecycle.recording ||
        state.lifecycle == SessionLifecycle.paused) {
      return;
    }
    _launching = true;
    try {
      // Model existence is checked by the Rust side's own resolve_model_path(),
      // which handles tilde expansion, sandbox paths, and multiple search
      // locations. The old File.existsSync() check here was unreliable because
      // modelPath can be a relative path (fallback from modelPathForId) that
      // doesn't resolve against the Flutter app bundle's CWD, or contain an
      // unexpanded '~' in the library path — producing false-positive "model
      // tidak ditemukan" errors even when the model file exists.
      // Auto-detect frontmost window title as default session name.
      final detected = await _bridge.detectFrontmostWindowTitle();
      // The microphone needs a concrete device name resolved here (cpal has
      // no "default input" concept the engine can use). System audio does
      // not — see _resolveDevices.
      final configWithDevices = await _resolveDevices(state.config);
      state = state.copyWith(config: configWithDevices);
      final id = await _bridge.startSession(state.config);
      _loadSegments(const []);
      state = state.copyWith(
        lifecycle: SessionLifecycle.recording,
        sessionId: id,
        segments: _segmentsView,
        revision: _revision,
        sessionTitle: detected.isNotEmpty ? detected : state.sessionTitle,
        // A new meeting starts with no markers; carrying the previous
        // session's over would put them at timestamps that no longer exist.
        bookmarks: const [],
      );
      _subscribeToLiveStreams(id);
      _mirrorTitleToSnapshot();
      _resetAutoStopTimer();
    } finally {
      _launching = false;
    }
  }

  /// Resolves a concrete microphone name when the config doesn't already
  /// carry one, mirroring the setup wizard's choice (the OS default input).
  ///
  /// The speaker hint is passed through as-is — see below for why guessing
  /// one breaks system-audio capture on every platform.
  Future<SessionConfig> _resolveDevices(SessionConfig config) async {
    var micDeviceId = config.micDeviceId;
    final speakerDeviceId = config.speakerDeviceId;
    if (micDeviceId == null && config.micEnabled) {
      final inputs = await _bridge.listAudioDevices();
      if (inputs.isNotEmpty) {
        // Prefer the OS-reported default input device. Falling back to
        // inputs.first (as this used to) picks whatever the audio host
        // happens to enumerate first — on a machine with a virtual/loopback
        // input installed (e.g. BlackHole, common with meeting/recording
        // tools), that can silently outrank the user's real microphone,
        // capturing total silence with no error.
        micDeviceId = inputs
            .firstWhere((d) => d.isDefault, orElse: () => inputs.first)
            .name;
      }
    }
    // speakerDeviceId is deliberately left as the user set it, including
    // null. A null/empty hint is what tells the engine to resolve system
    // audio itself — ScreenCaptureKit's zero-setup capture on macOS, the
    // default sink's `.monitor` on Linux, the default render device on
    // Windows — and that is right on all three.
    //
    // Guessing one here is what used to break it. The old heuristic picked
    // the first output whose name contained "blackhole"/"loopback" and
    // otherwise `outputs.first`, then fell back to searching the *input*
    // list the same way. On macOS that concrete name made
    // `capture_loopback` skip ScreenCaptureKit entirely and try to open a
    // playback device ("MacBook Pro Speakers") as a capture source; on
    // Linux it handed `resolve_monitor_source` a sink name that is not a
    // monitor. Whatever the user actually chose in the setup wizard is
    // already in the config and is passed through untouched.
    return config.copyWith(
      micDeviceId: micDeviceId,
      speakerDeviceId: speakerDeviceId,
    );
  }

  /// The session id whose audio is still waiting to be exported. Kept
  /// after `stop()` so a retried save can still place the WAVs — the
  /// engine holds them until `exportSessionAudio` claims them.
  String? _pendingAudioSessionId;

  /// Title the save used, so a retry writes to the same folder.
  String _pendingTitle = '';

  /// Whether the captured audio has been moved out of the recovery
  /// directory into a session folder. A retry must not try again once it
  /// has — the engine hands the audio over exactly once — but it *must*
  /// try again if the first attempt failed, so "Simpan ke folder lain"
  /// rescues the recording along with the transcript.
  bool _audioPlaced = false;

  /// Whether the transcript of the last stopped session is on disk.
  /// `false` after a failed save, until [retrySave] succeeds.
  bool get hasUnsavedTranscript =>
      state.lifecycle == SessionLifecycle.stopped &&
      state.segments.isNotEmpty &&
      _pendingAudioSessionId != null;

  Future<void> stop() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    final id = state.sessionId;
    if (id == null) return;
    _cancelLiveStreams();
    _recordingStartedAt = null;
    await _bridge.stopSession(id);
    state = state.copyWith(
      lifecycle: SessionLifecycle.stopped,
      elapsedSeconds: 0,
    );
    _pendingAudioSessionId = id;
    _audioPlaced = false;
    _pendingTitle = state.sessionTitle.isNotEmpty
        ? state.sessionTitle
        : 'Sesi ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}';
    await _saveStoppedSession(resolveTilde(_libraryPath));
  }

  /// Re-runs the save that failed, optionally somewhere else.
  ///
  /// A failed save used to be a three-second toast and nothing else: the
  /// transcript was still in memory, but the only way to get it onto disk
  /// was to notice the toast and know to press Ekspor. This is what the
  /// banner's "Coba lagi" / "Simpan ke folder lain" call.
  Future<void> retrySave({String? outputDir}) async {
    if (!hasUnsavedTranscript) return;
    await _saveStoppedSession(outputDir ?? resolveTilde(_libraryPath));
  }

  Future<void> _saveStoppedSession(String outputDir) async {
    final segments = state.segments;
    final id = _pendingAudioSessionId;
    final title = _pendingTitle;

    // Audio first, and unconditionally.
    //
    // Transcription can lag far behind capture on a slow device, so a
    // session stopped before Whisper has finalized its first segment is
    // an ordinary outcome — and it still holds the whole recording. The
    // audio used to be dropped in exactly that case, which made "stop too
    // early" a silent data-loss path. Saving it means the user can run
    // "Transkrip Ulang" over it afterwards.
    var audio = const <rust_export.ExportedFile>[];
    if (id != null && !_audioPlaced) {
      try {
        audio = await _bridge.exportSessionAudio(
          sessionId: id,
          outputDir: outputDir,
          title: title,
        );
        _audioPlaced = true;
      } catch (e) {
        debugPrint('exportSessionAudio failed: $e');
      }
    }
    if (segments.isEmpty && audio.isEmpty && _audioPlaced) {
      // Nothing was captured and nothing was transcribed: an empty folder
      // would just be litter in the library.
      _pendingAudioSessionId = null;
      return;
    }

    // Rethrown (not swallowed) so the caller can tell the user their
    // transcript failed to save — previously a failed auto-save here was
    // silently lost with zero feedback, leaving the user unable to tell
    // a real save from a failed one.
    final List<rust_export.ExportedFile> exported;
    try {
      exported = await _bridge.exportSession(
        segments: segments,
        outputDir: outputDir,
        title: title,
      );
    } catch (e) {
      throw TranscribeSaveError(
        'Sesi berhenti, tapi gagal menyimpan transkrip ke $outputDir: $e',
      );
    }
    // The transcript is on disk; a retry must not write it a second time.
    _pendingAudioSessionId = null;

    // Best-effort from here on: the transcript (the primary artifact) is
    // already saved, so a failure writing the metadata sidecar shouldn't
    // surface as a save error. The sidecar gives the library the
    // user-facing title (instead of the date-prefixed folder name) and
    // gives "Transkrip Ulang" the model and language this session used.
    final anchor = exported.isNotEmpty ? exported.first : audio.firstOrNull;
    if (anchor != null) {
      try {
        await writeSessionMeta(
          File(anchor.path).parent.path,
          SessionMeta(
            title: title,
            language: _language,
            model: _modelId,
            bookmarks: state.bookmarks,
          ),
        );
      } catch (_) {}
    }
    // Hand the finished session to the background "perhalus transkrip" pass
    // (F5). Deliberately after the sidecar write: the queue reads the session
    // folder from disk, and the backup it makes before replacing anything
    // depends on the transcript already being there.
    final directory = anchor == null ? null : File(anchor.path).parent.path;
    if (directory != null) {
      _onSessionSaved?.call(
        SavedSessionHandoff(
          directoryPath: directory,
          title: title,
          modelId: _modelId,
          language: _language,
          usedQuickModel: _progressiveEnabled || _modelId != kAccurateModelId,
          autoRetranscribePreference: _autoRetranscribe,
          segments: segments,
        ),
      );
    }
  }

  /// Called with every session that lands on disk, so the enhance queue can
  /// pick it up without `SessionNotifier` depending on the queue.
  void Function(SavedSessionHandoff)? _onSessionSaved;

  // ignore: use_setters_to_change_properties
  void onSessionSaved(void Function(SavedSessionHandoff)? callback) {
    _onSessionSaved = callback;
  }

  /// Called whenever the session becomes (or stops being) live, so the
  /// enhance queue can yield to it.
  ///
  /// A callback rather than `ref.listen(sessionProvider, …)` inside the
  /// provider that *creates* this notifier: that would be a provider
  /// depending on itself.
  // ignore: use_setters_to_change_properties
  void onLiveChanged(void Function(bool live)? callback) {
    _onLiveChanged = callback;
  }

  void Function(bool live)? _onLiveChanged;

  bool _lastLive = false;

  void _notifyLiveChanged() {
    final live =
        state.lifecycle == SessionLifecycle.recording ||
        state.lifecycle == SessionLifecycle.paused;
    if (state.lifecycle != _lastLifecycle) {
      // Metadata only: the session id and the two state names. This is the
      // trail a bug report needs and the reason the recorder exists.
      unawaited(
        FlightRecorder.instance.logLifecycle(
          state.sessionId ?? '-',
          _lastLifecycle.name,
          state.lifecycle.name,
        ),
      );
      _lastLifecycle = state.lifecycle;
    }
    if (live == _lastLive) return;
    _lastLive = live;
    _onLiveChanged?.call(live);
  }

  SessionLifecycle _lastLifecycle = SessionLifecycle.idle;

  bool _progressiveEnabled = true;
  bool? _autoRetranscribe;

  /// Pauses live transcript updates without tearing down the session —
  /// distinct from stop(), which ends it entirely (PP: pause/resume
  /// recording, not just start/stop). Cancellation of the old stream
  /// subscription is fire-and-forget: the UI toggle doesn't await pause(),
  /// so lifecycle must flip synchronously rather than after an async gap.
  void pause() {
    if (state.lifecycle != SessionLifecycle.recording) return;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _cancelLiveStreams();
    final id = state.sessionId;
    if (id != null) _bridge.pauseSession(id);
    state = state.copyWith(lifecycle: SessionLifecycle.paused);
  }

  void resume() {
    final id = state.sessionId;
    if (id == null || state.lifecycle != SessionLifecycle.paused) return;
    _bridge.resumeSession(id);
    _subscribeToLiveStreams(id);
    _resetAutoStopTimer();
    state = state.copyWith(lifecycle: SessionLifecycle.recording);
  }

  Future<void> toggleMic(bool enabled) async {
    final id = state.sessionId;
    state = state.copyWith(config: state.config.copyWith(micEnabled: enabled));
    if (id != null) await _bridge.toggleMic(id, enabled);
  }

  Future<void> toggleSpeaker(bool enabled) async {
    final id = state.sessionId;
    state = state.copyWith(
      config: state.config.copyWith(speakerEnabled: enabled),
    );
    if (id != null) await _bridge.toggleSpeaker(id, enabled);
  }

  // ── Bookmarks (F9) ────────────────────────────────────────────────────

  /// Offset into the recording *right now*, to sub-second precision.
  ///
  /// [SessionUiState.elapsedSeconds] only ticks once a second, so using it
  /// would quantise every marker to the nearest second — enough to land a
  /// bookmark on the wrong utterance in a fast exchange.
  double get _currentOffsetSeconds {
    final started = _recordingStartedAt;
    if (started == null) return state.elapsedSeconds;
    return DateTime.now().difference(started).inMilliseconds / 1000.0;
  }

  /// Drops a marker at the current position. `note` is optional — the
  /// timestamp is the point, and stopping to type during a meeting is exactly
  /// what this feature exists to avoid.
  ///
  /// Returns the bookmark that was added, or `null` when there is no
  /// recording to mark.
  Bookmark? addBookmark({String note = ''}) {
    if (state.lifecycle != SessionLifecycle.recording &&
        state.lifecycle != SessionLifecycle.paused) {
      return null;
    }
    final bookmark = Bookmark(
      timestamp: _currentOffsetSeconds.clamp(0, double.maxFinite),
      note: note.trim(),
    );
    final next = [...state.bookmarks, bookmark]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = state.copyWith(bookmarks: next);
    return bookmark;
  }

  /// Attaches or replaces the note on the bookmark at [timestamp].
  void setBookmarkNote(double timestamp, String note) {
    final next = [
      for (final bookmark in state.bookmarks)
        if (bookmark.timestamp == timestamp)
          Bookmark(timestamp: bookmark.timestamp, note: note.trim())
        else
          bookmark,
    ];
    state = state.copyWith(bookmarks: next);
  }

  void removeBookmark(double timestamp) {
    state = state.copyWith(
      bookmarks: state.bookmarks
          .where((bookmark) => bookmark.timestamp != timestamp)
          .toList(),
    );
  }

  // ── Per-session kamus istilah (F3) ────────────────────────────────────

  /// Replaces this meeting's extra glossary terms and pushes them into the
  /// session config, so a term added before Mulai is in effect from the first
  /// chunk.
  ///
  /// Terms added *during* a recording apply to subsequent chunks only: the
  /// engine's worker already holds its glossary, and restarting capture to
  /// pick up a term would cost the audio in flight.
  void setSessionGlossaryTerms(List<String> terms, {GlossarySettings? global}) {
    final cleaned = dedupeTerms(terms);
    final settings = global ?? _glossarySettings;
    state = state.copyWith(
      sessionGlossaryTerms: cleaned,
      config: state.config.copyWith(
        glossary: settings.toConfig(sessionTerms: cleaned),
      ),
    );
  }

  GlossarySettings _glossarySettings = kDefaultGlossarySettings;

  /// Edits one row in place. The segment key is `(source, timestamp)`, and
  /// neither changes here, so [_segmentIndexByKey] stays valid.
  void editTranscriptSegment(int index, String newText) {
    if (index < 0 || index >= _segments.length) return;
    _segments[index] = _segments[index].copyWith(text: newText);
    _publishSegments();
  }

  void renameSpeaker(String oldLabel, String newLabel) {
    var changed = false;
    for (var i = 0; i < _segments.length; i++) {
      if (_segments[i].speaker != oldLabel) continue;
      _segments[i] = _segments[i].copyWith(speaker: newLabel);
      changed = true;
    }
    if (changed) _publishSegments();
  }

  void setMode(SessionMode mode) {
    // Update mode AND apply mode's default mic/speaker toggles
    // (Blueprint: Webinar=Mic OFF/SPK ON, Online=Both ON, Offline=Mic ON/SPK OFF)
    final (mic, speaker) = mode.defaultToggles;
    state = state.copyWith(
      config: state.config.copyWith(
        mode: mode,
        micEnabled: mic,
        speakerEnabled: speaker,
      ),
    );
  }

  void syncDefaultSettings(AppSettings settings) {
    _libraryPath = settings.libraryPath;
    if (state.lifecycle == SessionLifecycle.recording ||
        state.lifecycle == SessionLifecycle.paused) {
      return;
    }
    _autoStopMinutes = settings.autoStopMinutes;
    _language = settings.language;
    _modelId = settings.defaultModel;
    _glossarySettings = settings.glossary;
    _progressiveEnabled = settings.progressiveEnabled;
    _autoRetranscribe = settings.autoRetranscribe;
    final (mic, speaker) = settings.defaultMode.defaultToggles;
    // HPT: quick pass uses the default model; refine pass always targets
    // large-v3-turbo-q5 when progressive is enabled (and the quick model
    // is not itself the q5 — HPT only makes sense quick≠refine).
    final quickPath = modelPathForId(
      settings.defaultModel,
      libraryPath: settings.libraryPath,
    );
    final refinePath =
        settings.progressiveEnabled &&
            settings.defaultModel != 'large-v3-turbo-q5' &&
            isModelAvailable(
              'large-v3-turbo-q5',
              libraryPath: settings.libraryPath,
            )
        ? modelPathForId('large-v3-turbo-q5', libraryPath: settings.libraryPath)
        : null;
    state = state.copyWith(
      config: SessionConfig(
        micEnabled: mic,
        speakerEnabled: speaker,
        mode: settings.defaultMode,
        modelPath: quickPath,
        refineModelPath: refinePath,
        vadEnabled: settings.vadEnabled,
        micDeviceId: settings.micDeviceId,
        speakerDeviceId: settings.speakerDeviceId,
        gpuEnabled: settings.gpuEnabled,
        gpuDevice: settings.gpuDevice,
        audioToDisk: settings.audioToDisk,
        glossary: settings.glossary.toConfig(
          sessionTerms: state.sessionGlossaryTerms,
        ),
        // Only meaningful in single-model mode, where the engine
        // benchmarks `quickPath` and swaps this in if it cannot keep up
        // live. In progressive mode adaptive HPT already owns that choice.
        fallbackModelPath: refinePath != null
            ? null
            : fastestInstalledModelPath(
                exclude: quickPath,
                libraryPath: settings.libraryPath,
              ),
      ),
    );
  }

  void setTitle(String title) {
    state = state.copyWith(sessionTitle: title);
    if (state.lifecycle == SessionLifecycle.recording) {
      _mirrorTitleToSnapshot();
    }
  }

  /// Pushes the current title into the recovery snapshot, so a crashed
  /// session shows up under the name the user gave it rather than a UUID.
  ///
  /// Called both on edit *and* right after the session starts: the usual
  /// order is to type the title first and then press Mulai, in which case
  /// there was no session to mirror into at the time it was typed.
  ///
  /// Fire-and-forget: the title field has to stay responsive, and a failed
  /// mirror costs a label in one dialog.
  void _mirrorTitleToSnapshot() {
    final id = state.sessionId;
    final title = state.sessionTitle;
    if (id == null || title.isEmpty) return;
    unawaited(_bridge.setSessionTitle(id, title).catchError((_) {}));
  }

  void updateAutoStopMinutes(int? minutes) {
    _autoStopMinutes = minutes;
    if (state.lifecycle == SessionLifecycle.recording) {
      _resetAutoStopTimer();
    }
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _cancelLiveStreams();
    super.dispose();
  }
}

final StateNotifierProvider<SessionNotifier, SessionUiState>
sessionProvider = StateNotifierProvider<SessionNotifier, SessionUiState>((ref) {
  // Use ref.read (not watch) — watching would recreate the SessionNotifier on
  // every settings change, destroying the active session (transcript subs,
  // timers, segments).  ref.listen below handles updates reactively.
  final settings = ref.read(settingsProvider);
  final notifier = SessionNotifier(
    ref.read(rustBridgeProvider),
    settings.defaultMode,
    modelPathForId(settings.defaultModel, libraryPath: settings.libraryPath),
  );
  notifier.syncDefaultSettings(settings);
  ref.listen<AppSettings>(settingsProvider, (previous, next) {
    notifier.syncDefaultSettings(next);
    if (previous?.autoStopMinutes != next.autoStopMinutes) {
      notifier.updateAutoStopMinutes(next.autoStopMinutes);
    }
  });
  // "Perhalus transkrip" (F5): every saved session is offered to the queue,
  // which decides for itself whether it qualifies. The queue also yields
  // while a session is live — Whisper cannot usefully run twice at once.
  notifier.onSessionSaved((handoff) {
    unawaited(ref.read(enhanceQueueProvider.notifier).considerSession(handoff));
  });
  notifier.onLiveChanged((live) {
    ref.read(enhanceQueueProvider.notifier).setPaused(live);
  });
  return notifier;
});
