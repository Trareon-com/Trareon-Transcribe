/// Quick-share (F21): hands a freshly exported file to the platform share
/// sheet instead of leaving the user to go find it in a file manager.
///
/// `share_plus`'s Linux backend throws `UnimplementedError` for any share
/// that includes a file — there is no native share sheet on Linux desktop
/// to hand it to. Rather than let that surface as a crash or a silent
/// no-op, [shareExportedFile] falls back to copying the path to the
/// clipboard, with a toast that says exactly what happened so the fallback
/// never reads as the real thing.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/app_toast.dart';

/// Platforms `share_plus`'s own backend refuses to hand a file to — see
/// `share_plus_linux.dart`, which throws `UnimplementedError` for any
/// `ShareParams.files` on Linux desktop. Checked *before* calling the
/// plugin, not via try/catch: the Linux backend goes through
/// `url_launcher_linux`, which in a test sandbox with no real desktop
/// session does not throw promptly — it hangs, taking the whole suite
/// down with it. A platform check has no such failure mode.
bool get _platformSupportsFileShare => !Platform.isLinux;

/// Shares [path] via the platform share sheet, subject [subject].
///
/// On platforms without file-sharing support (Linux desktop today), falls
/// back to copying the path to the clipboard and tells the user so via a
/// toast — it never claims the file was shared when it was only copied.
///
/// [copyToClipboard] defaults to the real `Clipboard.setData` and exists
/// as a seam for tests: the clipboard's platform channel hangs rather
/// than failing fast in a sandboxed/headless test runner with no desktop
/// clipboard to talk to, which is exactly the kind of failure a widget
/// test cannot recover from.
Future<void> shareExportedFile(
  BuildContext context,
  String path, {
  String? subject,
  Future<void> Function(String path)? copyToClipboard,
}) async {
  if (_platformSupportsFileShare) {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: subject),
      );
      return;
    } catch (_) {
      // Fall through to the clipboard fallback below.
    }
  }
  // No native share sheet to hand the file to — give the user the next
  // best thing: the path, ready to paste into a chat or file manager.
  if (!context.mounted) return;
  await (copyToClipboard ?? _copyToClipboard)(path);
  if (!context.mounted) return;
  AppToast.show(
    context,
    'Berbagi file tidak didukung di platform ini. '
    'Path disalin: ${File(path).uri.pathSegments.last}',
  );
}

Future<void> _copyToClipboard(String path) =>
    Clipboard.setData(ClipboardData(text: path));
