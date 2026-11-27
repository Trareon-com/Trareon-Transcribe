/// The app's one native window, through window_manager's nativeapi surface
/// (issue #67).
///
/// Replaces the `WindowManager.instance` singleton of `legacy.dart`, which
/// looked the window up on every call. Here it is looked up once and kept.
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:window_manager/window_manager.dart';

Window? _window;

/// The app window, or `null` while the platform does not report one yet.
///
/// nativeapi's `getCurrent()` answers "the window the platform considers
/// current". On Windows that is the *active* window, and the runner keeps
/// the app's window hidden until Flutter's first frame
/// (`windows/runner/flutter_window.cpp`), so before then there may be none;
/// a single-window app's only window is the same answer.
Window? appWindow() {
  final cached = _window;
  if (cached != null) return cached;
  try {
    final manager = WindowManager.instance;
    final found = manager.getCurrent() ?? _sole(manager.getAll());
    if (found != null) _window = found;
    return found;
  } catch (_) {
    // No native window layer (a headless test, an unsupported platform).
    return null;
  }
}

Window? _sole(List<Window> windows) =>
    windows.length == 1 ? windows.single : null;

/// [appWindow], waiting up to [timeout] for it to appear: once right away,
/// then after each frame (the Windows runner shows its window on the first
/// one) and at short intervals in between.
Future<Window?> waitForAppWindow({
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final window = appWindow();
    if (window != null) return window;
    if (DateTime.now().isAfter(deadline)) return null;
    await Future.any([
      SchedulerBinding.instance.endOfFrame,
      Future<void>.delayed(const Duration(milliseconds: 50)),
    ]);
  }
}
