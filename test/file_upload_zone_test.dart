import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/batch_upload_model.dart';
import 'package:transcribe/widgets/file_upload_zone.dart';

void main() {
  group('shouldRefineImport', () {
    // Sprint 14a item 4: an import has no real-time deadline, so it must
    // refine with the accurate model whenever one is installed —
    // regardless of the live-only "Cepat dulu, lalu diperhalus" toggle,
    // which this function deliberately takes no parameter for.
    test('refines when the accurate model is installed and not already chosen', () {
      expect(
        shouldRefineImport(modelId: 'base', refineModelAvailable: true),
        isTrue,
      );
      expect(
        shouldRefineImport(modelId: 'small', refineModelAvailable: true),
        isTrue,
      );
    });

    test('does not refine when the accurate model is not installed', () {
      expect(
        shouldRefineImport(modelId: 'base', refineModelAvailable: false),
        isFalse,
      );
    });

    test('does not double-refine when the accurate model is already chosen', () {
      expect(
        shouldRefineImport(
          modelId: 'large-v3-turbo-q5',
          refineModelAvailable: true,
        ),
        isFalse,
      );
    });
  });

  testWidgets(
    'shows cleanup controls only when queue has items and removes done files',
    (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(batchUploadProvider.notifier).addFiles([
        '/a/one.mp3',
        '/a/two.mp3',
      ]);
      container
          .read(batchUploadProvider.notifier)
          .updateStatus('/a/one.mp3', BatchFileStatus.done);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: FileUploadZone())),
        ),
      );

      expect(find.text('Hapus selesai'), findsOneWidget);
      expect(find.text('Kosongkan'), findsOneWidget);
      expect(find.text('one.mp3'), findsOneWidget);
      expect(find.text('two.mp3'), findsOneWidget);

      await tester.tap(find.text('Hapus selesai'));
      await tester.pump();

      expect(container.read(batchUploadProvider).map((e) => e.filename), [
        'two.mp3',
      ]);
      expect(find.text('one.mp3'), findsNothing);
      expect(find.text('two.mp3'), findsOneWidget);
    },
  );
}
