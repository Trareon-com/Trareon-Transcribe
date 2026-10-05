import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/global_hotkey_service.dart';
import '../services/library_index.dart';
import '../services/session_store.dart';
import '../services/tray_service.dart';
import '../src/rust/disk.dart' as rust_disk;
import '../src/rust/session.dart' as rust_session;
import '../state/audio_stream_model.dart';
import '../state/audio_watchdog_model.dart';
import '../state/enhance_queue_model.dart';
import '../state/library_model.dart';
import '../state/models.dart';
import '../state/session_model.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_shortcuts.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../utils/format_time.dart';
import '../widgets/app_toast.dart';
import '../widgets/bookmark_bar.dart';
import '../widgets/capture_health_view.dart';
import '../widgets/platform_chrome.dart';
import '../widgets/record_button.dart';
import '../widgets/recovery_dialog.dart';
import '../widgets/session_controls.dart';
import '../widgets/session_sidebar.dart';
import '../widgets/transcript_view.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_chip.dart';
import '../widgets/ui/app_feedback.dart';
import '../widgets/ui/app_field.dart';
import '../widgets/ui/app_surface.dart';
import '../widgets/ui/interactive.dart';
import '../widgets/ui/key_hint.dart';
import 'archive_chat_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'transcript_player_screen.dart';

