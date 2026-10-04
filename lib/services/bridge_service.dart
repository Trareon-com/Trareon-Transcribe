import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../src/rust/actions.dart' as rust_actions;
import '../src/rust/api.dart' as rust_api;
import '../src/rust/archive.dart' as rust_archive;
import '../src/rust/capabilities.dart' as rust_capabilities;
import '../src/rust/audio.dart' as rust_audio;
import '../src/rust/audio/device.dart' as rust_device;
import '../src/rust/completion.dart' as rust_completion;
import '../src/rust/coverage.dart' as rust_coverage;
import '../src/rust/disk.dart' as rust_disk;
import '../src/rust/export.dart' as rust_export;
import '../src/rust/export/notulen.dart' as rust_notulen;
import '../src/rust/glossary.dart' as rust_glossary;
import '../src/rust/mapreduce.dart' as rust_mapreduce;
import '../src/rust/model.dart' as rust_model;
import '../src/rust/provenance.dart' as rust_provenance;
import '../src/rust/session.dart' as rust_session;
import '../src/rust/settings.dart' as rust_settings;
import '../src/rust/stt/file.dart' as rust_stt_file;
import '../src/rust/summary.dart' as rust_summary;
import '../state/models.dart';

/// Abstraction over the Rust engine, callable from Dart. [RustEngineBridge]
/// is the real flutter_rust_bridge-backed implementation; [RustBridgeMock]
/// is a timer-driven stand-in used by default in tests and available for
/// UI work that doesn't need a live Rust build.
abstract class RustBridge {
  Future<String> startSession(SessionConfig config);
  Future<void> stopSession(String sessionId);
  Future<void> toggleMic(String sessionId, bool enabled);
  Future<void> toggleSpeaker(String sessionId, bool enabled);
  Stream<TranscriptSegment> transcriptStream(String sessionId);
  Stream<VuLevel> vuMeterStream(String sessionId);

  /// Capture problems the engine reports mid-session — a source that could
  /// not be opened at start, or one that died while recording. Surfaced as a
  /// toast; without it a half-dead session looks identical to a quiet one.
  Stream<SessionNotice> noticeStream(String sessionId);
  /// Sessions left behind by a crash, each with what is actually
  /// recoverable for it (segment count, audio seconds per source) rather
  /// than just the configuration the snapshot stored.
  Future<List<rust_session.RecoverableSession>> listRecoverableSessions();

  /// Restores a crashed session and resumes capture into its files.
  /// Returns the recovered transcript along with the new session id.
  Future<rust_session.RecoveredSession> recoverSession(
    rust_session.SessionRecoverySnapshot snapshot,
  );

  /// Discards one recoverable session and everything it held.
  Future<void> deleteRecoverableSession(String sessionId);

  /// How much audio each source has actually delivered, whether it has
  /// ever been above the noise floor, and how long it has been quiet.
  /// Drives the live "rekaman terkonfirmasi" indicator and the integrity
  /// summary shown at Stop.
  Future<rust_session.CaptureHealth> captureHealth(String sessionId);

  /// Mirrors the session title into the recovery snapshot, so a crashed
  /// session shows up in the recovery dialog under its name.
  Future<void> setSessionTitle(String sessionId, String title);

  /// Free space on the volume holding [path], and whether that is enough
  /// to keep recording. Three hours of "Rapat Online" is ~1.4 GB of WAV.
  Future<rust_disk.DiskSpaceStatus> diskSpace(String path);
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<void> downloadModel(String modelsDir, String modelId);

  /// The pinned Whisper model catalog. Each entry's `sizeBytes` reflects the
  /// file's current on-disk size under [modelsDir] (0 if not yet downloaded).
  Future<List<rust_model.ModelInfo>> listAvailableModels(String modelsDir);

  /// Whether [modelId]'s file already exists under [modelsDir].
  Future<bool> isModelDownloaded(String modelsDir, String modelId);
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices();
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices();

  /// On macOS, returns the title of the frontmost window (e.g. a browser tab
  /// or meeting app name) via AppleScript. Falls back to empty string on
  /// other platforms or if detection fails.
  Future<String> detectFrontmostWindowTitle();

  /// Polls download progress for an active model download.
  /// Returns a stream of 0.0–1.0 ratios. Completes when progress reaches 1.0.
  /// The caller must start the download via [downloadModel] first.
  Stream<double> downloadProgress();

