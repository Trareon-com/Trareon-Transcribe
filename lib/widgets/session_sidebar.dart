/// Permanent session history. Blueprint §4.1, `docs/DESIGN-SYSTEM.md` §7.2.
///
/// Recording history is the product, and it used to be hidden behind an
/// unlabelled folder icon in a row of four unlabelled icons: the audit's first
/// finding about the main screen. Every competitor worth the comparison
/// (Granola, Otter) keeps it on screen.
///
/// Sprint 5 adds what a list of two hundred meetings needs to be usable: date
/// grouping, a snippet of the first line, status badges, and a collapse to a
/// 48 px icon rail.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/library_index.dart';
import '../state/enhance_queue_model.dart';
import '../state/library_model.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_shortcuts.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../utils/format_time.dart';
import 'enhance_queue_view.dart';
import 'ui/app_button.dart';
import 'ui/app_chip.dart';
import 'ui/app_feedback.dart';
import 'ui/app_field.dart';
import 'ui/app_list_row.dart';
import 'ui/key_hint.dart';
import 'ui/app_surface.dart';

/// Width of the permanent sidebar.
const double kSidebarWidth = Measure.sidebar;

/// Width of the sidebar collapsed to an icon rail.
const double kSidebarRailWidth = Measure.sidebarRail;

/// Below this window width the sidebar becomes a drawer instead.
const double kSidebarPersistentMinWidth = Breakpoints.compact;

/// How long the sidebar search waits after the last keystroke.
const Duration kSidebarSearchDebounce = Duration(milliseconds: 250);

/// Which date bucket a session falls in. Named in Indonesian because the
/// labels are what the user reads.
enum SessionGroup { hariIni, kemarin, mingguIni, lebihLama }

extension SessionGroupLabel on SessionGroup {
  String get label => switch (this) {
    SessionGroup.hariIni => 'Hari ini',
    SessionGroup.kemarin => 'Kemarin',
    SessionGroup.mingguIni => '7 hari terakhir',
    SessionGroup.lebihLama => 'Lebih lama',
  };
}

/// Buckets an entry by its `YYYY-MM-DD` date against [today].
///
/// Pure and public so the boundaries can be pinned by a test without pumping
/// a widget or waiting for midnight.
SessionGroup groupForDate(String date, {required DateTime today}) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return SessionGroup.lebihLama;
  final day = DateTime(parsed.year, parsed.month, parsed.day);
  final anchor = DateTime(today.year, today.month, today.day);
  final days = anchor.difference(day).inDays;
  if (days <= 0) return SessionGroup.hariIni;
  if (days == 1) return SessionGroup.kemarin;
  if (days <= 7) return SessionGroup.mingguIni;
  return SessionGroup.lebihLama;
}

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
    this.collapsed = false,
    this.onToggleCollapsed,
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

  /// Focused by the search shortcut.
  final FocusNode searchFocusNode;

  final bool isRecording;

  /// Collapsed to an icon rail. A null [onToggleCollapsed] hides the control,
  /// which is what the drawer does.
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  ConsumerState<SessionSidebar> createState() => _SessionSidebarState();
}