/// Main window: a permanent session sidebar and one workspace.
///
/// The redesign in blueprint §4 in one sentence: recording history moves
/// out of an unlabelled folder icon and onto the screen, and the workspace
/// has exactly one primary action at a time — a big "Mulai Rekam" when
/// there is nothing to show, the transcript once there is.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final GlobalHotkeyService _globalHotkeys = GlobalHotkeyService();
  final FocusNode _sidebarSearchFocus = FocusNode(debugLabel: 'sidebar-search');
  final _titleController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<rust_session.RecoverableSession> _recoverableSessions = const [];
  bool _loadingRecoveries = true;
  bool _showShortcuts = false;
  bool _sidebarCollapsed = false;
  bool _isStoppingSession = false;
  bool _isStartingSession = false;

  /// Session shown in the workspace instead of the live recording panel.
  SessionRecord? _openSession;
  bool _openingSession = false;

  /// Where to land in [_openSession], when it was opened by a citation
  /// rather than by picking it from the sidebar (F12 / F7).
  double? _openSessionSeek;

  /// Polled while recording so the confirmation badge and the Stop
  /// integrity summary read the same numbers.
  rust_session.CaptureHealth? _captureHealth;
  Timer? _healthTimer;

  /// Set when the auto-save on Stop failed. Stays on screen with a retry
  /// until the transcript is actually on disk — it used to be a
  /// three-second toast over a transcript the user could then only rescue
  /// by guessing that "Ekspor" would do it.
  String? _saveError;
  bool _retryingSave = false;

  /// Free space on the library volume, polled during recording.
  Timer? _diskTimer;
  bool _lowSpaceWarned = false;

  @override
  void initState() {
    super.initState();
    _globalHotkeys.init(
      ref.read(sessionProvider.notifier),
      () => ref.read(sessionProvider).lifecycle,
    );
    _loadRecoveries();
    TrayService.instance.confirmQuit = _confirmQuitWithPendingWork;
  }

  /// Guards [_resumeUnfinishedTranscripts] so it runs once per launch, on
  /// the first completed library load rather than on a timer.
  bool _resumedUnfinished = false;

  /// Gate on the tray's "Keluar" while background work is outstanding.
  ///
  /// Quitting with a completion pass in flight does not lose the work —
  /// the sidecar records which tracks are still untranscribed and
  /// [_resumeUnfinishedTranscripts] picks them up next launch — but it
  /// does mean the transcript stays incomplete until then, which is worth
  /// one dialog.
  Future<bool> _confirmQuitWithPendingWork() async {
    if (!mounted) return true;
    final queue = ref.read(enhanceQueueProvider);
    final recording =
        ref.read(sessionProvider).lifecycle == SessionLifecycle.recording;
    if (!queue.hasPendingWork && !recording) return true;
    final outstanding = queue.jobs
        .where(
          (j) =>
              j.kind == EnhanceJobKind.complete &&
              (j.status == EnhanceJobStatus.queued ||
                  j.status == EnhanceJobStatus.running),
        )
        .length;
    final reasons = [
      if (recording) 'Rekaman masih berjalan.',
      if (outstanding > 0)
        '$outstanding rekaman masih diselesaikan transkripnya, '
            'pekerjaan ini dilanjutkan otomatis saat aplikasi dibuka lagi.',
      if (outstanding == 0 && queue.hasPendingWork)
        'Masih ada transkrip yang sedang diperhalus.',
    ];
    if (!mounted) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar sekarang?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final reason in reasons) Text('• $reason')],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Tetap di aplikasi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Re-queues the completion work the sidecars say is outstanding.
  ///
  /// The queue lives in memory; which tracks are still untranscribed lives
  /// on disk next to the session. Without this, quitting while the
  /// post-stop pass was running would leave those minutes of the meeting
  /// permanently out of the transcript, with the sidecar still claiming
  /// they were coming.
  Future<void> _resumeUnfinishedTranscripts() async {
    if (_resumedUnfinished || !mounted) return;
    _resumedUnfinished = true;
    final entries = ref.read(libraryListProvider).entries;
    if (entries.isEmpty) return;
    try {
      final resumed = await ref
          .read(enhanceQueueProvider.notifier)
          .resumePending([
            for (final entry in entries)
              (dirPath: entry.dirPath, title: entry.title),
          ]);
      if (resumed > 0) {
        debugPrint('resumed $resumed unfinished transcript pass(es)');
      }
    } catch (e) {
      debugPrint('resume of unfinished transcripts failed: $e');
    }
  }

  @override
  void dispose() {
    _globalHotkeys.dispose();
    _healthTimer?.cancel();
    _diskTimer?.cancel();
    _sidebarSearchFocus.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadRecoveries() async {
    final bridge = ref.read(rustBridgeProvider);
    var recoveries = const <rust_session.RecoverableSession>[];
    try {
      recoveries = await bridge.listRecoverableSessions();
    } catch (e) {
      // A throw here — an unreadable recovery directory, a bridge that
      // failed to load — used to leave `_loadingRecoveries` true forever:
      // a sidebar stuck on "Memeriksa sesi…" that also hid the recovery
      // entry point entirely, so a crashed meeting became unreachable.
      // Clearing the loading state matters more than the list; the error is
      // reported rather than swallowed.
      debugPrint('gagal membaca sesi yang bisa dipulihkan: $e');
    }
    if (!mounted) return;
    setState(() {
      _recoverableSessions = recoveries;
      _loadingRecoveries = false;
    });
  }

  /// Capture health is cheap (counters, no I/O) but not free, and nothing
  /// on screen changes faster than a second.
  void _startHealthPolling(String sessionId) {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final health = await _readCaptureHealth(sessionId);
      if (!mounted || health == null) return;
      setState(() => _captureHealth = health);
    });
  }

  Future<rust_session.CaptureHealth?> _readCaptureHealth(
    String sessionId,
  ) async {
    try {
      return await ref.read(rustBridgeProvider).captureHealth(sessionId);
    } catch (_) {
      // The session ended between the tick and the call.
      return null;
    }
  }

  void _stopHealthPolling() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  /// Watches free space on the library volume while recording.
  ///
  /// Nothing in the app had ever asked: three hours of "Rapat Online" is
  /// about 1.4 GB of WAV, and a full disk showed up as a failed save at
  /// the end rather than a warning at the start.
  void _startDiskWatch() {
    _diskTimer?.cancel();
    _lowSpaceWarned = false;
    _diskTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkDiskSpaceWhileRecording(),
    );
  }

  void _stopDiskWatch() {
    _diskTimer?.cancel();
    _diskTimer = null;
  }

  String get _libraryPath =>
      resolveTilde(ref.read(settingsProvider).libraryPath);

  Future<void> _checkDiskSpaceWhileRecording() async {
    final status = await _readDiskSpace();
    if (!mounted || status == null) return;
    switch (status.level) {
      case rust_disk.DiskSpaceLevel.ok:
        _lowSpaceWarned = false;
      case rust_disk.DiskSpaceLevel.low:
        // Once per dip below the threshold, not once per poll.
        if (_lowSpaceWarned) return;
        _lowSpaceWarned = true;
        AppToast.show(context, status.message, type: ToastType.error);
      case rust_disk.DiskSpaceLevel.critical:
        _stopDiskWatch();
        AppToast.show(context, status.message, type: ToastType.error);
        // Stopping on purpose, while writing the transcript still works.
        // Running to ENOSPC would fail the save as well.
        await _handleBerhentiPressed(context, ref, skipConfirmation: true);
    }
  }

  Future<rust_disk.DiskSpaceStatus?> _readDiskSpace() async {
    try {
      return await ref.read(rustBridgeProvider).diskSpace(_libraryPath);
    } catch (_) {
      return null;
    }
  }

  /// Refuses to start on a volume that cannot hold a recording, and warns
  /// on one that is close. Returns false when the session must not start.
  Future<bool> _diskSpaceAllowsRecording(BuildContext context) async {
    final status = await _readDiskSpace();
    if (status == null || !context.mounted) return true;
    if (status.level == rust_disk.DiskSpaceLevel.critical) {
      AppToast.show(
        context,
        'Ruang disk di $_libraryPath tidak cukup untuk merekam. '
        '${status.message} Kosongkan ruang atau ubah lokasi perpustakaan '
        'di Pengaturan.',
        type: ToastType.error,
      );
      return false;
    }
    if (status.level == rust_disk.DiskSpaceLevel.low) {
      AppToast.show(context, status.message, type: ToastType.error);
    }
    return true;
  }

  Future<void> _retrySave({bool elsewhere = false}) async {
    String? outputDir;
    if (elsewhere) {
      outputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Simpan transkrip ke folder lain',
        initialDirectory: _libraryPath,
      );
      if (outputDir == null) return;
    }
    if (!mounted) return;
    setState(() => _retryingSave = true);
    try {
      await ref.read(sessionProvider.notifier).retrySave(outputDir: outputDir);
      if (!mounted) return;
      setState(() => _saveError = null);
      if (context.mounted) {
        AppToast.show(context, 'Transkrip tersimpan.', type: ToastType.success);
      }
    } on TranscribeSaveError catch (e) {
      if (mounted) setState(() => _saveError = '$e');
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _retryingSave = false);
    }
  }

  Future<void> _openRecoveryDialog(BuildContext context) async {
    final isActive = switch (ref.read(sessionProvider).lifecycle) {
      SessionLifecycle.recording || SessionLifecycle.paused => true,
      _ => false,
    };
    final choice = await showRecoveryDialog(
      context,
      _recoverableSessions,
      canRecover: !isActive,
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case RecoverSession(:final session):
        await _recoverSession(context, session);
      case DiscardSession(:final session):
        await _discardSession(context, session);
    }
  }

  Future<void> _recoverSession(
    BuildContext context,
    rust_session.RecoverableSession session,
  ) async {
    final rust_session.RecoveredSession? recovered;
    try {
      recovered = await ref
          .read(sessionProvider.notifier)
          .recoverFromSnapshot(session.snapshot);
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Gagal memulihkan sesi: $e',
          type: ToastType.error,
        );
      }
      return;
    }
    if (!mounted) return;
    _forgetRecoverable(session);
    if (recovered != null) {
      setState(() {
        _openSession = null;
        _openSessionSeek = null;
      });
      _startHealthPolling(recovered.sessionId);
      _startDiskWatch();
    }
    if (!context.mounted || recovered == null) return;
    AppToast.show(
      context,
      '"${session.title}" dipulihkan: ${recovered.segments.length} segmen '
      'dan ${formatDurationId(recovered.resumeOffsetSecs)} audio.',
      type: ToastType.success,
    );
  }

  Future<void> _discardSession(
    BuildContext context,
    rust_session.RecoverableSession session,
  ) async {
    try {
      await ref
          .read(rustBridgeProvider)
          .deleteRecoverableSession(session.snapshot.sessionId);
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Gagal menghapus: $e', type: ToastType.error);
      }
      return;
    }
    if (!mounted) return;
    _forgetRecoverable(session);
    if (!context.mounted) return;
    AppToast.show(context, '"${session.title}" dihapus.');
  }

  /// Banner line. Says what is recoverable, not just how many rows exist:
  /// "Ada 2 sesi yang bisa dipulihkan" told the user nothing about whether
  /// the transcript would actually come back, and for a while it wouldn't.
  static String _recoverySummary(
    List<rust_session.RecoverableSession> sessions,
  ) {
    final segments = sessions.fold<int>(0, (sum, s) => sum + s.segmentCount);
    final audioSecs = sessions.fold<double>(
      0,
      (sum, s) => sum + s.micAudioSecs + s.speakerAudioSecs,
    );
    final count = sessions.length == 1
        ? '1 sesi terhenti'
        : '${sessions.length} sesi terhenti';
    final contents = <String>[
      if (segments > 0) '$segments segmen transkrip',
      if (audioSecs > 0) '${formatDurationId(audioSecs)} audio',
    ];
    if (contents.isEmpty) {
      return '$count tanpa transkrip atau audio yang tersisa.';
    }
    return '$count: ${contents.join(' dan ')} bisa dipulihkan.';
  }

  void _forgetRecoverable(rust_session.RecoverableSession session) {
    setState(() {
      _recoverableSessions = _recoverableSessions
          .where(
            (item) => item.snapshot.sessionId != session.snapshot.sessionId,
          )
          .toList(growable: false);
    });
  }

  Future<void> _handleBerhentiPressed(
    BuildContext context,
    WidgetRef ref, {

    /// Set when the app stops the session itself (out of disk space) —
    /// there is nothing for the user to confirm.
    bool skipConfirmation = false,
  }) async {
    final session = ref.read(sessionProvider);
    final segments = session.segments;
    if (segments.isNotEmpty && !skipConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Berhenti merekam?'),
          content: Text(
            'Sesi ini punya ${segments.length} segmen transkrip. '
            'Sesi akan disimpan otomatis saat berhenti.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Berhenti'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!context.mounted) return;
    // Read the final health *before* stopping: the counters live in the
    // session the stop is about to remove.
    final sessionId = session.sessionId;
    final health = sessionId == null
        ? null
        : await _readCaptureHealth(sessionId);
    if (!context.mounted) return;
    _stopHealthPolling();
    _stopDiskWatch();
    setState(() {
      _isStoppingSession = true;
      _saveError = null;
    });
    var saved = false;
    try {
      await ref.read(sessionProvider.notifier).stop();
      saved = segments.isNotEmpty;
    } on TranscribeSaveError catch (e) {
      // Persistent, not a toast: the transcript is still in memory and
      // recoverable, and the user has to be able to act on that.
      if (mounted) setState(() => _saveError = '$e');
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Gagal menghentikan sesi: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isStoppingSession = false);
    }
    // The session just written belongs in the sidebar without a restart.
    unawaited(ref.read(libraryListProvider.notifier).refresh());
    if (!context.mounted) return;

    // A channel that recorded nothing is worth a dialog the user has to
    // dismiss; a clean session is worth a toast and no interruption.
    if (health != null && health.warnings.isNotEmpty) {
      await showCaptureIntegrityDialog(context, health, saved: saved);
    } else if (saved) {
      AppToast.show(
        context,
        'Sesi tersimpan (${segments.length} segmen).',
        type: ToastType.success,
      );
    }
    if (mounted) setState(() => _captureHealth = null);
  }

  // ── Bookmarks (F9) ────────────────────────────────────────────────────

  /// Ctrl+B: drops a marker at the current position and says so. Deliberately
  /// no dialog — the point of a one-key marker is that it does not interrupt
  /// the meeting.
  void _addBookmark() {
    final bookmark = ref.read(sessionProvider.notifier).addBookmark();
    if (!mounted) return;
    if (bookmark == null) {
      AppToast.show(
        context,
        'Belum ada rekaman untuk ditandai.',
        type: ToastType.info,
      );
      return;
    }
    AppToast.show(
      context,
      'Ditandai di ${formatTimestamp(bookmark.timestamp)}.',
      type: ToastType.success,
    );
  }

  /// Drops the marker first, then asks for the note: the timestamp must be
  /// the moment the user acted, not the moment they finished typing.
  Future<void> _addBookmarkWithNote() async {
    final notifier = ref.read(sessionProvider.notifier);
    final bookmark = notifier.addBookmark();
    if (bookmark == null) {
      if (mounted) {
        AppToast.show(
          context,
          'Belum ada rekaman untuk ditandai.',
          type: ToastType.info,
        );
      }
      return;
    }
    if (!mounted) return;
    final note = await showBookmarkNoteDialog(
      context,
      timestamp: bookmark.timestamp,
    );
    if (note != null && note.trim().isNotEmpty) {
      notifier.setBookmarkNote(bookmark.timestamp, note);
    }
  }

  Future<void> _editBookmarkNote(Bookmark bookmark) async {
    final note = await showBookmarkNoteDialog(
      context,
      timestamp: bookmark.timestamp,
      initial: bookmark.note,
    );
    if (note == null || !mounted) return;
    ref
        .read(sessionProvider.notifier)
        .setBookmarkNote(bookmark.timestamp, note);
  }

  Future<void> _toggleStartBerhenti(BuildContext context, WidgetRef ref) async {
    final lifecycle = ref.read(sessionProvider).lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording ||
        lifecycle == SessionLifecycle.paused;
    if (isActive) {
      await _handleBerhentiPressed(context, ref);
      return;
    }
    // Recording always takes over the workspace: starting a session while
    // reading an old one and having the new transcript appear nowhere
    // visible is how a recording gets lost.
    if (_openSession != null) {
      setState(() {
        _openSession = null;
        _openSessionSeek = null;
      });
    }
    // start() can hang for a long time with zero other feedback while
    // waiting on a native macOS permission dialog (e.g. first-ever Webinar/
    // system-audio capture) — without this the record button just looks
    // unresponsive to a click that's actually still in flight.
    if (!await _diskSpaceAllowsRecording(context)) return;
    if (!context.mounted) return;
    setState(() => _isStartingSession = true);
    try {
      await ref.read(sessionProvider.notifier).start();
      final id = ref.read(sessionProvider).sessionId;
      if (id != null) {
        _startHealthPolling(id);
        _startDiskWatch();
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, '$e');
    } finally {
      if (mounted) setState(() => _isStartingSession = false);
    }
  }

  Future<void> _onEkspor(BuildContext context) async {
    final session = ref.read(sessionProvider);
    if (session.segments.isEmpty) {
      AppToast.show(context, 'Tidak ada transkrip untuk diekspor.');
      return;
    }
    final settings = ref.read(settingsProvider);
    final defaultDir = resolveTilde(settings.libraryPath);
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih folder ekspor',
      initialDirectory: defaultDir,
    );
    if (selectedDir == null) return;
    if (!context.mounted) return;
    try {
      final bridge = ref.read(rustBridgeProvider);
      final title = session.sessionTitle.isNotEmpty
          ? session.sessionTitle
          : 'Sesi ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}';
      await bridge.exportSession(
        segments: session.segments,
        outputDir: selectedDir,
        title: title,
      );
      if (!context.mounted) return;
      AppToast.show(
        context,
        'Ekspor berhasil ke: $selectedDir',
        type: ToastType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Ekspor gagal: $e', type: ToastType.error);
    }
  }

  // --- Navigation -----------------------------------------------------

  void _openSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  Future<void> _openLibrary({int tab = 0}) async {
    final libraryPath = resolveTilde(ref.read(settingsProvider).libraryPath);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LibraryScreen(libraryPath: libraryPath, initialTab: tab),
      ),
    );
    if (mounted) unawaited(ref.read(libraryListProvider.notifier).refresh());
  }

  /// Opens "Tanya Arsip Rapat" (F12). A citation in an answer brings the
  /// user back here with the right session open at the right moment.
  Future<void> _openArchiveChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArchiveChatScreen(
          onOpenSession: (dirPath, timestamp) {
            Navigator.of(context).pop();
            final entry = ref
                .read(libraryListProvider)
                .entries
                .where((e) => e.dirPath == dirPath)
                .firstOrNull;
            if (entry != null) {
              unawaited(_selectSession(entry, seekSeconds: timestamp));
            }
          },
        ),
      ),
    );
  }

  /// Loads a session's transcript and shows it in the workspace.
  ///
  /// [seekSeconds] is set when a citation chose the moment as well as the
  /// meeting; null leaves the player at the start as before.
  Future<void> _selectSession(LibraryEntry entry, {double? seekSeconds}) async {
    setState(() => _openingSession = true);
    final record = await loadSessionRecord(entry.dirPath);
    if (!mounted) return;
    setState(() {
      _openingSession = false;
      _openSession = record;
      _openSessionSeek = record == null ? null : seekSeconds;
    });
    if (record == null && context.mounted) {
      AppToast.show(
        context,
        '"${entry.title}" tidak bisa dibuka.',
        type: ToastType.error,
      );
    }
  }

  void _newSession() {
    setState(() {
      _openSession = null;
      _openSessionSeek = null;
    });
    _sidebarSearchFocus.unfocus();
  }

  /// Collapses the sidebar to a 48 px icon rail and back.
  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  void _focusSidebarSearch() {
    if (_scaffoldKey.currentState?.hasDrawer == true &&
        !(_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      _scaffoldKey.currentState?.openDrawer();
    }
    _sidebarSearchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final lifecycle = session.lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording ||
        lifecycle == SessionLifecycle.paused;
    final isPaused = lifecycle == SessionLifecycle.paused;
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final vuLevel = ref.watch(vuLevelProvider).valueOrNull;

    // The first completed library load is the earliest moment the sidecars
    // are known, and the latest one at which an unfinished transcript
    // should still be waiting. Keyed off the load rather than a timer so
    // nothing is left pending in a widget test.
    ref.listen<LibraryListState>(libraryListProvider, (previous, next) {
      if (!next.loading && next.entries.isNotEmpty) {
        unawaited(_resumeUnfinishedTranscripts());
      }
    });

    // Keep the title controller in sync with auto-detected session title
    // (set by the Rust bridge on session start via detectFrontmostWindowTitle).
    ref.listen(sessionProvider.select((s) => s.sessionTitle), (_, next) {
      if (_titleController.text != next) {
        _titleController.text = next;
        _titleController.selection = TextSelection.fromPosition(
          TextPosition(offset: next.length),
        );
      }
    });

    // No-audio watchdog: warns once if recording has been running for a
    // while with zero signal on any enabled source (see
    // audio_watchdog_model.dart for why this can happen silently).
    ref.listen(audioWatchdogProvider, (_, warning) {
      if (warning == null) return;
      AppToast.show(context, warning, type: ToastType.error);
      ref.read(audioWatchdogProvider.notifier).acknowledge();
    });

    // Capture problems the engine reports directly: a source that couldn't be
    // opened at start, or one that died mid-recording. Faster and far more
    // specific than the silence watchdog above, which can only infer trouble
    // after twelve seconds of nothing.
    ref.listen(sessionNoticeProvider, (_, next) {
      final notice = next.valueOrNull;
      if (notice == null) return;
      AppToast.show(context, notice.message, type: ToastType.error);
    });

    final sidebar = SessionSidebar(
      selectedDirPath: _openSession?.dirPath,
      onSelect: (entry) {
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
        }
        _selectSession(entry);
      },
      onNewSession: () {
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
        }
        _newSession();
      },
      onOpenLibrary: () => _openLibrary(),
      onOpenUpload: () => _openLibrary(tab: 1),
      onOpenSettings: _openSettings,
      onOpenArchiveChat: _openArchiveChat,
      searchFocusNode: _sidebarSearchFocus,
      isRecording: isActive,
      collapsed: _sidebarCollapsed,
      onToggleCollapsed: _toggleSidebar,
    );

    return AppPlatformMenuBar(
      onNewSession: _newSession,
      onToggleRecording: () => _toggleStartBerhenti(context, ref),
      onOpenSettings: _openSettings,
      onFocusSearch: _focusSidebarSearch,
      onToggleSidebar: _toggleSidebar,
      onShowShortcuts: () => setState(() => _showShortcuts = true),
      child: CallbackShortcuts(
        bindings: {
          for (final activator in AppShortcuts.startStop.activators)
            activator: () => _toggleStartBerhenti(context, ref),
          for (final activator in AppShortcuts.pauseResume.activators)
            activator: () {
              if (isPaused) {
                notifier.resume();
              } else if (lifecycle == SessionLifecycle.recording) {
                notifier.pause();
              }
            },
          // The history is already on screen, so this focuses the sidebar
          // search rather than pushing a separate library screen.
          for (final activator in AppShortcuts.searchSessions.activators)
            activator: _focusSidebarSearch,
          for (final activator in AppShortcuts.settings.activators)
            activator: _openSettings,
          for (final activator in AppShortcuts.shortcutsPanel.activators)
            activator: () => setState(() => _showShortcuts = !_showShortcuts),
          // Tandai poin penting (F9). One key, no dialog: the point of a
          // one-key marker is that it does not interrupt the meeting.
          for (final activator in AppShortcuts.bookmark.activators)
            activator: _addBookmark,
          for (final activator in AppShortcuts.toggleSidebar.activators)
            activator: _toggleSidebar,
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final persistentSidebar =
                  constraints.maxWidth >= kSidebarPersistentMinWidth;
              return Scaffold(
                key: _scaffoldKey,
                backgroundColor: colors.background,
                drawer: persistentSidebar
                    ? null
                    : Drawer(
                        child: SessionSidebar(
                          selectedDirPath: _openSession?.dirPath,
                          onSelect: (entry) {
                            Navigator.of(context).pop();
                            _selectSession(entry);
                          },
                          onNewSession: () {
                            Navigator.of(context).pop();
                            _newSession();
                          },
                          onOpenLibrary: () => _openLibrary(),
                          onOpenUpload: () => _openLibrary(tab: 1),
                          onOpenSettings: _openSettings,
                          onOpenArchiveChat: _openArchiveChat,
                          searchFocusNode: _sidebarSearchFocus,
                          isRecording: isActive,
                        ),
                      ),
                // The drag strip and the caption buttons live at the root, in
                // WindowChromeScaffold, so that every route has them. Repeating
                // them here drew a second row of buttons under the first.
                body: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (persistentSidebar) sidebar,
                          Expanded(
                            child: _Workspace(
                              showMenuButton: !persistentSidebar,
                              onOpenMenu: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                              session: session,
                              notifier: notifier,
                              isActive: isActive,
                              isPaused: isPaused,
                              openSession: _openSession,
                              openingSession: _openingSession,
                              openSessionSeek: _openSessionSeek,
                              onCloseSession: _newSession,
                              vuLevel: vuLevel,
                              captureHealth: _captureHealth,
                              titleController: _titleController,
                              onStartBerhenti: () =>
                                  _toggleStartBerhenti(context, ref),
                              onEkspor: () => _onEkspor(context),
                              isBusy: _isStoppingSession || _isStartingSession,
                              busyLabel: _isStartingSession
                                  ? 'Memulai…'
                                  : 'Menyimpan…',
                              saveError: _saveError,
                              retryingSave: _retryingSave,
                              onRetrySave: () => _retrySave(),
                              onSaveElsewhere: () =>
                                  _retrySave(elsewhere: true),
                              loadingRecoveries: _loadingRecoveries,
                              recoverySummary: _recoverableSessions.isEmpty
                                  ? null
                                  : _recoverySummary(_recoverableSessions),
                              onOpenRecovery: () =>
                                  _openRecoveryDialog(context),
                              showShortcuts: _showShortcuts,
                              onCloseShortcuts: () =>
                                  setState(() => _showShortcuts = false),
                              onShowShortcuts: () =>
                                  setState(() => _showShortcuts = true),
                              onAddBookmark: _addBookmark,
                              onAddBookmarkWithNote: () =>
                                  unawaited(_addBookmarkWithNote()),
                              onRemoveBookmark: (bookmark) => ref
                                  .read(sessionProvider.notifier)
                                  .removeBookmark(bookmark.timestamp),
                              onEditBookmarkNote: (bookmark) =>
                                  unawaited(_editBookmarkNote(bookmark)),
                              onSessionEdited: (dirPath) => unawaited(
                                ref
                                    .read(libraryListProvider.notifier)
                                    .refreshOne(dirPath),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.showMenuButton,
    required this.onOpenMenu,
    required this.session,
    required this.notifier,
    required this.isActive,
    required this.isPaused,
    required this.openSession,
    required this.openingSession,
    this.openSessionSeek,
    required this.onCloseSession,
    required this.vuLevel,
    required this.captureHealth,
    required this.titleController,
    required this.onStartBerhenti,
    required this.onEkspor,
    required this.isBusy,
    required this.busyLabel,
    required this.saveError,
    required this.retryingSave,
    required this.onRetrySave,
    required this.onSaveElsewhere,
    required this.loadingRecoveries,
    required this.recoverySummary,
    required this.onOpenRecovery,
    required this.showShortcuts,
    required this.onCloseShortcuts,
    required this.onShowShortcuts,
    required this.onAddBookmark,
    required this.onAddBookmarkWithNote,
    required this.onRemoveBookmark,
    required this.onEditBookmarkNote,
    required this.onSessionEdited,
  });

  final bool showMenuButton;
  final VoidCallback onOpenMenu;
  final SessionUiState session;
  final SessionNotifier notifier;
  final bool isActive;
  final bool isPaused;
  final SessionRecord? openSession;
  final bool openingSession;
  final double? openSessionSeek;
  final VoidCallback onCloseSession;
  final VuLevel? vuLevel;
  final rust_session.CaptureHealth? captureHealth;
  final TextEditingController titleController;
  final VoidCallback onStartBerhenti;
  final VoidCallback onEkspor;
  final bool isBusy;
  final String busyLabel;
  final String? saveError;
  final bool retryingSave;
  final VoidCallback onRetrySave;
  final VoidCallback onSaveElsewhere;
  final bool loadingRecoveries;
  final String? recoverySummary;
  final VoidCallback onOpenRecovery;
  final bool showShortcuts;
  final VoidCallback onCloseShortcuts;

  /// Opens the shortcuts panel from the footer hint.
  final VoidCallback onShowShortcuts;
  final VoidCallback onAddBookmark;
  final VoidCallback onAddBookmarkWithNote;
  final void Function(Bookmark) onRemoveBookmark;
  final void Function(Bookmark) onEditBookmarkNote;
  final ValueChanged<String> onSessionEdited;

  @override
  Widget build(BuildContext context) {
    final hasTranscript = session.segments.isNotEmpty;

    // A shape-matched skeleton, not a bare spinner in the middle of an empty
    // pane: the transcript that is loading has a known shape.
    if (openingSession) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.xl),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: Measure.reading,
            child: AppSkeletonList(rows: 8),
          ),
        ),
      );
    }

    final opened = openSession;
    if (opened != null) {
      return TranscriptPlayerScreen(
        // The seek is part of the key: a second citation into a session
        // that is already open has to re-enter the player, otherwise the
        // jump silently does nothing.
        key: ValueKey('${opened.dirPath}@${openSessionSeek ?? 0}'),
        initialSeekSeconds: openSessionSeek,
        title: opened.title,
        durationSeconds: opened.durationSeconds,
        segments: opened.segments,
        audioPath: opened.audioPath,
        sessionDirPath: opened.dirPath,
        meta: opened.meta,
        onClose: onCloseSession,
        onSegmentsChanged: (_) => onSessionEdited(opened.dirPath),
      );
    }

    // Three workspace states, in the order a meeting goes through them.
    //
    // Idle is a hero: one headline, three explained mode cards, the two
    // capture chips, and one filled button. Blueprint §4.2 asks for exactly
    // one primary action on an empty screen, and the old layout put nine
    // controls above the fold before you could reach it.
    final idle = !hasTranscript && !isActive;

    return Column(
      children: [
        if (saveError != null)
          _SaveFailedBanner(
            message: saveError!,
            busy: retryingSave,
            onRetry: onRetrySave,
            onSaveElsewhere: onSaveElsewhere,
          ),
        if (loadingRecoveries)
          const AppLinearProgress(height: Strokes.focusRing)
        else if (recoverySummary != null)
          _RecoveryBanner(summary: recoverySummary!, onOpen: onOpenRecovery),
        if (isActive)
          _RecordingStrip(
            showMenuButton: showMenuButton,
            onOpenMenu: onOpenMenu,
            elapsedSeconds: session.elapsedSeconds,
            isPaused: isPaused,
            mode: session.config.mode,
            micEnabled: session.config.micEnabled,
            speakerEnabled: session.config.speakerEnabled,
            onMicToggled: notifier.toggleMic,
            onSpeakerToggled: notifier.toggleSpeaker,
            vuLevel: vuLevel,
            captureHealth: captureHealth,
            onStartBerhenti: onStartBerhenti,
            onAddBookmark: onAddBookmark,
            isBusy: isBusy,
            busyLabel: busyLabel,
          )
        else if (!idle)
          _SessionStrip(
            showMenuButton: showMenuButton,
            onOpenMenu: onOpenMenu,
            notifier: notifier,
            mode: session.config.mode,
            titleController: titleController,
            onEkspor: onEkspor,
            onStartBerhenti: onStartBerhenti,
            isBusy: isBusy,
            busyLabel: busyLabel,
          )
        else if (showMenuButton)
          _CompactMenuBar(onOpenMenu: onOpenMenu),
        if (!idle)
          BookmarkBar(
            bookmarks: session.bookmarks,
            live: isActive,
            onAdd: onAddBookmark,
            onAddWithNote: onAddBookmarkWithNote,
            onRemove: onRemoveBookmark,
            onEditNote: onEditBookmarkNote,
          ),
        Expanded(
          child: Stack(
            children: [
              if (idle)
                _IdleHero(
                  titleController: titleController,
                  mode: session.config.mode,
                  onModeChanged: notifier.setMode,
                  micEnabled: session.config.micEnabled,
                  speakerEnabled: session.config.speakerEnabled,
                  onMicToggled: notifier.toggleMic,
                  onSpeakerToggled: notifier.toggleSpeaker,
                  onStart: onStartBerhenti,
                  busy: isBusy,
                  busyLabel: busyLabel,
                )
              else
                TranscriptView(
                  segments: session.segments,
                  revision: session.revision,
                  onRenameSpeaker: notifier.renameSpeaker,
                  tentativeText: session.tentativeText,
                ),
              if (showShortcuts)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _ShortcutsPanel(onClose: onCloseShortcuts),
                ),
            ],
          ),
        ),
        _FooterBar(
          lifecycle: session.lifecycle,
          segmentsCount: session.segments.length,
          elapsedSeconds: session.elapsedSeconds,
          onShowShortcuts: onShowShortcuts,
        ),
      ],
    );
  }
}

