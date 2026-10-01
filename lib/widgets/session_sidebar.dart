import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/library_index.dart';
import '../state/library_model.dart';
import '../theme/app_colors.dart';
import '../utils/format_time.dart';

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

  /// Focused by Ctrl+L / ⌘L.
  final FocusNode searchFocusNode;

  final bool isRecording;

  @override
  ConsumerState<SessionSidebar> createState() => _SessionSidebarState();
}

class _SessionSidebarState extends ConsumerState<SessionSidebar> {
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
    final entries = _query.isEmpty
        ? library.entries
        : library.entries.where((e) => e.haystack.contains(_query)).toList();

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
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: FilledButton.icon(
              onPressed: widget.onNewSession,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Sesi baru'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _search,
                focusNode: widget.searchFocusNode,
                onChanged: _onSearchChanged,
                style: TextStyle(color: colors.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari sesi... (Ctrl+L)',
                  hintStyle: TextStyle(color: colors.textTertiary, fontSize: 12),
                  prefixIcon:
                      Icon(Icons.search, size: 16, color: colors.textTertiary),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.clear,
                              size: 14, color: colors.textTertiary),
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
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          library.error != null
                              ? 'Folder sesi tidak bisa dibaca:\n${library.error}'
                              : _query.isEmpty
                                  ? 'Belum ada sesi. Tekan "Sesi baru" untuk '
                                      'mulai merekam.'
                                  : 'Tidak ada sesi yang cocok.',
                          style: TextStyle(
                              color: colors.textTertiary, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
            icon: Icons.upload_file_outlined,
            label: 'Impor berkas',
            onTap: widget.onOpenUpload,
          ),
          _FooterAction(
            icon: Icons.folder_open_outlined,
            label: 'Kelola perpustakaan',
            onTap: widget.onOpenLibrary,
          ),
          const SizedBox(height: 6),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
      child: Row(
        children: [
          Image.asset('assets/logo.png',
              width: 20,
              height: 20,
              errorBuilder: (_, _, _) => const SizedBox.shrink()),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Trareon Transcribe',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18),
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
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.chipBackground,
          borderRadius: BorderRadius.circular(8),
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
            const SizedBox(width: 8),
            Text(
              'Sedang merekam',
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
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
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? colors.primary : colors.text,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    entry.date,
                    if (entry.durationSeconds > 0)
                      formatDurationId(entry.durationSeconds),
                    '${entry.segmentsCount} segmen',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textTertiary, fontSize: 11),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