class _SessionSidebarState extends ConsumerState<SessionSidebar> {
  /// Tags selected in the filter row (F20). Empty means "no filter".
  ///
  /// Intersection, not union: picking "Anggaran" and "Mingguan" means the
  /// weekly budget meetings, which is what someone with two tags selected is
  /// looking for.
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
    if (value.isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(kSidebarSearchDebounce, () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  void _toggleTag(String tag, bool selected) {
    setState(() {
      if (selected) {
        _tagFilter.add(tag);
      } else {
        _tagFilter.remove(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final library = ref.watch(libraryListProvider);

    var entries = _query.isEmpty
        ? library.entries
        : library.entries.where((e) => e.haystack.contains(_query)).toList();
    if (_tagFilter.isNotEmpty) {
      entries = entries
          .where(
            (e) => _tagFilter.every(
              (tag) => e.tags.any((t) => t.toLowerCase() == tag.toLowerCase()),
            ),
          )
          .toList();
    }

    // Every tag in the library, so a filter chip exists for one the user only
    // put on a single meeting.
    final allTags = <String>{};
    for (final entry in library.entries) {
      allTags.addAll(entry.tags);
    }
    final sortedTags = allTags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return AnimatedContainer(
      duration: motion.slow,
      curve: AppEasing.emphasized,
      width: widget.collapsed ? kSidebarRailWidth : kSidebarWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.hairline)),
      ),
      child: ClipRect(
        child: widget.collapsed
            ? _Rail(
                onExpand: widget.onToggleCollapsed,
                onNewSession: widget.onNewSession,
                onOpenUpload: widget.onOpenUpload,
                onOpenArchiveChat: widget.onOpenArchiveChat,
                onOpenLibrary: widget.onOpenLibrary,
                onOpenSettings: widget.onOpenSettings,
                sessionCount: library.entries.length,
                isRecording: widget.isRecording,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onCollapse: widget.onToggleCollapsed),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.md,
                      0,
                      Spacing.md,
                      Spacing.sm,
                    ),
                    child: AppButton.primary(
                      label: 'Sesi Baru',
                      icon: AppIcons.add,
                      expand: true,
                      onPressed: widget.onNewSession,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                    child: AppSearchField(
                      controller: _search,
                      focusNode: widget.searchFocusNode,
                      onChanged: _onSearchChanged,
                      placeholder: 'Cari sesi…',
                      semanticLabel: 'Cari di riwayat sesi',
                      shortcut: AppShortcuts.searchSessions.shortcut,
                    ),
                  ),
                  if (sortedTags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.md,
                        Spacing.sm,
                        Spacing.md,
                        0,
                      ),
                      child: Wrap(
                        spacing: Spacing.xs,
                        runSpacing: Spacing.xs,
                        children: [
                          for (final tag in sortedTags)
                            AppFilterChip(
                              label: tag,
                              icon: AppIcons.tag,
                              selected: _tagFilter.contains(tag),
                              onSelected: (selected) =>
                                  _toggleTag(tag, selected),
                            ),
                          if (_tagFilter.isNotEmpty)
                            AppFilterChip(
                              label: 'Semua',
                              selected: false,
                              onSelected: (_) => setState(_tagFilter.clear),
                            ),
                        ],
                      ),
                    ),
                  Spacing.gapSm,
                  // Background "perhalus transkrip" jobs (F5). Above the
                  // session list so a running pass is never scrolled out of
                  // sight.
                  const EnhanceQueueView(),
                  if (widget.isRecording)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        Spacing.md,
                        0,
                        Spacing.md,
                        Spacing.sm,
                      ),
                      child: _RecordingRow(),
                    ),
                  Expanded(
                    child: library.loading && library.entries.isEmpty
                        ? const AppSkeletonList(rows: 6)
                        : entries.isEmpty
                        ? _EmptyList(
                            error: library.error,
                            searching:
                                _query.isNotEmpty || _tagFilter.isNotEmpty,
                          )
                        : _SessionList(
                            entries: entries,
                            selectedDirPath: widget.selectedDirPath,
                            onSelect: widget.onSelect,
                          ),
                  ),
                  AppHairline(color: colors.hairline),
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
                  _FooterAction(
                    icon: AppIcons.settings,
                    label: 'Pengaturan',
                    shortcut: AppShortcuts.settings.shortcut,
                    onTap: widget.onOpenSettings,
                  ),
                  Spacing.gapSm,
                ],
              ),
      ),
    );
  }
}

/// The session list, grouped by date.
class _SessionList extends ConsumerWidget {
  const _SessionList({
    required this.entries,
    required this.selectedDirPath,
    required this.onSelect,
  });