/// The idle screen: one headline, the mode decision as three explained cards,
/// the two capture chips, and one filled button.
class _IdleHero extends StatelessWidget {
  const _IdleHero({
    required this.titleController,
    required this.mode,
    required this.onModeChanged,
    required this.micEnabled,
    required this.speakerEnabled,
    required this.onMicToggled,
    required this.onSpeakerToggled,
    required this.onStart,
    required this.busy,
    required this.busyLabel,
  });

  final TextEditingController titleController;
  final SessionMode mode;
  final ValueChanged<SessionMode> onModeChanged;
  final bool micEnabled;
  final bool speakerEnabled;
  final ValueChanged<bool> onMicToggled;
  final ValueChanged<bool> onSpeakerToggled;
  final VoidCallback onStart;
  final bool busy;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The hero sheds weight in two stages as the pane gets shorter, so the
        // one action this screen exists for is never pushed below the fold.
        // It is still inside a scroll view, but a record button you have to
        // scroll to find is a broken empty state, not a scrollable one.
        //
        //   >= 660: headline and the offline reassurance line
        //   >= 600: the one-line explanation under each mode card
        //    < 600: cards are name and glyph only
        final showIntro = constraints.maxHeight >= 660;
        final showExplanations = constraints.maxHeight >= 600;
        final wide = constraints.maxWidth >= Measure.hero + Spacing.xxxl * 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xl,
            vertical: Spacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: DeviceStatusChip.width * 2 + Spacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showIntro) ...[
                    Text(
                      'Siap merekam',
                      textAlign: TextAlign.center,
                      style: AppText.title.c(colors.text),
                    ),
                    Spacing.gapSm,
                    Text(
                      'Semua transkripsi berjalan di komputer ini. '
                      'Tidak ada audio yang keluar.',
                      textAlign: TextAlign.center,
                      style: AppText.body.c(colors.textSecondary),
                    ),
                    Spacing.gapXl,
                  ],
                  SizedBox(
                    width: Measure.sidebar,
                    child: Align(
                      alignment: Alignment.center,
                      child: AppTextField(
                        controller: titleController,
                        placeholder: 'Judul sesi…',
                        prefixIcon: AppIcons.edit,
                        reserveHelperSpace: false,
                      ),
                    ),
                  ),
                  Spacing.gapLg,
                  _ModeCards(
                    mode: mode,
                    onChanged: onModeChanged,
                    stacked: !wide,
                    showExplanations: showExplanations,
                  ),
                  Spacing.gapLg,
                  DeviceGroup(
                    compact: true,
                    micEnabled: micEnabled,
                    speakerEnabled: speakerEnabled,
                    onMicToggled: onMicToggled,
                    onSpeakerToggled: onSpeakerToggled,
                    micLevel: 0,
                    speakerLevel: 0,
                    live: false,
                  ),
                  Spacing.gapXl,
                  Center(
                    child: RecordButton(
                      large: true,
                      isRecording: false,
                      isPaused: false,
                      isBusy: busy,
                      busyLabel: busyLabel,
                      onPressed: onStart,
                    ),
                  ),
                  Spacing.gapMd,
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'atau tekan',
                          style: AppText.caption.c(colors.textTertiary),
                        ),
                        Spacing.hSm,
                        KeyHint(AppShortcuts.startStop.shortcut),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The three capture modes as cards: a glyph, a name, and one line saying what