  /// Transcribes every file in [files] against a single loaded model.
  ///
  /// Pass the whole queue in one call: loading the model is the expensive
  /// step, so a per-file loop pays it once per file. Returns one outcome per
  /// input file, carrying either the transcript or the error.
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    rust_glossary.GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  });

  /// Writes [segments] to `outputDir/<sanitized title>/` in the requested
  /// [formats]. Each format is a member of [rust_export.ExportFormat].
  /// Defaults to [markdown, txt, json] when empty. Returns the files that
  /// were actually written, whose paths reveal the real (date-prefixed,
  /// sanitized) session directory the Rust side created.
  Future<List<rust_export.ExportedFile>> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
      rust_export.ExportFormat.txt,
      rust_export.ExportFormat.json,
    ],
  });

  /// Places the mic/speaker audio captured during [sessionId]'s live
  /// recording as `mic.wav`/`speaker.wav` in the same session folder
  /// [exportSession] uses for this `outputDir`/`title`. Call once, after
  /// [stopSession] — the audio is only retained until the first call for a
  /// given session. Returns an empty list (not an error) when there was no
  /// live capture to save, e.g. a batch-file transcription.
  Future<List<rust_export.ExportedFile>> exportSessionAudio({
    required String sessionId,
    required String outputDir,
    required String title,
  });

  /// Prevents transcript and VU events from being forwarded to the Dart
  /// stream controllers during a pause. The Rust-side poll keeps draining the
  /// mpsc channel (preventing overflow) but events are silently discarded.
  void pauseSession(String sessionId);

  /// Resumes event forwarding for a previously-paused session.
  void resumeSession(String sessionId);

  /// Benchmarks a model's realtime factor (seconds-audio-per-second-wallclock)
  /// by transcribing a 5s synthetic sine wave. Used by adaptive HPT at startup.
  /// Throws if the model cannot be loaded.
  Future<double> benchmarkRtf(String modelPath);

  /// Two-pass (HPT) transcription of a single file: a quick pass from the
  /// base model, then a refined pass from large-v3-turbo-q5 carrying the same
  /// `(source, timestamp)` keys. Used by file import when Progressive Mode is
  /// on and both models are present.
  Future<rust_api.ProgressiveFileResult> progressiveTranscribeFile({
    required String quickModelPath,
    required String refineModelPath,
    required String path,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    rust_glossary.GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  });

  /// Which file the in-flight [batchTranscribeFiles] call is currently on.
  /// `null` when no batch is running. [batchTranscribeFiles] only returns
  /// once every file is done, so this is the only way to show real progress.
  Future<rust_stt_file.BatchProgressSnapshot?> batchProgress();

  // ── Transcript completion (ITEM 0) ─────────────────────────────────
  //
  // The live worker can fall behind the meeting on a slow device, and Stop
  // cannot wait for it. What it never reached is transcribed afterwards
  // from the saved WAV. Entirely local.

  /// Length of an audio file in seconds, from its header where possible.
  Future<double> audioDurationSecs(String path);

  /// What [segments] account for across `audioPath`, and what they miss.
  /// No inference; this runs on every session save.
  Future<rust_coverage.CoverageReport> transcriptCoverage({
    required List<TranscriptSegment> segments,
    required String audioPath,
  });

  /// Transcribes the stretches of [audioPath] that [existing] does not
  /// cover and returns the merged transcript. Long-running; poll
  /// [completionProgress] while it is in flight.
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
  });

  /// Per-source progress of every completion pass currently running.
  Future<List<rust_completion.CompletionProgress>> completionProgress();

  // ── Tanya arsip rapat (F12) ────────────────────────────────────────
  //
  // Indexing and retrieval are local. Only [archiveAsk] leaves the
  // machine, and only with the passages retrieval already selected.

  Future<bool> archiveIsStale({
    required String libraryPath,
    required String dirPath,
    required int transcriptSize,
    required int transcriptModifiedMs,
  });

  Future<int> archiveIndexSession({
    required String libraryPath,
    required String dirPath,
    required String title,
    required String date,
    required List<TranscriptSegment> segments,
    required String summary,
    required int transcriptSize,
    required int transcriptModifiedMs,
  });

  Future<void> archiveForgetSession({
    required String libraryPath,
    required String dirPath,
  });

  /// Ranked passages for a question. No network.
  Future<List<rust_archive.ArchiveHit>> archiveSearch({
    required String libraryPath,
    required String question,
    int limit = 12,
  });

  Future<rust_archive.ArchiveStats> archiveStats(String libraryPath);

  Future<void> archiveClear(String libraryPath);

  /// **Networked**, to the configured summary endpoint only. Sends the
  /// retrieved passages and the question; nothing else.
  Future<rust_archive.ArchiveAnswer> archiveAsk({
    required String libraryPath,
    required String question,
    required rust_summary.SummaryConfig config,
  });

  // ── Tindak lanjut & provenans ringkasan (F6/F7/F15) ───────────────
  //
  // All pure and local: these only re-read a summary the endpoint has
  // already returned. [generateSummaryLong] is the exception and is as
  // networked as [generateSummary].

  /// **Networked.** As [generateSummary], but splits a meeting too long
  /// for one request into time windows and reduces the partials (F15).
  Future<String> generateSummaryLong({
    required List<TranscriptSegment> segments,
    required rust_summary.SummaryConfig config,
    List<Bookmark> bookmarks = const [],
  });

  /// How far a map-reduce summary has got, or null when none is running.
  Future<rust_mapreduce.MapReduceProgress?> summaryProgress();

  /// The tugas / PJ / tenggat / status rows in a summary (F6).
  Future<List<rust_actions.ActionItem>> parseActionItems(String summary);

  /// Drops the machine-readable JSON block once it has been parsed, so
  /// the rendered summary does not show it under the checklist.
  Future<String> stripActionItemsBlock(String summary);

  /// RFC 5545 calendar: one VTODO per task, plus a VEVENT per resolvable
  /// deadline. [today] is `YYYY-MM-DD` and resolves "Jumat"/"besok".
  Future<String> actionItemsToIcs({
    required List<rust_actions.ActionItem> items,
    required String calendarName,
    required String today,
  });

  Future<String> actionItemsToCsv(List<rust_actions.ActionItem> items);

  /// Summary split into lines with each `[#n]` resolved to a timestamp,
  /// invalid ids dropped and counted (F7).
  Future<rust_provenance.SummaryProvenance> summaryProvenance({
    required String summary,
    required List<TranscriptSegment> segments,
    bool verify = true,
  });

  /// **The only networked call in the app.** Sends the rendered transcript
  /// text (never audio, never paths) to the user-configured endpoint and
  /// returns Markdown. Runs only on an explicit user action.
  Future<String> generateSummary({
    required List<TranscriptSegment> segments,
    required rust_summary.SummaryConfig config,
    List<Bookmark> bookmarks = const [],
  });

  /// Every capability, where it runs and whether it is on (F14).
  ///
  /// Comes from the same list `rust_core/src/privacy.rs` checks against
  /// the source, so the screen cannot drift from what the code does.
  /// Local and pure.
  Future<List<rust_capabilities.Capability>> describeCapabilities(
    AppSettings settings,
  );

  /// Lists models offered by the configured summary endpoint. Sends no
  /// transcript content — used to populate the settings dropdown.
  Future<List<String>> listSummaryModels({
    required rust_summary.SummaryProvider provider,
    required String baseUrl,
    required String apiKey,
  });

  /// Renders [segments] exactly as [generateSummary] would transmit them, so
  /// the user can review what would leave the machine before opting in.
  /// Local only.
  Future<String> summaryPreviewTranscript(List<TranscriptSegment> segments);

  /// As [exportSession], but leads the Markdown/TXT/HTML/DOCX output with
  /// [summary]. An empty [summary] behaves exactly like [exportSession].
  Future<List<rust_export.ExportedFile>> exportSessionWithSummary({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    required String summary,
    List<Bookmark> bookmarks,
    List<rust_export.ExportFormat> formats,
  });

  /// Writes the official "Notulen Rapat" DOCX (F2) into the session folder.
  /// `form.variant` chooses "Notulen Dinas" or "Notulen Ringkas".
  Future<rust_export.ExportedFile> exportNotulen({
    required rust_notulen.NotulenForm form,
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
  });

  /// Parses an AI summary into the notulen form's body sections. Local only.
  Future<rust_notulen.NotulenDraft> notulenDraftFromSummary(String summary);

  /// Renders bookmarks as the `"[mm:ss] catatan"` lines every export and the
  /// notulen's "Poin Penting" section use.
  Future<List<String>> formatBookmarks(List<Bookmark> bookmarks);

  /// Kamus istilah helpers — all pure and local.
  Future<rust_api.GlossaryPromptInfo> glossaryPromptPreview({
    required rust_glossary.GlossaryConfig glossary,
    String contextTail = '',
  });
  Future<List<String>> parseGlossaryFile(String content);
  Future<String> renderGlossaryFile(List<String> terms, {bool csv = false});

  /// Section headings a built-in summary template asks for — the starting
  /// point when the user duplicates it (F8).
  Future<List<String>> summaryTemplateHeadings(rust_summary.SummaryTemplate template);

  /// Composes a user template's instruction from its prose plus its headings.
  Future<String> composeSummaryInstruction({
    required String instructions,
    required List<String> headings,
  });

  /// Packs "Ekspor Log Diagnostik": rotated logs + doctor report as a .zip.
  /// Contains no transcript text and no audio.
  Future<String> exportDiagnostics({
    required String destination,
    required String doctorReport,
    required String environment,
  });

  /// How many flight-recorder files (active + rotated) an export would carry.
  Future<int> diagnosticLogFileCount();
}

