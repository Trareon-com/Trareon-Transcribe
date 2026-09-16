import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'session_model.dart';
import 'settings_model.dart';

const _silenceWarningDelay = Duration(seconds: 12);
const _signalEpsilon = 0.02;

/// Warns once per recording session if neither an enabled mic nor speaker
/// channel produces any audio signal within [_silenceWarningDelay].
///
/// This is the only user-visible symptom when capture silently fails —
/// e.g. speaker capture falling back to an unconfigured BlackHole device
/// (ScreenCaptureKit permission denied/unavailable, and no Multi-Output
/// Device routing system audio into BlackHole), or a revoked microphone
/// permission. Without this, the session just sits there recording
/// nothing with zero indication anything is wrong.
class AudioWatchdogNotifier extends StateNotifier<String?> {
  AudioWatchdogNotifier(this._ref, {Duration silenceWarningDelay = _silenceWarningDelay})
      : _delay = silenceWarningDelay,
        super(null) {
    _ref.listen<SessionUiState>(sessionProvider, _onSessionChanged, fireImmediately: true);
  }

  final Ref _ref;
  final Duration _delay;
  StreamSubscription<VuLevel>? _vuSub;
  Timer? _timer;
  String? _watchedSessionId;
  bool _signalSeen = false;

  void _onSessionChanged(SessionUiState? previous, SessionUiState next) {
    final isRecording = next.lifecycle == SessionLifecycle.recording;
    if (isRecording && next.sessionId != _watchedSessionId) {
      _startWatching(next);
    } else if (!isRecording) {
      _stopWatching();
    }
  }

  void _startWatching(SessionUiState session) {
    _stopWatching();
    final sessionId = session.sessionId;
    if (sessionId == null) return;
    _watchedSessionId = sessionId;
    _signalSeen = false;
    state = null;

    final bridge = _ref.read(rustBridgeProvider);
    _vuSub = bridge.vuMeterStream(sessionId).listen((vu) {
      if (vu.micLevel > _signalEpsilon || vu.speakerLevel > _signalEpsilon) {
        _signalSeen = true;
      }
    });

    _timer = Timer(_delay, () {
      final current = _ref.read(sessionProvider);
      if (_signalSeen || current.segments.isNotEmpty) return;
      if (current.sessionId != _watchedSessionId) return;
      if (current.lifecycle != SessionLifecycle.recording) return;
      final hasEnabledSource = current.config.micEnabled || current.config.speakerEnabled;
      if (!hasEnabledSource) return;
      state =
          'Belum ada suara terdeteksi. Cek izin Mikrofon / "Rekam Layar & Audio Sistem" di System Settings, atau pastikan sumber audio yang dipilih benar.';
    });
  }

  void _stopWatching() {
    _vuSub?.cancel();
    _vuSub = null;
    _timer?.cancel();
    _timer = null;
    _watchedSessionId = null;
  }

  /// Called by the UI once the warning has been shown, so it doesn't repeat.
  void acknowledge() {
    state = null;
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }
}

final audioWatchdogProvider = StateNotifierProvider<AudioWatchdogNotifier, String?>((ref) {
  return AudioWatchdogNotifier(ref);
});
