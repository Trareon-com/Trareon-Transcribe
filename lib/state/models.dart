/// Dart-side mirrors of the Rust API types (rust_core/src/{audio,export,settings}.rs).
/// Once FRB codegen is wired (Fase 5) these become generated bindings;
/// keeping them hand-written now lets UI development proceed in parallel.
library;

import 'dart:io';

import '../src/rust/glossary.dart' show GlossaryConfig, ReplacementRule;
import '../src/rust/pdp.dart' show PdpSettings;
import '../src/rust/pdp/redaction.dart' show RedactionConfig;
import '../src/rust/pdp/retention.dart' show RetentionPolicy;
import '../src/rust/settings.dart'
    show
        CustomSummaryTemplate,
        GlossarySettings,
        NotulenDefaults,
        SummarySettings;
import '../src/rust/summary.dart'
    show SummaryConfig, SummaryProvider, SummaryTemplate;

export '../src/rust/actions.dart' show ActionItem, ActionStatus;
export '../src/rust/export.dart' show Bookmark;
export '../src/rust/export/notulen.dart'
    show NotulenDraft, NotulenForm, RisalahEntry, TindakLanjut;
export '../src/rust/llm_setup.dart'
    show HardwareProfile, InstallGuide, LlmTier, ModelOption, PullProgress,
        Recommendation;
export '../src/rust/notulen.dart' show NotulenLength, NotulenTemplate;
export '../src/rust/notulen/factcheck.dart'
    show FaktaMasalah, LaporanFakta, TemuanFakta;
export '../src/rust/notulen/register.dart'
    show RegisterFinding, RegisterRule;
export '../src/rust/notulen/schema.dart' show StructureReport;
export '../src/rust/srikandi.dart'
    show KlasifikasiKeamanan, Sifat, SrikandiMetadata, TemuanMetadata,
        TingkatPerkembangan, Tingkat;
export '../src/rust/glossary.dart' show GlossaryConfig, ReplacementRule;
export '../src/rust/mapreduce.dart' show MapReduceProgress;
export '../src/rust/pdp.dart' show PdpSettings;
export '../src/rust/pdp/audit.dart' show AuditAction, AuditEntry;
export '../src/rust/pdp/redaction.dart' show PiiKind, PiiMatch, RedactionConfig;
export '../src/rust/pdp/retention.dart'
    show RetentionItem, RetentionPlan, RetentionPolicy;
export '../src/rust/provenance.dart'
    show Citation, SummaryLine, SummaryProvenance;
export '../src/rust/settings.dart'
    show
        CustomSummaryTemplate,
        GlossarySettings,
        NotulenDefaults,
        SummarySettings;
export '../src/rust/summary.dart'
    show SummaryConfig, SummaryProvider, SummaryTemplate;

enum SessionMode { webinar, online, offline }

/// Resolves what language to actually pass to the transcription engine for
/// a new session (Sprint 14a item 11).
///
/// `globalLanguage` is [AppSettings.language]: `null` means "no explicit
/// global override — decide per mode", and that per-mode decision is what
/// fixed the reported bug ("audio berbahasa Inggris muncul di sesi
/// berbahasa Indonesia" — a webinar with no override used to be forced to
/// `'id'` because the old Rust default was `Some('id')` for every mode).
/// A non-null `globalLanguage` is an explicit choice (made in Settings, or
/// carried over from a pre-14a install that always wrote `'id'`) and wins
/// outright — this function only fills in the gap when there is no
/// explicit choice at all.
String? effectiveSessionLanguage({
  required String? globalLanguage,
  required SessionMode mode,
}) {
  if (globalLanguage != null) return globalLanguage;
  // Rapat Offline keeps a forced 'id': it is the one mode blueprint-listed
  // as "Indonesia only" for accuracy, and it is also the mode with no
  // second speaker whose language could differ from the room's.
  return mode == SessionMode.offline ? 'id' : null;
}

/// How many of the most recent segments [shouldOfferAutoLanguage] looks at.
/// Small enough to react within a few sentences of someone switching
/// language, large enough that one stray misdetection doesn't trigger it.
const int kLanguageOfferWindow = 10;

/// Below this count there isn't enough evidence yet either way — showing
/// the offer after one segment would fire on the very first sentence,
/// before the speaker has even settled into a language.
const int _kLanguageOfferMinSegments = 4;

