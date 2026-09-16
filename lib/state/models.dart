/// Dart-side mirrors of the Rust API types (rust_core/src/{audio,export,settings}.rs).
/// Once FRB codegen is wired (Fase 5) these become generated bindings;
/// keeping them hand-written now lets UI development proceed in parallel.
library;

import 'dart:io';

enum SessionMode { webinar, online, offline }

/// Resolves a leading `~` in [path] to the user's home directory.
String resolveTilde(String path) {
  if (path.startsWith('~/')) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home${path.substring(1)}';
  }
  return path;
}

String _modelFileName(String modelId) => switch (modelId) {
  'base' => 'ggml-base.bin',
  'large-v3-turbo-q5' => 'ggml-large-v3-turbo-q5_0.bin',
  _ => 'ggml-$modelId.bin',
};

/// The only model ids the current 2-model bundle exposes in the UI (Settings
/// dropdown, setup wizard). A model id can still have a cached file on disk
/// after being dropped from this list (e.g. `tiny` from an earlier release)
/// — [isModelAvailable] alone doesn't catch that, so callers that need a
/// UI-selectable default (not just a playable file) must also check this.
const List<String> kKnownModelIds = ['base', 'large-v3-turbo-q5'];

/// Resolves a model id to an absolute file path. The bare relative path
/// `models/ggml-*.bin` only resolves by coincidence when a process happens
/// to have the repo root as its CWD (e.g. a shell-launched `cargo run`) — a
/// normally-launched (or macOS-sandboxed) app never does, so this checks,
/// in order: (1) the configured library path — where downloadModel() saves
/// non-bundled models, and matches Rust's own resolve_model_path(); (2) the
/// bundled-vs-dev-tree executable-relative search already used by
/// [rust_library_loader.dart] for the native library. macOS App Sandbox
/// blocks opening arbitrary paths outside the bundle/container, so relying
/// only on (2) works in dev but never in a sandboxed release build.
String modelPathForId(String modelId, {String? libraryPath}) {
  final fileName = _modelFileName(modelId);

  // Known macOS model cache location
  String? homeCachePath;
  final home = Platform.environment['HOME'];
  if (home != null) {
    homeCachePath = '$home/Library/Caches/TrareonTranscribe/models/$fileName';
  }
  // Known Windows model cache location
  String? localAppDataPath;
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null) {
    localAppDataPath = '$localAppData\\TrareonTranscribe\\models\\$fileName';
  }

  final candidates = [
    if (libraryPath != null && libraryPath.isNotEmpty)
      '${resolveTilde(libraryPath)}/$fileName',
    ?homeCachePath,
    ?localAppDataPath,
    _bundledResourcesPath(fileName),
    ..._devTreePaths(fileName),
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) return candidate;
  }
  // Last-resort fallback
  return 'models/$fileName';
}

/// Whether [modelId]'s file actually exists somewhere modelPathForId()
/// would find it. Selecting an unavailable model as the default (there is
/// no in-UI download affordance outside the setup wizard) previously
/// crashed session start with an unhandled "model file not found"
/// exception — callers should check this before committing the choice.
bool isModelAvailable(String modelId, {String? libraryPath}) {
  final fileName = _modelFileName(modelId);
  final home = Platform.environment['HOME'];
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final candidates = [
    if (libraryPath != null && libraryPath.isNotEmpty)
      '${libraryPath.startsWith('~/') && home != null ? '$home${libraryPath.substring(1)}' : libraryPath}/$fileName',
    if (home != null) '$home/Library/Caches/TrareonTranscribe/models/$fileName',
    if (localAppData != null)
      '$localAppData\\TrareonTranscribe\\models\\$fileName',
    _bundledResourcesPath(fileName),
    ..._devTreePaths(fileName),
  ];
  return candidates.any((c) => File(c).existsSync());
}

/// Directory downloaded models are saved into when the user hasn't picked a
/// custom library path. Matches the "Known macOS/Windows model cache
/// location" candidates [isModelAvailable] and [modelPathForId] already
/// check unconditionally, so a model downloaded here is found on the very
/// next app launch — before `AppSettings` (and its `libraryPath`) finish
/// loading from disk.
String defaultModelsCacheDir() {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && Platform.isWindows) {
    return '$localAppData\\TrareonTranscribe\\models';
  }
  final home = Platform.environment['HOME'];
  if (home != null) {
    return '$home/Library/Caches/TrareonTranscribe/models';
  }
  return 'models';
}

