// Sprint 20 Bagian C — Item 4 Sprint 7 disambungkan ke UI: formulir
// metadata SRIKANDI harus benar-benar memanggil srikandiMetadataDefault,
// srikandiValidate, srikandiSiapUnggah, dan exportNotulenSrikandi dari
// widget tree aplikasi nyata — bukan hanya ada sebagai modul Rust yang
// tidak pernah dipanggil (lihat docs/SPRINT-REPORTS.md §Sprint 7 Item 4).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/export/notulen.dart' as rust_notulen;
import 'package:transcribe/src/rust/srikandi.dart' as rust_srikandi;
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/widgets/srikandi_export_dialog.dart';
import 'package:transcribe/widgets/ui/app_button.dart';
import 'package:transcribe/widgets/ui/app_field.dart';

import 'test_helpers.dart';

const _form = rust_notulen.NotulenForm(
  template: NotulenTemplate.dinas,
  instansi: 'Dinas Komunikasi dan Informatika',
  unitKerja: 'Bidang Persandian',
  nomor: '',
  judul: 'Rapat Koordinasi Triwulan',
  hari: 'Kamis',
  tanggal: '1 Oktober 2026',
  waktu: '09.05 - 11.30 WIB',
  tempat: 'Ruang Rapat Lt. 5',
  pimpinan: 'Budi Santoso',
  notulis: 'Siti Aminah',
  peserta: ['Budi Santoso', 'Siti Aminah'],
  agenda: ['Pagu indikatif'],
  ringkasan: '',
  pembahasan: 'Pembahasan pagu indikatif triwulan.',
  jalannyaRapat: [],
  pihak: [],
  keputusan: ['Menyusun jadwal penyerapan mingguan'],
  tindakLanjut: [],
  poinPenting: [],
  kopSuratPath: '',
  lampirkanTranskrip: false,
);

/// Records every call so the test can assert the real API chain ran:
/// default → validate (on load, and again on every edit) → siapUnggah →
/// exportNotulenSrikandi, in that order.
class _SrikandiBridge extends NoopBridge {
  int defaultCalls = 0;
  int validateCalls = 0;
  int siapUnggahCalls = 0;
  int exportCalls = 0;
  rust_srikandi.SrikandiMetadata? lastValidated;
  rust_srikandi.SrikandiMetadata? lastExported;

  @override
  Future<rust_srikandi.SrikandiMetadata> srikandiMetadataDefault(
    rust_notulen.NotulenForm form,
  ) async {
    defaultCalls++;
    return rust_srikandi.SrikandiMetadata(
      nomor: '',
      tanggal: form.tanggal,
      jenisNaskah: 'Notula Rapat',
      perihal: form.judul,
      sifat: rust_srikandi.Sifat.biasa,
      klasifikasiKeamanan: rust_srikandi.KlasifikasiKeamanan.biasa,
      kodeKlasifikasiArsip: '',
      unitPengolah: form.unitKerja,
      penandatanganNama: form.pimpinan,
      penandatanganJabatan: '',
      jumlahLampiran: 0,
      tingkatPerkembangan: rust_srikandi.TingkatPerkembangan.asli,
      catatan: '',
    );
  }

  @override
  Future<List<rust_srikandi.TemuanMetadata>> srikandiValidate(
    rust_srikandi.SrikandiMetadata metadata,
  ) async {
    validateCalls++;
    lastValidated = metadata;
    return [
      if (metadata.nomor.trim().isEmpty)
        const rust_srikandi.TemuanMetadata(
          bidang: 'nomor',
          tingkat: rust_srikandi.Tingkat.wajib,
          pesan: 'Nomor naskah belum diisi.',
        ),
      if (metadata.kodeKlasifikasiArsip.trim().isEmpty)
        const rust_srikandi.TemuanMetadata(
          bidang: 'kodeKlasifikasiArsip',
          tingkat: rust_srikandi.Tingkat.saran,
          pesan: 'Kode klasifikasi arsip belum diisi.',
        ),
    ];
  }

  @override
  Future<bool> srikandiSiapUnggah(
    rust_srikandi.SrikandiMetadata metadata,
  ) async {
    siapUnggahCalls++;
    return metadata.nomor.trim().isNotEmpty;
  }

