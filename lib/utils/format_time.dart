import '../l10n/l10n.dart';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Transcript-row timestamp, `[mm:ss]` or `[h:mm:ss]`.
///
/// The hour component used to be dropped, so in the three-hour meeting
/// this app is built for, minute 5 and minute 65 both rendered `[05:00]`.
String formatTimestamp(double seconds) {
  final d = Duration(milliseconds: (seconds * 1000).round());
  return '[${formatDuration(d)}]';
}

/// Coarse duration for list rows and summaries: "1 jam 32 menit",
/// "4 menit", "12 detik". Reads better than `1:32:07` where the exact
/// second carries no information. In the interface language.
String formatDurationId(double seconds) {
  final l10n = currentL10n;
  if (seconds < 1) return l10n.formatTimeSeconds(0);
  final d = Duration(milliseconds: (seconds * 1000).round());
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes > 0
        ? l10n.formatTimeHoursMinutes(hours, minutes)
        : l10n.formatTimeHours(hours);
  }
  if (minutes > 0) return l10n.formatTimeMinutes(minutes);
  return l10n.formatTimeSeconds(d.inSeconds);
}
