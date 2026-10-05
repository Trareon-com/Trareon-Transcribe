import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/widgets/stream_toggle.dart';

void main() {
  testWidgets('exposes a merged semantic node with the label and switch', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamToggle(
            source: StreamSource.mic,
            enabled: true,
            accent: AppColors.light.success,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    // The visible label is Indonesian …
    expect(find.text('Mikrofon'), findsOneWidget);
    // … and so is the screen-reader announcement, which also carries the
    // on/off state. Deriving it from the visible label (as this widget used
    // to) broke the moment that label was translated.
    final semantics = tester.getSemantics(find.byType(StreamToggle));
    // Exactly one sentence: the chip's own Text is excluded from the
    // semantics tree, so a screen reader does not read "Mikrofon aktif,
    // Mikrofon, HIDUP".
    expect(semantics.label, 'Mikrofon aktif');
    // The on/off state is also in the label, which is what a screen reader
    // actually reads out; `toggled:` on the Semantics node carries it for
    // assistive tech that queries the flag instead.
    expect(semantics.label, contains('aktif'));

    handle.dispose();
  });

  testWidgets('announces the off state and the system-audio source', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamToggle(
            source: StreamSource.speaker,
            enabled: false,
            accent: AppColors.light.info,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Suara sistem'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(StreamToggle)).label,
      'Pengeras suara nonaktif',
    );

    handle.dispose();
  });
}
