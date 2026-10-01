/// "Perhalus transkrip" — the background re-transcribe queue (F5).
///
/// On a weak CPU the live pass has to use the quick model or the transcript
/// falls behind the meeting. That is a real compromise, and the fix is to run
/// the accurate model over the saved audio *after* the meeting, while the user
/// is doing something else. This turns the slow-device compromise into a
/// feature, which is why it is on by default whenever the live pass used the
/// quick model.
///
/// Design constraints, all of them learned from the audit:
///
/// * **One job at a time.** Whisper saturates the CPU; two concurrent passes
///   would make both slower than either alone, and would fight the next live
///   recording for the same cores.
/// * **Cancellable, and paused by a live session.** Starting a new meeting
///   takes priority over polishing the last one.
/// * **The transcript is only replaced on success**, after a backup, and
///   manual speaker renames and bookmarks survive where timestamps line up.
/// * **Never twice.** A finished pass is recorded in the sidecar.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../services/session_store.dart';
import '../utils/atomic_file.dart';
import 'models.dart';
import 'settings_model.dart';

/// The model the background pass upgrades to.
const String kAccurateModelId = 'large-v3-turbo-q5';

/// What a just-saved session hands to the queue.
///
/// A plain value rather than a reference to `SessionNotifier`, so the session
/// does not have to know the queue exists.
class SavedSessionHandoff {
  const SavedSessionHandoff({
    required this.directoryPath,
    required this.title,
    required this.modelId,
    required this.language,
    required this.usedQuickModel,
    required this.autoRetranscribePreference,
    required this.segments,
  });

  final String directoryPath;
  final String title;

  /// Model the live pass used.
  final String modelId;
  final String? language;

  /// Whether the live transcript came from the quick model (directly, or as
  /// the first pass of progressive mode).
  final bool usedQuickModel;

  /// `AppSettings.autoRetranscribe`: `true`/`false` to force, `null` to let
  /// [shouldAutoEnhance] decide from the model that was used.
  final bool? autoRetranscribePreference;

  final List<TranscriptSegment> segments;
}

/// Whether a saved session should be queued for a background accurate pass.
///
/// Pure, so the default — "on when the live pass used the quick model" — is
/// one testable rule rather than a condition spread across the UI.
bool shouldAutoEnhance({
  required bool usedQuickModel,
  required bool accurateModelInstalled,
  required bool hasAudio,
  required bool alreadyDone,
  required bool liveModelWasAccurate,
  bool? preference,
}) {
  if (preference == false) return false;
  if (alreadyDone || !accurateModelInstalled || !hasAudio) return false;
  if (liveModelWasAccurate) return false;
  if (preference == true) return true;
  return usedQuickModel;
}

enum EnhanceJobStatus { queued, running, done, failed, cancelled }

/// One session waiting for, or undergoing, the accurate pass.
@immutable
class EnhanceJob {
  const EnhanceJob({
    required this.directoryPath,
    required this.title,
    required this.audioPath,
    required this.language,
    this.status = EnhanceJobStatus.queued,
    this.error,
  });

  final String directoryPath;
  final String title;
  final String audioPath;
  final String? language;
  final EnhanceJobStatus status;
  final String? error;

  EnhanceJob copyWith({EnhanceJobStatus? status, String? error}) => EnhanceJob(
    directoryPath: directoryPath,
    title: title,
    audioPath: audioPath,
    language: language,
    status: status ?? this.status,
    error: error ?? this.error,
  );
}

@immutable
class EnhanceQueueState {
  const EnhanceQueueState({this.jobs = const [], this.paused = false});

  final List<EnhanceJob> jobs;

  /// True while a live session is recording — the queue yields to it.
  final bool paused;

  EnhanceJob? get running =>
      jobs.where((j) => j.status == EnhanceJobStatus.running).firstOrNull;

  List<EnhanceJob> get pending =>
      jobs.where((j) => j.status == EnhanceJobStatus.queued).toList();

  /// Jobs worth showing in the sidebar: anything not yet finished, plus the
  /// most recent failure so an error is not silently dropped.
  List<EnhanceJob> get visible => jobs
      .where((j) =>
          j.status == EnhanceJobStatus.queued ||
          j.status == EnhanceJobStatus.running ||
          j.status == EnhanceJobStatus.failed)
      .toList();

  EnhanceQueueState copyWith({List<EnhanceJob>? jobs, bool? paused}) =>
      EnhanceQueueState(
        jobs: jobs ?? this.jobs,
        paused: paused ?? this.paused,
      );
}

