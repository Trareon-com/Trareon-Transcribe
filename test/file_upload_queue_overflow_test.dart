import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/state/batch_upload_model.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/widgets/file_upload_zone.dart';

/// The import queue was spread directly into a Column, so it overflowed
/// off the bottom of the window after about five files and the tiles past
/// that could not be reached at all. Exercised at the smallest window size
/// the app supports.
void main() {
  Future<void> pumpWithQueue(
    WidgetTester tester,
    int fileCount, {
    Size surface = const Size(800, 600),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(batchUploadProvider.notifier)
        .addFiles([for (var i = 0; i < fileCount; i++) '/tmp/rapat-$i.wav']);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(12),
              child: FileUploadZone(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a twelve-file queue does not overflow at 800x600', (
    tester,
  ) async {
    await pumpWithQueue(tester, 12);
    expect(tester.takeException(), isNull);
    expect(find.byType(FileUploadZone), findsOneWidget);
  });

  testWidgets('the queue scrolls to reach the files past the fold', (
    tester,
  ) async {
    await pumpWithQueue(tester, 12);

    final list = find.byType(ListView);
    expect(list, findsOneWidget);
    // The last file is below the fold on an 800x600 window...
    expect(find.text('rapat-11.wav'), findsNothing);
    await tester.drag(list, const Offset(0, -2000));
    await tester.pump();
    // ...and reachable by scrolling.
    expect(find.text('rapat-11.wav'), findsOneWidget);
  });

  testWidgets('an empty queue renders only the drop zone', (tester) async {
    await pumpWithQueue(tester, 0);
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsNothing);
    expect(find.text('Pilih Berkas'), findsOneWidget);
  });
}