/// each one actually records. A bare three-way segmented control tells a
/// first-time notulis nothing about the difference.
class _ModeCards extends StatelessWidget {
  const _ModeCards({
    required this.mode,
    required this.onChanged,
    required this.stacked,
    required this.showExplanations,
  });

  final SessionMode mode;
  final ValueChanged<SessionMode> onChanged;
  final bool stacked;
  final bool showExplanations;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final m in kModeOrder)
        _ModeCard(
          mode: m,
          selected: m == mode,
          onPressed: () => onChanged(m),
          showExplanation: showExplanations,
        ),
    ];
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) Spacing.gapSm,
            cards[i],
          ],
        ],
      );
    }
    // IntrinsicHeight so the three cards match the tallest one. Without it a
    // `stretch` Row inside the hero's scroll view is handed an infinite
    // height constraint and throws.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) Spacing.hSm,
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onPressed,
    required this.showExplanation,
  });

  final SessionMode mode;
  final bool selected;
  final VoidCallback onPressed;
  final bool showExplanation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    return Interactive(
      onPressed: onPressed,
      borderRadius: Radii.lgAll,
      selected: selected,
      semanticLabel: modeSemantics(mode),
      builder: (context, state) => AnimatedContainer(
        duration: motion.fast,
        curve: AppEasing.standard,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: selected
              ? colors.primarySubtle
              : state.active
              ? colors.surfaceSunken
              : colors.surface,
          borderRadius: Radii.lgAll,
          border: Border.all(
            color: selected ? colors.primary : colors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // The tick replaces the mode glyph rather than being appended:
                // a third thing in the row costs the label the width it needs,
                // and "Rapat Online" was being truncated to "Rapat Onl…".
                Icon(
                  selected ? AppIcons.checkPlain : modeIcon(mode),
                  size: IconSizes.md,
                  color: selected ? colors.primaryText : colors.textSecondary,
                ),
                Spacing.hSm,
                Expanded(
                  child: Text(
                    mode.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.subheading.c(
                      selected ? colors.primaryText : colors.text,
                    ),
                  ),
                ),
              ],
            ),
            if (showExplanation) ...[
              Spacing.gapXs,
              Text(
                modeExplanation(mode),
                style: AppText.caption.c(colors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The strip above the transcript while a session is running: the timer, the
/// live level per channel, the capture-health badge, bookmark and stop.
class _RecordingStrip extends StatelessWidget {
  const _RecordingStrip({
    required this.showMenuButton,
    required this.onOpenMenu,
    required this.elapsedSeconds,
    required this.isPaused,
    required this.mode,
    required this.micEnabled,
    required this.speakerEnabled,
    required this.onMicToggled,
    required this.onSpeakerToggled,
    required this.vuLevel,
    required this.captureHealth,
    required this.onStartBerhenti,
    required this.onAddBookmark,
    required this.isBusy,
    required this.busyLabel,
  });

  final bool showMenuButton;
  final VoidCallback onOpenMenu;
  final double elapsedSeconds;
  final bool isPaused;
  final SessionMode mode;
  final bool micEnabled;
  final bool speakerEnabled;
  final ValueChanged<bool> onMicToggled;
  final ValueChanged<bool> onSpeakerToggled;
  final VuLevel? vuLevel;
  final rust_session.CaptureHealth? captureHealth;
  final VoidCallback onStartBerhenti;
  final VoidCallback onAddBookmark;
  final bool isBusy;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md,
        Spacing.lg,
        Spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two capture chips plus a waveform need about 640 px. Below that
          // the waveform moves under the chips rather than being squeezed to
          // nothing, and the mode badge drops out of the timer row.
          final roomy = constraints.maxWidth >= 640;
          final waveform = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              LiveWaveform(
                live: !isPaused,
                level: _loudest(vuLevel, micEnabled, speakerEnabled),
                color: colors.primary,
              ),
              Spacing.gapSm,
              // The waveform alone cannot distinguish "recording" from "open
              // but silent"; the badge is what says audio actually arrived
              // and was written.
              CaptureConfirmationBadge(health: captureHealth),
            ],
          );
          final devices = DeviceGroup(
            compact: true,
            micEnabled: micEnabled,
            speakerEnabled: speakerEnabled,
            onMicToggled: onMicToggled,
            onSpeakerToggled: onSpeakerToggled,
            micLevel: vuLevel?.micLevel ?? 0,
            speakerLevel: vuLevel?.speakerLevel ?? 0,
            live: true,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (showMenuButton) ...[
                    AppIconButton(
                      icon: AppIcons.menu,
                      tooltip: 'Riwayat sesi',
                      onPressed: onOpenMenu,
                    ),
                    Spacing.hSm,
                  ],
                  RecordingDot(live: !isPaused),
                  Spacing.hMd,
                  Semantics(
                    label: 'Durasi rekaman',
                    child: Text(
                      formatElapsed(elapsedSeconds),
                      style: AppText.monoTimer.c(colors.text),
                    ),
                  ),
                  if (roomy) ...[
                    Spacing.hMd,
                    AppStatusBadge(
                      label: isPaused ? 'Dijeda' : mode.label,
                      status: isPaused
                          ? AppStatus.warning
                          : AppStatus.recording,
                      dot: !isPaused,
                      icon: isPaused ? AppIcons.pause : null,
                    ),
                  ],
                  const Spacer(),
                  AppIconButton(
                    icon: AppIcons.bookmarkAdd,
                    tooltip:
                        'Tandai poin penting '
                        '(${AppShortcuts.bookmark.shortcut.label})',
                    onPressed: onAddBookmark,
                  ),
                  Spacing.hSm,
                  RecordButton(
                    isRecording: true,
                    isPaused: isPaused,
                    isBusy: isBusy,
                    busyLabel: busyLabel,
                    onPressed: onStartBerhenti,
                  ),
                ],
              ),
              Spacing.gapMd,
              if (roomy)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    devices,
                    Spacing.hLg,
                    Expanded(child: waveform),
                  ],
                )
              else ...[
                devices,
                Spacing.gapMd,
                waveform,
              ],
            ],
          );
        },
      ),
    );
  }

  static double _loudest(VuLevel? level, bool mic, bool speaker) {
    if (level == null) return 0;
    final values = <double>[
      if (mic) level.micLevel,
      if (speaker) level.speakerLevel,
    ];
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b);
  }
}

