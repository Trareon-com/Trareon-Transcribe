import 'dart:async';

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
import '../theme/app_typography.dart';
import '../utils/format_time.dart';
import 'summary_template_editor.dart';
import '../theme/app_icons.dart';
import 'app_toast.dart';
import 'ui/app_button.dart';
import 'ui/app_feedback.dart';
import 'ui/app_field.dart';
import 'ui/app_surface.dart';
import 'ui/interactive.dart';

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
    this.provider,
    this.onSeekToTimestamp,
  });

  /// The session's summary notifier, when the host screen owns it.
  ///
  /// The checklist panel (F6) renders from the same state, so somebody
  /// above both of them has to hold it. Null keeps the old behaviour of
  /// making one here, which is what the panel's own tests use.
  final StateNotifierProvider<SummaryNotifier, SummaryUiState>? provider;

  /// Jumps the player to a cited moment (F7). Null hides the citation
  /// chips rather than rendering buttons that do nothing.
  final void Function(double seconds)? onSeekToTimestamp;

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

  /// True while the user is editing the Markdown by hand. The rendered
  /// view with its citation links is the default once there is anything
  /// to cite — the links are the point of F7.
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMeta.summary);
    _expanded = widget.initialMeta.hasSummary;
    _provider =
        widget.provider ??
        StateNotifierProvider<SummaryNotifier, SummaryUiState>((ref) {
          return SummaryNotifier(
            ref.read(rustBridgeProvider),
            widget.sessionDirPath,
            initialMeta: widget.initialMeta,
            onNetworkRequest: (endpoint) => ref
                .read(privacyReportProvider.notifier)
                .recordSummaryRequest(endpoint),
          );
        });
    // A session reopened with a saved summary should show its citations
    // without the user having to regenerate it.
    if (widget.initialMeta.hasSummary) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref.read(_provider.notifier).refreshProvenance(widget.segments()),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final settings = ref.read(settingsProvider);
    await ref
        .read(_provider.notifier)
        .generate(
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
    AppToast.show(context, 'Ringkasan tersimpan.', type: ToastType.success);
  }

  /// Whether there is a citation-bearing rendering to offer at all.
  bool _canRender(SummaryUiState state) {
    final provenance = state.provenance;
    if (provenance == null || provenance.lines.isEmpty) return false;
    return provenance.lines.any((line) => line.citations.isNotEmpty);
  }

  bool _showRendered(SummaryUiState state) => _canRender(state) && !_editing;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
          Interactive(
            onPressed: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.zero,
            semanticLabel: 'Ringkasan AI',
            toggled: _expanded,
            builder: (context, interaction) => Container(
              color: interactionTint(context, interaction),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.enhance,
                    size: IconSizes.md,
                    color: colors.primary,
                  ),
                  Spacing.hSm,
                  Text(
                    'Ringkasan AI',
                    style: AppText.subheading.c(colors.text),
                  ),
                  if (state.status == SummaryStatus.ready) ...[
                    Spacing.hSm,
                    Icon(
                      AppIcons.checkFilled,
                      size: IconSizes.xs,
                      color: colors.primary,
                    ),
                  ],
                  if (state.dirty) ...[
                    Spacing.hSm,
                    Text(
                      'belum disimpan',
                      style: AppText.micro.c(colors.textTertiary),
                    ),
                  ],
                  const Spacer(),
                  if (busy)
                    const AppProgressRing(size: IconSizes.md)
                  else
                    Icon(
                      _expanded ? AppIcons.expandLess : AppIcons.expandMore,
                      size: IconSizes.lg,
                      color: colors.textSecondary,
                    ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                0,
                Spacing.lg,
                Spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!settings.summary.enabled)
                    _Notice(
                      icon: AppIcons.info,
                      message:
                          'Ringkasan AI mati. Fitur ini satu-satunya yang memakai '
                          'jaringan, nyalakan di Pengaturan, Ringkasan AI, bila '
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
                            initialValue:
                                state.customTemplateId ?? state.template.name,
                            isDense: true,
                            style: AppText.body.c(colors.text),
                            decoration: InputDecoration(
                              labelText: 'Template',
                              helperText: state.customTemplateId != null
                                  ? 'Template buatan sendiri'
                                  : summaryTemplateHint(state.template),
                              helperMaxLines: 2,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: Spacing.sm,
                                vertical: Spacing.sm,
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
                                    final notifier = ref.read(
                                      _provider.notifier,
                                    );
                                    if (builtin != null) {
                                      notifier.setTemplate(builtin);
                                    } else {
                                      notifier.setCustomTemplate(value);
                                    }
                                  },
                          ),
                        ),
                        Spacing.hSm,
                        AppIconButton(
                          tooltip: 'Kelola template ringkasan',
                          icon: AppIcons.tune,
                          onPressed: busy
                              ? null
                              : () => showSummaryTemplateManager(context),
                        ),
                        Spacing.hSm,
                        AppButton.primary(
                          onPressed: busy ? null : _generate,
                          loading: busy,
                          icon: state.status == SummaryStatus.ready
                              ? AppIcons.refresh
                              : AppIcons.enhance,
                          label: state.status == SummaryStatus.ready
                              ? 'Buat Ulang'
                              : 'Buat Ringkasan',
                        ),
                      ],
                    ),
                    if (state.progress != null) ...[
                      Spacing.gapSm,
                      // F15: a three-hour meeting is many round trips, and
                      // a panel that shows nothing for twenty minutes reads
                      // as a hang rather than as work in progress.
                      _MapReduceProgress(
                        progress: state.progress!,
                        colors: colors,
                      ),
                    ],
                    Spacing.gapSm,
                    if (_showRendered(state))
                      _CitedSummary(
                        provenance: state.provenance!,
                        colors: colors,
                        onSeekToTimestamp: widget.onSeekToTimestamp,
                      )
                    else
                      AppTextField(
                        controller: _controller,
                        maxLines: 12,
                        minLines: 5,
                        enabled: !busy,
                        reserveHelperSpace: false,
                        onChanged: ref.read(_provider.notifier).edit,
                        placeholder:
                            'Ringkasan akan muncul di sini. Anda bisa '
                            'menyuntingnya sebelum menyimpan.',
                      ),
                    if (state.droppedCitations > 0) ...[
                      Spacing.gapSm,
                      // Surfaced rather than swallowed: a summary with
                      // many invalid citations came from a model that is
                      // guessing, and that is worth knowing before the
                      // notulen is signed.
                      _Notice(
                        icon: AppIcons.report,
                        message:
                            '${state.droppedCitations} rujukan dibuang karena '
                            'tidak cocok dengan transkrip. Periksa ringkasan '
                            'ini lebih teliti.',
                        color: colors.textSecondary,
                      ),
                    ],
                    Spacing.gapSm,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_canRender(state))
                          AppButton.ghost(
                            onPressed: () =>
                                setState(() => _editing = !_editing),
                            icon: _editing ? AppIcons.show : AppIcons.edit,
                            label: _editing ? 'Lihat rujukan' : 'Sunting',
                          ),
                        AppButton.ghost(
                          onPressed: state.text.trim().isEmpty
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: state.text),
                                  );
                                  if (!context.mounted) return;
                                  AppToast.show(
                                    context,
                                    'Ringkasan disalin.',
                                    type: ToastType.success,
                                  );
                                },
                          icon: AppIcons.copy,
                          label: 'Salin',
                        ),
                        Spacing.hSm,
                        AppButton(
                          onPressed: state.dirty && !busy ? _save : null,
                          icon: AppIcons.save,
                          label: 'Simpan',
                        ),
                      ],
                    ),
                  ],
                  if (state.error != null) ...[
                    Spacing.gapSm,
                    _Notice(
                      icon: AppIcons.error,
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
        Icon(icon, size: IconSizes.sm, color: color),
        Spacing.hSm,
        Expanded(child: Text(message, style: AppText.caption.c(color))),
      ],
    );
  }
}

