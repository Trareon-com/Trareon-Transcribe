import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/src/rust/export.dart' as rust_export;

import 'test_helpers.dart';

class _FailingExportBridge extends NoopBridge {
  bool exportCalled = false;

  @override
  Future<void> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
      rust_export.ExportFormat.txt,
      rust_export.ExportFormat.json,
    ],
  }) async {
    exportCalled = true;
    throw Exception('permission denied');
  }
}

TranscriptSegment _segment(String text) => TranscriptSegment(
      source: 'mic',
      speaker: 'MIC',
      text: text,
      timestamp: 0,
      duration: 1,
      language: 'id',
      confidence: 0.9,
      isPartial: false,
    );

void main() {
  test('stop() surfaces a TranscribeSaveError when the export write fails', () async {
    final bridge = _FailingExportBridge();
    final notifier = SessionNotifier(bridge, SessionMode.offline, 'models/ggml-base.bin');
    notifier.state = notifier.state.copyWith(
      sessionId: 'session-1',
      segments: [_segment('halo dunia')],
    );

    await expectLater(notifier.stop(), throwsA(isA<TranscribeSaveError>()));
    expect(bridge.exportCalled, isTrue);
  });

  test('stop() does not attempt to export when there are no segments', () async {
    final bridge = _FailingExportBridge();
    final notifier = SessionNotifier(bridge, SessionMode.offline, 'models/ggml-base.bin');
    notifier.state = notifier.state.copyWith(sessionId: 'session-2', segments: const []);

    await notifier.stop();

    expect(bridge.exportCalled, isFalse);
  });
}