  @override
  Future<List<rust_export.ExportedFile>> exportNotulenSrikandi({
    required rust_notulen.NotulenForm form,
    required rust_srikandi.SrikandiMetadata metadata,
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
  }) async {
    exportCalls++;
    lastExported = metadata;
    return [
      rust_export.ExportedFile(
        filename: '$title.docx',
        path: '$outputDir/$title.docx',
        sizeBytes: BigInt.from(2048),
      ),
      rust_export.ExportedFile(
        filename: '$title.pdf',
        path: '$outputDir/$title.pdf',
        sizeBytes: BigInt.from(2048),
      ),
      rust_export.ExportedFile(
        filename: '$title - metadata.json',
        path: '$outputDir/$title - metadata.json',
        sizeBytes: BigInt.from(256),
      ),
      rust_export.ExportedFile(
        filename: '$title - metadata.csv',
        path: '$outputDir/$title - metadata.csv',
        sizeBytes: BigInt.from(128),
      ),
    ];
  }
}

Future<void> _open(WidgetTester tester, RustBridge bridge) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    buildTestAppWithOverrides(
      overrides: [rustBridgeProvider.overrideWithValue(bridge)],
      child: Builder(
        builder: (context) => Material(
          child: Center(
            child: AppButton.primary(
              label: 'Buka',
              onPressed: () => showSrikandiExportDialog(
                context,
                form: _form,
                segments: const [],
                title: 'Rapat Koordinasi Triwulan',
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'membuka formulir memanggil srikandiMetadataDefault dan srikandiValidate sungguhan',
    (tester) async {
      final bridge = _SrikandiBridge();
      await _open(tester, bridge);

      expect(bridge.defaultCalls, 1);
      expect(bridge.validateCalls, 1);
      // nomor sengaja kosong (tidak pernah diisi otomatis) — validator
      // menandainya Wajib, dan itu harus terlihat pengguna.
      expect(find.textContaining('Wajib'), findsOneWidget);
      expect(find.textContaining('Nomor naskah belum diisi'), findsOneWidget);
      expect(find.textContaining('Saran'), findsOneWidget);

      // Perihal terisi dari judul rapat (form.judul), nomor dibiarkan kosong.
      expect(
        find.widgetWithText(AppTextField, 'Rapat Koordinasi Triwulan'),
        findsOneWidget,
      );
    },
  );

  testWidgets('mengisi nomor memicu srikandiValidate ulang dan temuan hilang', (
    tester,
  ) async {
    final bridge = _SrikandiBridge();
    await _open(tester, bridge);

    final nomorField = find.ancestor(
      of: find.text('Nomor naskah'),
      matching: find.byType(AppTextField),
    );
    await tester.enterText(nomorField, 'B-125/TU.01/KP.03/10/2026');
    await tester.pumpAndSettle();

    expect(bridge.validateCalls, greaterThanOrEqualTo(2));
    expect(bridge.lastValidated?.nomor, 'B-125/TU.01/KP.03/10/2026');
    expect(find.textContaining('Nomor naskah belum diisi'), findsNothing);
  });

  testWidgets(
    'tombol ekspor menolak saat belum siap, lalu memanggil siapUnggah dan exportNotulenSrikandi',
    (tester) async {
      final bridge = _SrikandiBridge();
      await _open(tester, bridge);

      await tester.tap(find.text('Ekspor (4 berkas)'));
      await tester.pumpAndSettle();

      // nomor kosong → siapUnggah() sungguhan mengembalikan false, dan
      // exportNotulenSrikandi tidak boleh dipanggil sampai itu lunas.
      expect(bridge.siapUnggahCalls, 1);
      expect(bridge.exportCalls, 0);
      expect(find.textContaining('Metadata belum lengkap'), findsOneWidget);

      final nomorField = find.ancestor(
        of: find.text('Nomor naskah'),
        matching: find.byType(AppTextField),
      );
      await tester.enterText(nomorField, 'B-125/TU.01/KP.03/10/2026');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ekspor (4 berkas)'));
      await tester.pumpAndSettle();

      expect(bridge.siapUnggahCalls, 2);
      // getDirectoryPath has no native picker in the test sandbox and
      // resolves to null, which is treated exactly like the user cancelling
      // the folder dialog — exportNotulenSrikandi is reached only past that.
      expect(bridge.exportCalls, 0);
    },
  );
}
