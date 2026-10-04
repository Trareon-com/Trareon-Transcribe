import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Blueprint §4.4 and audit A.12: the UI is Indonesian, and the words it uses
/// are the ones a notulis already knows.
///
/// The audit's copy inventory listed twenty English strings in an
/// Indonesian-first product — `VAD`, `Echo Dedupe`, `Progressive Mode`,
/// `Subtitle format`, `API key`. Each one individually looks harmless; together
/// they are why the app read as a translation of an English tool. This test
/// reads the source so the next one is caught in CI rather than in a
/// screenshot review.
///
/// It is deliberately a **blocklist**, not an attempt to detect English: a
/// general detector would flag `Markdown`, `Ollama` and `DOCX`, which are
/// product names, and would have to be silenced so often that it would stop
/// being read.
void main() {
  /// Jargon and English UI words that must not reach the user.
  ///
  /// Each entry says what to use instead, so a failure is actionable rather
  /// than a riddle. Keys are matched case-insensitively on word boundaries.
  const forbidden = <String, String>{
    // The four the blueprint names explicitly (§4.4).
    'VAD': 'Abaikan jeda sunyi',
    'Echo Dedupe': 'Hapus suara ganda',
    'Dedupe': 'Hapus suara ganda',
    'Progressive Mode': 'Cepat dulu, lalu diperhalus',
    'Auto-detect': 'Deteksi otomatis',
    // Internal acronyms that only mean something to the people who wrote
    // them. HPT and RTF are implementation names; a user has no use for
    // either.
    'HPT': 'jangan tampilkan — ini nama internal',
    'RTF': 'jangan tampilkan — ini nama internal',
    'realtime factor': 'jangan tampilkan — ini nama internal',
    // Plain English that crept into labels.
    'Auto-Stop': 'Berhenti sendiri saat sunyi',
    'API key': 'Kunci API',
    'Action Items': 'Tindak Lanjut',
    'Settings': 'Pengaturan',
    'Cancel': 'Batal',
    'Loading': 'Memuat',
    'Decoding': 'Membaca berkas',
    'Speaker': 'Pembicara (orang) / Pengeras suara (perangkat)',
    'Upload': 'Impor',
    'Subtitle': 'Takarir',
    'Plain text': 'Teks biasa',
    'Preview': 'Pratinjau',
    'cloud': 'server / layanan daring',
    'Tone Test': 'Uji nada',
    'CPU Cores': 'Inti prosesor',
  };

  /// Strings that legitimately contain a blocked word.
  ///
  /// Kept short and each with a reason: an allowlist that grows without
  /// argument is how the inventory stopped being enforced the first time.
  const allowed = <String>{
    // `StreamToggle.kSpeakerKey` — a widget key, not copy; the label it
    // produces is "Pengeras suara aktif".
    'SPEAKER_TOGGLE_KEY',
    // Microsoft's product name.
    'Dokumen Microsoft Word',
  };

  late final RegExp stringLiteral;
  late final List<({String file, int line, String text})> uiStrings;

  setUpAll(() {
    // Single- and double-quoted Dart literals, one line at a time. Built from
    // two halves because a raw literal cannot end in the quote character it
    // is delimited by.
    const singleQuoted = r"'([^'\\]|\\.){4,}'";
    final doubleQuoted = '"([^"\\\\]|\\\\.){4,}"';
    stringLiteral = RegExp('$singleQuoted|$doubleQuoted');
    uiStrings = _collectUiStrings(stringLiteral);
  });

  test('the scan sees a representative amount of UI copy', () {
    // A regex that matches nothing would make everything below pass forever.
    expect(uiStrings.length, greaterThan(300));
    expect(
      uiStrings.any((s) => s.text.contains('Pengaturan')),
      isTrue,
      reason: 'the scan should find the settings title',
    );
  });

  test('no English UI words or internal jargon in user-facing strings', () {
    final offenders = <String>[];
    for (final entry in forbidden.entries) {
      final pattern = RegExp(
        r'(?<![A-Za-z])' + RegExp.escape(entry.key) + r'(?![A-Za-z])',
        caseSensitive: false,
      );
      for (final found in uiStrings) {
        if (!pattern.hasMatch(found.text)) continue;
        if (allowed.any(found.text.contains)) continue;
        offenders.add(
          '${found.file}:${found.line}  "${found.text}"\n'
          '      → "${entry.key}" sebaiknya "${entry.value}"',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Indonesian-first means the UI words are Indonesian too '
          '(blueprint §4.4):\n${offenders.join('\n')}',
    );
  });

  test('the blocklist itself still catches what it is meant to catch', () {
    // Guards against a regex change that quietly stops matching.
    final vad = RegExp(r'(?<![A-Za-z])VAD(?![A-Za-z])', caseSensitive: false);
    expect(vad.hasMatch('VAD (deteksi suara)'), isTrue);
    expect(vad.hasMatch('Abaikan jeda sunyi'), isFalse);
    // A word that merely contains the token must not match.
    expect(vad.hasMatch('Nevada'), isFalse);
  });
}

/// Every string literal in the hand-written UI sources, with its location.
///
/// Skips `lib/src/rust/` (generated), doc comments, `//` comments, and
/// anything that looks like an identifier rather than copy: a path, a key, an
/// interpolation-only string, or a single lowercase token.
List<({String file, int line, String text})> _collectUiStrings(RegExp literal) {
  final out = <({String file, int line, String text})>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.replaceAll(r'\', '/').startsWith('lib/src/rust/'))
      // Generated localisations: `app_localizations_en.dart` is the English
      // translation, so of course it contains English. The Indonesian copy is
      // authored in `lib/l10n/app_id.arb` (not a `.dart` file) and reviewed
      // there; the generated Dart is machinery.
      .where(
        (f) => !f.path
            .replaceAll(r'\', '/')
            .startsWith('lib/l10n/generated/'),
      )
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
      // `debugPrint` and `tracing`-style diagnostics are developer output.
      if (trimmed.startsWith('debugPrint')) continue;
      for (final match in literal.allMatches(line)) {
        final raw = match.group(0)!;
        // Interpolations are Dart code, not copy: `\${settings.autoStopMinutes}`
        // would otherwise read as the English word "Settings".
        final text = _stripInterpolations(raw.substring(1, raw.length - 1));
        if (!_looksLikeCopy(text)) continue;
        out.add((file: file.path.replaceAll(r'\', '/'), line: i + 1, text: text));
      }
    }
  }
  return out;
}

/// Replaces every `\$identifier` and `\${...}` with a placeholder, so the
/// variable names inside them are not mistaken for English UI copy.
String _stripInterpolations(String text) => text
    .replaceAll(RegExp(r'\$\{[^}]*\}'), '<x>')
    .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '<x>');

/// Heuristic for "this is shown to a person".
///
/// Requires a capital letter or a space, and rejects the shapes that are
/// clearly machinery: paths, package ids, preference keys, format ids, and
/// pure interpolations.
bool _looksLikeCopy(String text) {
  if (text.trim().isEmpty) return false;
  if (text.startsWith(r'$') && !text.contains(' ')) return false;
  if (text.contains('/') && !text.contains(' ')) return false;
  if (text.startsWith('package:') || text.startsWith('dart:')) return false;
  if (text.startsWith('com.') || text.startsWith('http')) return false;
  if (RegExp(r'^[a-z][a-zA-Z0-9_]*$').hasMatch(text)) return false;
  return text.contains(' ') || RegExp(r'[A-Z]').hasMatch(text);
}
