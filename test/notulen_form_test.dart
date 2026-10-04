import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/widgets/notulen_dialog.dart';

/// Notulen Rapat (F2), Dart side: the Indonesian date/time conventions, the
/// prefill rules, and the form's round-trip through the session sidecar.
void main() {
  group('Indonesian date and time conventions', () {
    test('hari and tanggal are written out, never numeric', () {
      final date = DateTime(2026, 10, 1); // a Thursday
      expect(hariIndonesia(date), 'Kamis');
      expect(tanggalIndonesia(date), '1 Oktober 2026');
    });

    test('every weekday and month has a name', () {
      for (var day = 1; day <= 7; day++) {
        // 2026-06-01 is a Monday, so +0..+6 covers every weekday.
        final date = DateTime(2026, 6, day);
        expect(hariIndonesia(date), isNotEmpty);
        expect(kHariIndonesia, contains(hariIndonesia(date)));
      }
      for (var month = 1; month <= 12; month++) {
        expect(tanggalIndonesia(DateTime(2026, month, 15)),
            '15 ${kBulanIndonesia[month - 1]} 2026');
      }
    });

    test('waktu uses dots and spans the recording', () {
      final start = DateTime(2026, 10, 1, 9, 5);
      // 2 h 25 min.
      expect(waktuIndonesia(start, 8700), '09.05 – 11.30 WIB');
    });

    test('a zero-length recording still produces a valid range', () {
      final start = DateTime(2026, 10, 1, 14, 0);
      expect(waktuIndonesia(start, 0), '14.00 – 14.00 WIB');
    });
  });

  group('pesertaFromSegments', () {
    TranscriptSegment segment(String speaker) => TranscriptSegment(
      source: 'mic',
      speaker: speaker,
      text: 'halo',
      timestamp: 0,
      duration: 1,
      language: 'id',
      confidence: 0.9,
      isPartial: false,
    );

    test('drops the engine source labels and deduplicates', () {
      expect(
        pesertaFromSegments([
          segment('MIC'),
          segment('Dr. Siti Aminah'),
          segment('SPK'),
          segment('Budi Santoso'),
          segment('dr. siti aminah'),
          segment('  '),
        ]),
        ['Dr. Siti Aminah', 'Budi Santoso'],
      );
    });

    test('a transcript with only engine labels yields no peserta', () {
      // Better an empty list the notulis fills in than a document claiming
      // "SPK" attended the meeting.
      expect(pesertaFromSegments([segment('MIC'), segment('SPK')]), isEmpty);
    });
  });

  group('buildNotulenPrefill', () {
    final recordedAt = DateTime(2026, 10, 1, 9, 0);
    const defaults = NotulenDefaults(
      unitKerja: 'Direktorat Jenderal Anggaran',
      tempat: 'Ruang Rapat Lt. 5',
      notulis: 'Budi Santoso',
      kopSuratPath: '/tmp/kop.png',
    );

    test('fills the office fields, the dates and the peserta', () {
      final form = buildNotulenPrefill(
        title: 'Rapat Koordinasi RKAKL',
        recordedAt: recordedAt,
        durationSeconds: 5400,
        defaults: defaults,
        segments: const [],
      );
      expect(form.judul, 'Rapat Koordinasi RKAKL');
      expect(form.instansi, 'Direktorat Jenderal Anggaran');
      expect(form.tempat, 'Ruang Rapat Lt. 5');
      expect(form.notulis, 'Budi Santoso');
      expect(form.kopSuratPath, '/tmp/kop.png');
      expect(form.hari, 'Kamis');
      expect(form.tanggal, '1 Oktober 2026');
      expect(form.waktu, '09.00 – 10.30 WIB');
      expect(form.variant, NotulenVariant.dinas);
    });

    test('a saved form wins outright over any prefill', () {
      const saved = NotulenFormData(
        judul: 'Judul yang sudah diedit',
        nomor: 'ND-9/2026',
      );
      final form = buildNotulenPrefill(
        title: 'Judul folder',
        recordedAt: recordedAt,
        durationSeconds: 60,
        defaults: defaults,
        segments: const [],
        saved: saved,
      );
      expect(form.judul, 'Judul yang sudah diedit');
      expect(form.nomor, 'ND-9/2026');
      expect(form.tempat, isEmpty, reason: 'a saved form is used verbatim');
    });

    test('the summary draft supplies the body sections', () {
      final form = buildNotulenPrefill(
        title: 'Rapat',
        recordedAt: recordedAt,
        durationSeconds: 60,
        defaults: defaults,
        segments: const [],
        draft: const NotulenDraft(
          pembahasan: '- Pagu naik 4%',
          keputusan: ['Pagu disetujui'],
          tindakLanjut: [
            TindakLanjut(
              tugas: 'Susun draf',
              penanggungJawab: 'Rina',
              tenggat: '10 Oktober',
            ),
          ],
          peserta: ['Dr. Siti Aminah'],
        ),
      );
      expect(form.pembahasan, '- Pagu naik 4%');
      expect(form.keputusan, ['Pagu disetujui']);
      expect(form.peserta, ['Dr. Siti Aminah'],
          reason: "the summary's participant list beats the speaker labels");
      expect(form.tindakLanjut.single.penanggungJawab, 'Rina');
    });
  });

  group('NotulenFormData persistence', () {
    const form = NotulenFormData(
      variant: NotulenVariant.ringkas,
      instansi: 'KEMENKEU',
      unitKerja: 'DJA',
      nomor: 'ND-12/AG.3/2026',
      judul: 'Rapat Koordinasi',
      hari: 'Senin',
      tanggal: '1 Oktober 2026',
      waktu: '09.00 – 11.30 WIB',
      tempat: 'Zoom',
      pimpinan: 'Dr. Siti Aminah',
      notulis: 'Budi Santoso',
      peserta: ['Dr. Siti Aminah', 'Budi Santoso'],
      agenda: ['Evaluasi pagu'],
      pembahasan: '- Pagu naik 4%',
      keputusan: ['Pagu disetujui'],
      tindakLanjut: [
        NotulenTask(
          tugas: 'Susun draf',
          penanggungJawab: 'Rina',
          tenggat: '10 Oktober 2026',
        ),
      ],
      kopSuratPath: '/tmp/kop.png',
      lampirkanTranskrip: true,
    );

    test('round-trips through JSON without losing a field', () {
      final restored = NotulenFormData.fromJson(form.toJson());
      expect(restored.variant, NotulenVariant.ringkas);
      expect(restored.instansi, 'KEMENKEU');
      expect(restored.nomor, 'ND-12/AG.3/2026');
      expect(restored.peserta, form.peserta);
      expect(restored.agenda, form.agenda);
      expect(restored.keputusan, form.keputusan);
      expect(restored.tindakLanjut.single.tugas, 'Susun draf');
      expect(restored.tindakLanjut.single.tenggat, '10 Oktober 2026');
      expect(restored.kopSuratPath, '/tmp/kop.png');
      expect(restored.lampirkanTranskrip, isTrue);
    });

    test('a hand-edited sidecar with wrong types loads rather than throwing', () {
      final restored = NotulenFormData.fromJson({
        'variant': 'tidak-ada-varian-ini',
        'judul': 42,
        'peserta': 'bukan daftar',
        'tindak_lanjut': 'juga bukan daftar',
        'lampirkan_transkrip': 'ya',
      });
      expect(restored.variant, NotulenVariant.dinas, reason: 'safe default');
      expect(restored.judul, isEmpty);
      expect(restored.peserta, isEmpty);
      expect(restored.tindakLanjut, isEmpty);
      expect(restored.lampirkanTranskrip, isFalse);
    });

    test('toRust carries the bookmark lines through as Poin Penting', () {
      final rust = form.toRust(poinPenting: const ['[05:12] keputusan']);
      expect(rust.poinPenting, ['[05:12] keputusan']);
      expect(rust.tindakLanjut.single.penanggungJawab, 'Rina');
      expect(rust.variant, NotulenVariant.ringkas);
    });

    test('survives a real sidecar write and read', () async {
      final dir = await Directory.systemTemp.createTemp('trareon-notulen-');
      try {
        await writeSessionMeta(
          dir.path,
          const SessionMeta(title: 'Rapat', notulen: form),
        );
        final meta = await readSessionMeta(dir.path);
        expect(meta.notulen, isNotNull);
        expect(meta.notulen!.nomor, 'ND-12/AG.3/2026');
        expect(meta.notulen!.tindakLanjut.single.tugas, 'Susun draf');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
