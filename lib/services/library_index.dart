/// Two-phase library load.
///
/// Opening the library used to parse **every** transcript in the corpus on
/// the UI isolate: for 200 sessions × 5 000 segments that is a million
/// `TranscriptSegment` objects, several hundred megabytes, and seconds of
/// synchronous JSON decoding behind a spinner that could not animate
/// because the decode blocked the isolate (audit A.2-3).
///
/// Phase 1 — this file — reads one small index file and shows the list.
/// Phase 2 — [loadSessionRecord] — parses a session's segments only when
/// the user actually opens it.
///
/// The index is a cache, never a source of truth: every entry is validated
/// against the transcript's size and mtime, and anything stale or missing
/// is re-derived from disk. Deleting the index file costs one slow open,
/// not a wrong library.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../state/models.dart';
import '../utils/atomic_file.dart';
import 'session_store.dart';

/// Where the index lives. Inside the library directory so it travels with
/// it, dot-prefixed so the directory scan skips it like any hidden file.
const String kLibraryIndexFilename = '.trareon-library-index.json';

/// Bumped when the entry shape changes; a mismatched version is discarded
/// rather than migrated.
const int kLibraryIndexVersion = 1;

/// Longest snippet stored per session. Enough for a recognisable line in a
/// search result, short enough that 200 of them stay a small file.
const int kSnippetMaxChars = 200;

/// One session as the library *list* needs it. Deliberately does not carry
/// segments: that is what made the old load O(corpus).
class LibraryEntry {
  /// Absolute path of the session directory. Doubles as the stable id.
  final String dirPath;
  final String title;

  /// `YYYY-MM-DD`. Taken from the `YYYYMMDD-` directory prefix the
  /// exporter writes, falling back to the directory mtime. The mtime alone
  /// was wrong: renaming a session, saving a summary or re-transcribing all
  /// write inside the directory, so editing an old meeting relabelled it
  /// today and moved it to the top of the list (audit A.2-7).
  final String date;

  final double durationSeconds;
  final int segmentsCount;

  /// First transcript line, for the card and for cheap search.
  final String snippet;

  /// Absolute path of the session's playable audio, if it has any.
  final String? audioPath;

  /// The saved AI summary, carried in the index so that searching it does
  /// not mean opening 200 sidecars.
  final String summary;

  /// Lowercased title + snippet + summary, computed once at construction.
  /// `toLowerCase()` per session per keystroke is most of what made search
  /// unusable (audit A.2-4).
  final String haystack;

  /// Identity of the transcript this entry was derived from. A changed
  /// size or mtime invalidates the entry.
  final int transcriptSize;
  final int transcriptModifiedMs;

  LibraryEntry({
    required this.dirPath,
    required this.title,
    required this.date,
    required this.durationSeconds,
    required this.segmentsCount,
    required this.snippet,
    required this.transcriptSize,
    required this.transcriptModifiedMs,
    this.summary = '',
    this.audioPath,
  }) : haystack = '$title\n$snippet\n$summary'.toLowerCase();

  bool get hasSummary => summary.trim().isNotEmpty;

  SessionSummary toSummary() => SessionSummary(
        id: dirPath,
        title: title,
        date: date,
        segmentsCount: segmentsCount,
        durationSeconds: durationSeconds,
        audioPath: audioPath,
      );

  LibraryEntry copyWith({String? title, String? summary}) => LibraryEntry(
        dirPath: dirPath,
        title: title ?? this.title,
        date: date,
        durationSeconds: durationSeconds,
        segmentsCount: segmentsCount,
        snippet: snippet,
        audioPath: audioPath,
        summary: summary ?? this.summary,
        transcriptSize: transcriptSize,
        transcriptModifiedMs: transcriptModifiedMs,
      );

  Map<String, dynamic> toJson(String dirName) => {
        'dir': dirName,
        'title': title,
        'date': date,
        'duration': durationSeconds,
        'segments': segmentsCount,
        'snippet': snippet,
        if (audioPath != null) 'audio': _basename(audioPath!),
        if (summary.isNotEmpty) 'summary': summary,
        'size': transcriptSize,
        'mtime': transcriptModifiedMs,
      };

  static LibraryEntry? fromJson(String libraryPath, Map<String, dynamic> json) {
    final dirName = json['dir'];
    if (dirName is! String || dirName.isEmpty) return null;
    final dirPath = '$libraryPath${Platform.pathSeparator}$dirName';
    final audio = json['audio'];
    return LibraryEntry(
      dirPath: dirPath,
      title: json['title'] as String? ?? titleFromDirName(dirName),
      date: json['date'] as String? ?? '',
      durationSeconds: (json['duration'] as num?)?.toDouble() ?? 0,
      segmentsCount: (json['segments'] as num?)?.toInt() ?? 0,
      snippet: json['snippet'] as String? ?? '',
      audioPath: audio is String && audio.isNotEmpty
          ? '$dirPath${Platform.pathSeparator}$audio'
          : null,
      summary: json['summary'] as String? ?? '',
      transcriptSize: (json['size'] as num?)?.toInt() ?? -1,
      transcriptModifiedMs: (json['mtime'] as num?)?.toInt() ?? -1,
    );
  }
}

