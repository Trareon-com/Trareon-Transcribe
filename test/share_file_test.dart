/// Sprint 15 F21: the quick-share fallback for platforms with no native
/// file-share channel.
///
/// `share_plus`'s own Linux backend throws for any file share, and in a
/// sandbox with no real desktop session that throw does not happen
/// promptly — calling it from a test hangs the suite. `shareExportedFile`
/// is written to short-circuit on `Platform.isLinux` before ever reaching
/// the plugin, so this test (and the real Linux build) never calls it.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/utils/share_file.dart';

import 'test_helpers.dart';

void main() {
  testWidgets(
    'falls back to copying the path and says so, never claiming a share '
    'that did not happen',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      String? copied;
      await shareExportedFile(
        capturedContext,
        '/tmp/sesi/tindak-lanjut.ics',
        subject: 'Tindak Lanjut: Rapat Anggaran',
        // The real `Clipboard.setData` platform channel hangs rather than
        // failing fast in this sandboxed test runner (no desktop
        // clipboard to talk to) — see share_file.dart's doc comment.
        copyToClipboard: (path) async => copied = path,
      );
      await tester.pump();

      expect(copied, '/tmp/sesi/tindak-lanjut.ics');
      // The toast message is the user-visible contract: it must say what
      // actually happened (copied), never claim a share that did not occur.
      expect(find.textContaining('Path disalin'), findsOneWidget);
      expect(find.textContaining('tindak-lanjut.ics'), findsOneWidget);

      // Let the toast's dismissal timer expire before the test ends.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
    // Pins the Linux-only clipboard fallback. On macOS/Windows
    // shareExportedFile reaches the real share_plus sheet, which blocks in a
    // headless runner.
    skip: !Platform.isLinux,
  );
}
