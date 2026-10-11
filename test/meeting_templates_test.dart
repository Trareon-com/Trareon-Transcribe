/// Sprint 15 F24: meeting setup templates (peserta + agenda + bahasa +
/// mode saved for reuse), distinct from `notulen_templates.dart`'s
/// document-format templates.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/services/dart_prefs.dart';
import 'package:transcribe/state/meeting_templates.dart';
import 'package:transcribe/state/models.dart' show SessionMode;

void main() {
  setUp(() async {
    // Same reasoning as speakers_test.dart: DartPrefs has no real path in
    // a unit test, so load() swallows that and starts empty.
    await DartPrefs.instance.load();
    DartPrefs.instance.remove('meeting_templates');
  });

  test('a saved template round-trips through JSON unchanged', () async {
    final store = const MeetingTemplateStore();
    const template = MeetingTemplate(
      id: 't1',
      name: 'Rapat Mingguan Tim',
      participants: ['Budi', 'Sari'],
      agenda: ['Progres sprint', 'Risiko'],
      language: 'id',
      mode: SessionMode.online,
    );

    await store.saveAll([template]);
    final reloaded = await store.load();

    expect(reloaded, hasLength(1));
    expect(reloaded.single.name, 'Rapat Mingguan Tim');
    expect(reloaded.single.participants, ['Budi', 'Sari']);
    expect(reloaded.single.agenda, ['Progres sprint', 'Risiko']);
    expect(reloaded.single.language, 'id');
    expect(reloaded.single.mode, SessionMode.online);
  });

  test('a template with no language saved means "Otomatis"', () async {
    final store = const MeetingTemplateStore();
    await store.saveAll([
      const MeetingTemplate(id: 't1', name: 'Webinar Publik'),
    ]);

    final reloaded = await store.load();
    expect(reloaded.single.language, isNull);
  });

  test('a malformed entry does not take the whole list down', () async {
    final store = const MeetingTemplateStore();
    DartPrefs.instance.setString(
      'meeting_templates',
      '[{"id": "t1", "name": "Sah"}, {"name": "tanpa id"}, "bukan objek"]',
    );
    final reloaded = await store.load();
    expect(reloaded, hasLength(1));
    expect(reloaded.single.name, 'Sah');
  });

  test('corrupt JSON degrades to an empty list, not a crash', () async {
    final store = const MeetingTemplateStore();
    DartPrefs.instance.setString('meeting_templates', 'bukan json');
    expect(await store.load(), isEmpty);
  });

  group('notifier', () {
    test('upsert adds a new template and replaces one with the same id', () {
      final notifier = MeetingTemplateNotifier();
      notifier.upsert(
        const MeetingTemplate(id: 't1', name: 'Rapat A', mode: SessionMode.offline),
      );
      expect(notifier.state, hasLength(1));

      notifier.upsert(
        const MeetingTemplate(id: 't1', name: 'Rapat A (diedit)', mode: SessionMode.online),
      );
      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.name, 'Rapat A (diedit)');
      expect(notifier.state.single.mode, SessionMode.online);
    });

    test('remove drops only the matching template', () {
      final notifier = MeetingTemplateNotifier();
      notifier.upsert(const MeetingTemplate(id: 't1', name: 'Rapat A'));
      notifier.upsert(const MeetingTemplate(id: 't2', name: 'Rapat B'));

      notifier.remove('t1');
      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.id, 't2');
    });
  });
}