  final List<LibraryEntry> entries;
  final String? selectedDirPath;
  final ValueChanged<LibraryEntry> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    // One flat list of rows and headers rather than nested lists, so the
    // builder stays lazy at two hundred sessions (the Sprint 2 library perf
    // budget is 500 ms to first paint).
    final rows = <_Row>[];
    SessionGroup? current;
    for (final entry in entries) {
      final group = groupForDate(entry.date, today: today);
      if (group != current) {
        current = group;
        rows.add(_Row.header(group));
      }
      rows.add(_Row.entry(entry));
    }

    // One job per directory, preferring the running one over a merely
    // queued one — that is the one whose stage is worth showing.
    final running = <String, EnhanceJob>{};
    for (final job in ref.watch(enhanceQueueProvider).jobs) {
      if (job.status != EnhanceJobStatus.queued &&
          job.status != EnhanceJobStatus.running) {
        continue;
      }
      final existing = running[job.directoryPath];
      if (existing == null || existing.status != EnhanceJobStatus.running) {
        running[job.directoryPath] = job;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final group = row.group;
        if (group != null) {
          return AppListGroupHeader(label: group.label);
        }
        final entry = row.entry!;
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.xs / 2),
          child: _SessionRow(
            key: ValueKey(entry.dirPath),
            entry: entry,
            selected: entry.dirPath == selectedDirPath,
            retranscribingJob: running[entry.dirPath],
            onTap: () => onSelect(entry),
          ),
        );
      },
    );
  }
}

class _Row {
  const _Row.header(this.group) : entry = null;
  const _Row.entry(this.entry) : group = null;

  final SessionGroup? group;
  final LibraryEntry? entry;
}

/// The brand row.
///
/// Settings is deliberately *not* here: at 260 px the wordmark lost to two
/// 48 px icon buttons and rendered as "Trareon Trans…". It is a destination
/// like "Impor berkas" and now sits with the other three at the bottom.
class _Header extends StatelessWidget {
  const _Header({required this.onCollapse});

  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.xs,
        Spacing.sm,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Image.asset(
              'assets/logo.png',
              width: IconSizes.lg,
              height: IconSizes.lg,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Spacing.hSm,
          Expanded(
            child: Text(
              'Trareon Transcribe',
              overflow: TextOverflow.ellipsis,
              style: AppText.subheading.c(colors.text),
            ),
          ),
          if (onCollapse != null)
            AppIconButton(
              icon: AppIcons.sidebarCollapse,
              tooltip:
                  'Sembunyikan sidebar '
                  '(${AppShortcuts.toggleSidebar.shortcut.label})',
              size: IconSizes.md,
              onPressed: onCollapse,
            ),
        ],
      ),
    );
  }
}

/// The sidebar collapsed to a 48 px icon rail.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.onExpand,
    required this.onNewSession,
    required this.onOpenUpload,
    required this.onOpenArchiveChat,
    required this.onOpenLibrary,
    required this.onOpenSettings,
    required this.sessionCount,
    required this.isRecording,
  });

  final VoidCallback? onExpand;
  final VoidCallback onNewSession;
  final VoidCallback onOpenUpload;
  final VoidCallback onOpenArchiveChat;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenSettings;
  final int sessionCount;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Spacing.gapSm,
        if (onExpand != null)
          AppIconButton(
            icon: AppIcons.sidebarExpand,
            tooltip:
                'Tampilkan sidebar '
                '(${AppShortcuts.toggleSidebar.shortcut.label})',
            size: IconSizes.md,
            onPressed: onExpand,
          ),
        AppIconButton(
          icon: AppIcons.add,
          tooltip: 'Sesi baru',
          onPressed: onNewSession,
        ),
        if (isRecording)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Spacing.sm),
            child: RecordingDot(),
          ),
        const Spacer(),
        AppIconButton(
          icon: AppIcons.history,
          tooltip: 'Riwayat sesi',
          badge: sessionCount,
          onPressed: onExpand ?? onOpenLibrary,
        ),
        AppIconButton(
          icon: AppIcons.uploadFile,
          tooltip: 'Impor berkas',
          onPressed: onOpenUpload,
        ),
        AppIconButton(
          icon: AppIcons.chat,
          tooltip: 'Tanya arsip rapat',
          onPressed: onOpenArchiveChat,
        ),
        AppIconButton(
          icon: AppIcons.settings,
          tooltip: 'Pengaturan',
          onPressed: onOpenSettings,
        ),
        Spacing.gapSm,
      ],
    );
  }
}