/// Merges an accurate-pass transcript over the one the user may have edited.
///
/// Rule: the new text wins (that is the point of the pass), but a speaker
/// label the user changed by hand and any note they attached stay — matched by
/// timestamp within [toleranceSeconds], because the accurate pass segments the
/// audio slightly differently and exact equality would preserve nothing.
///
/// Pure and tested: this is the function that decides whether an hour of
/// manual correction survives.
List<TranscriptSegment> mergeEnhanced({
  required List<TranscriptSegment> previous,
  required List<TranscriptSegment> enhanced,
  double toleranceSeconds = 1.5,
}) {
  if (enhanced.isEmpty) return previous;
  // Engine-generated labels carry no user intent, so they must not override
  // the accurate pass's own labelling.
  const engineLabels = {'mic', 'spk', 'speaker', 'file', ''};
  final sorted = [...previous]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  TranscriptSegment? nearest(double timestamp) {
    TranscriptSegment? best;
    var bestDelta = double.infinity;
    for (final candidate in sorted) {
      final delta = (candidate.timestamp - timestamp).abs();
      if (delta > bestDelta) {
        // `sorted` is ascending, so once the distance starts growing the
        // nearest candidate is behind us.
        if (candidate.timestamp > timestamp) break;
        continue;
      }
      bestDelta = delta;
      best = candidate;
    }
    return bestDelta <= toleranceSeconds ? best : null;
  }

  return [
    for (final segment in enhanced)
      () {
        final match = nearest(segment.timestamp);
        if (match == null) return segment;
        final keepSpeaker =
            !engineLabels.contains(match.speaker.trim().toLowerCase()) &&
                match.speaker.trim() != segment.speaker.trim();
        return keepSpeaker ? segment.copyWith(speaker: match.speaker) : segment;
      }(),
  ];
}

/// Keeps every bookmark whose timestamp still falls inside the new
/// transcript's span. One that does not is dropped rather than clamped: a
/// marker pointing at the wrong moment is worse than no marker.
List<Bookmark> retainAlignedBookmarks(
  List<Bookmark> bookmarks,
  List<TranscriptSegment> enhanced,
) {
  if (bookmarks.isEmpty || enhanced.isEmpty) return bookmarks;
  final last = enhanced.last;
  final end = last.timestamp + last.duration;
  return bookmarks
      .where((bookmark) => bookmark.timestamp >= 0 && bookmark.timestamp <= end)
      .toList();
}

class EnhanceQueueNotifier extends StateNotifier<EnhanceQueueState> {
  EnhanceQueueNotifier(this._bridge, this._settings)
      : super(const EnhanceQueueState());

  final RustBridge _bridge;

  /// Read lazily so the queue always uses the *current* library path and
  /// glossary rather than whatever they were when the app started.
  final AppSettings Function() _settings;

  bool _draining = false;
  bool _cancelCurrent = false;

  /// Yields to a live recording and resumes when it ends.
  void setPaused(bool paused) {
    if (state.paused == paused) return;
    state = state.copyWith(paused: paused);
    if (!paused) unawaited(_drain());
  }

  /// Queues [handoff] if the rules say it should be enhanced. Returns true
  /// when a job was added.
  Future<bool> considerSession(SavedSessionHandoff handoff) async {
    final settings = _settings();
    final meta = await readSessionMeta(handoff.directoryPath);
    final audio = _findAudio(handoff.directoryPath);
    final accurateInstalled = isModelAvailable(
      kAccurateModelId,
      libraryPath: settings.libraryPath,
    );
    final enqueue = shouldAutoEnhance(
      usedQuickModel: handoff.usedQuickModel,
      accurateModelInstalled: accurateInstalled,
      hasAudio: audio != null,
      alreadyDone: meta.autoRetranscribeDone,
      liveModelWasAccurate: handoff.modelId == kAccurateModelId,
      preference: handoff.autoRetranscribePreference,
    );
    if (!enqueue || audio == null) return false;
    if (state.jobs.any((job) =>
        job.directoryPath == handoff.directoryPath &&
        (job.status == EnhanceJobStatus.queued ||
            job.status == EnhanceJobStatus.running))) {
      return false;
    }
    state = state.copyWith(jobs: [
      ...state.jobs,
      EnhanceJob(
        directoryPath: handoff.directoryPath,
        title: handoff.title,
        audioPath: audio.path,
        language: handoff.language,
      ),
    ]);
    unawaited(_drain());
    return true;
  }

  /// Cancels a queued job, or asks the running one to stop.
  ///
  /// A running job cannot be interrupted mid-inference — the engine call is a
  /// single FRB future — so cancelling it means its result is discarded rather
  /// than written. The transcript on disk is untouched either way, which is
  /// the property that matters.
  void cancel(String directoryPath) {
    final running = state.running;
    if (running?.directoryPath == directoryPath) {
      _cancelCurrent = true;
    }
    state = state.copyWith(jobs: [
      for (final job in state.jobs)
        if (job.directoryPath == directoryPath &&
            job.status == EnhanceJobStatus.queued)
          job.copyWith(status: EnhanceJobStatus.cancelled)
        else
          job,
    ]);
  }

