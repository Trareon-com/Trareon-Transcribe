/// Temp-file-plus-rename writes for everything Dart persists.
///
/// Rust already wrote atomically in both places it mattered; every Dart
/// write was `writeAsString` in place — the transcript the player saves
/// after each edit, the metadata sidecar that holds the only copy of the
/// summary, and the prefs file. A crash, a full disk or a power cut
/// during any of those left a truncated file where a valid one used to be,
/// and the edit that triggered the write took the old contents with it.
library;

import 'dart:convert';
import 'dart:io';

/// Writes [contents] to [target] so that a reader either sees the previous
/// file or the complete new one, never a half-written mixture.
///
/// The temp file is created **in the same directory** as [target]: `rename`
/// is only atomic within a filesystem, and a system temp directory is
/// routinely on a different one.
///
/// Throws on failure — the point of this exercise is that callers stop
/// swallowing write errors, so this does not swallow them either.
Future<void> writeStringAtomic(File target, String contents) async {
  // Explicitly UTF-8, not the platform encoding: a transcript is full of
  // non-ASCII and must round-trip identically on all three platforms.
  await writeBytesAtomic(target, utf8.encode(contents));
}

/// As [writeStringAtomic], for binary payloads.
Future<void> writeBytesAtomic(File target, List<int> bytes) async {
  final directory = target.parent;
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  // The pid keeps two processes (or a crashed previous run) from fighting
  // over the same temp name; it is removed on every path out of here.
  final temp = File('${target.path}.$pid.tmp');
  try {
    final handle = await temp.open(mode: FileMode.writeOnly);
    try {
      await handle.writeFrom(bytes);
      // Without this the rename can land before the data does, which on a
      // power cut yields a correctly-named, empty file — the worst of both
      // outcomes.
      await handle.flush();
    } finally {
      await handle.close();
    }
    await temp.rename(target.path);
  } catch (_) {
    if (await temp.exists()) {
      try {
        await temp.delete();
      } catch (_) {
        // Best effort: the throw below is the thing the caller needs.
      }
    }
    rethrow;
  }
}
