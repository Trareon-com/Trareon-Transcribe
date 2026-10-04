/// "Notulen Rapat" (F2) — the form, and the export it produces.
///
/// The eleven fields here are the ones audio cannot supply: nomor naskah,
/// hari/tanggal, waktu, tempat, pimpinan, notulis, peserta, agenda. Four come
/// prefilled from Settings (the office-level ones), the body sections come
/// prefilled from the AI summary via `notulenDraftFromSummary`, and what the
/// user types is saved into the session sidecar so re-exporting six months
/// later reproduces the same document.
///
/// Two template variants ship, because Tata Naskah Dinas varies per ministry
/// and pemda: "Notulen Dinas" (full form, kop surat, signature block) and
/// "Notulen Ringkas" (one page, for circulating the outcome).
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/session_store.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_toast.dart';
import '../theme/app_icons.dart';

/// Indonesian day names, indexed by `DateTime.weekday` (1 = Monday).
const List<String> kHariIndonesia = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// Indonesian month names, indexed by `DateTime.month - 1`.
const List<String> kBulanIndonesia = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// `"Senin"` for [date].
String hariIndonesia(DateTime date) =>
    kHariIndonesia[(date.weekday - 1).clamp(0, 6)];

/// `"1 Oktober 2026"` for [date] — the written form Tata Naskah Dinas uses,
/// never `01/10/2026`.
String tanggalIndonesia(DateTime date) =>
    '${date.day} ${kBulanIndonesia[(date.month - 1).clamp(0, 11)]} ${date.year}';

/// `"09.00 – 11.30 WIB"` for a session that started at [start] and ran for
/// [durationSeconds]. Dots, not colons: that is the Indonesian convention.
String waktuIndonesia(DateTime start, double durationSeconds) {
  String clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}.${at.minute.toString().padLeft(2, '0')}';
  final end = start.add(Duration(seconds: durationSeconds.round()));
  return '${clock(start)} - ${clock(end)} WIB';
}

/// Speaker labels worth offering as peserta.
///
/// `MIC`/`SPK` are the engine's source names, not people, so they are dropped
/// — a notulen listing "SPK" as an attendee is worse than one listing nobody.
List<String> pesertaFromSegments(List<TranscriptSegment> segments) {
  const engineLabels = {'mic', 'spk', 'speaker', 'file', 'unknown'};
  final seen = <String>{};
  final out = <String>[];
  for (final segment in segments) {
    final speaker = segment.speaker.trim();
    if (speaker.isEmpty) continue;
    if (engineLabels.contains(speaker.toLowerCase())) continue;
    if (!seen.add(speaker.toLowerCase())) continue;
    out.add(speaker);
  }
  return out;
}

/// Builds the form a session starts from: office defaults, dates derived from
/// the recording, peserta from the speakers, body from the summary draft.
///
/// Pure so the prefill logic is testable without a dialog or an engine.
NotulenFormData buildNotulenPrefill({
  required String title,
  required DateTime recordedAt,
  required double durationSeconds,
  required NotulenDefaults defaults,
  required List<TranscriptSegment> segments,
  NotulenFormData? saved,
  NotulenDraft? draft,
  List<ActionItem> actionItems = const [],
}) {
  if (saved != null) return saved;
  return NotulenFormData(
    instansi: defaults.unitKerja,
    unitKerja: '',
    judul: title,
    hari: hariIndonesia(recordedAt),
    tanggal: tanggalIndonesia(recordedAt),
    waktu: waktuIndonesia(recordedAt, durationSeconds),
    tempat: defaults.tempat,
    notulis: defaults.notulis,
    peserta: draft?.peserta.isNotEmpty == true
        ? draft!.peserta
        : pesertaFromSegments(segments),
    pembahasan: draft?.pembahasan ?? '',
    keputusan: draft?.keputusan ?? const [],
    // F6: the structured checklist wins over re-parsing the summary
    // prose. Those rows are what the user actually reviewed and
    // corrected, and a notulen that disagrees with the checklist on
    // screen is the version that gets signed.
    tindakLanjut: _tindakLanjutFrom(actionItems, draft),
    kopSuratPath: defaults.kopSuratPath,
  );
}

