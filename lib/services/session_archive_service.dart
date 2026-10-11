/// "Ekspor/Impor arsip sesi" (F26/F27, Sprint 16): move a whole session
/// between devices as one `.zip`.
///
/// The mechanical zip/unzip is Rust (`session_archive.rs`, exposed through
/// [RustBridge.exportSessionArchive]/[RustBridge.importSessionArchive]) —
/// the same crate and pattern `flight_recorder.rs` already uses for the
/// diagnostics bundle. Everything here is Dart-side orchestration around
/// that: naming, validating an extracted folder against the *existing*
/// tolerant sidecar parser (`SessionMeta.fromJson`, not a new one), and
/// making the import atomic.
///
/// This is deliberately one-shot and manual: the user presses "Ekspor",
/// moves the `.zip` themselves, then presses "Impor" on the other device.
/// No watch-folder, no account, no device learning about another device —
/// see `docs/MULTI_DEVICE_HANDOFF_AUDIT.md`.
library;

import 'dart:io';

import 'bridge_service.dart';
import 'session_store.dart';

/// Characters illegal in a filename on at least one of Windows, macOS or
/// Linux, so a sanitized name is safe to write on every platform this app
/// ships on.
final RegExp _illegalFilenameChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

/// Turns [name] into something safe to use as a file or directory name on
/// every platform this app ships on.
///
/// Trailing dots/spaces are stripped because Windows silently drops them on
/// creation, which would otherwise make the name actually written differ
/// from the one the caller asked for.
String sanitizeArchiveName(String name) {
  final cleaned = name
      .replaceAll(_illegalFilenameChars, '_')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (cleaned.isEmpty) return 'sesi';
  return cleaned.length > 150 ? cleaned.substring(0, 150) : cleaned;
}

/// Default `.zip` filename for exporting a session titled [title], recorded
/// on [date] (`YYYY-MM-DD`, may be empty).
String archiveFilenameFor({required String title, required String date}) {
  final datePart = date.replaceAll('-', '');
  final name = sanitizeArchiveName(title);
  final stem = datePart.isEmpty ? name : '$datePart-$name';
  return '$stem.zip';
}

/// Thrown when a `.zip` the user picked to import is not a usable Trareon
/// session archive: unreadable/corrupt, or missing the parts a session
/// needs to open.
class InvalidSessionArchiveException implements Exception {
  final String message;
  const InvalidSessionArchiveException(this.message);
  @override
  String toString() => message;
}

/// A session's files, extracted into a scratch directory and confirmed to
/// be a real session, but not yet placed in the library.
class ValidatedSessionImport {
  /// Scratch directory holding the extracted files. Inside [libraryPath]
  /// (same filesystem) so [finalizeSessionImport] can place it with a plain
  /// rename. The caller must eventually finalize or delete it.
  final Directory tempDir;
  final SessionMeta meta;

  /// Directory name to try first in the target library — from the
  /// sidecar's title when it has one, otherwise the archive's own
  /// filename.
  final String suggestedDirName;

  const ValidatedSessionImport({
    required this.tempDir,
    required this.meta,
    required this.suggestedDirName,
  });
}

/// Prefix for the scratch directories this creates inside a library path,
/// so a crashed-mid-import leftover is recognisable and never shown as a
/// session (`buildLibraryEntry` already skips any folder with no
/// transcript, but naming it plainly helps a human looking at the folder).
const String _kImportScratchPrefix = '.trareon-impor-sementara-';

