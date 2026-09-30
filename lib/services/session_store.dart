/// On-disk session library.
///
/// A session is a directory under the configured library path containing the
/// exported transcript (`*.json`, written by the Rust exporter), optionally
/// the source/captured audio, and — new here — a [kMetaFilename] sidecar.
///
/// The sidecar exists because everything Meetily-parity needs beyond raw
/// segments has nowhere else to live: a summary, the template it was made
/// with, a user-chosen title independent of the folder name, and which model
/// produced the transcript. The transcript `*.json` is a bare segment array
/// and must stay that way — it is also an export artifact the user may hand
/// to other tools.
///
/// Sessions written before the sidecar existed load fine: every field falls
/// back to something derivable from the directory itself.
library;

import 'dart:convert';
import 'dart:io';

import '../state/models.dart';

const String kMetaFilename = 'trareon-session.json';

/// Audio container extensions recognised when locating a session's playable
/// source file.
const Set<String> kAudioExtensions = {
  'wav',
  'mp3',
  'm4a',
  'aac',
  'ogg',
  'flac',
  'opus',
  'mp4',
  'mov',
  'mkv',
};

/// Sidecar contents. Everything is optional — a missing sidecar yields
/// [SessionMeta.empty] and the library still renders.
class SessionMeta {
  /// User-facing title. Independent of the directory name so renaming never
  /// has to move files (which would break `audioPath` and the exported
  /// filenames inside the folder).
  final String? title;
  final String summary;
  final SummaryTemplate? summaryTemplate;
  final DateTime? summaryGeneratedAt;

  /// Language and model the transcript was produced with, so "Transkrip
  /// Ulang" can show what it is replacing.
  final String? language;
  final String? model;

  const SessionMeta({
    this.title,
    this.summary = '',
    this.summaryTemplate,
    this.summaryGeneratedAt,
    this.language,
    this.model,
  });

  static const SessionMeta empty = SessionMeta();

  bool get hasSummary => summary.trim().isNotEmpty;

  SessionMeta copyWith({
    String? title,
    String? summary,
    SummaryTemplate? summaryTemplate,
    DateTime? summaryGeneratedAt,
    String? language,
    String? model,
  }) {
    return SessionMeta(
      title: title ?? this.title,
      summary: summary ?? this.summary,
      summaryTemplate: summaryTemplate ?? this.summaryTemplate,
      summaryGeneratedAt: summaryGeneratedAt ?? this.summaryGeneratedAt,
      language: language ?? this.language,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    if (title != null) 'title': title,
    if (summary.isNotEmpty) 'summary': summary,
    if (summaryTemplate != null) 'summary_template': summaryTemplate!.name,
    if (summaryGeneratedAt != null)
      'summary_generated_at': summaryGeneratedAt!.toIso8601String(),
    if (language != null) 'language': language,
    if (model != null) 'model': model,
  };

  /// Tolerant of every field being absent, of the wrong type, or naming a
  /// template this build doesn't know — a hand-edited or
  /// newer-version sidecar must not make a session unopenable.
  factory SessionMeta.fromJson(Map<String, dynamic> json) {
    final templateName = json['summary_template'];
    return SessionMeta(
      title: json['title'] is String ? json['title'] as String : null,
      summary: json['summary'] is String ? json['summary'] as String : '',
      summaryTemplate: templateName is String
          ? SummaryTemplate.values
                .where((t) => t.name == templateName)
                .firstOrNull
          : null,
      summaryGeneratedAt: json['summary_generated_at'] is String
          ? DateTime.tryParse(json['summary_generated_at'] as String)
          : null,
      language: json['language'] is String ? json['language'] as String : null,
      model: json['model'] is String ? json['model'] as String : null,
    );
  }
}

/// One session as the library screen sees it: transcript plus sidecar.
class SessionRecord {
  /// Absolute path of the session directory. Doubles as the stable id.
  final String dirPath;
  final String title;
  final String date;
  final List<TranscriptSegment> segments;
  final double durationSeconds;
  final String? audioPath;
  final SessionMeta meta;

  /// Segment count shown on the card. Defaults to `segments.length`, which is
  /// always right for a disk-loaded session; kept overridable so a caller that
  /// seeds the library with a count but only a sample of segments (tests,
  /// previews) still renders the real number.
  final int? seededSegmentsCount;

  const SessionRecord({
    required this.dirPath,
    required this.title,
    required this.date,
    required this.segments,
    required this.durationSeconds,
    required this.meta,
    this.audioPath,
    this.seededSegmentsCount,
  });

  int get segmentsCount => seededSegmentsCount ?? segments.length;

  SessionSummary toSummary() => SessionSummary(
    id: dirPath,
    title: title,
    date: date,
    segmentsCount: segmentsCount,
    segments: segments,
    durationSeconds: durationSeconds,
    audioPath: audioPath,
  );

