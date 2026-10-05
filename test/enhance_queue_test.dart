import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/src/rust/glossary.dart' as rust_glossary;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/state/enhance_queue_model.dart';
import 'package:transcribe/state/models.dart';

import 'test_helpers.dart';

TranscriptSegment segment({
  required double timestamp,
  required String text,
  String speaker = 'MIC',
  double duration = 2,
}) => TranscriptSegment(
  source: 'mic',
  speaker: speaker,
  text: text,
  timestamp: timestamp,
  duration: duration,
  language: 'id',
  confidence: 0.9,
  isPartial: false,
);

rust_export.Segment rustSegment({
  required double timestamp,
  required String text,
  String speaker = 'MIC',
  double duration = 2,
}) => rust_export.Segment(
  source: 'mic',
  speaker: speaker,
  text: text,
  timestamp: timestamp,
  duration: duration,
  language: 'id',
  confidence: 0.9,
  avgLogProb: -0.3,
  isPartial: false,
  lowConfidence: false,
  words: const [],
);

/// A bridge whose accurate pass returns a fixed transcript.
class _EnhanceBridge extends NoopBridge {
  _EnhanceBridge(this.result, {this.error});

  final List<rust_export.Segment> result;
  final String? error;
  int calls = 0;
  rust_glossary.GlossaryConfig? lastGlossary;

  @override
  Future<List<rust_stt_file.BatchFileOutcome>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
    bool gpuEnabled = false,
    int gpuDevice = 0,
    rust_glossary.GlossaryConfig glossary = kEmptyGlossary,
    int speakerHint = 0,
  }) async {
    calls++;
    lastGlossary = glossary;
    return [
      rust_stt_file.BatchFileOutcome(
        filename: files.first.split(Platform.pathSeparator).last,
        path: files.first,
        error: error,
        result: error != null
            ? null
            : rust_stt_file.TranscribeFileResult(
                filename: 'mic.wav',
                durationSecs: 10,
                segments: result,
                language: language ?? 'id',
              ),
      ),
    ];
  }
}

/// Plants a stub accurate-model file inside [dirPath], which every queue test
/// also passes as `libraryPath`.
///
/// [EnhanceQueueNotifier.considerSession] refuses to queue anything unless the
/// accurate model is installed, and the real file is a 574 MB download that
/// only ever exists in a developer's model cache. Depending on it made these
/// tests pass on a machine that had done the download and fail everywhere else
/// — including CI, where nothing was queued, so the queue assertions had no
/// job to look at. The engine is a fake here, so nothing reads the bytes:
/// `isModelAvailable()` only checks that the file exists.
///
/// The name comes from [modelPathForId] rather than a literal so it cannot
/// drift away from the mapping the production gate uses.
Future<void> installAccurateModelStub(String dirPath) async {
  final fileName = p.basename(
    modelPathForId(kAccurateModelId, libraryPath: dirPath),
  );
  await File(p.join(dirPath, fileName)).writeAsBytes(const [0]);
}