/// Extracts [archivePath] into a scratch directory inside [libraryPath] and
/// validates the result is a Trareon session, using the same tolerant
/// sidecar parser the library already trusts (`SessionMeta.fromJson`).
///
/// The scratch directory lives inside [libraryPath] — not the system temp
/// directory — specifically so [finalizeSessionImport] moves it into place
/// with a same-filesystem rename rather than a cross-filesystem copy.
///
/// Throws [InvalidSessionArchiveException] — and leaves nothing behind in
/// [libraryPath] — when the zip cannot be read or the extracted folder has
/// no transcript. Any stale scratch directory from a previous crashed
/// import is swept first.
Future<ValidatedSessionImport> extractAndValidateSessionArchive(
  RustBridge bridge,
  String archivePath,
  String libraryPath,
) async {
  await _sweepStaleScratchDirs(libraryPath);

  final tempDir = Directory(
    '$libraryPath${Platform.pathSeparator}'
    '$_kImportScratchPrefix${DateTime.now().microsecondsSinceEpoch}',
  );
  await tempDir.create(recursive: true);

  Future<T> fail<T>(String message) async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {
      // Best effort: an import that is already failing must not also
      // throw a second, more confusing error about cleanup.
    }
    throw InvalidSessionArchiveException(message);
  }

  List<String> written;
  try {
    written = await bridge.importSessionArchive(
      archivePath: archivePath,
      destinationDir: tempDir.path,
    );
  } catch (e) {
    return fail('Gagal membuka arsip: tidak terbaca atau rusak ($e).');
  }
  if (written.isEmpty) {
    return fail('Arsip ini kosong atau bukan arsip sesi Trareon.');
  }

  final transcript = transcriptFileIn(tempDir);
  if (transcript == null) {
    return fail(
      'File ini bukan arsip sesi Trareon yang valid: '
      'tidak ada transkrip di dalamnya.',
    );
  }

  final meta = await readSessionMeta(tempDir.path);
  final rawTitle = meta.title?.trim();
  final suggestedDirName = sanitizeArchiveName(
    rawTitle != null && rawTitle.isNotEmpty
        ? rawTitle
        : _basenameWithoutZip(archivePath),
  );

  return ValidatedSessionImport(
    tempDir: tempDir,
    meta: meta,
    suggestedDirName: suggestedDirName,
  );
}

/// Removes scratch directories from an import that never finished (crash,
/// kill -9) and is old enough that it cannot belong to an import still in
/// progress right now.
Future<void> _sweepStaleScratchDirs(String libraryPath) async {
  final root = Directory(libraryPath);
  if (!await root.exists()) return;
  const stale = Duration(minutes: 5);
  try {
    for (final entry in root.listSync().whereType<Directory>()) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!name.startsWith(_kImportScratchPrefix)) continue;
      try {
        final stat = await entry.stat();
        if (DateTime.now().difference(stat.modified) > stale) {
          await entry.delete(recursive: true);
        }
      } catch (_) {
        // A folder that can no longer be stat'd or deleted is left for the
        // next sweep rather than aborting this import over someone else's
        // leftover.
      }
    }
  } catch (_) {
    // Listing the library itself failing must not block the import.
  }
}

String _basenameWithoutZip(String path) {
  final base = path.split(Platform.pathSeparator).last;
  return base.toLowerCase().endsWith('.zip')
      ? base.substring(0, base.length - 4)
      : base;
}

/// How to resolve a name already taken by another session in the target
/// library.
enum SessionImportConflictChoice { skip, duplicate, overwrite }

/// Moves [validated]'s scratch directory into [libraryPath] under
/// [ValidatedSessionImport.suggestedDirName], resolving a name clash with
/// [onConflict] — called only when a session of that name already exists.
///
/// Returns the final session directory path, or `null` if the user chose
/// to skip, in which case the scratch directory is removed and nothing is
/// written to [libraryPath].
Future<String?> finalizeSessionImport(
  ValidatedSessionImport validated,
  String libraryPath, {
  required Future<SessionImportConflictChoice> Function() onConflict,
}) async {
  var targetPath =
      '$libraryPath${Platform.pathSeparator}${validated.suggestedDirName}';

  if (await Directory(targetPath).exists()) {
    switch (await onConflict()) {
      case SessionImportConflictChoice.skip:
        await validated.tempDir.delete(recursive: true);
        return null;
      case SessionImportConflictChoice.overwrite:
        await Directory(targetPath).delete(recursive: true);
      case SessionImportConflictChoice.duplicate:
        targetPath = _firstFreeDuplicatePath(
          libraryPath,
          validated.suggestedDirName,
        );
    }
  }

  await validated.tempDir.rename(targetPath);
  return targetPath;
}

String _firstFreeDuplicatePath(String libraryPath, String baseName) {
  for (var i = 2; i < 1000; i++) {
    final candidate =
        '$libraryPath${Platform.pathSeparator}$baseName ($i)';
    if (!Directory(candidate).existsSync()) return candidate;
  }
  // Practically unreachable — 998 same-named imports — but a path is still
  // owed rather than a crash.
  return '$libraryPath${Platform.pathSeparator}$baseName '
      '(${DateTime.now().microsecondsSinceEpoch})';
}
