/// ITEM 0, Dart side: a session whose live pass fell behind must be queued
/// for completion, must say so while it is outstanding, and must survive a
/// restart.
///
/// The failure these guard is specific and was observed on this machine: a
/// 6-minute recording saved with 8 seconds of transcript, presented in the
/// library as a finished session.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/src/rust/completion.dart' as rust_completion;
import 'package:transcribe/src/rust/coverage.dart' as rust_coverage;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/glossary.dart' as rust_glossary;
import 'package:transcribe/state/enhance_queue_model.dart';
import 'package:transcribe/state/models.dart';

import 'test_helpers.dart';

TranscriptSegment seg({
  required double timestamp,
  required String text,
  String source = 'spk',
  double duration = 4,
}) => TranscriptSegment(
  source: source,
  speaker: 'Peserta 1',
  text: text,
  timestamp: timestamp,
  duration: duration,
  language: 'id',
  confidence: 0.9,
  isPartial: false,
);

rust_export.Segment rustSeg({
  required double timestamp,
  required String text,
  String source = 'spk',
  double duration = 4,
}) => rust_export.Segment(
  source: source,
  speaker: 'Peserta 1',
  text: text,
  timestamp: timestamp,
  duration: duration,
  language: 'id',
  confidence: 0.9,
  avgLogProb: -0.3,
  isPartial: false,
  lowConfidence: false,
);

/// A bridge that reports a gap and then fills it.
class _CompletionBridge extends NoopBridge {
  _CompletionBridge({
    this.gaps = const [rust_coverage.TimeRange(start: 8, end: 360)],
    this.recovered = const [],
  });

  final List<rust_coverage.TimeRange> gaps;
  final List<rust_export.Segment> recovered;

  final List<String> coverageChecks = [];
  final List<String> completionRuns = [];
  List<TranscriptSegment> lastExisting = const [];
  String? lastModelPath;

  @override
  Future<rust_coverage.CoverageReport> transcriptCoverage({
    required List<TranscriptSegment> segments,
    required String audioPath,
  }) async {
    coverageChecks.add(audioPath);
    return rust_coverage.CoverageReport(
      coveredSecs: 7,
      totalSecs: 360,
      fraction: 7 / 360,
      gaps: gaps,
      missingSecs: 352,
    );
  }

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
  }) async {
    completionRuns.add(audioPath);
    lastExisting = existing;
    lastModelPath = modelPath;
    return rust_completion.CompletionOutcome(
      segments: [...existing.map(toRustSegment), ...recovered],
      added: recovered.length,
      rejected: 0,
      coverage: kCompleteCoverage,
      speechSecs: 30,
      speechCoveredSecs: 30,
      audioSecs: 360,
    );
  }
}

/// A session directory shaped like one the app writes.
Future<Directory> plantSession(
  List<TranscriptSegment> transcript, {
  List<String> tracks = const ['speaker.wav'],
}) async {
  final dir = await Directory.systemTemp.createTemp('trareon_completion_');
  await File(
    p.join(dir.path, 'Sesi.json'),
  ).writeAsString(encodeTranscriptJson(transcript));
  for (final track in tracks) {
    await File(p.join(dir.path, track)).writeAsBytes(const [0, 0, 0, 0]);
  }
  return dir;
}

SavedSessionHandoff handoffFor(
  Directory dir,
  List<TranscriptSegment> segments, {
  String modelId = 'large-v3-turbo-q5',
}) => SavedSessionHandoff(
  directoryPath: dir.path,
  title: 'Sesi',
  modelId: modelId,
  language: 'id',
  usedQuickModel: false,
  autoRetranscribePreference: false,
  segments: segments,
);

