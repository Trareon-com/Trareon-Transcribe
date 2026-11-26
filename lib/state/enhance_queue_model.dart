/// "Antrean perhalus" — the background pass queue.
///
/// Two kinds of job share it, because they share every constraint and the
/// user experiences them as one thing ("the app is still working on that
/// meeting"):
///
/// * [EnhanceJobKind.complete] (ITEM 0) — **the transcript is missing
///   audio.** The live worker is one Whisper thread; when the chosen model
///   runs slower than real time its input backlog grows all meeting and
///   Stop cannot wait for it. A real 6-minute session recorded by this app
///   came back with 8 seconds of transcript. This job re-transcribes
///   exactly the uncovered stretches from the saved WAV, per source, with
///   the model the user actually chose.
/// * [EnhanceJobKind.enhance] (F5) — the transcript is complete but came
///   from the quick model, and the accurate one is installed.
///
/// Completion always outranks enhancement: missing text is a defect,
/// better text is an improvement.
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
/// * **Survives a restart.** Which tracks are still untranscribed lives in
///   the session's sidecar ([SessionMeta.pendingCompletion]), not only in
///   this queue, so quitting mid-pass resumes rather than silently drops
///   the rest of the meeting.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../services/session_store.dart';
import '../src/rust/api.dart' as rust_api;
import '../src/rust/stt/file.dart' as rust_stt_file;
import '../utils/atomic_file.dart';
import 'library_model.dart';
import 'models.dart';
import 'settings_model.dart';

/// The model the background pass upgrades to.
const String kAccurateModelId = 'large-v3-turbo-q5';

/// Sentinel distinguishing "leave [EnhanceJob.stage] alone" from "set it to
/// null" in [EnhanceJob.copyWith] — the field itself is nullable, so a plain
/// `stage ?? this.stage` could never clear it back to null (e.g. once a job
/// finishes and no stage applies any more).
const Object _unset = Object();

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
/// Pure, so the rule — off unless the user explicitly opted in from
/// Settings — is one testable function rather than a condition spread
/// across the UI.
bool shouldAutoEnhance({
  required bool usedQuickModel,
  required bool accurateModelInstalled,
  required bool hasAudio,
  required bool alreadyDone,
  required bool liveModelWasAccurate,
  bool liveModelWasExperimental = false,
  bool? preference,
}) {
  // Off unless the user explicitly turned it on in Settings. A silent
  // default-on background pass with no visible switch is exactly the
  // surprise this setting exists to prevent.
  if (preference != true) return false;
  if (alreadyDone || !accurateModelInstalled || !hasAudio) return false;
  if (liveModelWasAccurate) return false;
  // The enhance pass is whisper. Over an Eksperimental (Qwen3-ASR) session
  // it would replace the engine the user picked with a less accurate one,
  // and stitch two engines' "handwriting" into one notulen.
  if (liveModelWasExperimental) return false;
  return true;
}

enum EnhanceJobStatus { queued, running, done, failed, cancelled }

/// What a queued pass is for. Order matters: [complete] sorts first.
enum EnhanceJobKind {
  /// Audio the transcript does not account for (ITEM 0).
  complete,

  /// A complete transcript that could be more accurate (F5).
  enhance,
}

/// The capture source a job's audio file belongs to. Matches the engine's
/// `source` tags so labels ("Saya" / "Peserta N") come out the same as the
/// live pass produced.
String sourceForAudioPath(String audioPath) {
  final name = audioPath.split(Platform.pathSeparator).last.split('/').last;
  return switch (name) {
    'mic.wav' => 'mic',
    'speaker.wav' => 'spk',
    _ => 'file',
  };
}

/// Indonesian label for a source, for the progress line.
String sourceLabel(String source) => switch (source) {
  'mic' => 'mikrofon',
  'spk' => 'audio sistem',
  _ => 'rekaman',
};

/// One track waiting for, or undergoing, a background pass.
@immutable
class EnhanceJob {
  const EnhanceJob({
    required this.directoryPath,
    required this.title,
    required this.audioPath,
    required this.language,
    this.kind = EnhanceJobKind.enhance,
    this.modelId = kAccurateModelId,
    this.status = EnhanceJobStatus.queued,
    this.error,
    this.progress = 0,
    this.etaSecs = 0,
    this.stage,
  });