/// Above this fraction of the recent window detected as something other
/// than the forced language, the mismatch is "many segments", not noise.
const double _kLanguageOfferMismatchThreshold = 0.3;

/// Sprint 14a item 11: whether to show the "Ganti ke Otomatis" offer.
///
/// `currentLanguage` is the language this session is forced to (`'id'` or
/// `'en'`); `null` means the session is already Otomatis, in which case
/// there is nothing to offer — Whisper is already choosing per window.
/// Looks only at the most recent [kLanguageOfferWindow] segments, not the
/// whole session, so a meeting that starts in English and settles into
/// Indonesian doesn't keep nagging once the mismatch has passed.
bool shouldOfferAutoLanguage({
  required String? currentLanguage,
  required List<TranscriptSegment> segments,
}) {
  if (currentLanguage == null) return false;
  final recent = segments.length <= kLanguageOfferWindow
      ? segments
      : segments.sublist(segments.length - kLanguageOfferWindow);
  if (recent.length < _kLanguageOfferMinSegments) return false;
  final mismatched = recent
      .where((s) => s.language.isNotEmpty && s.language != currentLanguage)
      .length;
  return mismatched / recent.length > _kLanguageOfferMismatchThreshold;
}

/// The AI-summary configuration a fresh install starts from: disabled, no
/// key, pointing at a loopback Ollama. Mirrors `SummarySettings::default()`
/// on the Rust side — FRB generates no Dart-side constructor default, so the
/// value has to be spelled out once here rather than at each call site.
const SummarySettings kDefaultSummarySettings = SummarySettings(
  enabled: false,
  provider: SummaryProvider.ollama,
  baseUrl: 'http://localhost:11434',
  apiKey: '',
  model: '',
  template: SummaryTemplate.notulenRapat,
  customPrompt: '',
  withCitations: false,
  withActionItems: false,
);

/// A fresh install's kamus istilah: on, but empty, so it is a no-op until the
/// user adds a term. Mirrors `GlossarySettings::default()` — FRB generates no
/// Dart-side defaults.
const GlossarySettings kDefaultGlossarySettings = GlossarySettings(
  enabled: true,
  terms: [],
  postCorrection: true,
  replacements: [],
);

/// Office-level notulen defaults, all blank on a fresh install.
const NotulenDefaults kDefaultNotulenDefaults = NotulenDefaults(
  unitKerja: '',
  tempat: '',
  notulis: '',
  kopSuratPath: '',
);

/// Indonesian label for each built-in summary template.
String summaryTemplateLabel(SummaryTemplate template) => switch (template) {
  SummaryTemplate.notulenRapat => 'Notulen Rapat',
  SummaryTemplate.ringkasanEksekutif => 'Ringkasan Eksekutif',
  SummaryTemplate.actionItems => 'Keputusan & Tindak Lanjut',
  SummaryTemplate.standup => 'Laporan Harian',
  SummaryTemplate.kustom => 'Kustom',
};

/// One-line description shown under the template picker.
String summaryTemplateHint(SummaryTemplate template) => switch (template) {
  SummaryTemplate.notulenRapat =>
    'Ringkasan, peserta, pembahasan, keputusan, tindak lanjut',
  SummaryTemplate.ringkasanEksekutif =>
    'Paragraf singkat untuk yang tidak hadir',
  SummaryTemplate.actionItems =>
    'Hanya keputusan dan tugas beserta penanggung jawabnya',
  SummaryTemplate.standup => 'Per orang: selesai, berikutnya, hambatan',
  SummaryTemplate.kustom => 'Instruksi sendiri',
};

String summaryProviderLabel(SummaryProvider provider) => switch (provider) {
  SummaryProvider.ollama => 'Ollama (lokal)',
  SummaryProvider.openAiCompatible => 'Layanan serupa OpenAI',
};

/// Where sessions are saved until the user points Settings elsewhere.
/// Still tilde-form: pass it through [resolveTilde] before touching disk.
const String kDefaultLibraryPath = '~/Documents/TrareonTranscribe';

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

