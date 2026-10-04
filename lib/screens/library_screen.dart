import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../services/library_index.dart';
import '../services/session_store.dart';
import '../state/enhance_queue_model.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';

import '../widgets/file_upload_zone.dart';
import '../widgets/session_card.dart';
import '../widgets/storage_bar.dart';
import '../widgets/empty_state.dart';
import 'transcript_player_screen.dart';
import '../widgets/export_dialog.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// How long the library search box waits after the last keystroke.
/// Matching the whole corpus per keystroke was the second half of the
/// scalability wall (audit A.2-4).
const Duration kLibrarySearchDebounce = Duration(milliseconds: 250);

class LibraryScreen extends ConsumerStatefulWidget {
  /// Optional seed list used in tests to bypass the async disk load.
  final List<SessionSummary>? sessions;

  /// Resolved library directory path. When null and [sessions] is also null,
  /// the screen shows an empty state without hitting disk.
  final String? libraryPath;

  /// Which tab opens first. The upload zone is reached from its own header
  /// action, which used to land on the sessions tab and leave the user to
  /// find the second tab.
  final int initialTab;

  const LibraryScreen({
    super.key,
    this.sessions,
    this.libraryPath,
    this.initialTab = 0,
  });

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';

  List<LibraryEntry> _entries = [];
  bool _loading = true;

  /// Deep-search results for [_query], keyed by session directory. Also the
  /// snippet memo: `matchingSnippet` used to re-walk every segment of every
  /// matching session inside `itemBuilder`, i.e. on every rebuild.
  Map<String, String> _deepHits = {};
  String? _deepQuery;
  bool _deepSearching = false;

  // Soft-delete: timer fires real disk deletion after SnackBar expires.
  // Cancelled immediately if the user taps "Urungkan".
  final Map<String, Timer> _pendingDeletions = {};

  @override
  void initState() {
    super.initState();
    final seeded = widget.sessions;
    if (seeded != null) {
      _entries = [
        for (final s in seeded)
          LibraryEntry(
            dirPath: s.id,
            title: s.title,
            date: s.date,
            durationSeconds: s.durationSeconds,
            segmentsCount: s.segmentsCount,
            snippet: s.segments.isEmpty
                ? ''
                : '${s.segments.first.speaker}: ${s.segments.first.text}',
            audioPath: s.audioPath,
            transcriptSize: -1,
            transcriptModifiedMs: -1,
          ),
      ];
      _loading = false;
    } else {
      _loadFromDisk();
    }
  }

