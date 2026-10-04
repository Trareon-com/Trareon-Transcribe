/// Platform window chrome. `docs/DESIGN-SYSTEM.md` §9.
///
/// macOS hides its title bar and lets the sidebar run under the traffic
/// lights; Windows draws its own caption bar with real minimise / maximise /
/// close buttons; Linux keeps the GTK client-side decorations the desktop
/// already provides. The point is that the owner's side-by-side test of the
/// same build on a MacBook and a Windows laptop reads as two native apps
/// rather than one toolkit.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../services/window_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Overridable so widget tests and goldens can pin each platform's chrome
/// without running on that platform.
@visibleForTesting
TargetPlatform? debugChromePlatformOverride;

TargetPlatform get _platform {
  final override = debugChromePlatformOverride;
  if (override != null) return override;
  if (kIsWeb) return TargetPlatform.linux;
  if (Platform.isMacOS) return TargetPlatform.macOS;
  if (Platform.isWindows) return TargetPlatform.windows;
  return TargetPlatform.linux;
}

/// A strip that drags the window, and double-click-to-maximise.
///
/// Both platforms with a hidden title bar need this: without it a window with
/// no caption bar cannot be moved at all, which is the classic way a custom
/// title bar ships broken.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !isDesktop || _platform == TargetPlatform.linux) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: child,
    );
  }
}

/// The reserved strip at the top of the sidebar.
///
/// On macOS it leaves room for the traffic lights, which now float over the
/// app's own surface; on Windows it is only a drag handle, because the caption
/// buttons live at the top right in [WindowsCaptionButtons]; on Linux it
/// collapses to nothing, because GTK still draws a real title bar.
class WindowTopInset extends StatelessWidget {
  const WindowTopInset({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return const SizedBox.shrink();
    return switch (_platform) {
      TargetPlatform.macOS => const WindowDragArea(
        child: SizedBox(
          height: WindowChrome.dragStripHeight,
          width: double.infinity,
        ),
      ),
      TargetPlatform.windows => const WindowDragArea(
        child: SizedBox(
          height: WindowChrome.dragStripHeight,
          width: double.infinity,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Windows caption buttons: minimise, maximise/restore, close.
///
/// Drawn to the Windows 11 metrics (46x32, close turns red on hover) so snap
/// layouts and muscle memory both still work. `window_manager` keeps the
/// system's snap-layout flyout attached to the maximise button as long as the
/// window itself is a normal top-level window, which it is.
class WindowsCaptionButtons extends StatelessWidget {
  const WindowsCaptionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isDesktop || _platform != TargetPlatform.windows) {
      return const SizedBox.shrink();
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptionButton(
          icon: AppIcons.minimize,
          tooltip: 'Perkecil',
          action: _CaptionAction.minimize,
        ),
        _CaptionButton(
          icon: AppIcons.maximize,
          tooltip: 'Perbesar',
          action: _CaptionAction.maximize,
        ),
        _CaptionButton(
          icon: AppIcons.close,
          tooltip: 'Tutup',
          action: _CaptionAction.close,
          danger: true,
        ),
      ],
    );
  }
}

enum _CaptionAction { minimize, maximize, close }

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.action,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final _CaptionAction action;
  final bool danger;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;

  Future<void> _run() async {
    switch (widget.action) {
      case _CaptionAction.minimize:
        await windowManager.minimize();
      case _CaptionAction.maximize:
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      case _CaptionAction.close:
        await windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final bg = !_hovered
        ? Colors.transparent
        : widget.danger
        ? colors.error
        : colors.hoverOverlay;
    final fg = _hovered && widget.danger ? colors.onError : colors.icon;
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _run,
            child: AnimatedContainer(
              duration: motion.fast,
              curve: AppEasing.standard,
              width: WindowChrome.captionButtonWidth,
              height: WindowChrome.captionBarHeight,
              color: bg,
              child: Icon(widget.icon, size: IconSizes.sm, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// The macOS menu bar. Declared from the one shortcut table, so a menu item
/// and the binding it claims cannot disagree.
///
/// On Windows and Linux this is a pass-through: neither platform puts an
/// application menu outside the window, and a fake one inside it would be a
/// second place to hunt for the same five actions.
class AppPlatformMenuBar extends StatelessWidget {
  const AppPlatformMenuBar({
    super.key,
    required this.child,
    required this.onNewSession,
    required this.onToggleRecording,
    required this.onOpenSettings,
    required this.onFocusSearch,
    required this.onToggleSidebar,
    required this.onShowShortcuts,
  });

  final Widget child;
  final VoidCallback onNewSession;
  final VoidCallback onToggleRecording;
  final VoidCallback onOpenSettings;
  final VoidCallback onFocusSearch;
  final VoidCallback onToggleSidebar;
  final VoidCallback onShowShortcuts;

  @override
  Widget build(BuildContext context) {
    if (_platform != TargetPlatform.macOS) return child;
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Berkas',
          menus: [
            PlatformMenuItem(label: 'Sesi Baru', onSelected: onNewSession),
            PlatformMenuItem(
              label: 'Mulai atau Berhenti Merekam',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyR,
                meta: true,
              ),
              onSelected: onToggleRecording,
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.servicesSubmenu,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Tampilan',
          menus: [
            PlatformMenuItem(
              label: 'Cari di Riwayat Sesi',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyL,
                meta: true,
              ),
              onSelected: onFocusSearch,
            ),
            PlatformMenuItem(
              label: 'Sembunyikan Sidebar',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: true,
                shift: true,
              ),
              onSelected: onToggleSidebar,
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Jendela',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Bantuan',
          menus: [
            PlatformMenuItem(
              label: 'Pintasan Keyboard',
              onSelected: onShowShortcuts,
            ),
            PlatformMenuItem(label: 'Pengaturan', onSelected: onOpenSettings),
          ],
        ),
      ],
      child: child,
    );
  }
}
