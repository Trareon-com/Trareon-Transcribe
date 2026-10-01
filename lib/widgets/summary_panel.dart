import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/session_store.dart';
import '../state/models.dart';
import '../state/privacy_report_model.dart';
import '../state/settings_model.dart';
import '../state/summary_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'summary_template_editor.dart';

/// Editable AI summary for one session.
///
/// Collapsed by default so an un-summarised session looks exactly as it did
/// before this feature existed. Expanding it does not make a request — only
/// "Buat Ringkasan" does.
class SummaryPanel extends ConsumerStatefulWidget {
  const SummaryPanel({
    super.key,
    required this.sessionDirPath,
    required this.segments,
    this.initialMeta = SessionMeta.empty,
    this.onSummaryChanged,
    this.bookmarks = const [],
  });

  /// Markers the notulis dropped during the meeting. Passed to the model as a
  /// "prioritise these" block after the transcript, so a three-hour meeting
  /// cannot truncate away the moments the user explicitly flagged.
  final List<Bookmark> bookmarks;

  /// Directory the sidecar is written to.
  final String sessionDirPath;

  /// Transcript to summarise. Read at generate time, so later edits count.
  final List<TranscriptSegment> Function() segments;

  final SessionMeta initialMeta;

  /// Notified whenever the saved summary text changes, so the host screen can
  /// include it in an export without re-reading the sidecar.
  final ValueChanged<String>? onSummaryChanged;

  @override
  ConsumerState<SummaryPanel> createState() => _SummaryPanelState();
}

class _SummaryPanelState extends ConsumerState<SummaryPanel> {
  late final StateNotifierProvider<SummaryNotifier, SummaryUiState> _provider;
  late final TextEditingController _controller;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMeta.summary);
    _expanded = widget.initialMeta.hasSummary;
    _provider = StateNotifierProvider<SummaryNotifier, SummaryUiState>((ref) {
      return SummaryNotifier(
        ref.read(rustBridgeProvider),
        widget.sessionDirPath,
        initialMeta: widget.initialMeta,
        onNetworkRequest: (endpoint) => ref
            .read(privacyReportProvider.notifier)
            .recordSummaryRequest(endpoint),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final settings = ref.read(settingsProvider);
    await ref.read(_provider.notifier).generate(
          segments: widget.segments(),
          settings: settings,
          bookmarks: widget.bookmarks,
        );
    if (!mounted) return;
    final generated = ref.read(_provider).text;
    if (generated.isNotEmpty && generated != _controller.text) {
      _controller.text = generated;
      widget.onSummaryChanged?.call(generated);
    }
  }

  Future<void> _save() async {
    await ref.read(_provider.notifier).save();
    if (!mounted) return;
    widget.onSummaryChanged?.call(ref.read(_provider).text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ringkasan tersimpan.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final state = ref.watch(_provider);
    final settings = ref.watch(settingsProvider);
    final busy = state.status == SummaryStatus.generating;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Ringkasan AI',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (state.status == SummaryStatus.ready) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, size: 14, color: colors.primary),
                  ],
                  if (state.dirty) ...[
                    const SizedBox(width: 6),
                    Text(
                      'belum disimpan',
                      style: TextStyle(color: colors.textTertiary, fontSize: 11),
                    ),
                  ],
                  const Spacer(),
                  if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!settings.summary.enabled)
                    _Notice(
                      icon: Icons.info_outline,
                      message:
                          'Ringkasan AI mati. Fitur ini satu-satunya yang memakai '
                          'jaringan — nyalakan di Pengaturan → Ringkasan AI bila '
                          'ingin memakainya.',
                      color: colors.textSecondary,
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // The value space is "built-in name or template
                            // id", because a user template is also a choice
                            // in this one picker — two pickers for one
                            // decision is worse than a prefixed key.
                            initialValue: state.customTemplateId ??
                                state.template.name,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: 'Template',
                              helperText: state.customTemplateId != null
                                  ? 'Template buatan sendiri'
                                  : summaryTemplateHint(state.template),
                              helperMaxLines: 2,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items: [
                              for (final t in SummaryTemplate.values)
                                DropdownMenuItem(
                                  value: t.name,
                                  child: Text(summaryTemplateLabel(t)),
                                ),
                              for (final custom in settings.summaryTemplates)
                                DropdownMenuItem(
                                  value: custom.id,
                                  child: Text('★ ${custom.name}'),
                                ),
                            ],
                            onChanged: busy
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    final builtin = SummaryTemplate.values
                                        .where((t) => t.name == value)
                                        .firstOrNull;
                                    final notifier =
                                        ref.read(_provider.notifier);
                                    if (builtin != null) {
                                      notifier.setTemplate(builtin);
                                    } else {
                                      notifier.setCustomTemplate(value);
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        IconButton(
                          tooltip: 'Kelola template ringkasan',
                          constraints: TouchTarget.constraints,
                          icon: const Icon(Icons.tune, size: IconSizes.md),
                          onPressed: busy
                              ? null
                              : () => showSummaryTemplateManager(context),
                        ),
                        const SizedBox(width: Spacing.sm),
                        FilledButton.icon(
                          onPressed: busy ? null : _generate,
                          icon: Icon(
                            state.status == SummaryStatus.ready
                                ? Icons.refresh
                                : Icons.auto_awesome,
                            size: 16,
                          ),
                          label: Text(
                            state.status == SummaryStatus.ready
                                ? 'Buat Ulang'
                                : 'Buat Ringkasan',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      maxLines: 12,
                      minLines: 5,
                      readOnly: busy,
                      onChanged: ref.read(_provider.notifier).edit,
                      style: const TextStyle(fontSize: 13, height: 1.45),
                      decoration: const InputDecoration(
                        hintText:
                            'Ringkasan akan muncul di sini. Anda bisa menyuntingnya '
                            'sebelum menyimpan.',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: state.text.trim().isEmpty
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: state.text),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ringkasan disalin.'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.copy_outlined, size: 16),
                          label: const Text('Salin'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: state.dirty && !busy ? _save : null,
                          icon: const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Simpan'),
                        ),
                      ],
                    ),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 8),
                    _Notice(
                      icon: Icons.error_outline,
                      message: state.error!,
                      color: colors.error,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color, fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }
}
