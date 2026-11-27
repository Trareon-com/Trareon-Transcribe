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
  String transcriptPlayerScreenBookmarkSaveFailed(String error) {
    return 'Tanda poin gagal disimpan: $error';
  }

  @override
  String get transcriptPlayerScreenAudioUnavailable =>
      'File audio sumber tidak tersedia untuk diputar.';

  @override
  String transcriptPlayerScreenSpeakerChangesApplied(int count) {
    return '$count perubahan pembicara diterapkan.';
  }

  @override
  String transcriptPlayerScreenSaveFailed(String path, String error) {
    return 'Perubahan transkrip gagal disimpan ke $path: $error';
  }

  @override
  String get transcriptPlayerScreenSaveElsewhereDialogTitle =>
      'Simpan transkrip ke folder lain';

  @override
  String get transcriptPlayerScreenSaved => 'Transkrip tersimpan.';

  @override
  String transcriptPlayerScreenBackupFailed(String error) {
    return 'Transkrip lama gagal dicadangkan ($error), jadi transkrip ulang dibatalkan. Transkrip Anda tidak diubah.';
  }

  @override
  String transcriptPlayerScreenRetranscribed(int count, String model) {
    return 'Transkrip diperbarui: $count segmen ($model). Versi sebelumnya dicadangkan.';
  }

  @override
  String get transcriptPlayerScreenRestore => 'Pulihkan';

  @override
  String get transcriptPlayerScreenBackupUnreadable =>
      'Cadangan transkrip tidak bisa dibaca.';

  @override
  String transcriptPlayerScreenBackupRestored(int count) {
    return 'Transkrip sebelum transkrip ulang dipulihkan ($count segmen).';
  }

  @override
  String transcriptPlayerScreenGlossaryReplaceSaved(
    String before,
    String after,
  ) {
    return 'Disimpan. \"$before\" akan ditulis \"$after\" selanjutnya.';
  }

  @override
  String transcriptPlayerScreenGlossaryAdded(String term) {
    return '\"$term\" ditambahkan ke kamus istilah.';
  }

  @override
  String get transcriptPlayerScreenCloseSession => 'Tutup sesi';

  @override
  String get transcriptPlayerScreenBack => 'Kembali';

  @override
  String get transcriptPlayerScreenSaveAsTemplate =>
      'Simpan sebagai template rapat';

  @override
  String get transcriptPlayerScreenShortcutsTooltip =>
      'Pintasan: Spasi putar/jeda · ←/→ 5 detik · J/K/L 10 detik';

  @override
  String get transcriptPlayerScreenSaveElsewhere => 'Simpan ke folder lain';

  @override
  String get transcriptPlayerScreenSaving => 'Menyimpan…';

  @override
  String get transcriptPlayerScreenRetry => 'Coba lagi';

  @override
  String get transcriptPlayerScreenRewind => 'Mundur 10 detik (J)';

  @override
  String get transcriptPlayerScreenPause => 'Jeda (Spasi)';

  @override
  String get transcriptPlayerScreenPlay => 'Putar (Spasi)';

  @override
  String get transcriptPlayerScreenForward => 'Maju 10 detik (L)';

  @override
  String get transcriptPlayerScreenPlaybackSpeed => 'Kecepatan pemutaran';

  @override
  String get transcriptPlayerScreenSpeedHeader => 'Kecepatan';

  @override
  String get transcriptPlayerScreenBookmarkHere => 'Tandai di sini';

  @override
  String get transcriptPlayerScreenMinutes => 'Notulen Rapat';

  @override
  String get transcriptPlayerScreenRestoreBackup => 'Pulihkan cadangan';

  @override
  String get transcriptPlayerScreenRetranscribe => 'Transkrip Ulang';

  @override
  String get transcriptPlayerScreenTags => 'Tag';

  @override
  String transcriptPlayerScreenTagsCount(int count) {
    return 'Tag ($count)';
  }

  @override
  String get transcriptPlayerScreenSpeakers => 'Pembicara';

  @override
  String get transcriptPlayerScreenExport => 'Ekspor';

  @override
  String transcriptPlayerScreenTemplateSaved(String title) {
    return 'Template \"$title\" disimpan.';
  }

  @override
  String get transcriptPlayerScreenShortcutHelpTitle => 'Pintasan pemutar';

  @override
  String get transcriptPlayerScreenShortcutHelpPlay =>
      'Spasi atau K: putar atau jeda';

  @override
  String get transcriptPlayerScreenShortcutHelpSeek5 =>
      'Panah kiri atau kanan: mundur atau maju 5 detik';

  @override
  String get transcriptPlayerScreenShortcutHelpSeek10 =>
      'J atau L: mundur atau maju 10 detik';

  @override
  String get transcriptPlayerScreenShortcutHelpClickRow =>
      'Klik baris transkrip: lompat ke waktu itu';

  @override
  String get transcriptPlayerScreenShortcutHelpClickMark =>
      'Klik tanda di garis waktu: lompat ke poin yang ditandai';

  @override
  String get transcriptPlayerScreenClose => 'Tutup';

  @override
  String get fileUploadZoneQueueEmpty => 'Belum ada berkas di antrean.';

  @override
  String fileUploadZoneQueueSummary(int count, int pending) {
    return '$count berkas · $pending menunggu';
  }

  @override
  String get fileUploadZoneRemoveDone => 'Hapus selesai';

  @override
  String get fileUploadZoneClear => 'Kosongkan';

  @override
  String get fileUploadZoneProcessing => 'Memproses…';

  @override
  String get fileUploadZoneStart => 'Mulai Transkripsi';

  @override
  String fileUploadZoneRejectedMore(int count) {
    return ' dan $count lainnya';
  }

  @override
  String fileUploadZoneRejected(String detail, String more) {
    return 'Dilewati: $detail$more.';
  }

  @override
  String get fileUploadZoneDropAreaSemantics =>
      'Area impor berkas, tarik dan lepas berkas audio atau video ke sini';

  @override
  String get fileUploadZoneDropRelease =>
      'Lepaskan untuk menambahkan ke antrean';

  @override
  String get fileUploadZoneDropHint =>
      'Tarik & lepas berkas audio/video ke sini';

  @override
  String fileUploadZoneFormats(String formats) {
    return 'Format: $formats';
  }

  @override
  String fileUploadZoneMaxSize(String size) {
    return 'Maksimum $size per berkas';
  }

  @override
  String get fileUploadZonePickSemantics => 'Pilih file untuk diupload';

  @override
  String get fileUploadZonePick => 'Pilih Berkas';

  @override
  String get fileUploadZoneLanguage => 'Bahasa';

  @override
  String get fileUploadZoneAutoDetect => 'Deteksi otomatis';

  @override
  String get fileUploadZoneIndonesian => 'Indonesia';

  @override
  String get fileUploadZoneModel => 'Model';

  @override
  String get fileUploadZoneSpeakerCount => 'Jumlah pembicara';

  @override
  String fileUploadZoneSpeakerCountOption(int count) {
    return '$count orang';
  }

  @override
  String get fileUploadZonePreviewFailed => 'Tidak bisa memutar berkas ini.';

  @override
  String fileUploadZoneEntrySemantics(String filename, String status) {
    return '$filename: $status';
  }

  @override
  String fileUploadZoneEntrySemanticsError(
    String filename,
    String status,
    String error,
  ) {
    return '$filename: $status, error: $error';
  }

  @override
  String get fileUploadZoneStopPreview => 'Hentikan pratinjau';

  @override
  String get fileUploadZonePreview => 'Pratinjau audio';

  @override
  String get fileUploadZoneRetry => 'Coba lagi';

  @override
  String get fileUploadZoneCancelFile => 'Batalkan berkas ini';

  @override
  String get fileUploadZoneStatusQueued => 'Antre';

  @override
  String get fileUploadZoneStatusDecoding => 'Membaca berkas';

  @override
  String get fileUploadZoneStatusTranscribing => 'Transkripsi';

  @override
  String get fileUploadZoneStatusDone => 'Selesai';

  @override
  String get fileUploadZoneStatusError => 'Gagal';

  @override
  String get fileUploadZoneStatusCancelled => 'Dibatalkan';

  @override
  String libraryScreenDeleted(String title) {
    return '\"$title\" dihapus.';
  }

  @override
  String get libraryScreenUndo => 'Urungkan';

  @override
  String get libraryScreenRenameTitle => 'Ganti Nama Sesi';

  @override
  String get libraryScreenRenameLabel => 'Nama sesi';

  @override
  String libraryScreenRenameFailed(String error) {
    return 'Gagal mengganti nama: $error';
  }

  @override
  String get libraryScreenSaveArchiveDialogTitle => 'Simpan arsip sesi';

  @override
  String libraryScreenArchiveSaved(String path) {
    return 'Arsip sesi tersimpan: $path';
  }

  @override
  String libraryScreenArchiveExportFailed(String error) {
    return 'Gagal mengekspor arsip sesi: $error';
  }

  @override
  String get libraryScreenPickArchiveDialogTitle => 'Pilih arsip sesi (.zip)';

  @override
  String get libraryScreenImportSkipped => 'Impor arsip sesi dilewati.';

  @override
  String libraryScreenImported(String name) {
    return 'Sesi \"$name\" diimpor.';
  }

  @override
  String get libraryScreenConflictTitle => 'Sesi sudah ada';

  @override
  String libraryScreenConflictBody(String name) {
    return 'Sesi dengan nama \"$name\" sudah ada di perpustakaan ini. Apa yang ingin dilakukan?';
  }

  @override
  String get libraryScreenImportDuplicate => 'Impor sebagai duplikat';

  @override
  String get libraryScreenOverwrite => 'Timpa';

  @override
  String libraryScreenOpenFailed(String title) {
    return '\"$title\" tidak bisa dibuka.';
  }

  @override
  String get libraryScreenTitle => 'Perpustakaan';

  @override
  String get libraryScreenBack => 'Kembali';

  @override
  String get libraryScreenTabSessions => 'Sesi';

  @override
  String get libraryScreenTabImport => 'Impor Berkas';

  @override
  String get libraryScreenSearchHint =>
      'Cari judul, isi transkrip, atau ringkasan…';

  @override
  String get libraryScreenClearSearch => 'Bersihkan pencarian';

  @override
  String get libraryScreenDeepSearching => 'Mencari di dalam transkrip…';

  @override
  String get libraryScreenEmptyTitle => 'Belum ada sesi tersimpan';

  @override
  String get libraryScreenEmptySubtitle =>
      'Sesi transkripsi akan muncul di sini';

  @override
  String get libraryScreenNoMatch => 'Tidak ada sesi cocok';

  @override
  String get libraryScreenImportArchive => 'Impor arsip sesi (.zip)';

  @override
  String exportDialogTitle(String title) {
    return 'Ekspor \"$title\"';
  }

  @override
  String get exportDialogIncomplete =>
      'Transkrip sesi ini belum lengkap, masih ada audio yang sedang ditranskripsi. Hasil ekspor sekarang akan kehilangan bagian itu.';

  @override
  String get exportDialogChooseFormat => 'Pilih format ekspor:';

  @override
  String get exportDialogFormatMd => 'Dengan waktu & nama pembicara';

  @override
  String get exportDialogFormatTxt => 'Teks biasa tanpa waktu';

  @override
  String get exportDialogFormatJson => 'Data lengkap untuk program lain';

  @override
  String get exportDialogFormatSrt => 'Takarir untuk pemutar video';

  @override
  String get exportDialogFormatVtt => 'Takarir untuk web';

  @override
  String get exportDialogFormatHtml => 'Halaman web yang sudah ditata';

  @override
  String get exportDialogFormatDocx => 'Dokumen Microsoft Word';

  @override
  String get exportDialogFormatPdf =>
      'Dokumen siap cetak, font ikut disertakan';

  @override
  String get exportDialogFormatCsv => 'Tabel per segmen untuk spreadsheet';

  @override
  String exportDialogBookmarksIncluded(int count) {
    return '$count poin penting disertakan sebagai bagian \"Poin Penting\"';
  }

  @override
  String get exportDialogSummaryIncluded =>
      'Ringkasan AI disertakan di Markdown, TXT, HTML & DOCX';

  @override
  String get exportDialogPdpRedaction =>
      'Mode Kepatuhan PDP aktif: data pribadi akan disamarkan di file hasil ekspor. Transkrip tersimpan tidak berubah.';

  @override
  String get exportDialogPreview => 'Pratinjau';

  @override
  String get exportDialogSingleFolder => 'Semua file dalam 1 folder';

  @override
  String get exportDialogChooseFolder => 'Pilih Folder';

  @override
  String exportDialogFolderPickerTitle(String title) {
    return 'Pilih folder ekspor untuk \"$title\"';
  }

  @override
  String exportDialogExporting(int count) {
    return 'Mengekspor $count format…';
  }

  @override
  String exportDialogSuccess(String path) {
    return 'Ekspor berhasil ke: $path';
  }

  @override
  String get exportDialogShare => 'Bagikan';

  @override
  String exportDialogFailed(String error) {
    return 'Ekspor gagal: $error';
  }

  @override
  String speakerManagerDialogRenameTitle(String name) {
    return 'Ganti nama \"$name\"';
  }

  @override
  String get speakerManagerDialogNameLabel => 'Nama';

  @override
  String get speakerManagerDialogNameHelper =>
      'Berlaku untuk seluruh sesi ini.';

  @override
  String get speakerManagerDialogRenameConfirm => 'Ganti';

  @override
  String speakerManagerDialogMergeTitle(String name) {
    return 'Gabungkan \"$name\" ke siapa?';
  }

  @override
  String speakerManagerDialogMergeOption(String name, int count) {
    return '$name ($count segmen)';
  }

  @override
  String get speakerManagerDialogTitle => 'Kelola Pembicara';

  @override
  String get speakerManagerDialogNoSpeakers =>
      'Transkrip ini belum punya pembicara.';

  @override
  String speakerManagerDialogPending(int count) {
    return '$count perubahan menunggu. Tekan Terapkan untuk menuliskannya ke transkrip.';
  }

  @override
  String get speakerManagerDialogNothingRemembered =>
      'Belum ada nama yang diingat.';

  @override
  String get speakerManagerDialogForgotten =>
      'Nama pembicara yang diingat dihapus.';

  @override
  String get speakerManagerDialogForgetAll => 'Lupakan nama tersimpan';

  @override
  String get speakerManagerDialogApply => 'Terapkan';

  @override
  String speakerManagerDialogStatsSeconds(int segments, int seconds) {
    return '$segments segmen · $seconds detik';
  }

  @override
  String speakerManagerDialogStatsMinutes(int segments, int minutes) {
    return '$segments segmen · $minutes menit';
  }

  @override
  String get speakerManagerDialogRename => 'Ganti nama';

  @override
  String get speakerManagerDialogMerge => 'Gabungkan dengan pembicara lain';

  @override
  String get speakerManagerDialogNoMerge =>
      'Tidak ada pembicara lain untuk digabung';

  @override
  String speakerManagerDialogSuggestion(String name) {
    return 'Diingat dari rapat sebelumnya: $name';
  }

  @override
  String get speakerManagerDialogUseSuggestion => 'Pakai';

  @override
  String speakerManagerDialogRememberUnrenamed(String label) {
    return 'Ingat nama ini untuk label \"$label\" di rapat berikutnya (ganti namanya dulu)';
  }

  @override
  String speakerManagerDialogRemember(String name, String label) {
    return 'Ingat \"$name\" untuk label \"$label\" di rapat berikutnya';
  }

  @override
  String sessionCardDurationHours(int hours, int minutes) {
    return '${hours}j ${minutes}m';
  }

  @override
  String sessionCardDurationMinutes(int minutes) {
    return '$minutes menit';
  }

  @override
  String sessionCardDate(String day, String month, String year) {
    return '$day $month $year';
  }

  @override
  String get sessionCardMonthJan => 'Jan';

  @override
  String get sessionCardMonthFeb => 'Feb';

  @override
  String get sessionCardMonthMar => 'Mar';

  @override
  String get sessionCardMonthApr => 'Apr';

  @override
  String get sessionCardMonthMay => 'Mei';

  @override
  String get sessionCardMonthJun => 'Jun';

  @override
  String get sessionCardMonthJul => 'Jul';

  @override
  String get sessionCardMonthAug => 'Agu';

  @override
  String get sessionCardMonthSep => 'Sep';

  @override
  String get sessionCardMonthOct => 'Okt';

  @override
  String get sessionCardMonthNov => 'Nov';

  @override
  String get sessionCardMonthDec => 'Des';

  @override
  String get sessionCardHasSummary => 'Punya ringkasan AI';

  @override
  String sessionCardSegments(int count) {
    return '$count segmen';
  }

  @override
  String get sessionCardRename => 'Ganti nama';

  @override
  String get sessionCardExport => 'Ekspor';

  @override
  String get sessionCardExportArchive => 'Ekspor sebagai arsip (.zip)';

  @override
  String get sessionCardDelete => 'Hapus';

  @override
  String get dictionaryLearningDialogTitle => 'Ingat koreksi ini?';

  @override
  String get dictionaryLearningDialogDescription =>
      'Anda mengubah satu kata. Trareon bisa mengingatnya agar tidak perlu dikoreksi lagi di rapat berikutnya.';

  @override
  String get dictionaryLearningDialogDontRemember => 'Jangan ingat';

  @override
  String dictionaryLearningDialogAddToGlossary(String term) {
    return 'Tambahkan \"$term\" ke kamus istilah';
  }

  @override
  String get dictionaryLearningDialogAddToGlossaryHelper =>
      'Mesin pengenal suara diberi tahu istilah ini sebelum mentranskrip, sehingga lebih mungkin menuliskannya dengan benar sejak awal.';

  @override
  String dictionaryLearningDialogAutoReplace(String before, String after) {
    return 'Ganti otomatis \"$before\" → \"$after\" selanjutnya';
  }

  @override
  String dictionaryLearningDialogAutoReplaceHelper(
    String before,
    String after,
  ) {
    return 'Setiap kata \"$before\" yang berdiri sendiri akan ditulis \"$after\" di transkrip berikutnya. Bisa dihapus di Pengaturan → Kamus istilah.';
  }

  @override
  String get dictionaryLearningDialogPickOne =>
      'Pilih setidaknya satu agar ada yang disimpan.';

  @override
  String get tagEditorDialogTitle => 'Tag sesi';

  @override
  String get tagEditorDialogDescription =>
      'Tag dipakai untuk memfilter daftar sesi di bilah kiri. Tidak ada berkas yang dipindahkan.';

  @override
  String get tagEditorDialogAddLabel => 'Tambah tag';

  @override
  String get tagEditorDialogAdd => 'Tambah';

  @override
  String get tagEditorDialogEmpty => 'Sesi ini belum punya tag.';

  @override
  String get tagEditorDialogSuggestions => 'Tag lain di perpustakaan';

  @override
  String get appShortcutsStartStop => 'Mulai atau berhenti merekam';

  @override
  String get appShortcutsPauseResume => 'Jeda atau lanjutkan';

  @override
  String get appShortcutsSearchSessions => 'Cari di riwayat sesi';

  @override
  String get appShortcutsBookmark => 'Tandai poin penting';

  @override
  String get appShortcutsSettings => 'Buka Pengaturan';

  @override
  String get appShortcutsShortcutsPanel => 'Tampilkan pintasan keyboard';

  @override
  String get appShortcutsToggleSidebar => 'Sembunyikan atau tampilkan sidebar';

  @override
  String formatTimeSeconds(int seconds) {
    return '$seconds detik';
  }

  @override
  String formatTimeMinutes(int minutes) {
    return '$minutes menit';
  }

  @override
  String formatTimeHours(int hours) {
    return '$hours jam';
  }

  @override
  String formatTimeHoursMinutes(int hours, int minutes) {
    return '$hours jam $minutes menit';
  }

  @override
  String get modelDownloadCardNotDownloaded => 'Belum diunduh';

  @override
  String get modelDownloadCardReady => 'Siap';

  @override
  String get modelDownloadCardFailed => 'Gagal, coba lagi';

  @override
  String appFeedbackPercent(int percent) {
    return '$percent persen';
  }

  @override
  String appChipDelete(String label) {
    return 'Hapus $label';
  }

  @override
  String get resourceIndicatorSemantics =>
      'Penggunaan memori tinggi, pertimbangkan tutup aplikasi lain';

  @override
  String get resourceIndicatorHigh =>
      'Tinggi, pertimbangkan tutup aplikasi lain';

  @override
  String summaryModelSaveActionItemsFailed(String error) {
    return 'Gagal menyimpan tindak lanjut: $error';
  }

  @override
  String get summaryModelDisabled =>
      'Ringkasan AI belum diaktifkan. Nyalakan di Pengaturan → Ringkasan AI.';

  @override
  String get summaryModelNotConfigured =>
      'Endpoint atau model ringkasan belum diisi. Lengkapi di Pengaturan → Ringkasan AI.';

  @override
  String get summaryModelEmptyTranscriptSummarize =>
      'Transkrip kosong, tidak ada yang bisa diringkas.';

  @override
  String summaryModelTemplateUnusable(String name, String error) {
    return 'Template \"$name\" tidak bisa dipakai: $error';
  }

  @override
  String summaryModelGenerateFailed(String error) {
    return 'Gagal membuat ringkasan (transkrip tetap aman): $error';
  }

  @override
  String get summaryModelEmptyTranscriptMerge =>
      'Transkrip kosong, tidak ada yang bisa digabung.';

  @override
  String summaryModelEnhanceFailed(String error) {
    return 'Gagal menggabungkan catatan dengan transkrip: $error';
  }

  @override
  String summaryModelSaveFailed(String error) {
    return 'Gagal menyimpan ringkasan: $error';
  }
}
