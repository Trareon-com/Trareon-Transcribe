/// F16 bagian B: auto-stop saat rapat sudah sunyi berkepanjangan.
///
/// Reuses the VU-level stream the audio watchdog already listens to
/// ([AudioWatchdogNotifier] in `audio_watchdog_model.dart`) rather than
/// writing a new silence detector — both mic and system-audio levels are
/// already surfaced per chunk via `LiveEvent::Vu` → `SessionEvent::Vu` →
/// `RustBridge.vuMeterStream`. A warning is always shown first ("Lanjutkan"
/// or auto-stop in one more minute); the session is never stopped silently,
/// since a long pause in speech is not the same as a meeting that has
/// ended.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/flight_recorder_service.dart';
import 'models.dart';
import 'session_model.dart';
import 'settings_model.dart';

/// How often the elapsed-silence check runs. Independent of the warning's
/// own grace period below.
const _checkInterval = Duration(seconds: 10);

/// How long after the warning appears the session auto-stops if the user
/// does not tap "Lanjutkan" and no sound resumes on its own.
const silenceAutoStopGrace = Duration(minutes: 1);

/// Signal level above which a VU sample counts as "someone is speaking" —
/// matches the audio watchdog's own epsilon for the same reason: real
/// speech reads well above the capture noise floor.
const _speechEpsilon = 0.02;

/// Shown while a recording session has produced no audio signal (mic nor
/// system) for the configured threshold. `autoStopAt` is when the session
/// will be stopped automatically unless the user taps "Lanjutkan" or sound
/// resumes before then.
class SilenceAutoStopWarning {
  const SilenceAutoStopWarning(this.silentMinutes, this.autoStopAt);

  final int silentMinutes;
  final DateTime autoStopAt;
}

class SilenceAutoStopNotifier extends StateNotifier<SilenceAutoStopWarning?> {
  SilenceAutoStopNotifier(this._ref, {DateTime Function()? now})
    : super(null) {
    if (now != null) _now = now;
    _ref.listen<SessionUiState>(
      sessionProvider,
      _onSessionChanged,
      fireImmediately: true,
    );
  }

  final Ref _ref;
  DateTime Function() _now = DateTime.now;

  StreamSubscription<VuLevel>? _vuSub;
  Timer? _checkTimer;
  Timer? _graceTimer;
  String? _watchedSessionId;
  DateTime? _lastSpeechAt;

  void _onSessionChanged(SessionUiState? previous, SessionUiState next) {
    final isRecording = next.lifecycle == SessionLifecycle.recording;
    if (isRecording && next.sessionId != _watchedSessionId) {
      _startWatching(next.sessionId!);
    } else if (!isRecording) {
      _stopWatching();
    }
  }

  void _startWatching(String sessionId) {
    _stopWatching();
    _watchedSessionId = sessionId;
    _lastSpeechAt = _now();
    state = null;

    final bridge = _ref.read(rustBridgeProvider);
    _vuSub = bridge.vuMeterStream(sessionId).listen((vu) {
      if (vu.micLevel > _speechEpsilon || vu.speakerLevel > _speechEpsilon) {
        _lastSpeechAt = _now();
        // Sound resumed on its own — the warning no longer applies; a
        // pause in speech is not the same thing as a meeting that ended.
        if (state != null) _clearWarning();
      }
    });

    _checkTimer = Timer.periodic(_checkInterval, (_) => _checkSilence());
  }

  void _checkSilence() {
    final current = _ref.read(sessionProvider);
    if (current.sessionId != _watchedSessionId ||
        current.lifecycle != SessionLifecycle.recording) {
      return;
    }
    if (state != null) return; // already warning; grace timer owns this.
    final thresholdMinutes = _ref.read(settingsProvider).silenceAutoStopMinutes;
    if (thresholdMinutes == null || thresholdMinutes <= 0) return;
    final lastSpeechAt = _lastSpeechAt;
    if (lastSpeechAt == null) return;
    final silentFor = _now().difference(lastSpeechAt);
    if (silentFor < Duration(minutes: thresholdMinutes)) return;

    final autoStopAt = _now().add(silenceAutoStopGrace);
    state = SilenceAutoStopWarning(thresholdMinutes, autoStopAt);
    _graceTimer = Timer(silenceAutoStopGrace, () => _autoStop(thresholdMinutes));
  }

  Future<void> _autoStop(int silentMinutes) async {
    final sessionId = _watchedSessionId;
    final current = _ref.read(sessionProvider);
    if (sessionId == null ||
        current.sessionId != sessionId ||
        current.lifecycle != SessionLifecycle.recording) {
      return;
    }
    await FlightRecorder.instance.logAutoStopSilence(sessionId, silentMinutes);
    try {
      await _ref.read(sessionProvider.notifier).stop();
    } catch (_) {
      // Best effort: the session may already be stopping via another path
      // (user tapped Stop at the same moment the grace period expired).
    }
    _clearWarning();
  }

  /// Called by the UI's "Lanjutkan" button: the meeting is still going,
  /// just quiet — reset the clock instead of stopping.
  void continueRecording() {
    _lastSpeechAt = _now();
    _clearWarning();
  }

  void _clearWarning() {
    _graceTimer?.cancel();
    _graceTimer = null;
    state = null;
  }

  void _stopWatching() {
    _vuSub?.cancel();
    _vuSub = null;
    _checkTimer?.cancel();
    _checkTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _watchedSessionId = null;
    _lastSpeechAt = null;
    state = null;
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }
}

final silenceAutoStopProvider =
    StateNotifierProvider<SilenceAutoStopNotifier, SilenceAutoStopWarning?>((
      ref,
    ) {
      return SilenceAutoStopNotifier(ref);
    });