  SessionRecord copyWith({String? title, SessionMeta? meta}) => SessionRecord(
    dirPath: dirPath,
    title: title ?? this.title,
    date: date,
    segments: segments,
    durationSeconds: durationSeconds,
    audioPath: audioPath,
    meta: meta ?? this.meta,
    seededSegmentsCount: seededSegmentsCount,
  );
}

/// Strips the `YYYYMMDD-` prefix the exporter prepends to session folders, so
/// the library shows "Rapat Tim" rather than "20260930-Rapat Tim".
String titleFromDirName(String dirName) {
  final match = RegExp(r'^\d{8}-(.+)$').firstMatch(dirName);
  return match?.group(1) ?? dirName;
}

/// Whether [record] matches [query], searched over the title, the summary and
/// every segment's text.
///
/// Full-text search across transcripts is the point: the library previously
/// matched titles only, which for auto-titled sessions ("Sesi 2026-09-30
/// 14:05") meant search found nothing anyone would think to look for.
bool sessionMatchesQuery(SessionRecord record, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (record.title.toLowerCase().contains(q)) return true;
  if (record.meta.summary.toLowerCase().contains(q)) return true;
  return record.segments.any((s) => s.text.toLowerCase().contains(q));
}

/// The first transcript line containing [query], for the search-result
/// snippet. `null` when the match came from the title or summary only.
String? matchingSnippet(SessionRecord record, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;
  for (final segment in record.segments) {
    if (segment.text.toLowerCase().contains(q)) {
      return '${segment.speaker}: ${segment.text}'.trim();
    }
  }
  return null;
}

/// Reads the sidecar in [dirPath]. Returns [SessionMeta.empty] when it is
/// missing or unreadable — a corrupt sidecar must never hide a transcript.
Future<SessionMeta> readSessionMeta(String dirPath) async {
  try {
    final file = File('$dirPath${Platform.pathSeparator}$kMetaFilename');
    if (!await file.exists()) return SessionMeta.empty;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return SessionMeta.empty;
    return SessionMeta.fromJson(decoded);
  } catch (_) {
    return SessionMeta.empty;
  }
}

/// Writes the sidecar for [dirPath], creating the directory if needed.
/// Throws on failure so callers can tell the user their edit wasn't saved.
Future<void> writeSessionMeta(String dirPath, SessionMeta meta) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) await dir.create(recursive: true);
  final file = File('$dirPath${Platform.pathSeparator}$kMetaFilename');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(meta.toJson()));
}

/// Parses the exported transcript JSON (a bare segment array) into segments.
/// Exposed for tests and for the re-transcribe flow.
List<TranscriptSegment> parseTranscriptJson(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded.whereType<Map<String, dynamic>>().map((m) {
    return TranscriptSegment(
      source: m['source'] as String? ?? '',
      speaker: m['speaker'] as String? ?? '',
      text: m['text'] as String? ?? '',
      timestamp: (m['timestamp'] as num?)?.toDouble() ?? 0,
      duration: (m['duration'] as num?)?.toDouble() ?? 0,
      language: m['language'] as String? ?? '',
      confidence: (m['confidence'] as num?)?.toDouble() ?? 1.0,
      isPartial: m['is_partial'] as bool? ?? false,
      lowConfidence: m['low_confidence'] as bool? ?? false,
      avgLogProb: (m['avg_log_prob'] as num?)?.toDouble() ?? 0.0,
    );
  }).toList();
}

/// Serialises segments back into the exporter's JSON shape, so an edited or
/// re-transcribed session round-trips through the same file the library reads.
String encodeTranscriptJson(List<TranscriptSegment> segments) {
  return jsonEncode([
    for (final s in segments)
      {
        'source': s.source,
        'speaker': s.speaker,
        'text': s.text,
        'timestamp': s.timestamp,
        'duration': s.duration,
        'language': s.language,
        'confidence': s.confidence,
        'avg_log_prob': s.avgLogProb,
        'is_partial': s.isPartial,
        'low_confidence': s.lowConfidence,
      },
  ]);
}

/// The transcript JSON file inside a session directory, or `null` if absent.
/// Skips [kMetaFilename] — the sidecar is JSON too, and picking it as the
/// transcript would make every session look empty.
File? transcriptFileIn(Directory sessionDir) {
  try {
    return sessionDir
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.json') &&
              f.uri.pathSegments.last != kMetaFilename,
        )
        .firstOrNull;
  } catch (_) {
    return null;
  }
}

/// Loads every session under [libraryPath], newest first.
///
/// A directory that fails to parse is skipped rather than aborting the scan:
/// one bad folder must not empty the user's whole library.
Future<List<SessionRecord>> loadSessionLibrary(String libraryPath) async {
  final dir = Directory(libraryPath);
  if (!await dir.exists()) return const [];

  final sessions = <SessionRecord>[];
  final List<FileSystemEntity> entries;
  try {
    entries = dir.listSync();
  } catch (_) {
    return const [];
  }

  for (final entry in entries) {
    if (entry is! Directory) continue;
    try {
      final transcript = transcriptFileIn(entry);
      if (transcript == null) continue;
      final segments = parseTranscriptJson(await transcript.readAsString());
      final meta = await readSessionMeta(entry.path);
      final stat = await entry.stat();
      final dirName = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final audio = entry.listSync().whereType<File>().where((f) {
        final ext = f.path.split('.').last.toLowerCase();
        return kAudioExtensions.contains(ext);
      }).firstOrNull;

      sessions.add(
        SessionRecord(
          dirPath: entry.path,
          title: meta.title?.trim().isNotEmpty == true
              ? meta.title!.trim()
              : titleFromDirName(dirName),
          date: stat.modified.toIso8601String().substring(0, 10),
          segments: segments,
          durationSeconds: segments.isEmpty
              ? 0
              : segments.last.timestamp + segments.last.duration,
          audioPath: audio?.path,
          meta: meta,
        ),
      );
    } catch (_) {
      continue;
    }
  }

  sessions.sort((a, b) => b.date.compareTo(a.date));
  return sessions;
}
