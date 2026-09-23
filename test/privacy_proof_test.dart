import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Privacy proof at the Dart layer — mirrors rust_core/src/privacy.rs.
///
/// Guarantees:
/// 1. No HTTP client usage anywhere in the transcribe/UI hot path.
/// 2. `downloadModel` (the only network-capable bridge method) is only
///    reachable from the explicit model-download flow, never from session
///    capture or transcription code.
/// 3. `recordModelDownload` (privacy counter) has exactly one definition
///    and zero call sites while models are bundled — so the counter stays
///    0 unless a user-initiated download is wired up.
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
}