/// "Perhalus transkrip" (F5).
void main() {
  group('shouldAutoEnhance', () {
    bool decide({
      bool usedQuickModel = true,
      bool accurateModelInstalled = true,
      bool hasAudio = true,
      bool alreadyDone = false,
      bool liveModelWasAccurate = false,
      bool? preference,
    }) => shouldAutoEnhance(
      usedQuickModel: usedQuickModel,
      accurateModelInstalled: accurateModelInstalled,
      hasAudio: hasAudio,
      alreadyDone: alreadyDone,
      liveModelWasAccurate: liveModelWasAccurate,
      preference: preference,
    );

    test('on by default when the live pass used the quick model', () {
      expect(decide(), isTrue);
    });

    test('off when the live pass already used the accurate model', () {
      // Re-running the same model over the same audio costs minutes of CPU
      // and changes nothing.
      expect(decide(liveModelWasAccurate: true), isFalse);
    });

    test('off when the user said no, whatever else is true', () {
      expect(decide(preference: false), isFalse);
      expect(decide(preference: false, usedQuickModel: true), isFalse);
    });

    test('a forced yes still needs the model, the audio, and a first run', () {
      expect(decide(preference: true, usedQuickModel: false), isTrue);
      expect(decide(preference: true, accurateModelInstalled: false), isFalse);
      expect(decide(preference: true, hasAudio: false), isFalse);
      expect(decide(preference: true, alreadyDone: false), isTrue);
      expect(decide(preference: true, alreadyDone: true), isFalse);
    });

    test('never runs twice for the same session', () {
      expect(decide(alreadyDone: true), isFalse);
    });
  });

  group('mergeEnhanced', () {
    test('the accurate text wins', () {
      final merged = mergeEnhanced(
        previous: [segment(timestamp: 0, text: 'anggaran kemenku')],
        enhanced: [segment(timestamp: 0, text: 'anggaran Kemenkeu')],
      );
      expect(merged.single.text, 'anggaran Kemenkeu');
    });

    test('a hand-renamed speaker survives a slight timestamp shift', () {
      // The accurate pass segments the audio differently, so exact timestamp
      // equality would preserve nothing.
      final merged = mergeEnhanced(
        previous: [segment(timestamp: 10.0, text: 'lama', speaker: 'Pak Budi')],
        enhanced: [segment(timestamp: 10.4, text: 'baru', speaker: 'MIC')],
      );
      expect(merged.single.speaker, 'Pak Budi');
      expect(merged.single.text, 'baru');
    });

    test('an engine label never overrides the accurate pass labelling', () {
      final merged = mergeEnhanced(
        previous: [segment(timestamp: 0, text: 'lama', speaker: 'MIC')],
        enhanced: [segment(timestamp: 0, text: 'baru', speaker: 'Pembicara 1')],
      );
      expect(merged.single.speaker, 'Pembicara 1');
    });

    test('a rename too far away is not applied', () {
      final merged = mergeEnhanced(
        previous: [segment(timestamp: 0, text: 'lama', speaker: 'Pak Budi')],
        enhanced: [segment(timestamp: 120, text: 'baru', speaker: 'MIC')],
      );
      expect(merged.single.speaker, 'MIC');
    });

    test('an empty accurate pass keeps the previous transcript untouched', () {
      final previous = [segment(timestamp: 0, text: 'hasil manual')];
      expect(mergeEnhanced(previous: previous, enhanced: const []), previous);
    });

    test('segments the previous transcript never had are kept as-is', () {
      final merged = mergeEnhanced(
        previous: [segment(timestamp: 0, text: 'satu')],
        enhanced: [
          segment(timestamp: 0, text: 'satu akurat'),
          segment(timestamp: 30, text: 'dua akurat'),
        ],
      );
      expect(merged.length, 2);
      expect(merged.last.text, 'dua akurat');
    });
  });

  group('retainAlignedBookmarks', () {
    test('keeps markers inside the new transcript span', () {
      final kept = retainAlignedBookmarks(
        const [
          Bookmark(timestamp: 5, note: ''),
          Bookmark(timestamp: 50, note: ''),
        ],
        [segment(timestamp: 0, text: 'a'), segment(timestamp: 20, text: 'b')],
      );
      // The span ends at 20 + 2 = 22 s.
      expect(kept.map((b) => b.timestamp), [5]);
    });

    test('drops rather than clamps a marker past the end', () {
      // A marker pointing at the wrong moment is worse than no marker.
      final kept = retainAlignedBookmarks(
        const [Bookmark(timestamp: 9999, note: '')],
        [segment(timestamp: 0, text: 'a')],
      );
      expect(kept, isEmpty);
    });

    test('an empty transcript leaves the markers alone', () {
      const bookmarks = [Bookmark(timestamp: 5, note: '')];
      expect(retainAlignedBookmarks(bookmarks, const []), bookmarks);
    });
  });

  group('EnhanceQueueNotifier', () {
    Future<Directory> sessionWithAudio() async {
      final dir = await Directory.systemTemp.createTemp('trareon-enhance-');
      await installAccurateModelStub(dir.path);
      await File(
        '${dir.path}${Platform.pathSeparator}mic.wav',
      ).writeAsBytes(const [0, 1, 2, 3]);
      await File(
        '${dir.path}${Platform.pathSeparator}Rapat.json',
      ).writeAsString(
        encodeTranscriptJson([segment(timestamp: 0, text: 'hasil cepat')]),
      );
      return dir;
    }

    SavedSessionHandoff handoff(String dirPath) => SavedSessionHandoff(
      directoryPath: dirPath,
      title: 'Rapat',
      modelId: 'base',
      language: 'id',
      usedQuickModel: true,
      autoRetranscribePreference: true,
      segments: [segment(timestamp: 0, text: 'hasil cepat')],
    );

    test(
      'replaces the transcript, backs it up, and records that it is done',
      () async {
        final dir = await sessionWithAudio();
        try {
          final bridge = _EnhanceBridge([
            rustSegment(timestamp: 0, text: 'hasil akurat'),
          ]);
          final queue = EnhanceQueueNotifier(
            bridge,
            () => AppSettings.defaults().copyWith(libraryPath: dir.path),
          );

          await queue.considerSession(handoff(dir.path));
          await queue.idle;

          expect(bridge.calls, 1);
          final transcript = await File(
            '${dir.path}${Platform.pathSeparator}Rapat.json',
          ).readAsString();
          expect(transcript, contains('hasil akurat'));

          final backup = transcriptBackupIn(dir.path);
          expect(backup, isNotNull, reason: 'the old transcript must survive');
          expect(await backup!.readAsString(), contains('hasil cepat'));

          final meta = await readSessionMeta(dir.path);
          expect(meta.autoRetranscribeDone, isTrue);
          expect(meta.model, kAccurateModelId);
        } finally {
          await dir.delete(recursive: true);
        }
      },
    );

    test('a failed pass leaves the transcript exactly as it was', () async {
      final dir = await sessionWithAudio();
      try {
        final bridge = _EnhanceBridge(const [], error: 'model gagal dimuat');
        final queue = EnhanceQueueNotifier(
          bridge,
          () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        );
        await queue.considerSession(handoff(dir.path));
        await queue.idle;

        final transcript = await File(
          '${dir.path}${Platform.pathSeparator}Rapat.json',
        ).readAsString();
        expect(transcript, contains('hasil cepat'));
        expect(queue.state.jobs.single.status, EnhanceJobStatus.failed);
        expect(queue.state.jobs.single.error, contains('model gagal dimuat'));
        expect((await readSessionMeta(dir.path)).autoRetranscribeDone, isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test(
      'the pass carries the glossary so jargon survives the upgrade',
      () async {
        final dir = await sessionWithAudio();
        try {
          final bridge = _EnhanceBridge([
            rustSegment(timestamp: 0, text: 'PPBJ'),
          ]);
          final queue = EnhanceQueueNotifier(
            bridge,
            () => AppSettings.defaults().copyWith(
              libraryPath: dir.path,
              glossary: const GlossarySettings(
                enabled: true,
                terms: ['PPBJ'],
                postCorrection: true,
                replacements: [],
              ),
            ),
          );
          await queue.considerSession(handoff(dir.path));
          await queue.idle;
          expect(bridge.lastGlossary?.globalTerms, ['PPBJ']);
        } finally {
          await dir.delete(recursive: true);
        }
      },
    );

    test('a live recording pauses the queue', () async {
      final dir = await sessionWithAudio();
      try {
        final bridge = _EnhanceBridge([
          rustSegment(timestamp: 0, text: 'hasil akurat'),
        ]);
        final queue = EnhanceQueueNotifier(
          bridge,
          () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        );
        queue.setPaused(true);
        await queue.considerSession(handoff(dir.path));
        await queue.idle;
        expect(bridge.calls, 0, reason: 'Whisper cannot usefully run twice');
        expect(queue.state.pending.length, 1);

        queue.setPaused(false);
        await queue.idle;
        expect(bridge.calls, 1);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('a session with no audio is never queued', () async {
      final dir = await Directory.systemTemp.createTemp('trareon-enhance-');
      // The model is installed and only the audio is missing, so a refusal
      // here can only be the audio gate.
      await installAccurateModelStub(dir.path);
      try {
        final bridge = _EnhanceBridge(const []);
        final queue = EnhanceQueueNotifier(
          bridge,
          () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        );
        expect(await queue.considerSession(handoff(dir.path)), isFalse);
        expect(queue.state.jobs, isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('an already-enhanced session is not queued again', () async {
      final dir = await sessionWithAudio();
      try {
        await writeSessionMeta(
          dir.path,
          const SessionMeta(title: 'Rapat', autoRetranscribeDone: true),
        );
        final bridge = _EnhanceBridge(const []);
        final queue = EnhanceQueueNotifier(
          bridge,
          () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        );
        expect(await queue.considerSession(handoff(dir.path)), isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('cancelling a queued job keeps it out of the engine', () async {
      final dir = await sessionWithAudio();
      try {
        final bridge = _EnhanceBridge(const []);
        final queue = EnhanceQueueNotifier(
          bridge,
          () => AppSettings.defaults().copyWith(libraryPath: dir.path),
        );
        queue.setPaused(true);
        await queue.considerSession(handoff(dir.path));
        queue.cancel(dir.path);
        queue.setPaused(false);
        await queue.idle;
        expect(bridge.calls, 0);
        expect(queue.state.jobs.single.status, EnhanceJobStatus.cancelled);
        expect(queue.state.visible, isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
