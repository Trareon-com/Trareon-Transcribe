/// The flight recorder, as the app actually uses it (audit item 27).
///
/// `rust_core/src/flight_recorder.rs` has existed since the first release and
/// nothing in `lib/` ever called it: no `init`, no events, no way for a user to
/// produce a log. "Send us your log" was therefore not an answerable request,
/// which is why most support questions had no evidence behind them.
///
/// What is recorded is metadata only — lifecycle transitions, segment counts,
/// error strings, settings changes. Never transcript text, never audio, never
/// a path from the user's library. [exportDiagnostics] packs the rotated logs
/// plus the doctor report into a single `.zip` the user can attach to an issue.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_version.dart';
import '../src/rust/api.dart' as rust_api;

/// Directory the recorder writes into. Alongside the model cache rather than
/// in the library, so a user who moves their library does not scatter logs.
String diagnosticsDirectory() {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (Platform.isWindows && localAppData != null) {
    return '$localAppData\\TrareonTranscribe\\logs';
  }
  final home = Platform.environment['HOME'];
  if (home != null) {
    return '$home/Library/Caches/TrareonTranscribe/logs';
  }
  return 'logs';
}

/// Machine and build facts worth having in a bug report, and nothing else.
///
/// Deliberately no username, no hostname and no library path: a diagnostics
/// bundle is something a user forwards to strangers.
String environmentSummary() => [
      'Trareon Transcribe $kAppVersion',
      'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'Dart: ${Platform.version}',
      'Prosesor: ${Platform.numberOfProcessors} inti',
      'Mode: ${kDebugMode ? 'debug' : 'release'}',
    ].join('\n');

/// Thin, failure-tolerant façade over the engine's recorder.
///
/// Every method swallows its errors: a logger that can take the app down with
/// it is worse than no logger.
class FlightRecorder {
  const FlightRecorder._();

  static const FlightRecorder instance = FlightRecorder._();

  /// Points the recorder at [diagnosticsDirectory] and records the launch.
  /// Call once, right after `RustLib.init()`.
  Future<void> init() async {
    try {
      await rust_api.initFlightRecorder(appSupportDir: diagnosticsDirectory());
      await logSystem('app_start', {
        'version': kAppVersion,
        'platform': Platform.operatingSystem,
      });
    } catch (e) {
      debugPrint('flight recorder init failed: $e');
    }
  }

  Future<void> logSystem(String event, [Map<String, String>? details]) async {
    try {
      await rust_api.flightLogSystem(event: event, details: details);
    } catch (_) {}
  }

  Future<void> logLifecycle(String sessionId, String from, String to) async {
    try {
      await rust_api.flightLogLifecycle(
        sessionId: sessionId,
        from: from,
        to: to,
      );
    } catch (_) {}
  }

  Future<void> logError(String sessionId, String source, String message) async {
    try {
      await rust_api.flightLogError(
        sessionId: sessionId,
        source: source,
        message: message,
      );
    } catch (_) {}
  }

  /// Number of log files an export would contain (active + rotated).
  Future<int> logFileCount() async {
    try {
      return await rust_api.flightLogFileCount();
    } catch (_) {
      return 0;
    }
  }

  Future<int> entryCount() async {
    try {
      return (await rust_api.flightEntryCount()).toInt();
    } catch (_) {
      return 0;
    }
  }
}
