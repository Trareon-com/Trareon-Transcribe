/// Access to the generated [AppLocalizations] (issue #47).
///
/// Widgets use `context.l10n.someKey`. Code without a `BuildContext`
/// (state notifiers, services) uses [currentL10n], which follows the
/// language the app is showing.
library;

import 'package:material_ui/material_ui.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Indonesian is the template locale and the product's first language: it
/// is what a widget gets when no `Localizations` ancestor is present (a
/// widget test pumping a bare `MaterialApp`, or a dialog built before the
/// app's delegates load).
final AppLocalizations _fallback = lookupAppLocalizations(const Locale('id'));

AppLocalizations? _current;

/// The strings for the language the app currently shows, for code that has
/// no `BuildContext`. Updated by the app's `MaterialApp.builder`.
AppLocalizations get currentL10n => _current ?? _fallback;

/// Called from `MaterialApp.builder` whenever the resolved locale changes.
void updateCurrentL10n(AppLocalizations l10n) => _current = l10n;

extension AppL10nContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? _fallback;
}