  Future<void> _loadFromDisk() async {
    final libraryPath = widget.libraryPath;
    if (libraryPath == null) {
      setState(() => _loading = false);
      return;
    }
    final load = await loadLibraryIndex(libraryPath);
    if (!mounted) return;
    setState(() {
      _entries = load.entries;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    // Flush all pending deletions immediately when screen closes
    for (final entry in _pendingDeletions.entries) {
      entry.value.cancel();
      try {
        final dir = Directory(entry.key);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (e) { debugPrint("LibraryScreen: deleteSync error: $e"); }
    }
    _pendingDeletions.clear();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(kLibrarySearchDebounce, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _maybeDeepSearch();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _deepHits = {};
      _deepQuery = null;
    });
  }

  /// Cheap pass: title, first line and summary, all precomputed and
  /// lowercased at index time.
  List<LibraryEntry> get _filteredEntries {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries
        .where((e) => e.haystack.contains(q) || _deepHits.containsKey(e.dirPath))
        .toList(growable: false);
  }

  /// Expensive pass, on a background isolate, and only when the cheap one
  /// came up empty: the words the user is looking for are usually in the
  /// body of a transcript, not in its auto-generated title.
  Future<void> _maybeDeepSearch() async {
    final query = _query;
    if (query.length < 3 || widget.libraryPath == null) {
      if (_deepHits.isNotEmpty) setState(() => _deepHits = {});
      return;
    }
    if (_deepQuery == query) return;
    final q = query.toLowerCase();
    final unmatched = _entries
        .where((e) => !e.haystack.contains(q))
        .map((e) => e.dirPath)
        .toList(growable: false);
    if (unmatched.isEmpty) {
      setState(() {
        _deepQuery = query;
        _deepHits = {};
      });
      return;
    }
    setState(() => _deepSearching = true);
    List<DeepSearchHit> hits;
    try {
      hits = await deepSearchLibrary(unmatched, query);
    } catch (_) {
      hits = const [];
    }
    if (!mounted || _query != query) return;
    setState(() {
      _deepSearching = false;
      _deepQuery = query;
      _deepHits = {for (final hit in hits) hit.dirPath: hit.snippet};
    });
  }

  /// Snippet shown under a search result. Memoised: the deep search
  /// already produced the matching line, and an index-level match shows the
  /// session's stored first line.
  String? _snippetFor(LibraryEntry entry) {
    if (_query.isEmpty) return null;
    final deep = _deepHits[entry.dirPath];
    if (deep != null) return deep;
    final q = _query.toLowerCase();
    return entry.snippet.toLowerCase().contains(q) ? entry.snippet : null;
  }

  void _deleteSession(LibraryEntry session) {
    final index = _entries.indexOf(session);
    if (index == -1) return;

    // Remove from UI immediately (optimistic). Actual disk deletion is
    // deferred by 5 s so "Urungkan" can cancel it before data is gone.
    setState(() => _entries = [..._entries]..removeAt(index));
    _persistIndex();
    _pendingDeletions[session.dirPath]?.cancel();
    _pendingDeletions[session.dirPath] = Timer(const Duration(seconds: 5), () {
      _pendingDeletions.remove(session.dirPath);
      try {
        final dir = Directory(session.dirPath);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (e) { debugPrint("LibraryScreen: timer error: $e"); }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${session.title}" dihapus.'),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () {
            _pendingDeletions.remove(session.dirPath)?.cancel();
            if (mounted) {
              setState(() {
                final restored = [..._entries];
                restored.insert(index.clamp(0, restored.length), session);
                _entries = restored;
              });
              _persistIndex();
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Keeps the on-disk index in step with an in-memory change, so the next
  /// open does not have to re-derive the whole corpus to notice.
  void _persistIndex() {
    final libraryPath = widget.libraryPath;
    if (libraryPath == null) return;
    unawaited(saveLibraryIndex(libraryPath, _entries).catchError((_) {}));
  }

  /// Renames a session by writing the new title into its metadata sidecar.
  ///
  /// The directory keeps its original `YYYYMMDD-…` name on purpose: moving it
  /// would invalidate the audio path the player already holds and desync the
  /// exported filenames inside from the folder around them.
  Future<void> _renameSession(LibraryEntry session) async {
    final controller = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ganti Nama Sesi'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama sesi',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(dialogCtx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();

    final trimmed = newTitle?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == session.title) return;

    try {
      final meta = await readSessionMeta(session.dirPath);
      await writeSessionMeta(session.dirPath, meta.copyWith(title: trimmed));
      if (!mounted) return;
      setState(() {
        final index = _entries.indexOf(session);
        if (index >= 0) {
          final updated = [..._entries];
          updated[index] = session.copyWith(title: trimmed);
          _entries = updated;
        }
      });
      _persistIndex();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengganti nama: $e')),
      );
    }
  }

  Future<void> _exportSession(LibraryEntry session) async {
    final bridge = ref.read(rustBridgeProvider);
    final settings = ref.read(settingsProvider);
    // Phase 2: the segments are only read when something actually needs
    // them. The list itself never has them in memory.
    final record = await loadSessionRecord(session.dirPath);
    if (!mounted) return;
    await showEksporDialog(
      context,
      record?.toSummary() ?? session.toSummary(),
      bridge: bridge,
      defaultOutputDir: resolveTilde(settings.libraryPath),
      defaultFormat: settings.defaultExportFormat,
      summary: record?.meta.summary ?? '',
      incomplete: (record?.meta.isIncomplete ?? false) ||
          ref.read(enhanceQueueProvider).isCompletingSession(session.dirPath),
      pdp: settings.pdp,
    );
  }

  Future<void> _openSession(LibraryEntry session) async {
    final record = await loadSessionRecord(session.dirPath);
    if (!mounted) return;
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${session.title}" tidak bisa dibuka.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranscriptPlayerScreen(
          title: record.title,
          durationSeconds: record.durationSeconds,
          segments: record.segments,
          audioPath: record.audioPath,
          sessionDirPath: record.dirPath,
          meta: record.meta,
        ),
      ),
    );
    // The player can edit the transcript, re-transcribe and save a summary.
    // Only that one session can have changed, so only that one is re-read —
    // re-scanning the whole library here was paying the old open cost again
    // even when the user had merely looked (audit A.2-5).
    if (!mounted || widget.sessions != null) return;
    final refreshed = await buildLibraryEntry(Directory(session.dirPath));
    if (!mounted || refreshed == null) return;
    setState(() {
      final index = _entries.indexWhere((e) => e.dirPath == session.dirPath);
      if (index < 0) return;
      final updated = [..._entries];
      updated[index] = refreshed;
      _entries = updated;
    });
    _persistIndex();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final filtered = _filteredEntries;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.headerBackground,
          foregroundColor: colors.text,
          title: const Text('Perpustakaan', style: TextStyle(fontWeight: FontWeight.w600)),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(AppIcons.back, size: IconSizes.lg),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Kembali',
          ),
          bottom: TabBar(
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: colors.primary,
            tabs: const [
              Tab(text: 'Sesi'),
              Tab(text: 'Impor Berkas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Sessions tab
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Cari judul, isi transkrip, atau ringkasan...',
                      prefixIcon: Icon(AppIcons.search, color: colors.textTertiary, size: IconSizes.md),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(AppIcons.clear, size: IconSizes.md, color: colors.textTertiary),
                              onPressed: _clearSearch,
                              tooltip: 'Bersihkan pencarian',
                            )
                          : null,
                      filled: true,
                      fillColor: colors.chipBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                    ),
                  ),
                ),
                if (_deepSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Spacing.md),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        Spacing.hSm,
                        Text('Mencari di dalam transkrip…',
                            style: TextStyle(fontSize: FontSizes.caption)),
                      ],
                    ),
                  ),
                // Outside the list on purpose: as list item 0 it was
                // disposed and re-created on every scroll, and each
                // creation walked the whole library directory (A.2-6).
                if (!_loading && _entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                    child: StorageBar(
                      totalSessions: _entries.length,
                      libraryPath: widget.libraryPath,
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _entries.isEmpty
                          ? const EmptyState(
                              icon: AppIcons.folderOpen,
                              title: 'Belum ada sesi tersimpan',
                              subtitle: 'Sesi transkripsi akan muncul di sini',
                            )
                          : filtered.isEmpty
                              ? const EmptyState(
                                  icon: AppIcons.searchOff,
                                  title: 'Tidak ada sesi cocok',
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Spacing.md, vertical: Spacing.sm),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      Spacing.gapSm,
                                  itemBuilder: (context, index) {
                                    final session = filtered[index];
                                    return SessionCardFromSummary(
                                      key: ValueKey(session.dirPath),
                                      session: session.toSummary(),
                                      hasSummary: session.hasSummary,
                                      matchSnippet: _snippetFor(session),
                                      onDelete: () => _deleteSession(session),
                                      onExport: () => _exportSession(session),
                                      onRename: () => _renameSession(session),
                                      onTap: () => _openSession(session),
                                    );
                                  },
                                ),
                ),
              ],
            ),

            // Upload tab
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: FileUploadZone(onProcessed: _loadFromDisk),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> shareSessionSummary(SessionSummary session) {
  final minutes = (session.durationSeconds / 60).floor();
  final transcript = session.segments.isEmpty
      ? 'Tidak ada transkrip.'
      : session.segments.map((s) => '${s.speaker}: ${s.text}').join('\n');
  return SharePlus.instance.share(
    ShareParams(
      subject: session.title,
      text: '${session.title}\n$minutes menit · ${session.segmentsCount} segmen\n\n$transcript',
    ),
  );
}

String buildSessionShareText(SessionSummary session) {
  final minutes = (session.durationSeconds / 60).floor();
  final transcript = session.segments.isEmpty
      ? 'Tidak ada transkrip yang tersimpan.'
      : session.segments.map((s) => '${s.speaker}: ${s.text}').join('\n');
  return '${session.title}\n${session.date} · $minutes menit · '
      '${session.segmentsCount} segmen\n\n$transcript\n\nDitranskrip dengan Trareon Transcribe.';
}
