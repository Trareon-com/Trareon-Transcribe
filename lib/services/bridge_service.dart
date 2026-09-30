import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../src/rust/api.dart' as rust_api;
import '../src/rust/audio.dart' as rust_audio;
import '../src/rust/audio/device.dart' as rust_device;
import '../src/rust/disk.dart' as rust_disk;
import '../src/rust/export.dart' as rust_export;
import '../src/rust/model.dart' as rust_model;
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
  });

  /// Which file the in-flight [batchTranscribeFiles] call is currently on.
  /// `null` when no batch is running. [batchTranscribeFiles] only returns
  /// once every file is done, so this is the only way to show real progress.
  Future<rust_stt_file.BatchProgressSnapshot?> batchProgress();

  /// **The only networked call in the app.** Sends the rendered transcript
  /// text (never audio, never paths) to the user-configured endpoint and
  /// returns Markdown. Runs only on an explicit user action.
  Future<String> generateSummary({
    required List<TranscriptSegment> segments,
    required rust_summary.SummaryConfig config,
  });

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
    List<rust_export.ExportFormat> formats,
  });
}

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
  }) async => rust_api.ProgressiveFileResult(
    filename: path.split(Platform.pathSeparator).last,
    quickSegments: const [],
    refinedSegments: const [],
    language: language ?? 'auto',
  );

  @override
  Future<rust_stt_file.BatchProgressSnapshot?> batchProgress() async => null;

  /// The mock never performs I/O of any kind — a test that reaches the
  /// summary path must fail loudly rather than silently hit a real endpoint.
  @override
  Future<String> generateSummary({
    required List<TranscriptSegment> segments,
    required rust_summary.SummaryConfig config,
  }) async =>
      throw UnsupportedError('RustBridgeMock does not generate summaries');

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
    await rust_api.stopSession(sessionId: sessionId);
    await _transcriptControllers.remove(sessionId)?.close();
    await _vuControllers.remove(sessionId)?.close();
    await _noticeControllers.remove(sessionId)?.close();
    _lastMicLevels.remove(sessionId);
    _lastSpeakerLevels.remove(sessionId);
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
  Stream<double> downloadProgress() {
    late final StreamController<double> controller;
    Timer? timer;
    controller = StreamController<double>(
      onCancel: () => timer?.cancel(),
    );
    timer = Timer.periodic(const Duration(milliseconds: 200), (t) async {
      final progress = await rust_api.getDownloadProgress();
      if (progress == null) return;
      final downloaded = progress.$1;
      final total = progress.$2;
      if (total == BigInt.zero) return;
      final ratio = downloaded.toDouble() / total.toDouble();
      controller.add(ratio);
      if (ratio >= 1.0) {
        t.cancel();
        controller.close();
      }
    });
    return controller.stream;
  }

  @override
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
  }) =>
      rust_api.transcribeFilesBatch(
        modelPath: modelPath,
        files: files,
        language: language,
        gpuEnabled: gpuEnabled,
        gpuDevice: gpuDevice,
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
    );
  }

  @override
  Future<rust_api.ProgressiveFileResult> progressiveTranscribeFile({
    required String quickModelPath,
    required String refineModelPath,
    required String path,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
  }) => rust_api.progressiveTranscribeFile(
    quickModelPath: quickModelPath,
    refineModelPath: refineModelPath,
    path: path,
    language: language,
    gpuEnabled: gpuEnabled,
    gpuDevice: gpuDevice,
  );

  @override
  Future<rust_stt_file.BatchProgressSnapshot?> batchProgress() =>
      rust_api.getBatchProgress();

  @override
  Future<String> generateSummary({
    required List<TranscriptSegment> segments,
    required rust_summary.SummaryConfig config,
  }) => rust_api.generateSummary(
    segments: segments.map(toRustSegment).toList(),
    config: config,
  );

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
    );
  }
}
