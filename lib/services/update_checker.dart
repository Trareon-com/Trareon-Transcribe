import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_version.dart';

/// Information about an update check result.
class UpdateInfo {
  /// The currently installed version string.
  final String currentVersion;

  /// The latest version available on the server.
  final String latestVersion;

  /// Optional URL to download the update.
  final String? downloadUrl;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    this.downloadUrl,
  });

  /// Whether the latest version is newer than the current version.
  bool get isUpdateAvailable =>
      _compareVersions(latestVersion, currentVersion) > 0;

  /// Simple semantic version comparison.
  /// Returns negative if a < b, zero if equal, positive if a > b.
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad shorter list with zeros
    final maxLen = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;
    while (aParts.length < maxLen) {
      aParts.add(0);
    }
    while (bParts.length < maxLen) {
      bParts.add(0);
    }

    for (int i = 0; i < maxLen; i++) {
      if (aParts[i] != bParts[i]) return aParts[i] - bParts[i];
    }
    return 0;
  }
}

/// Exception thrown when an update check fails.
class UpdateCheckException implements Exception {
  /// User-friendly error message in Bahasa Indonesia.
  final String message;

  const UpdateCheckException(this.message);

  @override
  String toString() => message;
}

/// Checks for application updates by fetching a version manifest.
///
/// This is one of the app's four outbound paths, so [onNetworkRequest] is
/// **required**, not optional: it is what puts the check into the Privacy
/// Report. The report used to claim two network activities while this class
/// silently contacted `raw.githubusercontent.com` on every "Cek Pembaruan",
/// and a callback that can be omitted is a callback that will be.
class UpdateChecker {
  /// Current app version. Defaults to [kAppVersion], which
  /// `test/app_version_test.dart` keeps in lockstep with `pubspec.yaml` and
  /// the `VERSION` manifest — it was hardcoded `0.1.0` against a pubspec
  /// saying `1.0.0`, so the comparison was wrong in both directions.
  final String currentVersion;

  /// URL of the version manifest file.
  final String manifestUrl;

  /// Optional network timeout override (defaults to 10 seconds).
  final Duration timeout;

  /// Invoked with [manifestUrl] immediately before the socket is opened.
  final void Function(String endpoint) onNetworkRequest;

  UpdateChecker({
    required this.onNetworkRequest,
    this.currentVersion = kAppVersion,
    this.manifestUrl = kVersionManifestUrl,
    this.timeout = const Duration(seconds: 10),
  });

  /// Fetches the latest version from the manifest URL and returns
  /// an [UpdateInfo] comparing it to the current version.
  ///
  /// Throws [UpdateCheckException] on network errors or bad responses.
  Future<UpdateInfo> checkForUpdate() async {
    // Before the socket, and before any failure path can skip it: a check
    // that could not connect is still a check the user should see recorded.
    onNetworkRequest(manifestUrl);
    final client = HttpClient();
    client.connectionTimeout = timeout;

    try {
      final request = await client.getUrl(Uri.parse(manifestUrl));
      final response = await request.close().timeout(timeout);

      if (response.statusCode != 200) {
        throw UpdateCheckException(
          'Server merespon dengan kode ${response.statusCode}. Coba lagi nanti.',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final latestVersion = body.trim();

      if (latestVersion.isEmpty) {
        throw UpdateCheckException(
          'File versi kosong. Coba lagi nanti.',
        );
      }

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: kReleasesUrl,
      );
    } on SocketException {
      throw UpdateCheckException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on HttpException {
      throw UpdateCheckException(
        'Server tidak merespons dengan benar. Coba lagi nanti.',
      );
    } on TimeoutException {
      throw UpdateCheckException(
        'Permintaan timeout. Periksa koneksi internet Anda dan coba lagi.',
      );
    } on FormatException {
      throw UpdateCheckException(
        'Data yang diterima tidak valid. Coba lagi nanti.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
