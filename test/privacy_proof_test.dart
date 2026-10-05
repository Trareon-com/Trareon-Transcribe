import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Privacy proof at the Dart layer — mirrors rust_core/src/privacy.rs.
///
/// Guarantees:
/// 1. No HTTP client usage anywhere in the transcribe/UI hot path.
/// 2. `downloadModel` (a network-capable bridge method) is only reachable
///    from the explicit model-download flow, never from session capture or
///    transcription code.
/// 3. **Every network call site records itself in the Privacy Report,
///    before the request leaves.** This replaces an older invariant that
///    asserted `recordModelDownload` had *zero* call sites — which pinned
///    the counter at 0 and, worse, was satisfied while the updater
///    contacted raw.githubusercontent.com on every "Cek Pembaruan" without
///    recording anything. A counter nobody is allowed to increment is not a
///    privacy guarantee, it is a guaranteed-wrong number.
/// 4. The AI summary — the most sensitive networked feature — cannot be
///    reached from the transcription path.
void main() {
  test('no network primitives in transcribe hot path (Dart)', () {
    final transcribePath = <String>[
      'lib/widgets/transcript_view.dart',
      'lib/screens/transcript_player_screen.dart',
      'lib/state/session_model.dart',
      'lib/state/models.dart',
    ];

    const forbidden = ['package:http', 'HttpClient(', 'WebSocket', 'Socket('];
    // NOTE: 'dart:io' is intentionally NOT forbidden — it is imported for
    // local File/Platform ops (modelPathForId, library scan), which are
    // offline. The true network primitives in dart:io are HttpClient,
    // WebSocket and Socket — those are the ones we scan for.

    for (final f in transcribePath) {
      final file = File(f);
      if (!file.existsSync()) continue;
      final content = file.readAsStringSync();
      for (final pat in forbidden) {
        if (pat == 'dart:io' && f == 'lib/state/session_model.dart') continue;
        expect(
          content.contains(pat),
          isFalse,
          reason: '$f must not contain $pat (privacy invariant)',
        );
      }
    }
  });

  test('downloadModel reachable only from bridge + explicit download UI', () {
    final lib = Directory('lib');
    final hits = <String>[];
    lib.listSync(recursive: true).whereType<File>().forEach((f) {
      if (!f.path.endsWith('.dart')) return;
      final lines = f.readAsStringSync().split('\n');
      for (final line in lines) {
        if (!line.trim().startsWith('//') && line.contains('downloadModel(')) {
          hits.add(
            f.path
                .replaceAll('${lib.path}/', '')
                .replaceAll('${lib.path}\\', '')
                .replaceAll('\\', '/'),
          );
        }
      }
    });

    // Definition (bridge_service) + any legit UI call sites. The wizard
    // download step was REMOVED (models bundled), so the only expected hit
    // is the bridge definition itself.
    expect(hits, contains('services/bridge_service.dart'));
    for (final h in hits) {
      expect(
        h == 'services/bridge_service.dart' ||
            h.startsWith('screens/setup_wizard') ||
            h.startsWith('widgets/model_download_dialog') ||
            h.startsWith(
              'state/onboarding_model',
            ) || // first-launch download flow
            // Sprint 4b: the Silero VAD gate and the two speaker-
            // diarization models. Same contract as every other entry here
            // — a button the user presses, recorded in the Privacy Report
            // before the request leaves (see the `initiators` test below).
            h.startsWith('widgets/engine_assets_section') ||
            h.startsWith('src/rust/'), // generated FRB bindings — allowed
        isTrue,
        reason: 'unexpected downloadModel call site: $h',
      );
    }
  });

  test(
    'the Privacy Report knows about exactly the outbound paths that exist',
    () {
      // Anything in lib/ that can put bytes on the wire. Adding a fifth one
      // means adding a recorder for it and updating the screen copy.
      const initiators = <String, String>{
        'downloadModel(': 'recordModelDownload',
        // `generateSummaryLong` (F15) is the same endpoint and the same
        // recorder: it is `generateSummary` with the transcript cut into
        // windows, not a second destination.
        'generateSummary(': 'recordSummaryRequest',
        'checkForUpdate(': 'recordUpdateCheck',
        'launchUrl(': 'recordExternalLink',
        // F12: the archive answer reuses the summary endpoint, but what
        // it sends is different — passages from several past meetings —
        // so it is recorded as its own kind of outbound call.
        'archiveAsk(': 'recordArchiveQuestion',
      };
      final recorders = File(
        'lib/state/privacy_report_model.dart',
      ).readAsStringSync();
      for (final recorder in initiators.values) {
        expect(
          recorders,
          contains('void $recorder('),
          reason: 'the report must be able to record $recorder',
        );
      }
      // And no recorder exists for an activity that no longer happens.
      final declared = RegExp(
        r'void (record\w+)\(',
      ).allMatches(recorders).map((m) => m.group(1)!).toSet();
      expect(declared, unorderedEquals(initiators.values.toSet()));
    },
  );

  test('every network call site records itself first', () {
    /// Files that *define* a network-capable operation rather than
    /// initiating one on the user's behalf. Each is checked separately
    /// below or is pure plumbing over an already-recorded call.
    const definitionSites = <String>{
      'services/bridge_service.dart', // the RustBridge interface + mock
      'services/update_checker.dart', // checked by its own test below
    };

    /// `initiating call` -> `recorder that must run before the request`.
    const mustPrecede = <String, String>{
      '.downloadModel(': 'recordModelDownload',
      '.generateSummary(': 'onNetworkRequest',
      '.generateSummaryLong(': 'onNetworkRequest',
      'launchUrl(': 'recordExternalLink',
      '.archiveAsk(': '_onNetworkRequest',
    };

    /// `constructor` -> `recorder that must be handed to it`. Ordering is
    /// meaningless here: the recorder *is* the argument, so what matters is
    /// that it appears inside the argument list.
    const mustInject = <String, String>{'UpdateChecker(': 'recordUpdateCheck'};

    /// The argument list starting at the `(` that ends [open], by bracket
    /// depth — string literals in this codebase never contain unbalanced
    /// parentheses inside a call, so a depth counter is enough.
    String argumentList(String source, int openIndex) {
      var depth = 0;
      for (var i = openIndex; i < source.length; i++) {
        if (source[i] == '(') depth++;
        if (source[i] == ')') {
          depth--;
          if (depth == 0) return source.substring(openIndex, i + 1);
        }
      }
      return source.substring(openIndex);
    }

    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final relative = file.path
          .replaceFirst(RegExp(r'^lib[/\\]'), '')
          .replaceAll('\\', '/');
      // Generated FRB bindings mirror whatever api.rs exposes.
      if (relative.startsWith('src/rust/')) continue;
      if (definitionSites.contains(relative)) continue;

      final source = file.readAsStringSync();
      for (final entry in mustPrecede.entries) {
        final callIndex = source.indexOf(entry.key);
        if (callIndex < 0) continue;
        final recordIndex = source.indexOf(entry.value);
        if (recordIndex < 0) {
          offenders.add('$relative calls ${entry.key} without ${entry.value}');
        } else if (recordIndex > callIndex) {
          offenders.add(
            '$relative records ${entry.value} only after ${entry.key}',
          );
        }
      }
      for (final entry in mustInject.entries) {
        final callIndex = source.indexOf(entry.key);
        if (callIndex < 0) continue;
        final args = argumentList(source, callIndex + entry.key.length - 1);
        if (!args.contains(entry.value)) {
          offenders.add(
            '$relative builds ${entry.key} without passing ${entry.value}',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'every outbound request must be counted before it leaves:\n'
          '${offenders.join('\n')}',
    );
  });

  test('UpdateChecker cannot run without notifying the counter', () {
    final source = File('lib/services/update_checker.dart').readAsStringSync();
    // Required, not optional: an omittable callback is one that gets omitted.
    expect(
      source,
      contains('required this.onNetworkRequest'),
      reason: 'the recorder must not be skippable',
    );
    final body = source.substring(
      source.indexOf('Future<UpdateInfo> checkForUpdate()'),
    );
    final notifyIndex = body.indexOf('onNetworkRequest(');
    final requestIndex = body.indexOf('client.getUrl(');
    expect(notifyIndex, greaterThan(-1));
    expect(requestIndex, greaterThan(-1));
    expect(
      notifyIndex,
      lessThan(requestIndex),
      reason: 'the counter must be notified before the socket opens',
    );
  });

  test('the version used for update comparison is not hardcoded stale', () {
    final source = File('lib/services/update_checker.dart').readAsStringSync();
    expect(
      source.contains("currentVersion = '0.1.0'"),
      isFalse,
      reason: 'the updater compared a hardcoded 0.1.0 against pubspec 1.0.0',
    );
    expect(source, contains('this.currentVersion = kAppVersion'));
  });

  test('transcription path cannot reach the summary feature', () {
    // Summaries are the one networked feature. Keeping them out of the
    // capture/transcript path is what makes "network only on demand"
    // checkable rather than a claim in a README.
    const transcribePath = [
      'lib/state/session_model.dart',
      'lib/state/audio_stream_model.dart',
      'lib/state/batch_upload_model.dart',
      'lib/widgets/transcript_view.dart',
      'lib/widgets/file_upload_zone.dart',
    ];
    const forbidden = [
      'summary_model.dart',
      'generateSummary',
      'listSummaryModels',
    ];

    for (final path in transcribePath) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final content = file.readAsStringSync();
      for (final pattern in forbidden) {
        expect(
          content.contains(pattern),
          isFalse,
          reason:
              '$path references the networked summary feature via "$pattern" — '
              'summaries must never run inside the transcription path',
        );
      }
    }
  });

  test('every summary request is recorded in the Privacy Report', () {
    // A user-configurable endpoint means the report must be able to show
    // *where* a transcript went. If generate() can run without notifying the
    // counter, the report silently understates network activity.
    final source = File('lib/state/summary_model.dart').readAsStringSync();
    final generateBody = source.substring(
      source.indexOf('Future<void> generate('),
      source.indexOf('Future<void> save()'),
    );
    final notifyIndex = generateBody.indexOf('onNetworkRequest?.call(');
    // Either spelling counts: the long-meeting path (F15) is the same
    // request to the same endpoint, and pinning this to one method name
    // would make the invariant stop covering the call that actually runs.
    final requestIndex = [
      generateBody.indexOf('_bridge.generateSummary('),
      generateBody.indexOf('_bridge.generateSummaryLong('),
    ].where((i) => i >= 0).fold<int>(-1, (a, b) => a < 0 ? b : (b < a ? b : a));

    expect(
      notifyIndex,
      greaterThan(-1),
      reason: 'generate() must notify the counter',
    );
    expect(
      requestIndex,
      greaterThan(-1),
      reason: 'generate() must actually make the summary request',
    );
    expect(
      notifyIndex,
      lessThan(requestIndex),
      reason: 'the counter must be notified before the request leaves',
    );
  });

  test('the shipped summary configuration is disabled and loopback-only', () {
    final source = File('lib/state/models.dart').readAsStringSync();
    final defaults = source.substring(
      source.indexOf('const SummarySettings kDefaultSummarySettings'),
      source.indexOf('/// Indonesian label for each built-in summary template'),
    );
    expect(defaults, contains('enabled: false'));
    expect(defaults, contains("apiKey: ''"));
    expect(
      defaults.contains('localhost') || defaults.contains('127.0.0.1'),
      isTrue,
      reason: 'the default endpoint must not reach the public internet',
    );
  });
}