/// A glossary that changes nothing — the default for every call site that
/// does not opt in.
const rust_glossary.GlossaryConfig kEmptyGlossary = rust_glossary.GlossaryConfig(
  sessionTerms: [],
  globalTerms: [],
  postCorrection: false,
);

/// "Nothing is missing." Used by every bridge that does no real coverage
/// check, so a stand-in can never leave the UI stuck at "Menyelesaikan
/// transkrip…" with nothing able to finish it.
const rust_coverage.CoverageReport kCompleteCoverage =
    rust_coverage.CoverageReport(
  coveredSecs: 0,
  totalSecs: 0,
  fraction: 1,
  gaps: [],
  missingSecs: 0,
);

/// Shared conversion so every bridge method sends the same Segment shape.
rust_export.Segment toRustSegment(TranscriptSegment s) => rust_export.Segment(
  source: s.source,
  speaker: s.speaker,
  text: s.text,
  timestamp: s.timestamp,
  duration: s.duration,
  language: s.language,
  confidence: s.confidence,
  isPartial: s.isPartial,
  lowConfidence: s.lowConfidence,
  avgLogProb: s.avgLogProb,
);

/// Appearance preference, Dart -> Rust.
///
/// Top-level (like [toRustSegment]) so the mapping is directly testable:
/// "Sistem" used to collapse to `Light` on the way out and come back as
/// "Terang" after every restart, and nothing could see that happen.
rust_settings.Theme toRustTheme(AppThemeMode mode) => switch (mode) {
  AppThemeMode.light => rust_settings.Theme.light,
  AppThemeMode.dark => rust_settings.Theme.dark,
  AppThemeMode.system => rust_settings.Theme.system,
};

/// Inverse of [toRustTheme].
AppThemeMode fromRustTheme(rust_settings.Theme theme) => switch (theme) {
  rust_settings.Theme.light => AppThemeMode.light,
  rust_settings.Theme.dark => AppThemeMode.dark,
  rust_settings.Theme.system => AppThemeMode.system,
};

/// Turns repeated `(downloaded, total)` polls into a 0..1 progress stream.
///
/// Top-level and parameterised over the reader (like [toRustSegment]) so the
/// part with the bug is directly testable without the native library.
///
/// The timer has to die when the consumer stops listening *or* when the
/// controller closes, and `onCancel` only covers the first. A download that
/// is cancelled, fails, or stalls never reaches ratio 1.0 — [readProgress]
/// simply keeps returning null or a partial ratio — so the old version left
/// `Timer.periodic` calling into Rust five times a second for the rest of
/// the app's life, with a `StreamController` nobody would ever close.
///
/// There are two `isClosed` checks because the tick body awaits: the
/// controller can be closed while [readProgress] is in flight, and `add()`
/// on a closed controller throws.
Stream<double> pollDownloadProgress(
  Future<(BigInt, BigInt)?> Function() readProgress, {
  Duration interval = const Duration(milliseconds: 200),
}) {
  late final StreamController<double> controller;
  Timer? timer;
  controller = StreamController<double>(onCancel: () => timer?.cancel());
  timer = Timer.periodic(interval, (t) async {
    if (controller.isClosed) {
      t.cancel();
      return;
    }
    final progress = await readProgress();
    if (progress == null) return;
    final downloaded = progress.$1;
    final total = progress.$2;
    if (total == BigInt.zero) return;
    final ratio = downloaded.toDouble() / total.toDouble();
    if (controller.isClosed) {
      t.cancel();
      return;
    }
    controller.add(ratio);
    if (ratio >= 1.0) {
      t.cancel();
      await controller.close();
    }
  });
  return controller.stream;
}

/// Inverse of [toRustSegment].
TranscriptSegment fromRustSegment(rust_export.Segment s) => TranscriptSegment(
  source: s.source,
  speaker: s.speaker,
  text: s.text,
  timestamp: s.timestamp,
  duration: s.duration,
  language: s.language,
  confidence: s.confidence,
  isPartial: s.isPartial,
  lowConfidence: s.lowConfidence,
  avgLogProb: s.avgLogProb,
);

class RustBridgeMock implements RustBridge {
  final _random = Random();
  final Map<String, StreamController<TranscriptSegment>> _transcriptControllers = {};
  final Map<String, StreamController<VuLevel>> _vuControllers = {};
  final Map<String, StreamController<SessionNotice>> _noticeControllers = {};
  final Map<String, Timer> _timers = {};
  AppSettings _settings = AppSettings.defaults();

  @override
  Future<String> startSession(SessionConfig config) async {
    final id = 'mock-session-${DateTime.now().millisecondsSinceEpoch}';
    final transcriptController = StreamController<TranscriptSegment>.broadcast();
    final vuController = StreamController<VuLevel>.broadcast();
    _transcriptControllers[id] = transcriptController;
    _vuControllers[id] = vuController;
    _noticeControllers[id] = StreamController<SessionNotice>.broadcast();

    var elapsed = 0.0;
    _timers[id] = Timer.periodic(const Duration(milliseconds: 500), (_) {
      elapsed += 0.5;
      vuController.add(
        VuLevel(micLevel: _random.nextDouble(), speakerLevel: _random.nextDouble()),
      );
      if (elapsed.toInt() % 3 == 0) {
        transcriptController.add(
          TranscriptSegment(
            source: config.micEnabled ? 'mic' : 'spk',
            speaker: config.micEnabled ? 'MIC' : 'SPK',
            text: 'Contoh transkrip pada detik ke-${elapsed.toInt()}.',
            timestamp: elapsed,
            duration: 2.0,
            language: 'id',
            confidence: 0.92,
            isPartial: false,
            lowConfidence: false,
          ),
        );
      }
    });

    return id;
  }