/// The strip shown over a finished transcript that has not been saved away
/// yet: title, mode, export and the record button.
class _SessionStrip extends StatelessWidget {
  const _SessionStrip({
    required this.showMenuButton,
    required this.onOpenMenu,
    required this.notifier,
    required this.mode,
    required this.titleController,
    required this.onEkspor,
    required this.onStartBerhenti,
    required this.isBusy,
    required this.busyLabel,
  });

  final bool showMenuButton;
  final VoidCallback onOpenMenu;
  final SessionNotifier notifier;
  final SessionMode mode;
  final TextEditingController titleController;
  final VoidCallback onEkspor;
  final VoidCallback onStartBerhenti;
  final bool isBusy;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md,
        Spacing.lg,
        Spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showMenuButton) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs / 2),
              child: AppIconButton(
                icon: AppIcons.menu,
                tooltip: 'Riwayat sesi',
                onPressed: onOpenMenu,
              ),
            ),
            Spacing.hSm,
          ],
          Expanded(
            child: SessionControlGroup(
              titleController: titleController,
              onTitleChanged: notifier.setTitle,
              mode: mode,
              onModeChanged: notifier.setMode,
              modeLocked: false,
            ),
          ),
          Spacing.hMd,
          AppButton(
            label: 'Ekspor',
            icon: AppIcons.download,
            onPressed: onEkspor,
          ),
          Spacing.hSm,
          RecordButton(
            isRecording: false,
            isPaused: false,
            isBusy: isBusy,
            busyLabel: busyLabel,
            onPressed: onStartBerhenti,
          ),
        ],
      ),
    );
  }
}

