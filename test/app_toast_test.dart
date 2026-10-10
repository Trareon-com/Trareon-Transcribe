import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/widgets/app_toast.dart';

void main() {
  tearDown(() => AppToast.clear());

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            captured = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('an info toast auto-dismisses on its own', (tester) async {
    final context = await pumpHost(tester);
    AppToast.show(context, 'Halo', type: ToastType.info);
    await tester.pump();
    expect(find.text('Halo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Halo'), findsNothing);
  });

  testWidgets('a custom duration overrides the default', (tester) async {
    final context = await pumpHost(tester);
    AppToast.show(
      context,
      'Peringatan izin',
      type: ToastType.warning,
      duration: const Duration(seconds: 8),
    );
    await tester.pump();
    expect(find.text('Peringatan izin'), findsOneWidget);

    // Still up just before the custom duration elapses.
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Peringatan izin'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Peringatan izin'), findsNothing);
  });

  testWidgets('an error toast never auto-dismisses', (tester) async {
    final context = await pumpHost(tester);
    AppToast.show(context, 'Gagal total', type: ToastType.error);
    await tester.pump();
    expect(find.text('Gagal total'), findsOneWidget);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(find.text('Gagal total'), findsOneWidget);

    AppToast.clear();
    await tester.pump();
  });

  testWidgets(
    'the manual close button is present even with an action button',
    (tester) async {
      final context = await pumpHost(tester);
      var tapped = false;
      AppToast.show(
        context,
        'Butuh izin',
        type: ToastType.warning,
        actionLabel: 'Buka Pengaturan',
        onAction: () => tapped = true,
      );
      await tester.pump();

      expect(find.text('Buka Pengaturan'), findsOneWidget);
      expect(find.byTooltip('Tutup pemberitahuan'), findsOneWidget);

      await tester.tap(find.byTooltip('Tutup pemberitahuan'));
      await tester.pump();
      expect(find.text('Butuh izin'), findsNothing);
      expect(tapped, isFalse);
    },
  );

  testWidgets('tapping the action button runs it and dismisses', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    var tapped = false;
    AppToast.show(
      context,
      'Butuh izin',
      type: ToastType.warning,
      actionLabel: 'Buka Pengaturan',
      onAction: () => tapped = true,
    );
    await tester.pump();

    await tester.tap(find.text('Buka Pengaturan'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(find.text('Butuh izin'), findsNothing);
  });
}