  final String directoryPath;
  final String title;
  final String audioPath;
  final String? language;
  final EnhanceJobKind kind;

  /// Model this pass runs with. For [EnhanceJobKind.complete] it is the
  /// model the session was recorded with, so the recovered text matches the
  /// live text in quality; for [EnhanceJobKind.enhance] it is always
  /// [kAccurateModelId], which is the point of that job.
  final String modelId;

  final EnhanceJobStatus status;
  final String? error;

  /// `0.0..=1.0` for a running job — from the engine's per-source progress
  /// slot for [EnhanceJobKind.complete], and from the shared batch-progress
  /// slot (the same one file import polls) for [EnhanceJobKind.enhance].
  final double progress;
  final double etaSecs;

  /// Indonesian stage label for a running job (Sprint 14b, item 10b):
  /// "Menyiapkan model" -> "Mentranskripsi" -> "Menggabungkan" -> "Selesai".
  /// `null` while queued/done/failed, or for the rare running job whose
  /// engine call hasn't reported a stage yet.
  final String? stage;

  /// Stable identity. One session can have two completion jobs (mic and
  /// speaker) plus an enhancement, so the directory alone is not enough.
  String get id => '$directoryPath $audioPath ${kind.name}';

  String get source => sourceForAudioPath(audioPath);

