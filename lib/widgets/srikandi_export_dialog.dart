/// Formulir metadata SRIKANDI (Sprint 7 Item 4, disambungkan ke UI di
/// Sprint 20).
///
/// Prefill dari `srikandiMetadataDefault`, validasi real-time lewat
/// `srikandiValidate` (Wajib/Saran per bidang), lalu ekspor lewat
/// `srikandiSiapUnggah` + `exportNotulenSrikandi` (empat berkas: DOCX, PDF,
/// metadata JSON, metadata CSV). Prosedur lengkap ada di
/// `docs/SRIKANDI-EXPORT.md`. `nomor` TIDAK pernah diisi otomatis — lihat
/// §3 dokumen itu — dan validator hanya menandainya, tidak menggantinya.
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/export/notulen.dart' as rust_notulen;
import '../src/rust/srikandi.dart' as rust_srikandi;
import '../state/models.dart';
import '../state/settings_model.dart' show rustBridgeProvider;
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'app_toast.dart';
import 'settings_controls.dart' show CompactDropdown;
import 'ui/app_button.dart';
import 'ui/app_dialog.dart';
import 'ui/app_feedback.dart';
import 'ui/app_field.dart';
import 'ui/app_surface.dart' show AppGroupLabel;

/// Opens the SRIKANDI metadata form for a notulen already prefilled by the
/// notulen dialog. Returns `true` when the four files were written.
Future<bool> showSrikandiExportDialog(
  BuildContext context, {
  required rust_notulen.NotulenForm form,
  required List<TranscriptSegment> segments,
  required String title,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _SrikandiExportDialog(form: form, segments: segments, title: title),
  );
  return result ?? false;
}

String _sifatLabel(rust_srikandi.Sifat sifat) => switch (sifat) {
  rust_srikandi.Sifat.sangatSegera => 'Sangat Segera (24 jam)',
  rust_srikandi.Sifat.segera => 'Segera (2x24 jam)',
  rust_srikandi.Sifat.biasa => 'Biasa',
};

String _klasifikasiLabel(rust_srikandi.KlasifikasiKeamanan k) => switch (k) {
  rust_srikandi.KlasifikasiKeamanan.sangatRahasia => 'Sangat Rahasia',
  rust_srikandi.KlasifikasiKeamanan.rahasia => 'Rahasia',
  rust_srikandi.KlasifikasiKeamanan.terbatas => 'Terbatas',
  rust_srikandi.KlasifikasiKeamanan.biasa => 'Biasa',
};

String _tingkatLabel(rust_srikandi.TingkatPerkembangan t) => switch (t) {
  rust_srikandi.TingkatPerkembangan.asli => 'Asli',
  rust_srikandi.TingkatPerkembangan.salinan => 'Salinan',
  rust_srikandi.TingkatPerkembangan.tembusan => 'Tembusan',
  rust_srikandi.TingkatPerkembangan.pertinggal => 'Pertinggal',
};

class _SrikandiExportDialog extends ConsumerStatefulWidget {
  const _SrikandiExportDialog({
    required this.form,
    required this.segments,
    required this.title,
  });

  final rust_notulen.NotulenForm form;
  final List<TranscriptSegment> segments;
  final String title;

  @override
  ConsumerState<_SrikandiExportDialog> createState() =>
      _SrikandiExportDialogState();
}

