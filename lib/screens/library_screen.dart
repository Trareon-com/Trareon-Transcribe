import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
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
  List<SessionSummary> _sessions = [];
  bool _loading = true;
  // Soft-delete: timer fires real disk deletion after SnackBar expires.
  // Cancelled immediately if the user taps "Urungkan".
  final Map<String, Timer> _pendingDeletions = {};

  @override
  void initState() {
    super.initState();
    if (widget.sessions != null) {
      _sessions = List.of(widget.sessions!);
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
    final dir = Directory(libraryPath);
    if (!dir.existsSync()) {
      setState(() => _loading = false);
      return;
    }
    final sessions = <SessionSummary>[];
    try {
      for (final entry in dir.listSync()) {
        if (entry is! Directory) continue;
        try {
          final sessionDir = entry;
          final files = sessionDir.listSync().whereType<File>().toList();
          final jsonFile = files.where((f) => f.path.endsWith('.json')).firstOrNull;
          if (jsonFile == null) continue;
          final raw = await jsonFile.readAsString();
          final list = jsonDecode(raw) as List<dynamic>;
          final segments = list.map((e) {
            final m = e as Map<String, dynamic>;
            return TranscriptSegment(
              source: m['source'] as String? ?? '',
              speaker: m['speaker'] as String? ?? '',
              text: m['text'] as String? ?? '',
              timestamp: (m['timestamp'] as num?)?.toDouble() ?? 0,
              duration: (m['duration'] as num?)?.toDouble() ?? 0,
              language: m['language'] as String? ?? '',
              confidence: (m['confidence'] as num?)?.toDouble() ?? 1.0,
              isPartial: m['is_partial'] as bool? ?? false,
            );
          }).toList();
          final title = sessionDir.path.split(Platform.pathSeparator).last;
          final stat = await sessionDir.stat();
          final duration = segments.isEmpty ? 0.0
              : (segments.last.timestamp + segments.last.duration);
          final audioFile = files.firstWhere(
            (f) => const {'wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac', 'opus', 'mp4', 'mov', 'mkv'}
                .contains(f.path.split('.').last.toLowerCase()),
            orElse: () => File(''),
          );
          sessions.add(SessionSummary(
            id: sessionDir.path,
            title: title,
            date: stat.modified.toIso8601String().substring(0, 10),
            segmentsCount: segments.length,
            segments: segments,
            durationSeconds: duration,
            audioPath: audioFile.path.isEmpty ? null : audioFile.path,
          ));
        } catch (_) {
          continue;
        }
      }
      sessions.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) { debugPrint("LibraryScreen: sort error: $e"); }
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

  List<SessionSummary> get _filteredSessions {
    if (_query.isEmpty) return _sessions;
    final q = _query.toLowerCase();
    return _sessions.where((s) => s.title.toLowerCase().contains(q)).toList();
  }

  void _deleteSession(SessionSummary session) {
    final index = _sessions.indexOf(session);
    if (index == -1) return;

    // Remove from UI immediately (optimistic). Actual disk deletion is
    // deferred by 5 s so "Urungkan" can cancel it before data is gone.
    setState(() => _sessions.removeAt(index));
    _pendingDeletions[session.id]?.cancel();
    _pendingDeletions[session.id] = Timer(const Duration(seconds: 5), () {
      _pendingDeletions.remove(session.id);
      try {
        final dir = Directory(session.id);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (e) { debugPrint("LibraryScreen: timer error: $e"); }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${session.title}" dihapus.'),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () {
            _pendingDeletions.remove(session.id)?.cancel();
            if (mounted) {
              setState(() => _sessions.insert(index.clamp(0, _sessions.length), session));
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _exportSession(SessionSummary session) async {
    final bridge = ref.read(rustBridgeProvider);
    final settings = ref.read(settingsProvider);
    await showEksporDialog(
      context,
      session,
      bridge: bridge,
      defaultOutputDir: resolveTilde(settings.libraryPath),
      defaultFormat: settings.defaultExportFormat,
    );
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
                      hintText: 'Cari sesi...',
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
                                      session: session,
                                      onDelete: () => _deleteSession(session),
                                      onExport: () => _exportSession(session),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => TranscriptPlayerScreen(
                                            title: session.title,
                                            durationSeconds: session.durationSeconds,
                                            segments: session.segments,
                                            audioPath: session.audioPath,
                                          ),
                                        ),
                                      ),
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