/// The live session, pinned above the history while it runs.
class _RecordingRow extends StatelessWidget {
  const _RecordingRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.recordingSubtle,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        children: [
          const RecordingDot(size: Spacing.sm - 2),
          Spacing.hSm,
          Text('Sedang merekam', style: AppText.captionStrong.c(colors.text)),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.retranscribingJob,
    required this.onTap,
  });

  final LibraryEntry entry;
  final bool selected;

  /// The background pass currently queued or running for this session, if
  /// any — carries the stage (Sprint 14b, item 10b) so the badge can say
  /// *what* is happening rather than just that something is.
  final EnhanceJob? retranscribingJob;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (entry.durationSeconds > 0) formatDurationId(entry.durationSeconds),
      '${entry.segmentsCount} segmen',
    ].join('  ');

    final job = retranscribingJob;
    // Completion jobs (ITEM 0) don't set `stage` — they have only one
    // phase — but they do carry a real `progress` fraction, which is worth
    // showing here too rather than just for the F5 enhance pass.
    final stage = job == null
        ? null
        : job.stage ??
              (job.kind == EnhanceJobKind.complete &&
                      job.status == EnhanceJobStatus.running
                  ? 'Menyelesaikan ${sourceLabel(job.source)}'
                  : null);
    final stageLabel = job != null && stage != null
        ? '$stage ${(job.progress.clamp(0.0, 1.0) * 100).round()}%'
        : null;

    return AppListRow(
      title: entry.title,
      subtitle: entry.snippet.isEmpty ? entry.date : entry.snippet,
      selected: selected,
      onTap: onTap,
      semanticLabel:
          '${entry.title}, ${entry.date}, $meta'
          '${stageLabel == null ? '' : ', $stageLabel'}',
      badges: [
        AppChip(label: meta, mono: true),
        if (job != null)
          Tooltip(
            message: stageLabel == null
                ? 'Menunggu antrean untuk ditranskrip ulang.'
                : 'Ditranskrip ulang: $stageLabel',
            child: AppStatusBadge(
              label: stageLabel ?? 'Ditranskrip ulang',
              status: AppStatus.info,
              icon: AppIcons.enhance,
            ),
          ),
        if (entry.hasSummary)
          const AppStatusBadge(
            label: 'Ada ringkasan',
            status: AppStatus.success,
            icon: AppIcons.shortText,
          ),
      ],
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.error, required this.searching});

  final String? error;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return AppEmptyState(
        compact: true,
        tone: AppEmptyTone.error,
        icon: AppIcons.folderOpen,
        title: 'Folder sesi tidak terbaca',
        message: error!,
      );
    }
    if (searching) {
      return const AppEmptyState(
        compact: true,
        icon: AppIcons.searchOff,
        title: 'Tidak ada yang cocok',
        message: 'Coba kata kunci lain atau lepaskan filter tag.',
      );
    }
    // No action button here: "Sesi Baru" is already the filled button three
    // rows above, and two CTAs with the same intent on one surface is a
    // defect rather than helpfulness.
    return const AppEmptyState(
      compact: true,
      icon: AppIcons.history,
      badgeIcon: AppIcons.add,
      title: 'Belum ada sesi',
      message: 'Rapat yang sudah direkam muncul di sini.',
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.shortcut,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppShortcut? shortcut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: AppListRow(
        dense: true,
        title: label,
        onTap: onTap,
        leading: Icon(icon, size: IconSizes.sm, color: colors.textSecondary),
        actions: shortcut == null
            ? const []
            : [
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: KeyHint(shortcut!),
                ),
              ],
      ),
    );
  }
}
