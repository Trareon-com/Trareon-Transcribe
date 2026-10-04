import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/library_index.dart';
import '../state/library_model.dart';
import '../theme/app_colors.dart';
import '../utils/format_time.dart';
import 'enhance_queue_view.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// Width of the permanent sidebar. Narrow enough that the workspace still
/// has 540 px at the app's 800 px minimum window.
const double kSidebarWidth = 260;

/// Below this window width the sidebar becomes a drawer instead. The app's
/// minimum window is 800x600, where the sidebar stays put and leaves the
/// workspace 540 px; only a window dragged below the supported minimum
/// gets the drawer.
const double kSidebarPersistentMinWidth = 700;

/// How long the sidebar search waits after the last keystroke.
const Duration kSidebarSearchDebounce = Duration(milliseconds: 250);

/// Permanent session history (blueprint §4.1).
///
/// Recording history is the product, and it used to be hidden behind an
/// unlabelled folder icon in a row of four unlabelled icons — the audit's
/// first finding about the main screen. Every competitor worth the
/// comparison (Granola, Otter) keeps it on screen.
class SessionSidebar extends ConsumerStatefulWidget {
  const SessionSidebar({
    super.key,
    required this.selectedDirPath,
    required this.onSelect,
    required this.onNewSession,
    required this.onOpenLibrary,
    required this.onOpenUpload,
    required this.onOpenSettings,
    required this.onOpenArchiveChat,
    required this.searchFocusNode,
    this.isRecording = false,
  });

  /// Session currently shown in the workspace, or null while the live
  /// recording panel is showing.
  final String? selectedDirPath;

  final ValueChanged<LibraryEntry> onSelect;
  final VoidCallback onNewSession;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenUpload;
  final VoidCallback onOpenSettings;

  /// Opens "Tanya Arsip Rapat" (F12).
  final VoidCallback onOpenArchiveChat;

  /// Focused by Ctrl+L / ⌘L.
  final FocusNode searchFocusNode;

  final bool isRecording;

  @override
  ConsumerState<SessionSidebar> createState() => _SessionSidebarState();
}