  EnhanceJob copyWith({
    EnhanceJobStatus? status,
    String? error,
    double? progress,
    double? etaSecs,
    Object? stage = _unset,
  }) => EnhanceJob(
    directoryPath: directoryPath,
    title: title,
    audioPath: audioPath,
    language: language,
    kind: kind,
    modelId: modelId,
    status: status ?? this.status,
    error: error ?? this.error,
    progress: progress ?? this.progress,
    etaSecs: etaSecs ?? this.etaSecs,
    stage: identical(stage, _unset) ? this.stage : stage as String?,
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

  /// Queued jobs, completion first. A session missing audio is a defect
  /// waiting to be fixed; a session that could read better is not.
  List<EnhanceJob> get pending {
    final queued = jobs
        .where((j) => j.status == EnhanceJobStatus.queued)
        .toList();
    queued.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return queued;
  }

  /// Jobs worth showing in the sidebar: anything not yet finished, plus the
  /// most recent failure so an error is not silently dropped.
  List<EnhanceJob> get visible => jobs
      .where(
        (j) =>
            j.status == EnhanceJobStatus.queued ||
            j.status == EnhanceJobStatus.running ||
            j.status == EnhanceJobStatus.failed,
      )
      .toList();

  /// Unfinished work for one session, for the player's status line.
  List<EnhanceJob> completionJobsFor(String directoryPath) => jobs
      .where(
        (j) =>
            j.directoryPath == directoryPath &&
            j.kind == EnhanceJobKind.complete &&
            (j.status == EnhanceJobStatus.queued ||
                j.status == EnhanceJobStatus.running),
      )
      .toList();

  /// Whether anything is still outstanding — what the quit confirmation
  /// and the "belum selesai" badges key off.
  bool get hasPendingWork => jobs.any(
    (j) =>
        j.status == EnhanceJobStatus.queued ||
        j.status == EnhanceJobStatus.running,
  );

  /// Whether a session still has audio nobody has transcribed.
  bool isCompletingSession(String directoryPath) =>
      completionJobsFor(directoryPath).isNotEmpty;

  EnhanceQueueState copyWith({List<EnhanceJob>? jobs, bool? paused}) =>
      EnhanceQueueState(jobs: jobs ?? this.jobs, paused: paused ?? this.paused);
}

/// The Indonesian status line for a completion job: "Menyelesaikan
/// transkrip… 34%", with the source named when a session has more than one
/// track in flight and an ETA once there is one worth showing.
///
/// Pure, so the exact wording is testable without building a widget — the
/// user reads this line more often than any other part of the feature.
String completionStatusLine(
  List<EnhanceJob> jobs, {
  bool includeSource = true,
}) {
  if (jobs.isEmpty) return '';
  final running = jobs
      .where((j) => j.status == EnhanceJobStatus.running)
      .toList();
  if (running.isEmpty) {
    return jobs.length == 1
        ? 'Menunggu antrean untuk menyelesaikan transkrip.'
        : 'Menunggu antrean untuk menyelesaikan ${jobs.length} rekaman.';
  }
  final parts = <String>[];
  for (final job in running) {
    final percent = (job.progress.clamp(0.0, 1.0) * 100).round();
    final where = includeSource && jobs.length > 1
        ? ' (${sourceLabel(job.source)})'
        : '';
    final eta = job.etaSecs >= 5 ? ', sisa ${_humanEta(job.etaSecs)}' : '';
    parts.add('Menyelesaikan transkrip…$where $percent%$eta');
  }
  return parts.join('\n');
}

/// "45 detik" / "12 menit" / "1 jam 5 menit". Indonesian, and never
/// "0.7 jam" — an ETA the user has to convert is not an ETA.
String formatEta(double seconds) => _humanEta(seconds);

String _humanEta(double seconds) {
  if (seconds < 60) return '${seconds.round()} detik';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes menit';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours jam' : '$hours jam $rest menit';
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
  EnhanceQueueNotifier(this._bridge, this._settings, {this.onSessionChanged})
    : super(const EnhanceQueueState());

  final RustBridge _bridge;

  /// Called after a pass rewrites a session's transcript on disk.
  ///
  /// The library index caches each session's segment count and duration
  /// keyed on the transcript's size and mtime, and nothing was telling it
  /// those had changed: after a completion pass turned a 15-segment live
  /// preview into a 38-segment transcript, the sidebar still said "1
  /// menit · 15 segmen" until the next full library load. Optional so the
  /// queue stays testable without a library.
  final void Function()? onSessionChanged;

  /// Read lazily so the queue always uses the *current* library path and
  /// glossary rather than whatever they were when the app started.
  final AppSettings Function() _settings;

  bool _draining = false;
  bool _cancelCurrent = false;
  Future<void> _drainTask = Future<void>.value();

  /// Completes when the queue has nothing left to run.
  ///
  /// The drain loop is deliberately fire-and-forget — queueing a job must not
  /// block the save that triggered it — so this is the only honest way for a
  /// caller (a test, or a shutdown path that wants the last write to land) to
  /// know the pass finished. Waiting a fixed number of milliseconds instead
  /// looks like it works and fails on a slow disk.
  Future<void> get idle => _drainTask;

  /// Yields to a live recording and resumes when it ends.
  void setPaused(bool paused) {
    if (state.paused == paused) return;
    state = state.copyWith(paused: paused);
    if (!paused) _schedule();
  }

  /// Starts a drain pass unless one is already running — an in-flight loop
  /// re-reads [EnhanceQueueState.pending] each iteration, so it picks up
  /// whatever was just added without a second loop.
  void _schedule() {
    if (_draining) return;
    // `_drain` sets `_draining` before its first `await`, so this assignment
    // always captures the real loop rather than an early return.
    _drainTask = _drain();
  }

  /// Queues whatever [handoff]'s session needs: a completion pass per
  /// captured track whose audio the transcript does not account for, then
  /// an enhancement pass if the rules call for one. Returns true when at
  /// least one job was added.
  ///
  /// The coverage check runs before the enhancement decision because the
  /// two answer different questions, and the completion one comes first:
  /// polishing a transcript that is missing five minutes of the meeting
  /// polishes the wrong thing.
  Future<bool> considerSession(SavedSessionHandoff handoff) async {
    final completing = await _enqueueCompletion(handoff);
    final enhancing = await _enqueueEnhancement(handoff);
    if (completing || enhancing) _schedule();
    return completing || enhancing;
  }

  /// Per-track completion jobs for a just-saved session, recorded in the
  /// sidecar so a restart picks up where this left off.
  Future<bool> _enqueueCompletion(SavedSessionHandoff handoff) async {
    final tracks = capturedTracks(handoff.directoryPath);
    if (tracks.isEmpty) return false;
    final meta = await readSessionMeta(handoff.directoryPath);
    final incomplete = <String>[];
    var worstFraction = 1.0;
    for (final track in tracks) {
      try {
        final coverage = await _bridge.transcriptCoverage(
          segments: handoff.segments
              .where((s) => s.source == sourceForAudioPath(track.path))
              .toList(),
          audioPath: track.path,
        );
        if (coverage.gaps.isEmpty) continue;
        incomplete.add(track.path);
        worstFraction = worstFraction < coverage.fraction
            ? worstFraction
            : coverage.fraction;
      } catch (e) {
        // A coverage check that cannot run must not invent a gap: an
        // unreadable WAV is reported by the save path, and queueing a pass
        // that will immediately fail only adds a second error.
        debugPrint('coverage check failed for ${track.path}: $e');
      }
    }
    if (incomplete.isEmpty) {
      if (meta.pendingCompletion.isNotEmpty || meta.coverageFraction != 1.0) {
        await writeSessionMeta(
          handoff.directoryPath,
          meta.copyWith(pendingCompletion: const [], coverageFraction: 1.0),
        );
      }
      return false;
    }
    await writeSessionMeta(
      handoff.directoryPath,
      meta.copyWith(
        pendingCompletion: incomplete,
        coverageFraction: worstFraction,
      ),
    );
    var added = false;
    for (final path in incomplete) {
      added |= _addJob(
        EnhanceJob(
          directoryPath: handoff.directoryPath,
          title: handoff.title,
          audioPath: path,
          language: handoff.language,
          kind: EnhanceJobKind.complete,
          modelId: handoff.modelId,
        ),
      );
    }
    return added;
  }

  Future<bool> _enqueueEnhancement(SavedSessionHandoff handoff) async {
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
      liveModelWasExperimental: isExperimentalModel(handoff.modelId),
      preference: handoff.autoRetranscribePreference,
    );
    if (!enqueue || audio == null) return false;
    return _addJob(
      EnhanceJob(
        directoryPath: handoff.directoryPath,
        title: handoff.title,
        audioPath: audio.path,
        language: handoff.language,
      ),
    );
  }

