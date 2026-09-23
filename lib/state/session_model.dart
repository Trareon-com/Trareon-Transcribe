import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../src/rust/audio.dart' as rust_audio;
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
  final List<TranscriptSegment> segments;
  final String sessionTitle;
  final double elapsedSeconds;

  const SessionUiState({
    required this.lifecycle,
    required this.config,
    this.sessionId,
    this.segments = const [],
    this.sessionTitle = '',
    this.elapsedSeconds = 0,
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
    String? sessionTitle,
    double? elapsedSeconds,
  }) {
    return SessionUiState(
      lifecycle: lifecycle ?? this.lifecycle,
      sessionId: sessionId ?? this.sessionId,
      config: config ?? this.config,
      segments: segments ?? this.segments,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionUiState> {
  final RustBridge _bridge;
  StreamSubscription<TranscriptSegment>? _transcriptSub;
  Timer? _autoStopTimer;
  Timer? _elapsedTimer;
  DateTime? _recordingStartedAt;
  int? _autoStopMinutes;
  String _libraryPath = '~/Documents/TrareonTranscribe';

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

  void _onTranscriptSegment(TranscriptSegment segment) {
    if (_isBlankAudio(segment)) return;
    final segments = state.segments;
    final key = segment.segmentKey;
    final index = segments.indexWhere((s) => s.segmentKey == key);
    if (index >= 0) {
      // HPT: refined (final) text replaces the partial quick pass. A new
      // partial NEVER overwrites an already-refined row — the accurate
      // pass is authoritative.
      if (!segment.isPartial || segments[index].isPartial) {
        final updated = [...segments];
        updated[index] = segment;
        state = state.copyWith(segments: updated);
      }
    } else {
      state = state.copyWith(segments: [...segments, segment]);
    }
    _resetAutoStopTimer();
  }

  void _subscribeToLiveStreams(String sessionId) {
    _transcriptSub = _bridge
        .transcriptStream(sessionId)
        .listen(_onTranscriptSegment);
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

  Future<void> recoverFromSnapshot(
    rust_session.SessionRecoverySnapshot snapshot,
  ) async {
    // Same guard as start(): without it, recovering while a session is
    // already recording (e.g. a previous recovery, or the user pressing
    // Mulai first) silently orphans that session's Rust-side capture —
    // its registry entry and audio threads keep running with nothing left
    // to stop them — while this one clobbers the visible state.
    if (state.lifecycle == SessionLifecycle.recording ||
        state.lifecycle == SessionLifecycle.paused) {
      return;
    }
    seedRecovery(snapshot);
    final id = await _bridge.recoverSession(snapshot);
    state = state.copyWith(
      lifecycle: SessionLifecycle.recording,
      sessionId: id,
      segments: [],
    );
    _subscribeToLiveStreams(id);
    _resetAutoStopTimer();
  }

  Future<void> start() async {
    // Guard against double-start: if already recording/paused, ignore.
    if (state.lifecycle == SessionLifecycle.recording ||
        state.lifecycle == SessionLifecycle.paused) {
      return;
    }
    // Model existence is checked by the Rust side's own resolve_model_path(),
    // which handles tilde expansion, sandbox paths, and multiple search
    // locations. The old File.existsSync() check here was unreliable because
    // modelPath can be a relative path (fallback from modelPathForId) that
    // doesn't resolve against the Flutter app bundle's CWD, or contain an
    // unexpanded '~' in the library path — producing false-positive "model
    // tidak ditemukan" errors even when the model file exists.
    // Auto-detect frontmost window title as default session name.
    final detected = await _bridge.detectFrontmostWindowTitle();
    // start_capture() on the Rust side treats a null device id as "setup not
    // completed" and skips spawning the capture thread entirely — so a
    // concrete device name must be resolved here, or mic/speaker audio is
    // silently never captured regardless of the mic/speaker toggles.
    final configWithDevices = await _resolveDevices(state.config);
    state = state.copyWith(config: configWithDevices);
    final id = await _bridge.startSession(state.config);
    state = state.copyWith(
      lifecycle: SessionLifecycle.recording,
      sessionId: id,
      segments: [],
      sessionTitle: detected.isNotEmpty ? detected : state.sessionTitle,
    );
    _subscribeToLiveStreams(id);
    _resetAutoStopTimer();
  }

  /// Resolves concrete mic/speaker device names when the config doesn't
  /// already carry one. Mirrors the setup wizard's own default-selection
  /// heuristic: system default input device for mic, first loopback-looking
  /// output device (BlackHole/WASAPI loopback) for speaker.
  Future<SessionConfig> _resolveDevices(SessionConfig config) async {
    var micDeviceId = config.micDeviceId;
    var speakerDeviceId = config.speakerDeviceId;
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
    if (speakerDeviceId == null && config.speakerEnabled) {
      final outputs = await _bridge.listOutputAudioDevices();
      if (outputs.isNotEmpty) {
        speakerDeviceId = outputs
            .firstWhere(
              (d) =>
                  d.name.toLowerCase().contains('blackhole') ||
                  d.name.toLowerCase().contains('loopback'),
              orElse: () => outputs.first,
            )
            .name;
      }
      // Fallback: search listAudioDevices() for BlackHole/loopback too
      if (speakerDeviceId == null) {
        final inputs = await _bridge.listAudioDevices();
        if (inputs.isNotEmpty) {
          speakerDeviceId = inputs
              .firstWhere(
                (d) =>
                    d.name.toLowerCase().contains('blackhole') ||
                    d.name.toLowerCase().contains('loopback'),
                orElse: () => inputs.first,
              )
              .name;
        }
      }
    }
    return config.copyWith(
      micDeviceId: micDeviceId,
      speakerDeviceId: speakerDeviceId,
    );
  }

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
    final segments = state.segments;
    if (segments.isNotEmpty) {
      final title = state.sessionTitle.isNotEmpty
          ? state.sessionTitle
          : 'Sesi ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}';
      final outputDir = resolveTilde(_libraryPath);
      // Rethrown (not swallowed) so the caller can tell the user their
      // transcript failed to save — previously a failed auto-save here was
      // silently lost with zero feedback, leaving the user unable to tell
      // a real save from a failed one.
      try {
        await _bridge.exportSession(
          segments: segments,
          outputDir: outputDir,
          title: title,
        );
      } catch (e) {
        throw TranscribeSaveError(
          'Sesi berhenti, tapi gagal menyimpan transkrip ke $outputDir: $e',
        );
      }
      // Best-effort: the transcript (the primary artifact) already saved
      // successfully above, so a raw-audio export failure here shouldn't
      // surface as a save error to the user — swallow it.
      try {
        await _bridge.exportSessionAudio(
          sessionId: id,
          outputDir: outputDir,
          title: title,
        );
      } catch (_) {}
    }
  }

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

  void editTranscriptSegment(int index, String newText) {
    if (index < 0 || index >= state.segments.length) return;
    final edited = [...state.segments];
    edited[index] = edited[index].copyWith(text: newText);
    state = state.copyWith(segments: edited);
  }

  void renameSpeaker(String oldLabel, String newLabel) {
    state = state.copyWith(
      segments: state.segments
          .map((s) => s.speaker == oldLabel ? s.copyWith(speaker: newLabel) : s)
          .toList(),
    );
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
    final (mic, speaker) = settings.defaultMode.defaultToggles;
    // HPT: quick pass uses the default model; refine pass always targets
    // large-v3-turbo-q5 when progressive is enabled (and the quick model
    // is not itself the q5 — HPT only makes sense quick≠refine).
    final quickPath = modelPathForId(
      settings.defaultModel,
      libraryPath: settings.libraryPath,
    );
    final refinePath = settings.progressiveEnabled &&
            settings.defaultModel != 'large-v3-turbo-q5' &&
            isModelAvailable('large-v3-turbo-q5',
                libraryPath: settings.libraryPath)
        ? modelPathForId('large-v3-turbo-q5',
            libraryPath: settings.libraryPath)
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
      ),
    );
  }

  void setTitle(String title) {
    state = state.copyWith(sessionTitle: title);
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

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionUiState>((
  ref,
) {
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
  return notifier;
});
