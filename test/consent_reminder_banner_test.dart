/// Sprint 13 E1: the pre-recording consent reminder banner. The audit
/// acknowledgement itself (`acknowledgeConsent`) is a Rust-side function
/// tested in `rust_core/src/pdp/mod.rs`; what this covers is the part that
/// only exists here — whether the banner shows, and that dismissing it
/// persists through `AppSettings.consentBannerDismissed`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/widgets/session_controls.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('shows the reminder when the banner has not been dismissed', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(NoopBridge()),
          ),
        ],
        child: const Scaffold(body: ConsentReminderBanner()),
      ),
    );
    await tester.pump();

    expect(
      find.text('Pastikan semua peserta tahu rapat ini direkam.'),
      findsOneWidget,
    );
    expect(find.text('Jangan tampilkan lagi'), findsOneWidget);
  });

  testWidgets('hides immediately for a settings state that already '
      'dismissed it', (tester) async {
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(NoopBridge()),
          ),
        ],
        child: const Scaffold(body: ConsentReminderBanner()),
      ),
    );
    final context = tester.element(find.byType(ConsentReminderBanner));
    await ProviderScope.containerOf(
      context,
    ).read(settingsProvider.notifier).dismissConsentBanner();
    await tester.pump();

    expect(
      find.text('Pastikan semua peserta tahu rapat ini direkam.'),
      findsNothing,
    );
  });

  testWidgets('tapping "Jangan tampilkan lagi" hides the banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(NoopBridge()),
          ),
        ],
        child: const Scaffold(body: ConsentReminderBanner()),
      ),
    );
    await tester.pump();
    expect(
      find.text('Pastikan semua peserta tahu rapat ini direkam.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Jangan tampilkan lagi'));
    await tester.pump();

    expect(
      find.text('Pastikan semua peserta tahu rapat ini direkam.'),
      findsNothing,
    );
  });
}