  /// Re-queues completion work the sidecars say is outstanding.
  ///
  /// Called once at startup with the loaded library. This is what turns
  /// "persist progress" into something real: the queue is in memory, but
  /// which tracks are still untranscribed is on disk next to the session,
  /// so quitting mid-pass resumes rather than quietly dropping the rest of
  /// the meeting.
  Future<int> resumePending(
    Iterable<({String dirPath, String title})> sessions,
  ) async {
    var added = 0;
    for (final session in sessions) {
      final meta = await readSessionMeta(session.dirPath);
      if (meta.pendingCompletion.isEmpty) continue;
      for (final path in meta.pendingCompletion) {
        if (!File(path).existsSync()) continue;
        if (_addJob(
          EnhanceJob(
            directoryPath: session.dirPath,
            title: session.title,
            audioPath: path,
            language: meta.language,
            kind: EnhanceJobKind.complete,
            modelId: meta.model ?? kAccurateModelId,
          ),
        )) {
          added++;
        }
      }
    }
    if (added > 0) _schedule();
    return added;
  }

  /// Adds [job] unless the same track is already queued or running.
  bool _addJob(EnhanceJob job) {
    final alreadyActive = state.jobs.any(
      (existing) =>
          existing.id == job.id &&
          (existing.status == EnhanceJobStatus.queued ||
              existing.status == EnhanceJobStatus.running),
    );
    if (alreadyActive) return false;
    state = state.copyWith(
      jobs: [...state.jobs.where((existing) => existing.id != job.id), job],
    );
    return true;
  }

