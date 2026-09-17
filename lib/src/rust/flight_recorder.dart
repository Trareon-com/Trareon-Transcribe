// Copyright 2026 YSF Studio. Licensed under Privacy-Preserving Software License v1.0.
// SPDX-License-Identifier: PPSL
//
// Flight recorder (Rust-backed) — privacy-conscious, metadata-only event
// logger for diagnosing long-recording sessions. This is a thin wrapper over
// the auto-generated FRB bindings in `api.dart`; all persistence, rotation
// (JSONL, capped at 5000 entries) and fallback logic lives in
// `rust_core/src/flight_recorder.rs`.
//
// Every call is fire-and-forget: failures are swallowed in Rust and never
// propagate to the UI.

import 'api.dart' as frb;

/// Points the recorder at the app-support directory. Call once at startup,
/// right after `RustLib.init()`. Creates the directory if missing.
Future<void> initFlightRecorder(String appSupportDir) =>
    frb.initFlightRecorder(appSupportDir: appSupportDir);

/// Master switch — set false to disable all recording (defense in depth).
Future<void> setEnabled(bool enabled) => frb.flightSetEnabled(enabled: enabled);

/// Lifecycle transition of a session (e.g. idle -> recording -> stopped).
Future<void> logLifecycle({
  required String sessionId,
  required String from,
  required String to,
}) => frb.flightLogLifecycle(sessionId: sessionId, from: from, to: to);

/// Periodic segment-production heartbeat (metadata only, no transcript text).
Future<void> logSegmentBatch({
  required String sessionId,
  required BigInt batchSize,
  required BigInt totalSegments,
  required BigInt queueDepth,
}) => frb.flightLogSegmentBatch(
  sessionId: sessionId,
  batchSize: batchSize,
  totalSegments: totalSegments,
  queueDepth: queueDepth,
);

/// Non-fatal error signal (source + capped message, no stack traces).
Future<void> logError({
  required String sessionId,
  required String source,
  required String message,
}) =>
    frb.flightLogError(sessionId: sessionId, source: source, message: message);

/// Auto-stop fired after inactivity.
Future<void> logAutoStop({
  required String sessionId,
  required BigInt minutes,
}) => frb.flightLogAutoStop(sessionId: sessionId, minutes: minutes);

/// Generic system event with optional key/value details (no PII).
Future<void> logSystem(String event, {Map<String, String>? details}) =>
    frb.flightLogSystem(event: event, details: details);

/// Reads the current flight-recorder contents (raw JSONL) for diagnostics.
Future<String> readLog() => frb.flightReadLog();

/// Empties the log file.
Future<void> clearLog() => frb.flightClearLog();

/// Number of entries currently in the log.
Future<int> entryCount() async => (await frb.flightEntryCount()).toInt();
