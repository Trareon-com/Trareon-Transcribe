import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/global_hotkey_service.dart';
import '../services/library_index.dart';
import '../services/session_store.dart';
import '../services/tray_service.dart';
import '../state/audio_stream_model.dart';
import '../state/enhance_queue_model.dart';
import '../state/audio_watchdog_model.dart';
import '../state/library_model.dart';
import '../state/models.dart';
import '../state/session_model.dart';
import '../state/settings_model.dart';
import '../src/rust/disk.dart' as rust_disk;
import '../src/rust/session.dart' as rust_session;
import '../theme/app_colors.dart';
import '../utils/format_time.dart';
import '../widgets/app_toast.dart';
import '../widgets/bookmark_bar.dart';
import '../widgets/capture_health_view.dart';
import '../widgets/recovery_dialog.dart';
import '../widgets/session_controls.dart';
import '../widgets/session_sidebar.dart';
import '../widgets/animated_record_button.dart';
import '../widgets/transcript_view.dart';
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
  final FocusNode _sidebarSearchFocus =
      FocusNode(debugLabel: 'sidebar-search');
  final _titleController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<rust_session.RecoverableSession> _recoverableSessions = const [];
  bool _loadingRecoveries = true;
  bool _showShortcuts = false;
  bool _isStoppingSession = false;
  bool _isStartingSession = false;

  /// Session shown in the workspace instead of the live recording panel.
  SessionRecord? _openSession;
  bool _openingSession = false;

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
        .where((j) =>
            j.kind == EnhanceJobKind.complete &&
            (j.status == EnhanceJobStatus.queued ||
                j.status == EnhanceJobStatus.running))
        .length;
    final reasons = [
      if (recording) 'Rekaman masih berjalan.',
      if (outstanding > 0)
        '$outstanding rekaman masih diselesaikan transkripnya — '
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

  Future<rust_session.CaptureHealth?> _readCaptureHealth(String sessionId) async {
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

  String get _libraryPath => resolveTilde(ref.read(settingsProvider).libraryPath);

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
        AppToast.show(context, 'Gagal memulihkan sesi: $e', type: ToastType.error);
      }
      return;
    }
    if (!mounted) return;
    _forgetRecoverable(session);
    if (recovered != null) {
      setState(() => _openSession = null);
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
    return '$count — ${contents.join(' dan ')} bisa dipulihkan.';
  }

  void _forgetRecoverable(rust_session.RecoverableSession session) {
    setState(() {
      _recoverableSessions = _recoverableSessions
          .where((item) => item.snapshot.sessionId != session.snapshot.sessionId)
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
    final health =
        sessionId == null ? null : await _readCaptureHealth(sessionId);
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
        AppToast.show(context, 'Gagal menghentikan sesi: $e', type: ToastType.error);
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
    ref.read(sessionProvider.notifier).setBookmarkNote(bookmark.timestamp, note);
  }

  Future<void> _toggleStartBerhenti(BuildContext context, WidgetRef ref) async {
    final lifecycle = ref.read(sessionProvider).lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording || lifecycle == SessionLifecycle.paused;
    if (isActive) {
      await _handleBerhentiPressed(context, ref);
      return;
    }
    // Recording always takes over the workspace: starting a session while
    // reading an old one and having the new transcript appear nowhere
    // visible is how a recording gets lost.
    if (_openSession != null) setState(() => _openSession = null);
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
      AppToast.show(context, 'Ekspor berhasil ke: $selectedDir', type: ToastType.success);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Ekspor gagal: $e', type: ToastType.error);
    }
  }

  // --- Navigation -----------------------------------------------------

  void _openSettings() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );

  Future<void> _openLibrary({int tab = 0}) async {
    final libraryPath = resolveTilde(ref.read(settingsProvider).libraryPath);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LibraryScreen(libraryPath: libraryPath, initialTab: tab),
      ),
    );
    if (mounted) unawaited(ref.read(libraryListProvider.notifier).refresh());
  }

  /// Loads a session's transcript and shows it in the workspace.
  Future<void> _selectSession(LibraryEntry entry) async {
    setState(() => _openingSession = true);
    final record = await loadSessionRecord(entry.dirPath);
    if (!mounted) return;
    setState(() {
      _openingSession = false;
      _openSession = record;
    });
    if (record == null && context.mounted) {
      AppToast.show(context, '"${entry.title}" tidak bisa dibuka.',
          type: ToastType.error);
    }
  }

  void _newSession() {
    setState(() => _openSession = null);
    _sidebarSearchFocus.unfocus();
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
        lifecycle == SessionLifecycle.recording || lifecycle == SessionLifecycle.paused;
    final isPaused = lifecycle == SessionLifecycle.paused;
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
        _titleController.selection =
            TextSelection.fromPosition(TextPosition(offset: next.length));
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
      searchFocusNode: _sidebarSearchFocus,
      isRecording: isActive,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            _toggleStartBerhenti(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            _toggleStartBerhenti(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () {
          if (isPaused) {
            notifier.resume();
          } else if (lifecycle == SessionLifecycle.recording) {
            notifier.pause();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          if (isPaused) {
            notifier.resume();
          } else if (lifecycle == SessionLifecycle.recording) {
            notifier.pause();
          }
        },
        // Ctrl+L now focuses the sidebar search rather than pushing a
        // separate library screen: the history is already on screen.
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
            _focusSidebarSearch,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _focusSidebarSearch,
        SingleActivator(LogicalKeyboardKey.comma, meta: true): _openSettings,
        SingleActivator(LogicalKeyboardKey.comma, control: true): _openSettings,
        SingleActivator(LogicalKeyboardKey.slash, meta: true): () =>
            setState(() => _showShortcuts = !_showShortcuts),
        SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
            setState(() => _showShortcuts = !_showShortcuts),
        // Tandai poin penting (F9). One key, no dialog — the note is a
        // separate, optional step.
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
            _addBookmark,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _addBookmark,
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
              drawer: persistentSidebar ? null : Drawer(child: sidebar),
              body: Row(
                children: [
                  if (persistentSidebar) sidebar,
                  Expanded(
                    child: _Workspace(
                      showMenuButton: !persistentSidebar,
                      onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                      session: session,
                      notifier: notifier,
                      isActive: isActive,
                      isPaused: isPaused,
                      openSession: _openSession,
                      openingSession: _openingSession,
                      onCloseSession: _newSession,
                      vuLevel: vuLevel,
                      captureHealth: _captureHealth,
                      titleController: _titleController,
                      onStartBerhenti: () => _toggleStartBerhenti(context, ref),
                      onEkspor: () => _onEkspor(context),
                      isBusy: _isStoppingSession || _isStartingSession,
                      busyLabel:
                          _isStartingSession ? 'Memulai...' : 'Menyimpan...',
                      saveError: _saveError,
                      retryingSave: _retryingSave,
                      onRetrySave: () => _retrySave(),
                      onSaveElsewhere: () => _retrySave(elsewhere: true),
                      loadingRecoveries: _loadingRecoveries,
                      recoverySummary: _recoverableSessions.isEmpty
                          ? null
                          : _recoverySummary(_recoverableSessions),
                      onOpenRecovery: () => _openRecoveryDialog(context),
                      showShortcuts: _showShortcuts,
                      onCloseShortcuts: () =>
                          setState(() => _showShortcuts = false),
                      onAddBookmark: _addBookmark,
                      onAddBookmarkWithNote: () =>
                          unawaited(_addBookmarkWithNote()),
                      onRemoveBookmark: (bookmark) => ref
                          .read(sessionProvider.notifier)
                          .removeBookmark(bookmark.timestamp),
                      onEditBookmarkNote: (bookmark) =>
                          unawaited(_editBookmarkNote(bookmark)),
                      onSessionEdited: (dirPath) => unawaited(
                        ref.read(libraryListProvider.notifier).refreshOne(dirPath),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
  final VoidCallback onAddBookmark;
  final VoidCallback onAddBookmarkWithNote;
  final void Function(Bookmark) onRemoveBookmark;
  final void Function(Bookmark) onEditBookmarkNote;
  final ValueChanged<String> onSessionEdited;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final hasTranscript = session.segments.isNotEmpty;

    if (openingSession) {
      return const Center(child: CircularProgressIndicator());
    }

    final opened = openSession;
    if (opened != null) {
      return TranscriptPlayerScreen(
        key: ValueKey(opened.dirPath),
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
          const LinearProgressIndicator(minHeight: 2)
        else if (recoverySummary != null)
          Material(
            color: colors.chipBackground,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.restore_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recoverySummary!,
                      style: TextStyle(color: colors.text, fontSize: 13),
                    ),
                  ),
                  // No "Abaikan": it hid the banner without deleting
                  // anything, so the same sessions reappeared on every
                  // launch forever.
                  FilledButton(
                    onPressed: onOpenRecovery,
                    child: const Text('Lihat & pulihkan'),
                  ),
                ],
              ),
            ),
          ),
        _ControlArea(
          showMenuButton: showMenuButton,
          onOpenMenu: onOpenMenu,
          session: session,
          notifier: notifier,
          isActive: isActive,
          isPaused: isPaused,
          vuLevel: vuLevel,
          captureHealth: captureHealth,
          titleController: titleController,
          onStartBerhenti: onStartBerhenti,
          onEkspor: onEkspor,
          isBusy: isBusy,
          busyLabel: busyLabel,
          hasTranscript: hasTranscript,
        ),
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
              if (!hasTranscript && !isActive)
                _IdleWorkspace(onStart: onStartBerhenti, busy: isBusy)
              else
                TranscriptView(
                  segments: session.segments,
                  revision: session.revision,
                  onRenameSpeaker: notifier.renameSpeaker,
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
        ),
      ],
    );
  }
}

/// The empty state: one big, obvious thing to do (blueprint §4.2).
class _IdleWorkspace extends StatelessWidget {
  const _IdleWorkspace({required this.onStart, required this.busy});

  final VoidCallback onStart;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return LayoutBuilder(
      builder: (context, constraints) {
        // At 800x600 the control groups take most of the window; the one
        // action this screen exists for must still be fully on screen, so
        // the illustration and the spacing shrink rather than push it
        // below the fold.
        final compact = constraints.maxHeight < 300;
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 12 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  Icon(Icons.mic_none_outlined,
                      size: 56, color: colors.textTertiary),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Siap merekam',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: compact ? 16 : 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  compact
                      ? 'Transkrip muncul di sini, diproses di komputer Anda.'
                      : 'Transkrip muncul di sini begitu rekaman berjalan.\n'
                          'Semuanya diproses di komputer Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                SizedBox(height: compact ? 14 : 24),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onStart,
                    icon: const Icon(Icons.fiber_manual_record, size: 18),
                    label: const Text(
                      'Mulai Rekam',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'atau tekan Ctrl+R',
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Sesi" and "Perangkat", plus the one action that applies right now.
class _ControlArea extends StatelessWidget {
  const _ControlArea({
    required this.showMenuButton,
    required this.onOpenMenu,
    required this.session,
    required this.notifier,
    required this.isActive,
    required this.isPaused,
    required this.vuLevel,
    required this.captureHealth,
    required this.titleController,
    required this.onStartBerhenti,
    required this.onEkspor,
    required this.isBusy,
    required this.busyLabel,
    required this.hasTranscript,
  });

  final bool showMenuButton;
  final VoidCallback onOpenMenu;
  final SessionUiState session;
  final SessionNotifier notifier;
  final bool isActive;
  final bool isPaused;
  final VuLevel? vuLevel;
  final rust_session.CaptureHealth? captureHealth;
  final TextEditingController titleController;
  final VoidCallback onStartBerhenti;
  final VoidCallback onEkspor;
  final bool isBusy;
  final String busyLabel;
  final bool hasTranscript;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showMenuButton)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 10),
                  child: IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Riwayat sesi',
                    onPressed: onOpenMenu,
                  ),
                ),
              Expanded(
                child: Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    SessionGroup(
                      titleController: titleController,
                      onTitleChanged: notifier.setTitle,
                      mode: session.config.mode,
                      onModeChanged: notifier.setMode,
                      modeLocked: isActive,
                    ),
                    DeviceGroup(
                      micEnabled: session.config.micEnabled,
                      speakerEnabled: session.config.speakerEnabled,
                      onMicToggled: notifier.toggleMic,
                      onSpeakerToggled: notifier.toggleSpeaker,
                      micLevel: vuLevel?.micLevel ?? 0,
                      speakerLevel: vuLevel?.speakerLevel ?? 0,
                      live: isActive,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hidden until there is something to export: it used
                    // to sit next to the record button, enabled, on an
                    // empty screen (blueprint §4.2).
                    if (hasTranscript) ...[
                      SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: onEkspor,
                          icon: Icon(Icons.download_outlined,
                              size: 16, color: colors.text),
                          label: Text('Ekspor',
                              style: TextStyle(color: colors.text)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    AnimatedRecordButton(
                      isRecording: isActive,
                      isPaused: isPaused,
                      onPressed: onStartBerhenti,
                      isBusy: isBusy,
                      busyLabel: busyLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // The VU meter alone cannot distinguish "recording" from "open
          // but silent"; the badge is what says audio actually arrived.
          if (isActive) ...[
            const SizedBox(height: 8),
            CaptureConfirmationBadge(health: captureHealth),
          ],
        ],
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
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Material(
      color: colors.error.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '$message Transkrip masih ada di memori — jangan tutup '
                  'aplikasi sebelum tersimpan.',
                  style: TextStyle(color: colors.text, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: busy ? null : onSaveElsewhere,
              child: const Text('Simpan ke folder lain'),
            ),
            FilledButton(
              onPressed: busy ? null : onRetry,
              child: Text(busy ? 'Menyimpan…' : 'Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer bar: recording timer and segment count.
class _FooterBar extends StatelessWidget {
  final SessionLifecycle lifecycle;
  final int segmentsCount;
  final double elapsedSeconds;

  const _FooterBar({
    required this.lifecycle,
    required this.segmentsCount,
    this.elapsedSeconds = 0,
  });

  String _formatElapsed(double secs) {
    final h = (secs / 3600).floor();
    final m = ((secs % 3600) / 60).floor();
    final s = (secs % 60).floor();
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final isRecording = lifecycle == SessionLifecycle.recording;
    final isPaused = lifecycle == SessionLifecycle.paused;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          if (isRecording || isPaused) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording ? colors.success : colors.warning,
                boxShadow: isRecording
                    ? [
                        BoxShadow(
                          color: colors.success.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatElapsed(elapsedSeconds),
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (segmentsCount > 0) ...[
            Icon(Icons.chat_bubble_outline, size: 14, color: colors.textTertiary),
            const SizedBox(width: 4),
            Text(
              '$segmentsCount',
              style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(width: 16),
          ],
          const Spacer(),
          Text(
            'Ctrl+/ untuk pintasan',
            style: TextStyle(color: colors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Keyboard shortcuts panel
class _ShortcutsPanel extends StatelessWidget {
  final VoidCallback onClose;

  const _ShortcutsPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pintasan keyboard',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
                tooltip: 'Tutup',
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _ShortcutRow(label: 'Mulai / Berhenti merekam', shortcut: 'Ctrl+R'),
          const _ShortcutRow(label: 'Jeda / Lanjutkan', shortcut: 'Ctrl+P'),
          const _ShortcutRow(label: 'Cari di riwayat sesi', shortcut: 'Ctrl+L'),
          const _ShortcutRow(
              label: 'Tandai poin penting', shortcut: 'Ctrl+B'),
          const _ShortcutRow(label: 'Buka Pengaturan', shortcut: 'Ctrl+,'),
          const _ShortcutRow(label: 'Tampilkan panel pintasan', shortcut: 'Ctrl+/'),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String label;
  final String shortcut;

  const _ShortcutRow({required this.label, required this.shortcut});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: colors.text, fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.chipBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