/// A summary rendered line by line, each claim followed by the transcript
/// moments it came from (F7).
///
/// The citation is a button, not a footnote: a summary bullet you can
/// check in one tap is a different thing from one you have to trust.
class _CitedSummary extends StatelessWidget {
  const _CitedSummary({
    required this.provenance,
    required this.colors,
    this.onSeekToTimestamp,
  });

  final SummaryProvenance provenance;
  final AppColorSet colors;
  final void Function(double seconds)? onSeekToTimestamp;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      radius: Radii.mdAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in provenance.lines)
            Padding(
              padding: EdgeInsets.only(
                bottom: line.isHeading ? Spacing.xs : Spacing.sm - 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.text,
                    style: line.isHeading
                        ? AppText.bodyStrong.c(colors.text)
                        : AppText.reading.c(colors.text),
                  ),
                  if (line.citations.isNotEmpty && onSeekToTimestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.xs),
                      child: Wrap(
                        spacing: Spacing.xs,
                        children: [
                          for (final citation in line.citations)
                            _CitationChip(
                              citation: citation,
                              colors: colors,
                              onTap: () =>
                                  onSeekToTimestamp!(citation.timestamp),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({
    required this.citation,
    required this.colors,
    required this.onTap,
  });

  final Citation citation;
  final AppColorSet colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = formatTimestamp(citation.timestamp);
    return Interactive(
      onPressed: onTap,
      borderRadius: Radii.smAll,
      semanticLabel: 'Putar segmen ${citation.segmentId} pada $label',
      builder: (context, interaction) => Container(
        decoration: BoxDecoration(
          color: interaction.active ? colors.primarySubtle : Colors.transparent,
          borderRadius: Radii.smAll,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        child: Text(
          label,
          style: AppText.monoMicro.cw(colors.primary, FontWeight.w600),
        ),
      ),
    );
  }
}

/// "Bagian 3 dari 10 — 20:00–30:00", while a long meeting is reduced.
class _MapReduceProgress extends StatelessWidget {
  const _MapReduceProgress({required this.progress, required this.colors});

  final MapReduceProgress progress;
  final AppColorSet colors;

  @override
  Widget build(BuildContext context) {
    final total = progress.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(progress.label, style: AppText.caption.c(colors.textSecondary)),
        Spacing.gapXs,
        AppLinearProgress(
          // An unknown total must not render as a full bar.
          value: total > 0 ? (progress.done / total).clamp(0.0, 1.0) : null,
          semanticLabel: progress.label,
        ),
      ],
    );
  }
}
