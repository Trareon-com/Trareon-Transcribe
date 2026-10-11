/// Sprint 15 F24: "Mulai dari template" picker/creator dialog.
///
/// Persistence itself is covered by `meeting_templates_test.dart`; this
/// checks the UI flow — creating a template and picking an existing one
/// both return the template to the caller, who applies it to the
/// not-yet-started session.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/meeting_templates.dart';
import 'package:transcribe/widgets/meeting_template_picker.dart';
import 'package:transcribe/widgets/ui/app_button.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('creating a new template returns it to the caller', (
    tester,
  ) async {
    MeetingTemplate? picked;

    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          meetingTemplatesProvider.overrideWith(
            (ref) => MeetingTemplateNotifier(
              store: InMemoryTemplateStore(),
            ),
          ),
        ],
        child: Scaffold(
          body: Builder(
            builder: (context) => AppButton(
              label: 'buka',
              onPressed: () async {
                picked = await showMeetingTemplatePicker(context);
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada template tersimpan.'), findsNothing);
    await tester.tap(
      find.widgetWithText(AppButton, 'Buat template baru').hitTestable(),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Rapat Mingguan Tim',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Simpan').hitTestable());
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.name, 'Rapat Mingguan Tim');
  });

  testWidgets('picking an existing template returns it', (tester) async {
    MeetingTemplate? picked;
    const existing = MeetingTemplate(id: 't1', name: 'Rapat Anggaran');

    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          meetingTemplatesProvider.overrideWith((ref) {
            final notifier = MeetingTemplateNotifier(
              store: InMemoryTemplateStore(),
            );
            notifier.upsert(existing);
            return notifier;
          }),
        ],
        child: Scaffold(
          body: Builder(
            builder: (context) => AppButton(
              label: 'buka',
              onPressed: () async {
                picked = await showMeetingTemplatePicker(context);
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Rapat Anggaran'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Pakai').hitTestable());
    await tester.pumpAndSettle();

    expect(picked?.id, 't1');
  });
}
