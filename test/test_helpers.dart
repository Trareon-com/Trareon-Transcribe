import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/screens/main_screen.dart';
import 'package:transcribe/widgets/setup_overlay.dart';
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;

/// Timer-free test double for RustBridge that persists settings in memory
class NoopBridge implements RustBridge {
  NoopBridge();

  AppSettings _storedSettings = AppSettings.defaults();

  @override
  Future<String> startSession(SessionConfig config) async => 'test-session';

  @override
  Future<void> stopSession(String sessionId) async {}

  @override
  Future<void> toggleMic(String sessionId, bool enabled) async {}

  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) async {}

  @override
  Future<double> benchmarkRtf(String modelPath) async => 0.8;

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) => const Stream.empty();

  @override
  Stream<VuLevel> vuMeterStream(String sessionId) => const Stream.empty();

  @override
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions() async => const [];

  @override
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async => 'test-session';

  @override
  Future<AppSettings> loadSettings() async => _storedSettings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _storedSettings = settings;
  }

  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {}

  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => const [];

  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async => const [];

  @override
  Future<String> detectFrontmostWindowTitle() async => '';

  @override
  Stream<double> downloadProgress() => const Stream.empty();

  @override
  Future<List<rust_stt_file.TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
  }) async => [];

  @override
  Future<void> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
      rust_export.ExportFormat.txt,
      rust_export.ExportFormat.json,
    ],
  }) async {}

  @override
  Future<void> exportSessionAudio({
    required String sessionId,
    required String outputDir,
    required String title,
  }) async {}

  @override
  void pauseSession(String sessionId) {}

  @override
  void resumeSession(String sessionId) {}
}

/// Test app that skips SetupOverlay (preflight checks)
/// Use this instead of TranscribeApp in widget tests
Widget buildTestApp({Widget? child}) {
  // Enable test mode to skip preflight checks
  skipPreflightChecks = true;

  return ProviderScope(
    overrides: [
      rustBridgeProvider.overrideWithValue(NoopBridge()),
    ],
    child: MaterialApp(
      title: 'Trareon Transcribe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      home: child ?? const MainScreenTestWrapper(),
    ),
  );
}

/// Wrapper that uses MainScreen but without SetupOverlay
/// This is used for tests that need the main screen without preflight checks
class MainScreenTestWrapper extends StatelessWidget {
  const MainScreenTestWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MainScreen();
  }
}

/// Build a test app with custom overrides
Widget buildTestAppWithOverrides({
  required List<Override> overrides,
  Widget? child,
}) {
  // Enable test mode to skip preflight checks
  skipPreflightChecks = true;

  return ProviderScope(
    overrides: [
      rustBridgeProvider.overrideWithValue(NoopBridge()),
      ...overrides,
    ],
    child: MaterialApp(
      title: 'Trareon Transcribe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      home: child ?? const MainScreenTestWrapper(),
    ),
  );
}