  @override
  Future<void> stopSession(String sessionId) async {
    _timers.remove(sessionId)?.cancel();
    await _transcriptControllers.remove(sessionId)?.close();
    await _vuControllers.remove(sessionId)?.close();
    await _noticeControllers.remove(sessionId)?.close();
  }

  @override
  Future<void> toggleMic(String sessionId, bool enabled) async {}

  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) async {}

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) {
    return _transcriptControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Stream<VuLevel> vuMeterStream(String sessionId) {
    return _vuControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Stream<SessionNotice> noticeStream(String sessionId) {
    return _noticeControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Future<List<rust_session.RecoverableSession>> listRecoverableSessions() async =>
      const [];

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

  /// The mock never touches the filesystem, so it reports plenty of room
  /// rather than blocking a UI test on the host machine's free space.
  @override
  Future<rust_disk.DiskSpaceStatus> diskSpace(String path) async =>
      rust_disk.DiskSpaceStatus(
        availableBytes: BigInt.from(64 * 1024 * 1024 * 1024),
        level: rust_disk.DiskSpaceLevel.ok,
        message: '',
      );

  @override
  Future<rust_session.RecoveredSession> recoverSession(
    rust_session.SessionRecoverySnapshot snapshot,
  ) async {
    final id = await startSession(
      SessionConfig(
        micEnabled: snapshot.config.micEnabled,
        speakerEnabled: snapshot.config.speakerEnabled,
        mode: switch (snapshot.config.mode) {
          rust_audio.SessionMode.webinar => SessionMode.webinar,
          rust_audio.SessionMode.online => SessionMode.online,
          rust_audio.SessionMode.offline => SessionMode.offline,
        },
        modelPath: snapshot.config.modelPath,
        vadEnabled: snapshot.config.vadEnabled,
      ),
    );
    return rust_session.RecoveredSession(
      sessionId: id,
      segments: const [],
      resumeOffsetSecs: 0,
      micAudioSecs: 0,
      speakerAudioSecs: 0,
    );
  }

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {}

  @override
  Future<List<rust_model.ModelInfo>> listAvailableModels(String modelsDir) async => [
        rust_model.ModelInfo(
          id: 'base',
          name: 'base (ggml-base.bin)',
          url: '',
          sha256: '',
          sizeBytes: BigInt.from(148897024),
          minRamGb: 1,
          isBundled: true,
        ),
        rust_model.ModelInfo(
          id: 'large-v3-turbo-q5',
          name: 'large-v3-turbo-q5 (ggml-large-v3-turbo-q5_0.bin)',
          url: '',
          sha256: '',
          sizeBytes: BigInt.from(574619648),
          minRamGb: 4,
          isBundled: true,
        ),
      ];

  @override
  Future<bool> isModelDownloaded(String modelsDir, String modelId) async => false;

  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => [
        rust_device.AudioDeviceInfo(
          name: 'Built-in Microphone',
          deviceId: 'mic-1',
          isDefault: true,
          channels: 1,
          sampleRates: Uint32List.fromList([16000, 44100, 48000]),
        ),
      ];

  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async => [
        rust_device.AudioDeviceInfo(
          name: 'Built-in Speakers',
          deviceId: 'spk-1',
          isDefault: true,
          channels: 2,
          sampleRates: Uint32List.fromList([16000, 44100, 48000]),
        ),
        rust_device.AudioDeviceInfo(
          name: 'BlackHole 2ch',
          deviceId: 'spk-2',
          isDefault: false,
          channels: 2,
          sampleRates: Uint32List.fromList([16000, 44100, 48000]),
        ),
      ];

  @override
  Future<String> detectFrontmostWindowTitle() async => ''; // Mock: no real window detection

  @override
  Stream<double> downloadProgress() =>
      Stream.periodic(const Duration(milliseconds: 300), (i) => (i + 1) / 10.0).take(10);

  @override
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    rust_glossary.GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) async => []; // Mock: returns empty results

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

  @override
  Future<double> benchmarkRtf(String modelPath) async => 0.8;

  @override
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
  }) async => [];

  @override
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
    filename: path.split(Platform.pathSeparator).last,
    quickSegments: const [],
    refinedSegments: const [],
    language: language ?? 'auto',
  );

  @override
  Future<rust_stt_file.BatchProgressSnapshot?> batchProgress() async => null;

  @override
  Future<double> audioDurationSecs(String path) async => 0;

  /// Mock sessions are always complete: a stand-in bridge must never put the
  /// UI into "Menyelesaikan transkrip…" with nothing able to finish it.
  @override
  Future<rust_coverage.CoverageReport> transcriptCoverage({
    required List<TranscriptSegment> segments,
    required String audioPath,
  }) async => kCompleteCoverage;

  @override
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

  @override
  Future<List<rust_completion.CompletionProgress>> completionProgress() async =>
      const [];

  @override
  Future<bool> archiveIsStale({
    required String libraryPath,
    required String dirPath,
    required int transcriptSize,
    required int transcriptModifiedMs,
  }) async => false;

  @override
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

  @override
  Future<void> archiveForgetSession({
    required String libraryPath,
    required String dirPath,
  }) async {}

  @override
  Future<List<rust_archive.ArchiveHit>> archiveSearch({
    required String libraryPath,
    required String question,
    int limit = 12,
  }) async => const [];

  @override
  Future<rust_archive.ArchiveStats> archiveStats(String libraryPath) async =>
      rust_archive.ArchiveStats(sessions: 0, passages: 0, bytes: BigInt.zero);

  @override
  Future<void> archiveClear(String libraryPath) async {}

  @override
  Future<rust_archive.ArchiveAnswer> archiveAsk({
    required String libraryPath,
    required String question,
    required rust_summary.SummaryConfig config,
  }) async =>
      throw UnsupportedError('RustBridgeMock does not answer archive questions');

  /// The mock never performs I/O of any kind — a test that reaches the
  /// summary path must fail loudly rather than silently hit a real endpoint.
  @override
  Future<String> generateSummary({
    required List<TranscriptSegment> segments,
    required rust_summary.SummaryConfig config,
    List<Bookmark> bookmarks = const [],
  }) async =>
      throw UnsupportedError('RustBridgeMock does not generate summaries');

  @override
  Future<String> generateSummaryLong({
    required List<TranscriptSegment> segments,
    required rust_summary.SummaryConfig config,
    List<Bookmark> bookmarks = const [],
  }) async =>
      throw UnsupportedError('RustBridgeMock does not generate summaries');

  @override
  Future<List<rust_capabilities.Capability>> describeCapabilities(
    AppSettings settings,
  ) async => const [];

  @override
  Future<rust_mapreduce.MapReduceProgress?> summaryProgress() async => null;

  @override
  Future<List<rust_actions.ActionItem>> parseActionItems(
    String summary,
  ) async => const [];

  @override
  Future<String> stripActionItemsBlock(String summary) async => summary;

  @override
  Future<String> actionItemsToIcs({
    required List<rust_actions.ActionItem> items,
    required String calendarName,
    required String today,
  }) async => 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n';

  @override
  Future<String> actionItemsToCsv(
    List<rust_actions.ActionItem> items,
  ) async => '';

  @override
  Future<rust_provenance.SummaryProvenance> summaryProvenance({
    required String summary,
    required List<TranscriptSegment> segments,
    bool verify = true,
  }) async => const rust_provenance.SummaryProvenance(lines: [], dropped: 0);

  @override
  Future<List<String>> listSummaryModels({
    required rust_summary.SummaryProvider provider,
    required String baseUrl,
    required String apiKey,
  }) async => const [];

  @override
  Future<String> summaryPreviewTranscript(
    List<TranscriptSegment> segments,
  ) async => segments.map((s) => '${s.speaker}: ${s.text}').join('\n');

  @override
  Future<rust_export.ExportedFile> exportNotulen({
    required rust_notulen.NotulenForm form,
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
  }) async => rust_export.ExportedFile(
    filename: 'Notulen - $title.docx',
    path: '$outputDir/Notulen - $title.docx',
    sizeBytes: BigInt.from(1024),
  );

  /// Mirrors the Rust parser closely enough for widget tests: the sections the
  /// notulen form prefills from, without a real engine.
  @override
  Future<rust_notulen.NotulenDraft> notulenDraftFromSummary(String summary) async {
    final keputusan = <String>[];
    var section = '';
    for (final raw in summary.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('#')) {
        section = line.replaceAll('#', '').trim().toLowerCase();
        continue;
      }
      if (section.contains('keputusan') && line.startsWith('- ')) {
        keputusan.add(line.substring(2));
      }
    }
    return rust_notulen.NotulenDraft(
      pembahasan: summary,
      keputusan: keputusan,
      tindakLanjut: const [],
      peserta: const [],
    );
  }

  @override
  Future<rust_api.GlossaryPromptInfo> glossaryPromptPreview({
    required rust_glossary.GlossaryConfig glossary,
    String contextTail = '',
  }) async {
    final terms = [...glossary.sessionTerms, ...glossary.globalTerms]
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return rust_api.GlossaryPromptInfo(
      prompt: terms.isEmpty ? contextTail : 'Istilah: ${terms.join(', ')}.',
      termsUsed: terms.length,
      termsTotal: terms.length,
    );
  }

  @override
  Future<List<String>> parseGlossaryFile(String content) async => content
      .split('\n')
      .map((line) => line.split(',').first.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();

  @override
  Future<String> renderGlossaryFile(List<String> terms, {bool csv = false}) async =>
      '${csv ? 'istilah\n' : ''}${terms.join('\n')}\n';

  @override
  Future<List<String>> summaryTemplateHeadings(
    rust_summary.SummaryTemplate template,
  ) async => const ['Ringkasan', 'Keputusan'];

  @override
  Future<String> composeSummaryInstruction({
    required String instructions,
    required List<String> headings,
  }) async => headings.isEmpty
      ? instructions
      : '$instructions\n\n${headings.map((h) => '## $h').join('\n')}';

  @override
  Future<String> exportDiagnostics({
    required String destination,
    required String doctorReport,
    required String environment,
  }) async => destination;

  @override
  Future<int> diagnosticLogFileCount() async => 1;

  @override
  Future<List<String>> formatBookmarks(List<Bookmark> bookmarks) async => [
    for (final bookmark in bookmarks)
      '[${_mmss(bookmark.timestamp)}] '
          '${bookmark.note.trim().isEmpty ? 'Poin penting' : bookmark.note.trim()}',
  ];
}