/// Result of a phase-1 load.
class LibraryIndexLoad {
  final List<LibraryEntry> entries;

  /// How many sessions had to be parsed because the index was missing or
  /// stale. Zero on a warm open — which is the whole point, and what the
  /// benchmark asserts.
  final int parsedFromDisk;

  const LibraryIndexLoad(this.entries, this.parsedFromDisk);
}

String _basename(String path) {
  final i = path.lastIndexOf(Platform.pathSeparator);
  return i < 0 ? path : path.substring(i + 1);
}

String _dirNameOf(Directory dir) =>
    dir.uri.pathSegments.where((s) => s.isNotEmpty).last;

/// `YYYYMMDD-Judul` → `2026-01-31`. Null when the directory carries no
/// date prefix.
String? dateFromDirName(String dirName) {
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})-').firstMatch(dirName);
  if (match == null) return null;
  return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
}

String _snippetOf(List<TranscriptSegment> segments) {
  for (final segment in segments) {
    final text = segment.text.trim();
    if (text.isEmpty) continue;
    final line = segment.speaker.trim().isEmpty
        ? text
        : '${segment.speaker}: $text';
    return line.length <= kSnippetMaxChars
        ? line
        : '${line.substring(0, kSnippetMaxChars)}…';
  }
  return '';
}

/// Parses one session directory into an index entry. This is the expensive
/// path — it decodes the transcript — and is only taken for sessions the
/// index does not already cover.
Future<LibraryEntry?> buildLibraryEntry(Directory dir) async {
  try {
    final transcript = transcriptFileIn(dir);
    if (transcript == null) return null;
    final raw = await transcript.readAsString();
    final segments = parseTranscriptJson(raw);
    final meta = await readSessionMeta(dir.path);
    final stat = await transcript.stat();
    final dirName = _dirNameOf(dir);
    final audio = dir.listSync().whereType<File>().where((f) {
      final ext = f.path.split('.').last.toLowerCase();
      return kAudioExtensions.contains(ext);
    }).firstOrNull;

    final title = meta.title?.trim().isNotEmpty == true
        ? meta.title!.trim()
        : titleFromDirName(dirName);
    final snippet = _snippetOf(segments);
    return LibraryEntry(
      dirPath: dir.path,
      title: title,
      date: dateFromDirName(dirName) ??
          (await dir.stat()).modified.toIso8601String().substring(0, 10),
      durationSeconds: segments.isEmpty
          ? 0
          : segments.last.timestamp + segments.last.duration,
      segmentsCount: segments.length,
      snippet: snippet,
      audioPath: audio?.path,
      summary: meta.summary,
      transcriptSize: stat.size,
      transcriptModifiedMs: stat.modified.millisecondsSinceEpoch,
    );
  } catch (_) {
    // One unreadable folder must never empty the user's whole library.
    return null;
  }
}

/// Phase 1: the list, as fast as the index allows.
Future<LibraryIndexLoad> loadLibraryIndex(String libraryPath) async {
  final root = Directory(libraryPath);
  if (!await root.exists()) return const LibraryIndexLoad([], 0);

  final List<FileSystemEntity> children;
  try {
    children = root.listSync();
  } catch (_) {
    return const LibraryIndexLoad([], 0);
  }
  final directories = children.whereType<Directory>().toList();

  final cached = await _readIndexFile(libraryPath);
  final entries = <LibraryEntry>[];
  var parsed = 0;
  var indexChanged = cached.length != directories.length;

  for (final dir in directories) {
    final entry = cached[dir.path];
    if (entry != null && await _stillValid(dir, entry)) {
      entries.add(entry);
      continue;
    }
    final built = await buildLibraryEntry(dir);
    indexChanged = true;
    if (built == null) continue;
    parsed++;
    entries.add(built);
  }

  entries.sort((a, b) => b.date.compareTo(a.date));
  if (indexChanged) {
    // Best effort: a read-only library still opens, it just opens slowly.
    unawaited(saveLibraryIndex(libraryPath, entries).catchError((_) {}));
  }
  return LibraryIndexLoad(entries, parsed);
}

Future<bool> _stillValid(Directory dir, LibraryEntry entry) async {
  try {
    final transcript = transcriptFileIn(dir);
    if (transcript == null) return false;
    final stat = await transcript.stat();
    return stat.size == entry.transcriptSize &&
        stat.modified.millisecondsSinceEpoch == entry.transcriptModifiedMs;
  } catch (_) {
    return false;
  }
}