/// The notulen's "Tindak Lanjut" rows.
///
/// Cancelled tasks are left out — a document that lists a dropped task
/// next to live ones reads as an instruction to do it. Anything the
/// checklist does not cover falls back to the summary draft.
List<NotulenTask> _tindakLanjutFrom(
  List<ActionItem> actionItems,
  NotulenDraft? draft,
) {
  final live = [
    for (final item in actionItems)
      if (item.tugas.trim().isNotEmpty &&
          item.status != ActionStatus.dibatalkan)
        NotulenTask(
          tugas: item.tugas,
          penanggungJawab: item.penanggungJawab,
          tenggat: item.tenggat,
        ),
  ];
  if (live.isNotEmpty) return live;
  return [
    for (final task in draft?.tindakLanjut ?? const <TindakLanjut>[])
      NotulenTask(
        tugas: task.tugas,
        penanggungJawab: task.penanggungJawab,
        tenggat: task.tenggat,
      ),
  ];
}

/// Opens the notulen form for [session] and, on confirm, writes the DOCX.
///
/// Returns the form the user saved (so the caller can persist it to the
/// sidecar), or `null` if they cancelled.
Future<NotulenFormData?> showNotulenDialog(
  BuildContext context, {
  required SessionSummary session,
  required DateTime recordedAt,
  required String summary,
  required List<Bookmark> bookmarks,
  NotulenFormData? saved,
  List<ActionItem> actionItems = const [],
}) {
  return showDialog<NotulenFormData>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NotulenDialog(
      session: session,
      recordedAt: recordedAt,
      summary: summary,
      bookmarks: bookmarks,
      saved: saved,
      actionItems: actionItems,
    ),
  );
}

class _NotulenDialog extends ConsumerStatefulWidget {
  const _NotulenDialog({
    required this.session,
    required this.recordedAt,
    required this.summary,
    required this.bookmarks,
    this.saved,
    this.actionItems = const [],
  });

  final SessionSummary session;
  final DateTime recordedAt;
  final String summary;
  final List<Bookmark> bookmarks;
  final NotulenFormData? saved;

  /// The session's reviewed checklist (F6), preferred over whatever the
  /// summary prose can be parsed into.
  final List<ActionItem> actionItems;

  @override
  ConsumerState<_NotulenDialog> createState() => _NotulenDialogState();
}

