/// "Tanya Arsip Rapat" (F12).
///
/// A question box over every meeting in the library. Two buttons, not
/// one, because they do genuinely different things and the difference
/// matters:
///
/// * **Cari** searches the local index. No network, no endpoint needed,
///   and the ranked passages are themselves an answer.
/// * **Jawab** additionally sends those passages to the configured
///   summary endpoint and shows a composed answer with `[K1]` links.
///
/// Every citation is a button that opens the meeting at the moment it
/// came from — an answer about what a meeting decided is only worth
/// having if you can check it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/library_index.dart';
import '../src/rust/archive.dart' as rust_archive;
import '../state/archive_chat_model.dart';
import '../state/library_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/format_time.dart';
import '../theme/app_icons.dart';

class ArchiveChatScreen extends ConsumerStatefulWidget {
  const ArchiveChatScreen({super.key, this.onOpenSession});

  /// Opens a session at a timestamp. Null in tests and wherever the
  /// player is not reachable.
  final void Function(String dirPath, double timestamp)? onOpenSession;

  @override
  ConsumerState<ArchiveChatScreen> createState() => _ArchiveChatScreenState();
}

class _ArchiveChatScreenState extends ConsumerState<ArchiveChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _reindexed = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _maybeReindex(List<LibraryEntry> entries) {
    if (_reindexed || entries.isEmpty) return;
    _reindexed = true;
    // Fire and forget: the user can search what is already indexed while
    // the rest catches up.
    ref.read(archiveChatProvider.notifier).reindex(entries);
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final state = ref.watch(archiveChatProvider);
    final notifier = ref.read(archiveChatProvider.notifier);
    final library = ref.watch(libraryListProvider);
    if (!library.loading) _maybeReindex(library.entries);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        foregroundColor: colors.text,
        elevation: 0,
        title: const Text(
          'Tanya Arsip Rapat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (state.turns.isNotEmpty)
            TextButton(
              onPressed: notifier.clear,
              child: const Text('Bersihkan'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.indexing)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: colors.surface,
            ),
          Expanded(
            child: state.turns.isEmpty
                ? _EmptyPrompt(colors: colors, sessions: library.entries.length)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(Spacing.md),
                    itemCount: state.turns.length,
                    itemBuilder: (_, index) => _TurnView(
                      turn: state.turns[index],
                      colors: colors,
                      onOpenSession: widget.onOpenSession,
                    ),
                  ),
          ),
          _Composer(
            controller: _controller,
            busy: state.busy,
            colors: colors,
            onSearch: () => _submit(notifier.search),
            onAsk: () => _submit(notifier.ask),
          ),
        ],
      ),
    );
  }

  void _submit(Future<void> Function(String) action) {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    _controller.clear();
    action(question).then((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({required this.colors, required this.sessions});

  final AppColorSet colors;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.chat,
              size: IconSizes.hero,
              color: colors.textTertiary,
            ),
            Spacing.gapMd,
            Text(
              sessions == 0
                  ? 'Belum ada rapat di perpustakaan.'
                  : 'Tanyakan apa saja tentang $sessions rapat yang tersimpan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: FontSizes.body, color: colors.text),
            ),
            Spacing.gapSm,
            Text(
              '"Cari" bekerja sepenuhnya di komputer ini. "Jawab" juga '
              'mengirim kutipan yang ditemukan ke endpoint ringkasan yang '
              'Anda atur, dan dicatat di Laporan Privasi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: FontSizes.caption,
                color: colors.textTertiary,
                height: 1.4,
              ),
            ),
            Spacing.gapMd,
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final example in const [
                  'Apa keputusan soal anggaran?',
                  'Siapa penanggung jawab laporan keuangan?',
                  'Kapan tenggat peluncuran?',
                ])
                  Chip(
                    label: Text(
                      example,
                      style: const TextStyle(fontSize: FontSizes.micro),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({
    required this.turn,
    required this.colors,
    this.onOpenSession,
  });

  final ArchiveTurn turn;
  final AppColorSet colors;
  final void Function(String dirPath, double timestamp)? onOpenSession;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: Text(
            turn.question,
            style: TextStyle(
              fontSize: FontSizes.body,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ),
        if (turn.error != null)
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.12),
              borderRadius: Radii.smAll,
            ),
            child: Text(
              turn.error!,
              style: TextStyle(fontSize: FontSizes.caption, color: colors.text),
            ),
          )
        else if (turn.answer.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              turn.answer,
              style: TextStyle(
                fontSize: FontSizes.body,
                color: colors.text,
                height: 1.5,
              ),
            ),
          ),
        if (turn.sources.isNotEmpty) ...[
          Spacing.gapSm,
          Text(
            'Kutipan',
            style: TextStyle(
              fontSize: FontSizes.micro,
              fontWeight: FontWeight.w600,
              color: colors.textTertiary,
            ),
          ),
          for (final entry in turn.sources.asMap().entries)
            _SourceRow(
              index: entry.key + 1,
              hit: entry.value,
              colors: colors,
              onOpen: onOpenSession,
            ),
        ],
        const Divider(height: Spacing.xl),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.index,
    required this.hit,
    required this.colors,
    this.onOpen,
  });

  final int index;
  final rust_archive.ArchiveHit hit;
  final AppColorSet colors;
  final void Function(String dirPath, double timestamp)? onOpen;

  @override
  Widget build(BuildContext context) {
    final label = hit.timestamp < 0
        ? '${hit.title} (${hit.date}) · ringkasan'
        : '${hit.title} (${hit.date}) · ${formatTimestamp(hit.timestamp)}';
    return InkWell(
      onTap: onOpen == null
          ? null
          : () => onOpen!(hit.dirPath, hit.timestamp < 0 ? 0 : hit.timestamp),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '[K$index]',
                style: TextStyle(
                  fontSize: FontSizes.micro,
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: FontSizes.micro,
                      color: colors.primary,
                    ),
                  ),
                  Text(
                    hit.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: FontSizes.caption,
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.colors,
    required this.onSearch,
    required this.onAsk,
  });

  final TextEditingController controller;
  final bool busy;
  final AppColorSet colors;
  final VoidCallback onSearch;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !busy,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Tanyakan sesuatu tentang rapat-rapat Anda…',
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          OutlinedButton.icon(
            onPressed: busy ? null : onSearch,
            icon: const Icon(AppIcons.search, size: IconSizes.md),
            label: const Text('Cari'),
          ),
          const SizedBox(width: Spacing.sm),
          FilledButton.icon(
            onPressed: busy ? null : onAsk,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.enhance, size: IconSizes.md),
            label: const Text('Jawab'),
          ),
        ],
      ),
    );
  }
}
