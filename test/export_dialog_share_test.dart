// Sprint 22 celah B: `shareExportedFile` (F21) was wired into
// action_items_panel.dart only. A successful transcript/notulen export via
// `showEksporDialog` (export_dialog.dart) must offer a "Bagikan" action on
// its success toast, from a real widget tree, not just write files to disk
// and leave the user to go find them.

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/state/models.dart';
import 'package:transcribe/widgets/export_dialog.dart';
import 'package:transcribe/widgets/ui/app_button.dart';

import 'test_helpers.dart';

/// file_picker's native folder dialog has no counterpart in a widget test
/// sandbox. Since 11.0.0 the plugin's API is static (`FilePicker.getDirectoryPath`)
/// with no injectable instance, so the fake sits at the plugin boundary: the
/// default platform implementation is the method-channel one, and this channel
/// is what it asks for a directory. The reply stands in for the user picking a
/// real folder.
const _filePickerChannel = MethodChannel(
  'miguelruivo.flutter.plugins.filepicker',
  StandardMethodCodec(),
);

const _pickedDirectory = '/tmp/sesi-ekspor';

class _ExportBridge extends NoopBridge {
  @override
  Future<List<rust_export.ExportedFile>> exportSessionWithSummary({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    String summary = '',
    List<Bookmark> bookmarks = const [],
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
    ],
  }) async => [
    rust_export.ExportedFile(
      filename: '$title.md',
      path: '$outputDir/$title.md',
      sizeBytes: BigInt.from(512),
    ),
  ];
}

const _segment = TranscriptSegment(
  source: 'mic',
  speaker: 'Saya',
  text: 'kita putuskan pakai Rust',
  timestamp: 0,
  duration: 2,
  language: 'id',
  confidence: 0.9,
  isPartial: false,
);

void main() {
  // Reading `FilePicker`'s static API never needs an instance any more, but
  // with no plugin registrant under `flutter test` the call still reaches the
  // method channel with nothing on the other end, so answer it here. Only ever
  // mock it; there is no real dialog to restore afterwards.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _filePickerChannel,
          (call) async => call.method == 'dir' ? _pickedDirectory : null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_filePickerChannel, null);
  });

  testWidgets(
    'ekspor berhasil menawarkan tombol Bagikan pada toast sukses',
    (tester) async {
      // Real Clipboard.setData hangs in this sandboxed test runner (see
      // share_file.dart's doc comment); not tapped here, but mocked
      // defensively in case a future change makes this toast auto-run its
      // action.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final bridge = _ExportBridge();
      final session = SessionSummary(
        id: 's1',
        title: 'Rapat Anggaran',
        date: '2026-10-13',
        segmentsCount: 1,
        segments: const [_segment],
        durationSeconds: 60,
      );

      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: const [],
          child: Builder(
            builder: (context) => Material(
              child: AppButton.primary(
                label: 'buka',
                onPressed: () => showEksporDialog(
                  context,
                  session,
                  bridge: bridge,
                  defaultFormat: 'markdown',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      // "md" is pre-selected via defaultFormat; confirm straight to the
      // (faked) folder picker.
      await tester.tap(find.text('Pilih Folder'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ekspor berhasil'), findsOneWidget);
      expect(find.text('Bagikan'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );
}
