/// "Pratinjau penyamaran" (F13): what redaction would change, before the
/// file is written.
///
/// Redaction that happens invisibly is indistinguishable from a bug. A
/// notulis who exports a document and finds "[NOMOR REKENING]" where the
/// budget figure was has no way to tell whether the feature worked or
/// mangled their minutes — so every match is listed, by category, with
/// the text it would replace and the line it came from.
library;

import 'package:flutter/material.dart';

import '../services/bridge_service.dart';
import '../src/rust/api.dart' as rust_api;
import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_icons.dart';

Future<void> showRedactionPreview(
  BuildContext context, {
  required List<TranscriptSegment> segments,
  required RedactionConfig config,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: RedactionPreview(segments: segments, config: config),
    ),
  );
}

class RedactionPreview extends StatefulWidget {
  const RedactionPreview({
    super.key,
    required this.segments,
    required this.config,
    this.matches,
  });

  final List<TranscriptSegment> segments;
  final RedactionConfig config;

  /// Supplied by tests; `null` asks the engine.
  final List<PiiMatch>? matches;

  @override
  State<RedactionPreview> createState() => _RedactionPreviewState();
}

class _RedactionPreviewState extends State<RedactionPreview> {
  List<PiiMatch>? _matches;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.matches != null) {
      _matches = widget.matches;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final matches = await rust_api.previewRedactionSegments(
        segments: widget.segments.map(toRustSegment).toList(),
        config: widget.config,
      );
      if (mounted) setState(() => _matches = matches);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final matches = _matches;
    return SizedBox(
      width: 640,
      height: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Icon(AppIcons.hide, color: colors.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Pratinjau penyamaran',
                      style: TextStyle(
                        fontSize: FontSizes.title,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          if (matches != null && matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                0,
                Spacing.md,
                Spacing.sm,
              ),
              child: Text(
                redactionSummary(matches),
                style: TextStyle(
                  fontSize: FontSizes.caption,
                  color: colors.text,
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: switch ((matches, _error)) {
              (_, final String error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Text(
                    'Pratinjau gagal: $error',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
              (null, _) => const Center(child: CircularProgressIndicator()),
              (final List<PiiMatch> list, _) when list.isEmpty => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Text(
                    'Tidak ada data pribadi yang terdeteksi. File hasil '
                    'ekspor akan sama persis dengan transkrip.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textTertiary),
                  ),
                ),
              ),
              (final List<PiiMatch> list, _) => ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final match = list[index];
                  return ListTile(
                    dense: true,
                    leading: Chip(
                      label: Text(
                        piiKindLabel(match.kind),
                        style: const TextStyle(fontSize: FontSizes.micro),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: match.text,
                            style: TextStyle(
                              color: colors.error,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const TextSpan(text: '  →  '),
                          TextSpan(
                            text: match.replacement,
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: FontSizes.body,
                        color: colors.text,
                      ),
                    ),
                  );
                },
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// "3 NIK, 1 alamat email akan disamarkan." — the one-line count.
String redactionSummary(List<PiiMatch> matches) {
  if (matches.isEmpty) return 'Tidak ada yang akan disamarkan.';
  final counts = <String, int>{};
  for (final match in matches) {
    final label = piiKindLabel(match.kind);
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final parts = counts.entries.map((e) => '${e.value} ${e.key}').toList()
    ..sort();
  return '${parts.join(', ')} akan disamarkan.';
}

String piiKindLabel(PiiKind kind) => switch (kind) {
  PiiKind.nik => 'NIK',
  PiiKind.npwp => 'NPWP',
  PiiKind.phone => 'Nomor telepon',
  PiiKind.email => 'Alamat email',
  PiiKind.bankAccount => 'Nomor rekening',
  PiiKind.name => 'Nama',
};
