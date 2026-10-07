/// "Tindak Lanjut" — the structured action items of a meeting (F6).
///
/// A summary paragraph that mentions a task is not a task: nobody can
/// filter it, tick it off, or put it in a calendar. This panel is the
/// same information as four editable columns — tugas, penanggung jawab,
/// tenggat, status — plus the two exports that make it leave the app:
/// `.ics` for a calendar and `.csv` for a spreadsheet.
///
/// Every row keeps the transcript segments the model cited, so "who
/// agreed to this?" is one tap away rather than an argument.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/models.dart';
import '../state/settings_model.dart';
import '../state/summary_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/atomic_file.dart';
import 'app_toast.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';

/// Indonesian label for a status.
///
/// Spelled out here rather than awaited over the FFI for every dropdown
/// item on every rebuild. It mirrors `ActionStatus::label()`
/// (rust_core/src/actions.rs) and `action_items_test.dart` reads that
/// file to check the two have not drifted — the `.ics`/`.csv` exports
/// come from the Rust side, so two spellings would mean a status that
/// reads one way on screen and another in the file.
String actionStatusLabel(ActionStatus status) => switch (status) {
  ActionStatus.belum => 'Belum mulai',
  ActionStatus.berjalan => 'Sedang berjalan',
  ActionStatus.selesai => 'Selesai',
  ActionStatus.dibatalkan => 'Dibatalkan',
};

class ActionItemsPanel extends ConsumerStatefulWidget {
  const ActionItemsPanel({
    super.key,
    required this.provider,
    required this.sessionTitle,
    required this.sessionDirPath,
    this.onSeekToSegment,
  });

  /// The session's summary notifier — the checklist lives with the
  /// summary it came from, not in a provider of its own.
  final StateNotifierProvider<SummaryNotifier, SummaryUiState> provider;

  final String sessionTitle;

  /// Where `.ics` and `.csv` are written.
  final String sessionDirPath;

  /// Jumps the player to a cited segment index.
  final void Function(int segmentIndex)? onSeekToSegment;

  @override
  ConsumerState<ActionItemsPanel> createState() => _ActionItemsPanelState();
}

/// The most recent export started from an [ActionItemsPanel], or null if
/// none has run yet.
///
/// The export buttons are fire-and-forget (`onPressed: () => _exportCsv(…)`),
/// so a test has no handle on the Rust call plus atomic write they kick off.
/// Polling for the file to appear is what this replaces: a bounded poll that
/// gives up silently turns a loaded CPU into a failure several lines after
/// its cause. Awaiting the future is deterministic at any speed — the same
/// reasoning, and the same shape, as `libraryIndexWriteSettled`.
///
/// Completes rather than fails on an export error, matching the panel's
/// contract: a failed export surfaces as a toast, not an exception.
///
/// Production behaviour is unchanged: nothing awaits this.
@visibleForTesting
Future<void>? actionItemExportSettled;

class _ActionItemsPanelState extends ConsumerState<ActionItemsPanel> {
  bool _expanded = true;
  bool _exporting = false;

  SummaryNotifier get _notifier => ref.read(widget.provider.notifier);

  /// Writes [content] next to the session and reports where it went.
  ///
  /// Atomic (temp + rename in the same directory) like every other
  /// persisted file here: a calendar half-written because the disk filled
  /// up imports as a corrupt calendar, not as nothing.
  Future<void> _write(String filename, String content, String what) async {
    setState(() => _exporting = true);
    try {
      final path = '${widget.sessionDirPath}${Platform.pathSeparator}$filename';
      await writeStringAtomic(File(path), content);
      if (!mounted) return;
      AppToast.show(context, '$what disimpan: $filename');
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Gagal menyimpan $what: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportIcs(List<ActionItem> items) async {
    final bridge = ref.read(rustBridgeProvider);
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    try {
      final ics = await bridge.actionItemsToIcs(
        items: items,
        calendarName: 'Tindak Lanjut: ${widget.sessionTitle}',
        today: today,
      );
      await _write('tindak-lanjut.ics', ics, 'Kalender tindak lanjut');
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, 'Gagal membuat .ics: $e', type: ToastType.error);
    }
  }

  Future<void> _exportCsv(List<ActionItem> items) async {
    final bridge = ref.read(rustBridgeProvider);
    try {
      final csv = await bridge.actionItemsToCsv(items);
      await _write('tindak-lanjut.csv', csv, 'Tabel tindak lanjut');
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, 'Gagal membuat .csv: $e', type: ToastType.error);
    }
  }