/// The model ids the UI exposes as choices (Settings dropdown, setup
/// wizard) — Sprint 14a added `small` as the mid-RAM tier recommended by
/// `model_select::recommend_default_model`. A model id can still have a
/// cached file on disk after being dropped from this list (e.g. `tiny`
/// from an earlier release) — [isModelAvailable] alone doesn't catch that,
/// so callers that need a UI-selectable default (not just a playable file)
/// must also check this.
const List<String> kKnownModelIds = ['base', 'small', 'large-v3-turbo-q5'];

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
  // GPU acceleration (Vulkan/CUDA/Metal — whichever backend the native
  // build was compiled with). Defaults off; wired from AppSettings by the
  // caller (see SettingsController / bridge_service._toRustSessionConfig).
  final bool gpuEnabled;
  final int gpuDevice;

  /// Stream captured audio to disk as it arrives instead of buffering it
  /// in RAM until Stop. On by default; see `AppSettings.audioToDisk`.
  final bool audioToDisk;

  /// Kamus istilah for this session — global terms plus whatever was typed
  /// for this meeting. Empty is a no-op.
  final GlossaryConfig glossary;

  /// Fastest model installed, for the *live preview only* when [modelPath]
  /// turns out to be slower than real time on this device.
  ///
  /// It does not downgrade what the user ends up with: the post-stop
  /// completion pass re-runs the saved audio with [modelPath]. What it
  /// prevents is the live worker falling further behind every minute until
  /// Stop, which on a weak CPU produced a 6-minute recording with 8 seconds
  /// of transcript. Null disables the substitution.
  final String? fallbackModelPath;

  /// Per-session language override (Sprint 14a item 11): set from the
  /// session options menu, not Settings, so picking English for one
  /// English-speaking webinar doesn't change every future meeting's
  /// default. `null` means "no override" — Rust's
  /// `session::resolve_session_language` then falls back to the global
  /// setting and [mode] exactly as before this existed.
  final String? language;

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
    this.gpuEnabled = false,
    this.gpuDevice = 0,
    this.audioToDisk = true,
    this.glossary = const GlossaryConfig(
      sessionTerms: [],
      globalTerms: [],
      postCorrection: false,
      replacements: [],
    ),
    this.fallbackModelPath,
    this.language,
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
    bool? gpuEnabled,
    int? gpuDevice,
    bool? audioToDisk,
    GlossaryConfig? glossary,
    Object? fallbackModelPath = _sentinel,
    Object? language = _sentinel,
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
      gpuEnabled: gpuEnabled ?? this.gpuEnabled,
      gpuDevice: gpuDevice ?? this.gpuDevice,
      audioToDisk: audioToDisk ?? this.audioToDisk,
      glossary: glossary ?? this.glossary,
      fallbackModelPath: fallbackModelPath == _sentinel
          ? this.fallbackModelPath
          : fallbackModelPath as String?,
      language: language == _sentinel ? this.language : language as String?,
    );
  }
}

/// The fastest model installed on this machine, for the live preview to
/// fall back to. Ordered fastest first; `null` when none of them is
/// installed or the only one installed is [exclude] itself.
///
/// `tiny` is not in [kKnownModelIds] — it is not offered in Settings — but
/// it is bundled in the repo and left behind by older releases, and for a
/// live preview on a two-core machine it is exactly the right answer.
String? fastestInstalledModelPath({
  required String exclude,
  String? libraryPath,
}) {
  for (final id in const ['tiny', 'base']) {
    if (!isModelAvailable(id, libraryPath: libraryPath)) continue;
    final path = modelPathForId(id, libraryPath: libraryPath);
    if (path != exclude) return path;
  }
  return null;
}

/// One word of a segment, with the span the player highlights.
///
/// Mirrors rust_core's `export::WordTimestamp`. Produced from Whisper's
/// token timestamps, so the boundaries are the model's, not an
/// interpolation — except when [prob] is zero, which marks a word whose
/// position was interpolated because the engine reported no usable token
/// times (see `stt::words::interpolate_words`).
class TranscriptWord {
  final String word;
  final double start;
  final double end;

  /// Mean probability Whisper gave this word's tokens, `0.0`–`1.0`.
  /// `0.0` means "not measured", not "certainly wrong".
  final double prob;

  const TranscriptWord({
    required this.word,
    required this.start,
    required this.end,
    this.prob = 0.0,
  });

  /// Whether the word is worth the reader's attention in "Tinjau".
  /// Interpolated words are excluded: there is no measurement to doubt.
  bool get isLowConfidence => prob > 0 && prob < kLowWordProb;

  /// Whether [seconds] falls inside this word, for the karaoke highlight.
  bool contains(double seconds) => seconds >= start && seconds < end;

