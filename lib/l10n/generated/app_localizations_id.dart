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
  String get qualityProfileReasonManual => 'Dipilih manual';

  @override
  String get qualityProfileReasonUnmeasured =>
      'Belum terukur; pengaturan konservatif dipakai';

  @override
  String get qualityProfileReasonClean =>
      'Ruangan bersih; derau dan AGC dimatikan agar tidak memakan kata';

  @override
  String get qualityProfileReasonLightNoiseGain =>
      'Derau ringan; hanya level yang dinaikkan';

  @override
  String get qualityProfileReasonLightNoiseNoGain =>
      'Derau ringan; level sudah cukup, gain tidak dipakai';

  @override
  String get qualityProfileReasonNoisy =>
      'Derau tinggi; pengurangan derau dinyalakan';

  @override
  String get notulenGenerationLengthShort => 'Ringkas';

  @override
  String get notulenGenerationLengthMedium => 'Sedang';

  @override
  String get notulenGenerationLengthFull => 'Lengkap';

  @override
  String get liveQaModelNeedsEndpoint =>
      'Tanya Langsung memerlukan endpoint ringkasan yang sudah diatur di Pengaturan → Ringkasan AI.';

  @override
  String privacyReportModelEventModelDownload(String modelId) {
    return 'Mengunduh model \"$modelId\" dari huggingface.co';
  }

  @override
  String privacyReportModelEventSummary(String endpoint) {
    return 'Ringkasan AI dikirim ke $endpoint';
  }

  @override
  String privacyReportModelEventArchiveQuestion(
    String endpoint,
    int passageCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      passageCount,
      locale: localeName,
      other: '$passageCount kutipan rapat',
    );
    return 'Pertanyaan arsip dikirim ke $endpoint ($_temp0)';
  }

  @override
  String privacyReportModelEventLiveQaQuestion(
    String endpoint,
    int passageCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      passageCount,
      locale: localeName,
      other: '$passageCount kutipan transkrip',
    );
    return 'Pertanyaan Tanya Langsung dikirim ke $endpoint ($_temp0)';
  }

  @override
  String privacyReportModelEventUpdateCheck(String endpoint) {
    return 'Memeriksa pembaruan ke $endpoint';
  }

  @override
  String privacyReportModelEventExternalLink(String url) {
    return 'Membuka $url di peramban';
  }

  @override
  String get speechTimelineSemanticLabel => 'Garis waktu rekaman';

  @override
  String speechTimelinePercent(int percent) {
    return '$percent persen';
  }

  @override
  String get audioWatchdogModelMicSilent =>
      'Mikrofon belum diberi izin, atau tidak mengirim suara sama sekali. Periksa izin Mikrofon di Pengaturan Sistem.';

  @override
  String get audioWatchdogModelSystemAudioSilent =>
      'Audio sistem tidak terdeteksi sama sekali. Periksa izin \"Rekam Layar & Audio Sistem\" di Pengaturan Sistem.';

  @override
  String get audioWatchdogModelBothSilent =>
      'Mikrofon maupun audio sistem belum diberi izin. Periksa Pengaturan Sistem untuk Mikrofon dan \"Rekam Layar & Audio Sistem\".';

  @override
  String get audioWatchdogModelNoSound =>
      'Belum ada suara terdeteksi. Periksa izin Mikrofon dan \"Rekam Layar & Audio Sistem\" di Pengaturan Sistem, atau pastikan sumber audio yang dipilih sudah benar.';

  @override
  String get modelDownloadDialogDownloading => 'Mengunduh…';

  @override
  String modelDownloadDialogDownloadingName(String name) {
    return 'Mengunduh $name…';
  }

  @override
  String modelDownloadDialogDownloadingProgress(String name, int percent) {
    return 'Mengunduh $name… $percent%';
  }

  @override
  String modelDownloadDialogFailed(String error) {
    return 'Gagal mengunduh: $error';
  }

  @override
  String modelDownloadDialogTitle(String name) {
    return 'Unduh $name';
  }

  @override
  String modelDownloadDialogPrompt(String name) {
    return '$name belum diunduh. Apakah Anda ingin mengunduh sekarang?';
  }

  @override
  String get modelDownloadDialogDownload => 'Unduh';

  @override
  String retranscribeDialogEngineFailed(String error) {
    return 'Gagal transkrip ulang: $error. Transkrip lama tetap dipertahankan.';
  }

  @override
  String get retranscribeDialogNoSpeech =>
      'Tidak ada ucapan terdeteksi. Transkrip lama tetap dipertahankan.';

  @override
  String retranscribeDialogFailed(String error) {
    return 'Gagal transkrip ulang (transkrip lama tetap aman): $error';
  }

  @override
  String get retranscribeDialogTitle => 'Transkrip Ulang';

  @override
  String get retranscribeDialogDescription =>
      'Audio asli akan ditranskrip ulang. Transkrip lama diganti hanya kalau proses berhasil.';

  @override
  String get retranscribeDialogModelLabel => 'Kualitas model';

  @override
  String get retranscribeDialogLanguageLabel => 'Bahasa';

  @override
  String get retranscribeDialogAutoDetect => 'Deteksi otomatis';

  @override
  String get retranscribeDialogIndonesian => 'Indonesia';

  @override
  String get retranscribeDialogNoModels => 'Tidak ada model terpasang.';

  @override
  String get retranscribeDialogProcessing =>
      'Memproses… ini bisa memakan waktu untuk rekaman panjang.';

  @override
  String get retranscribeDialogStart => 'Mulai';

  @override
  String get auditLogViewTitle => 'Log audit';

  @override
  String get auditLogViewClose => 'Tutup';

  @override
  String auditLogViewReadError(String error) {
    return 'Log audit tidak bisa dibaca: $error';
  }

  @override
  String get auditLogViewEmpty =>
      'Belum ada catatan. Log terisi saat sesi dibuat, transkrip diekspor, atau data dihapus.';

  @override
  String get auditLogViewActionSessionCreated => 'Sesi dibuat';

  @override
  String get auditLogViewActionSessionExported => 'Transkrip diekspor';

  @override
  String get auditLogViewActionSummarySent => 'Ringkasan dikirim ke endpoint';

  @override
  String get auditLogViewActionSessionDeleted => 'Sesi dihapus';

  @override
  String get auditLogViewActionAudioDeleted => 'Audio dihapus';

  @override
  String get auditLogViewActionTranscriptDeleted => 'Transkrip dihapus';

  @override
  String get auditLogViewActionConsentAcknowledged =>
      'Pemberitahuan perekaman disampaikan';

  @override
  String get auditLogViewActionRedactionApplied =>
      'Penyamaran data pribadi diterapkan';

  @override
  String get auditLogViewActionRetentionApplied =>
      'Kebijakan retensi dijalankan';

  @override
  String get auditLogViewActionAuditExported => 'Log audit diekspor';

  @override
  String get auditLogViewActionModelPulled => 'Model notulen diunduh';

  @override
  String get auditLogViewActionDocumentContextUsed =>
      'Konteks dokumen digunakan';

  @override
  String get auditLogViewActionTranscriptEnhanced =>
      'Transkrip diperhalus otomatis';

  @override
  String get onboardingScreenWelcome => 'Selamat datang di Trareon Transcribe';

  @override
  String get onboardingScreenReady => 'Siap merekam';

  @override
  String get onboardingScreenPostponed => 'Unduhan ditunda';

  @override
  String get onboardingScreenNeedsDownload => 'Model perlu diunduh';

  @override
  String get onboardingScreenDownloading => 'Mengunduh model';

  @override
  String get onboardingScreenReadyBody =>
      'Kedua model sudah ada di perangkat ini. Transkripsi berjalan sepenuhnya offline.';

  @override
  String get onboardingScreenOfflineBody =>
      'Trareon bekerja 100% offline, jadi modelnya perlu ada di perangkat Anda. Hanya sekali.';

  @override
  String get onboardingScreenRetry => 'Coba Lagi';

  @override
  String get onboardingScreenDownloadNow => 'Unduh sekarang';

  @override
  String get onboardingScreenContinueWithoutModels => 'Masuk tanpa model';

  @override
  String get onboardingScreenStartRecording => 'Mulai Merekam';

  @override
  String get onboardingScreenAwaitingConsent => 'Menunggu izin unduh';

  @override
  String get onboardingScreenDownloadingButton => 'Mengunduh…';

  @override
  String get onboardingScreenFooterReady =>
      'Model tidak akan pernah dikirim ke mana pun.';

  @override
  String get onboardingScreenFooterPostponed =>
      'Tidak ada yang diunduh. Tanpa model, rekaman belum bisa ditranskripsi; ajakan mengunduh muncul lagi saat Anda mulai merekam.';

  @override
  String get onboardingScreenFooterWaiting =>
      'Tidak ada yang diunduh sebelum Anda setuju.';

  @override
  String get onboardingScreenFooterDownloading =>
      'Anda boleh menutup aplikasi, unduhan dilanjutkan di latar belakang.';

  @override
  String get onboardingScreenStepPermissions => 'Izin mikrofon & audio sistem';

  @override
  String get onboardingScreenStepModel => 'Pilih model';

  @override
  String get onboardingScreenStepReady => 'Siap rekam';

  @override
  String onboardingScreenStepSemantics(int step, int total, String label) {
    return 'Langkah $step dari $total: $label';
  }

  @override
  String get onboardingScreenQuickModelTitle => 'Model Cepat';

  @override
  String get onboardingScreenQuickModelSubtitle =>
      'Transkripsi cepat, akurasi Bahasa Indonesia maksimal';

  @override
  String get onboardingScreenAccurateModelTitle => 'Model Akurat';

  @override
  String get onboardingScreenAccurateModelSubtitle =>
      'Menyempurnakan transkrip di latar belakang, akurasi global terbaik';

  @override
  String sessionModelSaveFailed(String outputDir, String error) {
    return 'Sesi berhenti, tapi gagal menyimpan transkrip ke $outputDir: $error';
  }

  @override
  String settingsModelSaveFailed(String label, String message) {
    return 'Pengaturan \"$label\" gagal disimpan: $message. Perubahan dikembalikan.';
  }

  @override
  String get settingsModelLabelTheme => 'Tema';

  @override
  String get settingsModelLabelProgressive => 'Cepat dulu, lalu diperhalus';

  @override
  String get settingsModelLabelGpu => 'Akselerasi GPU';

  @override
  String get settingsModelLabelGpuDevice => 'Perangkat GPU';

  @override
  String get settingsModelLabelBenchmark => 'Skor benchmark';

  @override
  String get settingsModelLabelHptMode => 'Cara transkripsi bertahap';

  @override
  String get settingsModelLabelSummary => 'Ringkasan AI';

  @override
  String get settingsModelLabelGlossary => 'Kamus istilah';

  @override
  String get settingsModelLabelNeuralDiarization =>
      'Pemisahan pembicara akurat';

  @override
  String get settingsModelLabelEngineModels => 'Model mesin';

  @override
  String get settingsModelLabelPdp => 'Mode Kepatuhan PDP';

  @override
  String get settingsModelLabelSummaryTemplates => 'Template ringkasan';

  @override
  String get settingsModelLabelNotulenLetterhead => 'Kop surat notulen';

  @override
  String get settingsModelLabelAutoRetranscribe =>
      'Perhalus transkrip otomatis';

  @override
  String get settingsModelLabelDefaultModel => 'Model default';

  @override
  String get settingsModelLabelLanguage => 'Bahasa';

  @override
  String get settingsModelLabelDefaultMode => 'Mode default';

  @override
  String get settingsModelLabelVad => 'Abaikan jeda sunyi';

  @override
  String get settingsModelLabelNoiseReduction => 'Pengurangan derau';

  @override
  String get settingsModelLabelAgc => 'Penguatan suara otomatis';

  @override
  String get settingsModelLabelAutoAudioTuning => 'Penyetelan audio otomatis';

  @override
  String get settingsModelLabelSimpleMode => 'Mode Sederhana';

  @override
  String get settingsModelLabelDeferDownloads => 'Tunda unduhan';

  @override
  String get settingsModelLabelUpgradeOffer => 'Tawaran tingkatkan akurasi';

  @override
  String get settingsModelLabelConsentReminder =>
      'Pengingat persetujuan perekaman';

  @override
  String get settingsModelLabelAutoStop => 'Berhenti sendiri saat sunyi';

  @override
  String get settingsModelLabelExportFormat => 'Format ekspor default';

  @override
  String get settingsModelLabelOutputFolder => 'Folder output';

  @override
  String get settingsModelLabelMicrophone => 'Mikrofon';

  @override
  String get settingsModelLabelSpeaker => 'Pengeras suara';

  @override
  String get sessionControlsSessionGroup => 'Sesi';

  @override
  String get sessionControlsTitlePlaceholder => 'Judul sesi…';

  @override
  String get sessionControlsModeSemantics => 'Mode sesi';

  @override
  String get sessionControlsAttendees => 'Peserta:';

  @override
  String get sessionControlsModeOfflineSemantics =>
      'Mode rapat offline: hanya mikrofon';

  @override
  String get sessionControlsModeOnlineSemantics =>
      'Mode rapat online: mikrofon dan suara sistem';

  @override
  String get sessionControlsModeWebinarSemantics =>
      'Mode webinar: hanya suara sistem';

  @override
  String get sessionControlsModeOfflineExplanation =>
      'Rapat di satu ruangan. Hanya mikrofon yang direkam.';

  @override
  String get sessionControlsModeOnlineExplanation =>
      'Zoom, Meet atau Teams. Mikrofon dan suara sistem.';

  @override
  String get sessionControlsModeWebinarExplanation =>
      'Anda hanya menyimak. Hanya suara sistem.';

  @override
  String sessionControlsGlossaryTooltip(int globalCount) {
    return 'Istilah khusus rapat ini, di atas $globalCount istilah di Pengaturan';
  }

  @override
  String get sessionControlsGlossarySemanticsEmpty =>
      'Istilah rapat, belum ada';

  @override
  String sessionControlsGlossarySemanticsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count istilah',
    );
    return 'Istilah rapat, $_temp0';
  }

  @override
  String get sessionControlsGlossaryPill => 'Istilah rapat';

  @override
  String sessionControlsGlossaryPillCount(int count) {
    return 'Istilah rapat ($count)';
  }

  @override
  String get sessionControlsGlossaryDialogTitle => 'Istilah khusus rapat ini';

  @override
  String get sessionControlsGlossaryDialogDescription =>
      'Satu istilah per baris: nama peserta, singkatan, nama program. Diutamakan di atas kamus di Pengaturan.';

  @override
  String get sessionControlsOptionsTooltip => 'Opsi sesi';

  @override
  String get sessionControlsQualityHeader => 'Kualitas transkripsi';

  @override
  String get sessionControlsSkipSilence => 'Lewati jeda sunyi';

  @override
  String get sessionControlsLanguageHeader => 'Bahasa rapat ini';

  @override
  String get sessionControlsLanguageAuto => 'Otomatis (deteksi per kalimat)';

  @override
  String get sessionControlsLanguageIndonesian => 'Indonesia';

  @override
  String get sessionControlsLanguageEnglish => 'Inggris';

  @override
  String get sessionControlsLanguageMismatch =>
      'Banyak kalimat terakhir terdeteksi bukan bahasa yang dipilih untuk sesi ini.';

  @override
  String get sessionControlsSwitchToAuto => 'Ganti ke Otomatis';

  @override
  String get sessionControlsConsentReminder =>
      'Pastikan semua peserta tahu rapat ini direkam.';

  @override
  String get sessionControlsDontShowAgain => 'Jangan tampilkan lagi';

  @override
  String get sessionControlsMicrophone => 'Mikrofon';

  @override
  String get sessionControlsSystemAudio => 'Suara sistem';

  @override
  String get sessionControlsDevicesGroup => 'Perangkat';

  @override
  String get sessionControlsSystemDefault => 'Bawaan sistem';

  @override
  String sessionControlsDeviceOn(String label) {
    return '$label aktif';
  }

  @override
  String sessionControlsDeviceOff(String label) {
    return '$label nonaktif';
  }

  @override
  String sessionControlsChooseDevice(String label) {
    return 'Pilih perangkat $label';
  }

  @override
  String get sessionControlsDeviceAuto => 'Otomatis (bawaan sistem)';

  @override
  String sessionControlsReloadDevices(String label) {
    return 'Muat ulang daftar perangkat $label';
  }

  @override
  String sessionControlsLevel(String label) {
    return 'Level $label';
  }

  @override
  String get mainScreenQuitReasonRecording => 'Rekaman masih berjalan.';

  @override
  String mainScreenQuitReasonOutstanding(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rekaman masih diselesaikan transkripnya, pekerjaan ini dilanjutkan otomatis saat aplikasi dibuka lagi.',
    );
    return '$_temp0';
  }

  @override
  String get mainScreenQuitReasonRefining =>
      'Masih ada transkrip yang sedang diperhalus.';

  @override
  String get mainScreenQuitTitle => 'Keluar sekarang?';

  @override
  String get mainScreenQuitStay => 'Tetap di aplikasi';

  @override
  String get mainScreenQuit => 'Keluar';

  @override
  String get mainScreenMeetingDetectedTitle => 'Rapat terdeteksi';

  @override
  String mainScreenMeetingDetectedBody(String app) {
    return 'Terdeteksi rapat ($app). Mulai rekam?';
  }

  @override
  String get mainScreenIgnore => 'Abaikan';

  @override
  String get mainScreenStartRecording => 'Mulai Rekam';

  @override
  String get mainScreenSilenceTitle => 'Tidak ada suara';

  @override
  String mainScreenSilenceBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes menit',
    );
    return 'Tidak ada suara selama $_temp0. Rekaman akan berhenti otomatis kecuali dilanjutkan.';
  }

  @override
  String get mainScreenContinue => 'Lanjutkan';

  @override
  String mainScreenDiskFull(String path, String detail) {
    return 'Ruang disk di $path tidak cukup untuk merekam. $detail Kosongkan ruang atau ubah lokasi perpustakaan di Pengaturan.';
  }

  @override
  String get mainScreenSaveElsewhereDialogTitle =>
      'Simpan transkrip ke folder lain';

  @override
  String get mainScreenTranscriptSaved => 'Transkrip tersimpan.';

  @override
  String mainScreenSaveFailed(String error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String mainScreenRecoverFailed(String error) {
    return 'Gagal memulihkan sesi: $error';
  }

  @override
  String mainScreenRecovered(String title, int segments, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      segments,
      locale: localeName,
      other: '$segments segmen',
    );
    return '\"$title\" dipulihkan: $_temp0 dan $duration audio.';
  }

  @override
  String mainScreenDeleteFailed(String error) {
    return 'Gagal menghapus: $error';
  }

  @override
  String mainScreenDeleted(String title) {
    return '\"$title\" dihapus.';
  }

  @override
  String mainScreenRecoveryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesi terhenti',
      one: '1 sesi terhenti',
    );
    return '$_temp0';
  }

  @override
  String mainScreenRecoverySegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segmen transkrip',
    );
    return '$_temp0';
  }

  @override
  String mainScreenRecoveryAudio(String duration) {
    return '$duration audio';
  }

  @override
  String get mainScreenRecoveryJoiner => ' dan ';

  @override
  String mainScreenRecoveryNothingLeft(String count) {
    return '$count tanpa transkrip atau audio yang tersisa.';
  }

  @override
  String mainScreenRecoveryContents(String count, String contents) {
    return '$count: $contents bisa dipulihkan.';
  }

  @override
  String get mainScreenStopTitle => 'Berhenti merekam?';

  @override
  String mainScreenStopBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segmen transkrip',
    );
    return 'Sesi ini punya $_temp0. Sesi akan disimpan otomatis saat berhenti.';
  }

  @override
  String get mainScreenStop => 'Berhenti';

  @override
  String mainScreenStopFailed(String error) {
    return 'Gagal menghentikan sesi: $error';
  }

  @override
  String mainScreenSessionSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segmen',
    );
    return 'Sesi tersimpan ($_temp0).';
  }

  @override
  String get mainScreenNothingToBookmark => 'Belum ada rekaman untuk ditandai.';

  @override
  String mainScreenBookmarked(String time) {
    return 'Ditandai di $time.';
  }

  @override
  String get mainScreenModelMissingTitle => 'Model belum diunduh';

  @override
  String mainScreenModelMissingMessage(String model, String size) {
    return 'Rekaman perlu $model di perangkat ini. Unduh sekarang$size? Unduhan tercatat di Laporan Privasi.';
  }

  @override
  String get mainScreenDownloadNow => 'Unduh sekarang';

  @override
  String get mainScreenLater => 'Nanti';

  @override
  String get mainScreenNothingToExport => 'Tidak ada transkrip untuk diekspor.';

  @override
  String get mainScreenChooseExportFolder => 'Pilih folder ekspor';

  @override
  String mainScreenExportSucceeded(String dir) {
    return 'Ekspor berhasil ke: $dir';
  }

  @override
  String mainScreenExportFailed(String error) {
    return 'Ekspor gagal: $error';
  }

  @override
  String mainScreenCannotOpen(String title) {
    return '\"$title\" tidak bisa dibuka.';
  }

  @override
  String get mainScreenOpenSystemSettings => 'Buka Pengaturan Sistem';

  @override
  String get mainScreenStarting => 'Memulai…';

  @override
  String get mainScreenSaving => 'Menyimpan…';

  @override
  String get mainScreenSwitchPanel => 'Ganti panel';

  @override
  String get mainScreenPersonalNotes => 'Catatan Pribadi';

  @override
  String get mainScreenLiveQa => 'Tanya Langsung';

  @override
  String get mainScreenReady => 'Siap merekam';

  @override
  String get mainScreenLocalOnly =>
      'Semua transkripsi berjalan di komputer ini. Tidak ada audio yang keluar.';

  @override
  String get mainScreenTitlePlaceholder => 'Judul sesi…';

  @override
  String get mainScreenStartFromTemplate => 'Mulai dari template';

  @override
  String get mainScreenImportInvite => 'Impor undangan (.ics)';

  @override
  String get mainScreenOrPress => 'atau tekan';

  @override
  String get mainScreenSessionHistory => 'Riwayat sesi';

  @override
  String get mainScreenRecordingDuration => 'Durasi rekaman';

  @override
  String get mainScreenPaused => 'Dijeda';

  @override
  String mainScreenBookmarkTooltip(String shortcut) {
    return 'Tandai poin penting ($shortcut)';
  }

  @override
  String get mainScreenExport => 'Ekspor';

  @override
  String mainScreenSaveFailedBanner(String message) {
    return '$message Transkrip masih ada di memori, jangan tutup aplikasi sebelum tersimpan.';
  }

  @override
  String get mainScreenSaveElsewhere => 'Simpan ke folder lain';

  @override
  String get mainScreenRetry => 'Coba Lagi';

  @override
  String get mainScreenViewAndRecover => 'Lihat & Pulihkan';

  @override
  String mainScreenSegmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segmen',
    );
    return '$_temp0';
  }

  @override
  String get mainScreenShowShortcuts => 'Tampilkan pintasan keyboard';

  @override
  String get mainScreenShortcuts => 'Pintasan';

  @override
  String get mainScreenKeyboardShortcuts => 'Pintasan keyboard';

  @override
  String get mainScreenClose => 'Tutup';
}
