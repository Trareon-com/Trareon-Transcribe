import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Minimize-to-tray (PRD: "Minimize-to-tray menjaga transkrip berjalan
/// background"). Closing the window hides it instead of quitting the
/// process, so a live transcription session keeps running; the tray
/// icon's context menu is the only way to actually quit.
class TrayService with TrayListener, WindowListener {
  static final TrayService instance = TrayService._();
  TrayService._();

  bool _initialized = false;

  /// Asked before the tray's "Keluar" actually quits. Returning false
  /// aborts the quit.
  ///
  /// Set by the main screen, which is the only thing with both a
  /// `BuildContext` and knowledge of what is still running. The app can
  /// have a background transcript-completion pass in flight (ITEM 0) that
  /// takes an hour on a weak CPU; quitting through it is allowed, but it
  /// has to be a decision rather than an accident.
  Future<bool> Function()? confirmQuit;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await windowManager.ensureInitialized();
      // macOS secure state restoration restores the saved (possibly
      // off-screen) window frame after launch. Poll for the first
      // seconds of runtime and recenter whenever the frame lands
      // outside the visible area (restoration can settle late).
      _watchWindowFrame();
      await windowManager.setPreventClose(true);
      windowManager.addListener(this);

      final iconPath = Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png';
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('Trareon Transcribe');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: 'Buka Trareon Transcribe'),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: 'Keluar'),
          ],
        ),
      );
      trayManager.addListener(this);
    } catch (e) {
      // Tray not available in headless/Xvfb environments — skip silently.
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
      case 'quit':
        final confirm = confirmQuit;
        if (confirm != null) {
          // The dialog lives in the window, so it has to be visible for
          // the user to answer it.
          await _showWindow();
          if (!await confirm()) return;
        }
        await windowManager.setPreventClose(false);
        await windowManager.close();
    }
  }

  @override
  void onWindowClose() async {
    final preventClose = await windowManager.isPreventClose();
    if (preventClose) {
      await windowManager.hide();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Keeps the window on a visible display.
  ///
  /// macOS may restore a saved (possibly off-screen) frame at launch AND
  /// again when the window is re-shown from the dock/tray, defeating
  /// single-shot centering. We recenter whenever the frame ends up with
  /// no visible intersection on the primary display — both via the
  /// window-moved event and a short launch-time poll.
  void _watchWindowFrame() {
    var checks = 0;
    Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      checks++;
      if (checks > 10) {
        timer.cancel();
        return;
      }
      await _recenterIfOffScreen();
    });
  }

  @override
  void onWindowMoved() {
    _recenterIfOffScreen();
  }

  Future<void> _recenterIfOffScreen() async {
    try {
      final primary = await screenRetriever.getPrimaryDisplay();
      final vp = primary.visiblePosition ?? const Offset(0, 0);
      final vs = primary.visibleSize ?? primary.size;
      final bounds = await windowManager.getBounds();
      final intersects = bounds.left < vp.dx + vs.width &&
          bounds.top < vp.dy + vs.height &&
          bounds.left + bounds.width > vp.dx &&
          bounds.top + bounds.height > vp.dy;
      if (!intersects) {
        final size = await windowManager.getSize();
        final dx = vp.dx + ((vs.width - size.width) / 2);
        final dy = vp.dy + ((vs.height - size.height) / 2);
        await windowManager.setPosition(Offset(dx, dy));
      }
    } catch (_) {
      // Window not ready yet — keep polling.
    }
  }
}
