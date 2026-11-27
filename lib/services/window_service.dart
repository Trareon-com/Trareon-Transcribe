/// Window geometry and platform chrome. `docs/DESIGN-SYSTEM.md` §4.5 and §9.
///
/// Three jobs, all of which used to be missing or wrong:
///
/// 1. The window opens at a sensible size (1280x800) instead of whatever the
///    toolkit picks, and cannot be dragged below 900x600, which is the
///    smallest geometry every layout in the app is designed to survive.
/// 2. The size and position are remembered across launches. Re-dragging the
///    window to the same place on every launch is the kind of friction a user
///    notices every single day.
/// 3. On macOS the title bar is hidden so content runs under the traffic
///    lights, and on Windows the native caption bar is replaced by one the app
///    draws, so both look like the platform rather than like Flutter.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_tokens.dart';
import 'app_window.dart';
import 'dart_prefs.dart';

/// Keys in `dart_prefs.json`.
const _kWindowWidth = 'window.width';
const _kWindowHeight = 'window.height';
const _kWindowX = 'window.x';
const _kWindowY = 'window.y';
const _kWindowMaximized = 'window.maximized';

/// True on the desktop platforms `window_manager` supports.
bool get isDesktop =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

/// Reserved at the top of the window for dragging and, on macOS, for the
/// traffic lights that now sit over the app's own content.
abstract final class WindowChrome {
  /// Height of the draggable strip at the top of the sidebar.
  static const double dragStripHeight = ControlSizes.md;

  /// How far in the macOS traffic lights sit. Content below the strip is
  /// clear of them; content inside it must leave this much room on the left.
  static const double trafficLightsInset = 78;

  /// Width of one Windows caption button, per the Windows 11 metrics.
  static const double captionButtonWidth = 46;

  /// Height of the Windows caption bar.
  static const double captionBarHeight = ControlSizes.md;
}

/// Applies the window's geometry and chrome, before the first frame where
/// the platform already reports the window.
///
/// On Windows the runner keeps the window hidden until Flutter's first
/// frame, and nativeapi may not report it until then; waiting for it here,
/// before `runApp`, would wait for a frame that cannot come. So when there
/// is no window yet, the same setup runs as soon as one appears.
///
/// Every step is individually guarded: a window manager that refuses a hint
/// (a tiling WM on Linux, a remote session on Windows) must not stop the app
/// from launching. The layout is merely croppable then, not broken.
Future<void> configureWindow() async {
  if (!isDesktop) return;
  final window = appWindow();
  if (window != null) {
    await _configure(window);
    return;
  }
  unawaited(
    waitForAppWindow(timeout: const Duration(seconds: 10)).then((found) async {
      if (found != null) await _configure(found);
    }),
  );
}

Future<void> _configure(Window window) async {
  _guard(() => window.minimumSize = WindowSizes.minimum.toNative());

  // macOS: hide the title bar so the sidebar runs to the top edge under the
  // traffic lights, the way every native-feeling Mac app does. Windows: hide
  // the whole caption bar; WindowsTitleBar draws its own.
  if (Platform.isMacOS) {
    _guard(() {
      window.titleBarStyle = TitleBarStyle.hidden;
      window.isWindowControlButtonsVisible = true;
    });
  } else if (Platform.isWindows) {
    _guard(() {
      window.titleBarStyle = TitleBarStyle.hidden;
      window.isWindowControlButtonsVisible = false;
    });
  }

  final restored = await _restoreGeometry(window);
  if (!restored) {
    _guard(() => window.setSize(WindowSizes.defaultSize.toNative(), false));
    _guard(window.center);
  }
  _guard(() {
    if (window.isMinimized) window.restore();
    window.show();
  });
}

/// Reads the saved geometry and applies it. Returns false when there is
/// nothing saved, or when what was saved is no longer usable.
Future<bool> _restoreGeometry(Window window) async {
  try {
    await DartPrefs.instance.load();
  } catch (_) {
    return false;
  }
  final prefs = DartPrefs.instance;
  final width = prefs.getDouble(_kWindowWidth);
  final height = prefs.getDouble(_kWindowHeight);
  if (width == null || height == null) return false;

  final size = Size(
    width.clamp(WindowSizes.minimum.width, 10000),
    height.clamp(WindowSizes.minimum.height, 10000),
  );
  _guard(() => window.setSize(size.toNative(), false));

  final x = prefs.getDouble(_kWindowX);
  final y = prefs.getDouble(_kWindowY);
  // A saved position from a monitor that is no longer attached would put the
  // window off screen with no way to reach it, so anything negative past a
  // small tolerance falls back to centring.
  if (x != null && y != null && x > -64 && y > -64) {
    _guard(() => window.position = Offset(x, y).toNative());
  } else {
    _guard(window.center);
  }

  if (prefs.getBool(_kWindowMaximized) ?? false) {
    _guard(window.maximize);
  }
  return true;
}

void _guard(void Function() action) {
  try {
    action();
  } catch (_) {
    // See the note on configureWindow.
  }
}

/// Saves the window's geometry whenever the user finishes moving or resizing
/// it. Install once, at the root of the app.
class WindowGeometryRecorder {
  WindowGeometryRecorder._();

  static final WindowGeometryRecorder instance = WindowGeometryRecorder._();

  Window? _window;
  ListenerId? _listener;
  bool _installing = false;

  /// Starts listening once the window exists (see [configureWindow] for why
  /// it may not yet).
  void install() {
    if (_listener != null || _installing || !isDesktop) return;
    _installing = true;
    unawaited(
      waitForAppWindow(timeout: const Duration(seconds: 10)).then((window) {
        _installing = false;
        if (window == null || _listener != null) return;
        _window = window;
        _listener = window.addListener(_onEvent);
      }),
    );
  }

  void dispose() {
    final listener = _listener;
    if (listener == null) return;
    _window?.removeListener(listener);
    _listener = null;
  }

  void _onEvent(WindowEvent event) {
    switch (event) {
      case WindowResizedEvent() || WindowMovedEvent():
        _save();
      case WindowMaximizedEvent():
        _saveMaximized(true);
      // Restoring may mean leaving maximized or leaving minimized back into
      // maximized; the window knows which.
      case WindowRestoredEvent():
        _saveMaximized(_window?.isMaximized ?? false);
      default:
        break;
    }
  }

  Future<void> _saveMaximized(bool value) async {
    DartPrefs.instance.setBool(_kWindowMaximized, value);
    await DartPrefs.instance.save();
  }

  /// Writes the current bounds. A maximized window's bounds are the screen's,
  /// so they are deliberately not recorded: restoring them would make
  /// un-maximizing a no-op.
  Future<void> _save() async {
    final window = _window;
    if (window == null) return;
    try {
      if (window.isMaximized) return;
      final bounds = window.bounds.toRect();
      final prefs = DartPrefs.instance;
      prefs.setDouble(_kWindowWidth, bounds.width);
      prefs.setDouble(_kWindowHeight, bounds.height);
      prefs.setDouble(_kWindowX, bounds.left);
      prefs.setDouble(_kWindowY, bounds.top);
      await prefs.save();
    } catch (_) {
      // Geometry is a convenience; a failure here must not surface.
    }
  }
}
