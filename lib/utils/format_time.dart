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

/// Coarse Indonesian duration for list rows and summaries: "1 jam 32 menit",
/// "4 menit", "12 detik". Reads better than `1:32:07` where the exact
/// second carries no information.
String formatDurationId(double seconds) {
  if (seconds < 1) return '0 detik';
  final d = Duration(milliseconds: (seconds * 1000).round());
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes > 0 ? '$hours jam $minutes menit' : '$hours jam';
  }
  if (minutes > 0) return '$minutes menit';
  return '${d.inSeconds} detik';
}
