// F11 (Sprint 19): catatan pribadi saat rapat digabung AI dengan transkrip.
//
// Part A — the split-screen notes panel must actually appear next to the
// live transcript in MainScreen's real widget tree while a session is
// recording (not a notifier-only test), and typing into it must reach
// `SessionNotifier.setPersonalNotes` for real.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/main_screen.dart';
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/widgets/personal_notes_panel.dart';

import 'test_helpers.dart';

Future<ProviderContainer> _pumpRecordingMainScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(buildTestAppWithOverrides(overrides: const []));
  await tester.pump();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(MainScreen)),
  );
  await container.read(sessionProvider.notifier).start();
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  group('F11 Bagian A — panel catatan pribadi saat rekam', () {
    testWidgets(
      'panel catatan pribadi muncul berdampingan dengan transkrip saat merekam',
      (tester) async {
        await _pumpRecordingMainScreen(tester);

        expect(
          find.byType(PersonalNotesPanel),
          findsOneWidget,
          reason:
              'the split-screen notes panel must be in the real widget '
              'tree once a session is recording, not just reachable '
              'through the provider',
        );
        expect(find.text('Catatan Pribadi'), findsOneWidget);
      },
    );

    testWidgets('panel tidak muncul saat sesi masih idle (belum merekam)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(buildTestAppWithOverrides(overrides: const []));
      await tester.pump();

      expect(find.byType(PersonalNotesPanel), findsNothing);
    });

    testWidgets(
      'mengetik di panel benar-benar memperbarui SessionUiState.personalNotes',
      (tester) async {
        final container = await _pumpRecordingMainScreen(tester);

        expect(container.read(sessionProvider).personalNotes, isEmpty);

        await tester.enterText(
          find.descendant(
            of: find.byType(PersonalNotesPanel),
            matching: find.byType(TextField),
          ),
          'PENTING: deadline Jumat',
        );
        await tester.pump();

        expect(
          container.read(sessionProvider).personalNotes,
          'PENTING: deadline Jumat',
          reason:
              'typing in the live panel must reach SessionNotifier.'
              'setPersonalNotes, not just update local widget state',
        );
      },
    );
  });
}
