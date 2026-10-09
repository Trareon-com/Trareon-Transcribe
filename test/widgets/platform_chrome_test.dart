import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/widgets/platform_chrome.dart';

void main() {
  PlatformMenuBar findMenuBar(WidgetTester tester) =>
      tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));

  // `PlatformProvidedMenuItem.hasMenu` and the real `PlatformMenuBar`
  // consult `defaultTargetPlatform` themselves; without pinning it to
  // match the chrome override, building a macOS-shaped menu under the
  // test binding's default (android) platform throws — the same mismatch
  // A4 fixes for the app's own `_platform` getter. Both overrides are
  // reset at the end of the test body itself: the binding's end-of-test
  // invariant check runs immediately after the test closure returns and
  // before `tearDown`/`addTearDown` hooks fire, so resetting there is too
  // late.
  Future<void> pumpMenuBar(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.macOS,
  }) async {
    debugChromePlatformOverride = platform;
    debugDefaultTargetPlatformOverride = platform;
    await tester.pumpWidget(
      MaterialApp(
        home: AppPlatformMenuBar(
          onNewSession: () {},
          onToggleRecording: () {},
          onOpenSettings: () {},
          onFocusSearch: () {},
          onToggleSidebar: () {},
          onShowShortcuts: () {},
          child: const SizedBox(),
        ),
      ),
    );
  }

  void resetOverrides() {
    debugChromePlatformOverride = null;
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('on macOS the app menu is first and carries Pengaturan', (
    tester,
  ) async {
    await pumpMenuBar(tester);
    final bar = findMenuBar(tester);

    final appMenu = bar.menus.first as PlatformMenu;
    expect(appMenu.label, 'Trareon Transcribe');

    final settingsItem = appMenu.menus
        .whereType<PlatformMenuItem>()
        .firstWhere((item) => item.label == 'Pengaturan…');
    expect(
      settingsItem.shortcut,
      const SingleActivator(LogicalKeyboardKey.comma, meta: true),
    );
    resetOverrides();
  });

  testWidgets('Bantuan no longer duplicates Pengaturan', (tester) async {
    await pumpMenuBar(tester);
    final bar = findMenuBar(tester);

    final bantuan = bar.menus
        .whereType<PlatformMenu>()
        .firstWhere((menu) => menu.label == 'Bantuan');
    final labels = bantuan.menus
        .whereType<PlatformMenuItem>()
        .map((item) => item.label);
    expect(labels, isNot(contains('Pengaturan')));
    resetOverrides();
  });

  testWidgets('menu order is app menu, Berkas, Tampilan, Jendela, Bantuan', (
    tester,
  ) async {
    await pumpMenuBar(tester);
    final bar = findMenuBar(tester);
    final labels = bar.menus.whereType<PlatformMenu>().map((m) => m.label);
    expect(labels, [
      'Trareon Transcribe',
      'Berkas',
      'Tampilan',
      'Jendela',
      'Bantuan',
    ]);
    resetOverrides();
  });

  testWidgets('on a non-macOS chrome platform the menu bar is a pass-through', (
    tester,
  ) async {
    await pumpMenuBar(tester, platform: TargetPlatform.linux);
    expect(find.byType(PlatformMenuBar), findsNothing);
    resetOverrides();
  });
}