class _SrikandiExportDialogState
    extends ConsumerState<_SrikandiExportDialog> {
  rust_srikandi.SrikandiMetadata? _metadata;
  List<rust_srikandi.TemuanMetadata> _temuan = const [];
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
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key, String initial) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  Future<void> _prefill() async {
    try {
      final metadata = await ref
          .read(rustBridgeProvider)
          .srikandiMetadataDefault(widget.form);
      if (!mounted) return;
      setState(() {
        _metadata = metadata;
        _loading = false;
      });
      await _validate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal menyiapkan metadata: $e';
        _loading = false;
      });
    }
  }

  Future<void> _validate() async {
    final metadata = _metadata;
    if (metadata == null) return;
    try {
      final temuan = await ref
          .read(rustBridgeProvider)
          .srikandiValidate(metadata);
      if (!mounted) return;
      setState(() => _temuan = temuan);
    } catch (_) {
      // Validation is advisory; a failed check must not block editing.
    }
  }

  void _update({
    String? nomor,
    String? tanggal,
    String? jenisNaskah,
    String? perihal,
    rust_srikandi.Sifat? sifat,
    rust_srikandi.KlasifikasiKeamanan? klasifikasiKeamanan,
    String? kodeKlasifikasiArsip,
    String? unitPengolah,
    String? penandatanganNama,
    String? penandatanganJabatan,
    int? jumlahLampiran,
    rust_srikandi.TingkatPerkembangan? tingkatPerkembangan,
    String? catatan,
  }) {
    final current = _metadata;
    if (current == null) return;
    setState(() {
      _metadata = rust_srikandi.SrikandiMetadata(
        nomor: nomor ?? current.nomor,
        tanggal: tanggal ?? current.tanggal,
        jenisNaskah: jenisNaskah ?? current.jenisNaskah,
        perihal: perihal ?? current.perihal,
        sifat: sifat ?? current.sifat,
        klasifikasiKeamanan:
            klasifikasiKeamanan ?? current.klasifikasiKeamanan,
        kodeKlasifikasiArsip:
            kodeKlasifikasiArsip ?? current.kodeKlasifikasiArsip,
        unitPengolah: unitPengolah ?? current.unitPengolah,
        penandatanganNama: penandatanganNama ?? current.penandatanganNama,
        penandatanganJabatan:
            penandatanganJabatan ?? current.penandatanganJabatan,
        jumlahLampiran: jumlahLampiran ?? current.jumlahLampiran,
        tingkatPerkembangan:
            tingkatPerkembangan ?? current.tingkatPerkembangan,
        catatan: catatan ?? current.catatan,
      );
    });
    unawaited(_validate());
  }

  Future<void> _export() async {
    final metadata = _metadata;
    if (metadata == null) return;
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final bridge = ref.read(rustBridgeProvider);
      final siap = await bridge.srikandiSiapUnggah(metadata);
      if (!siap) {
        if (!mounted) return;
        setState(() {
          _exporting = false;
          _error = 'Metadata belum lengkap. Periksa temuan "Wajib" di atas.';
        });
        return;
      }
      final outputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilih folder untuk ekspor SRIKANDI',
      );
      if (outputDir == null) {
        if (mounted) setState(() => _exporting = false);
        return;
      }
      final exported = await bridge.exportNotulenSrikandi(
        form: widget.form,
        metadata: metadata,
        segments: widget.segments,
        outputDir: outputDir,
        title: widget.title,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppToast.show(
        context,
        '${exported.length} berkas siap-SRIKANDI tersimpan di $outputDir',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _error = 'Gagal mengekspor: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final metadata = _metadata;
    final wajib = _temuan
        .where((t) => t.tingkat == rust_srikandi.Tingkat.wajib)
        .toList();
    final saran = _temuan
        .where((t) => t.tingkat == rust_srikandi.Tingkat.saran)
        .toList();

    return AppDialog(
      title: 'Ekspor siap-SRIKANDI',
      icon: AppIcons.document,
      width: Measure.dialogForm,
      actions: [
        AppButton.ghost(
          onPressed: _exporting ? null : () => Navigator.of(context).pop(false),
          label: 'Batal',
        ),
        AppButton.primary(
          onPressed: (_loading || _exporting || metadata == null)
              ? null
              : _export,
          loading: _exporting,
          icon: AppIcons.download,
          label: _exporting ? 'Mengekspor…' : 'Ekspor (4 berkas)',
        ),
      ],
      child: SizedBox(
        width: double.infinity,
        child: _loading || metadata == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(Spacing.xl),
                  child: AppProgressRing(),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Berkas yang dihasilkan hanya disiapkan di perangkat ini. '
                    'Unggahan ke SRIKANDI tetap dilakukan manual lewat '
                    'antarmuka instansi (lihat docs/SRIKANDI-EXPORT.md).',
                    style: AppText.caption.c(colors.textSecondary),
                  ),
                  Spacing.gapLg,
                  _field(
                    'nomor',
                    'Nomor naskah',
                    metadata.nomor,
                    (v) => _update(nomor: v),
                    hint: 'Minta ke Tata Usaha unit, mis. B-125/TU.01/KP.03/10/2026',
                  ),
                  Spacing.gapMd,
                  _field(
                    'tanggal',
                    'Tanggal',
                    metadata.tanggal,
                    (v) => _update(tanggal: v),
                  ),
                  Spacing.gapMd,
                  _field(
                    'jenisNaskah',
                    'Jenis naskah',
                    metadata.jenisNaskah,
                    (v) => _update(jenisNaskah: v),
                  ),
                  Spacing.gapMd,
                  _field(
                    'perihal',
                    'Perihal',
                    metadata.perihal,
                    (v) => _update(perihal: v),
                  ),
                  Spacing.gapMd,
                  AppGroupLabel('Sifat'),
                  Spacing.gapSm,
                  CompactDropdown<rust_srikandi.Sifat>(
                    value: metadata.sifat,
                    items: rust_srikandi.Sifat.values,
                    labelBuilder: _sifatLabel,
                    onChanged: (v) => _update(sifat: v),
                  ),
                  Spacing.gapMd,
                  AppGroupLabel('Klasifikasi keamanan'),
                  Spacing.gapSm,
                  CompactDropdown<rust_srikandi.KlasifikasiKeamanan>(
                    value: metadata.klasifikasiKeamanan,
                    items: rust_srikandi.KlasifikasiKeamanan.values,
                    labelBuilder: _klasifikasiLabel,
                    onChanged: (v) => _update(klasifikasiKeamanan: v),
                  ),
                  Spacing.gapMd,
                  _field(
                    'kodeKlasifikasiArsip',
                    'Kode klasifikasi arsip',
                    metadata.kodeKlasifikasiArsip,
                    (v) => _update(kodeKlasifikasiArsip: v),
                    hint: 'Minta ke arsiparis unit, mis. UM.03.01',
                  ),
                  Spacing.gapMd,
                  _field(
                    'unitPengolah',
                    'Unit pengolah',
                    metadata.unitPengolah,
                    (v) => _update(unitPengolah: v),
                  ),
                  Spacing.gapMd,
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'penandatanganNama',
                          'Nama penandatangan',
                          metadata.penandatanganNama,
                          (v) => _update(penandatanganNama: v),
                        ),
                      ),
                      Spacing.hSm,
                      Expanded(
                        child: _field(
                          'penandatanganJabatan',
                          'Jabatan penandatangan',
                          metadata.penandatanganJabatan,
                          (v) => _update(penandatanganJabatan: v),
                        ),
                      ),
                    ],
                  ),
                  Spacing.gapMd,
                  _field(
                    'jumlahLampiran',
                    'Jumlah lampiran',
                    '${metadata.jumlahLampiran}',
                    (v) => _update(jumlahLampiran: int.tryParse(v) ?? 0),
                  ),
                  Spacing.gapMd,
                  AppGroupLabel('Tingkat perkembangan'),
                  Spacing.gapSm,
                  CompactDropdown<rust_srikandi.TingkatPerkembangan>(
                    value: metadata.tingkatPerkembangan,
                    items: rust_srikandi.TingkatPerkembangan.values,
                    labelBuilder: _tingkatLabel,
                    onChanged: (v) => _update(tingkatPerkembangan: v),
                  ),
                  Spacing.gapMd,
                  _field(
                    'catatan',
                    'Catatan',
                    metadata.catatan,
                    (v) => _update(catatan: v),
                  ),
                  if (wajib.isNotEmpty || saran.isNotEmpty) ...[
                    Spacing.gapLg,
                    AppGroupLabel('Pemeriksaan metadata'),
                    Spacing.gapSm,
                    for (final t in wajib)
                      _TemuanTile(temuan: t, colors: colors, wajib: true),
                    for (final t in saran)
                      _TemuanTile(temuan: t, colors: colors, wajib: false),
                  ],
                  if (_error != null) ...[
                    Spacing.gapMd,
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: AppText.caption.c(colors.error),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _field(
    String key,
    String label,
    String initial,
    void Function(String) onChanged, {
    String? hint,
  }) => AppTextField(
    controller: _controller(key, initial),
    label: label,
    placeholder: hint,
    reserveHelperSpace: false,
    onChanged: onChanged,
  );
}

class _TemuanTile extends StatelessWidget {
  const _TemuanTile({
    required this.temuan,
    required this.colors,
    required this.wajib,
  });

  final rust_srikandi.TemuanMetadata temuan;
  final AppColorSet colors;
  final bool wajib;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            wajib ? AppIcons.report : AppIcons.info,
            size: IconSizes.sm,
            color: wajib ? colors.error : colors.textSecondary,
          ),
          Spacing.hSm,
          Expanded(
            child: Text(
              '${wajib ? "Wajib" : "Saran"} · ${temuan.bidang}: ${temuan.pesan}',
              style: AppText.caption.c(
                wajib ? colors.error : colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