/// Just the drawer button, for the idle hero in a narrow window.
class _CompactMenuBar extends StatelessWidget {
  const _CompactMenuBar({required this.onOpenMenu});

  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AppIconButton(
          icon: AppIcons.menu,
          tooltip: 'Riwayat sesi',
          onPressed: onOpenMenu,
        ),
      ),
    );
  }
}

/// Stays on screen until the transcript is actually on disk.
///
/// The failure it reports used to be a three-second toast, after which the
/// only route to the transcript still sitting in memory was to guess that
/// "Ekspor" would save it.
class _SaveFailedBanner extends StatelessWidget {
  const _SaveFailedBanner({
    required this.message,
    required this.busy,
    required this.onRetry,
    required this.onSaveElsewhere,
  });

  final String message;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onSaveElsewhere;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.errorSubtle,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Row(
        children: [
          Icon(AppIcons.error, size: IconSizes.md, color: colors.error),
          Spacing.hMd,
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                '$message Transkrip masih ada di memori, jangan tutup '
                'aplikasi sebelum tersimpan.',
                style: AppText.body.c(colors.text),
              ),
            ),
          ),
          Spacing.hSm,
          AppButton.ghost(
            label: 'Simpan ke folder lain',
            onPressed: busy ? null : onSaveElsewhere,
          ),
          Spacing.hSm,
          AppButton.primary(
            label: busy ? 'Menyimpan…' : 'Coba Lagi',
            loading: busy,
            onPressed: busy ? null : onRetry,
          ),
        ],
      ),
    );
  }
}

