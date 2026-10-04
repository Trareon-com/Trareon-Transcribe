import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/l10n/generated/app_localizations.dart';
import 'package:transcribe/main.dart' show resolveLocale;

/// Proves the i18n infrastructure (audit item 26) is wired end to end: the
/// generated [AppLocalizations] loads for both supported locales, Indonesian
/// is the template, and plurals resolve per-locale. The full string
/// extraction across every screen is the remaining (large) parallel track.
void main() {
  test('both locales are supported', () {
    final codes =
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toList();
    expect(codes, contains('id'));
    expect(codes, contains('en'));
  });

  group('resolveLocale is Indonesian-first', () {
    final supported = AppLocalizations.supportedLocales;

    test('an unknown system locale falls back to Indonesian, not English', () {
      expect(resolveLocale([const Locale('fr')], supported), const Locale('id'));
    });

    test('no system preference falls back to Indonesian', () {
      expect(resolveLocale(null, supported), const Locale('id'));
      expect(resolveLocale([], supported), const Locale('id'));
    });

    test('a supported system locale is honoured', () {
      expect(resolveLocale([const Locale('en')], supported), const Locale('en'));
      expect(resolveLocale([const Locale('id')], supported), const Locale('id'));
    });

    test('the first matching preference wins', () {
      expect(
        resolveLocale(
          [const Locale('fr'), const Locale('en'), const Locale('id')],
          supported,
        ),
        const Locale('en'),
      );
    });

    test('country code does not block a language match', () {
      expect(
        resolveLocale([const Locale('en', 'US')], supported),
        const Locale('en'),
      );
    });
  });

  test('Indonesian strings load', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('id'));
    expect(l10n.appTitle, 'Trareon Transcribe');
    expect(l10n.alreadyRunningTitle, 'Trareon Transcribe sudah berjalan');
    expect(l10n.actionSave, 'Simpan');
    expect(l10n.languageSubtitle, contains('transkripsi'));
  });

  test('English strings load', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l10n.appTitle, 'Trareon Transcribe');
    expect(l10n.alreadyRunningTitle, 'Trareon Transcribe is already running');
    expect(l10n.actionSave, 'Save');
  });

  test('plurals resolve per locale', () async {
    final id = await AppLocalizations.delegate.load(const Locale('id'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(id.storageSessionCount(0), 'Belum ada sesi');
    expect(id.storageSessionCount(3), '3 sesi');

    expect(en.storageSessionCount(0), 'No sessions yet');
    expect(en.storageSessionCount(1), '1 session');
    expect(en.storageSessionCount(3), '3 sessions');
  });

  test('placeholder messages interpolate', () async {
    final id = await AppLocalizations.delegate.load(const Locale('id'));
    expect(id.bookmarkMarkedAt('00:42'), 'Poin ditandai pada 00:42');
  });
}
