import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transcribe/state/download_consent.dart';
import 'package:transcribe/widgets/download_consent_dialog.dart';

import 'test_helpers.dart';

/// Opens the dialog from a button, as onboarding does, and reports the
/// answer through [onAnswer].
Future<void> _open(
  WidgetTester tester,
  void Function(DownloadConsentAnswer) onAnswer,
) async {
  await tester.pumpWidget(
    buildTestApp(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onAnswer(
            await showDownloadConsentDialog(
              context: context,
              items: kFirstRunDownloadPlan,
              initialDeferOnMetered: true,
            ),
          ),
          child: const Text('buka'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists each model and the total before anything downloads', (
    tester,
  ) async {
    await _open(tester, (_) {});

    expect(find.text('Model Cepat'), findsOneWidget);
    expect(find.text('±142 MB'), findsOneWidget);
    expect(find.text('Model Akurat'), findsOneWidget);
    expect(find.text('±548 MB'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('download-consent-total'))).data,
      '±690 MB',
    );
    expect(find.text('Tunda kalau koneksi metered'), findsOneWidget);
  });

  testWidgets('"Nanti" answers no and keeps the metered choice', (
    tester,
  ) async {
    DownloadConsentAnswer? answer;
    await _open(tester, (a) => answer = a);

    await tester.tap(find.text('Tunda kalau koneksi metered'));
    await tester.pump();
    await tester.tap(find.text('Nanti'));
    await tester.pumpAndSettle();

    expect(answer, isNotNull);
    expect(answer!.downloadNow, isFalse);
    expect(answer!.deferOnMetered, isFalse);
  });

  testWidgets('"Unduh sekarang" answers yes', (tester) async {
    DownloadConsentAnswer? answer;
    await _open(tester, (a) => answer = a);

    await tester.tap(find.text('Unduh sekarang'));
    await tester.pumpAndSettle();

    expect(answer!.downloadNow, isTrue);
    expect(answer!.deferOnMetered, isTrue);
  });
}