/// `mm:ss` for the mock's bookmark formatter.
String _mmss(double seconds) {
  final total = seconds.isFinite && seconds > 0 ? seconds.floor() : 0;
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  return '$minutes:${(total % 60).toString().padLeft(2, '0')}';
}

/// Real bridge backed by the flutter_rust_bridge-generated bindings in
/// `lib/src/rust/`. Requires `RustLib.init()` to have completed (see
/// `main()`). Converts between the hand-written Dart models in
/// `state/models.dart` and the generated types 1:1.
///
class RustEngineBridge implements RustBridge {
  final Map<String, StreamController<TranscriptSegment>> _transcriptControllers = {};
  final Map<String, StreamController<VuLevel>> _vuControllers = {};
  final Map<String, StreamController<SessionNotice>> _noticeControllers = {};
  final Map<String, Timer> _pollTimers = {};
  final Set<String> _polling = {};
  final Set<String> _pausedSessions = {};
  final Map<String, double> _lastMicLevels = {};
  final Map<String, double> _lastSpeakerLevels = {};

  /// The engine-side stop, as an overridable seam.
  ///
  /// `rust_api` needs the native library loaded, so the one guarantee that
  /// matters in [stopSession] — the Dart plumbing is torn down even when the
  /// engine call throws — is otherwise unreachable from a unit test.
  @visibleForTesting
  Future<void> Function(String sessionId) stopEngineSession =
      (sessionId) => rust_api.stopSession(sessionId: sessionId);

  /// How many live sessions still hold Dart-side stream controllers.
  /// Exposed so a test can see the leak this file used to have.
  @visibleForTesting
  int get openStreamCount =>
      _transcriptControllers.length +
      _vuControllers.length +
      _noticeControllers.length +
      _pollTimers.length;

  @visibleForTesting
  void openSessionStreamsForTest(String sessionId) =>
      _openSessionStreams(sessionId);

  @override
  Future<String> startSession(SessionConfig config) async {
    final id = await rust_api.startSession(config: _toRustSessionConfig(config));
    _openSessionStreams(id);
    return id;
  }