String _bundledResourcesPath(String fileName) {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  if (Platform.isMacOS) {
    return '$exeDir/../Resources/models/$fileName';
  }
  return '$exeDir/models/$fileName';
}

List<String> _devTreePaths(String fileName) {
  // Walk up from the executable looking for a `models/` directory —
  // works for `flutter run` (exe under build/{platform}/.../Debug)
  // without hardcoding a repo-root assumption.
  var dir = File(Platform.resolvedExecutable).parent;
  final paths = <String>[];
  for (var i = 0; i < 14; i++) {
    paths.add('${dir.path}/models/$fileName');
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return paths;
}

extension SessionModeDefaults on SessionMode {
  (bool mic, bool speaker) get defaultToggles => switch (this) {
    SessionMode.webinar => (false, true),
    SessionMode.online => (true, true),
    SessionMode.offline => (true, false),
  };

  bool get echoDedupeEnabled => this == SessionMode.online;

  String get label => switch (this) {
    SessionMode.webinar => 'Webinar',
    SessionMode.online => 'Rapat Online',
    SessionMode.offline => 'Rapat Offline',
  };
}

class SessionConfig {
  final bool micEnabled;
  final bool speakerEnabled;
  final SessionMode mode;
  final String modelPath;
  final bool vadEnabled;
  final String? micDeviceId;
  final String? speakerDeviceId;
  // Optional second model for HPT. When non-null, live sessions run
  // quick (base) → refine (q5) and replace partial rows in place.
  final String? refineModelPath;
  final HptMode hptMode;

  const SessionConfig({
    required this.micEnabled,
    required this.speakerEnabled,
    required this.mode,
    required this.modelPath,
    this.vadEnabled = true,
    this.micDeviceId,
    this.speakerDeviceId,
    this.refineModelPath,
    this.hptMode = HptMode.auto,
  });

  factory SessionConfig.forMode(SessionMode mode, String modelPath) {
    final (mic, speaker) = mode.defaultToggles;
    return SessionConfig(
      micEnabled: mic,
      speakerEnabled: speaker,
      mode: mode,
      modelPath: modelPath,
    );
  }

  SessionConfig copyWith({
    bool? micEnabled,
    bool? speakerEnabled,
    SessionMode? mode,
    bool? vadEnabled,
    String? micDeviceId,
    String? speakerDeviceId,
    Object? refineModelPath = _sentinel,
    HptMode? hptMode,
  }) {
    return SessionConfig(
      micEnabled: micEnabled ?? this.micEnabled,
      speakerEnabled: speakerEnabled ?? this.speakerEnabled,
      mode: mode ?? this.mode,
      modelPath: modelPath,
      vadEnabled: vadEnabled ?? this.vadEnabled,
      micDeviceId: micDeviceId ?? this.micDeviceId,
      speakerDeviceId: speakerDeviceId ?? this.speakerDeviceId,
      refineModelPath: refineModelPath == _sentinel
          ? this.refineModelPath
          : refineModelPath as String?,
      hptMode: hptMode ?? this.hptMode,
    );
  }
}

class TranscriptSegment {
  final String source;
  final String speaker;
  final String text;
  final double timestamp;
  final double duration;
  final String language;
  final double confidence;
  final bool isPartial;
  final bool lowConfidence;

  const TranscriptSegment({
    required this.source,
    required this.speaker,
    required this.text,
    required this.timestamp,
    required this.duration,
    required this.language,
    required this.confidence,
    required this.isPartial,
    this.lowConfidence = false,
  });

  TranscriptSegment copyWith({String? speaker, String? text}) {
    return TranscriptSegment(
      source: source,
      speaker: speaker ?? this.speaker,
      text: text ?? this.text,
      timestamp: timestamp,
      duration: duration,
      language: language,
      confidence: confidence,
      isPartial: isPartial,
      lowConfidence: lowConfidence,
    );
  }

  /// HPT merge key: same (source, timestamp) in the quick pass and the
  /// refined pass refers to the SAME utterance — Dart replaces text in
  /// place instead of appending a duplicate row.
  String get segmentKey => '$source@${timestamp.toStringAsFixed(2)}';
}

class VuLevel {
  final double micLevel;
  final double speakerLevel;

  const VuLevel({required this.micLevel, required this.speakerLevel});
}

enum AppThemeMode { light, dark, system }

/// HPT (Hybrid Progressive Transcription) strategy chosen by the user.
enum HptMode {
  /// Benchmark q5 RTF; direct if fast, dual-pass if slow (default).
  auto,

  /// Force base quick → q5 refine dual-pass.
  forceDual,

  /// Force q5 single-pass (skip base entirely).
  forceDirect,
}

class AppSettings {
  final AppThemeMode theme;
  final String defaultModel;
  final SessionMode defaultMode;
  final String libraryPath;
  final bool vadEnabled;
  final String? language;
  final int? autoStopMinutes;
  // Dart-only: not sent to Rust. Persists for the app session only.
  final String defaultExportFormat;
  final String? micDeviceId;
  final String? speakerDeviceId;
  // Hybrid Progressive Transcription: quick pass (base) then refine (q5).
  // Dart-only — resolved into SessionConfig.refineModelPath at session start.
  final bool progressiveEnabled;
  // Benchmarked q5 realtime factor (seconds audio / second wall).
  // 0.0 = not yet benchmarked. ≥1.2 ≈ fast enough for single-pass q5.
  final double rtfScore;
  final HptMode hptMode;

  const AppSettings({
    required this.theme,
    required this.defaultModel,
    required this.defaultMode,
    required this.libraryPath,
    required this.vadEnabled,
    this.language,
    this.autoStopMinutes,
    this.defaultExportFormat = 'markdown',
    this.micDeviceId,
    this.speakerDeviceId,
    this.progressiveEnabled = true,
    this.rtfScore = 0.0,
    this.hptMode = HptMode.auto,
  });

  factory AppSettings.defaults() => const AppSettings(
    theme: AppThemeMode.light,
    defaultModel: 'base',
    defaultMode: SessionMode.online,
    libraryPath: '~/Documents/TrareonTranscribe',
    vadEnabled: true,
  );

  AppSettings copyWith({
    AppThemeMode? theme,
    String? defaultModel,
    SessionMode? defaultMode,
    String? libraryPath,
    bool? vadEnabled,
    String? language,
    int? autoStopMinutes,
    bool clearAutoStop = false,
    String? defaultExportFormat,
    Object? micDeviceId = _sentinel,
    Object? speakerDeviceId = _sentinel,
    bool? progressiveEnabled,
    double? rtfScore,
    HptMode? hptMode,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultMode: defaultMode ?? this.defaultMode,
      libraryPath: libraryPath ?? this.libraryPath,
      vadEnabled: vadEnabled ?? this.vadEnabled,
      language: language ?? this.language,
      autoStopMinutes: clearAutoStop
          ? null
          : (autoStopMinutes ?? this.autoStopMinutes),
      defaultExportFormat: defaultExportFormat ?? this.defaultExportFormat,
      micDeviceId: micDeviceId == _sentinel
          ? this.micDeviceId
          : micDeviceId as String?,
      speakerDeviceId: speakerDeviceId == _sentinel
          ? this.speakerDeviceId
          : speakerDeviceId as String?,
      progressiveEnabled: progressiveEnabled ?? this.progressiveEnabled,
      rtfScore: rtfScore ?? this.rtfScore,
      hptMode: hptMode ?? this.hptMode,
    );
  }
}

// Sentinel value for distinguishing "not passed" from "explicitly null" in copyWith.
const Object _sentinel = Object();

/// Summary of a recorded session, used by LibraryScreen and export dialogs.
class SessionSummary {
  final String id;
  final String title;
  final String date;
  final double durationSeconds;
  final int segmentsCount;
  final List<TranscriptSegment> segments;
  final String? audioPath;

  const SessionSummary({
    required this.id,
    required this.title,
    required this.date,
    required this.segmentsCount,
    this.segments = const [],
    this.durationSeconds = 0,
    this.audioPath,
  });
}
