import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/flight_recorder_service.dart';
import '../services/preflight_service.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_toast.dart';
import '../theme/app_icons.dart';

/// "Diagnostik" — runs `doctor.rs` on demand and says, in Indonesian, what
/// is wrong and what to do about it.
///
/// The engine has been able to answer these questions since the first
/// release; until now nothing in the app asked (audit A.0-2).
class DiagnosticsScreen extends ConsumerStatefulWidget {
  /// Injectable so the widget test does not need the native library.
  final Future<PreflightResult> Function()? runChecks;

  const DiagnosticsScreen({super.key, this.runChecks});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  PreflightResult? _result;
  bool _running = true;
  bool _exporting = false;

  /// How many log files an export would carry. `null` until asked.
  int? _logFiles;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    final result = await (widget.runChecks ?? runPreflight)();
    final logFiles = await FlightRecorder.instance.logFileCount();
    if (!mounted) return;
    setState(() {
      _result = result;
      _logFiles = logFiles;
      _running = false;
    });
  }

  /// Packs the rotating logs plus this run's doctor report into one `.zip`.
  ///
  /// The report text is formatted here rather than in Rust so the bundle says
  /// exactly what the user saw on screen.
  Future<void> _exportDiagnostics() async {
    final result = _result;
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan log diagnostik',
      fileName:
          'trareon-diagnostik-'
          '${DateTime.now().toIso8601String().substring(0, 10)}.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (destination == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final written = await ref
          .read(rustBridgeProvider)
          .exportDiagnostics(
            destination: destination,
            doctorReport: _doctorReport(result),
            environment: environmentSummary(),
          );
      if (!mounted) return;
      setState(() => _exporting = false);
      AppToast.show(
        context,
        'Log diagnostik tersimpan: $written',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      AppToast.show(
        context,
        'Gagal menyimpan log diagnostik: $e',
        type: ToastType.error,
      );
    }
  }

  String _doctorReport(PreflightResult? result) {
    if (result == null) return 'Pemeriksaan belum dijalankan.';
    if (result.error != null) {
      return 'Pemeriksaan gagal dijalankan: ${result.error}';
    }
    return [
      for (final check in result.checks)
        '${markerOf(check)} ${check.name}: ${messageOf(check)}'
            '${(check.remediation ?? '').isEmpty ? '' : ' — ${check.remediation}'}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final result = _result;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        foregroundColor: colors.text,
        elevation: 0,
        title: const Text('Diagnostik'),
        actions: [
          TextButton.icon(
            onPressed: _running ? null : _run,
            icon: const Icon(AppIcons.refresh, size: IconSizes.md),
            label: const Text('Periksa ulang'),
          ),
          Spacing.hSm,
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          Text(
            'Pemeriksaan ini berjalan sepenuhnya di komputer Anda dan tidak '
            'mengirim apa pun ke internet.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: FontSizes.body,
            ),
          ),
          Spacing.gapLg,
          if (_running) const LinearProgressIndicator(minHeight: 2),
          if (result != null) ...[
            if (result.error != null)
              _DiagnosticCard(
                marker: '✗',
                color: colors.error,
                title: 'Pemeriksaan gagal dijalankan',
                message: result.error!,
                remediation:
                    'Mesin transkripsi mungkin tidak termuat. Tutup dan buka '
                    'ulang aplikasi; jika tetap gagal, pasang ulang Trareon.',
              )
            else if (result.checks.isEmpty)
              _DiagnosticCard(
                marker: '!',
                color: colors.textSecondary,
                title: 'Tidak ada pemeriksaan yang berjalan',
                message: 'Mesin tidak mengembalikan hasil apa pun.',
              )
            else
              for (final check in result.checks)
                _DiagnosticCard(
                  marker: markerOf(check),
                  color: switch (severityOf(check)) {
                    PreflightSeverity.ok => colors.success,
                    PreflightSeverity.warn => colors.warning,
                    PreflightSeverity.fail => colors.error,
                  },
                  title: checkTitle(check.name),
                  message: messageOf(check).isEmpty
                      ? checkPurpose(check.name)
                      : messageOf(check),
                  remediation: check.remediation,
                ),
            Spacing.gapMd,
            Text(
              result.hasFailures
                  ? 'Ada masalah yang perlu diperbaiki sebelum merekam.'
                  : result.hasWarnings
                  ? 'Aplikasi bisa dipakai, tapi ada hal yang sebaiknya '
                        'diperiksa.'
                  : 'Semua siap. Aplikasi bisa merekam.',
              style: TextStyle(
                color: colors.text,
                fontSize: FontSizes.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          // Last: exporting the log is what you do *after* reading the
          // checks, and it is also what goes into a bug report alongside them.
          Spacing.gapXl,
          _DiagnosticsExportCard(
            logFiles: _logFiles,
            busy: _exporting || _running,
            onExport: _exportDiagnostics,
          ),
        ],
      ),
    );
  }
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({
    required this.marker,
    required this.color,
    required this.title,
    required this.message,
    this.remediation,
  });

  final String marker;
  final Color color;
  final String title;
  final String message;
  final String? remediation;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              // "✓" / "!" / "✗" carry the severity visually; read aloud they
              // are a punctuation mark. The label says it in words.
              child: Semantics(
                label: switch (marker) {
                  '✓' => 'Baik',
                  '!' => 'Perlu diperiksa',
                  _ => 'Gagal',
                },
                excludeSemantics: true,
                child: Text(
                  marker,
                  style: TextStyle(
                    color: color,
                    fontSize: FontSizes.title,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: FontSizes.bodyLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    Spacing.gapXs,
                    Text(
                      message,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: FontSizes.caption,
                      ),
                    ),
                  ],
                  if (remediation != null && remediation!.isNotEmpty) ...[
                    Spacing.gapSm,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(AppIcons.idea, size: IconSizes.xs, color: color),
                        Spacing.hSm,
                        Expanded(
                          child: Text(
                            remediation!,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: FontSizes.caption,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience for the Settings tile.
Future<void> openDiagnostics(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen()));
}

/// "Ekspor Log Diagnostik" (audit item 27).
///
/// States plainly what goes into the bundle: a user asked to send logs to
/// strangers deserves to know the transcript is not in them.
class _DiagnosticsExportCard extends StatelessWidget {
  const _DiagnosticsExportCard({
    required this.logFiles,
    required this.busy,
    required this.onExport,
  });

  final int? logFiles;
  final bool busy;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: Radii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.bugReport,
            size: IconSizes.lg,
            color: colors.textSecondary,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log Diagnostik',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: FontSizes.bodyLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Satu berkas .zip berisi ${logFiles == null ? '' : '$logFiles '}'
                  'berkas log dan hasil pemeriksaan di atas. '
                  'Tidak berisi transkrip, audio, atau nama berkas rapat Anda.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: FontSizes.caption,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          FilledButton.icon(
            onPressed: busy ? null : () => onExport(),
            icon: busy
                ? const SizedBox(
                    width: IconSizes.sm,
                    height: IconSizes.sm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.download, size: IconSizes.md),
            label: const Text('Ekspor'),
          ),
        ],
      ),
    );
  }
}