  void cancelAll() {
    _cancelCurrent = true;
    state = state.copyWith(jobs: [
      for (final job in state.jobs)
        if (job.status == EnhanceJobStatus.queued ||
            job.status == EnhanceJobStatus.running)
          job.copyWith(status: EnhanceJobStatus.cancelled)
        else
          job,
    ]);
  }

  /// Clears finished and failed jobs from the visible list.
  void dismiss(String directoryPath) {
    state = state.copyWith(
      jobs: state.jobs
          .where((job) => job.directoryPath != directoryPath)
          .toList(),
    );
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (!state.paused) {
        final next = state.pending.firstOrNull;
        if (next == null) break;
        await _run(next);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _run(EnhanceJob job) async {
    _cancelCurrent = false;
    _updateJob(job.directoryPath, EnhanceJobStatus.running);
    final settings = _settings();
    try {
      final outcomes = await _bridge.batchTranscribeFiles(
        modelPath: modelPathForId(
          kAccurateModelId,
          libraryPath: settings.libraryPath,
        ),
        files: [job.audioPath],
        language: job.language,
        gpuEnabled: settings.gpuEnabled,
        gpuDevice: settings.gpuDevice,
        glossary: settings.glossary.toConfig(),
      );
      if (_cancelCurrent) {
        _updateJob(job.directoryPath, EnhanceJobStatus.cancelled);
        return;
      }
      final outcome = outcomes.firstOrNull;
      final enhanced =
          outcome?.result?.segments.map(fromRustSegment).toList() ??
              const <TranscriptSegment>[];
      if (enhanced.isEmpty) {
        _updateJob(
          job.directoryPath,
          EnhanceJobStatus.failed,
          error: outcome?.error ?? 'Tidak ada ucapan terdeteksi.',
        );
        return;
      }
      await _replaceTranscript(job, enhanced);
      _updateJob(job.directoryPath, EnhanceJobStatus.done);
    } catch (e) {
      _updateJob(job.directoryPath, EnhanceJobStatus.failed, error: '$e');
    }
  }

  /// Backs up, merges, writes, and records that the pass is done — in that
  /// order, so an interruption at any point leaves the previous transcript
  /// recoverable.
  Future<void> _replaceTranscript(
    EnhanceJob job,
    List<TranscriptSegment> enhanced,
  ) async {
    final directory = Directory(job.directoryPath);
    final transcriptFile = transcriptFileIn(directory);
    final previous = transcriptFile == null
        ? const <TranscriptSegment>[]
        : parseTranscriptJson(await transcriptFile.readAsString());

    if (previous.isNotEmpty) {
      await backupTranscript(job.directoryPath, previous);
    }
    final merged = mergeEnhanced(previous: previous, enhanced: enhanced);
    final target = transcriptFile ??
        File('${job.directoryPath}${Platform.pathSeparator}'
            '${job.title}.json');
    await writeStringAtomic(target, encodeTranscriptJson(merged));

    final meta = await readSessionMeta(job.directoryPath);
    await writeSessionMeta(
      job.directoryPath,
      meta.copyWith(
        model: kAccurateModelId,
        bookmarks: retainAlignedBookmarks(meta.bookmarks, merged),
        autoRetranscribeDone: true,
      ),
    );
  }

  void _updateJob(
    String directoryPath,
    EnhanceJobStatus status, {
    String? error,
  }) {
    state = state.copyWith(jobs: [
      for (final job in state.jobs)
        if (job.directoryPath == directoryPath)
          job.copyWith(status: status, error: error)
        else
          job,
    ]);
  }

  /// The session's playable audio: the live capture's `mic.wav` when there is
  /// one, otherwise the imported source file.
  File? _findAudio(String directoryPath) {
    try {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) return null;
      final files = directory.listSync().whereType<File>().toList();
      File? byName(String name) =>
          files.where((f) => f.uri.pathSegments.last == name).firstOrNull;
      return byName('mic.wav') ??
          byName('speaker.wav') ??
          files
              .where((f) => kAudioExtensions
                  .contains(f.path.split('.').last.toLowerCase()))
              .firstOrNull;
    } catch (_) {
      return null;
    }
  }
}

final enhanceQueueProvider =
    StateNotifierProvider<EnhanceQueueNotifier, EnhanceQueueState>((ref) {
  return EnhanceQueueNotifier(
    ref.read(rustBridgeProvider),
    () => ref.read(settingsProvider),
  );
});