  Map<String, dynamic> toJson() => {
    'word': word,
    'start': start,
    'end': end,
    'prob': prob,
  };

  static TranscriptWord? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final word = raw['word'] as String?;
    if (word == null) return null;
    return TranscriptWord(
      word: word,
      start: (raw['start'] as num?)?.toDouble() ?? 0,
      end: (raw['end'] as num?)?.toDouble() ?? 0,
      prob: (raw['prob'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Below this per-word probability the player underlines a word as one
/// worth checking. Mirrors `export::LOW_WORD_PROB` in rust_core.
const double kLowWordProb = 0.6;

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

  /// Average log probability per token from Whisper (negative, e.g. -0.5).
  /// Mirrors rust_core's Segment.avg_log_prob; not surfaced in the UI today
  /// but carried through so export round-trips don't silently drop it.
  final double avgLogProb;

  /// Per-word spans, when the engine produced them. Empty for every
  /// transcript written before Sprint 4b, and for a segment the user has
  /// edited by hand — see [copyWith].
  final List<TranscriptWord> words;

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
    this.avgLogProb = 0.0,
    this.words = const [],
  });

  /// Whether this segment can drive the karaoke highlight and
  /// click-a-word-to-seek.
  bool get hasWordTimings => words.isNotEmpty;

  /// The word being spoken at [seconds], or `null` outside the segment.
  TranscriptWord? wordAt(double seconds) {
    for (final word in words) {
      if (word.contains(seconds)) return word;
    }
    return null;
  }

  /// [text] edits invalidate the word spans: the words the user typed were
  /// never aligned to the audio, and keeping the old spans would highlight
  /// the wrong word and seek to the wrong place. Changing only the speaker
  /// keeps them.
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
      avgLogProb: avgLogProb,
      words: (text == null || text == this.text) ? words : const [],
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

/// Severity of a [SessionNotice].
enum SessionNoticeLevel {
  /// The session is running, but with fewer sources than requested.
  warning,

  /// Something the user asked for has stopped working.
  error,
}

/// Something the engine has to tell the user *while* a session runs: a
/// capture source that couldn't be opened, or one that died mid-recording.
///
/// Distinct from the [AudioWatchdogNotifier] warning, which infers trouble
/// from twelve seconds of silence. These are reported by the engine the
/// moment they happen, and say which source and why.
class SessionNotice {
  final SessionNoticeLevel level;

  /// `'mic'`, `'spk'`, or `'session'` for one that isn't source-specific.
  final String source;
  final String message;

  const SessionNotice({
    required this.level,
    required this.source,
    required this.message,
  });
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
  // GPU acceleration for whisper inference (Vulkan/CUDA/Metal, whichever
  // backend the native build was compiled with). Off by default — opt-in,
  // not auto-detected, since low-VRAM devices can be slower on GPU once
  // the model doesn't fit and falls back to partial CPU offload.
  final bool gpuEnabled;
  final int gpuDevice;

  /// Stream captured audio straight to disk instead of holding it in RAM
  /// until Stop. On by default; the switch exists because this touches the
  /// capture path, and a release can fall back without a rebuild. The RAM
  /// path remains the fallback when the disk writer cannot be opened.
  final bool audioToDisk;

  /// Opt-in AI-summary endpoint configuration. Persisted by Rust alongside
  /// the rest of the settings; `enabled == false` means the app makes no
  /// outbound request at all.
  final SummarySettings summary;

  /// Kamus istilah (F3): the global term list plus its two switches.
  final GlossarySettings glossary;

  /// Summary templates the user wrote or duplicated (F8).
  final List<CustomSummaryTemplate> summaryTemplates;

  /// Kop surat / notulis defaults reused by every notulen export (F2).
  final NotulenDefaults notulen;

  /// Re-run the transcript with the accurate model after the meeting (F5).
  /// `null` = decide from the live model: on when the quick model was used.
  final bool? autoRetranscribe;

  /// Mode Kepatuhan UU PDP (F13). Off by default: every part of it either
  /// hides or deletes something, so none of it may start happening
  /// because the app updated.
  final PdpSettings pdp;

  /// Run RNNoise over the audio before transcription (F17). Off by
  /// default; see rust_core/src/denoise.rs for the trade-off.
  final bool noiseReduction;

  /// "Pemisahan pembicara akurat": sherpa-onnx neural diarization on the
  /// import, re-transcribe and post-stop paths instead of the lightweight
  /// acoustic clustering.
  ///
  /// Off by default — it needs ~34 MB of models the user has to agree to
  /// download, and the lightweight clustering is adequate for the
  /// two-source live case most sessions are. Mirrors
  /// `AppSettings::neural_diarization` in Rust.
  final bool neuralDiarization;

  /// Whether the user dismissed the "Tingkatkan akurasi" offer shown when
  /// the Rust-side model recommendation (`recommendDefaultModel`) disagrees
  /// with [defaultModel]. Mirrors
  /// `AppSettings::default_model_upgrade_dismissed` in Rust.
  final bool defaultModelUpgradeDismissed;

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
    this.gpuEnabled = false,
    this.gpuDevice = 0,
    this.audioToDisk = true,
    this.summary = kDefaultSummarySettings,
    this.glossary = kDefaultGlossarySettings,
    this.summaryTemplates = const [],
    this.notulen = kDefaultNotulenDefaults,
    this.autoRetranscribe,
    this.pdp = kDefaultPdpSettings,
    this.noiseReduction = false,
    this.neuralDiarization = false,
    this.defaultModelUpgradeDismissed = false,
  });