class _NotulenDialogState extends ConsumerState<_NotulenDialog> {
  NotulenFormData _form = const NotulenFormData();
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key, String initial) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  Future<void> _prefill() async {
    NotulenDraft? draft;
    if (widget.saved == null && widget.summary.trim().isNotEmpty) {
      try {
        draft = await ref
            .read(rustBridgeProvider)
            .notulenDraftFromSummary(widget.summary);
      } catch (_) {
        // A summary that cannot be parsed still reaches the document: the
        // raw text goes into Pembahasan below.
      }
    }
    final form = buildNotulenPrefill(
      title: widget.session.title,
      recordedAt: widget.recordedAt,
      durationSeconds: widget.session.durationSeconds,
      defaults: ref.read(settingsProvider).notulen,
      segments: widget.session.segments,
      saved: widget.saved,
      draft: draft,
      actionItems: widget.actionItems,
    );
    if (!mounted) return;
    setState(() {
      _form =
          draft == null &&
              widget.saved == null &&
              widget.summary.trim().isNotEmpty
          // No parse, but there *is* a summary — do not silently lose it.
          ? form.copyWith(pembahasan: widget.summary.trim())
          : form;
      _loading = false;
    });
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final bridge = ref.read(rustBridgeProvider);
      final poinPenting = widget.bookmarks.isEmpty
          ? const <String>[]
          : await bridge.formatBookmarks(widget.bookmarks);
      final outputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilih folder untuk notulen',
      );
      if (outputDir == null) {
        if (mounted) setState(() => _exporting = false);
        return;
      }
      final exported = await bridge.exportNotulen(
        form: _form.toRust(poinPenting: poinPenting),
        segments: widget.session.segments,
        outputDir: outputDir,
        title: widget.session.title,
      );
      if (!mounted) return;
      Navigator.of(context).pop(_form);
      AppToast.show(
        context,
        'Notulen tersimpan: ${exported.path}',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _error = 'Gagal membuat notulen: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: const Text('Notulen Rapat'),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(Spacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _variantPicker(colors),
                    Spacing.gapLg,
                    _sectionLabel('Identitas rapat', colors),
                    Spacing.gapSm,
                    _field(
                      'judul',
                      'Judul Rapat',
                      _form.judul,
                      (v) => _form = _form.copyWith(judul: v),
                    ),
                    if (_form.variant == NotulenVariant.dinas) ...[
                      Spacing.gapMd,
                      _field(
                        'nomor',
                        'Nomor Notulen',
                        _form.nomor,
                        (v) => _form = _form.copyWith(nomor: v),
                        hint: 'mis. ND-12/AG.3/2026',
                      ),
                      Spacing.gapMd,
                      _field(
                        'instansi',
                        'Instansi (kop surat)',
                        _form.instansi,
                        (v) => _form = _form.copyWith(instansi: v),
                      ),
                      Spacing.gapMd,
                      _field(
                        'unitKerja',
                        'Unit kerja (baris kedua kop)',
                        _form.unitKerja,
                        (v) => _form = _form.copyWith(unitKerja: v),
                      ),
                    ],
                    Spacing.gapMd,
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'hari',
                            'Hari',
                            _form.hari,
                            (v) => _form = _form.copyWith(hari: v),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          flex: 2,
                          child: _field(
                            'tanggal',
                            'Tanggal',
                            _form.tanggal,
                            (v) => _form = _form.copyWith(tanggal: v),
                          ),
                        ),
                      ],
                    ),
                    Spacing.gapMd,
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'waktu',
                            'Waktu',
                            _form.waktu,
                            (v) => _form = _form.copyWith(waktu: v),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: _field(
                            'tempat',
                            'Tempat/Media',
                            _form.tempat,
                            (v) => _form = _form.copyWith(tempat: v),
                          ),
                        ),
                      ],
                    ),
                    Spacing.gapMd,
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'pimpinan',
                            'Pimpinan Rapat',
                            _form.pimpinan,
                            (v) => _form = _form.copyWith(pimpinan: v),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: _field(
                            'notulis',
                            'Notulis',
                            _form.notulis,
                            (v) => _form = _form.copyWith(notulis: v),
                          ),
                        ),
                      ],
                    ),
                    Spacing.gapLg,
                    _sectionLabel('Peserta', colors),
                    Spacing.gapSm,
                    _ListEditor(
                      items: _form.peserta,
                      hint: 'Nama peserta',
                      addLabel: 'Tambah peserta',
                      onChanged: (items) => setState(
                        () => _form = _form.copyWith(peserta: items),
                      ),
                    ),
                    Spacing.gapLg,
                    _sectionLabel('Agenda', colors),
                    Spacing.gapSm,
                    _ListEditor(
                      items: _form.agenda,
                      hint: 'Butir agenda',
                      addLabel: 'Tambah agenda',
                      onChanged: (items) =>
                          setState(() => _form = _form.copyWith(agenda: items)),
                    ),
                    Spacing.gapLg,
                    _sectionLabel('Pembahasan', colors),
                    Spacing.gapSm,
                    TextField(
                      controller: _controller('pembahasan', _form.pembahasan),
                      maxLines: 6,
                      minLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            'Isi pembahasan. Terisi otomatis dari '
                            'ringkasan AI kalau ada.',
                        isDense: true,
                      ),
                      onChanged: (v) => _form = _form.copyWith(pembahasan: v),
                    ),
                    Spacing.gapLg,
                    _sectionLabel('Keputusan', colors),
                    Spacing.gapSm,
                    _ListEditor(
                      items: _form.keputusan,
                      hint: 'Keputusan rapat',
                      addLabel: 'Tambah keputusan',
                      onChanged: (items) => setState(
                        () => _form = _form.copyWith(keputusan: items),
                      ),
                    ),
                    Spacing.gapLg,
                    _sectionLabel('Tindak Lanjut', colors),
                    Spacing.gapSm,
                    _TaskEditor(
                      tasks: _form.tindakLanjut,
                      onChanged: (tasks) => setState(
                        () => _form = _form.copyWith(tindakLanjut: tasks),
                      ),
                    ),
                    if (widget.bookmarks.isNotEmpty) ...[
                      Spacing.gapLg,
                      Row(
                        children: [
                          Icon(
                            AppIcons.bookmark,
                            size: IconSizes.sm,
                            color: colors.primary,
                          ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Text(
                              '${widget.bookmarks.length} poin penting yang '
                              'Anda tandai saat rapat akan disertakan.',
                              style: TextStyle(
                                fontSize: FontSizes.caption,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    Spacing.gapMd,
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _form.lampirkanTranskrip,
                      onChanged: (v) => setState(
                        () => _form = _form.copyWith(
                          lampirkanTranskrip: v ?? false,
                        ),
                      ),
                      title: const Text('Lampirkan transkrip lengkap'),
                      subtitle: Text(
                        '${widget.session.segmentsCount} baris transkrip '
                        'ditambahkan di halaman terpisah.',
                        style: TextStyle(
                          fontSize: FontSizes.caption,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      Spacing.gapMd,
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: colors.error,
                            fontSize: FontSizes.caption,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _loading || _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: IconSizes.sm,
                  height: IconSizes.sm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.document, size: IconSizes.md),
          label: Text(_exporting ? 'Menyusun…' : 'Buat Notulen (DOCX)'),
        ),
      ],
    );
  }

  Widget _variantPicker(AppColorSet colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('Bentuk notulen', colors),
      Spacing.gapSm,
      SegmentedButton<NotulenVariant>(
        segments: const [
          ButtonSegment(
            value: NotulenVariant.dinas,
            label: Text('Notulen Dinas'),
            icon: Icon(AppIcons.institution, size: IconSizes.md),
          ),
          ButtonSegment(
            value: NotulenVariant.ringkas,
            label: Text('Notulen Ringkas'),
            icon: Icon(AppIcons.shortText, size: IconSizes.md),
          ),
        ],
        selected: {_form.variant},
        onSelectionChanged: (selection) =>
            setState(() => _form = _form.copyWith(variant: selection.first)),
      ),
      Spacing.gapSm,
      Text(
        _form.variant == NotulenVariant.dinas
            ? 'Format lengkap tata naskah dinas: kop surat, nomor, '
                  'daftar peserta bernomor dan blok tanda tangan.'
            : 'Satu halaman tanpa kop surat dan tanda tangan, untuk '
                  'dibagikan cepat.',
        style: TextStyle(
          fontSize: FontSizes.caption,
          color: colors.textTertiary,
          height: 1.3,
        ),
      ),
    ],
  );

  Widget _sectionLabel(String text, AppColorSet colors) => Text(
    text,
    style: TextStyle(
      fontSize: FontSizes.caption,
      fontWeight: FontWeight.w600,
      color: colors.textTertiary,
      letterSpacing: 0.5,
    ),
  );

  Widget _field(
    String key,
    String label,
    String initial,
    void Function(String) onChanged, {
    String? hint,
  }) => TextField(
    controller: _controller(key, initial),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    onChanged: onChanged,
  );
}

/// A reorder-free editable list of single-line strings.
class _ListEditor extends StatefulWidget {
  const _ListEditor({
    required this.items,
    required this.hint,
    required this.addLabel,
    required this.onChanged,
  });

  final List<String> items;
  final String hint;
  final String addLabel;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<_ListEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    _controller.clear();
    widget.onChanged([...widget.items, value]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.isNotEmpty)
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                InputChip(
                  label: Text('${i + 1}. ${widget.items[i]}'),
                  deleteButtonTooltipMessage: 'Hapus ${widget.items[i]}',
                  onDeleted: () =>
                      widget.onChanged([...widget.items]..removeAt(i)),
                ),
            ],
          ),
        if (widget.items.isNotEmpty) Spacing.gapSm,
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            IconButton(
              tooltip: widget.addLabel,
              constraints: TouchTarget.constraints,
              icon: const Icon(AppIcons.add, size: IconSizes.md),
              onPressed: _add,
            ),
          ],
        ),
      ],
    );
  }
}