void main() {
  group('sourceForAudioPath', () {
    test('maps the captured track filenames the engine writes', () {
      expect(sourceForAudioPath('/x/mic.wav'), 'mic');
      expect(sourceForAudioPath('/x/speaker.wav'), 'spk');
      expect(sourceForAudioPath('/x/rapat.m4a'), 'file');
    });
  });

  group('capturedTracks', () {
    test('finds both live tracks and ignores imported audio', () async {
      final dir = await plantSession(
        const [],
        tracks: const ['mic.wav', 'speaker.wav'],
      );
      await File(p.join(dir.path, 'impor.mp3')).writeAsBytes(const [0]);
      addTearDown(() => dir.delete(recursive: true));
      final names = capturedTracks(
        dir.path,
      ).map((f) => f.uri.pathSegments.last).toList();
      expect(names, ['mic.wav', 'speaker.wav']);
    });

    test('an import-only session has no captured tracks', () async {
      // An imported file was never live, so there is no part a live pass
      // missed. Queueing one would re-transcribe every import on save.
      final dir = await plantSession(const [], tracks: const []);
      await File(p.join(dir.path, 'rapat.m4a')).writeAsBytes(const [0]);
      addTearDown(() => dir.delete(recursive: true));
      expect(capturedTracks(dir.path), isEmpty);
    });
  });

  group('completionStatusLine', () {
    EnhanceJob job({
      required EnhanceJobStatus status,
      double progress = 0,
      double etaSecs = 0,
      String audioPath = '/x/speaker.wav',
    }) => EnhanceJob(
      directoryPath: '/x',
      title: 'Sesi',
      audioPath: audioPath,
      language: 'id',
      kind: EnhanceJobKind.complete,
      status: status,
      progress: progress,
      etaSecs: etaSecs,
    );

    test('shows the percentage the brief asks for', () {
      expect(
        completionStatusLine([
          job(status: EnhanceJobStatus.running, progress: 0.34),
        ]),
        'Menyelesaikan transkrip… 34%',
      );
    });

    test('adds an ETA once there is one worth showing', () {
      expect(
        completionStatusLine([
          job(status: EnhanceJobStatus.running, progress: 0.5, etaSecs: 90),
        ]),
        'Menyelesaikan transkrip… 50%, sisa 2 menit',
      );
      // Under 5 s the number churns faster than it can be read.
      expect(
        completionStatusLine([
          job(status: EnhanceJobStatus.running, progress: 0.99, etaSecs: 2),
        ]),
        'Menyelesaikan transkrip… 99%',
      );
    });

    test('names the source when a session has two tracks in flight', () {
      final line = completionStatusLine([
        job(
          status: EnhanceJobStatus.running,
          progress: 0.1,
          audioPath: '/x/mic.wav',
        ),
        job(
          status: EnhanceJobStatus.running,
          progress: 0.6,
          audioPath: '/x/speaker.wav',
        ),
      ]);
      expect(line, contains('(mikrofon) 10%'));
      expect(line, contains('(audio sistem) 60%'));
    });

    test('a queued job says it is waiting, not 0%', () {
      expect(
        completionStatusLine([job(status: EnhanceJobStatus.queued)]),
        'Menunggu antrean untuk menyelesaikan transkrip.',
      );
    });

    test('nothing outstanding is an empty line, not a stale one', () {
      expect(completionStatusLine(const []), '');
    });
  });

  group('formatEta', () {
    test('is Indonesian and never asks the user to convert units', () {
      expect(formatEta(45), '45 detik');
      expect(formatEta(90), '2 menit');
      expect(formatEta(600), '10 menit');
      expect(formatEta(3600), '1 jam');
      expect(formatEta(3900), '1 jam 5 menit');
    });
  });

  group('considerSession', () {
    test('queues a completion pass when the transcript misses audio', () async {
      final live = [seg(timestamp: 1, text: 'Selamat pagi semuanya.')];
      final dir = await plantSession(live);
      addTearDown(() => dir.delete(recursive: true));
      final bridge = _CompletionBridge();
      final queue = EnhanceQueueNotifier(
        bridge,
        () => AppSettings.defaults().copyWith(libraryPath: dir.path),
      );

      expect(await queue.considerSession(handoffFor(dir, live)), isTrue);
      expect(bridge.coverageChecks.single, endsWith('speaker.wav'));
      expect(queue.state.isCompletingSession(dir.path), isTrue);

      // On disk, so a restart can pick it up.
      final meta = await readSessionMeta(dir.path);
      expect(meta.isIncomplete, isTrue);
      expect(meta.pendingCompletion.single, endsWith('speaker.wav'));
      expect(meta.coverageFraction, closeTo(7 / 360, 1e-9));

      await queue.idle;
      expect(bridge.completionRuns.single, endsWith('speaker.wav'));
    });

    test('a finished pass tells the library its transcript grew', () async {
      // The library index caches each session's segment count keyed on
      // the transcript's size and mtime. Before this, a completion pass
      // could turn a 15-segment live preview into a 38-segment
      // transcript and the sidebar would still say "15 segmen" until the
      // next full library load — observed in the Sprint 4 smoke test.
      final live = [seg(timestamp: 1, text: 'Selamat pagi semuanya.')];
      final dir = await plantSession(live);
      addTearDown(() => dir.delete(recursive: true));
      final bridge = _CompletionBridge();
      var refreshes = 0;
      final queue = EnhanceQueueNotifier(
        bridge,
        () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        onSessionChanged: () => refreshes++,
      );

      expect(await queue.considerSession(handoffFor(dir, live)), isTrue);
      await queue.idle;

      expect(
        refreshes,
        1,
        reason: 'the index must be told exactly once per rewritten session',
      );
    });

    test(
      'a complete transcript queues nothing and is marked finished',
      () async {
        final live = [seg(timestamp: 1, text: 'Selamat pagi semuanya.')];
        final dir = await plantSession(live);
        addTearDown(() => dir.delete(recursive: true));
        final bridge = _CompletionBridge(gaps: const []);
        final queue = EnhanceQueueNotifier(
          bridge,
          () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        );

        expect(await queue.considerSession(handoffFor(dir, live)), isFalse);
        expect(queue.state.hasPendingWork, isFalse);
        final meta = await readSessionMeta(dir.path);
        expect(meta.isIncomplete, isFalse);
        expect(meta.coverageFraction, 1.0);
      },
    );

    test(
      'a finished silent track does not mark the session complete',
      () async {
        // The observed overclaim: a mic track that was pure silence finished
        // first and wrote coverage 100% while the speaker track was still
        // missing five minutes.
        final live = [seg(timestamp: 1, text: 'halo')];
        final dir = await plantSession(
          live,
          tracks: const ['mic.wav', 'speaker.wav'],
        );
        addTearDown(() => dir.delete(recursive: true));
        final queue = EnhanceQueueNotifier(
          _OneTrackOnlyBridge(),
          () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        );
        await queue.considerSession(handoffFor(dir, live));
        // Let the mic job finish; the speaker job is still queued.
        await queue.idle;
        final meta = await readSessionMeta(dir.path);
        expect(meta.pendingCompletion, isEmpty);
        expect(
          meta.coverageFraction,
          lessThan(1.0),
          reason: 'the least-complete track decides',
        );
      },
    );

    test('one job per captured track', () async {
      final live = [seg(timestamp: 1, text: 'halo')];
      final dir = await plantSession(
        live,
        tracks: const ['mic.wav', 'speaker.wav'],
      );
      addTearDown(() => dir.delete(recursive: true));
      final bridge = _CompletionBridge();
      final queue = EnhanceQueueNotifier(
        bridge,
        () => AppSettings.defaults().copyWith(libraryPath: dir.path),
      );
      await queue.considerSession(handoffFor(dir, live));
      expect(queue.state.completionJobsFor(dir.path), hasLength(2));
      await queue.idle;
      expect(bridge.completionRuns, hasLength(2));
    });

    test('runs with the model the session was recorded with', () async {
      // Not the "accurate" model by default: the completion pass exists to
      // recover missing text, and recovering it with a different model than
      // the rest of the transcript would make the seam visible.
      final live = [seg(timestamp: 1, text: 'halo')];
      final dir = await plantSession(live);
      addTearDown(() => dir.delete(recursive: true));
      final bridge = _CompletionBridge();
      final queue = EnhanceQueueNotifier(
        bridge,
        () => AppSettings.defaults().copyWith(libraryPath: dir.path),
      );
      await queue.considerSession(handoffFor(dir, live, modelId: 'base'));
      await queue.idle;
      expect(bridge.lastModelPath, contains('base'));
    });

    test('only this source\'s segments are handed to the pass', () async {
      final live = [
        seg(timestamp: 1, text: 'dari speaker', source: 'spk'),
        seg(timestamp: 2, text: 'dari mikrofon', source: 'mic'),
      ];
      final dir = await plantSession(live);
      addTearDown(() => dir.delete(recursive: true));
      final bridge = _CompletionBridge();
      final queue = EnhanceQueueNotifier(
        bridge,
        () => AppSettings.defaults().copyWith(libraryPath: dir.path),
      );
      await queue.considerSession(handoffFor(dir, live));
      await queue.idle;
      expect(bridge.lastExisting.map((s) => s.text), ['dari speaker']);
    });
  });

  group('the completed transcript', () {
    test('gains the recovered text and keeps the other source', () async {
      final live = [
        seg(timestamp: 1, text: 'Selamat pagi semuanya.', source: 'spk'),
        seg(timestamp: 2, text: 'Catatan saya.', source: 'mic'),
      ];
      final dir = await plantSession(live);
      addTearDown(() => dir.delete(recursive: true));
      final bridge = _CompletionBridge(
        recovered: [rustSeg(timestamp: 152, text: 'Selamat pagi semuanya.')],
      );
      final queue = EnhanceQueueNotifier(
        bridge,
        () => AppSettings.defaults().copyWith(libraryPath: dir.path),
      );
      await queue.considerSession(handoffFor(dir, live));
      await queue.idle;

      final written = parseTranscriptJson(
        await File(p.join(dir.path, 'Sesi.json')).readAsString(),
      );
      // The repeated sentence two minutes later is the thing that used to
      // be lost; the mic line must survive untouched alongside it.
      expect(written.map((s) => s.timestamp), [1.0, 2.0, 152.0]);
      expect(
        written.where((s) => s.source == 'mic').single.text,
        'Catatan saya.',
      );
      final meta = await readSessionMeta(dir.path);
      expect(
        meta.isIncomplete,
        isFalse,
        reason: 'the sidecar must stop claiming the track is pending',
      );
      expect(meta.coverageFraction, 1.0);
    });

    test(
      'the previous transcript is backed up before it is replaced',
      () async {
        final live = [seg(timestamp: 1, text: 'asli')];
        final dir = await plantSession(live);
        addTearDown(() => dir.delete(recursive: true));
        final bridge = _CompletionBridge(
          recovered: [rustSeg(timestamp: 152, text: 'baru')],
        );
        final queue = EnhanceQueueNotifier(
          bridge,
          () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        );
        await queue.considerSession(handoffFor(dir, live));
        await queue.idle;
        final backup = await readTranscriptBackup(dir.path);
        expect(backup?.single.text, 'asli');
      },
    );

    test(
      'a failed pass leaves the transcript and the pending mark alone',
      () async {
        final live = [seg(timestamp: 1, text: 'asli')];
        final dir = await plantSession(live);
        addTearDown(() => dir.delete(recursive: true));
        final queue = EnhanceQueueNotifier(
          _FailingCompletionBridge(),
          () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        );
        await queue.considerSession(handoffFor(dir, live));
        await queue.idle;

        final written = parseTranscriptJson(
          await File(p.join(dir.path, 'Sesi.json')).readAsString(),
        );
        expect(written.single.text, 'asli');
        // Still pending, so the next launch tries again rather than calling
        // a session finished that is not.
        final meta = await readSessionMeta(dir.path);
        expect(meta.isIncomplete, isTrue);
        expect(queue.state.jobs.single.status, EnhanceJobStatus.failed);
      },
    );
  });

  group('resumePending', () {
    test('re-queues what the sidecar says is outstanding', () async {
      final dir = await plantSession([seg(timestamp: 1, text: 'halo')]);
      addTearDown(() => dir.delete(recursive: true));
      final track = p.join(dir.path, 'speaker.wav');
      await writeSessionMeta(
        dir.path,
        SessionMeta(pendingCompletion: [track], model: 'base', language: 'id'),
      );
      final bridge = _CompletionBridge();
      final queue = EnhanceQueueNotifier(
        bridge,
        () => AppSettings.defaults().copyWith(libraryPath: dir.path),
      );

      final resumed = await queue.resumePending([
        (dirPath: dir.path, title: 'Sesi'),
      ]);
      expect(resumed, 1);
      await queue.idle;
      expect(bridge.completionRuns.single, track);
    });

    test('skips a track whose audio the user deleted', () async {
      final dir = await plantSession(const [], tracks: const []);
      addTearDown(() => dir.delete(recursive: true));
      await writeSessionMeta(
        dir.path,
        SessionMeta(pendingCompletion: [p.join(dir.path, 'speaker.wav')]),
      );
      final queue = EnhanceQueueNotifier(
        _CompletionBridge(),
        () => AppSettings.defaults().copyWith(libraryPath: dir.path),
      );
      expect(
        await queue.resumePending([(dirPath: dir.path, title: 'Sesi')]),
        0,
      );
    });

    test('resuming twice does not queue the same track twice', () async {
      final dir = await plantSession([seg(timestamp: 1, text: 'halo')]);
      addTearDown(() => dir.delete(recursive: true));
      await writeSessionMeta(
        dir.path,
        SessionMeta(pendingCompletion: [p.join(dir.path, 'speaker.wav')]),
      );
      final queue = EnhanceQueueNotifier(
        _SlowCompletionBridge(),
        () => AppSettings.defaults().copyWith(libraryPath: dir.path),
      );
      await queue.resumePending([(dirPath: dir.path, title: 'Sesi')]);
      expect(
        await queue.resumePending([(dirPath: dir.path, title: 'Sesi')]),
        0,
      );
      queue.cancelAll();
      await queue.idle;
    });
  });

  group('queue ordering', () {
    test('completion outranks enhancement', () {
      // Missing text is a defect; better text is an improvement.
      const state = EnhanceQueueState(
        jobs: [
          EnhanceJob(
            directoryPath: '/a',
            title: 'a',
            audioPath: '/a/mic.wav',
            language: 'id',
          ),
          EnhanceJob(
            directoryPath: '/b',
            title: 'b',
            audioPath: '/b/speaker.wav',
            language: 'id',
            kind: EnhanceJobKind.complete,
          ),
        ],
      );
      expect(state.pending.first.kind, EnhanceJobKind.complete);
    });

    test('hasPendingWork is what the quit dialog keys off', () {
      const idle = EnhanceQueueState(
        jobs: [
          EnhanceJob(
            directoryPath: '/a',
            title: 'a',
            audioPath: '/a/mic.wav',
            language: 'id',
            status: EnhanceJobStatus.done,
          ),
        ],
      );
      expect(idle.hasPendingWork, isFalse);
      const busy = EnhanceQueueState(
        jobs: [
          EnhanceJob(
            directoryPath: '/a',
            title: 'a',
            audioPath: '/a/mic.wav',
            language: 'id',
            status: EnhanceJobStatus.running,
          ),
        ],
      );
      expect(busy.hasPendingWork, isTrue);
    });
  });
}

/// Mic completes fully (it was silence); the speaker track recovers only
/// half of its speech.
class _OneTrackOnlyBridge extends _CompletionBridge {
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
  }) async {
    completionRuns.add(audioPath);
    final silent = audioPath.endsWith('mic.wav');
    return rust_completion.CompletionOutcome(
      segments: existing.map(toRustSegment).toList(),
      added: 0,
      rejected: 0,
      coverage: kCompleteCoverage,
      speechSecs: silent ? 0 : 200,
      speechCoveredSecs: silent ? 0 : 100,
      audioSecs: 360,
    );
  }
}

class _FailingCompletionBridge extends _CompletionBridge {
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
  }) async => throw StateError('model tidak bisa dimuat');
}

/// Never finishes on its own, so a test can observe the running state.
class _SlowCompletionBridge extends _CompletionBridge {
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
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return super.completeSessionTranscript(
      modelPath: modelPath,
      audioPath: audioPath,
      jobKey: jobKey,
      existing: existing,
      language: language,
      gpuEnabled: gpuEnabled,
      gpuDevice: gpuDevice,
      glossary: glossary,
      vadEnabled: vadEnabled,
    );
  }
}
