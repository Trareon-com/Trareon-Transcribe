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
  String get appToastDismissTooltip => 'Tutup pemberitahuan';

  @override
  String get settingsControlsInfoBadge => 'Penjelasan';

  @override
  String get settingsControlsInfoDialogTitle => 'Informasi';

  @override
  String get settingsControlsClose => 'Tutup';

  @override
  String get taskProgressTileFailed => 'Gagal.';

  @override
  String get taskProgressTileCancelled => 'Dibatalkan.';

  @override
  String get taskProgressTileDone => 'Selesai.';

  @override
  String get taskProgressTileQueued => 'Menunggu antrean.';

  @override
  String get taskProgressTileProcessing => 'Memproses';

  @override
  String get enhanceQueueViewCompletingTitle => 'Menyelesaikan transkrip';

  @override
  String enhanceQueueViewCompletingSource(String source) {
    return 'Menyelesaikan $source';
  }

  @override
  String enhanceQueueViewEtaRemaining(String eta) {
    return 'sisa $eta';
  }

  @override
  String get enhanceQueueViewQueuedCompletion =>
      'Menunggu antrean, ada audio yang belum ditranskripsi.';

  @override
  String get enhanceQueueModelSourceMic => 'mikrofon';

  @override
  String get enhanceQueueModelSourceSystem => 'audio sistem';

  @override
  String get enhanceQueueModelSourceRecording => 'rekaman';

  @override
  String enhanceQueueModelQueuedForCompletion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Menunggu antrean untuk menyelesaikan $count rekaman.',
      one: 'Menunggu antrean untuk menyelesaikan transkrip.',
    );
    return '$_temp0';
  }

  @override
  String enhanceQueueModelCompletingLine(
    String source,
    int percent,
    String eta,
  ) {
    return 'Menyelesaikan transkrip…$source $percent%$eta';
  }

  @override
  String enhanceQueueModelEtaSuffix(String eta) {
    return ', sisa $eta';
  }

  @override
  String enhanceQueueModelEtaSeconds(int seconds) {
    return '$seconds detik';
  }

  @override
  String enhanceQueueModelEtaMinutes(int minutes) {
    return '$minutes menit';
  }

  @override
  String enhanceQueueModelEtaHours(int hours) {
    return '$hours jam';
  }

  @override
  String enhanceQueueModelEtaHoursMinutes(int hours, int minutes) {
    return '$hours jam $minutes menit';
  }

  @override
  String get enhanceQueueModelStagePreparing => 'Menyiapkan model';

  @override
  String get enhanceQueueModelStageTranscribing => 'Mentranskripsi';

  @override
  String get enhanceQueueModelStageMerging => 'Menggabungkan';

  @override
  String get enhanceQueueModelNoSpeech => 'Tidak ada ucapan terdeteksi.';

  @override
  String get batchUploadModelUnsupportedFormat => 'format tidak didukung';

  @override
  String get batchUploadModelTooLarge => 'lebih besar dari batas 2 GB';

  @override
  String get batchUploadModelNoSpeech => 'Tidak ada ucapan terdeteksi';

  @override
  String get batchUploadModelStoppedEarly =>
      'Proses berhenti sebelum file ini selesai';

  @override
  String get modelsSummaryTemplateNotulenRapat => 'Notulen Rapat';

  @override
  String get modelsSummaryTemplateRingkasanEksekutif => 'Ringkasan Eksekutif';

  @override
  String get modelsSummaryTemplateActionItems => 'Keputusan & Tindak Lanjut';

  @override
  String get modelsSummaryTemplateStandup => 'Laporan Harian';

  @override
  String get modelsSummaryTemplateKustom => 'Kustom';

  @override
  String get modelsSummaryTemplateHintNotulenRapat =>
      'Ringkasan, peserta, pembahasan, keputusan, tindak lanjut';

  @override
  String get modelsSummaryTemplateHintRingkasanEksekutif =>
      'Paragraf singkat untuk yang tidak hadir';

  @override
  String get modelsSummaryTemplateHintActionItems =>
      'Hanya keputusan dan tugas beserta penanggung jawabnya';

  @override
  String get modelsSummaryTemplateHintStandup =>
      'Per orang: selesai, berikutnya, hambatan';

  @override
  String get modelsSummaryTemplateHintKustom => 'Instruksi sendiri';

  @override
  String get modelsSummaryProviderOllama => 'Ollama (lokal)';

  @override
  String get modelsSummaryProviderOpenAiCompatible => 'Layanan serupa OpenAI';

  @override
  String get modelsSessionModeWebinar => 'Webinar';

  @override
  String get modelsSessionModeOnline => 'Rapat Online';

  @override
  String get modelsSessionModeOffline => 'Rapat Offline';

  @override
  String get usageDashboardScreenTitle => 'Dasbor Penggunaan';

  @override
  String get usageDashboardScreenTotalSessions => 'Total Sesi';

  @override
  String get usageDashboardScreenHoursTranscribed => 'Jam Ditranskrip';

  @override
  String get usageDashboardScreenTotalSegments => 'Total Segmen Transkrip';

  @override
  String get usageDashboardScreenEmpty => 'Belum ada data sesi tersimpan.';

  @override
  String get usageDashboardScreenSessionsByMode => 'Sesi per Mode';

  @override
  String usageDashboardScreenSessionCount(int count) {
    return '$count sesi';
  }

  @override
  String get meetingTemplatePickerModeWebinar => 'Webinar';

  @override
  String get meetingTemplatePickerModeOnline => 'Rapat online';

  @override
  String get meetingTemplatePickerModeOffline => 'Rapat tatap muka';

  @override
  String get meetingTemplatePickerLanguageAuto => 'Otomatis';

  @override
  String get meetingTemplatePickerLanguageIndonesian => 'Indonesia';

  @override
  String get meetingTemplatePickerLanguageEnglish => 'Inggris';

  @override
  String get meetingTemplatePickerTitle => 'Mulai dari template';

  @override
  String get meetingTemplatePickerEmptyDescription =>
      'Belum ada template tersimpan. Buat satu agar judul, peserta, agenda, bahasa, dan mode rapat yang sering dipakai tidak perlu diisi ulang setiap kali.';

  @override
  String get meetingTemplatePickerDescription =>
      'Pilih template untuk mengisi judul, mode, dan bahasa sesi secara otomatis.';

  @override
  String get meetingTemplatePickerCreate => 'Buat template baru';

  @override
  String get meetingTemplatePickerOptionalNote =>
      'Template tidak wajib. \"Rapat baru\" tetap memulai sesi kosong seperti biasa.';

  @override
  String meetingTemplatePickerParticipantCount(int count) {
    return '$count peserta';
  }

  @override
  String meetingTemplatePickerAgendaCount(int count) {
    return '$count agenda';
  }

  @override
  String get meetingTemplatePickerDelete => 'Hapus template';

  @override
  String get meetingTemplatePickerUse => 'Pakai';

  @override
  String get meetingTemplatePickerNewTitle => 'Template baru';

  @override
  String get meetingTemplatePickerNamePlaceholder =>
      'Nama template, mis. \"Rapat Mingguan Tim\"';

  @override
  String get meetingTemplatePickerParticipantsPlaceholder =>
      'Peserta default (satu nama per baris)';

  @override
  String get meetingTemplatePickerAgendaPlaceholder =>
      'Agenda default (satu poin per baris)';

  @override
  String get meetingTemplatePickerModeLabel => 'Mode';

  @override
  String get meetingTemplatePickerLanguageLabel => 'Bahasa';

  @override
  String get glossarySettingsSectionImportDialogTitle => 'Impor kamus istilah';

  @override
  String get glossarySettingsSectionImportEmpty =>
      'Tidak ada istilah di berkas itu.';

  @override
  String glossarySettingsSectionImported(int added, int lines) {
    return '$added istilah baru ditambahkan dari $lines baris.';
  }

  @override
  String glossarySettingsSectionImportFailed(String error) {
    return 'Gagal mengimpor: $error';
  }

  @override
  String get glossarySettingsSectionExportDialogTitle => 'Simpan kamus istilah';

  @override
  String glossarySettingsSectionExported(int count, String path) {
    return '$count istilah diekspor ke $path';
  }

  @override
  String glossarySettingsSectionExportFailed(String error) {
    return 'Gagal mengekspor: $error';
  }

  @override
  String get glossarySettingsSectionTitle => 'Kamus Istilah';

  @override
  String get glossarySettingsSectionEnable => 'Pakai kamus istilah';

  @override
  String get glossarySettingsSectionEnabledSubtitle =>
      'Istilah di bawah dibisikkan ke mesin transkripsi supaya singkatan dan nama lembaga tidak salah tulis.';

  @override
  String get glossarySettingsSectionDisabledSubtitle =>
      'Mesin transkripsi menebak sendiri semua istilah.';

  @override
  String get glossarySettingsSectionPostCorrection =>
      'Perbaiki ejaan yang mirip';

  @override
  String get glossarySettingsSectionPostCorrectionOnSubtitle =>
      'Kata yang hampir sama dengan istilah di kamus diperbaiki setelah transkripsi. Kata lain tidak disentuh.';

  @override
  String get glossarySettingsSectionPostCorrectionOffSubtitle =>
      'Hasil transkripsi dibiarkan apa adanya.';

  @override
  String glossarySettingsSectionListTitle(int count) {
    return 'Daftar Istilah ($count)';
  }

  @override
  String get glossarySettingsSectionAddLabel => 'Tambah istilah';

  @override
  String get glossarySettingsSectionAddHint =>
      'mis. PPBJ, Kemenkeu, Pak Budi Santoso';

  @override
  String get glossarySettingsSectionAdd => 'Tambah';

  @override
  String glossarySettingsSectionTermSemantics(String term) {
    return 'Istilah $term';
  }

  @override
  String glossarySettingsSectionRemoveTerm(String term) {
    return 'Hapus $term';
  }

  @override
  String get glossarySettingsSectionSuggestions => 'Saran istilah umum';

  @override
  String glossarySettingsSectionAddSuggestion(String term) {
    return 'Tambahkan $term ke kamus';
  }

  @override
  String get glossarySettingsSectionImportButton => 'Impor .txt / .csv';

  @override
  String get glossarySettingsSectionExportTxt => 'Ekspor .txt';

  @override
  String get glossarySettingsSectionExportCsv => 'Ekspor .csv';

  @override
  String get glossarySettingsSectionNoTerms =>
      'Belum ada istilah. Tanpa kamus, mesin transkripsi menebak sendiri.';

  @override
  String glossarySettingsSectionBudgetOverflow(int used, int total) {
    return '$used dari $total istilah dipakai, daftar terlalu panjang untuk dibisikkan sekaligus. Istilah paling atas yang dibuang; pindahkan yang penting ke atas atau kurangi daftarnya.';
  }

  @override
  String glossarySettingsSectionBudgetAll(int total) {
    return 'Semua $total istilah dipakai.';
  }

  @override
  String get summarySettingsSectionOllamaModelHint => 'nama model Ollama';

  @override
  String get summarySettingsSectionNoModels =>
      'Endpoint terhubung, tapi tidak ada model terpasang.';

  @override
  String get summarySettingsSectionEnable => 'Aktifkan Ringkasan AI';

  @override
  String get summarySettingsSectionEnabledSubtitle =>
      'Transkrip dikirim ke endpoint di bawah hanya saat Anda menekan \"Buat Ringkasan\". Tidak ada audio yang dikirim.';

  @override
  String get summarySettingsSectionDisabledSubtitle =>
      'Mati. Aplikasi tetap 100% offline.';

  @override
  String get summarySettingsSectionProvider => 'Penyedia';

  @override
  String get summarySettingsSectionEndpointUrl => 'URL endpoint';

  @override
  String get summarySettingsSectionApiKey => 'Kunci API';

  @override
  String get summarySettingsSectionApiKeyHelper =>
      'Disimpan apa adanya di file pengaturan aplikasi (tanpa keychain).';

  @override
  String get summarySettingsSectionApiKeyHint => 'Tempel kunci di sini';

  @override
  String get summarySettingsSectionModel => 'Model';

  @override
  String get summarySettingsSectionLoadModels =>
      'Muat daftar model dari endpoint';

  @override
  String get summarySettingsSectionSetupWizard =>
      'Siapkan Model AI (deteksi, pasang, unduh)…';

  @override
  String get summarySettingsSectionDefaultTemplate => 'Template default';

  @override
  String get summarySettingsSectionCitations => 'Rujukan ke transkrip';

  @override
  String get summarySettingsSectionCitationsSubtitle =>
      'Minta model menyebut nomor segmen untuk setiap poin, sehingga tiap baris ringkasan bisa diklik ke menit asalnya. Rujukan yang tidak cocok dibuang.';

  @override
  String get summarySettingsSectionActionItems => 'Tindak lanjut terstruktur';

  @override
  String get summarySettingsSectionActionItemsSubtitle =>
      'Minta daftar tugas, penanggung jawab, dan tenggat dalam format yang bisa disunting dan diekspor ke kalender (.ics) atau tabel (.csv).';

  @override
  String get summarySettingsSectionCustomInstructions => 'Instruksi kustom';

  @override
  String get summarySettingsSectionCustomInstructionsHint =>
      'Contoh: Buat daftar risiko dan mitigasinya.';

  @override
  String get pdpSettingsSectionRetentionForever => 'Simpan selamanya';

  @override
  String pdpSettingsSectionRetentionDays(int days) {
    return '$days hari';
  }

  @override
  String pdpSettingsSectionRetentionDaysMonths(int days, int months) {
    return '$days hari ($months bulan)';
  }

  @override
  String pdpSettingsSectionRetentionYears(int years) {
    return '$years tahun';
  }

  @override
  String get pdpSettingsSectionTitle => 'Kepatuhan UU PDP';

  @override
  String get pdpSettingsSectionEnable => 'Aktifkan Mode Kepatuhan PDP';

  @override
  String get pdpSettingsSectionEnableSubtitle =>
      'Penyamaran data pribadi saat ekspor, batas retensi, log audit, dan pemberitahuan perekaman. Mati secara bawaan.';

  @override
  String get pdpSettingsSectionRedactionTitle => 'Penyamaran saat ekspor';

  @override
  String get pdpSettingsSectionRedactionIntro =>
      'Transkrip tersimpan tidak diubah. Penyamaran hanya berlaku pada salinan yang diekspor, dan selalu bisa dilihat dulu sebelum file ditulis.';

  @override
  String get pdpSettingsSectionNik => 'NIK';

  @override
  String get pdpSettingsSectionNikHint =>
      '16 digit dengan kode provinsi yang sah';

  @override
  String get pdpSettingsSectionNpwp => 'NPWP';

  @override
  String get pdpSettingsSectionNpwpHint => '15 digit, dengan atau tanpa titik';

  @override
  String get pdpSettingsSectionPhone => 'Nomor telepon';

  @override
  String get pdpSettingsSectionPhoneHint =>
      '08…, +62…, dan nomor kantor dengan kode area';

  @override
  String get pdpSettingsSectionEmail => 'Alamat email';

  @override
  String get pdpSettingsSectionEmailHint => 'nama@instansi.go.id';

  @override
  String get pdpSettingsSectionBankAccount => 'Nomor rekening';

  @override
  String get pdpSettingsSectionBankAccountHint =>
      'Hanya bila ada kata \"rekening\" atau nama bank di dekatnya, supaya angka anggaran tidak ikut disamarkan';

  @override
  String get pdpSettingsSectionNamesTitle => 'Nama yang disamarkan';

  @override
  String get pdpSettingsSectionNamesIntro =>
      'Hanya Anda yang tahu nama mana yang sensitif di rapat ini. Entri kurang dari 3 huruf diabaikan.';

  @override
  String get pdpSettingsSectionNameHint => 'Mis. Budi Santoso';

  @override
  String get pdpSettingsSectionAdd => 'Tambah';

  @override
  String get pdpSettingsSectionRetentionTitle => 'Retensi data';

  @override
  String get pdpSettingsSectionRetentionIntro =>
      'Audio dan transkrip punya batas sendiri-sendiri: rekaman biasanya harus dihapus jauh lebih cepat daripada notulennya. Tidak ada yang dihapus otomatis. Anda melihat daftarnya dulu.';

  @override
  String get pdpSettingsSectionDeleteAudioAfter => 'Hapus audio setelah';

  @override
  String get pdpSettingsSectionDeleteTranscriptAfter =>
      'Hapus transkrip (seluruh sesi) setelah';

  @override
  String get pdpSettingsSectionPreviewRetention => 'Lihat & jalankan sekarang';

  @override
  String get pdpSettingsSectionRetentionDialogTitle =>
      'Jalankan kebijakan retensi?';

  @override
  String pdpSettingsSectionWholeSessionAge(int days) {
    return 'Seluruh sesi · $days hari';
  }

  @override
  String pdpSettingsSectionAudioOnlyAge(int days) {
    return 'Audio saja · $days hari';
  }

  @override
  String get pdpSettingsSectionCannotUndo =>
      'Tindakan ini tidak bisa dibatalkan.';

  @override
  String get pdpSettingsSectionDeleteNow => 'Hapus sekarang';

  @override
  String pdpSettingsSectionRetentionApplied(int count) {
    return '$count item dihapus sesuai kebijakan retensi.';
  }

  @override
  String pdpSettingsSectionRetentionPartial(int deleted, int failed) {
    return '$deleted dihapus, $failed gagal.';
  }

  @override
  String pdpSettingsSectionRetentionPreviewFailed(String error) {
    return 'Pratinjau retensi gagal: $error';
  }

  @override
  String get pdpSettingsSectionConsentTitle => 'Pemberitahuan perekaman';

  @override
  String get pdpSettingsSectionConsentReminder =>
      'Ingatkan sebelum mulai merekam';

  @override
  String get pdpSettingsSectionConsentReminderSubtitle =>
      'Tampilkan teks pemberitahuan yang bisa disalin ke obrolan rapat, dan catat penyampaiannya di log audit.';

  @override
  String get pdpSettingsSectionConsentTextLabel => 'Teks pemberitahuan';

  @override
  String pdpSettingsSectionConsentTextHelper(
    String titleToken,
    String dateToken,
  ) {
    return '$titleToken dan $dateToken diganti otomatis. Kosongkan untuk memakai teks bawaan.';
  }

  @override
  String get pdpSettingsSectionCopyNotice => 'Salin teks pemberitahuan';

  @override
  String get pdpSettingsSectionNoticeCopied => 'Teks pemberitahuan disalin.';

  @override
  String pdpSettingsSectionCopyFailed(String error) {
    return 'Gagal menyalin: $error';
  }

  @override
  String get pdpSettingsSectionAuditTitle => 'Log audit';

  @override
  String get pdpSettingsSectionAuditIntro =>
      'Catatan lokal tentang apa yang terjadi pada data: sesi dibuat, transkrip diekspor, ringkasan dikirim, data dihapus. Isinya hanya metadata, tidak ada kutipan transkrip di dalamnya.';

  @override
  String get pdpSettingsSectionViewLog => 'Lihat log';

  @override
  String get pdpSettingsSectionExportCsv => 'Ekspor CSV';

  @override
  String get pdpSettingsSectionSaveAuditDialogTitle => 'Simpan log audit';

  @override
  String pdpSettingsSectionAuditSaved(String path) {
    return 'Log audit disimpan ke $path';
  }

  @override
  String pdpSettingsSectionAuditExportFailed(String error) {
    return 'Ekspor log gagal: $error';
  }

  @override
  String transcriptViewNewLinesAnnouncement(
    int count,
    String speaker,
    String text,
  ) {
    return '$count baris baru. Terakhir, $speaker: $text';
  }

  @override
  String get transcriptViewSegmentCopied => 'Segmen disalin.';

  @override
  String get transcriptViewTranscriptCopied => 'Transkrip disalin.';

  @override
  String get transcriptViewEmptyTitle => 'Belum ada transkrip';

  @override
  String transcriptViewEmptySubtitle(String shortcut) {
    return 'Mulai sesi untuk memulai transkripsi\nTekan Mulai atau $shortcut';
  }

  @override
  String get transcriptViewSearchHint => 'Cari…';

  @override
  String get transcriptViewClearSearch => 'Bersihkan pencarian';

  @override
  String transcriptViewSegmentCount(int count) {
    return '$count segmen';
  }

  @override
  String transcriptViewFilteredSegmentCount(int shown, int total) {
    return '$shown dari $total segmen';
  }

  @override
  String transcriptViewRefiningCount(int count) {
    return '$count sedang diperbaiki';
  }

  @override
  String get transcriptViewFollowPlaybackOn => 'Ikuti pemutaran: aktif';

  @override
  String get transcriptViewFollowPlaybackOff => 'Ikuti pemutaran: mati';

  @override
  String get transcriptViewAutoScrollOn => 'Auto-scroll aktif';

  @override
  String get transcriptViewAutoScrollOff => 'Auto-scroll mati';

  @override
  String get transcriptViewReviewOnly =>
      'Tinjau: hanya segmen yang perlu diperiksa';

  @override
  String transcriptViewReviewCount(int count) {
    return 'Tinjau ($count segmen perlu diperiksa)';
  }

  @override
  String get transcriptViewCopyAll => 'Salin semua';

  @override
  String get transcriptViewNoMatches => 'Tidak ada segmen cocok';

  @override
  String transcriptViewEditingHint(String split) {
    return 'Enter simpan · Esc batal · $split pisah di kursor';
  }

  @override
  String transcriptViewBrowsingHint(String move, String merge) {
    return '↑↓ pilih · Enter sunting · $move pindahkan · $merge gabung ke atas';
  }

  @override
  String transcriptViewSegmentSemantics(
    String speaker,
    String time,
    String text,
  ) {
    return '$speaker pada $time: $text';
  }

  @override
  String get transcriptViewProcessing => 'Diproses…';

  @override
  String get transcriptViewQueued => 'Antre';

  @override
  String get transcriptViewLowConfidence => 'Kepercayaan rendah';

  @override
  String get transcriptViewCopySegment => 'Salin segmen';

  @override
  String get transcriptViewEdit => 'Edit';

  @override
  String get transcriptViewEditDialogTitle => 'Edit Transkrip';

  @override
  String get transcriptViewEditHint => 'Ketik koreksi transkrip…';

  @override
  String get transcriptViewRenameSpeakerTitle => 'Ganti Nama Pembicara';

  @override
  String get transcriptViewNewNameHint => 'Nama baru…';

  @override
  String transcriptViewTentativeSemantics(String text) {
    return 'Sementara, belum final: $text';
  }

  @override
  String get transcriptViewTentativePrefix => 'sementara · ';
}