/// "A meeting stopped without being saved." Says what is recoverable, not just
/// how many rows exist.
class _RecoveryBanner extends StatelessWidget {
  const _RecoveryBanner({required this.summary, required this.onOpen});

  final String summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.infoSubtle,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Row(
        children: [
          Icon(AppIcons.restore, size: IconSizes.md, color: colors.info),
          Spacing.hMd,
          Expanded(child: Text(summary, style: AppText.body.c(colors.text))),
          Spacing.hSm,
          // No "Abaikan": it hid the banner without deleting anything, so the
          // same sessions reappeared on every launch forever.
          AppButton(label: 'Lihat & Pulihkan', onPressed: onOpen),
        ],
      ),
    );
  }
}

/// Footer: the elapsed timer, the segment count, and the shortcut hint.
class _FooterBar extends StatelessWidget {
  const _FooterBar({
    required this.lifecycle,
    required this.segmentsCount,
    required this.onShowShortcuts,
    this.elapsedSeconds = 0,
  });

  final SessionLifecycle lifecycle;
  final int segmentsCount;
  final double elapsedSeconds;

  /// The hint is a control, not decoration: a keyboard affordance that can
  /// only be reached with the keyboard helps nobody who does not already
  /// know it is there.
  final VoidCallback onShowShortcuts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isRecording = lifecycle == SessionLifecycle.recording;
    final isPaused = lifecycle == SessionLifecycle.paused;

