import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/setup_wizard_screen.dart';
import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;
import 'package:transcribe/src/rust/model.dart' as rust_model;

Future<WizardSpecs> _detectSpecs() async => const WizardSpecs(
      cpuCores: 8,
      ramMb: 16384,
      suggestedModel: 'large-v3-turbo-q5',
    );

class _FakeBridge implements RustBridge {
  AppSettings savedSettings = AppSettings.defaults();
  final List<(String, String)> downloadModelCalls = [];

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
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async =>
      'test-session';

  @override
  Future<AppSettings> loadSettings() async => savedSettings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    savedSettings = settings;
  }

  @override
  Future<void> downloadModel(String modelsDir, String modelId) {
    downloadModelCalls.add((modelsDir, modelId));
    return Future.value();
  }

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
  Stream<double> downloadProgress() =>
      Stream.fromIterable([0.0, 0.5, 1.0]);

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
    List<rust_export.ExportFormat> formats = const [],
  }) async => [];
  @override
  Future<void> exportSessionAudio({
    required String sessionId,
    required String outputDir,
    required String title,
  }) async {}
  @override
  Future<void> pauseSession(String sessionId) async {}
  @override
  Future<void> resumeSession(String sessionId) async {}
}

void main() {
  testWidgets('wizard walks through all 4 steps and calls onFinished', (WidgetTester tester) async {
    var finished = false;
    final bridge = _FakeBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: MaterialApp(home: SetupWizardScreen(onFinished: () => finished = true, detectSpecs: _detectSpecs)),
      ),
    );

    // Step 1: spec detection — wait for async detection to complete
    await tester.pumpAndSettle();
    expect(find.text('1. Deteksi Spesifikasi'), findsOneWidget);
    expect(find.text('Selesai'), findsNothing);

    for (final expectedTitle in [
      '2. Pilih Model',
      '3. Setup Audio',
      '4. Tone Test',
    ]) {
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text(expectedTitle), findsOneWidget);
    }

    expect(finished, isFalse);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('back button disabled on first step, enabled after', (WidgetTester tester) async {
    final bridge = _FakeBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: MaterialApp(home: SetupWizardScreen(onFinished: () {}, detectSpecs: _detectSpecs)),
      ),
    );

    // Wait for spec detection to settle, then back button should be disabled on step 1
    await tester.pumpAndSettle();

    final backButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Kembali'));
    expect(backButton.onPressed, isNull);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    final backButtonAfter = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Kembali'));
    expect(backButtonAfter.onPressed, isNotNull);
  });

  testWidgets('selecting a model persists it through the settings provider', (
    WidgetTester tester,
  ) async {
    final bridge = _FakeBridge();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: MaterialApp(
          home: SetupWizardScreen(onFinished: () {}, detectSpecs: _detectSpecs),
        ),
      ),
    );

    // Step 1 → Step 2 (wait for spec detection to finish)
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Step 2: tap the bundled 'large-v3-turbo-q5' model card to change selection
    await tester.tap(find.text('🎯 Akurat'));
    await tester.pumpAndSettle();

    expect(bridge.savedSettings.defaultModel, 'large-v3-turbo-q5');
  });
}
