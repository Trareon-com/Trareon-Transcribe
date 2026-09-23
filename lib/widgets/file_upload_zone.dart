import 'package:audioplayers/audioplayers.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/batch_upload_model.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';

class FileUploadZone extends ConsumerStatefulWidget {
  final Future<void> Function()? onProcessed;

  const FileUploadZone({super.key, this.onProcessed});

  @override
  ConsumerState<FileUploadZone> createState() => _FileUploadZoneState();
}

class _FileUploadZoneState extends ConsumerState<FileUploadZone> {
  bool _dragging = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac', 'opus', 'mp4', 'mov', 'mkv',
      ],
    );
    if (result == null) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    await _addFiles(paths);
  }

  Future<void> _addFiles(List<String> paths) async {
    final batch = ref.read(batchUploadProvider.notifier);
    final rejected = batch.addFiles(paths);
    if (rejected.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${rejected.length} file dengan format tidak didukung dilewati.'),
        ),
      );
    }

    final settings = ref.read(settingsProvider);
    await batch.processBatch(
      ref.read(rustBridgeProvider),
      modelPathForId(settings.defaultModel, libraryPath: settings.libraryPath),
      outputDir: settings.libraryPath,
      language: settings.language,
    );
    if (mounted) {
      await widget.onProcessed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(batchUploadProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (details) {
            setState(() => _dragging = false);
            _addFiles(details.files.map((f) => f.path).toList());
          },
          child: Semantics(
            label: 'Area upload file, tarik dan lepas file audio atau video ke sini',
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _dragging ? AppColors.micAccent : Theme.of(context).dividerColor,
                  width: _dragging ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _dragging ? AppColors.micAccent.withValues(alpha: 0.08) : null,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: 'Ikon upload',
                      child: const Icon(Icons.upload_file_outlined, size: 32),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'Instruksi: tarik dan lepas file audio atau video ke sini',
                      child: Text('Tarik & lepas file audio/video ke sini'),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'Pilih file untuk diupload',
                      button: true,
                      child: OutlinedButton(
                        onPressed: _pickFiles,
                        child: const Text('Pilih File'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (queue.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Semantics(
                label: 'Hapus file yang selesai diproses dari antrian',
                button: true,
                child: TextButton.icon(
                  onPressed: queue.any((entry) => entry.status == BatchFileStatus.done)
                      ? () => ref.read(batchUploadProvider.notifier).removeDone()
                      : null,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Hapus selesai'),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Kosongkan seluruh antrian upload',
                button: true,
                child: TextButton.icon(
                  onPressed: () => ref.read(batchUploadProvider.notifier).clear(),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Kosongkan'),
                ),
              ),
            ],
          ),
          ...queue.map((entry) => _QueueTile(key: ValueKey(entry.path), entry: entry)),
        ],
      ],
    );
  }
}

class _QueueTile extends StatefulWidget {
  final BatchFileEntry entry;

  const _QueueTile({super.key, required this.entry});

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

  String get _audioPath => widget.entry.path;

  Future<void> _togglePreview() async {
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    final path = _audioPath;
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
          SnackBar(content: Text('Tidak bisa memutar file ini'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPreview = widget.entry.status == BatchFileStatus.queued && widget.entry.path.isNotEmpty;
    return Semantics(
      label: '${widget.entry.filename} — ${_statusLabel(widget.entry.status)}${widget.entry.error != null ? ', error: ${widget.entry.error}' : ''}',
      child: ListTile(
        dense: true,
        leading: Semantics(
          label: _statusLabel(widget.entry.status),
          child: _statusIcon(widget.entry.status),
        ),
        title: Text(widget.entry.filename, overflow: TextOverflow.ellipsis),
        subtitle: widget.entry.error != null ? Text(widget.entry.error!) : null,
        trailing: canPreview
            ? Semantics(
                label: _playing ? 'Hentikan pratinjau' : 'Putar pratinjau audio',
                button: true,
                child: IconButton(
                  icon: Icon(_playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                      color: AppColors.micAccent),
                  onPressed: _togglePreview,
                  tooltip: 'Pratinjau audio',
                ),
              )
            : null,
      ),
    );
  }

  String _statusLabel(BatchFileStatus status) {
    return switch (status) {
      BatchFileStatus.queued => 'Antri',
      BatchFileStatus.decoding => 'Decoding',
      BatchFileStatus.transcribing => 'Transkripsi',
      BatchFileStatus.done => 'Selesai',
      BatchFileStatus.error => 'Gagal',
    };
  }

  Widget _statusIcon(BatchFileStatus status) {
    return switch (status) {
      BatchFileStatus.queued => const Icon(Icons.schedule),
      BatchFileStatus.decoding => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      BatchFileStatus.transcribing => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      BatchFileStatus.done => const Icon(Icons.check_circle, color: AppColors.micAccent),
      BatchFileStatus.error => const Icon(Icons.error, color: AppColors.warning),
    };
  }
}
