import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Asks the user where to save [fileName] and returns the chosen path, or
/// `null` when they cancel.
///
/// Since file_picker 12, `FilePicker.saveFile()` no longer only picks a
/// path: it requires the file's bytes and writes them itself. Every save in
/// this app is written by someone else afterwards (Rust streams session
/// archives and diagnostic bundles, `writeStringAtomic` writes the glossary),
/// and a session archive can be far too large to hold in memory, which the
/// plugin documents as unsafe. So the dialog is opened with zero bytes,
/// leaving an empty placeholder at the chosen path, and the real writer
/// replaces it. Callers that fail before writing should pass the path to
/// [discardEmptyPlaceholder].
///
/// Desktop only: every desktop platform returns a `file:` URI. Anything
/// else (a `content:` URI on Android) cannot be written to by path, so it
/// is treated as a cancel rather than handed to a writer that would fail.
Future<String?> pickSaveLocation({
  required String dialogTitle,
  required String fileName,
}) async {
  final uri = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    bytes: Uint8List(0),
  );
  if (uri == null || !uri.isScheme('file')) return null;
  return uri.toFilePath();
}

/// Removes the empty file [pickSaveLocation] left at [path] when the real
/// write never happened, so a failed export does not leave a 0-byte file the
/// user might mistake for a valid one. A non-empty file is left alone.
Future<void> discardEmptyPlaceholder(String path) async {
  try {
    final file = File(path);
    if (await file.exists() && await file.length() == 0) {
      await file.delete();
    }
  } on FileSystemException {
    // Best effort: the export error is what the user needs to see.
  }
}

/// Asks the user for a folder and returns its path, or `null` on cancel.
///
/// file_picker 13 deprecated `getDirectoryPath()` for `pickDirectory()`,
/// which returns a `Uri` because an Android path is often unreadable. On
/// desktop the URI is always `file:`, so this converts it back to the path
/// every caller here hands to Rust. A directory URI may end in a slash
/// (`file:///Users/a/Rekaman/`); it is trimmed so a path compared against
/// a saved setting still matches.
Future<String?> pickDirectoryPath({
  String? dialogTitle,
  String? initialDirectory,
}) async {
  final uri = await FilePicker.pickDirectory(
    dialogTitle: dialogTitle,
    initialDirectory: initialDirectory,
  );
  if (uri == null || !uri.isScheme('file')) return null;
  final path = uri.toFilePath();
  final sep = Platform.pathSeparator;
  if (path.length > 1 && path.endsWith(sep) && !path.endsWith(':$sep')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}
