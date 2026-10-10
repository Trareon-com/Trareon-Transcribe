import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/system_privacy_settings.dart';
import 'models.dart';
import 'session_model.dart';
import 'settings_model.dart';

const _silenceWarningDelay = Duration(seconds: 12);
const _signalEpsilon = 0.02;

/// How long to wait before judging an enabled source's signal as "exact
/// zero" rather than "quiet" (Sprint 12, B6). macOS does not throw when a
/// permission is missing — it just hands back zero-filled buffers forever —
/// so the old single 12 s timer was the only thing standing between "no mic
/// permission" and a user who thinks the app is simply broken. 3 s is long
/// enough that a genuine source takes at least one VU sample above zero
/// (frame size is well under a second) and short enough that a user who
/// forgot to grant a permission finds out before they have said anything.
const _permissionCheckDelay = Duration(seconds: 3);

/// The watchdog's warning, with an optional one-tap fix.
///
/// [permissionKind] is set only for the fast "exact zero" path, where the
/// app can name the exact missing permission; the slower generic path (a
/// quiet room, a misrouted device, anything else) cannot, so it leaves this
/// `null` and says so in the message instead.
class AudioWatchdogWarning {
  const AudioWatchdogWarning(this.message, {this.permissionKind});

  final String message;
  final PrivacyPermissionKind? permissionKind;
}

/// Warns if neither an enabled mic nor speaker channel produces any audio
/// signal — fast and specific when a source is reading back exact digital
/// silence (no OS permission granted), slower and generic otherwise.
///
/// This is the only user-visible symptom when capture silently fails —
/// e.g. speaker capture falling back to an unconfigured BlackHole device
/// (ScreenCaptureKit permission denied/unavailable, and no Multi-Output
/// Device routing system audio into BlackHole), or a revoked microphone
/// permission. Without this, the session just sits there recording
/// nothing with zero indication anything is wrong.
class AudioWatchdogNotifier extends StateNotifier<AudioWatchdogWarning?> {
  AudioWatchdogNotifier(
    this._ref, {
    Duration silenceWarningDelay = _silenceWarningDelay,
    Duration permissionCheckDelay = _permissionCheckDelay,
  }) : _delay = silenceWarningDelay,
       _permissionDelay = permissionCheckDelay,
       super(null) {
    _ref.listen<SessionUiState>(
      sessionProvider,
      _onSessionChanged,
      fireImmediately: true,
    );
  }

  final Ref _ref;
  final Duration _delay;
  final Duration _permissionDelay;
  StreamSubscription<VuLevel>? _vuSub;
  Timer? _timer;
  Timer? _permissionTimer;
  String? _watchedSessionId;
  bool _signalSeen = false;
  bool _sawAnySample = false;
  bool _micAllZero = true;
  bool _speakerAllZero = true;

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
    _sawAnySample = false;
    _micAllZero = true;
    _speakerAllZero = true;
    state = null;

    final bridge = _ref.read(rustBridgeProvider);
    _vuSub = bridge.vuMeterStream(sessionId).listen((vu) {
      _sawAnySample = true;
      if (vu.micLevel > 0.0) _micAllZero = false;
      if (vu.speakerLevel > 0.0) _speakerAllZero = false;
      if (vu.micLevel > _signalEpsilon || vu.speakerLevel > _signalEpsilon) {
        _signalSeen = true;
      }
    });

    _permissionTimer = Timer(_permissionDelay, _checkExactZero);
    _timer = Timer(_delay, _checkGenericSilence);
  }

  void _checkExactZero() {
    final current = _ref.read(sessionProvider);
    if (!_isStillTheWatchedLiveSession(current)) return;
    if (_signalSeen || !_sawAnySample) return;
    final micEnabled = current.config.micEnabled;
    final speakerEnabled = current.config.speakerEnabled;
    final micDead = micEnabled && _micAllZero;
    final speakerDead = speakerEnabled && _speakerAllZero;
    if (micDead && !speakerDead) {
      state = const AudioWatchdogWarning(
        'Mikrofon belum diberi izin, atau tidak mengirim suara sama sekali. '
        'Periksa izin Mikrofon di Pengaturan Sistem.',
        permissionKind: PrivacyPermissionKind.microphone,
      );
    } else if (speakerDead && !micDead) {
      state = const AudioWatchdogWarning(
        'Audio sistem tidak terdeteksi sama sekali. Periksa izin '
        '"Rekam Layar & Audio Sistem" di Pengaturan Sistem.',
        permissionKind: PrivacyPermissionKind.screenCapture,
      );
    } else if (micDead && speakerDead) {
      state = const AudioWatchdogWarning(
        'Mikrofon maupun audio sistem belum diberi izin. Periksa Pengaturan '
        'Sistem untuk Mikrofon dan "Rekam Layar & Audio Sistem".',
        permissionKind: PrivacyPermissionKind.microphone,
      );
    }
    // A mixed case (one source already has signal) is left to the slower
    // generic timer below, since "exact zero" is no longer the explanation.
  }

  void _checkGenericSilence() {
    final current = _ref.read(sessionProvider);
    if (!_isStillTheWatchedLiveSession(current)) return;
    if (_signalSeen || current.segments.isNotEmpty) return;
    if (state != null) return; // the fast path already explained this
    final hasEnabledSource =
        current.config.micEnabled || current.config.speakerEnabled;
    if (!hasEnabledSource) return;
    state = const AudioWatchdogWarning(
      'Belum ada suara terdeteksi. Periksa izin Mikrofon dan "Rekam Layar & '
      'Audio Sistem" di Pengaturan Sistem, atau pastikan sumber audio yang '
      'dipilih sudah benar.',
    );
  }

  bool _isStillTheWatchedLiveSession(SessionUiState current) =>
      current.sessionId == _watchedSessionId &&
      current.lifecycle == SessionLifecycle.recording;

  void _stopWatching() {
    _vuSub?.cancel();
    _vuSub = null;
    _timer?.cancel();
    _timer = null;
    _permissionTimer?.cancel();
    _permissionTimer = null;
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

final audioWatchdogProvider =
    StateNotifierProvider<AudioWatchdogNotifier, AudioWatchdogWarning?>((
      ref,
    ) {
      return AudioWatchdogNotifier(ref);
    });
