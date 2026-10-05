/// Mode Kepatuhan UU PDP (F13), Dart side.
///
/// The engine owns detection and deletion; these guard the parts the user
/// actually touches — the master switch, the label mappings the viewer
/// renders without a bridge round trip, and the preview wording.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/widgets/audit_log_view.dart';
import 'package:transcribe/widgets/pdp_settings_section.dart';
import 'package:transcribe/widgets/redaction_preview.dart';

PiiMatch match(PiiKind kind, String text) => PiiMatch(
  kind: kind,
  start: 0,
  end: text.length,
  text: text,
  replacement: '[X]',
);

AuditEntry entry(AuditAction action, {String subject = 'Rapat'}) => AuditEntry(
  atUnixMs: BigInt.from(1767225600000),
  action: action,
  actor: 'budi',
  subject: subject,
  destination: '',
  detail: '',
);

void main() {
  group('the master switch', () {
    test('a fresh install is entirely inert', () {
      const pdp = kDefaultPdpSettings;
      expect(pdp.enabled, isFalse);
      expect(pdp.redacts, isFalse);
      expect(pdp.consentReminder, isFalse);
      expect(pdp.retention.audioDays, 0);
      expect(pdp.retention.transcriptDays, 0);
    });

    test('turning compliance off neutralises the redaction config', () {
      // The categories stay checked so the user does not have to re-pick
      // them, but nothing is masked while the mode is off.
      final pdp = kDefaultPdpSettings.copyWith(enabled: false);
      expect(pdp.redaction.nik, isTrue, reason: 'the choice is remembered');
      expect(pdp.redacts, isFalse);
      expect(pdp.activeRedaction.nik, isFalse);
      expect(pdp.activeRedaction.names, isEmpty);
    });

    test('with the mode on, a category has to be selected too', () {
      final off = kDefaultPdpSettings.copyWith(
        enabled: true,
        redaction: const RedactionConfig(
          nik: false,
          npwp: false,
          phone: false,
          email: false,
          bankAccount: false,
          names: [],
        ),
      );
      expect(off.redacts, isFalse);
      expect(
        off.copyWith(redaction: off.redaction.copyWith(nik: true)).redacts,
        isTrue,
      );
    });

    test('a name list alone is enough to redact', () {
      final pdp = kDefaultPdpSettings.copyWith(
        enabled: true,
        redaction: const RedactionConfig(
          nik: false,
          npwp: false,
          phone: false,
          email: false,
          bankAccount: false,
          names: ['Budi Santoso'],
        ),
      );
      expect(pdp.redacts, isTrue);
      expect(pdp.activeRedaction.names, ['Budi Santoso']);
    });

    test('copyWith does not clear what it was not asked about', () {
      // The bug this guards: a toggle that silently emptied the name list.
      final pdp = kDefaultPdpSettings.copyWith(
        enabled: true,
        redaction: kDefaultPdpSettings.redaction.copyWith(
          names: ['Budi', 'Siti'],
        ),
        consentText: 'Rapat ini direkam.',
      );
      final toggled = pdp.copyWith(consentReminder: true);
      expect(toggled.redaction.names, ['Budi', 'Siti']);
      expect(toggled.consentText, 'Rapat ini direkam.');
      expect(toggled.enabled, isTrue);
    });
  });

  group('retention labels', () {
    test('zero reads as "keep forever", not "0 hari"', () {
      expect(retentionLabel(0), 'Simpan selamanya');
    });

    test('long periods are given in the unit people use', () {
      expect(retentionLabel(90), '90 hari (3 bulan)');
      expect(retentionLabel(365), '1 tahun');
      expect(retentionLabel(730), '2 tahun');
    });

    test('every offered choice has a label', () {
      for (final days in kRetentionChoices) {
        expect(retentionLabel(days), isNotEmpty);
        expect(retentionLabel(days), isNot(contains('null')));
      }
    });

    test('keeping forever is the first and default choice', () {
      expect(kRetentionChoices.first, 0);
    });
  });

  group('redaction preview wording', () {
    test('counts by category in Indonesian', () {
      final summary = redactionSummary([
        match(PiiKind.nik, '3174012509800003'),
        match(PiiKind.nik, '3273010101900001'),
        match(PiiKind.email, 'budi@contoh.go.id'),
      ]);
      expect(summary, contains('2 NIK'));
      expect(summary, contains('1 Alamat email'));
      expect(summary, endsWith('akan disamarkan.'));
    });

    test('nothing to mask says so rather than showing an empty count', () {
      expect(redactionSummary(const []), 'Tidak ada yang akan disamarkan.');
    });

    test('every PII kind has an Indonesian label', () {
      for (final kind in PiiKind.values) {
        expect(piiKindLabel(kind), isNotEmpty);
      }
      expect(piiKindLabel(PiiKind.bankAccount), 'Nomor rekening');
    });
  });

  group('audit log view', () {
    test('every action has an Indonesian label', () {
      for (final action in AuditAction.values) {
        expect(
          auditActionLabel(action),
          isNotEmpty,
          reason: '$action has no label',
        );
      }
      expect(
        auditActionLabel(AuditAction.summarySent),
        'Ringkasan dikirim ke endpoint',
      );
    });

    test('timestamps render as Indonesian day/month order', () {
      final text = formatAuditTime(
        BigInt.from(DateTime(2026, 10, 4, 9, 5).millisecondsSinceEpoch),
      );
      expect(text, '04/10/2026 09:05');
    });

    testWidgets('an empty log explains itself instead of showing blank', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AuditLogView(entries: [])),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Belum ada catatan'), findsOneWidget);
    });

    testWidgets('entries render newest-first as the engine returns them', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditLogView(
              entries: [
                entry(AuditAction.sessionExported, subject: 'Rapat Anggaran'),
                entry(AuditAction.sessionCreated, subject: 'Rapat Anggaran'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('Transkrip diekspor: Rapat Anggaran'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sesi dibuat: Rapat Anggaran'),
        findsOneWidget,
      );
    });
  });

  group('redaction preview widget', () {
    testWidgets('lists each match with what replaces it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RedactionPreview(
              segments: const [],
              config: kDefaultPdpSettings.redaction,
              matches: [
                PiiMatch(
                  kind: PiiKind.nik,
                  start: 0,
                  end: 16,
                  text: '3174012509800003',
                  replacement: '[NIK]',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1 NIK akan disamarkan.'), findsOneWidget);
      expect(find.textContaining('3174012509800003'), findsWidgets);
    });

    testWidgets('a clean transcript says the export is unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RedactionPreview(
              segments: const [],
              config: kDefaultPdpSettings.redaction,
              matches: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('Tidak ada data pribadi yang terdeteksi'),
        findsOneWidget,
      );
    });
  });
}