/// The tugas / penanggung jawab / tenggat table.
class _TaskEditor extends StatelessWidget {
  const _TaskEditor({required this.tasks, required this.onChanged});

  final List<NotulenTask> tasks;
  final ValueChanged<List<NotulenTask>> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tasks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: tasks[i].tugas,
                    decoration: const InputDecoration(
                      labelText: 'Tugas',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => onChanged(
                      [...tasks]..[i] = tasks[i].copyWith(tugas: v),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: tasks[i].penanggungJawab,
                    decoration: const InputDecoration(
                      labelText: 'Penanggung Jawab',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => onChanged(
                      [...tasks]..[i] = tasks[i].copyWith(penanggungJawab: v),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: tasks[i].tenggat,
                    decoration: const InputDecoration(
                      labelText: 'Tenggat',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => onChanged(
                      [...tasks]..[i] = tasks[i].copyWith(tenggat: v),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus baris tindak lanjut',
                  constraints: TouchTarget.constraints,
                  icon: Icon(
                    AppIcons.delete,
                    size: IconSizes.md,
                    color: colors.textSecondary,
                  ),
                  onPressed: () => onChanged([...tasks]..removeAt(i)),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => onChanged([...tasks, const NotulenTask()]),
            icon: const Icon(AppIcons.add, size: IconSizes.md),
            label: const Text('Tambah tindak lanjut'),
          ),
        ),
      ],
    );
  }
}
