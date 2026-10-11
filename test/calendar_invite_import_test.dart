/// Sprint 15 F22: the opt-in confirmation step of manual `.ics` import.
///
/// The parser itself is Rust and tested in
/// `rust_core/src/calendar_import.rs`. The actual file pick goes through
/// `file_picker`'s platform channel, which this suite does not drive
/// (same reasoning as the clipboard fallback in `share_file_test.dart`:
/// a widget test has no real file picker to answer it). What is tested
/// here is the part that is pure Flutter: the confirmation dialog shows
/// the detected title and attendees, is declinable, and never offers to
/// apply a title the invite did not have.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/src/rust/calendar_import.dart';
import 'package:transcribe/widgets/calendar_invite_import.dart';
import 'package:transcribe/widgets/ui/app_button.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('shows the detected title and attendees, opt-in by default', (
    tester,
  ) async {
    const event = CalendarEvent(
      summary: 'Rapat Anggaran Mingguan',
      attendees: ['Budi Santoso', 'Sari Wulandari'],
      dtstart: '20261015T090000Z',
    );
    bool? result;

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => AppButton(
              label: 'buka',
              onPressed: () async {
                result = await confirmCalendarInvite(context, event);
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rapat Anggaran Mingguan'), findsOneWidget);
    expect(
      find.textContaining('Budi Santoso, Sari Wulandari'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Tidak').hitTestable());
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('confirming returns true', (tester) async {
    const event = CalendarEvent(summary: 'Rapat Anggaran', attendees: []);
    bool? result;

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => AppButton(
              label: 'buka',
              onPressed: () async {
                result = await confirmCalendarInvite(context, event);
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester
        .tap(find.widgetWithText(AppButton, 'Isi judul').hitTestable());
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('an invite with no title cannot be applied', (tester) async {
    const event = CalendarEvent(summary: '', attendees: ['Budi']);

    await tester.pumpWidget(
      buildTestApp(child: const InviteConfirmDialog(event: event)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Undangan ini tidak punya judul.'), findsOneWidget);
    final applyButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Isi judul').hitTestable(),
    );
    expect(applyButton.onPressed, isNull);
  });
}
