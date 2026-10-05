/// The notulen templates, Dart-side.
///
/// `api.notulenTemplates()` is the engine's own table and is what the
/// export actually uses. This is a copy, because the template picker is
/// built inside `build()` and a bridge round trip there would make the
/// dialog open empty and then jump. The same reasoning, and the same
/// shape, as `auditActionLabel` in `widgets/audit_log_view.dart`.
///
/// The copy is checked rather than trusted: `rust_core` writes
/// `test/fixtures/notulen_templates.json` from
/// `NotulenTemplate::{label, description, document_title, jenis_naskah,
/// is_formal}`, and `test/notulen_templates_test.dart` fails when this
/// table drifts from it.
library;

import '../src/rust/notulen.dart';

/// One template, as the picker shows it.
class NotulenTemplateInfo {
  const NotulenTemplateInfo({
    required this.template,
    required this.id,
    required this.label,
    required this.description,
    required this.documentTitle,
    required this.jenisNaskah,
    required this.formal,
  });

  final NotulenTemplate template;

  /// Stable id, matching `NotulenTemplate::id` and the benchmark's
  /// `templat:` field.
  final String id;
  final String label;
  final String description;

  /// What the document calls itself, e.g. "NOTULA RAPAT".
  final String documentTitle;

  /// Jenis naskah dinas, for the archive metadata sidecar.
  final String jenisNaskah;

  /// Whether the layout carries a kop surat, a nomor and a signature
  /// block.
  final bool formal;
}

/// Every template, in the order the picker shows them.
const List<NotulenTemplateInfo> kNotulenTemplates = [
  NotulenTemplateInfo(
    template: NotulenTemplate.dinas,
    id: 'notulen_dinas',
    label: 'Notulen Dinas',
    description:
        'Notula lengkap sesuai Tata Naskah Dinas: identitas rapat, peserta, '
        'acara, jalannya rapat, kesimpulan, tindak lanjut, dan ruang tanda '
        'tangan notulis serta pimpinan rapat.',
    documentTitle: 'NOTULA RAPAT',
    jenisNaskah: 'Notula Rapat',
    formal: true,
  ),
  NotulenTemplateInfo(
    template: NotulenTemplate.risalah,
    id: 'risalah_rapat',
    label: 'Risalah Rapat (verbatim-ringkas)',
    description:
        'Catatan berurutan per pembicara, mendekati verbatim tetapi '
        'diringkas. Dipakai untuk sidang dan rapat yang perlu merekam siapa '
        'menyampaikan apa.',
    documentTitle: 'RISALAH RAPAT',
    jenisNaskah: 'Risalah Rapat',
    formal: true,
  ),
  NotulenTemplateInfo(
    template: NotulenTemplate.beritaAcara,
    id: 'berita_acara',
    label: 'Berita Acara',
    description:
        'Naskah pembuktian: menyebut para pihak, apa yang telah '
        'dilaksanakan, hasilnya, dan ditutup dengan formula baku "Demikian '
        'Berita Acara ini dibuat dengan sesungguhnya".',
    documentTitle: 'BERITA ACARA',
    jenisNaskah: 'Berita Acara',
    formal: true,
  ),
  NotulenTemplateInfo(
    template: NotulenTemplate.ringkas,
    id: 'notulen_ringkas',
    label: 'Notulen Ringkas',
    description:
        'Satu halaman tanpa kop surat dan tanpa tanda tangan, untuk '
        'diedarkan cepat setelah rapat.',
    documentTitle: 'NOTULEN RINGKAS',
    jenisNaskah: 'Notulen Ringkas',
    formal: false,
  ),
];

extension NotulenTemplateX on NotulenTemplate {
  NotulenTemplateInfo get info => kNotulenTemplates.firstWhere(
    (entry) => entry.template == this,
    orElse: () => kNotulenTemplates.first,
  );

  /// Whether this layout carries a kop surat, a nomor and a signature
  /// block. The field the form uses to decide which inputs to show.
  bool get isFormal => info.formal;

  String get label => info.label;

  String get jenisNaskah => info.jenisNaskah;
}
