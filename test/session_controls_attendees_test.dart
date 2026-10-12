// Sprint 22 celah C: `CalendarEvent.attendees` (F22, rust_core's
// calendar_import.rs) was parsed and shown read-only in the invite
// confirmation dialog, but the session-start form (`SessionControlGroup`
// in session_controls.dart) had no attendees field at all — importing an
// invite pre-filled the title and dropped who was coming. This verifies
// the read-only chip list a real widget tree renders from
// `SessionControlGroup.attendees` (wired from `main_screen.dart`'s
// `_attendees` state, set by `onAttendeesImported`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/widgets/session_controls.dart';

import 'test_helpers.dart';

void main() {
  testWidgets(
    'SessionControlGroup menampilkan peserta saat diisi dari undangan',
    (tester) async {
      final titleController = TextEditingController();
      addTearDown(titleController.dispose);

      await tester.pumpWidget(
        buildTestApp(
          child: Material(
            child: SessionControlGroup(
              titleController: titleController,
              onTitleChanged: (_) {},
              mode: SessionMode.online,
              onModeChanged: (_) {},
              modeLocked: false,
              attendees: const ['Budi Santoso', 'Sari Wulandari'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peserta:'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Sari Wulandari'), findsOneWidget);
    },
  );

  testWidgets(
    'tanpa peserta, SessionControlGroup tidak menampilkan baris Peserta',
    (tester) async {
      final titleController = TextEditingController();
      addTearDown(titleController.dispose);

      await tester.pumpWidget(
        buildTestApp(
          child: Material(
            child: SessionControlGroup(
              titleController: titleController,
              onTitleChanged: (_) {},
              mode: SessionMode.online,
              onModeChanged: (_) {},
              modeLocked: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peserta:'), findsNothing);
    },
  );

  testWidgets('AttendeesChips kosong tidak merender apa pun', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: const Material(child: AttendeesChips(attendees: [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsNothing);
    expect(find.text('Peserta:'), findsNothing);
  });
}
