/// Preflight diagnostics, as the app sees them.
///
/// `doctor.rs` has existed since the first release and never ran: nothing
/// in `lib/` called it, so the one thing that could answer "why did my
/// recording come out empty?" was unreachable (audit A.0-2, item 19).
///
/// This wraps the generated binding with the two things the UI needs and
/// the binding does not have: a `try/catch` (a preflight that throws must
/// not be what stops the app from starting) and Indonesian titles for the
/// machine-readable check names.
library;

import '../src/rust/api.dart' as rust_api;
import '../src/rust/doctor.dart';

/// Human-readable name for each check `doctor.rs` runs.
const Map<String, String> kCheckTitles = {
  'library_path': 'Folder penyimpanan',
  'model': 'Model transkripsi',
  'config_dir': 'Folder pengaturan',
  'audio_input': 'Perangkat mikrofon',
  'disk_space': 'Ruang disk',
};

/// One-line explanation of why the check exists, shown under its title so
/// the screen teaches rather than just reports.
const Map<String, String> kCheckPurposes = {
  'library_path': 'Tempat rekaman dan transkrip disimpan.',
  'model': 'Berkas model yang dipakai untuk mengubah suara jadi teks.',
  'config_dir': 'Tempat pengaturan aplikasi disimpan.',
  'audio_input': 'Sumber suara untuk merekam.',
  'disk_space': 'Rekaman tiga jam butuh sekitar 1,4 GB.',
};

String checkTitle(String name) => kCheckTitles[name] ?? name;

String checkPurpose(String name) => kCheckPurposes[name] ?? '';

enum PreflightSeverity { ok, warn, fail }

PreflightSeverity severityOf(Check check) => switch (check.status) {
      CheckStatus_Ok() => PreflightSeverity.ok,
      CheckStatus_Warn() => PreflightSeverity.warn,
      CheckStatus_Fail() => PreflightSeverity.fail,
    };

/// The check's own message, or an empty string when it passed.
String messageOf(Check check) => switch (check.status) {
      CheckStatus_Ok() => '',
      CheckStatus_Warn(:final field0) => field0,
      CheckStatus_Fail(:final field0) => field0,
    };

/// Marker shown next to each row: ✓ / ! / ✗.
String markerOf(Check check) => switch (severityOf(check)) {
      PreflightSeverity.ok => '✓',
      PreflightSeverity.warn => '!',
      PreflightSeverity.fail => '✗',
    };

/// Outcome of a preflight run, including the case where the run itself
/// failed — which is information, not a reason to crash.
class PreflightResult {
  final List<Check> checks;

  /// Set when `run_preflight_checks` itself threw. The app still starts.
  final String? error;

  const PreflightResult(this.checks, {this.error});

  bool get hasFailures =>
      checks.any((c) => severityOf(c) == PreflightSeverity.fail);

  bool get hasWarnings =>
      checks.any((c) => severityOf(c) == PreflightSeverity.warn);

  List<Check> get failures =>
      checks.where((c) => severityOf(c) == PreflightSeverity.fail).toList();

  List<Check> get warnings =>
      checks.where((c) => severityOf(c) == PreflightSeverity.warn).toList();
}

/// Runs the engine's preflight checks. Never throws.
Future<PreflightResult> runPreflight() async {
  try {
    return PreflightResult(await rust_api.runPreflightChecks());
  } catch (e) {
    return PreflightResult(const [], error: '$e');
  }
}

/// Short summary for a banner: "Mikrofon, Ruang disk".
String summariseNames(List<Check> checks) =>
    checks.map((c) => checkTitle(c.name)).join(', ');
