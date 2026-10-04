/// Every keyboard shortcut the app binds, declared once.
///
/// The hint the user sees ([AppShortcut]), the macOS menu-bar item and the
/// actual `SingleActivator` binding are all derived from the same row here, so
/// they cannot drift apart. Before this file the main screen bound Ctrl+B and
/// the shortcuts panel said Ctrl+B in a hand-written string, which is exactly
/// how a shortcut ends up documented but unbound.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../widgets/ui/key_hint.dart';

/// One action: its Indonesian label, its hint, and the two activators that
/// trigger it (Command on macOS, Control everywhere else).
class AppAction {
  const AppAction({
    required this.id,
    required this.label,
    required this.shortcut,
    required this.logicalKey,
    this.shift = false,
    this.alt = false,
  });

  final String id;

  /// What the action is called, in Bahasa Indonesia, everywhere it appears.
  final String label;

  final AppShortcut shortcut;
  final LogicalKeyboardKey logicalKey;
  final bool shift;
  final bool alt;

  /// Both platform activators. Binding the Control variant on macOS as well is
  /// deliberate: an external PC keyboard on a Mac is common in these offices.
  List<SingleActivator> get activators => [
    SingleActivator(logicalKey, meta: true, shift: shift, alt: alt),
    SingleActivator(logicalKey, control: true, shift: shift, alt: alt),
  ];
}

abstract final class AppShortcuts {
  static const startStop = AppAction(
    id: 'start-stop',
    label: 'Mulai atau berhenti merekam',
    shortcut: AppShortcut('R', primary: true),
    logicalKey: LogicalKeyboardKey.keyR,
  );

  static const pauseResume = AppAction(
    id: 'pause-resume',
    label: 'Jeda atau lanjutkan',
    shortcut: AppShortcut('P', primary: true),
    logicalKey: LogicalKeyboardKey.keyP,
  );

  static const searchSessions = AppAction(
    id: 'search-sessions',
    label: 'Cari di riwayat sesi',
    shortcut: AppShortcut('L', primary: true),
    logicalKey: LogicalKeyboardKey.keyL,
  );

  static const bookmark = AppAction(
    id: 'bookmark',
    label: 'Tandai poin penting',
    shortcut: AppShortcut('B', primary: true),
    logicalKey: LogicalKeyboardKey.keyB,
  );

  static const settings = AppAction(
    id: 'settings',
    label: 'Buka Pengaturan',
    shortcut: AppShortcut(',', primary: true),
    logicalKey: LogicalKeyboardKey.comma,
  );

  static const shortcutsPanel = AppAction(
    id: 'shortcuts',
    label: 'Tampilkan pintasan keyboard',
    shortcut: AppShortcut('/', primary: true),
    logicalKey: LogicalKeyboardKey.slash,
  );

  static const toggleSidebar = AppAction(
    id: 'toggle-sidebar',
    label: 'Sembunyikan atau tampilkan sidebar',
    shortcut: AppShortcut('S', primary: true, shift: true),
    logicalKey: LogicalKeyboardKey.keyS,
    shift: true,
  );

  /// The full list, in the order the shortcuts panel shows them.
  static const List<AppAction> all = [
    startStop,
    pauseResume,
    bookmark,
    searchSessions,
    toggleSidebar,
    settings,
    shortcutsPanel,
  ];
}
