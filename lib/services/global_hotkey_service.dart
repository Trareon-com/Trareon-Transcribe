import 'package:flutter/services.dart';

import '../state/session_model.dart';

/// Channel for communicating with the macOS native hotkey monitor.
const _channel = MethodChannel('com.trareon.global_hotkey');

/// Handles global keyboard shortcuts (Ctrl+Shift+R, Ctrl+Shift+P) that work
/// even when the app is minimized or in the background.
///
/// macOS v1: uses [MethodChannel] to receive events forwarded from
/// [AppDelegate]'s global event monitor (addGlobalMonitorForEvents).
/// Future versions may add Windows/Linux support.
class GlobalHotkeyService {
  /// Start listening for global hotkey events from the native layer.
  ///
  /// [notifier] is the session notifier used to action start/stop/pause/resume.
  /// [lifecycle] provides the current lifecycle when a callback fires so the
  /// service can decide which action to take.
  void init(SessionNotifier notifier, SessionLifecycle Function() lifecycle) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'startStop':
          final current = lifecycle();
          if (current == SessionLifecycle.recording ||
              current == SessionLifecycle.paused) {
            await notifier.stop();
          } else {
            await notifier.start();
          }
        case 'pauseResume':
          final current = lifecycle();
          if (current == SessionLifecycle.paused) {
            notifier.resume();
          } else if (current == SessionLifecycle.recording) {
            notifier.pause();
          }
      }
    });
  }

  /// Tear down the channel handler.
  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
