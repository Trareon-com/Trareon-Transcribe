import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/screens/settings_screen.dart';
import 'package:transcribe/src/rust/disk.dart' as rust_disk;
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;
import 'package:transcribe/src/rust/model.dart' as rust_model;
import 'test_helpers.dart';

class _TestBridge with SummaryBridgeStubs implements RustBridge {
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
  Stream<TranscriptSegment> transcriptStream(String sessionId) =>
      const Stream.empty();
  @override
  Stream<VuLevel> vuMeterStream(String sessionId) => const Stream.empty();

  @override
  Stream<SessionNotice> noticeStream(String sessionId) => const Stream.empty();
  @override
  Stream<String> tentativeStream(String sessionId) => const Stream.empty();

  @override
  Future<List<rust_session.RecoverableSession>>
  listRecoverableSessions() async => const [];

  @override
  Future<rust_session.RecoveredSession> recoverSession(
    rust_session.SessionRecoverySnapshot snapshot,
  ) async => rust_session.RecoveredSession(
    sessionId: 'test-session',
    segments: const [],
    resumeOffsetSecs: 0,
    micAudioSecs: 0,
    speakerAudioSecs: 0,
  );

  @override
  Future<void> deleteRecoverableSession(String sessionId) async {}

  @override
  Future<rust_session.CaptureHealth> captureHealth(String sessionId) async =>
      rust_session.CaptureHealth(
        sessionId: sessionId,
        elapsedSecs: 0,
        segmentCount: 0,
        channels: const [],
        warnings: const [],
      );

  @override
  Future<void> setSessionTitle(String sessionId, String title) async {}

  @override
  Future<rust_disk.DiskSpaceStatus> diskSpace(String path) async =>
      rust_disk.DiskSpaceStatus(
        availableBytes: BigInt.from(64 * 1024 * 1024 * 1024),
        level: rust_disk.DiskSpaceLevel.ok,
        message: '',
      );
  @override
  Future<AppSettings> loadSettings() async => savedSettings;
  @override
  Future<void> saveSettings(AppSettings settings) async {
    savedSettings = settings;
  }

  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {}
  @override
  Future<List<rust_model.ModelInfo>> listAvailableModels(
    String modelsDir,
  ) async => [];
  @override
  Future<bool> isModelDownloaded(String modelsDir, String modelId) async =>
      false;
  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async =>
      const [];

  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async =>
      const [];
  @override
  Future<String> detectFrontmostWindowTitle() async => '';

  @override
  Stream<double> downloadProgress() => const Stream.empty();

  @override
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
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
  Future<List<rust_export.ExportedFile>> exportSessionAudio({
    required String sessionId,
    required String outputDir,
    required String title,
  }) async => [];
  @override
  void pauseSession(String sessionId) {}
  @override
  void resumeSession(String sessionId) {}
}

class _FailingSaveBridge extends _TestBridge {
  bool fail = true;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    if (fail) throw const FileSystemException('read-only file system');
    savedSettings = settings;
  }
}

Widget _host(RustBridge bridge) => ProviderScope(
  overrides: [rustBridgeProvider.overrideWithValue(bridge)],
  child: const MaterialApp(home: SettingsScreen()),
);

