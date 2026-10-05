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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_tokens.dart';
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

/// Applies the window's geometry and chrome before the first frame.
///
/// Every call is individually guarded: a window manager that refuses a hint
/// (a tiling WM on Linux, a remote session on Windows) must not stop the app
/// from launching. The layout is merely croppable then, not broken.
Future<void> configureWindow() async {
  if (!isDesktop) return;
  try {
    await windowManager.ensureInitialized();
  } catch (_) {
    return;
  }

  await _guard(() => windowManager.setMinimumSize(WindowSizes.minimum));

  // macOS: hide the title bar so the sidebar runs to the top edge under the
  // traffic lights, the way every native-feeling Mac app does. Windows: hide
  // the whole caption bar; WindowsTitleBar draws its own.
  if (Platform.isMacOS) {
    await _guard(
      () => windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: true,
      ),
    );
  } else if (Platform.isWindows) {
    await _guard(
      () => windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
    );
  }

  final restored = await _restoreGeometry();
  if (!restored) {
    await _guard(() => windowManager.setSize(WindowSizes.defaultSize));
    await _guard(() => windowManager.center());
  }
  await _guard(() => windowManager.show());
}

/// Reads the saved geometry and applies it. Returns false when there is
/// nothing saved, or when what was saved is no longer usable.
Future<bool> _restoreGeometry() async {
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
  await _guard(() => windowManager.setSize(size));

  final x = prefs.getDouble(_kWindowX);
  final y = prefs.getDouble(_kWindowY);
  // A saved position from a monitor that is no longer attached would put the
  // window off screen with no way to reach it, so anything negative past a
  // small tolerance falls back to centring.
  if (x != null && y != null && x > -64 && y > -64) {
    await _guard(() => windowManager.setPosition(Offset(x, y)));
  } else {
    await _guard(() => windowManager.center());
  }

  if (prefs.getBool(_kWindowMaximized) ?? false) {
    await _guard(() => windowManager.maximize());
  }
  return true;
}

Future<void> _guard(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    // See the note on configureWindow.
  }
}

/// Saves the window's geometry whenever the user finishes moving or resizing
/// it. Install once, at the root of the app.
class WindowGeometryRecorder with WindowListener {
  WindowGeometryRecorder._();

  static final WindowGeometryRecorder instance = WindowGeometryRecorder._();

  bool _installed = false;

  void install() {
    if (_installed || !isDesktop) return;
    _installed = true;
    windowManager.addListener(this);
  }

  void dispose() {
    if (!_installed) return;
    _installed = false;
    windowManager.removeListener(this);
  }

  @override
  void onWindowResized() => _save();

  @override
  void onWindowMoved() => _save();

  @override
  void onWindowMaximize() => _saveMaximized(true);

  @override
  void onWindowUnmaximize() => _saveMaximized(false);

  Future<void> _saveMaximized(bool value) async {
    DartPrefs.instance.setBool(_kWindowMaximized, value);
    await DartPrefs.instance.save();
  }

  /// Writes the current bounds. A maximized window's bounds are the screen's,
  /// so they are deliberately not recorded: restoring them would make
  /// un-maximizing a no-op.
  Future<void> _save() async {
    try {
      if (await windowManager.isMaximized()) return;
      final bounds = await windowManager.getBounds();
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
