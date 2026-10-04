import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/privacy_report_screen.dart';
import 'package:transcribe/state/privacy_report_model.dart';
import 'package:transcribe/theme/app_icons.dart';

void main() {
  testWidgets('shows zero network calls by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PrivacyReportScreen()),
      ),
    );

    expect(find.text('0 panggilan jaringan sejak aplikasi dibuka'), findsOneWidget);
    expect(find.byIcon(AppIcons.verifiedUser), findsOneWidget);
    expect(find.text('Belum ada aktivitas jaringan tercatat.'), findsOneWidget);
  });

  testWidgets('recording a model download updates the count and history', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PrivacyReportScreen()),
      ),
    );

    container.read(privacyReportProvider.notifier).recordModelDownload('tiny');
    await tester.pump();

    expect(find.text('1 panggilan jaringan sejak aplikasi dibuka'), findsOneWidget);
    expect(find.byIcon(AppIcons.warning), findsOneWidget);
    expect(find.textContaining('Mengunduh model "tiny"'), findsOneWidget);
  });
}
