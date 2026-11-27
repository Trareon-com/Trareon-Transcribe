// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Trareon Transcribe';

  @override
  String get languageSectionTitle => 'Bahasa';

  @override
  String get languageLabel => 'Bahasa antarmuka';

  @override
  String get languageSubtitle =>
      'Bahasa tombol dan menu. Tidak mengubah bahasa transkripsi.';

  @override
  String get languageSystem => 'Ikuti sistem';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get alreadyRunningTitle => 'Trareon Transcribe sudah berjalan';

  @override
  String get alreadyRunningBody =>
      'Hanya satu instance Trareon Transcribe yang bisa berjalan pada saat yang sama. Tutup jendela ini dan gunakan instance yang sudah terbuka.';

  @override
  String get actionSave => 'Simpan';

  @override
  String get actionCancel => 'Batal';

  @override
  String get actionSkip => 'Lewati';

  @override
  String get actionHide => 'Sembunyikan';

  @override
  String get actionCancelThis => 'Batalkan';

  @override
  String get actionCancelAll => 'Batalkan semua';

  @override
  String get enhanceQueueTitle => 'Memperhalus transkrip';

  @override
  String get enhanceQueuePaused => 'Ditunda selama ada rekaman berjalan.';

  @override
  String get enhanceJobRunning =>
      'Memakai model akurat… transkrip lama tetap aman sampai selesai.';

  @override
  String get enhanceJobFailed => 'Gagal. Transkrip lama dipakai.';

  @override
  String get enhanceJobQueued => 'Menunggu antrean.';

  @override
  String storageSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesi',
      zero: 'Belum ada sesi',
    );
    return '$_temp0';
  }

  @override
  String storageTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Penyimpanan: $count sesi tersimpan',
      zero: 'Penyimpanan: belum ada sesi tersimpan',
    );
    return '$_temp0';
  }

  @override
  String get storageEmptyCompact => '📂 Kosong';

  @override
  String storageCountCompact(int count) {
    return '📁 $count';
  }

  @override
  String storageSummary(String sessions, String size) {
    return '$sessions · $size';
  }

  @override
  String bytesKb(String value) {
    return '$value KB';
  }

  @override
  String bytesMb(String value) {
    return '$value MB';
  }

  @override
  String bytesGb(String value) {
    return '$value GB';
  }

  @override
  String get bookmarkAdd => 'Tandai';

  @override
  String get bookmarkAddTooltip =>
      'Tandai poin penting di posisi sekarang (Ctrl+B)';

  @override
  String get bookmarkAddWithNoteTooltip => 'Tandai dan tulis catatan';

  @override
  String bookmarkNoteDialogTitle(String time) {
    return 'Catatan untuk $time';
  }

  @override
  String get bookmarkNoteLabel => 'Catatan (opsional)';

  @override
  String get bookmarkNoteHint => 'mis. keputusan penting, tindak lanjut';

  @override
  String bookmarkMarkedAt(String time) {
    return 'Poin ditandai pada $time';
  }

  @override
  String get bookmarkNone => 'Belum ada poin yang ditandai.';

  @override
  String bookmarkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poin ditandai.',
    );
    return '$_temp0';
  }

  @override
  String bookmarkRemoveTooltip(String time) {
    return 'Hapus tanda $time';
  }

  @override
  String bookmarkJumpTooltip(String time) {
    return 'Klik: lompat ke $time · Tahan: ubah catatan';
  }

  @override
  String get bookmarkEditNoteTooltip => 'Klik untuk ubah catatan';

  @override
  String bookmarkRowLabel(String time, String note) {
    return '$time · $note';
  }

  @override
  String get notulenDialogSummaryNotConfigured =>
      'Endpoint atau model ringkasan belum diisi. Lengkapi di Pengaturan → Ringkasan AI.';

  @override
  String get notulenDialogPickReferenceDocTitle => 'Pilih dokumen rujukan';

  @override
  String notulenDialogReadDocFailed(String error) {
    return 'Gagal membaca dokumen: $error';
  }

  @override
  String get notulenDialogPickFolderTitle => 'Pilih folder untuk notulen';

  @override
  String notulenDialogSaved(String path) {
    return 'Notulen tersimpan: $path';
  }

  @override
  String notulenDialogExportFailed(String error) {
    return 'Gagal membuat notulen: $error';
  }

  @override
  String get notulenDialogTitle => 'Notulen Rapat';

  @override
  String get notulenDialogComposing => 'Menyusun…';

  @override
  String get notulenDialogCreateDocx => 'Buat Notulen (DOCX)';

  @override
  String get notulenDialogMeetingIdentity => 'Identitas rapat';

  @override
  String get notulenDialogFieldTitle => 'Judul Rapat';

  @override
  String get notulenDialogFieldNumber => 'Nomor Notulen';

  @override
  String get notulenDialogFieldNumberHint => 'mis. ND-12/AG.3/2026';

  @override
  String get notulenDialogFieldAgency => 'Instansi (kop surat)';

  @override
  String get notulenDialogFieldUnit => 'Unit kerja (baris kedua kop)';

  @override
  String get notulenDialogFieldDay => 'Hari';

  @override
  String get notulenDialogFieldDate => 'Tanggal';

  @override
  String get notulenDialogFieldTime => 'Waktu';

  @override
  String get notulenDialogFieldPlace => 'Tempat/Media';

  @override
  String get notulenDialogFieldChair => 'Pimpinan Rapat';

  @override
  String get notulenDialogFieldMinuteTaker => 'Notulis';

  @override
  String get notulenDialogParties => 'Para Pihak';

  @override
  String get notulenDialogPartiesHelp =>
      'Urutan menentukan kolom tanda tangan: pihak pertama di kanan, pihak kedua di kiri. Sebutkan nama beserta jabatannya.';

  @override
  String get notulenDialogPartyHint => 'Nama, jabatan';

  @override
  String get notulenDialogAddParty => 'Tambah pihak';

  @override
  String get notulenDialogAttendees => 'Peserta';

  @override
  String get notulenDialogAttendeeHint => 'Nama peserta';

  @override
  String get notulenDialogAddAttendee => 'Tambah peserta';

  @override
  String get notulenDialogAgenda => 'Agenda';

  @override
  String get notulenDialogAgendaHint => 'Butir agenda';

  @override
  String get notulenDialogAddAgenda => 'Tambah agenda';

  @override
  String get notulenDialogDiscussion => 'Pembahasan';

  @override
  String get notulenDialogDiscussionHint =>
      'Isi pembahasan. Terisi otomatis dari ringkasan AI kalau ada.';

  @override
  String get notulenDialogDecisions => 'Keputusan';

  @override
  String get notulenDialogDecisionHint => 'Keputusan rapat';

  @override
  String get notulenDialogAddDecision => 'Tambah keputusan';

  @override
  String get notulenDialogFollowUp => 'Tindak Lanjut';

  @override
  String get notulenDialogArchivalExport => 'Ekspor kearsipan';

  @override
  String get notulenDialogExportSrikandi => 'Ekspor siap-SRIKANDI…';

  @override
  String notulenDialogBookmarksIncluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poin penting yang Anda tandai saat rapat akan disertakan.',
    );
    return '$_temp0';
  }

  @override
  String get notulenDialogAttachTranscript => 'Lampirkan transkrip lengkap';

  @override
  String notulenDialogTranscriptLines(int count) {
    return '$count baris transkrip ditambahkan di halaman terpisah.';
  }

  @override
  String get notulenDialogFormType => 'Bentuk naskah';

  @override
  String get notulenDialogAutoFill => 'Isi otomatis dengan AI';

  @override
  String get notulenDialogSourceTranscript => 'Transkrip sesi';

  @override
  String get notulenDialogSourceNotes => 'Poin catatan';

  @override
  String get notulenDialogNotesHint =>
      'Tempel atau ketik butir-butir catatan rapat, satu poin per baris.';

  @override
  String get notulenDialogLength => 'Panjang notulen';

  @override
  String get notulenDialogAddReferenceDoc =>
      'Tambahkan dokumen rujukan (opsional)';

  @override
  String get notulenDialogRemoveReferenceDoc => 'Hapus dokumen rujukan';

  @override
  String get notulenDialogGenerate => 'Buat Otomatis';

  @override
  String get notulenDialogRetry => 'Coba lagi';

  @override
  String notulenDialogGenerateFailed(String error) {
    return 'Gagal membuat notulen otomatis: $error';
  }

  @override
  String get notulenDialogFactCheckSection => 'Periksa Fakta & Ragam';

  @override
  String get notulenDialogRecheck => 'Periksa Ulang';

  @override
  String get notulenDialogFactCheck => 'Periksa Fakta';

  @override
  String get notulenDialogTidyRegister => 'Rapikan Ragam';

  @override
  String notulenDialogCheckFailed(String error) {
    return 'Gagal memeriksa: $error';
  }

  @override
  String notulenDialogFactSummary(int checked, int clean, int flagged) {
    return '$checked pernyataan diperiksa, $clean bersih, $flagged butir perlu ditinjau.';
  }

  @override
  String get notulenDialogTidyPreview => 'Pratinjau Rapikan Ragam';

  @override
  String get notulenDialogApply => 'Terapkan';

  @override
  String notulenDialogRemoveItem(String item) {
    return 'Hapus $item';
  }

  @override
  String get notulenDialogTaskField => 'Tugas';

  @override
  String get notulenDialogOwnerField => 'Penanggung Jawab';

  @override
  String get notulenDialogDueField => 'Tenggat';

  @override
  String get notulenDialogRemoveTaskRow => 'Hapus baris tindak lanjut';

  @override
  String get notulenDialogAddTask => 'Tambah tindak lanjut';

  @override
  String get notulenDialogIssueNoCitation => 'Tanpa rujukan segmen';

  @override
  String get notulenDialogIssueInvalidCitation => 'Rujukan segmen tidak sah';

  @override
  String get notulenDialogIssueWeakSupport => 'Dukungan dari transkrip lemah';

  @override
  String get notulenDialogIssueCitationOff => 'Rujukan segmen meleset';

  @override
  String get notulenDialogIssueNumberMissing =>
      'Angka tidak ditemukan di transkrip';

  @override
  String get notulenDialogIssueNameMissing =>
      'Nama tidak ditemukan di transkrip';

  @override
  String notulenDialogRegisterLine(int line, String found) {
    return 'Baris $line: \"$found\"';
  }

  @override
  String notulenDialogRegisterSuggestion(String suggestion) {
    return 'Saran: \"$suggestion\" (diterapkan oleh Rapikan Ragam)';
  }

  @override
  String get actionItemsPanelStatusNotStarted => 'Belum mulai';

  @override
  String get actionItemsPanelStatusInProgress => 'Sedang berjalan';

  @override
  String get actionItemsPanelStatusDone => 'Selesai';

  @override
  String get actionItemsPanelStatusCancelled => 'Dibatalkan';

  @override
  String actionItemsPanelSaved(String what, String filename) {
    return '$what disimpan: $filename';
  }

  @override
  String actionItemsPanelSaveFailed(String what, String error) {
    return 'Gagal menyimpan $what: $error';
  }

  @override
  String get actionItemsPanelIcsWhat => 'Kalender tindak lanjut';

  @override
  String get actionItemsPanelCsvWhat => 'Tabel tindak lanjut';

  @override
  String actionItemsPanelIcsFailed(String error) {
    return 'Gagal membuat .ics: $error';
  }

  @override
  String actionItemsPanelCsvFailed(String error) {
    return 'Gagal membuat .csv: $error';
  }

  @override
  String get actionItemsPanelCopied => 'Tindak lanjut disalin.';

  @override
  String get actionItemsPanelTitle => 'Tindak Lanjut';

  @override
  String actionItemsPanelProgress(int done, int total) {
    return '$done/$total selesai';
  }

  @override
  String get actionItemsPanelEmpty =>
      'Belum ada tindak lanjut. Nyalakan \"Tindak lanjut terstruktur\" di Pengaturan → Ringkasan AI agar ringkasan berikutnya mengisinya sendiri, atau tambahkan sendiri di bawah.';

  @override
  String get actionItemsPanelAddTask => 'Tambah tugas';

  @override
  String get actionItemsPanelCopy => 'Salin';

  @override
  String get actionItemsPanelExportCsv => 'Ekspor CSV';

  @override
  String get actionItemsPanelShareCsv => 'Bagikan CSV';

  @override
  String get actionItemsPanelExportIcs => 'Ekspor .ics';

  @override
  String get actionItemsPanelShareIcs => 'Bagikan .ics';

  @override
  String actionItemsPanelMarkDone(String task) {
    return 'Tandai \"$task\" selesai';
  }

  @override
  String get actionItemsPanelTaskLabel => 'Tugas';

  @override
  String get actionItemsPanelRemoveTask => 'Hapus tugas';

  @override
  String get actionItemsPanelOwnerLabel => 'Penanggung jawab';

  @override
  String get actionItemsPanelDueLabel => 'Tenggat';

  @override
  String get actionItemsPanelStatusLabel => 'Status';

  @override
  String get diagnosticsScreenSaveDialogTitle => 'Simpan log diagnostik';

  @override
  String diagnosticsScreenSaved(String path) {
    return 'Log diagnostik tersimpan: $path';
  }

  @override
  String diagnosticsScreenSaveFailed(String error) {
    return 'Gagal menyimpan log diagnostik: $error';
  }

  @override
  String get diagnosticsScreenTitle => 'Diagnostik';

  @override
  String get diagnosticsScreenRecheck => 'Periksa ulang';

  @override
  String get diagnosticsScreenIntro =>
      'Pemeriksaan ini berjalan sepenuhnya di komputer Anda dan tidak mengirim apa pun ke internet.';

  @override
  String get diagnosticsScreenRunFailedTitle => 'Pemeriksaan gagal dijalankan';

  @override
  String get diagnosticsScreenRunFailedRemediation =>
      'Mesin transkripsi mungkin tidak termuat. Tutup dan buka ulang aplikasi; jika tetap gagal, pasang ulang Trareon.';

  @override
  String get diagnosticsScreenNoChecksTitle =>
      'Tidak ada pemeriksaan yang berjalan';

  @override
  String get diagnosticsScreenNoChecksMessage =>
      'Mesin tidak mengembalikan hasil apa pun.';

  @override
  String get diagnosticsScreenHasFailures =>
      'Ada masalah yang perlu diperbaiki sebelum merekam.';

  @override
  String get diagnosticsScreenHasWarnings =>
      'Aplikasi bisa dipakai, tapi ada hal yang sebaiknya diperiksa.';

  @override
  String get diagnosticsScreenAllGood => 'Semua siap. Aplikasi bisa merekam.';

  @override
  String get diagnosticsScreenSeverityOk => 'Baik';

  @override
  String get diagnosticsScreenSeverityWarn => 'Perlu diperiksa';

  @override
  String get diagnosticsScreenSeverityFail => 'Gagal';

  @override
  String get diagnosticsScreenExportTitle => 'Log Diagnostik';

  @override
  String get diagnosticsScreenExportBody =>
      'Satu berkas .zip berisi berkas log dan hasil pemeriksaan di atas. Tidak berisi transkrip, audio, atau nama berkas rapat Anda.';

  @override
  String diagnosticsScreenExportBodyCount(int count) {
    return 'Satu berkas .zip berisi $count berkas log dan hasil pemeriksaan di atas. Tidak berisi transkrip, audio, atau nama berkas rapat Anda.';
  }

  @override
  String get diagnosticsScreenExport => 'Ekspor';

  @override
  String get llmSetupWizardScreenTitle => 'Siapkan Model AI';

  @override
  String get llmSetupWizardScreenNotDetected =>
      'Ollama tidak terdeteksi di perangkat ini.';

  @override
  String llmSetupWizardScreenInstallOn(String system) {
    return 'Pasang Ollama di $system';
  }

  @override
  String llmSetupWizardScreenOpenLink(String url) {
    return 'Buka $url';
  }

  @override
  String get llmSetupWizardScreenInstalledRecheck =>
      'Sudah dipasang, periksa ulang';

  @override
  String llmSetupWizardScreenHardware(String ram, int threads) {
    return 'Perangkat ini: $ram GB RAM, $threads thread CPU.';
  }

  @override
  String llmSetupWizardScreenHardwareWithVram(
    String ram,
    int threads,
    String vram,
  ) {
    return 'Perangkat ini: $ram GB RAM, $threads thread CPU, $vram GB VRAM.';
  }

  @override
  String get llmSetupWizardScreenBelowMinimum =>
      'Perangkat ini di bawah rekomendasi minimum; model teringan tetap ditawarkan sebagai usaha terbaik.';

  @override
  String get llmSetupWizardScreenChooseModel => 'Pilih model';

  @override
  String llmSetupWizardScreenDownload(String model) {
    return 'Unduh $model';
  }

  @override
  String llmSetupWizardScreenDownloading(String model) {
    return 'Mengunduh $model…';
  }

  @override
  String get llmSetupWizardScreenDownloadingShort => 'Mengunduh';

  @override
  String get llmSetupWizardScreenPreparing => 'Menyiapkan unduhan…';

  @override
  String get llmSetupWizardScreenReady => 'Model siap dipakai';

  @override
  String llmSetupWizardScreenReadyBody(String model) {
    return '$model sudah terunduh dan disetel sebagai model Ringkasan AI.';
  }

  @override
  String get llmSetupWizardScreenDone => 'Selesai';

  @override
  String llmSetupWizardScreenReadyToast(String model) {
    return 'Model AI siap: $model';
  }

  @override
  String llmSetupWizardScreenModelMeta(String tag, String size, int context) {
    return '$tag · unduh $size GB · konteks $context';
  }

  @override
  String llmSetupWizardScreenError(String error) {
    return 'Terjadi kesalahan: $error';
  }

  @override
  String get llmSetupWizardScreenRetry => 'Coba lagi';

  @override
  String get capabilitiesScreenTitle => 'Apa Jalan di Mana';

  @override
  String capabilitiesScreenLoadFailed(String error) {
    return 'Daftar kemampuan tidak bisa dibaca: $error';
  }

  @override
  String get capabilitiesScreenRunsLocal => 'Lokal';

  @override
  String get capabilitiesScreenRunsEndpoint => 'Endpoint Anda';

  @override
  String get capabilitiesScreenRunsInternet => 'Internet';

  @override
  String capabilitiesScreenLocalCount(int local, int total) {
    return '$local dari $total kemampuan berjalan sepenuhnya di komputer ini.';
  }

  @override
  String capabilitiesScreenNetworked(int count, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count kemampuan bisa memakai jaringan; $active di antaranya aktif sekarang. Perekaman, transkripsi, dan ekspor tidak termasuk, itu tidak pernah memakai jaringan.',
      zero: 'Tidak ada kemampuan yang memakai jaringan.',
    );
    return '$_temp0';
  }

  @override
  String get capabilitiesScreenSourceNote =>
      'Daftar ini dibuat dari sumber yang sama dengan uji privasi di rust_core/src/privacy.rs: baris yang mengaku \"Lokal\" tetapi modulnya menyentuh jaringan akan menggagalkan build.';

  @override
  String capabilitiesScreenRowSemantics(
    String name,
    String runsAt,
    String status,
  ) {
    return '$name. $runsAt. $status.';
  }

  @override
  String get capabilitiesScreenActive => 'Aktif';

  @override
  String get capabilitiesScreenInactive => 'Tidak aktif';

  @override
  String get capabilitiesScreenRunsAt => 'Berjalan di: ';

  @override
  String capabilitiesScreenCode(String module) {
    return 'Kode: rust_core/src/$module';
  }

  @override
  String get archiveChatScreenTitle => 'Tanya Arsip Rapat';

  @override
  String get archiveChatScreenClear => 'Bersihkan';

  @override
  String archiveChatScreenEmpty(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tanyakan apa saja tentang $count rapat yang tersimpan.',
      zero: 'Belum ada rapat di perpustakaan.',
    );
    return '$_temp0';
  }

  @override
  String get archiveChatScreenExplain =>
      '\"Cari\" bekerja sepenuhnya di komputer ini. \"Jawab\" juga mengirim kutipan yang ditemukan ke endpoint ringkasan yang Anda atur, dan dicatat di Laporan Privasi.';

  @override
  String get archiveChatScreenExample1 => 'Apa keputusan soal anggaran?';

  @override
  String get archiveChatScreenExample2 =>
      'Siapa penanggung jawab laporan keuangan?';

  @override
  String get archiveChatScreenExample3 => 'Kapan tenggat peluncuran?';

  @override
  String get archiveChatScreenSources => 'Kutipan';

  @override
  String archiveChatScreenSourceSummary(String title, String date) {
    return '$title ($date) · ringkasan';
  }

  @override
  String get archiveChatScreenHint =>
      'Tanyakan sesuatu tentang rapat-rapat Anda…';

  @override
  String get archiveChatScreenSearch => 'Cari';

  @override
  String get archiveChatScreenAnswer => 'Jawab';

  @override
  String get redactionPreviewTitle => 'Pratinjau penyamaran';

  @override
  String get redactionPreviewClose => 'Tutup';

  @override
  String redactionPreviewFailed(String error) {
    return 'Pratinjau gagal: $error';
  }

  @override
  String get redactionPreviewNoneFound =>
      'Tidak ada data pribadi yang terdeteksi. File hasil ekspor akan sama persis dengan transkrip.';

  @override
  String get redactionPreviewNothing => 'Tidak ada yang akan disamarkan.';

  @override
  String redactionPreviewSummaryPart(int count, String kind) {
    return '$count $kind';
  }

  @override
  String redactionPreviewSummary(String parts) {
    return '$parts akan disamarkan.';
  }

  @override
  String get redactionPreviewKindPhone => 'Nomor telepon';

  @override
  String get redactionPreviewKindEmail => 'Alamat email';

  @override
  String get redactionPreviewKindBankAccount => 'Nomor rekening';

  @override
  String get redactionPreviewKindName => 'Nama';

  @override
  String get liveQaPanelTitle => 'Tanya Langsung';

  @override
  String get liveQaPanelHint => 'Tanyakan sesuatu tentang rapat ini…';

  @override
  String get liveQaPanelAsk => 'Tanya';

  @override
  String get liveQaPanelEmpty =>
      'Tanyakan apa saja yang sudah dibahas di rapat ini sejauh ini.';

  @override
  String get liveQaPanelPrivacy =>
      'Jawaban dikirim ke endpoint ringkasan yang Anda atur di Pengaturan → Ringkasan AI, dan dicatat di Laporan Privasi.';

  @override
  String get liveQaPanelSources => 'Kutipan transkrip';

  @override
  String get recordButtonSaving => 'Menyimpan…';

  @override
  String get recordButtonResume => 'Lanjutkan';

  @override
  String get recordButtonStop => 'Berhenti';

  @override
  String get recordButtonStart => 'Mulai Rekam';

  @override
  String get recordButtonResumeSemantics => 'Lanjutkan rekaman';

  @override
  String get recordButtonStopSemantics => 'Berhenti merekam';

  @override
  String get recordButtonStartSemantics => 'Mulai merekam';

  @override
  String get appDialogClose => 'Tutup';

  @override
  String get appDialogBarrierLabel => 'Tutup dialog';

  @override
  String get appDialogContinue => 'Lanjutkan';

  @override
  String get trayServiceOpen => 'Buka Trareon Transcribe';

  @override
  String get trayServiceQuit => 'Keluar';

  @override
  String get personalNotesPanelTitle => 'Catatan Pribadi';

  @override
  String get personalNotesPanelSubtitle =>
      'Tersimpan otomatis. Enhance nanti menggabungkannya dengan transkrip.';

  @override
  String get personalNotesPanelHint => 'mis. PENTING: deadline Jumat…';
}
