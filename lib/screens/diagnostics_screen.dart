import 'package:flutter/material.dart';

import '../services/preflight_service.dart';
import '../theme/app_colors.dart';

/// "Diagnostik" — runs `doctor.rs` on demand and says, in Indonesian, what
/// is wrong and what to do about it.
///
/// The engine has been able to answer these questions since the first
/// release; until now nothing in the app asked (audit A.0-2).
class DiagnosticsScreen extends StatefulWidget {
  /// Injectable so the widget test does not need the native library.
  final Future<PreflightResult> Function()? runChecks;

  const DiagnosticsScreen({super.key, this.runChecks});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  PreflightResult? _result;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    final result = await (widget.runChecks ?? runPreflight)();
    if (!mounted) return;
    setState(() {
      _result = result;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Periksa ulang'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pemeriksaan ini berjalan sepenuhnya di komputer Anda dan tidak '
            'mengirim apa pun ke internet.',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            Text(
              result.hasFailures
                  ? 'Ada masalah yang perlu diperbaiki sebelum merekam.'
                  : result.hasWarnings
                      ? 'Aplikasi bisa dipakai, tapi ada hal yang sebaiknya '
                          'diperiksa.'
                      : 'Semua siap. Aplikasi bisa merekam.',
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                marker,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                  if (remediation != null && remediation!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            remediation!,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 12,
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
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen()),
  );
}