  /// Wires the Dart-side stream controllers and the 200 ms poll for a
  /// session that is now live. Shared with [recoverSession]: a recovered
  /// session is a running session, and without this it produced no
  /// transcript events at all.
  void _openSessionStreams(String id) {
    _transcriptControllers[id] = StreamController<TranscriptSegment>.broadcast();
    _vuControllers[id] = StreamController<VuLevel>.broadcast();
    _noticeControllers[id] = StreamController<SessionNotice>.broadcast();
    _pollTimers[id] =
        Timer.periodic(const Duration(milliseconds: 200), (_) => _poll(id));
  }

  @override
  Future<void> stopSession(String sessionId) async {
    _pollTimers.remove(sessionId)?.cancel();
    _polling.remove(sessionId);
    _pausedSessions.remove(sessionId);
    // The Dart-side teardown happens whatever the Rust stop does. A throw
    // from `stopSession` (an id the engine has already forgotten, a poisoned
    // registry lock) used to leave all three StreamControllers open and
    // still in their maps — leaked for the life of the app, and leaving the
    // UI listening to a session that no longer exists. The caller still sees
    // the error; it just no longer costs the cleanup.
    try {
      await stopEngineSession(sessionId);
    } finally {
      await _transcriptControllers.remove(sessionId)?.close();
      await _vuControllers.remove(sessionId)?.close();
      await _noticeControllers.remove(sessionId)?.close();
      _lastMicLevels.remove(sessionId);
      _lastSpeakerLevels.remove(sessionId);
    }
  }

  @override
  void pauseSession(String sessionId) => _pausedSessions.add(sessionId);

  @override
  void resumeSession(String sessionId) => _pausedSessions.remove(sessionId);

  @override
  Future<double> benchmarkRtf(String modelPath) =>
      rust_api.benchmarkRtf(modelPath: modelPath);

