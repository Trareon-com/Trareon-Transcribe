import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/summary_model.dart';

import 'test_helpers.dart';

const _segment = TranscriptSegment(
  source: 'mic',
  speaker: 'Saya',
  text: 'kita putuskan pakai Rust',
  timestamp: 0,
  duration: 2,
  language: 'id',
  confidence: 0.9,
  isPartial: false,
);

/// Bridge that records what it was asked for and returns a canned summary.
class _SummaryBridge extends NoopBridge {
  _SummaryBridge({this.failWith});

  final Object? failWith;
  SummaryConfig? lastConfig;
  List<TranscriptSegment>? lastSegments;
  int calls = 0;

  @override
  Future<String> generateSummary({
    required List<TranscriptSegment> segments,
    required SummaryConfig config,
  }) async {
    calls++;
    lastConfig = config;
    lastSegments = segments;
    if (failWith != null) throw failWith!;
    return '## Keputusan\n- Pakai Rust';
  }
}

AppSettings settingsWithSummary({
  bool enabled = true,
  String model = 'qwen2.5:7b',
  String baseUrl = 'http://localhost:11434',
  String? language = 'id',
}) {
  return AppSettings.defaults().copyWith(
    language: language,
    summary: kDefaultSummarySettings.copyWith(
      enabled: enabled,
      model: model,
      baseUrl: baseUrl,
    ),
  );
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('trareon_summary_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('starts from the saved summary in the sidecar', () {
    final notifier = SummaryNotifier(
      NoopBridge(),
      dir.path,
      initialMeta: const SessionMeta(
        summary: '## Ringkasan\nHalo',
        summaryTemplate: SummaryTemplate.standup,
      ),
    );
    addTearDown(notifier.dispose);

    expect(notifier.state.status, SummaryStatus.ready);
    expect(notifier.state.text, '## Ringkasan\nHalo');
    expect(notifier.state.template, SummaryTemplate.standup);
    expect(notifier.state.dirty, isFalse);
  });

  test('generates, then persists to the sidecar', () async {
    final bridge = _SummaryBridge();
    final notifier = SummaryNotifier(bridge, dir.path);
    addTearDown(notifier.dispose);

    notifier.setTemplate(SummaryTemplate.actionItems);
    await notifier.generate(
      segments: const [_segment],
      settings: settingsWithSummary(),
    );

    expect(notifier.state.status, SummaryStatus.ready);
    expect(notifier.state.text, contains('Pakai Rust'));
    expect(notifier.state.dirty, isFalse, reason: 'generate() saves');

    final saved = await readSessionMeta(dir.path);
    expect(saved.summary, contains('Pakai Rust'));
    expect(saved.summaryTemplate, SummaryTemplate.actionItems);
    expect(saved.summaryGeneratedAt, isNotNull);
  });

  test('sends the selected template and UI language to the endpoint', () async {
    final bridge = _SummaryBridge();
    final notifier = SummaryNotifier(bridge, dir.path);
    addTearDown(notifier.dispose);

    notifier.setTemplate(SummaryTemplate.ringkasanEksekutif);
    await notifier.generate(
      segments: const [_segment],
      settings: settingsWithSummary(language: 'en'),
    );

    expect(bridge.lastConfig!.template, SummaryTemplate.ringkasanEksekutif);
    expect(bridge.lastConfig!.language, 'en');
    expect(bridge.lastConfig!.model, 'qwen2.5:7b');
    expect(bridge.lastSegments, hasLength(1));
  });

  test('never calls out while the feature is disabled', () async {
    final bridge = _SummaryBridge();
    final notifier = SummaryNotifier(bridge, dir.path);
    addTearDown(notifier.dispose);

    await notifier.generate(
      segments: const [_segment],
      settings: settingsWithSummary(enabled: false),
    );

    expect(bridge.calls, 0, reason: 'opt-in means no request at all');
    expect(notifier.state.status, SummaryStatus.failed);
    expect(notifier.state.error, contains('Pengaturan'));
  });

  test('never calls out when the endpoint is not configured', () async {
    final bridge = _SummaryBridge();
    final notifier = SummaryNotifier(bridge, dir.path);
    addTearDown(notifier.dispose);

    await notifier.generate(
      segments: const [_segment],
      settings: settingsWithSummary(model: ''),
    );
    expect(bridge.calls, 0);
    expect(notifier.state.status, SummaryStatus.failed);

    await notifier.generate(
      segments: const [_segment],
      settings: settingsWithSummary(baseUrl: '   '),
    );
    expect(bridge.calls, 0);
  });

  test('refuses an empty transcript instead of sending nothing', () async {
    final bridge = _SummaryBridge();
    final notifier = SummaryNotifier(bridge, dir.path);
    addTearDown(notifier.dispose);

    await notifier.generate(segments: const [], settings: settingsWithSummary());

    expect(bridge.calls, 0);
    expect(notifier.state.error, contains('kosong'));
  });

  test('a failed request reassures the user the transcript is safe', () async {
    final bridge = _SummaryBridge(failWith: StateError('connection refused'));
    final notifier = SummaryNotifier(bridge, dir.path);
    addTearDown(notifier.dispose);

    await notifier.generate(
      segments: const [_segment],
      settings: settingsWithSummary(),
    );

    expect(notifier.state.status, SummaryStatus.failed);
    expect(notifier.state.error, contains('transkrip tetap aman'));
    expect(notifier.state.error, contains('connection refused'));
    // Nothing must have been written over the session's sidecar.
    expect((await readSessionMeta(dir.path)).hasSummary, isFalse);
  });

  test('manual edits mark the summary dirty until saved', () async {
    final notifier = SummaryNotifier(NoopBridge(), dir.path);
    addTearDown(notifier.dispose);

    notifier.edit('ringkasan tulisan tangan');
    expect(notifier.state.dirty, isTrue);
    expect(notifier.state.status, SummaryStatus.ready);

    await notifier.save();
    expect(notifier.state.dirty, isFalse);
    expect((await readSessionMeta(dir.path)).summary, 'ringkasan tulisan tangan');
  });

  test('clearing the text returns the panel to empty', () {
    final notifier = SummaryNotifier(
      NoopBridge(),
      dir.path,
      initialMeta: const SessionMeta(summary: 'x'),
    );
    addTearDown(notifier.dispose);

    notifier.edit('   ');
    expect(notifier.state.status, SummaryStatus.empty);
  });

  group('SummarySettings', () {
    test('is not usable until enabled, addressed and given a model', () {
      expect(kDefaultSummarySettings.isUsable, isFalse);
      expect(kDefaultSummarySettings.copyWith(enabled: true).isUsable, isFalse);
      expect(
        kDefaultSummarySettings.copyWith(enabled: true, model: 'm').isUsable,
        isTrue,
      );
      expect(
        kDefaultSummarySettings
            .copyWith(enabled: true, model: 'm', baseUrl: '  ')
            .isUsable,
        isFalse,
      );
    });

    test('the shipped default is off and points at loopback', () {
      expect(kDefaultSummarySettings.enabled, isFalse);
      expect(kDefaultSummarySettings.apiKey, isEmpty);
      expect(kDefaultSummarySettings.baseUrl, contains('localhost'));
      expect(AppSettings.defaults().summary.enabled, isFalse);
    });

    test('copyWith touches only the named field', () {
      final next = kDefaultSummarySettings.copyWith(apiKey: 'sk-test');
      expect(next.apiKey, 'sk-test');
      expect(next.baseUrl, kDefaultSummarySettings.baseUrl);
      expect(next.enabled, kDefaultSummarySettings.enabled);
      expect(next.template, kDefaultSummarySettings.template);
    });

    test('every template has a distinct Indonesian label and hint', () {
      final labels = SummaryTemplate.values.map(summaryTemplateLabel).toSet();
      expect(labels, hasLength(SummaryTemplate.values.length));
      for (final t in SummaryTemplate.values) {
        expect(summaryTemplateLabel(t), isNotEmpty);
        expect(summaryTemplateHint(t), isNotEmpty);
      }
    });
  });
}
