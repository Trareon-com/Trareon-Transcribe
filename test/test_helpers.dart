import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/state/library_model.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/screens/main_screen.dart';
import 'package:transcribe/widgets/setup_overlay.dart';
import 'package:transcribe/src/rust/disk.dart' as rust_disk;
import 'package:transcribe/src/rust/api.dart' as rust_api;
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/actions.dart' as rust_actions;
import 'package:transcribe/src/rust/archive.dart' as rust_archive;
import 'package:transcribe/src/rust/capabilities.dart' as rust_capabilities;
import 'package:transcribe/src/rust/mapreduce.dart' as rust_mapreduce;
import 'package:transcribe/src/rust/provenance.dart' as rust_provenance;
import 'package:transcribe/src/rust/completion.dart' as rust_completion;
import 'package:transcribe/src/rust/coverage.dart' as rust_coverage;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/export/notulen.dart' as rust_notulen;
import 'package:transcribe/src/rust/glossary.dart' as rust_glossary;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;
import 'package:transcribe/src/rust/model.dart' as rust_model;

/// Inert implementations of the bridge methods added for Meetily parity
/// (summary, HPT file import, batch progress).
///
/// Mixed into every `RustBridge` test double so adding a bridge method
/// doesn't mean editing five near-identical fakes. [generateSummary] throws
/// rather than returning a placeholder: the summary path is the only one that
/// can touch the network, so a test that reaches it by accident must fail
/// loudly instead of quietly passing on fabricated Markdown. Individual
/// doubles override whichever members their test actually exercises.
mixin SummaryBridgeStubs {
  Future<List<rust_export.ExportedFile>> exportSessionWithSummary({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    required String summary,
    List<Bookmark> bookmarks = const [],
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
      rust_export.ExportFormat.txt,
      rust_export.ExportFormat.json,
    ],
  }) async => const [];

  Future<rust_api.ProgressiveFileResult> progressiveTranscribeFile({
    required String quickModelPath,
    required String refineModelPath,
    required String path,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    rust_glossary.GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) async => rust_api.ProgressiveFileResult(
    filename: path.split('/').last,
    quickSegments: const [],
    refinedSegments: const [],
    language: language ?? 'auto',
  );

  Future<rust_stt_file.BatchProgressSnapshot?> batchProgress() async => null;

  // ── Transcript completion (ITEM 0) ─────────────────────────────────
  //
  // Inert and "already complete": a test double must never leave the UI
  // in "Menyelesaikan transkrip…" with nothing able to finish it.

  Future<double> audioDurationSecs(String path) async => 0;

  Future<rust_coverage.CoverageReport> transcriptCoverage({
    required List<TranscriptSegment> segments,
    required String audioPath,
  }) async => kCompleteCoverage;

  Future<rust_completion.CompletionOutcome> completeSessionTranscript({
    required String modelPath,
    required String audioPath,
    required String jobKey,
    required List<TranscriptSegment> existing,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    rust_glossary.GlossaryConfig glossary = kEmptyGlossary,
    bool vadEnabled = true,
  }) async => rust_completion.CompletionOutcome(
    segments: existing.map(toRustSegment).toList(),
    added: 0,
    rejected: 0,
    coverage: kCompleteCoverage,
    speechSecs: 0,
    speechCoveredSecs: 0,
    audioSecs: 0,
  );

  Future<List<rust_completion.CompletionProgress>> completionProgress() async =>
      const [];

  // ── Tanya arsip rapat (F12) ────────────────────────────────────────
  //
  // Inert: indexing is a no-op, retrieval finds nothing, and asking a
  // question throws — the archive answer is a networked path, so a test
  // that reaches it by accident must fail loudly.

  Future<bool> archiveIsStale({
    required String libraryPath,
    required String dirPath,
    required int transcriptSize,
    required int transcriptModifiedMs,
  }) async => false;

  Future<int> archiveIndexSession({
    required String libraryPath,
    required String dirPath,
    required String title,
    required String date,
    required List<TranscriptSegment> segments,
    required String summary,
    required int transcriptSize,
    required int transcriptModifiedMs,
  }) async => 0;

  Future<void> archiveForgetSession({
    required String libraryPath,
    required String dirPath,
  }) async {}

  Future<List<rust_archive.ArchiveHit>> archiveSearch({
    required String libraryPath,
    required String question,
    int limit = 12,
  }) async => const [];

  Future<rust_archive.ArchiveStats> archiveStats(String libraryPath) async =>
      rust_archive.ArchiveStats(sessions: 0, passages: 0, bytes: BigInt.zero);

  Future<void> archiveClear(String libraryPath) async {}

  Future<rust_archive.ArchiveAnswer> archiveAsk({
    required String libraryPath,
    required String question,
    required SummaryConfig config,
  }) async =>
      throw UnsupportedError('test bridge does not answer archive questions');

  Future<String> generateSummary({
    required List<TranscriptSegment> segments,
    required SummaryConfig config,
    List<Bookmark> bookmarks = const [],
  }) async => throw UnsupportedError('test bridge does not generate summaries');

  // ── Tindak lanjut & provenans (F6/F7/F15) ──────────────────────────
  //
  // Pure re-reads of a summary, so they are safe to stub as "finds
  // nothing"; the long-meeting path throws for the same reason
  // [generateSummary] does.

  Future<String> generateSummaryLong({
    required List<TranscriptSegment> segments,
    required SummaryConfig config,
    List<Bookmark> bookmarks = const [],
  }) async => throw UnsupportedError('test bridge does not generate summaries');

  Future<rust_mapreduce.MapReduceProgress?> summaryProgress() async => null;

  Future<List<rust_capabilities.Capability>> describeCapabilities(
    AppSettings settings,
  ) async => const [];

  Future<List<rust_actions.ActionItem>> parseActionItems(
    String summary,
  ) async => const [];

  Future<String> stripActionItemsBlock(String summary) async => summary;

  Future<String> actionItemsToIcs({
    required List<rust_actions.ActionItem> items,
    required String calendarName,
    required String today,
  }) async => 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n';

  Future<String> actionItemsToCsv(List<rust_actions.ActionItem> items) async =>
      '';

  Future<rust_provenance.SummaryProvenance> summaryProvenance({
    required String summary,
    required List<TranscriptSegment> segments,
    bool verify = true,
  }) async => const rust_provenance.SummaryProvenance(lines: [], dropped: 0);

  Future<List<String>> listSummaryModels({
    required SummaryProvider provider,
    required String baseUrl,
    required String apiKey,
  }) async => const [];

  Future<String> summaryPreviewTranscript(
    List<TranscriptSegment> segments,
  ) async => segments.map((s) => '${s.speaker}: ${s.text}').join('\n');

  // ── Sprint 3 surface: notulen, kamus istilah, templates, diagnostics ──
  //
  // All inert. A test that needs real behaviour overrides the one method it
  // exercises; everything else must be impossible to depend on by accident.

  Future<rust_export.ExportedFile> exportNotulen({
    required rust_notulen.NotulenForm form,
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
  }) async => rust_export.ExportedFile(
    filename: 'Notulen - $title.docx',
    path: '$outputDir/Notulen - $title.docx',
    sizeBytes: BigInt.from(2048),
  );

  Future<rust_notulen.NotulenDraft> notulenDraftFromSummary(
    String summary,
  ) async => rust_notulen.NotulenDraft(
    pembahasan: summary,
    keputusan: const [],
    tindakLanjut: const [],
    peserta: const [],
  );

  Future<rust_api.GlossaryPromptInfo> glossaryPromptPreview({
    required rust_glossary.GlossaryConfig glossary,
    String contextTail = '',
  }) async {
    final terms = [
      ...glossary.sessionTerms,
      ...glossary.globalTerms,
    ].where((t) => t.trim().isNotEmpty).toList();
    return rust_api.GlossaryPromptInfo(
      prompt: terms.isEmpty ? contextTail : 'Istilah: ${terms.join(', ')}.',
      termsUsed: terms.length,
      termsTotal: terms.length,
    );
  }

  Future<List<String>> parseGlossaryFile(String content) async => content
      .split('\n')
      .map((line) => line.split(',').first.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();

  Future<String> renderGlossaryFile(
    List<String> terms, {
    bool csv = false,
  }) async => '${csv ? 'istilah\n' : ''}${terms.join('\n')}\n';

  Future<List<String>> summaryTemplateHeadings(
    SummaryTemplate template,
  ) async => const ['Ringkasan', 'Keputusan'];

  Future<String> composeSummaryInstruction({
    required String instructions,
    required List<String> headings,
  }) async => headings.isEmpty
      ? instructions
      : '$instructions\n\n${headings.map((h) => '## $h').join('\n')}';

  Future<String> exportDiagnostics({
    required String destination,
    required String doctorReport,
    required String environment,
  }) async => destination;

  Future<int> diagnosticLogFileCount() async => 1;

  Future<List<String>> formatBookmarks(List<Bookmark> bookmarks) async => [
    for (final bookmark in bookmarks)
      '[${(bookmark.timestamp ~/ 60).toString().padLeft(2, '0')}:'
          '${(bookmark.timestamp % 60).floor().toString().padLeft(2, '0')}] '
          '${bookmark.note.trim().isEmpty ? 'Poin penting' : bookmark.note.trim()}',
  ];
}

/// Timer-free test double for RustBridge that persists settings in memory
class NoopBridge with SummaryBridgeStubs implements RustBridge {
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
  Future<AppSettings> loadSettings() async => _storedSettings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _storedSettings = settings;
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
    rust_glossary.GlossaryConfig glossary = kEmptyGlossary,
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

/// Test app that skips SetupOverlay (preflight checks)
/// Use this instead of TranscribeApp in widget tests
Widget buildTestApp({Widget? child, ThemeMode themeMode = ThemeMode.light}) {
  // Enable test mode to skip preflight checks
  skipPreflightChecks = true;

  return ProviderScope(
    overrides: [
      rustBridgeProvider.overrideWithValue(NoopBridge()),
      // The sidebar reads the session index off disk; real I/O never
      // completes inside a widget test's fake-async zone.
      libraryListProvider.overrideWith(
        (ref) => LibraryListNotifier.seeded(const []),
      ),
    ],
    child: MaterialApp(
      title: 'Trareon Transcribe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
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
      libraryListProvider.overrideWith(
        (ref) => LibraryListNotifier.seeded(const []),
      ),
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
