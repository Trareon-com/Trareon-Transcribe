/// Deep links into macOS's Privacy & Security settings panes (Sprint 12,
/// B6). A no-op everywhere else: these panes only exist on macOS.
library;

import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

enum PrivacyPermissionKind { microphone, screenCapture }

String _schemeFor(PrivacyPermissionKind kind) => switch (kind) {
  PrivacyPermissionKind.microphone =>
    'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
  PrivacyPermissionKind.screenCapture =>
    'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture',
};

/// Opens System Settings straight to the Microphone or Screen & System Audio
/// Recording privacy pane. Does nothing on non-macOS platforms.
///
/// [recordExternalLink] is `PrivacyReportNotifier.recordExternalLink` —
/// Trareon itself opens no socket here, but the user's machine does to
/// hand off to System Settings, and the Privacy Report would be misleading
/// if it omitted that handoff. Called before the handoff, not after:
/// `test/privacy_proof_test.dart` enforces every outbound request is
/// counted before it leaves.
Future<void> openPrivacySettings(
  PrivacyPermissionKind kind,
  void Function(String url) recordExternalLink,
) async {
  if (!Platform.isMacOS) return;
  final uri = Uri.parse(_schemeFor(kind));
  recordExternalLink(uri.toString());
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    // `x-apple.systempreferences:` URLs are not registered with
    // `url_launcher`'s scheme allow-list on every macOS version; `open`
    // is the same mechanism System Settings' own links use.
    await Process.run('open', [uri.toString()]);
  }
}
