/// Speaker names remembered across sessions, by engine label (F10).
///
/// The diarizer produces labels, not names: `Saya`, `Peserta 2`,
/// `Pembicara 3 (Mikrofon)`. A notulis who records the same weekly
/// meeting renames the same labels to the same people every week, and
/// retyping them is exactly the kind of work software should absorb.
///
/// # Why this is by label and not by voice
///
/// It would be better to remember a *voice*. The clustering here is
/// pitch/energy/ZCR, which is nowhere near stable enough across sessions
/// and recording conditions for that to be trustworthy — remembering by
/// voice would confidently put the wrong name on the wrong person, which
/// is worse than no memory at all. By label it is only ever a
/// *suggestion* about ordering: `Peserta 2` in a recurring meeting is
/// usually the same person, and when it is not, the user renames it and
/// the memory updates.
///
/// So this is opt-in per rename, never applied silently to a transcript
/// the user has not looked at, and always visible as "diingat dari rapat
/// sebelumnya" where it is offered.
library;

import 'dart:convert';

import 'dart:async';

import 'dart_prefs.dart';

/// Prefs key holding the `label -> name` map as JSON.
const String kSpeakerAliasesKey = 'speaker_aliases';

/// Reads the remembered names. Empty when nothing has been remembered.
Map<String, String> readSpeakerAliases() {
  final raw = DartPrefs.instance.getString(kSpeakerAliasesKey);
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {
      for (final entry in decoded.entries)
        if (entry.key is String &&
            entry.value is String &&
            (entry.key as String).trim().isNotEmpty &&
            (entry.value as String).trim().isNotEmpty)
          entry.key as String: entry.value as String,
    };
  } catch (_) {
    // A hand-edited prefs file must not stop the player opening.
    return const {};
  }
}

/// Remembers that [label] is [name], or forgets it when [name] is blank
/// or equal to the label itself.
///
/// Returns true when the write reached disk — callers show the user
/// whether the memory took.
Future<bool> rememberSpeakerAlias(String label, String name) async {
  final aliases = Map<String, String>.from(readSpeakerAliases());
  final trimmedLabel = label.trim();
  final trimmedName = name.trim();
  if (trimmedLabel.isEmpty) return false;
  if (trimmedName.isEmpty || trimmedName == trimmedLabel) {
    aliases.remove(trimmedLabel);
  } else {
    aliases[trimmedLabel] = trimmedName;
  }
  DartPrefs.instance.setString(kSpeakerAliasesKey, jsonEncode(aliases));
  return DartPrefs.instance.save();
}

Future<bool> forgetSpeakerAlias(String label) =>
    rememberSpeakerAlias(label, '');

/// Clears every remembered name.
Future<bool> forgetAllSpeakerAliases() async {
  DartPrefs.instance.remove(kSpeakerAliasesKey);
  return DartPrefs.instance.save();
}

/// Suggestions for the labels actually present in [labels].
///
/// Only labels that are still the engine's own are offered: once the user
/// has renamed `Peserta 2` to "Pak Budi" in this session, a remembered
/// name for `Peserta 2` has nothing to say about it.
Map<String, String> suggestionsFor(Iterable<String> labels) {
  final aliases = readSpeakerAliases();
  return {
    for (final label in labels)
      if (aliases.containsKey(label)) label: aliases[label]!,
  };
}
