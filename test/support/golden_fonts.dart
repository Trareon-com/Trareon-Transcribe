/// Loads the bundled typefaces into a widget test, so the goldens under
/// `test/goldens/` render the type the app actually ships.
///
/// Without this every golden renders in Ahem, the solid-block placeholder the
/// test harness substitutes for a real font. Ahem goldens are deterministic
/// but they prove nothing about the design: the whole point of `docs/
/// DESIGN-SYSTEM.md` §3 is the type rhythm, and a wall of black rectangles
/// cannot regress on tracking, line height or tabular figures.
///
/// `golden_toolkit` used to provide this; it is archived, and this is the
/// twenty lines of it that matter.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _loaded = false;

/// Registers Inter and JetBrains Mono under the family names `pubspec.yaml`
/// declares. Idempotent, so every golden test can call it in `setUpAll`.
Future<void> loadAppFonts() async {
  if (_loaded) return;
  TestWidgetsFlutterBinding.ensureInitialized();

  const families = {
    'Inter': [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ],
    'JetBrainsMono': [
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-Medium.ttf',
    ],
  };

  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError(
          'Missing bundled font $path. The goldens are only deterministic '
          'because the app ships its own type; see assets/fonts/README.md.',
        );
      }
      loader.addFont(
        file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  }

  await _loadMaterialIcons();
  _loaded = true;
}

/// Registers `MaterialIcons`, the family every glyph in `AppIcons` comes from.
///
/// Without it every icon in a golden renders as the "missing glyph" box, which
/// is exactly the part of the design that most needs reviewing: the whole
/// point of §5 is that one icon family is used consistently.
///
/// The font ships inside the Flutter SDK rather than in this repo, so it is
/// located from `FLUTTER_ROOT` and then from the SDK directory the running
/// Dart executable sits in.
Future<void> _loadMaterialIcons() async {
  final roots = <String>[
    ?Platform.environment['FLUTTER_ROOT'],
    // …/flutter/bin/cache/dart-sdk/bin/dart
    File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path,
  ];
  for (final root in roots) {
    final file = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (!file.existsSync()) continue;
    final loader = FontLoader(
      'MaterialIcons',
    )..addFont(file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)));
    await loader.load();
    return;
  }
  throw StateError(
    'MaterialIcons-Regular.otf not found under any of $roots. Set FLUTTER_ROOT '
    'or run these goldens through `flutter test`, which sets it.',
  );
}