  @override
  Future<void> toggleMic(String sessionId, bool enabled) =>
      rust_api.toggleMic(sessionId: sessionId, enabled: enabled);

  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) =>
      rust_api.toggleSpeaker(sessionId: sessionId, enabled: enabled);

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) {
    return _transcriptControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Stream<VuLevel> vuMeterStream(String sessionId) {
    return _vuControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Stream<SessionNotice> noticeStream(String sessionId) {
    return _noticeControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Future<List<rust_session.RecoverableSession>> listRecoverableSessions() =>
      rust_api.listRecoverableSessions();

  @override
  Future<rust_session.RecoveredSession> recoverSession(
    rust_session.SessionRecoverySnapshot snapshot,
  ) async {
    final recovered = await rust_api.recoverSession(snapshot: snapshot);
    _openSessionStreams(recovered.sessionId);
    return recovered;
  }

  @override
  Future<void> deleteRecoverableSession(String sessionId) =>
      rust_api.deleteRecoverableSession(sessionId: sessionId);

  @override
  Future<rust_session.CaptureHealth> captureHealth(String sessionId) =>
      rust_api.getCaptureHealth(sessionId: sessionId);

  @override
  Future<void> setSessionTitle(String sessionId, String title) =>
      rust_api.setSessionTitle(sessionId: sessionId, title: title);

  @override
  Future<rust_disk.DiskSpaceStatus> diskSpace(String path) =>
      rust_api.checkDiskSpace(path: path);

  Future<void> _poll(String sessionId) async {
    if (!_polling.add(sessionId)) return;
    try {
      final events = await rust_api.pollSessionEvents(sessionId: sessionId);
      // Always drain events even when paused — this prevents the Rust mpsc
      // channel from filling up and blocking capture threads. Events are
      // simply not forwarded to the Dart stream controllers.
      final paused = _pausedSessions.contains(sessionId);
      var hasVu = false;
      for (final event in events) {
        event.when(
          transcript: (segment) {
            if (!paused) _transcriptControllers[sessionId]?.add(_fromRustSegment(segment));
          },
          vu: (source, level) {
            if (!paused) {
              hasVu = true;
              if (source == 'mic') { _lastMicLevels[sessionId] = level; }
              else if (source == 'spk') { _lastSpeakerLevels[sessionId] = level; }
            }
          },
          // Delivered even while paused: a source that just died is news
          // regardless, and unlike a segment it cannot be replayed later.
          notice: (level, source, message) {
            _noticeControllers[sessionId]?.add(SessionNotice(
              level: level == rust_session.NoticeLevel.error
                  ? SessionNoticeLevel.error
                  : SessionNoticeLevel.warning,
              source: source,
              message: message,
            ));
          },
        );
      }
      if (hasVu) {
        _vuControllers[sessionId]?.add(VuLevel(
          micLevel: _lastMicLevels[sessionId] ?? 0.0,
          speakerLevel: _lastSpeakerLevels[sessionId] ?? 0.0,
        ));
      }
    } on Object catch (_) {
      // Session shutdown races with the 200ms poll timer are expected.
    } finally {
      _polling.remove(sessionId);
    }
  }

  TranscriptSegment _fromRustSegment(rust_export.Segment segment) =>
      fromRustSegment(segment);

  @override
  Future<AppSettings> loadSettings() async {
    final settings = await rust_api.loadSettings();
    return _fromRustSettings(settings);
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    return rust_api.saveSettings(settings: _toRustSettings(settings));
  }

  @override
  Future<void> downloadModel(String modelsDir, String modelId) =>
      rust_api.downloadModel(modelsDir: modelsDir, modelId: modelId);

  @override
  Future<List<rust_model.ModelInfo>> listAvailableModels(String modelsDir) =>
      rust_api.listAvailableModels(modelsDir: modelsDir);

  @override
  Future<bool> isModelDownloaded(String modelsDir, String modelId) =>
      rust_api.isModelDownloaded(modelsDir: modelsDir, modelId: modelId);

  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() => rust_api.listAudioDevices();

  /// Playback devices, not capture ones. This used to call
  /// [listAudioDevices], so the "Pengeras Suara" picker offered the user a
  /// list of microphones to record the system audio from.
  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() =>
      rust_api.listOutputAudioDevices();

  /// Detects the frontmost window title on macOS by calling osascript.
  /// Gracefully returns empty string on failure or non-macOS platforms.
  /// Window title detection has been REMOVED for privacy.
  /// Reading another app's window title via osascript requires Accessibility
  /// permission and constitutes a cross-app information leak. Titles are now
  /// user-entered manually only — no passive observation of foreground apps.
  @override
  Future<String> detectFrontmostWindowTitle() async => '';

  @override
  Stream<double> downloadProgress() =>
      pollDownloadProgress(rust_api.getDownloadProgress);

  @override
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    rust_glossary.GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) =>
      rust_api.transcribeFilesBatch(
        modelPath: modelPath,
        files: files,
        language: language,
        gpuEnabled: gpuEnabled,
        gpuDevice: gpuDevice,
        glossary: glossary,
        speakerHint: speakerHint,
      );

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
  }) {
    return rust_api.exportSession(
      segments: segments.map(toRustSegment).toList(),
      formats: formats,
      outputDir: outputDir,
      title: title,
    );
  }

  @override
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
  }) {
    return rust_api.exportSessionWithSummary(
      segments: segments.map(toRustSegment).toList(),
      formats: formats,
      outputDir: outputDir,
      title: title,
      summary: summary,
      bookmarks: bookmarks,
    );
  }

  @override
  Future<rust_export.ExportedFile> exportNotulen({
    required rust_notulen.NotulenForm form,
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
  }) => rust_api.exportNotulen(
    form: form,
    segments: segments.map(toRustSegment).toList(),
    outputDir: outputDir,
    title: title,
  );

  @override
  Future<rust_notulen.NotulenDraft> notulenDraftFromSummary(String summary) =>
      rust_api.notulenDraftFromSummary(summary: summary);

  @override
  Future<rust_api.GlossaryPromptInfo> glossaryPromptPreview({
    required rust_glossary.GlossaryConfig glossary,
    String contextTail = '',
  }) => rust_api.glossaryPromptPreview(
    glossary: glossary,
    contextTail: contextTail,
  );

  @override
  Future<List<String>> parseGlossaryFile(String content) =>
      rust_api.parseGlossaryFile(content: content);

  @override
  Future<String> renderGlossaryFile(List<String> terms, {bool csv = false}) =>
      rust_api.renderGlossaryFile(terms: terms, csv: csv);

  @override
  Future<List<String>> summaryTemplateHeadings(
    rust_summary.SummaryTemplate template,
  ) => rust_api.summaryTemplateHeadings(template: template);

  @override
  Future<String> composeSummaryInstruction({
    required String instructions,
    required List<String> headings,
  }) => rust_api.composeSummaryInstruction(
    instructions: instructions,
    headings: headings,
  );

  @override
  Future<String> exportDiagnostics({
    required String destination,
    required String doctorReport,
    required String environment,
  }) => rust_api.flightExportDiagnostics(
    destination: destination,
    doctorReport: doctorReport,
    environment: environment,
  );

  @override
  Future<int> diagnosticLogFileCount() => rust_api.flightLogFileCount();

  @override
  Future<List<String>> formatBookmarks(List<Bookmark> bookmarks) =>
      rust_api.formatBookmarks(bookmarks: bookmarks);

  @override
  Future<rust_api.ProgressiveFileResult> progressiveTranscribeFile({
    required String quickModelPath,
    required String refineModelPath,
    required String path,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    rust_glossary.GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) => rust_api.progressiveTranscribeFile(
    quickModelPath: quickModelPath,
    refineModelPath: refineModelPath,
    path: path,
    language: language,
    speakerHint: speakerHint,
    gpuEnabled: gpuEnabled,
    gpuDevice: gpuDevice,
    glossary: glossary,
  );

  @override
  Future<rust_stt_file.BatchProgressSnapshot?> batchProgress() =>
      rust_api.getBatchProgress();

  @override
  Future<double> audioDurationSecs(String path) =>
      rust_api.audioDurationSecs(path: path);

  @override
  Future<rust_coverage.CoverageReport> transcriptCoverage({
    required List<TranscriptSegment> segments,
    required String audioPath,
  }) => rust_api.transcriptCoverageForAudio(
    segments: segments.map(toRustSegment).toList(),
    audioPath: audioPath,
  );

  @override
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
  }) => rust_api.completeSessionTranscript(
    modelPath: modelPath,
    audioPath: audioPath,
    jobKey: jobKey,
    existing: existing.map(toRustSegment).toList(),
    language: language,
    gpuEnabled: gpuEnabled,
    gpuDevice: gpuDevice,
    glossary: glossary,
    vadEnabled: vadEnabled,
  );

  @override
  Future<List<rust_completion.CompletionProgress>> completionProgress() =>
      rust_api.readCompletionProgress();

  @override
  Future<bool> archiveIsStale({
    required String libraryPath,
    required String dirPath,
    required int transcriptSize,
    required int transcriptModifiedMs,
  }) => rust_api.archiveIsStale(
    libraryPath: libraryPath,
    dirPath: dirPath,
    transcriptSize: BigInt.from(transcriptSize),
    transcriptMtimeMs: transcriptModifiedMs,
  );

  @override
  Future<int> archiveIndexSession({
    required String libraryPath,
    required String dirPath,
    required String title,
    required String date,
    required List<TranscriptSegment> segments,
    required String summary,
    required int transcriptSize,
    required int transcriptModifiedMs,
  }) => rust_api.archiveIndexSession(
    libraryPath: libraryPath,
    dirPath: dirPath,
    title: title,
    date: date,
    segments: segments.map(toRustSegment).toList(),
    summary: summary,
    transcriptSize: BigInt.from(transcriptSize),
    transcriptMtimeMs: transcriptModifiedMs,
  );

  @override
  Future<void> archiveForgetSession({
    required String libraryPath,
    required String dirPath,
  }) => rust_api.archiveForgetSession(
    libraryPath: libraryPath,
    dirPath: dirPath,
  );

  @override
  Future<List<rust_archive.ArchiveHit>> archiveSearch({
    required String libraryPath,
    required String question,
    int limit = 12,
  }) => rust_api.archiveSearch(
    libraryPath: libraryPath,
    question: question,
    limit: limit,
  );

  @override
  Future<rust_archive.ArchiveStats> archiveStats(String libraryPath) =>
      rust_api.archiveStats(libraryPath: libraryPath);

  @override
  Future<void> archiveClear(String libraryPath) =>
      rust_api.archiveClear(libraryPath: libraryPath);

  @override
  Future<rust_archive.ArchiveAnswer> archiveAsk({
    required String libraryPath,
    required String question,
    required rust_summary.SummaryConfig config,
  }) => rust_api.archiveAsk(
    libraryPath: libraryPath,
    question: question,
    config: config,
  );

  @override
  Future<String> generateSummary({
    required List<TranscriptSegment> segments,
    required rust_summary.SummaryConfig config,
    List<Bookmark> bookmarks = const [],
  }) => rust_api.generateSummary(
    segments: segments.map(toRustSegment).toList(),
    config: config,
    bookmarks: bookmarks,
  );

  @override
  Future<String> generateSummaryLong({
    required List<TranscriptSegment> segments,
    required rust_summary.SummaryConfig config,
    List<Bookmark> bookmarks = const [],
  }) => rust_api.generateSummaryLong(
    segments: segments.map(toRustSegment).toList(),
    config: config,
    bookmarks: bookmarks,
  );

  @override
  Future<List<rust_capabilities.Capability>> describeCapabilities(
    AppSettings settings,
  ) => rust_api.describeCapabilities(settings: _toRustSettings(settings));

  @override
  Future<rust_mapreduce.MapReduceProgress?> summaryProgress() =>
      rust_api.readSummaryProgress();

  @override
  Future<List<rust_actions.ActionItem>> parseActionItems(String summary) =>
      rust_api.parseActionItems(summary: summary);

  @override
  Future<String> stripActionItemsBlock(String summary) =>
      rust_api.stripActionItemsBlock(summary: summary);

  @override
  Future<String> actionItemsToIcs({
    required List<rust_actions.ActionItem> items,
    required String calendarName,
    required String today,
  }) => rust_api.actionItemsToIcs(
    items: items,
    calendarName: calendarName,
    today: today,
  );

  @override
  Future<String> actionItemsToCsv(List<rust_actions.ActionItem> items) =>
      rust_api.actionItemsToCsv(items: items);

  @override
  Future<rust_provenance.SummaryProvenance> summaryProvenance({
    required String summary,
    required List<TranscriptSegment> segments,
    bool verify = true,
  }) {
    final rustSegments = segments.map(toRustSegment).toList();
    return verify
        ? rust_api.parseSummaryProvenanceVerified(
            summary: summary,
            segments: rustSegments,
          )
        : rust_api.parseSummaryProvenance(
            summary: summary,
            segments: rustSegments,
          );
  }

  @override
  Future<List<String>> listSummaryModels({
    required rust_summary.SummaryProvider provider,
    required String baseUrl,
    required String apiKey,
  }) => rust_api.listSummaryModels(
    provider: provider,
    baseUrl: baseUrl,
    apiKey: apiKey,
  );

  @override
  Future<String> summaryPreviewTranscript(List<TranscriptSegment> segments) =>
      rust_api.summaryPreviewTranscript(
        segments: segments.map(toRustSegment).toList(),
      );

  @override
  Future<List<rust_export.ExportedFile>> exportSessionAudio({
    required String sessionId,
    required String outputDir,
    required String title,
  }) => rust_api.exportSessionAudio(
    sessionId: sessionId,
    outputDir: outputDir,
    title: title,
  );

  rust_audio.SessionConfig _toRustSessionConfig(SessionConfig config) {
    return rust_audio.SessionConfig(
      micEnabled: config.micEnabled,
      speakerEnabled: config.speakerEnabled,
      mode: _toRustSessionMode(config.mode),
      micDeviceId: config.micDeviceId,
      speakerDeviceId: config.speakerDeviceId,
      modelPath: config.modelPath,
      refineModelPath: config.refineModelPath,
      hptMode: _toRustHptMode(config.hptMode),
      vadEnabled: config.vadEnabled,
      gpuEnabled: config.gpuEnabled,
      gpuDevice: config.gpuDevice,
      audioToDisk: config.audioToDisk,
      glossary: config.glossary,
      fallbackModelPath: config.fallbackModelPath,
    );
  }

  static const _hptModeMap = {
    HptMode.auto: rust_audio.HptMode.auto,
    HptMode.forceDual: rust_audio.HptMode.forceDual,
    HptMode.forceDirect: rust_audio.HptMode.forceDirect,
  };

  rust_audio.HptMode _toRustHptMode(HptMode mode) =>
      _hptModeMap[mode] ?? rust_audio.HptMode.auto;

  rust_audio.SessionMode _toRustSessionMode(SessionMode mode) => switch (mode) {
    SessionMode.webinar => rust_audio.SessionMode.webinar,
    SessionMode.online => rust_audio.SessionMode.online,
    SessionMode.offline => rust_audio.SessionMode.offline,
  };

  SessionMode _fromRustSessionMode(rust_audio.SessionMode mode) => switch (mode) {
    rust_audio.SessionMode.webinar => SessionMode.webinar,
    rust_audio.SessionMode.online => SessionMode.online,
    rust_audio.SessionMode.offline => SessionMode.offline,
  };

  AppSettings _fromRustSettings(rust_settings.AppSettings settings) {
    return AppSettings(
      theme: fromRustTheme(settings.theme),
      defaultModel: settings.defaultModel,
      defaultMode: _fromRustSessionMode(settings.defaultMode),
      libraryPath: settings.libraryPath,
      vadEnabled: settings.vadEnabled,
      language: settings.language,
      gpuEnabled: settings.gpuEnabled,
      gpuDevice: settings.gpuDevice,
      autoStopMinutes: settings.autoStopMinutes,
      progressiveEnabled: settings.progressiveEnabled,
      audioToDisk: settings.audioToDisk,
      summary: settings.summary,
      glossary: settings.glossary,
      summaryTemplates: settings.summaryTemplates,
      notulen: settings.notulen,
      autoRetranscribe: settings.autoRetranscribe,
      pdp: settings.pdp,
      noiseReduction: settings.noiseReduction,
    );
  }

  rust_settings.AppSettings _toRustSettings(AppSettings settings) {
    return rust_settings.AppSettings(
      theme: toRustTheme(settings.theme),
      defaultModel: settings.defaultModel,
      defaultMode: _toRustSessionMode(settings.defaultMode),
      libraryPath: settings.libraryPath,
      alwaysOnTop: false,
      autoSaveIntervalSecs: 10,
      vadEnabled: settings.vadEnabled,
      // echoDedupeEnabled is mode-determined in Rust; always persist true
      echoDedupeEnabled: true,
      language: settings.language,
      gpuEnabled: settings.gpuEnabled,
      gpuDevice: settings.gpuDevice,
      autoStopMinutes: settings.autoStopMinutes,
      progressiveEnabled: settings.progressiveEnabled,
      audioToDisk: settings.audioToDisk,
      summary: settings.summary,
      glossary: settings.glossary,
      summaryTemplates: settings.summaryTemplates,
      notulen: settings.notulen,
      autoRetranscribe: settings.autoRetranscribe,
      pdp: settings.pdp,
      noiseReduction: settings.noiseReduction,
    );
  }
}
