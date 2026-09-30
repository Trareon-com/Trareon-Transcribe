import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/src/rust/settings.dart' as rust_settings;
import 'package:transcribe/state/models.dart';

/// "Sistem" is a real persisted preference, not a UI-only one.
///
/// The bridge used to write it out as `Theme::Light`, so the app came back
/// as "Terang" after every restart and the settings screen showed a choice
/// the user had not made. The Rust round-trip is covered by
/// `settings::tests::system_theme_survives_a_roundtrip`; this is the Dart
/// half of the same path.
void main() {
  test('every appearance mode survives a Dart -> Rust -> Dart round-trip', () {
    for (final mode in AppThemeMode.values) {
      expect(
        fromRustTheme(toRustTheme(mode)),
        mode,
        reason: '$mode must not collapse into another mode',
      );
    }
  });

  test('"Sistem" maps to its own Rust variant, not Light', () {
    expect(toRustTheme(AppThemeMode.system), rust_settings.Theme.system);
    expect(
      toRustTheme(AppThemeMode.system),
      isNot(rust_settings.Theme.light),
      reason: 'this is the exact substitution that lost the preference',
    );
  });

  test('every Rust variant maps back to a distinct Dart mode', () {
    final mapped = rust_settings.Theme.values.map(fromRustTheme).toSet();
    expect(mapped, hasLength(rust_settings.Theme.values.length));
  });
}
