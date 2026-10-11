/// Meeting setup templates (F24): peserta + agenda + bahasa + mode,
/// saved once and reused, distinct from `notulen_templates.dart`'s
/// *document-format* templates (Notulen Dinas, Risalah Rapat, ...), which
/// shape the exported document rather than the session that produces it.
///
/// Persisted through [DartPrefs] — the same Dart-only, atomic-write JSON
/// file already used for everything that is not sent to Rust — rather
/// than a dedicated file, since this is a short list a user edits rarely.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dart_prefs.dart';
import 'models.dart' show SessionMode;

const String _kPrefsKey = 'meeting_templates';

class MeetingTemplate {
  const MeetingTemplate({
    required this.id,
    required this.name,
    this.participants = const [],
    this.agenda = const [],
    this.language,
    this.mode = SessionMode.online,
  });

  final String id;
  final String name;
  final List<String> participants;
  final List<String> agenda;

  /// `null` means "Otomatis", matching [AppSettings.language]'s own
  /// convention — a template that pinned a language would otherwise be
  /// unable to express "decide per mode, like normal".
  final String? language;
  final SessionMode mode;

  MeetingTemplate copyWith({
    String? name,
    List<String>? participants,
    List<String>? agenda,
    String? language,
    bool clearLanguage = false,
    SessionMode? mode,
  }) => MeetingTemplate(
    id: id,
    name: name ?? this.name,
    participants: participants ?? this.participants,
    agenda: agenda ?? this.agenda,
    language: clearLanguage ? null : (language ?? this.language),
    mode: mode ?? this.mode,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'participants': participants,
    'agenda': agenda,
    if (language != null) 'language': language,
    'mode': mode.name,
  };

  /// Tolerant of a hand-edited or partially-written prefs file — one bad
  /// entry must not make every saved template unreadable.
  static MeetingTemplate? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    return MeetingTemplate(
      id: id,
      name: name,
      participants: _strings(raw['participants']),
      agenda: _strings(raw['agenda']),
      language: raw['language'] is String ? raw['language'] as String : null,
      mode:
          SessionMode.values
              .where((m) => m.name == raw['mode'])
              .firstOrNull ??
          SessionMode.online,
    );
  }
}

List<String> _strings(Object? raw) =>
    raw is List ? raw.whereType<String>().toList() : const [];

/// Loads and saves the saved-template list through [DartPrefs].
class MeetingTemplateStore {
  const MeetingTemplateStore();

  /// Reads the already-loaded [DartPrefs] singleton. Does not call
  /// `DartPrefs.instance.load()` itself: that reloads from disk and would
  /// stomp on whatever the caller just wrote in-memory via [saveAll] —
  /// `DartPrefs` is loaded once at app startup, same as every other
  /// consumer of it.
  Future<List<MeetingTemplate>> load() async {
    final raw = DartPrefs.instance.getString(_kPrefsKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(MeetingTemplate.fromJson).whereType<MeetingTemplate>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> saveAll(List<MeetingTemplate> templates) async {
    DartPrefs.instance.setString(
      _kPrefsKey,
      jsonEncode([for (final t in templates) t.toJson()]),
    );
    return DartPrefs.instance.save();
  }
}

class MeetingTemplateNotifier extends StateNotifier<List<MeetingTemplate>> {
  MeetingTemplateNotifier({MeetingTemplateStore? store})
    : _store = store ?? const MeetingTemplateStore(),
      super(const []);

  final MeetingTemplateStore _store;

  Future<void> load() async {
    state = await _store.load();
  }

  /// Adds [template], or replaces the existing one with the same id.
  Future<void> upsert(MeetingTemplate template) async {
    final next = [
      for (final existing in state)
        if (existing.id != template.id) existing,
      template,
    ];
    state = next;
    await _store.saveAll(next);
  }

  Future<void> remove(String id) async {
    final next = state.where((t) => t.id != id).toList();
    state = next;
    await _store.saveAll(next);
  }
}

final meetingTemplatesProvider =
    StateNotifierProvider<MeetingTemplateNotifier, List<MeetingTemplate>>(
      (ref) => MeetingTemplateNotifier(),
    );
