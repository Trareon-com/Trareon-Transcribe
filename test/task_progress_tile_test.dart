import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/widgets/ui/task_progress_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: ThemeData(extensions: <ThemeExtension<dynamic>>[AppColors.light]),
    home: Scaffold(body: child),
  );

  group('ProgressGate', () {
    testWidgets('stays hidden before the threshold elapses', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProgressGate(
            active: true,
            threshold: const Duration(seconds: 3),
            builder: (_) => const Text('TUGAS BERJALAN'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('TUGAS BERJALAN'), findsNothing);
    });

    testWidgets('becomes visible once the threshold elapses', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProgressGate(
            active: true,
            threshold: const Duration(seconds: 3),
            builder: (_) => const Text('TUGAS BERJALAN'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3, milliseconds: 1));
      expect(find.text('TUGAS BERJALAN'), findsOneWidget);
    });

    testWidgets('never shows for a task that finishes before the threshold', (
      tester,
    ) async {
      var active = true;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => ProgressGate(
              active: active,
              threshold: const Duration(seconds: 3),
              builder: (_) => const Text('TUGAS BERJALAN'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      active = false;
      await tester.pumpWidget(
        wrap(
          ProgressGate(
            active: active,
            threshold: const Duration(seconds: 3),
            builder: (_) => const Text('TUGAS BERJALAN'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('TUGAS BERJALAN'), findsNothing);
    });

    testWidgets('hides immediately once no longer active', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProgressGate(
            active: true,
            threshold: const Duration(seconds: 1),
            builder: (_) => const Text('TUGAS BERJALAN'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1, milliseconds: 1));
      expect(find.text('TUGAS BERJALAN'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          ProgressGate(
            active: false,
            threshold: const Duration(seconds: 1),
            builder: (_) => const Text('TUGAS BERJALAN'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('TUGAS BERJALAN'), findsNothing);
    });
  });

  group('TaskProgressTile', () {
    testWidgets('indeterminate: spinner has no fixed value, stage shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const TaskProgressTile(title: 'Rapat Senin', stage: 'Memuat model'),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Memuat model…'), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNull);
    });

    testWidgets('determinate: shows percent and the indicator has a value', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const TaskProgressTile(
            title: 'Rapat Senin',
            stage: 'Mentranskripsi',
            progress: 0.42,
            etaLabel: 'sisa 2 menit',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('42%'), findsOneWidget);
      expect(find.textContaining('sisa 2 menit'), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, closeTo(0.42, 0.001));
    });

    testWidgets('cancel button calls back only while running', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        wrap(
          TaskProgressTile(
            title: 'Rapat Senin',
            stage: 'Mentranskripsi',
            progress: 0.1,
            onCancel: () => cancelled = true,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Batalkan'));
      expect(cancelled, isTrue);
    });

    testWidgets('no cancel button once the task has finished', (tester) async {
      await tester.pumpWidget(
        wrap(
          TaskProgressTile(
            title: 'Rapat Senin',
            state: TaskRunState.done,
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byTooltip('Batalkan'), findsNothing);
      expect(find.textContaining('Selesai'), findsOneWidget);
    });

    testWidgets('failed state shows the override message', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TaskProgressTile(
            title: 'Rapat Senin',
            state: TaskRunState.failed,
            statusOverride: 'Model tidak ditemukan.',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Model tidak ditemukan.'), findsOneWidget);
    });

    testWidgets('carries a combined semantic label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          const TaskProgressTile(
            title: 'Rapat Senin',
            stage: 'Mentranskripsi',
            progress: 0.5,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Rapat Senin: Mentranskripsi… 50%')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
