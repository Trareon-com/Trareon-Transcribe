import 'package:audioplayers/audioplayers.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/batch_upload_model.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../utils/model_labels.dart';
import 'model_download_dialog.dart';

/// Extensions the importer accepts, in the order they are advertised.
const List<String> kImportExtensions = [
  'mp3',
  'm4a',
  'wav',
  'ogg',
  'flac',
  'opus',
  'aac',
  'mp4',
  'mov',
  'mkv',
];

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

class FileUploadZone extends ConsumerStatefulWidget {
  final Future<void> Function()? onProcessed;

  const FileUploadZone({super.key, this.onProcessed});

  @override
  ConsumerState<FileUploadZone> createState() => _FileUploadZoneState();
}

class _FileUploadZoneState extends ConsumerState<FileUploadZone> {
  bool _dragging = false;

  /// Import options, chosen *before* processing rather than silently
  /// inherited from Settings at the moment a file lands (audit A.11 upload
  /// zone, blueprint §4.6). Seeded from Settings on first build.
  String? _language;
  String? _modelId;
  bool _optionsSeeded = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (!_optionsSeeded) {
      _language = settings.language;
      _modelId = kKnownModelIds.contains(settings.defaultModel)
          ? settings.defaultModel
          : kKnownModelIds.first;
      _optionsSeeded = true;
    }
    final queue = ref.watch(batchUploadProvider);
    final notifier = ref.read(batchUploadProvider.notifier);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final pending = queue.where((e) => e.status == BatchFileStatus.queued).length;
    final busy = notifier.isRunning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DropZone(
          dragging: _dragging,
          onDragEntered: () => setState(() => _dragging = true),
          onDragExited: () => setState(() => _dragging = false),
          onFilesDropped: (paths) {
            setState(() => _dragging = false);
            _addFiles(paths);
          },
          onPick: _pickFiles,
        ),
        const SizedBox(height: 12),
        _ImportOptions(
          language: _language,
          modelId: _modelId ?? kKnownModelIds.first,
          enabled: !busy,
          onLanguageChanged: (v) => setState(() => _language = v),
          onModelChanged: (v) => setState(() => _modelId = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                queue.isEmpty
                    ? 'Belum ada berkas di antrean.'
                    : '${queue.length} berkas · $pending menunggu',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
            if (queue.isNotEmpty) ...[
              TextButton.icon(
                onPressed: queue.any((entry) => entry.status == BatchFileStatus.done)
                    ? notifier.removeDone
                    : null,
                icon: const Icon(Icons.clear_all),
                label: const Text('Hapus selesai'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: notifier.clear,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Kosongkan'),
              ),
              const SizedBox(width: 4),
            ],
            FilledButton.icon(
              onPressed: pending == 0 || busy ? null : _process,
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: Text(busy ? 'Memproses…' : 'Mulai Transkripsi'),
            ),
          ],
        ),
        if (queue.isNotEmpty) ...[
          const SizedBox(height: 8),
          // Scrollable, and lazily built: the queue used to be spread
          // directly into this Column, so it overflowed off the bottom of
          // the window after about five files and the tiles below that
          // could not be reached at all.
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: queue.length,
              itemBuilder: (context, index) => _QueueTile(
                key: ValueKey(queue[index].path),
                entry: queue[index],
                onCancel: () => notifier.cancelFile(queue[index].path),
                onRetry: () {
                  notifier.retryFile(queue[index].path);
                  _process();
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kImportExtensions,
    );
    if (result == null) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    _addFiles(paths);
  }

  /// Queues files. Processing is a separate, explicit step now: the old
  /// version started transcribing the moment a file landed, so the language
  /// and model pickers would have had nothing to act on.
  void _addFiles(List<String> paths) {
    final rejected = ref.read(batchUploadProvider.notifier).addFiles(paths);
    if (rejected.isEmpty || !mounted) return;
    final detail = rejected.take(3).map((r) => '${r.filename} (${r.message})').join(', ');
    final more = rejected.length > 3 ? ' dan ${rejected.length - 3} lainnya' : '';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Dilewati: $detail$more.')));
  }

  Future<void> _process() async {
    final settings = ref.read(settingsProvider);
    final batch = ref.read(batchUploadProvider.notifier);
    final modelId = _modelId ?? settings.defaultModel;

    if (!isModelAvailable(modelId, libraryPath: settings.libraryPath)) {
      final downloaded = await showModelDownloadDialog(
        context: context,
        bridge: ref.read(rustBridgeProvider),
        modelId: modelId,
        modelsDir: resolveTilde(settings.libraryPath),
        displayName: modelDisplayLabel(modelId),
      );
      if (!downloaded) return;
    }

    // Progressive Mode used to apply only to live recording — imports always
    // ran the single default model, so turning it on did nothing here.
    const refineId = 'large-v3-turbo-q5';
    final useProgressive =
        settings.progressiveEnabled &&
        modelId != refineId &&
        isModelAvailable(refineId, libraryPath: settings.libraryPath);

    await batch.processBatch(
      ref.read(rustBridgeProvider),
      modelPathForId(modelId, libraryPath: settings.libraryPath),
      outputDir: settings.libraryPath,
      language: _language,
      gpuEnabled: settings.gpuEnabled,
      gpuDevice: settings.gpuDevice,
      refineModelPath: useProgressive
          ? modelPathForId(refineId, libraryPath: settings.libraryPath)
          : null,
      modelId: useProgressive ? refineId : modelId,
    );
    if (mounted) await widget.onProcessed?.call();
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.dragging,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onFilesDropped,
    required this.onPick,
  });

  final bool dragging;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final ValueChanged<List<String>> onFilesDropped;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return DropTarget(
      onDragEntered: (_) => onDragEntered(),
      onDragExited: (_) => onDragExited(),
      onDragDone: (details) => onFilesDropped(details.files.map((f) => f.path).toList()),
      child: Semantics(
        label: 'Area upload file, tarik dan lepas file audio atau video ke sini',
        // Intrinsic height, not a fixed one: the format list wraps to two
        // lines in a narrow window, and a fixed box clipped it.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: dragging ? colors.primary : colors.border,
              width: dragging ? 2.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: dragging
                ? colors.primary.withValues(alpha: 0.10)
                : colors.surfaceElevated,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  dragging ? Icons.file_download_outlined : Icons.upload_file_outlined,
                  size: 32,
                  color: dragging ? colors.primary : colors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  dragging
                      ? 'Lepaskan untuk menambahkan ke antrean'
                      : 'Tarik & lepas berkas audio/video ke sini',
                  style: TextStyle(
                    color: dragging ? colors.primary : colors.text,
                    fontWeight: dragging ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Format: ${kImportExtensions.map((e) => e.toUpperCase()).join(' · ')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                ),
                Text(
                  'Maksimum ${formatBytes(kMaxImportBytes)} per berkas',
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Pilih file untuk diupload',
                  button: true,
                  child: OutlinedButton(
                    onPressed: onPick,
                    child: const Text('Pilih Berkas'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportOptions extends StatelessWidget {
  const _ImportOptions({
    required this.language,
    required this.modelId,
    required this.enabled,
    required this.onLanguageChanged,
    required this.onModelChanged,
  });

  final String? language;
  final String modelId;
  final bool enabled;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String> onModelChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Bahasa', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        DropdownButton<String?>(
          value: language,
          onChanged: enabled ? onLanguageChanged : null,
          items: const [
            DropdownMenuItem(value: null, child: Text('Deteksi otomatis')),
            DropdownMenuItem(value: 'id', child: Text('Indonesia')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
        ),
        const SizedBox(width: 8),
        Text('Model', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        DropdownButton<String>(
          value: modelId,
          onChanged: enabled ? (v) => v == null ? null : onModelChanged(v) : null,
          items: [
            for (final id in kKnownModelIds)
              DropdownMenuItem(value: id, child: Text(modelDisplayLabel(id))),
          ],
        ),
      ],
    );
  }
}

class _QueueTile extends StatefulWidget {
  final BatchFileEntry entry;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const _QueueTile({
    super.key,
    required this.entry,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  State<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<_QueueTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    final path = widget.entry.path;
    if (path.isEmpty) return;
    try {
      await _player.setSourceDeviceFile(path);
      await _player.resume();
      setState(() => _playing = true);
      _player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _playing = false);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak bisa memutar berkas ini'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final canPreview = entry.status == BatchFileStatus.queued && entry.path.isNotEmpty;
    final running =
        entry.status == BatchFileStatus.transcribing ||
        entry.status == BatchFileStatus.decoding;

    return Semantics(
      label:
          '${entry.filename} — ${_statusLabel(entry.status)}'
          '${entry.error != null ? ', error: ${entry.error}' : ''}',
      // A hand-built row rather than a ListTile: the status line plus a
      // progress bar does not fit a dense ListTile's subtitle box, and an
      // overflow warning in the import queue is exactly the bug this
      // sprint is meant to remove.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              child: Center(
                child: Semantics(
                  label: _statusLabel(entry.status),
                  child: _statusIcon(entry.status),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.filename,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.text, fontSize: 13),
                  ),
                  Text(
                    [
                      _statusLabel(entry.status),
                      if (entry.sizeBytes > 0) formatBytes(entry.sizeBytes),
                      if (running && entry.progress > 0)
                        '${(entry.progress * 100).round()}%',
                      if (entry.error != null) entry.error!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textTertiary, fontSize: 11),
                  ),
                  if (running)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(
                        value: entry.progress > 0 ? entry.progress : null,
                        minHeight: 3,
                      ),
                    ),
                ],
              ),
            ),
            if (canPreview)
              IconButton(
                icon: Icon(
                  _playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                  color: colors.primary,
                ),
                onPressed: _togglePreview,
                tooltip: _playing ? 'Hentikan pratinjau' : 'Pratinjau audio',
                visualDensity: VisualDensity.compact,
              ),
            if (entry.status == BatchFileStatus.error ||
                entry.status == BatchFileStatus.cancelled)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: widget.onRetry,
                tooltip: 'Coba lagi',
                visualDensity: VisualDensity.compact,
              ),
            if (!entry.isFinished)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel,
                tooltip: 'Batalkan berkas ini',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(BatchFileStatus status) => switch (status) {
    BatchFileStatus.queued => 'Antre',
    BatchFileStatus.decoding => 'Membaca berkas',
    BatchFileStatus.transcribing => 'Transkripsi',
    BatchFileStatus.done => 'Selesai',
    BatchFileStatus.error => 'Gagal',
    BatchFileStatus.cancelled => 'Dibatalkan',
  };

  Widget _statusIcon(BatchFileStatus status) => switch (status) {
    BatchFileStatus.queued => const Icon(Icons.schedule),
    BatchFileStatus.decoding || BatchFileStatus.transcribing => const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    BatchFileStatus.done => const Icon(Icons.check_circle, color: AppColors.statusActive),
    BatchFileStatus.error => const Icon(Icons.error, color: AppColors.warning),
    BatchFileStatus.cancelled => const Icon(Icons.block),
  };
}
