// Issue #70: after "Nanti" the first-run models may not be on disk. Pressing
// "Mulai Rekam" must offer the download right there, not start a session the
// engine cannot transcribe.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';

import 'test_helpers.dart';

class _CountingBridge extends NoopBridge {
  int startAttempts = 0;

  @override
  Future<String> startSession(SessionConfig config) async {
    startAttempts++;
    return super.startSession(config);
  }
}

void main() {
  testWidgets('recording without a model offers the download first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = _CountingBridge();
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          rustBridgeProvider.overrideWithValue(bridge),
          modelOnDiskProvider.overrideWithValue((_, _) => false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai Rekam'));
    await tester.pumpAndSettle();

    expect(find.text('Model belum diunduh'), findsOneWidget);
    expect(find.textContaining('±142 MB'), findsOneWidget);
    expect(bridge.startAttempts, 0);

    // Declining leaves the app idle: no download, no session.
    await tester.tap(find.text('Nanti'));
    await tester.pumpAndSettle();
    expect(bridge.startAttempts, 0);
    expect(find.text('Mulai Rekam'), findsOneWidget);
  });
}
