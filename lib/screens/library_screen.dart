import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../services/session_store.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';

import '../widgets/file_upload_zone.dart';
import '../widgets/session_card.dart';
import '../widgets/storage_bar.dart';
import '../widgets/empty_state.dart';
import 'transcript_player_screen.dart';
import '../widgets/export_dialog.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  /// Optional seed list used in tests to bypass the async disk load.
  final List<SessionSummary>? sessions;

  /// Resolved library directory path. When null and [sessions] is also null,
  /// the screen shows an empty state without hitting disk.
  final String? libraryPath;

  const LibraryScreen({super.key, this.sessions, this.libraryPath});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<SessionRecord> _sessions = [];
  bool _loading = true;
  // Soft-delete: timer fires real disk deletion after SnackBar expires.
  // Cancelled immediately if the user taps "Urungkan".
  final Map<String, Timer> _pendingDeletions = {};

  @override
  void initState() {
    super.initState();
    final seeded = widget.sessions;
    if (seeded != null) {
      _sessions = [
        for (final s in seeded)
          SessionRecord(
            dirPath: s.id,
            title: s.title,
            date: s.date,
            segments: s.segments,
            durationSeconds: s.durationSeconds,
            audioPath: s.audioPath,
            meta: SessionMeta.empty,
            seededSegmentsCount: s.segmentsCount,
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
    final sessions = await loadSessionLibrary(libraryPath);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  @override
  void dispose() {
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

  /// Full-text: matches the title, the saved summary, and every segment's
  /// text. Title-only matching used to make search useless for auto-titled
  /// sessions, which is most of them.
  List<SessionRecord> get _filteredSessions =>
      _sessions.where((s) => sessionMatchesQuery(s, _query)).toList();

  void _deleteSession(SessionRecord session) {
    final index = _sessions.indexOf(session);
    if (index == -1) return;

    // Remove from UI immediately (optimistic). Actual disk deletion is
    // deferred by 5 s so "Urungkan" can cancel it before data is gone.
    setState(() => _sessions.removeAt(index));
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
              setState(() => _sessions.insert(index.clamp(0, _sessions.length), session));
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Renames a session by writing the new title into its metadata sidecar.
  ///
  /// The directory keeps its original `YYYYMMDD-…` name on purpose: moving it
  /// would invalidate the audio path the player already holds and desync the
  /// exported filenames inside from the folder around them.
  Future<void> _renameSession(SessionRecord session) async {
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
        final index = _sessions.indexOf(session);
        if (index >= 0) {
          _sessions[index] = session.copyWith(
            title: trimmed,
            meta: session.meta.copyWith(title: trimmed),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengganti nama: $e')),
      );
    }
  }

  Future<void> _exportSession(SessionRecord session) async {
    final bridge = ref.read(rustBridgeProvider);
    final settings = ref.read(settingsProvider);
    await showEksporDialog(
      context,
      session.toSummary(),
      bridge: bridge,
      defaultOutputDir: resolveTilde(settings.libraryPath),
      defaultFormat: settings.defaultExportFormat,
      summary: session.meta.summary,
    );
  }

  Future<void> _openSession(SessionRecord session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranscriptPlayerScreen(
          title: session.title,
          durationSeconds: session.durationSeconds,
          segments: session.segments,
          audioPath: session.audioPath,
          sessionDirPath: session.dirPath,
          meta: session.meta,
        ),
      ),
    );
    // The player can edit the transcript, re-transcribe, and save a summary —
    // re-read so the list reflects all of that instead of going stale.
    if (mounted && widget.sessions == null) await _loadFromDisk();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final filtered = _filteredSessions;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.headerBackground,
          foregroundColor: colors.text,
          title: const Text('Perpustakaan', style: TextStyle(fontWeight: FontWeight.w600)),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: colors.primary,
            tabs: const [
              Tab(text: 'Sesi'),
              Tab(text: 'Upload Berkas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Sessions tab
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Cari judul, isi transkrip, atau ringkasan...',
                      prefixIcon: Icon(Icons.search, color: colors.textTertiary, size: 18),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 18, color: colors.textTertiary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.chipBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _sessions.isEmpty
                          ? const EmptyState(
                              icon: Icons.folder_open_outlined,
                              title: 'Belum ada sesi tersimpan',
                              subtitle: 'Sesi transkripsi akan muncul di sini',
                            )
                              : filtered.isEmpty
                                  ? const EmptyState(
                                      icon: Icons.search_off,
                                      title: 'Tidak ada sesi cocok',
                                    )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: filtered.length + 1, // +1 for storage bar
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return StorageBar(
                                      totalSessions: _sessions.length,
                                      libraryPath: widget.libraryPath,
                                    );
                                    }
                                    final session = filtered[index - 1];
                                    return SessionCardFromSummary(
                                      session: session.toSummary(),
                                      hasSummary: session.meta.hasSummary,
                                      matchSnippet:
                                          matchingSnippet(session, _query),
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
              padding: EdgeInsets.all(12),
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
