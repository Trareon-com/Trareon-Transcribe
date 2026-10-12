/// "Tanya Langsung" (Sprint 21): ask a question about the meeting while
/// it is still being recorded, answered from the transcript so far.
///
/// Trareon's F12 ("Tanya Arsip Rapat") answers from every *past* meeting
/// once it is indexed. This answers from the *current* one, live, which
/// is the differentiator `docs/COMPETITOR-RESEARCH.md` §1.18 describes —
/// and unlike the competitor it describes, it works in Bahasa Indonesia.
/// Only shown while a session is actively recording: a transcript that
/// has stopped growing is exactly what the archive is for.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/live_qa.dart' as rust_live_qa;
import '../state/live_qa_model.dart';
import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../utils/format_time.dart';
import 'ui/app_field.dart';

class LiveQaPanel extends ConsumerStatefulWidget {
  const LiveQaPanel({super.key, required this.segments, this.trailing});

  /// The live transcript as currently held by the recording session.
  /// Read at the moment "Tanya" is pressed — a snapshot, not re-read as
  /// the transcript keeps growing underneath an in-flight question.
  final List<TranscriptSegment> segments;

  /// An optional control placed at the end of the header row — see
  /// `PersonalNotesPanel.trailing`, which this mirrors so the tab
  /// switcher looks the same regardless of which panel is showing.
  final Widget? trailing;

  @override
  ConsumerState<LiveQaPanel> createState() => _LiveQaPanelState();
}

class _LiveQaPanelState extends ConsumerState<LiveQaPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit() {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    _controller.clear();
    ref.read(liveQaProvider.notifier).ask(question, widget.segments).then((
      _,
    ) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final state = ref.watch(liveQaProvider);
    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              Spacing.xs,
            ),
            child: Row(
              children: [
                Icon(AppIcons.chat, size: IconSizes.sm, color: colors.primary),
                Spacing.hSm,
                Expanded(
                  child: Text(
                    'Tanya Langsung',
                    style: AppText.bodyStrong.c(colors.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
          Expanded(
            child: state.turns.isEmpty
                ? _EmptyHint(colors: colors)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                    ),
                    itemCount: state.turns.length,
                    itemBuilder: (_, index) =>
                        _TurnView(turn: state.turns[index], colors: colors),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _controller,
                    enabled: !state.busy,
                    onSubmitted: (_) => _submit(),
                    reserveHelperSpace: false,
                    placeholder: 'Tanyakan sesuatu tentang rapat ini…',
                  ),
                ),
                Spacing.hSm,
                FilledButton.icon(
                  onPressed: state.busy ? null : _submit,
                  icon: state.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.enhance, size: IconSizes.md),
                  label: const Text('Tanya'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.colors});

  final AppColorSet colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.chat, size: IconSizes.hero, color: colors.textTertiary),
            Spacing.gapMd,
            Text(
              'Tanyakan apa saja yang sudah dibahas di rapat ini sejauh ini.',
              textAlign: TextAlign.center,
              style: AppText.body.c(colors.text),
            ),
            Spacing.gapSm,
            Text(
              'Jawaban dikirim ke endpoint ringkasan yang Anda atur di '
              'Pengaturan → Ringkasan AI, dan dicatat di Laporan Privasi.',
              textAlign: TextAlign.center,
              style: AppText.caption.c(colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn, required this.colors});

  final LiveQaTurn turn;
  final AppColorSet colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Spacing.gapSm,
        Text(
          turn.question,
          style: AppText.bodyStrong.c(colors.text),
        ),
        Spacing.gapXs,
        if (turn.error != null)
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.12),
              borderRadius: Radii.smAll,
            ),
            child: Text(turn.error!, style: AppText.caption.c(colors.text)),
          )
        else if (turn.answer.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              turn.answer,
              style: AppText.body.c(colors.text).copyWith(height: 1.5),
            ),
          ),
        if (turn.sources.isNotEmpty) ...[
          Spacing.gapSm,
          Text(
            'Kutipan transkrip',
            style: AppText.caption.c(colors.textTertiary).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final entry in turn.sources.asMap().entries)
            _SourceRow(index: entry.key + 1, hit: entry.value, colors: colors),
        ],
        const Divider(height: Spacing.lg),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.index, required this.hit, required this.colors});

  final int index;
  final rust_live_qa.LiveQaHit hit;
  final AppColorSet colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '[K$index]',
              style: AppText.micro.c(colors.primary).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatTimestamp(hit.timestamp)} · ${hit.speaker}',
                  style: AppText.micro.c(colors.primary),
                ),
                Text(
                  hit.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.c(colors.textSecondary).copyWith(
                    height: 1.35,
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
