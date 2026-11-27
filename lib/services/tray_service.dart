import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart' hide ListenerId;

import '../l10n/l10n.dart';
import 'app_window.dart';

/// Minimize-to-tray (PRD: "Minimize-to-tray menjaga transkrip berjalan
/// background"). Closing the window hides it instead of quitting the
/// process, so a live transcription session keeps running; the tray
/// icon's context menu is the only way to actually quit.
///
/// Built on window_manager's and tray_manager's nativeapi surface (#67):
/// a [TrayIcon] with a native [Menu], and a close-request listener on the
/// app [Window] in place of `setPreventClose`.
class TrayService {
  static final TrayService instance = TrayService._();
  TrayService._();

  bool _initialized = false;

  /// True only while quitting from the tray menu: lets the close request
  /// through instead of turning it into a hide.
  bool _quitting = false;

  TrayIcon? _trayIcon;
  Menu? _menu;
  MenuItem? _showItem;
  MenuItem? _quitItem;
  Window? _window;
  final List<void Function()> _unlisten = [];

  /// The language the menu labels were last built in, so a language change
  /// in Settings relabels the menu (it is created before `runApp`, when
  /// only the Indonesian fallback exists).
  String? _labelsLocale;

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
      _createTray();
    } catch (_) {
      // Tray not available in headless/Xvfb environments — skip silently.
    }
    // The window may not exist yet on Windows (see app_window.dart); the
    // tray works without it, and the close and frame handling attach as
    // soon as it appears.
    unawaited(
      waitForAppWindow(
        timeout: const Duration(seconds: 10),
      ).then((window) => window == null ? null : _attachWindow(window)),
    );
  }

  void _createTray() {
    final trayIcon = TrayIcon.create();
    if (trayIcon == null) return;
    final iconPath = Platform.isWindows
        ? 'assets/tray_icon.ico'
        : 'assets/tray_icon.png';
    trayIcon.icon = ImageAsset.fromAsset(iconPath);

    final menu = Menu.create();
    final showItem = MenuItem.createWithLabelAndType('', MenuItemType.normal);
    final quitItem = MenuItem.createWithLabelAndType('', MenuItemType.normal);
    if (menu != null && showItem != null && quitItem != null) {
      final showId = showItem.addListener((event) {
        if (event is MenuItemClickedEvent) _showWindow();
      });
      final quitId = quitItem.addListener((event) {
        if (event is MenuItemClickedEvent) _quitFromTray();
      });
      _unlisten
        ..add(() => showItem.removeListener(showId))
        ..add(() => quitItem.removeListener(quitId));
      menu
        ..addItem(showItem)
        ..addSeparator()
        ..addItem(quitItem);
      trayIcon.setContextMenu(menu);
      // The native default is no trigger at all. The legacy bridge only set
      // one on Linux, and this app never called popUpContextMenu, so on
      // macOS and Windows the "Keluar" menu could not be opened from the
      // tray; right-click opens it everywhere now.
      trayIcon.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
    }

    final trayId = trayIcon.addListener((event) {
      if (event is TrayIconClickedEvent) _showWindow();
    });
    _unlisten.add(() => trayIcon.removeListener(trayId));
    trayIcon.setVisible(true);

    _trayIcon = trayIcon;
    _menu = menu;
    _showItem = showItem;
    _quitItem = quitItem;
    updateLabels(currentL10n);
  }

  /// Sets the tooltip and menu labels in [l10n]'s language. Cheap to call on
  /// every rebuild: it only touches the native objects when the language
  /// actually changed.
  void updateLabels(AppLocalizations l10n) {
    if (_trayIcon == null || _labelsLocale == l10n.localeName) return;
    _labelsLocale = l10n.localeName;
    try {
      _trayIcon?.setTooltip(l10n.appTitle);
      _showItem?.label = l10n.trayServiceOpen;
      _quitItem?.label = l10n.trayServiceQuit;
    } catch (_) {
      // A tray that refuses a label keeps the old one.
    }
  }

  void _attachWindow(Window window) {
    _window = window;
    // Closing the window (title bar, Cmd+W) hides it to the tray instead;
    // only "Keluar" in the tray menu lets the close through.
    final id = window.addListener((event) {
      switch (event) {
        case WindowCloseRequestedEvent(:final request):
          if (_quitting) return;
          request.cancel();
          window.hide();
        case WindowMovedEvent():
          _recenterIfOffScreen();
        default:
          break;
      }
    });
    _unlisten.add(() => window.removeListener(id));
    // macOS secure state restoration restores the saved (possibly
    // off-screen) window frame after launch. Poll for the first
    // seconds of runtime and recenter whenever the frame lands
    // outside the visible area (restoration can settle late).
    _watchWindowFrame();
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    for (final unlisten in _unlisten) {
      try {
        unlisten();
      } catch (_) {}
    }
    _unlisten.clear();
    _trayIcon?.dispose();
    _menu?.dispose();
    _trayIcon = null;
    _menu = null;
  }

  Future<void> _quitFromTray() async {
    final confirm = confirmQuit;
    if (confirm != null) {
      // The dialog lives in the window, so it has to be visible for the
      // user to answer it.
      await _showWindow();
      if (!await confirm()) return;
    }
    final window = _window ?? appWindow();
    if (window == null) {
      exit(0);
    }
    _quitting = true;
    // Closing the last window ends the app on every platform here
    // (macOS: applicationShouldTerminateAfterLastWindowClosed).
    if (!Window.isCloseSupported() || !window.close()) {
      exit(0);
    }
  }

  Future<void> _showWindow() async {
    final window = _window ?? appWindow();
    if (window == null) return;
    try {
      if (window.isMinimized) window.restore();
      window.show();
      window.focus();
    } catch (_) {}
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
    Timer.periodic(const Duration(milliseconds: 800), (timer) {
      checks++;
      if (checks > 10) {
        timer.cancel();
        return;
      }
      _recenterIfOffScreen();
    });
  }

  void _recenterIfOffScreen() {
    final window = _window;
    if (window == null) return;
    try {
      final primary = DisplayManager.instance.getPrimary();
      if (primary == null) return;
      final visible = primary.workArea.toRect();
      final bounds = window.bounds.toRect();
      if (!bounds.overlaps(visible)) {
        final dx = visible.left + (visible.width - bounds.width) / 2;
        final dy = visible.top + (visible.height - bounds.height) / 2;
        window.position = Offset(dx, dy).toNative();
      }
    } catch (_) {
      // Window not ready yet — keep polling.
    }
  }
}
