// The model download dialog asks before downloading (issue #70): opening it
// from a model picker must not fetch anything until the user presses Unduh.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transcribe/widgets/model_download_dialog.dart';

import 'test_helpers.dart';

class _CountingBridge extends NoopBridge {
  final downloads = <String>[];
  final _progress = StreamController<double>.broadcast();

  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {
    downloads.add(modelId);
  }

  @override
  Stream<double> downloadProgress() => _progress.stream;
}

Future<void> _open(
  WidgetTester tester,
  _CountingBridge bridge, {
  bool startImmediately = false,
}) async {
  await tester.pumpWidget(
    buildTestApp(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModelDownloadDialog(
            context: context,
            bridge: bridge,
            modelId: 'large-v3-turbo-q5',
            modelsDir: '/tmp/models',
            displayName: 'Akurat',
            startImmediately: startImmediately,
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
  testWidgets('opening the dialog downloads nothing until Unduh', (
    tester,
  ) async {
    final bridge = _CountingBridge();
    await _open(tester, bridge);

    expect(find.textContaining('belum diunduh'), findsOneWidget);
    expect(bridge.downloads, isEmpty);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(bridge.downloads, isEmpty);
  });

  testWidgets('Unduh starts the download', (tester) async {
    final bridge = _CountingBridge();
    await _open(tester, bridge);

    await tester.tap(find.text('Unduh'));
    await tester.pumpAndSettle();
    expect(bridge.downloads, ['large-v3-turbo-q5']);
  });

  testWidgets('an already-confirmed caller can start right away', (
    tester,
  ) async {
    final bridge = _CountingBridge();
    await _open(tester, bridge, startImmediately: true);
    expect(bridge.downloads, ['large-v3-turbo-q5']);
  });
}
