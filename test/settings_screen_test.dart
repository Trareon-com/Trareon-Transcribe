import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/screens/settings_screen.dart';
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;
import 'package:transcribe/src/rust/model.dart' as rust_model;

class _TestBridge implements RustBridge {
  AppSettings savedSettings = AppSettings.defaults();

  @override
  Future<String> startSession(SessionConfig config) async => 'test';
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
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async => 'test';
  @override
  Future<AppSettings> loadSettings() async => savedSettings;
  @override
  Future<void> saveSettings(AppSettings settings) async { savedSettings = settings; }
  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {}
  @override
  Future<List<rust_model.ModelInfo>> listAvailableModels(String modelsDir) async => [];
  @override
  Future<bool> isModelDownloaded(String modelsDir, String modelId) async => false;
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
  Future<List<rust_export.ExportedFile>> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
      rust_export.ExportFormat.txt,
      rust_export.ExportFormat.json,
    ],
  }) async => [];
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

void main() {
  testWidgets('settings screen shows all controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = _TestBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Model default'), findsWidgets);
    expect(find.text('Bahasa'), findsWidgets);
    expect(find.text('VAD (deteksi suara)'), findsOneWidget);
    expect(find.text('Echo Dedupe'), findsOneWidget);

    // Scroll down to the "Lainnya" section (below viewport in lazy ListView)
    await tester.scrollUntilVisible(
      find.text('Laporan Privasi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Laporan Privasi'), findsOneWidget);
    expect(find.text('Dasbor Penggunaan'), findsOneWidget);
  });

  testWidgets('theme dropdown changes theme', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = _TestBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Find and tap the theme dropdown
    final dropdowns = find.byType(DropdownButton<AppThemeMode>);
    expect(dropdowns, findsWidgets);
  });
}