  /// Cancels every queued job for a session, or asks the running one to
  /// stop.
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
    state = state.copyWith(
      jobs: [
        for (final job in state.jobs)
          if (job.directoryPath == directoryPath &&
              job.status == EnhanceJobStatus.queued)
            job.copyWith(status: EnhanceJobStatus.cancelled)
          else
            job,
      ],
    );
  }

  void cancelAll() {
    _cancelCurrent = true;
    state = state.copyWith(
      jobs: [
        for (final job in state.jobs)
          if (job.status == EnhanceJobStatus.queued ||
              job.status == EnhanceJobStatus.running)
            job.copyWith(status: EnhanceJobStatus.cancelled)
          else
            job,
      ],
    );
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
    _updateJob(job.id, EnhanceJobStatus.running);
    switch (job.kind) {
      case EnhanceJobKind.complete:
        await _runCompletion(job);
      case EnhanceJobKind.enhance:
        await _runEnhancement(job);
    }
  }

  /// Transcribes the stretches of one track the live pass never reached,
  /// merges them in and clears that track from the sidecar's pending list.
  Future<void> _runCompletion(EnhanceJob job) async {
    final settings = _settings();
    final progress = _watchProgress(job);
    try {
      final directory = Directory(job.directoryPath);
      final transcriptFile = transcriptFileIn(directory);
      final previous = transcriptFile == null
          ? const <TranscriptSegment>[]
          : parseTranscriptJson(await transcriptFile.readAsString());
      final source = job.source;
      final own = previous.where((s) => s.source == source).toList();

      final outcome = await _bridge.completeSessionTranscript(
        modelPath: modelPathForId(
          job.modelId,
          libraryPath: settings.libraryPath,
        ),
        audioPath: job.audioPath,
        jobKey: job.directoryPath,
        existing: own,
        language: job.language,
        gpuEnabled: settings.gpuEnabled,
        gpuDevice: settings.gpuDevice,
        glossary: settings.glossary.toConfig(),
        vadEnabled: settings.vadEnabled,
      );
      if (_cancelCurrent) {
        _updateJob(job.id, EnhanceJobStatus.cancelled);
        return;
      }
      // This track's slice of the transcript is replaced wholesale; every
      // other source is untouched, so a session's two tracks can complete
      // independently and in any order.
      final merged = [
        ...previous.where((s) => s.source != source),
        ...outcome.segments.map(fromRustSegment),
      ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (previous.isNotEmpty) {
        await backupTranscript(job.directoryPath, previous);
      }
      final target =
          transcriptFile ??
          File(
            '${job.directoryPath}${Platform.pathSeparator}'
            '${job.title}.json',
          );
      await writeStringAtomic(target, encodeTranscriptJson(merged));

      final meta = await readSessionMeta(job.directoryPath);
      final remaining = meta.pendingCompletion
          .where((path) => path != job.audioPath)
          .toList();
      final thisTrack = outcome.speechSecs <= 0
          ? 1.0
          : (outcome.speechCoveredSecs / outcome.speechSecs).clamp(0.0, 1.0);
      await writeSessionMeta(
        job.directoryPath,
        meta.copyWith(
          bookmarks: retainAlignedBookmarks(meta.bookmarks, merged),
          pendingCompletion: remaining,
          // A session is only as complete as its least-complete track.
          // Last-writer-wins put a silent mic track's 100% over a speaker
          // track that was still missing five minutes, which is the exact
          // overclaim this sprint exists to stop.
          coverageFraction: remaining.isEmpty
              ? thisTrack
              : thisTrack < (meta.coverageFraction ?? 1.0)
              ? thisTrack
              : meta.coverageFraction,
        ),
      );
      _updateJob(job.id, EnhanceJobStatus.done, progress: 1);
      // The transcript on disk is now longer than the index believes.
      onSessionChanged?.call();
    } catch (e) {
      _updateJob(job.id, EnhanceJobStatus.failed, error: '$e');
    } finally {
      progress.cancel();
    }
  }

  /// Polls the engine's per-source progress slot while a completion pass
  /// runs. Without it the sidebar would show a spinner for however long
  /// the pass takes — up to an hour on a weak CPU with a big model.
  Timer _watchProgress(EnhanceJob job) {
    return Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      try {
        final slots = await _bridge.completionProgress();
        final slot = slots
            .where(
              (p) => p.jobKey == job.directoryPath && p.source == job.source,
            )
            .firstOrNull;
        if (slot == null || !mounted) return;
        _updateJob(
          job.id,
          EnhanceJobStatus.running,
          progress: slot.fraction,
          etaSecs: slot.etaSecs,
        );
      } catch (_) {
        // Progress is cosmetic; a failed poll must never fail the pass.
      }
    });
  }

  Future<void> _runEnhancement(EnhanceJob job) async {
    final settings = _settings();
    _updateJob(
      job.id,
      EnhanceJobStatus.running,
      progress: 0,
      stage: 'Menyiapkan model',
    );
    final progress = _watchEnhanceProgress(job);
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
        _updateJob(job.id, EnhanceJobStatus.cancelled, stage: null);
        return;
      }
      final outcome = outcomes.firstOrNull;
      final enhanced =
          outcome?.result?.segments.map(fromRustSegment).toList() ??
          const <TranscriptSegment>[];
      if (enhanced.isEmpty) {
        _updateJob(
          job.id,
          EnhanceJobStatus.failed,
          error: outcome?.error ?? 'Tidak ada ucapan terdeteksi.',
          stage: null,
        );
        return;
      }
      // The engine call has returned; what is left is writing the merged
      // transcript to disk. Brief on a short recording, but a worthwhile
      // label on a long one — either way it is a real, distinct stage, not
      // a guess.
      _updateJob(
        job.id,
        EnhanceJobStatus.running,
        progress: 0.95,
        stage: 'Menggabungkan',
      );
      await _replaceTranscript(job, enhanced);
      _updateJob(job.id, EnhanceJobStatus.done, progress: 1, stage: null);
    } catch (e) {
      _updateJob(job.id, EnhanceJobStatus.failed, error: '$e', stage: null);
    } finally {
      progress.cancel();
    }
  }

  /// Polls the engine's batch-progress slot — the same one file import uses
  /// — while the F5 accurate pass runs. Before this the sidebar card showed
  /// a bare spinner and the static "Memakai model akurat…" line for however
  /// long a whole-session re-transcription takes, which on a weak CPU with a
  /// big model is the exact "three silent spinners" complaint Sprint 14b
  /// item 10b exists to fix.
  Timer _watchEnhanceProgress(EnhanceJob job) {
    return Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      try {
        final snapshot = await _bridge.batchProgress();
        if (snapshot == null || !mounted) return;
        final (stage, fraction) = switch (snapshot.status) {
          rust_stt_file.BatchFileStatus.queued => ('Menyiapkan model', 0.0),
          rust_stt_file.BatchFileStatus.decoding => ('Menyiapkan model', 0.05),
          rust_stt_file.BatchFileStatus.transcribing => (
            'Mentranskripsi',
            0.1 + snapshot.progress.clamp(0.0, 1.0) * 0.8,
          ),
          rust_stt_file.BatchFileStatus.done => ('Menggabungkan', 0.95),
          rust_stt_file.BatchFileStatus.error => ('Menyiapkan model', 0.0),
        };
        _updateJob(
          job.id,
          EnhanceJobStatus.running,
          progress: fraction,
          stage: stage,
        );
      } catch (_) {
        // Progress is cosmetic; a failed poll must never fail the pass.
      }
    });
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
    final target =
        transcriptFile ??
        File(
          '${job.directoryPath}${Platform.pathSeparator}'
          '${job.title}.json',
        );
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
    if (_settings().pdp.enabled) {
      unawaited(
        rust_api
            .writeAuditEntry(
              action: AuditAction.transcriptEnhanced,
              subject: job.title,
              destination: kAccurateModelId,
              detail: '${merged.length} segmen',
            )
            .catchError((_) {}),
      );
    }
  }

  void _updateJob(
    String id,
    EnhanceJobStatus status, {
    String? error,
    double? progress,
    double? etaSecs,
    Object? stage = _unset,
  }) {
    state = state.copyWith(
      jobs: [
        for (final job in state.jobs)
          if (job.id == id)
            job.copyWith(
              status: status,
              error: error,
              progress: progress,
              etaSecs: etaSecs,
              stage: stage,
            )
          else
            job,
      ],
    );
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
              .where(
                (f) => kAudioExtensions.contains(
                  f.path.split('.').last.toLowerCase(),
                ),
              )
              .firstOrNull;
    } catch (_) {
      return null;
    }
  }
}

/// Every live-capture track in a session directory.
///
/// Only `mic.wav` / `speaker.wav`: an imported file has no "part the live
/// pass missed", because there was no live pass. Returning it here would
/// re-transcribe every import the moment it was saved.
List<File> capturedTracks(String directoryPath) {
  try {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) return const [];
    final files = directory.listSync().whereType<File>().toList();
    return [
      for (final name in const ['mic.wav', 'speaker.wav'])
        ...files.where((f) => f.uri.pathSegments.last == name),
    ];
  } catch (_) {
    return const [];
  }
}

final enhanceQueueProvider =
    StateNotifierProvider<EnhanceQueueNotifier, EnhanceQueueState>((ref) {
      return EnhanceQueueNotifier(
        ref.read(rustBridgeProvider),
        () => ref.read(settingsProvider),
        onSessionChanged: () =>
            unawaited(ref.read(libraryListProvider.notifier).refresh()),
      );
    });
