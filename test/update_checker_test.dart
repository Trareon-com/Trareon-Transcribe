import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/app_version.dart';
import 'package:transcribe/services/update_checker.dart';

/// The updater had no test at all, and shipped comparing a hardcoded
/// `0.1.0` against a `pubspec.yaml` saying `1.0.0`. These run against a
/// loopback HTTP server rather than the real manifest, so they are offline
/// and deterministic.
void main() {
  late HttpServer server;
  String body = '1.2.3';
  int statusCode = 200;

  setUp(() async {
    body = '1.2.3';
    statusCode = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = statusCode;
      request.response.write(body);
      await request.response.close();
    });
  });

  tearDown(() async => server.close(force: true));

  String manifestUrl() => 'http://127.0.0.1:${server.port}/VERSION';

  test('defaults to the shipped app version', () {
    expect(
      UpdateChecker(onNetworkRequest: (_) {}).currentVersion,
      kAppVersion,
    );
  });

  test('reports an update when the manifest is newer', () async {
    final recorded = <String>[];
    final info = await UpdateChecker(
      currentVersion: '1.0.0',
      manifestUrl: manifestUrl(),
      onNetworkRequest: recorded.add,
    ).checkForUpdate();

    expect(info.latestVersion, '1.2.3');
    expect(info.currentVersion, '1.0.0');
    expect(info.isUpdateAvailable, isTrue);
    expect(info.downloadUrl, kReleasesUrl);
    expect(recorded, [manifestUrl()]);
  });

  test('reports no update when the manifest matches or is older', () async {
    body = '1.0.0';
    final same = await UpdateChecker(
      currentVersion: '1.0.0',
      manifestUrl: manifestUrl(),
      onNetworkRequest: (_) {},
    ).checkForUpdate();
    expect(same.isUpdateAvailable, isFalse);

    body = '0.9.9';
    final older = await UpdateChecker(
      currentVersion: '1.0.0',
      manifestUrl: manifestUrl(),
      onNetworkRequest: (_) {},
    ).checkForUpdate();
    expect(older.isUpdateAvailable, isFalse);
  });

  test('compares components numerically, not lexicographically', () {
    bool newer(String latest, String current) => UpdateInfo(
      currentVersion: current,
      latestVersion: latest,
    ).isUpdateAvailable;

    expect(newer('1.10.0', '1.9.0'), isTrue, reason: '10 > 9');
    expect(newer('1.9.0', '1.10.0'), isFalse);
    expect(newer('2.0', '1.9.9'), isTrue, reason: 'short versions pad');
    expect(newer('1.0.0', '1.0'), isFalse, reason: '1.0 == 1.0.0');
  });

  test('a non-200 response is an Indonesian, actionable error', () async {
    statusCode = 404;
    await expectLater(
      UpdateChecker(
        manifestUrl: manifestUrl(),
        onNetworkRequest: (_) {},
      ).checkForUpdate(),
      throwsA(
        isA<UpdateCheckException>().having(
          (e) => e.message,
          'message',
          contains('404'),
        ),
      ),
    );
  });

  test('an empty manifest is an error, not a phantom downgrade', () async {
    body = '   ';
    await expectLater(
      UpdateChecker(
        manifestUrl: manifestUrl(),
        onNetworkRequest: (_) {},
      ).checkForUpdate(),
      throwsA(isA<UpdateCheckException>()),
    );
  });

  test('an unreachable host is an error, and is still recorded', () async {
    final recorded = <String>[];
    // Port 1 on loopback: nothing listens there.
    await expectLater(
      UpdateChecker(
        manifestUrl: 'http://127.0.0.1:1/VERSION',
        onNetworkRequest: recorded.add,
        timeout: const Duration(seconds: 2),
      ).checkForUpdate(),
      throwsA(isA<UpdateCheckException>()),
    );
    expect(
      recorded,
      ['http://127.0.0.1:1/VERSION'],
      reason: 'a check that failed to connect is still a check that happened',
    );
  });
}