  factory AppSettings.defaults() => const AppSettings(
    theme: AppThemeMode.light,
    defaultModel: 'base',
    defaultMode: SessionMode.online,
    libraryPath: kDefaultLibraryPath,
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
    bool? gpuEnabled,
    int? gpuDevice,
    // `audioToDisk` used to be missing here, so every copyWith silently
    // reset the user's choice to the default.
    bool? audioToDisk,
    SummarySettings? summary,
    GlossarySettings? glossary,
    List<CustomSummaryTemplate>? summaryTemplates,
    NotulenDefaults? notulen,
    Object? autoRetranscribe = _sentinel,
    PdpSettings? pdp,
    bool? noiseReduction,
    bool? neuralDiarization,
    bool? defaultModelUpgradeDismissed,
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
      gpuEnabled: gpuEnabled ?? this.gpuEnabled,
      gpuDevice: gpuDevice ?? this.gpuDevice,
      audioToDisk: audioToDisk ?? this.audioToDisk,
      summary: summary ?? this.summary,
      glossary: glossary ?? this.glossary,
      summaryTemplates: summaryTemplates ?? this.summaryTemplates,
      notulen: notulen ?? this.notulen,
      autoRetranscribe: autoRetranscribe == _sentinel
          ? this.autoRetranscribe
          : autoRetranscribe as bool?,
      pdp: pdp ?? this.pdp,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      neuralDiarization: neuralDiarization ?? this.neuralDiarization,
      defaultModelUpgradeDismissed:
          defaultModelUpgradeDismissed ?? this.defaultModelUpgradeDismissed,
    );
  }
}

/// Compliance mode as a brand-new install has it: entirely inert.
const PdpSettings kDefaultPdpSettings = PdpSettings(
  enabled: false,
  redaction: RedactionConfig(
    nik: true,
    npwp: true,
    phone: true,
    email: true,
    bankAccount: true,
    names: [],
  ),
  retention: RetentionPolicy(audioDays: 0, transcriptDays: 0),
  consentReminder: false,
  consentText: '',
);

/// Field-level updates for the FRB-generated compliance types, which have
/// no `copyWith` of their own. Respelling five required fields per toggle
/// is how a checkbox ends up clearing the name list.
extension PdpSettingsCopy on PdpSettings {
  PdpSettings copyWith({
    bool? enabled,
    RedactionConfig? redaction,
    RetentionPolicy? retention,
    bool? consentReminder,
    String? consentText,
  }) => PdpSettings(
    enabled: enabled ?? this.enabled,
    redaction: redaction ?? this.redaction,
    retention: retention ?? this.retention,
    consentReminder: consentReminder ?? this.consentReminder,
    consentText: consentText ?? this.consentText,
  );

  /// The redaction config an export should actually use: empty unless the
  /// master switch is on, so a caller never has to check both.
  RedactionConfig get activeRedaction => enabled
      ? redaction
      : const RedactionConfig(
          nik: false,
          npwp: false,
          phone: false,
          email: false,
          bankAccount: false,
          names: [],
        );