class _SessionSidebarState extends ConsumerState<SessionSidebar> {
  /// Tags selected in the filter row (F20). Empty means "no filter".
  ///
  /// Intersection, not union: picking "Anggaran" and "Mingguan" means the
  /// weekly budget meetings, which is what someone with two tags
  /// selected is looking for.
  final Set<String> _tagFilter = {};
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(kSidebarSearchDebounce, () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final library = ref.watch(libraryListProvider);
    var entries = _query.isEmpty
        ? library.entries
        : library.entries.where((e) => e.haystack.contains(_query)).toList();
    if (_tagFilter.isNotEmpty) {
      entries = entries
          .where((e) => _tagFilter.every(
                (tag) => e.tags.any(
                  (t) => t.toLowerCase() == tag.toLowerCase(),
                ),
              ))
          .toList();
    }
    // Every tag in the library, so a filter chip exists for one the user
    // only put on a single meeting.
    final allTags = <String>{};
    for (final entry in library.entries) {
      allTags.addAll(entry.tags);
    }
    final sortedTags = allTags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Container(
      width: kSidebarWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onOpenSettings: widget.onOpenSettings),
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.xs, Spacing.md, Spacing.sm),
            child: FilledButton.icon(
              onPressed: widget.onNewSession,
              icon: const Icon(AppIcons.add, size: IconSizes.md),
              label: const Text('Sesi baru'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _search,
                focusNode: widget.searchFocusNode,
                onChanged: _onSearchChanged,
                style: TextStyle(color: colors.text, fontSize: FontSizes.body),
                decoration: InputDecoration(
                  hintText: 'Cari sesi... (Ctrl+L)',
                  hintStyle: TextStyle(color: colors.textTertiary, fontSize: FontSizes.caption),
                  prefixIcon:
                      Icon(AppIcons.search, size: IconSizes.sm, color: colors.textTertiary),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(AppIcons.clear,
                              size: IconSizes.xs, color: colors.textTertiary),
                          tooltip: 'Bersihkan pencarian',
                          onPressed: () {
                            _debounce?.cancel();
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: colors.chipBackground,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (sortedTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final tag in sortedTags)
                    FilterChip(
                      label: Text(
                        tag,
                        style: const TextStyle(fontSize: FontSizes.micro),
                      ),
                      selected: _tagFilter.contains(tag),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _tagFilter.add(tag);
                        } else {
                          _tagFilter.remove(tag);
                        }
                      }),
                    ),
                  if (_tagFilter.isNotEmpty)
                    ActionChip(
                      label: const Text(
                        'Semua',
                        style: TextStyle(fontSize: FontSizes.micro),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      onPressed: () => setState(_tagFilter.clear),
                    ),
                ],
              ),
            ),
          Spacing.gapSm,
          // Background "perhalus transkrip" jobs (F5). Above the session
          // list so a running pass is never scrolled out of sight.
          const EnhanceQueueView(),
          if (widget.isRecording)
            _RecordingRow(selected: widget.selectedDirPath == null),
          Expanded(
            child: library.loading && library.entries.isEmpty
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Text(
                          library.error != null
                              ? 'Folder sesi tidak bisa dibaca:\n${library.error}'
                              : _query.isEmpty
                                  ? 'Belum ada sesi. Tekan "Sesi baru" untuk '
                                      'mulai merekam.'
                                  : 'Tidak ada sesi yang cocok.',
                          style: TextStyle(
                              color: colors.textTertiary, fontSize: FontSizes.caption),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return _SessionRow(
                            key: ValueKey(entry.dirPath),
                            entry: entry,
                            selected: entry.dirPath == widget.selectedDirPath,
                            onTap: () => widget.onSelect(entry),
                          );
                        },
                      ),
          ),
          Divider(height: 1, color: colors.divider),
          _FooterAction(
            icon: AppIcons.uploadFile,
            label: 'Impor berkas',
            onTap: widget.onOpenUpload,
          ),
          _FooterAction(
            icon: AppIcons.chat,
            label: 'Tanya arsip rapat',
            onTap: widget.onOpenArchiveChat,
          ),
          _FooterAction(
            icon: AppIcons.folderOpen,
            label: 'Kelola perpustakaan',
            onTap: widget.onOpenLibrary,
          ),
          Spacing.gapSm,
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.sm, Spacing.sm),
      child: Row(
        children: [
          Image.asset('assets/logo.png',
              width: 20,
              height: 20,
              errorBuilder: (_, _, _) => const SizedBox.shrink()),
          Spacing.hSm,
          Expanded(
            child: Text(
              'Trareon Transcribe',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: FontSizes.bodyLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(AppIcons.settings, size: IconSizes.md),
            tooltip: 'Pengaturan (Ctrl+,)',
            onPressed: onOpenSettings,
            color: colors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// The live session, pinned above the history while it runs.
class _RecordingRow extends StatelessWidget {
  const _RecordingRow({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, 0, Spacing.sm, Spacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.chipBackground,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.recording,
              ),
            ),
            Spacing.hSm,
            Text(
              'Sedang merekam',
              style: TextStyle(
                color: colors.text,
                fontSize: FontSizes.caption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final LibraryEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? colors.primary : colors.text,
                    fontSize: FontSizes.body,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                Spacing.gapXs,
                Text(
                  [
                    entry.date,
                    if (entry.durationSeconds > 0)
                      formatDurationId(entry.durationSeconds),
                    '${entry.segmentsCount} segmen',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textTertiary, fontSize: FontSizes.micro),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        child: Row(
          children: [
            Icon(icon, size: IconSizes.sm, color: colors.textSecondary),
            Spacing.hSm,
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textSecondary, fontSize: FontSizes.caption),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