  Future<void> _copyAsText(List<ActionItem> items) async {
    final lines = [
      'Tindak Lanjut: ${widget.sessionTitle}',
      for (final item in items)
        '- ${item.tugas}'
            '${item.penanggungJawab.isEmpty ? '' : ' (PJ: ${item.penanggungJawab})'}'
            '${item.tenggat.isEmpty ? '' : ' — tenggat ${item.tenggat}'}'
            ' [${actionStatusLabel(item.status)}]',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    AppToast.show(context, 'Tindak lanjut disalin.');
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final items = ref.watch(widget.provider).actionItems;
    // Only rows with a task can be exported; a blank row the user added
    // and has not filled in yet is not something to put in a calendar.
    final exportable = [
      for (final item in items)
        if (item.tugas.trim().isNotEmpty) item,
    ];
    final done = exportable
        .where((i) => i.status == ActionStatus.selesai)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.checklist,
                    size: IconSizes.md,
                    color: colors.primary,
                  ),
                  Spacing.hSm,
                  Text(
                    'Tindak Lanjut',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: FontSizes.bodyLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (exportable.isNotEmpty) ...[
                    Spacing.hSm,
                    Text(
                      '$done/${exportable.length} selesai',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: FontSizes.micro,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_exporting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _expanded ? AppIcons.expandLess : AppIcons.expandMore,
                      size: IconSizes.lg,
                      color: colors.textSecondary,
                    ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                0,
                Spacing.lg,
                Spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Text(
                        'Belum ada tindak lanjut. Nyalakan "Tindak lanjut '
                        'terstruktur" di Pengaturan → Ringkasan AI agar '
                        'ringkasan berikutnya mengisinya sendiri, atau '
                        'tambahkan sendiri di bawah.',
                        style: TextStyle(
                          fontSize: FontSizes.caption,
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    )
                  else
                    for (final entry in items.asMap().entries)
                      _ActionRow(
                        key: ValueKey(entry.value.id),
                        index: entry.key,
                        item: entry.value,
                        colors: colors,
                        onChanged: (item) =>
                            _notifier.setActionItem(entry.key, item),
                        onRemove: () => _notifier.removeActionItem(entry.key),
                        onSeekToSegment: widget.onSeekToSegment,
                      ),
                  Spacing.gapSm,
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.xs,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _notifier.addActionItem,
                        icon: const Icon(AppIcons.add, size: IconSizes.sm),
                        label: const Text('Tambah tugas'),
                      ),
                      TextButton.icon(
                        onPressed: exportable.isEmpty || _exporting
                            ? null
                            : () => _copyAsText(exportable),
                        icon: const Icon(AppIcons.copy, size: IconSizes.sm),
                        label: const Text('Salin'),
                      ),
                      OutlinedButton.icon(
                        onPressed: exportable.isEmpty || _exporting
                            ? null
                            : () {
                                // Kept, not awaited — see
                                // [actionItemExportSettled].
                                actionItemExportSettled = _exportCsv(
                                  exportable,
                                );
                              },
                        icon: const Icon(AppIcons.table, size: IconSizes.sm),
                        label: const Text('Ekspor CSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: exportable.isEmpty || _exporting
                            ? null
                            : () {
                                // Kept, not awaited — see
                                // [actionItemExportSettled].
                                actionItemExportSettled = _exportIcs(
                                  exportable,
                                );
                              },
                        icon: const Icon(AppIcons.event, size: IconSizes.sm),
                        label: const Text('Ekspor .ics'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One editable row.
///
/// Stateful so typing does not rebuild the whole panel on every
/// keystroke, and so the controllers survive a parent rebuild — a text
/// field that loses its cursor position mid-word is unusable.
class _ActionRow extends StatefulWidget {
  const _ActionRow({
    super.key,
    required this.index,
    required this.item,
    required this.colors,
    required this.onChanged,
    required this.onRemove,
    this.onSeekToSegment,
  });

  final int index;
  final ActionItem item;
  final AppColorSet colors;
  final ValueChanged<ActionItem> onChanged;
  final VoidCallback onRemove;
  final void Function(int segmentIndex)? onSeekToSegment;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  late final TextEditingController _tugas;
  late final TextEditingController _pj;
  late final TextEditingController _tenggat;

  @override
  void initState() {
    super.initState();
    _tugas = TextEditingController(text: widget.item.tugas);
    _pj = TextEditingController(text: widget.item.penanggungJawab);
    _tenggat = TextEditingController(text: widget.item.tenggat);
  }

  @override
  void dispose() {
    _tugas.dispose();
    _pj.dispose();
    _tenggat.dispose();
    super.dispose();
  }

  void _emit({ActionStatus? status}) {
    widget.onChanged(
      ActionItem(
        id: widget.item.id,
        tugas: _tugas.text,
        penanggungJawab: _pj.text,
        tenggat: _tenggat.text,
        status: status ?? widget.item.status,
        segmentIds: widget.item.segmentIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final selesai = widget.item.status == ActionStatus.selesai;
    final citations = widget.item.segmentIds;

    // Two lines rather than one: five controls plus a delete button in a
    // single row overflowed the status dropdown off the right edge at the
    // app's 800 px minimum window, which hid the one control whose label
    // ("Sedang berjalan") is the longest.
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A checkbox for the one status transition that happens a
              // hundred times more often than the others.
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Semantics(
                  label: 'Tandai "${widget.item.tugas}" selesai',
                  child: Checkbox(
                    value: selesai,
                    onChanged: (value) => _emit(
                      status: value == true
                          ? ActionStatus.selesai
                          : ActionStatus.belum,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _tugas,
                  onChanged: (_) => _emit(),
                  style: TextStyle(
                    fontSize: FontSizes.caption,
                    decoration: selesai ? TextDecoration.lineThrough : null,
                    color: selesai ? colors.textTertiary : colors.text,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Tugas',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Hapus tugas',
                icon: const Icon(AppIcons.close, size: IconSizes.sm),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          if (citations.isNotEmpty && widget.onSeekToSegment != null)
            Padding(
              padding: const EdgeInsets.only(
                left: TouchTarget.minimum - Spacing.sm,
                top: Spacing.xs,
              ),
              child: Wrap(
                spacing: Spacing.xs,
                children: [
                  for (final id in citations)
                    // The model numbers segments from 1; the player
                    // indexes from 0. Getting this wrong points every
                    // citation one line early.
                    ActionChip(
                      label: Text(
                        '[#$id]',
                        style: const TextStyle(fontSize: FontSizes.micro),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.onSeekToSegment!(id - 1),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(
              left: TouchTarget.minimum - Spacing.sm,
              top: Spacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _pj,
                    onChanged: (_) => _emit(),
                    style: const TextStyle(fontSize: FontSizes.caption),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Penanggung jawab',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _tenggat,
                    onChanged: (_) => _emit(),
                    style: const TextStyle(fontSize: FontSizes.caption),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Tenggat',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<ActionStatus>(
                    initialValue: widget.item.status,
                    isDense: true,
                    // Ellipsise rather than overflow: "Sedang berjalan"
                    // is wider than the column at a narrow window.
                    isExpanded: true,
                    style: AppText.caption.c(colors.text),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final status in ActionStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(
                            actionStatusLabel(status),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (status) {
                      if (status != null) _emit(status: status);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
