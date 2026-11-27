// The app's widgets come from package:material_ui, whose MaterialLocalizations
// is not flutter_localizations'. Switching the interface to Indonesian
// (issue #47) once made every dropdown fail with "No MaterialLocalizations
// found"; this pins the delegate list main.dart uses.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transcribe/l10n/l10n.dart';

void main() {
  for (final locale in const [Locale('id'), Locale('en')]) {
    testWidgets('material widgets localize in ${locale.languageCode}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: kAppLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(title: const Text('x')),
            body: DropdownButton<int>(
              value: 1,
              items: const [DropdownMenuItem(value: 1, child: Text('satu'))],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(DropdownButton<int>));
      expect(MaterialLocalizations.of(context), isNotNull);
      expect(context.l10n.localeName, locale.languageCode);
    });
  }
}
