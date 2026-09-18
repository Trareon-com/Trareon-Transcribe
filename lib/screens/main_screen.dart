import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/global_hotkey_service.dart';
import '../state/audio_stream_model.dart';
import '../state/audio_watchdog_model.dart';
import '../state/models.dart';
import '../state/session_model.dart';
import '../state/settings_model.dart';
import '../src/rust/session.dart' as rust_session;
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/mode_selector.dart';
import '../widgets/model_download_dialog.dart';
import '../widgets/stream_toggle.dart';
import '../widgets/animated_record_button.dart';
import '../widgets/transcript_view.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final GlobalHotkeyService _globalHotkeys = GlobalHotkeyService();
  List<rust_session.SessionRecoverySnapshot> _recoverableSessions = const [];
  bool _loadingRecoveries = true;
  bool _showShortcuts = false;
  bool _isStoppingSession = false;
  bool _isStartingSession = false;
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _globalHotkeys.init(
      ref.read(sessionProvider.notifier),
      () => ref.read(sessionProvider).lifecycle,
    );
    _loadRecoveries();
  }

  @override
  void dispose() {
    _globalHotkeys.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadRecoveries() async {
    final bridge = ref.read(rustBridgeProvider);
    List<rust_session.SessionRecoverySnapshot> recoveries = const [];
    try {
      recoveries = await bridge.listRecoverableSessions();
    } catch (_) {
      // A throw here (corrupt snapshot dir, bridge failure) previously left
      // _loadingRecoveries true forever — a permanent loading bar that also
      // hid the recovery banner entirely. Fall through with an empty list so
      // the loading state clears.
    }
    if (!mounted) return;
    setState(() {
      _recoverableSessions = recoveries;
      _loadingRecoveries = false;
    });
  }

  Future<void> _recoverSession(
    BuildContext context,
    WidgetRef ref,
    rust_session.SessionRecoverySnapshot snapshot,
  ) async {
    try {
      await ref.read(sessionProvider.notifier).recoverFromSnapshot(snapshot);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Gagal memulihkan sesi: $e', type: ToastType.error);
      return;
    }
    if (!context.mounted) return;
    setState(() {
      _recoverableSessions = _recoverableSessions
          .where((item) => item.sessionId != snapshot.sessionId)
          .toList(growable: false);
    });
    AppToast.show(context, 'Sesi ${snapshot.sessionId} dipulihkan.', type: ToastType.success);
  }

  Future<void> _handleBerhentiPressed(BuildContext context, WidgetRef ref) async {
    final segments = ref.read(sessionProvider).segments;
    if (segments.isNotEmpty) {
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
    setState(() => _isStoppingSession = true);
    try {
      await ref.read(sessionProvider.notifier).stop();
      if (segments.isNotEmpty && context.mounted) {
        AppToast.show(
          context,
          'Sesi tersimpan (${segments.length} segmen).',
          type: ToastType.success,
        );
      }
    } on TranscribeSaveError catch (e) {
      if (context.mounted) {
        AppToast.show(context, '$e', type: ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Gagal menghentikan sesi: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isStoppingSession = false);
    }
  }

  Future<void> _toggleStartBerhenti(BuildContext context, WidgetRef ref) async {
    final lifecycle = ref.read(sessionProvider).lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording || lifecycle == SessionLifecycle.paused;
    if (isActive) {
      await _handleBerhentiPressed(context, ref);
      return;
    }
    // start() can hang for a long time with zero other feedback while
    // waiting on a native macOS permission dialog (e.g. first-ever Webinar/
    // system-audio capture) — without this the record button just looks
    // unresponsive to a click that's actually still in flight.
    setState(() => _isStartingSession = true);
    try {
      await ref.read(sessionProvider.notifier).start();
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final lifecycle = session.lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording || lifecycle == SessionLifecycle.paused;
    final isPaused = lifecycle == SessionLifecycle.paused;
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vuLevel = ref.watch(vuLevelProvider).valueOrNull;

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

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            _toggleStartBerhenti(context, ref),
        SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            _toggleStartBerhenti(context, ref),
        SingleActivator(LogicalKeyboardKey.keyP, meta: true): () {
          if (isPaused) {
            notifier.resume();
          } else if (lifecycle == SessionLifecycle.recording) {
            notifier.pause();
          }
        },
        SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          if (isPaused) {
            notifier.resume();
          } else if (lifecycle == SessionLifecycle.recording) {
            notifier.pause();
          }
        },
        SingleActivator(LogicalKeyboardKey.keyL, meta: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
              final lp = ref.read(settingsProvider).libraryPath;
              return LibraryScreen(libraryPath: resolveTilde(lp));
            })),
        SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
              final lp = ref.read(settingsProvider).libraryPath;
              return LibraryScreen(libraryPath: resolveTilde(lp));
            })),
        SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        SingleActivator(LogicalKeyboardKey.slash, meta: true): () =>
            setState(() => _showShortcuts = !_showShortcuts),
        SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
            setState(() => _showShortcuts = !_showShortcuts),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.background,
          body: Column(
            children: [
              // Recovery banner
              if (_loadingRecoveries)
                const LinearProgressIndicator(minHeight: 2)
              else if (_recoverableSessions.isNotEmpty)
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
                            'Ada ${_recoverableSessions.length} sesi yang bisa dipulihkan.',
                            style: TextStyle(color: colors.text, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _recoverableSessions = const []),
                          child: const Text('Abaikan'),
                        ),
                        FilledButton(
                          // A session is already recording (possibly a
                          // just-recovered one) — recovering another would
                          // silently orphan this one's Rust-side capture
                          // with nothing left to stop it. Session lifecycle
                          // here is single-active, so make that visible
                          // instead of a no-op tap.
                          onPressed: isActive
                              ? null
                              : () => _recoverSession(context, ref, _recoverableSessions.first),
                          child: const Text('Pulihkan'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Minimal header row (native title bar dari OS yang handle window chrome)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colors.headerBackground,
                  border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/logo.png', width: 20, height: 20,
                        errorBuilder: (_, _, _) => const SizedBox.shrink()),
                    const SizedBox(width: 8),
                    Text(
                      'Trareon Transcribe',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.upload_file_outlined, size: 18),
                      tooltip: 'Upload File',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) {
                            final lp = ref.read(settingsProvider).libraryPath;
                            return LibraryScreen(libraryPath: resolveTilde(lp));
                          },
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      color: colors.textSecondary,
                    ),
                    IconButton(
                      icon: Icon(Icons.folder_outlined, size: 18),
                      tooltip: 'Perpustakaan',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) {
                            final lp = ref.read(settingsProvider).libraryPath;
                            return LibraryScreen(libraryPath: resolveTilde(lp));
                          },
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      color: colors.textSecondary,
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_outlined, size: 18),
                      tooltip: 'Pengaturan',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      color: colors.textSecondary,
                    ),
                    IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        size: 18,
                      ),
                      tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
                      onPressed: () {
                        final notifier = ref.read(settingsProvider.notifier);
                        notifier.toggleTheme();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),

              // Control bar
              _ControlBar(
                session: session,
                notifier: notifier,
                isActive: isActive,
                isPaused: isPaused,
                vuMikrofonLevel: vuLevel?.micLevel ?? 0.0,
                vuSpeakerLevel: vuLevel?.speakerLevel ?? 0.0,
                titleController: _titleController,
                onStartBerhenti: () => _toggleStartBerhenti(context, ref),
                onEkspor: () => _onEkspor(context),
                isBusy: _isStoppingSession || _isStartingSession,
                busyLabel: _isStartingSession ? 'Memulai...' : 'Menyimpan...',
              ),

              // Transcript
              Expanded(
                child: Stack(
                  children: [
                    TranscriptView(
                      segments: session.segments,
                      onRenameSpeaker: (oldLabel, newLabel) {
                        ref
                            .read(sessionProvider.notifier)
                            .renameSpeaker(oldLabel, newLabel);
                      },
                    ),
                    if (_showShortcuts)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _ShortcutsPanel(
                          onClose: () => setState(() => _showShortcuts = false),
                        ),
                      ),
                  ],
                ),
              ),

              // Footer
              _FooterBar(
                lifecycle: lifecycle,
                segmentsCount: session.segments.length,
                elapsedSeconds: session.elapsedSeconds,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Control bar: 3 rows - title+quality, VU meters, action buttons
class _ControlBar extends StatelessWidget {
  final SessionUiState session;
  final SessionNotifier notifier;
  final bool isActive;
  final bool isPaused;
  final double vuMikrofonLevel;
  final double vuSpeakerLevel;
  final TextEditingController titleController;
  final VoidCallback onStartBerhenti;
  final VoidCallback onEkspor;
  final bool isBusy;
  final String busyLabel;

  const _ControlBar({
    required this.session,
    required this.notifier,
    required this.isActive,
    required this.isPaused,
    required this.vuMikrofonLevel,
    required this.vuSpeakerLevel,
    required this.titleController,
    required this.onStartBerhenti,
    required this.onEkspor,
    required this.isBusy,
    required this.busyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: title + quality toggle
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colors.chipBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: colors.textTertiary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: titleController,
                          onChanged: notifier.setTitle,
                          onSubmitted: notifier.setTitle,
                          style: TextStyle(color: colors.text, fontSize: 13),
                          decoration: InputDecoration.collapsed(
                            hintText: 'Judul sesi...',
                            hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _QualityToggle(),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: VU meters (visible during recording)
          if (isActive) ...[
            Row(
              children: [
                Expanded(
                  child: _VuMeterRow(
                    micLevel: vuMikrofonLevel,
                    speakerLevel: vuSpeakerLevel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Row 3: action buttons. The mode selector + stream toggles are
          // wrapped in a horizontal scroll view and Ekspor/record are kept
          // outside of it — at narrow window widths (Row's un-scrollable
          // content used to overflow off the right edge of the window,
          // silently clipping the record button so clicking where it used
          // to be did nothing) this guarantees Ekspor and the record button
          // stay on-screen and clickable no matter how narrow the window is.
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Mode selector — disabled while a session is active
                      IgnorePointer(
                        ignoring: isActive,
                        child: Opacity(
                          opacity: isActive ? 0.5 : 1.0,
                          child: ModeSelector(
                            selected: session.config.mode,
                            onChanged: notifier.setMode,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // MIC toggle interaktif
                      StreamToggle(
                        label: 'Mikrofon',
                        enabled: session.config.micEnabled,
                        accent: colors.primary,
                        onChanged: (enabled) => notifier.toggleMic(enabled),
                      ),
                      const SizedBox(width: 8),

                      // SPK toggle interaktif
                      StreamToggle(
                        label: 'Pengeras Suara',
                        enabled: session.config.speakerEnabled,
                        accent: colors.primary,
                        onChanged: (enabled) => notifier.toggleSpeaker(enabled),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Ekspor button
              SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: onEkspor,
                  icon: Icon(Icons.download_outlined, size: 16, color: colors.text),
                  label: Text('Ekspor', style: TextStyle(color: colors.text)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Animated record button
              AnimatedRecordButton(
                isRecording: isActive,
                isPaused: isPaused,
                onPressed: onStartBerhenti,
                isBusy: isBusy,
                busyLabel: busyLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VuMeterRow extends StatelessWidget {
  final double micLevel;
  final double speakerLevel;

  const _VuMeterRow({required this.micLevel, required this.speakerLevel});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, size: 14, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: _AudioLevelBar(level: micLevel, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 16),
          Icon(Icons.volume_up, size: 14, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: _AudioLevelBar(level: speakerLevel, color: const Color(0xFFE65100)),
          ),
        ],
      ),
    );
  }
}

class _AudioLevelBar extends StatelessWidget {
  final double level;
  final Color color;

  const _AudioLevelBar({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: level.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        builder: (context, value, _) {
          return LinearProgressIndicator(
            value: value,
            minHeight: 6,
            color: color,
            backgroundColor: colors.border.withValues(alpha: 0.3),
          );
        },
      ),
    );
  }
}

/// Footer bar: recording timer, minify to tray, diarization info
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
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
          // Recording dot + timer
          if (isRecording || isPaused) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording ? AppColors.statusActive : Colors.orange,
                boxShadow: isRecording
                    ? [BoxShadow(color: AppColors.statusActive.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)]
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

          // Segments
          if (segmentsCount > 0) ...[
            Icon(Icons.chat_bubble_outline, size: 14, color: colors.textTertiary),
            const SizedBox(width: 4),
            Text(
              '$segmentsCount',
              style: TextStyle(color: colors.textTertiary, fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(width: 16),
          ],

          const Spacer(),
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
            color: Colors.black.withValues(alpha: 0.1),
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
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ShortcutRow(label: 'Mulai / Berhenti merekam', shortcut: 'Cmd+R'),
          _ShortcutRow(label: 'Jeda / Lanjutkan', shortcut: 'Cmd+P'),
          _ShortcutRow(label: 'Buka Perpustakaan', shortcut: 'Cmd+L'),
          _ShortcutRow(label: 'Buka Pengaturan', shortcut: 'Cmd+,'),
          _ShortcutRow(label: 'Tampilkan panel pintasan', shortcut: 'Cmd+/'),
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
              style: TextStyle(color: colors.textSecondary, fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle kualitas: ⚡ Cepat (base) / 🎯 Akurat (large-v3-turbo-q5)
class _QualityToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final isAkurat = settings.defaultModel == 'large-v3-turbo-q5';

    // 'large-v3-turbo' (unquantized) is a real KNOWN_MODELS entry but has no
    // pinned SHA256 yet — verify_checksum() hard-refuses any download without
    // a pin, so targeting it here would always fail. The bundled, downloadable
    // "accurate" model is the q5-quantized variant.
    final targetModel = isAkurat ? 'base' : 'large-v3-turbo-q5';
    final targetAvailable = isModelAvailable(targetModel, libraryPath: settings.libraryPath);

    return GestureDetector(
      onTap: () async {
        if (!targetAvailable) {
          if (!context.mounted) return;
          final modelsDir = resolveTilde(settings.libraryPath);
          final ok = await showModelDownloadDialog(
            context: context,
            bridge: ref.read(rustBridgeProvider),
            modelId: targetModel,
            modelsDir: modelsDir,
            displayName: isAkurat ? 'Model Akurat' : 'Model Cepat',
          );
          if (ok) {
            await notifier.setDefaultModel(targetModel);
          }
          return;
        }
        await notifier.setDefaultModel(targetModel);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.chipBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border),
        ),
        child: Opacity(
          opacity: targetAvailable ? 1.0 : 0.4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isAkurat ? '🎯' : '⚡', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                isAkurat ? 'Akurat' : 'Cepat',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