void _sizeViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets(
    'two panes: a category list on the left, its content on the right',
    (WidgetTester tester) async {
      _sizeViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(_host(_TestBridge()));
      await tester.pumpAndSettle();

      // Every category is reachable from the rail without scrolling a
      // single long column.
      for (final label in [
        'Tampilan',
        'Model & Mode',
        'Audio & Suara',
        'Penyimpanan',
        'Ringkasan AI',
        'Kepatuhan PDP',
        'Penyiapan & Diagnostik',
        'Tentang',
      ]) {
        expect(find.text(label), findsWidgets, reason: 'rail entry $label');
      }

      // The default pane is Tampilan; Model & Mode is one click away.
      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Model default'), findsNothing);

      await tester.tap(find.text('Model & Mode'));
      await tester.pumpAndSettle();
      expect(find.text('Model default'), findsOneWidget);
      expect(find.text('Bahasa'), findsOneWidget);

      await tester.tap(find.text('Audio & Suara'));
      await tester.pumpAndSettle();
      expect(find.text('Abaikan jeda sunyi'), findsOneWidget);
      expect(find.text('Hapus suara ganda'), findsOneWidget);
    },
  );

  testWidgets('both panes still fit at the 800x600 minimum window', (
    WidgetTester tester,
  ) async {
    _sizeViewport(tester, const Size(800, 600));
    await tester.pumpWidget(_host(_TestBridge()));
    await tester.pumpAndSettle();

    // The rail is a ListView; the last categories may sit below the fold
    // at the minimum window, which is fine as long as they are reachable.
    await tester.ensureVisible(find.text('Penyiapan & Diagnostik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penyiapan & Diagnostik'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnostik'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no overflow at 800x600');
  });

  testWidgets('a very narrow window falls back to a chip strip', (
    WidgetTester tester,
  ) async {
    _sizeViewport(tester, const Size(560, 600));
    await tester.pumpWidget(_host(_TestBridge()));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Audio & Suara'));
    await tester.pumpAndSettle();
    expect(find.text('Abaikan jeda sunyi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the setup wizard and diagnostics are reachable from Settings', (
    WidgetTester tester,
  ) async {
    _sizeViewport(tester, const Size(1440, 900));
    await tester.pumpWidget(_host(_TestBridge()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Penyiapan & Diagnostik'));
    await tester.pumpAndSettle();
    expect(find.text('Jalankan Ulang Penyiapan'), findsOneWidget);

    // The wizard had 935 lines of tested UI and no route into it at all
    // until this sprint (audit A.6-1).
    //
    // Pumped rather than settled: step 1 reads real system specs
    // (/proc/meminfo and friends), and real I/O does not complete inside
    // a widget test's fake-async zone, so its spinner never stops.
    await tester.tap(find.text('Jalankan Ulang Penyiapan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1. Deteksi Spesifikasi'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);

    await tester.tap(find.text('Tutup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Jalankan Ulang Penyiapan'), findsOneWidget);
  });

  testWidgets('a failed save rolls back and says so, with a retry', (
    WidgetTester tester,
  ) async {
    _sizeViewport(tester, const Size(1440, 900));
    final bridge = _FailingSaveBridge();
    await tester.pumpWidget(_host(bridge));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audio & Suara'));
    await tester.pumpAndSettle();

    final before = tester.widget<Switch>(find.byType(Switch).first).value;
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('gagal disimpan'), findsOneWidget);
    expect(
      tester.widget<Switch>(find.byType(Switch).first).value,
      before,
      reason: 'a switch that stays flipped after a failed write is lying',
    );

    // Retry, this time with a working disk.
    bridge.fail = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('gagal disimpan'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, !before);
    expect(bridge.savedSettings.vadEnabled, !before);
  });

  testWidgets('the GPU helper describes the machine, not the switch', (
    WidgetTester tester,
  ) async {
    _sizeViewport(tester, const Size(1440, 900));
    await tester.pumpWidget(_host(_TestBridge()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Model & Mode'));
    await tester.pumpAndSettle();

    // Without the native engine the capability is unknown, so the text
    // must stay conditional instead of asserting "menggunakan GPU".
    expect(find.textContaining('Transkripsi memakai CPU'), findsOneWidget);
    expect(
      find.textContaining('menggunakan GPU (Vulkan/CUDA/Metal)'),
      findsNothing,
    );
  });

  testWidgets('theme dropdown is present', (WidgetTester tester) async {
    _sizeViewport(tester, const Size(1440, 900));
    await tester.pumpWidget(_host(_TestBridge()));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<AppThemeMode>), findsWidgets);
  });
}
