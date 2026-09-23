//! Trareon Transcribe Integration Tests — Full Stack (Dart + Rust via FRB)
//!
//! These tests exercise the application end-to-end using the real
//! flutter_rust_bridge bindings (not mock/stub). They require:
//!   1. `librust_core.dylib` compiled (cargo build --release --lib)
//!   2. Flutter desktop device (macOS for local)
//!
//! Run:
//!   cd rust_core && cargo build --release --lib && cd ..
//!   flutter test integration_test/ -d macos
//!
//! FRB handles Rust library loading automatically during flutter test.

import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:transcribe/src/rust/api.dart' as rust_api;
import 'package:transcribe/src/rust/audio.dart' as rust_audio;
import 'package:transcribe/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize the Rust bridge. The macOS app bundles librust_core.dylib
    // into Contents/Frameworks during the integration-test build. Resolve it
    // from the test host's own executable (Platform.resolvedExecutable) so
    // the path stays inside the app bundle — the sandbox blocks dlopen() on
    // anything outside it (verified: "file system sandbox blocked open()").
    final exe = File(Platform.resolvedExecutable).absolute;
    final bundleRoot = exe.path
        .split(Platform.pathSeparator)
        .takeWhile((s) => s != 'Contents')
        .join(Platform.pathSeparator);
    final dylib = '$bundleRoot/Contents/Frameworks/librust_core.dylib';
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(dylib),
    );
  });

  // ── Layer 3: Full Stack — Rust Engine Health ──────────────────────
  group('Rust Engine (direct FRB)', () {
    test('engine version is non-empty', () async {
      final version = await rust_api.engineVersion();
      expect(version, isNotEmpty);
      debugPrint('  Engine version: $version');
    });

    test('health check returns true', () async {
      final ok = await rust_api.healthCheck();
      expect(ok, isTrue);
    });

    test('settings roundtrip', () async {
      final settings = await rust_api.loadSettings();
      expect(settings.defaultModel, isNotEmpty);
      expect(settings.libraryPath, isNotEmpty);
      debugPrint('  Default model: ${settings.defaultModel}');
      debugPrint('  Library path: ${settings.libraryPath}');
    });

    test('model list includes tiny', () async {
      final models = await rust_api.listAvailableModels(
        modelsDir: Platform.environment['HOME']!,
      );
      expect(models.any((m) => m.id == 'tiny'), isTrue);
    });

    test('session lifecycle (start → status → stop)', () async {
      final config = rust_audio.SessionConfig(
        micEnabled: false,
        speakerEnabled: false,
        mode: rust_audio.SessionMode.offline,
        modelPath: 'tiny', // will not load — capture is disabled
        hptMode: rust_audio.HptMode.auto,
        gpuEnabled: false,
        gpuDevice: 0,
        vadEnabled: true,
        sampleRate: 16000,
        chunkDurationSecs: 30,
      );
      final sessionId = await rust_api.startSession(config: config);
      expect(sessionId, isNotEmpty);

      final status = await rust_api.getSessionStatus(sessionId: sessionId);
      expect(status.sessionId, sessionId);

      await rust_api.stopSession(sessionId: sessionId);
    });
  });

  // ── Layer 3: Full Stack — Audio Pipeline ──────────────────────────
  group('Audio Pipeline', () {
    test('list audio devices does not error', () async {
      final devices = await rust_api.listAudioDevices();
      // On CI, there may be no devices; on a real Mac there will be.
      // The important thing is the call doesn't crash or error.
      debugPrint('  Found ${devices.length} audio device(s)');
    });
  });
}