  bool get redacts =>
      enabled &&
      (redaction.nik ||
          redaction.npwp ||
          redaction.phone ||
          redaction.email ||
          redaction.bankAccount ||
          redaction.names.isNotEmpty);
}

extension RedactionConfigCopy on RedactionConfig {
  RedactionConfig copyWith({
    bool? nik,
    bool? npwp,
    bool? phone,
    bool? email,
    bool? bankAccount,
    List<String>? names,
  }) => RedactionConfig(
    nik: nik ?? this.nik,
    npwp: npwp ?? this.npwp,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    bankAccount: bankAccount ?? this.bankAccount,
    names: names ?? this.names,
  );
}

extension RetentionPolicyCopy on RetentionPolicy {
  RetentionPolicy copyWith({int? audioDays, int? transcriptDays}) =>
      RetentionPolicy(
        audioDays: audioDays ?? this.audioDays,
        transcriptDays: transcriptDays ?? this.transcriptDays,
      );
}

/// Field-level update for [GlossarySettings]. FRB generates no `copyWith`,
/// and respelling three required fields per settings callback is how a
/// toggle ends up clearing the term list.
extension GlossarySettingsCopy on GlossarySettings {
  GlossarySettings copyWith({
    bool? enabled,
    List<String>? terms,
    bool? postCorrection,
    List<ReplacementRule>? replacements,
  }) {
    return GlossarySettings(
      enabled: enabled ?? this.enabled,
      terms: terms ?? this.terms,
      postCorrection: postCorrection ?? this.postCorrection,
      replacements: replacements ?? this.replacements,
    );
  }

  /// Per-session glossary config: `sessionTerms` on top of the global list.
  /// Returns an empty config when the feature is off, so callers need no
  /// special case (mirrors `GlossarySettings::to_config` in Rust).
  GlossaryConfig toConfig({List<String> sessionTerms = const []}) {
    if (!enabled) {
      return const GlossaryConfig(
        sessionTerms: [],
        globalTerms: [],
        postCorrection: false,
        replacements: [],
      );
    }
    return GlossaryConfig(
      sessionTerms: sessionTerms,
      globalTerms: terms,
      postCorrection: postCorrection,
      replacements: replacements,
    );
  }
}

/// Field-level update for [NotulenDefaults].
extension NotulenDefaultsCopy on NotulenDefaults {
  NotulenDefaults copyWith({
    String? unitKerja,
    String? tempat,
    String? notulis,
    String? kopSuratPath,
  }) {
    return NotulenDefaults(
      unitKerja: unitKerja ?? this.unitKerja,
      tempat: tempat ?? this.tempat,
      notulis: notulis ?? this.notulis,
      kopSuratPath: kopSuratPath ?? this.kopSuratPath,
    );
  }
}

/// Field-level update for a user-authored summary template.
extension CustomSummaryTemplateCopy on CustomSummaryTemplate {
  CustomSummaryTemplate copyWith({
    String? name,
    String? instructions,
    List<String>? headings,
  }) {
    return CustomSummaryTemplate(
      id: id,
      name: name ?? this.name,
      instructions: instructions ?? this.instructions,
      headings: headings ?? this.headings,
    );
  }
}

/// Field-level update for [SummarySettings]. FRB generates the class without
/// a `copyWith`, and respelling seven required fields at every settings
/// callback is where a typo silently swaps `baseUrl` and `apiKey`.
extension SummarySettingsCopy on SummarySettings {
  SummarySettings copyWith({
    bool? enabled,
    SummaryProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
    SummaryTemplate? template,
    String? customPrompt,
    bool? withCitations,
    bool? withActionItems,
  }) {
    return SummarySettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      template: template ?? this.template,
      customPrompt: customPrompt ?? this.customPrompt,
      withCitations: withCitations ?? this.withCitations,
      withActionItems: withActionItems ?? this.withActionItems,
    );
  }

  /// Whether a summary can actually be requested: the feature is on and both
  /// the endpoint and the model are filled in.
  bool get isUsable =>
      enabled && baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  /// Runtime config for the bridge call. Kept here so every caller sends the
  /// same timeout and language.
  SummaryConfig toConfig({String? language, SummaryTemplate? template}) {
    return SummaryConfig(
      provider: provider,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      template: template ?? this.template,
      customPrompt: customPrompt,
      language: language ?? 'id',
      timeoutSecs: BigInt.from(180),
      withCitations: withCitations,
      withActionItems: withActionItems,
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