    return Container(
      height: ControlSizes.md,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: [
          if (isRecording || isPaused) ...[
            RecordingDot(size: Spacing.sm - 2, live: isRecording),
            Spacing.hSm,
            Text(
              formatElapsed(elapsedSeconds),
              style: AppText.monoMicro.c(colors.textSecondary),
            ),
            Spacing.hLg,
          ],
          if (segmentsCount > 0) ...[
            Icon(
              AppIcons.segments,
              size: IconSizes.xs,
              color: colors.textTertiary,
            ),
            Spacing.hXs,
            Text(
              '$segmentsCount segmen',
              style: AppText.monoMicro.c(colors.textTertiary),
            ),
          ],
          const Spacer(),
          Interactive(
            onPressed: onShowShortcuts,
            borderRadius: Radii.smAll,
            semanticLabel: 'Tampilkan pintasan keyboard',
            builder: (context, state) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs / 2,
              ),
              decoration: BoxDecoration(
                color: state.active ? colors.hoverOverlay : Colors.transparent,
                borderRadius: Radii.smAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pintasan', style: AppText.micro.c(colors.textTertiary)),
                  Spacing.hSm,
                  KeyHint(AppShortcuts.shortcutsPanel.shortcut),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// hh:mm:ss (or mm:ss under an hour), in tabular figures so it does not
/// reflow once a second.
String formatElapsed(double secs) {
  final total = secs.floor();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// The keyboard shortcut panel, built from the one shortcut table so it cannot
/// list a binding the app does not actually have.
class _ShortcutsPanel extends StatelessWidget {
  const _ShortcutsPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppSurface(
      elevation: Elevation.modal,
      radius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.lg,
        Spacing.md,
        Spacing.lg,
      ),
      // Capped and centred: at 1920 px an uncapped panel puts every keycap a
      // screen-width away from the action it belongs to.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Measure.reading),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pintasan keyboard',
                      style: AppText.heading.c(colors.text),
                    ),
                  ),
                  AppIconButton(
                    icon: AppIcons.close,
                    tooltip: 'Tutup',
                    size: IconSizes.md,
                    onPressed: onClose,
                  ),
                ],
              ),
              Spacing.gapSm,
              for (final action in AppShortcuts.all)
                KeyHintRow(label: action.label, shortcut: action.shortcut),
            ],
          ),
        ),
      ),
    );
  }
}
