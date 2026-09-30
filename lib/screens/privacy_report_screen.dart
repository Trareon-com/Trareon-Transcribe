import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/privacy_report_model.dart';
import '../theme/app_colors.dart';

class PrivacyReportScreen extends ConsumerStatefulWidget {
  const PrivacyReportScreen({super.key});

  @override
  ConsumerState<PrivacyReportScreen> createState() => _PrivacyReportScreenState();
}

class _PrivacyReportScreenState extends ConsumerState<PrivacyReportScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(privacyReportProvider);
    final elapsed = DateTime.now().difference(report.launchedAt);
    final isClean = report.networkCallCount == 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: isClean ? AppColors.micAccent.withValues(alpha: 0.1) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isClean ? Icons.verified_user_outlined : Icons.warning_amber_outlined,
                    color: isClean ? AppColors.micAccent : AppColors.warning,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${report.networkCallCount} network calls since launch',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('Sesi berjalan selama ${_formatDuration(elapsed)}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trareon Transcribe tidak melakukan panggilan jaringan apa pun selama transkripsi '
            'berlangsung — baik live capture maupun upload berkas. Audio tidak pernah keluar '
            'dari perangkat ini.\n\n'
            'Hanya ada dua aktivitas jaringan yang sah, dan keduanya Anda mulai sendiri:\n'
            '1. Unduh model whisper yang Anda pilih.\n'
            '2. Ringkasan AI — mengirim teks transkrip (bukan audio) ke endpoint yang Anda '
            'atur sendiri. Fitur ini mati secara bawaan dan defaultnya menunjuk ke Ollama '
            'di komputer ini (localhost), jadi bawaannya pun tidak keluar dari perangkat.\n\n'
            'Setiap permintaan ringkasan tercatat di riwayat di bawah, lengkap dengan '
            'endpoint tujuannya.',
          ),
          const SizedBox(height: 16),
          if (report.events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada aktivitas jaringan tercatat.'),
            )
          else ...[
            Text('Riwayat aktivitas:', style: Theme.of(context).textTheme.titleSmall),
            for (final event in report.events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• $event'),
              ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}j ${m}m';
    if (m > 0) return '${m}m ${s}d';
    return '${s}d';
  }
}
