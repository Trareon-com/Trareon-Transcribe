import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Privacy proof at the Dart layer — mirrors rust_core/src/privacy.rs.
///
/// Guarantees:
/// 1. No HTTP client usage anywhere in the transcribe/UI hot path.
/// 2. `downloadModel` (a network-capable bridge method) is only reachable
///    from the explicit model-download flow, never from session capture or
///    transcription code.
/// 3. `recordModelDownload` (privacy counter) has exactly one definition
///    and zero call sites while models are bundled — so the counter stays
///    0 unless a user-initiated download is wired up.
/// 4. The AI summary — the only other networked feature — cannot be reached
///    from the transcription path, and every request it does make is counted
///    in the Privacy Report.
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
            h.startsWith('src/rust/'), // generated FRB bindings — allowed
        isTrue,
        reason: 'unexpected downloadModel call site: $h',
      );
    }
  });

  test('recordModelDownload counter has zero call sites while bundled', () {
    final lib = Directory('lib');
    final hits = <String>[];
    lib.listSync(recursive: true).whereType<File>().forEach((f) {
      if (!f.path.endsWith('.dart')) return;
      final lines = f.readAsStringSync().split('\n');
      for (final line in lines) {
        // Doc comments referencing the method are not call sites.
        if (line.trimLeft().startsWith('//')) continue;
        if (line.contains('recordModelDownload')) {
          hits.add(
            f.path
                .replaceAll('${lib.path}/', '')
                .replaceAll('${lib.path}\\', '')
                .replaceAll('\\', '/'),
          );
        }
      }
    });

    expect(
      hits,
      ['state/privacy_report_model.dart'],
      reason: 'counter must only be defined, never incremented while bundled',
    );
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
    final requestIndex = generateBody.indexOf('_bridge.generateSummary(');

    expect(notifyIndex, greaterThan(-1), reason: 'generate() must notify the counter');
    expect(requestIndex, greaterThan(-1));
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