Future<Map<String, LibraryEntry>> _readIndexFile(String libraryPath) async {
  try {
    final file =
        File('$libraryPath${Platform.pathSeparator}$kLibraryIndexFilename');
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return {};
    if (decoded['version'] != kLibraryIndexVersion) return {};
    final raw = decoded['entries'];
    if (raw is! List) return {};
    final result = <String, LibraryEntry>{};
    for (final item in raw.whereType<Map<String, dynamic>>()) {
      final entry = LibraryEntry.fromJson(libraryPath, item);
      if (entry != null) result[entry.dirPath] = entry;
    }
    return result;
  } catch (_) {
    return {};
  }
}

/// Writes the index atomically — it lives in the directory it describes,
/// and a half-written index would be discarded on the next open anyway,
/// but a truncated one next to the user's meetings is still litter.
Future<void> saveLibraryIndex(
  String libraryPath,
  List<LibraryEntry> entries,
) async {
  final file =
      File('$libraryPath${Platform.pathSeparator}$kLibraryIndexFilename');
  await writeStringAtomic(
    file,
    jsonEncode({
      'version': kLibraryIndexVersion,
      'entries': [
        for (final entry in entries) entry.toJson(_basename(entry.dirPath)),
      ],
    }),
  );
}

/// Phase 2: everything the player needs, for one session.
Future<SessionRecord?> loadSessionRecord(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return null;
  try {
    final transcript = transcriptFileIn(dir);
    final segments = transcript == null
        ? const <TranscriptSegment>[]
        : parseTranscriptJson(await transcript.readAsString());
    final meta = await readSessionMeta(dirPath);
    final dirName = _dirNameOf(dir);
    final audio = dir.listSync().whereType<File>().where((f) {
      final ext = f.path.split('.').last.toLowerCase();
      return kAudioExtensions.contains(ext);
    }).firstOrNull;
    return SessionRecord(
      dirPath: dirPath,
      title: meta.title?.trim().isNotEmpty == true
          ? meta.title!.trim()
          : titleFromDirName(dirName),
      date: dateFromDirName(dirName) ??
          (await dir.stat()).modified.toIso8601String().substring(0, 10),
      segments: segments,
      durationSeconds: segments.isEmpty
          ? 0
          : segments.last.timestamp + segments.last.duration,
      audioPath: audio?.path,
      meta: meta,
    );
  } catch (_) {
    return null;
  }
}

/// A transcript line that matched a deep search.
class DeepSearchHit {
  final String dirPath;
  final String snippet;

  const DeepSearchHit(this.dirPath, this.snippet);
}

/// Full-text search over transcripts the index could not answer.
///
/// Runs on a background isolate: it reads and scans every transcript in the
/// corpus, which on the UI isolate is exactly the freeze the two-phase load
/// was built to remove. Only reached when the cheap index-level match finds
/// nothing, so ordinary "search by title" typing never pays for it.
Future<List<DeepSearchHit>> deepSearchLibrary(
  List<String> dirPaths,
  String query, {
  int limit = 50,
}) async {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty || dirPaths.isEmpty) return const [];
  return Isolate.run(() => _deepSearchSync(dirPaths, needle, limit));
}

/// Body of [deepSearchLibrary]. Top-level and self-contained so it can be
/// sent to an isolate, and directly callable in tests.
List<DeepSearchHit> _deepSearchSync(
  List<String> dirPaths,
  String needle,
  int limit,
) {
  if (needle.isEmpty) return const [];
  final hits = <DeepSearchHit>[];
  for (final dirPath in dirPaths) {
    if (hits.length >= limit) break;
    try {
      final transcript = transcriptFileIn(Directory(dirPath));
      if (transcript == null) continue;
      final raw = transcript.readAsStringSync();
      // A cheap whole-file reject before paying for a JSON decode: the
      // needle cannot be in a segment if it is not in the file.
      if (!raw.toLowerCase().contains(needle)) continue;
      for (final segment in parseTranscriptJson(raw)) {
        if (!segment.text.toLowerCase().contains(needle)) continue;
        hits.add(DeepSearchHit(
          dirPath,
          '${segment.speaker}: ${segment.text}'.trim(),
        ));
        break;
      }
    } catch (_) {
      continue;
    }
  }
  return hits;
}

/// Synchronous [deepSearchLibrary], for tests that must not depend on
/// isolate availability.
List<DeepSearchHit> deepSearchLibrarySync(
  List<String> dirPaths,
  String query, {
  int limit = 50,
}) =>
    _deepSearchSync(dirPaths, query.trim().toLowerCase(), limit);
