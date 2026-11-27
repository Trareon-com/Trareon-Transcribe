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

import '../l10n/l10n.dart';
import '../src/rust/notulen.dart';

/// One template, as the picker shows it.
class NotulenTemplateInfo {
  const NotulenTemplateInfo({
    required this.template,
    required this.id,
    required this.documentTitle,
    required this.jenisNaskah,
    required this.formal,
  });

  final NotulenTemplate template;

  /// Stable id, matching `NotulenTemplate::id` and the benchmark's
  /// `templat:` field.
  final String id;
  /// Shown in the template picker, in the interface language.
  String get label => switch (template) {
    NotulenTemplate.dinas => currentL10n.notulenTemplatesDinasLabel,
    NotulenTemplate.risalah => currentL10n.notulenTemplatesRisalahLabel,
    NotulenTemplate.beritaAcara => currentL10n.notulenTemplatesBeritaAcaraLabel,
    NotulenTemplate.ringkas => currentL10n.notulenTemplatesRingkasLabel,
  };

  /// One-line explanation under the picker, in the interface language.
  String get description => switch (template) {
    NotulenTemplate.dinas => currentL10n.notulenTemplatesDinasDescription,
    NotulenTemplate.risalah => currentL10n.notulenTemplatesRisalahDescription,
    NotulenTemplate.beritaAcara =>
      currentL10n.notulenTemplatesBeritaAcaraDescription,
    NotulenTemplate.ringkas => currentL10n.notulenTemplatesRingkasDescription,
  };

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
    documentTitle: 'NOTULA RAPAT',
    jenisNaskah: 'Notula Rapat',
    formal: true,
  ),
  NotulenTemplateInfo(
    template: NotulenTemplate.risalah,
    id: 'risalah_rapat',
    documentTitle: 'RISALAH RAPAT',
    jenisNaskah: 'Risalah Rapat',
    formal: true,
  ),
  NotulenTemplateInfo(
    template: NotulenTemplate.beritaAcara,
    id: 'berita_acara',
    documentTitle: 'BERITA ACARA',
    jenisNaskah: 'Berita Acara',
    formal: true,
  ),
  NotulenTemplateInfo(
    template: NotulenTemplate.ringkas,
    id: 'notulen_ringkas',
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
