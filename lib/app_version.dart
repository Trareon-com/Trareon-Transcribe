/// The shipped application version.
///
/// A compile-time constant rather than `package_info_plus`: the version is
/// needed by [UpdateChecker], which runs before any platform channel is
/// guaranteed to be up, and an extra plugin for a string already present in
/// `pubspec.yaml` buys nothing. What it does need is a guarantee that the
/// constant, `pubspec.yaml` and the `VERSION` manifest never drift — the
/// updater previously hardcoded `0.1.0` against a `pubspec.yaml` saying
/// `1.0.0`, so it could not report correctly in either direction.
/// `test/app_version_test.dart` is that guarantee.
library;

const String kAppVersion = '1.0.0';

/// Where "Lihat Rilis" sends the user. Opened with `url_launcher` on an
/// explicit tap only; recorded in the Privacy Report like every other
/// outbound request.
const String kReleasesUrl =
    'https://github.com/Trareon-com/Transcribe/releases';

/// Plain-text manifest carrying the latest released version. Fetched only
/// when the user presses "Cek Pembaruan".
const String kVersionManifestUrl =
    'https://raw.githubusercontent.com/Trareon-com/Transcribe/main/VERSION';
