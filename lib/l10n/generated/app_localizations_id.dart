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
  String get settingsScreenTitle => 'Pengaturan';

  @override
  String get settingsScreenCategoryAppearance => 'Tampilan';

  @override
  String get settingsScreenCategoryModelMode => 'Model & Mode';

  @override
  String get settingsScreenCategoryAudio => 'Audio & Suara';

  @override
  String get settingsScreenCategoryGlossary => 'Kamus Istilah';

  @override
  String get settingsScreenCategoryStorage => 'Penyimpanan';

  @override
  String get settingsScreenCategorySummary => 'Ringkasan AI';

  @override
  String get settingsScreenCategoryMinutes => 'Notulen Resmi';

  @override
  String get settingsScreenCategoryCompliance => 'Kepatuhan PDP';

  @override
  String get settingsScreenCategorySetup => 'Penyiapan & Diagnostik';

  @override
  String get settingsScreenCategoryAbout => 'Tentang';

  @override
  String get settingsScreenDismiss => 'Abaikan';

  @override
  String get settingsScreenRetry => 'Coba lagi';

  @override
  String get settingsScreenTheme => 'Tema';

  @override
  String get settingsScreenThemeSystemSubtitle =>
      'Mengikuti tema sistem operasi Anda saat ini.';

  @override
  String get settingsScreenThemeLightSubtitle =>
      'Selalu terang, apa pun tema sistem.';

  @override
  String get settingsScreenThemeDarkSubtitle =>
      'Selalu gelap, apa pun tema sistem.';

  @override
  String get settingsScreenThemeLight => 'Terang';

  @override
  String get settingsScreenThemeDark => 'Gelap';

  @override
  String get settingsScreenThemeSystem => 'Sistem';

  @override
  String get settingsScreenSimpleMode => 'Mode Sederhana';

  @override
  String get settingsScreenSimpleModeOnSubtitle =>
      'Hanya kontrol yang mengubah hasil transkrip yang tampil. Sisanya ada di balik \"Pengaturan lanjutan\".';

  @override
  String get settingsScreenSimpleModeOffSubtitle =>
      'Semua kontrol ditampilkan.';

  @override
  String get settingsScreenAutoAudioTuning => 'Penyetelan audio otomatis';

  @override
  String get settingsScreenAutoAudioTuningOffSubtitle =>
      'Dimatikan karena Anda pernah mengubah derau/AGC sendiri. Nilai Anda yang dipakai.';

  @override
  String get settingsScreenChangeManually => 'Ubah manual';

  @override
  String get settingsScreenUseAutomatic => 'Pakai otomatis';

  @override
  String get settingsScreenDefaultModel => 'Model default';

  @override
  String get settingsScreenModelAvailable => 'Tersedia di komputer ini.';

  @override
  String get settingsScreenModelNotDownloaded =>
      'Belum diunduh. Pilih untuk mengunduhnya.';

  @override
  String get settingsScreenProgressive => 'Cepat dulu, lalu diperhalus';

  @override
  String get settingsScreenProgressiveOnSubtitle =>
      'Teks muncul cepat, lalu diperbaiki sendiri dengan model yang lebih teliti.';

  @override
  String get settingsScreenProgressiveOffSubtitle =>
      'Pakai satu model saja. Teks muncul sekali, sudah final.';

  @override
  String get settingsScreenAutoRetranscribe =>
      'Perhalus otomatis dengan model lebih akurat di latar belakang';

  @override
  String get settingsScreenAutoRetranscribeMissingSubtitle =>
      'Model akurat belum terpasang di komputer ini. Unduh dulu lewat \"Model default\" di atas sebelum menyalakan ini.';

  @override
  String get settingsScreenAutoRetranscribeOnSubtitle =>
      'Setelah rekam/unggah selesai, transkrip diperhalus di latar belakang tanpa menghentikan pekerjaan Anda. Transkrip lama diganti hanya kalau prosesnya berhasil.';

  @override
  String get settingsScreenAutoRetranscribeOffSubtitle =>
      'Mati. Transkrip tidak diperhalus otomatis setelah rekaman selesai.';

  @override
  String get settingsScreenGpu => 'Akselerasi GPU';

  @override
  String get settingsScreenDefaultMode => 'Mode default';

  @override
  String get settingsScreenModeWebinarSubtitle =>
      'Mikrofon mati, suara sistem direkam.';

  @override
  String get settingsScreenModeOnlineSubtitle =>
      'Mikrofon dan suara sistem direkam.';

  @override
  String get settingsScreenModeOfflineSubtitle =>
      'Hanya mikrofon yang direkam.';

  @override
  String get settingsScreenTranscriptionLanguage => 'Bahasa';

  @override
  String get settingsScreenLanguageAutoSubtitle =>
      'Bahasa dideteksi otomatis per segmen.';

  @override
  String get settingsScreenLanguageForcedSubtitle =>
      'Dipaksa ke satu bahasa, lebih akurat kalau rapatnya memang satu bahasa.';

  @override
  String get settingsScreenLanguageAuto => 'Deteksi otomatis';

  @override
  String get settingsScreenLanguageIndonesian => 'Indonesia';

  @override
  String get settingsScreenHideAdvanced => 'Sembunyikan pengaturan lanjutan';

  @override
  String get settingsScreenShowAdvanced => 'Pengaturan lanjutan';

  @override
  String get settingsScreenAdvancedSubtitle =>
      'Akselerasi GPU · cepat-lalu-diperhalus · perbaikan di latar belakang · mode rekaman.';

  @override
  String get settingsScreenTranscription => 'Transkripsi';

  @override
  String get settingsScreenSpeedComparison => 'Perbandingan Kecepatan';

  @override
  String get settingsScreenSpeedComparisonSubtitle =>
      'Bahasa Indonesia: ringan 3 detik · cepat 10 detik · akurat 56 detik untuk tiap 1 menit audio.\nModel akurat disarankan untuk rapat dan wawancara.';

  @override
  String settingsScreenAudioDecision(String reason, String noise, String agc) {
    return '$reason. Derau $noise, AGC $agc.';
  }

  @override
  String get settingsScreenStateOn => 'nyala';

  @override
  String get settingsScreenStateOff => 'mati';

  @override
  String get settingsScreenGpuUnknownOnSubtitle =>
      'Akan memakai GPU bila build ini mendukungnya.';

  @override
  String get settingsScreenGpuCpuSubtitle => 'Transkripsi memakai CPU.';

  @override
  String get settingsScreenGpuNotCompiledSubtitle =>
      'Build ini dikompilasi tanpa dukungan GPU, jadi transkripsi tetap memakai CPU meski sakelar ini aktif.';

  @override
  String settingsScreenGpuOnSubtitle(String backend) {
    return 'Transkripsi memakai GPU ($backend).';
  }

  @override
  String settingsScreenGpuAvailableOffSubtitle(String backend) {
    return 'GPU ($backend) tersedia, tapi transkripsi memakai CPU.';
  }

  @override
  String get settingsScreenDecidedAutomatically => 'Diputuskan otomatis';

  @override
  String get settingsScreenVad => 'Abaikan jeda sunyi';

  @override
  String get settingsScreenVadOnSubtitle =>
      'Bagian yang sunyi dilewati, jadi transkripsi lebih cepat. Berlaku mulai sesi berikutnya.';

  @override
  String get settingsScreenVadOffSubtitle =>
      'Semua audio ditranskrip, termasuk bagian yang sunyi.';

  @override
  String get settingsScreenNoiseReduction => 'Pengurangan derau (RNNoise)';

  @override
  String get settingsScreenNoiseReductionOnSubtitle =>
      'Derau ruangan (kipas, AC, lalu lintas) ditekan sebelum transkripsi. Berlaku mulai potongan audio berikutnya.';

  @override
  String get settingsScreenNoiseReductionOffSubtitle =>
      'Mati. Nyalakan bila ruangan Anda berisik; pada rekaman yang sudah bersih ini bisa menghilangkan satu-dua konsonan.';

  @override
  String get settingsScreenAgc => 'Penguatan suara otomatis (AGC)';

  @override
  String get settingsScreenAgcOnSubtitle =>
      'Suara pelan tapi nyata dikuatkan sebelum transkripsi, agar tidak terbaca sebagai sunyi.';

  @override
  String get settingsScreenAgcOffSubtitle =>
      'Mati. Audio ditranskrip pada volume aslinya.';

  @override
  String get settingsScreenDedup => 'Hapus suara ganda';

  @override
  String get settingsScreenDedupOnlineSubtitle =>
      'Aktif di mode Rapat Online: duplikasi MIC/SPK dibuang.';

  @override
  String get settingsScreenDedupOtherSubtitle =>
      'Hanya berlaku di mode Rapat Online.';

  @override
  String get settingsScreenDedupInfo =>
      'Membandingkan kemiripan audio dari mikrofon dan pengeras suara, lalu menghapus yang terdengar dua kali.';

  @override
  String get settingsScreenAutoStop => 'Berhenti sendiri saat sunyi';

  @override
  String settingsScreenAutoStopOnSubtitle(int minutes) {
    return 'Berhenti setelah $minutes menit tanpa suara.';
  }

  @override
  String get settingsScreenAutoStopOffSubtitle =>
      'Rekaman berjalan sampai Anda menghentikannya sendiri.';

  @override
  String get settingsScreenAutoStopDelay => 'Lama sunyi sebelum berhenti';

  @override
  String settingsScreenMinutes(int minutes) {
    return '$minutes menit';
  }

  @override
  String get settingsScreenOutputStorage => 'Output & Penyimpanan';

  @override
  String get settingsScreenOutputFolder => 'Folder output';

  @override
  String get settingsScreenPickOutputFolder => 'Pilih folder output';

  @override
  String get settingsScreenDefaultExportFormat => 'Format ekspor default';

  @override
  String get settingsScreenDefaultExportFormatSubtitle =>
      'Format yang sudah tercentang saat dialog Ekspor dibuka.';

  @override
  String get settingsScreenDiagnostics => 'Diagnostik';

  @override
  String get settingsScreenDiagnosticsSubtitle =>
      'Periksa folder, model, mikrofon dan ruang disk. Semuanya lokal.';

  @override
  String get settingsScreenRerunSetup => 'Jalankan Ulang Penyiapan';

  @override
  String get settingsScreenRerunSetupSubtitle =>
      'Pilih ulang mikrofon, pengeras suara dan model, lalu uji suara.';

  @override
  String get settingsScreenPrivacyReport => 'Laporan Privasi';

  @override
  String get settingsScreenPrivacyReportSubtitle =>
      'Apa yang pernah keluar dari komputer ini.';

  @override
  String get settingsScreenCapabilities => 'Apa Jalan di Mana';

  @override
  String get settingsScreenCapabilitiesSubtitle =>
      'Setiap kemampuan, tempatnya berjalan, dan statusnya sekarang.';

  @override
  String get settingsScreenUsageDashboard => 'Dasbor Penggunaan';

  @override
  String get settingsScreenUsageDashboardSubtitle =>
      'Berapa lama Anda merekam, per minggu.';

  @override
  String get settingsScreenCheckUpdate => 'Cek Pembaruan';

  @override
  String settingsScreenCheckUpdateSubtitle(String version) {
    return 'Versi saat ini $version. Memeriksa pembaruan menghubungi GitHub dan dicatat di Laporan Privasi.';
  }

  @override
  String get settingsScreenAboutTrareon => 'Tentang Trareon';

  @override
  String get settingsScreenTagline => 'Transkripsi offline, privasi terjamin.';

  @override
  String get settingsScreenUpdateAvailableTitle => 'Pembaruan Tersedia';

  @override
  String settingsScreenUpdateAvailableBody(String latest, String current) {
    return 'Versi $latest tersedia (saat ini $current).';
  }

  @override
  String get settingsScreenLater => 'Nanti';

  @override
  String get settingsScreenViewRelease => 'Lihat Rilis';

  @override
  String get settingsScreenUpToDate => 'Sudah versi terbaru.';

  @override
  String settingsScreenUpdateCheckFailed(String error) {
    return 'Gagal memeriksa pembaruan: $error';
  }

  @override
  String settingsScreenBrowserFailed(String url) {
    return 'Tidak bisa membuka peramban. Buka $url secara manual.';
  }

  @override
  String get settingsScreenBuiltWith => 'Dibangun dengan Flutter + Rust';

  @override
  String settingsScreenUpgradeOffer(String model) {
    return 'Komputer ini sanggup menjalankan $model untuk akurasi lebih baik.';
  }

  @override
  String get settingsScreenUpgradeAccuracy => 'Tingkatkan akurasi';

  @override
  String get settingsScreenNotNow => 'Nanti saja';

  @override
  String get summaryPanelSaved => 'Ringkasan tersimpan.';

  @override
  String summaryPanelShareFailed(String error) {
    return 'Gagal menyiapkan ringkasan untuk dibagikan: $error';
  }

  @override
  String get summaryPanelTitle => 'Ringkasan AI';

  @override
  String get summaryPanelUnsaved => 'belum disimpan';

  @override
  String get summaryPanelDisabledNotice =>
      'Ringkasan AI mati. Fitur ini satu-satunya yang memakai jaringan, nyalakan di Pengaturan, Ringkasan AI, bila ingin memakainya.';

  @override
  String get summaryPanelTemplateLabel => 'Template';

  @override
  String get summaryPanelCustomTemplateHelper => 'Template buatan sendiri';

  @override
  String get summaryPanelManageTemplates => 'Kelola template ringkasan';

  @override
  String get summaryPanelRegenerate => 'Buat Ulang';

  @override
  String get summaryPanelGenerate => 'Buat Ringkasan';

  @override
  String get summaryPanelPlaceholder =>
      'Ringkasan akan muncul di sini. Anda bisa menyuntingnya sebelum menyimpan.';

  @override
  String summaryPanelDroppedCitations(int count) {
    return '$count rujukan dibuang karena tidak cocok dengan transkrip. Periksa ringkasan ini lebih teliti.';
  }

  @override
  String get summaryPanelViewCitations => 'Lihat rujukan';

  @override
  String get summaryPanelEdit => 'Sunting';

  @override
  String get summaryPanelCopied => 'Ringkasan disalin.';

  @override
  String get summaryPanelCopy => 'Salin';

  @override
  String get summaryPanelShare => 'Bagikan';

  @override
  String get summaryPanelPersonalNotes => 'Catatan Pribadi';

  @override
  String get summaryPanelEnhance => 'Enhance';

  @override
  String get summaryPanelNoNotes =>
      'Tidak ada catatan yang ditulis selama rapat. Enhance tetap bisa dipakai, hasilnya akan berupa ringkasan dari transkrip saja.';

  @override
  String get summaryPanelMergedResult => 'Hasil Gabungan (AI)';

  @override
  String summaryPanelPlayCitation(int segment, String time) {
    return 'Putar segmen $segment pada $time';
  }

  @override
  String get summaryTemplateEditorManagerTitle => 'Template Ringkasan';

  @override
  String get summaryTemplateEditorManagerIntro =>
      'Buat template sendiri dengan judul bagian dan instruksi Anda. Disimpan di komputer ini.';

  @override
  String get summaryTemplateEditorEmpty => 'Belum ada template buatan sendiri.';

  @override
  String get summaryTemplateEditorNoHeadings => 'Tanpa judul bagian';

  @override
  String summaryTemplateEditorEditTooltip(String name) {
    return 'Ubah $name';
  }

  @override
  String summaryTemplateEditorDuplicateTooltip(String name) {
    return 'Duplikat $name';
  }

  @override
  String summaryTemplateEditorDeleteTooltip(String name) {
    return 'Hapus $name';
  }

  @override
  String summaryTemplateEditorCopyName(String name) {
    return '$name (salinan)';
  }

  @override
  String get summaryTemplateEditorStartFromBuiltin =>
      'Mulai dari template bawaan';

  @override
  String summaryTemplateEditorDuplicateBuiltinTooltip(String name) {
    return 'Duplikat \"$name\" jadi template sendiri';
  }

  @override
  String summaryTemplateEditorMineName(String name) {
    return '$name (saya)';
  }

  @override
  String get summaryTemplateEditorBlank => 'Kosong';

  @override
  String get summaryTemplateEditorBlankTooltip => 'Buat template dari nol';

  @override
  String get summaryTemplateEditorDefaultName => 'Template saya';

  @override
  String get summaryTemplateEditorClose => 'Tutup';

  @override
  String get summaryTemplateEditorEditTitle => 'Ubah template';

  @override
  String get summaryTemplateEditorNameLabel => 'Nama template';

  @override
  String get summaryTemplateEditorHeadingsLabel =>
      'Judul bagian (satu per baris)';

  @override
  String get summaryTemplateEditorHeadingsHint =>
      'Ringkasan\nKeputusan\nRisiko';

  @override
  String get summaryTemplateEditorInstructionsLabel => 'Instruksi tambahan';

  @override
  String get summaryTemplateEditorInstructionsHint =>
      'mis. Fokus pada risiko anggaran dan sebutkan angka persis seperti di transkrip.';

  @override
  String get summaryTemplateEditorHeadingsNote =>
      'Judul bagian dikirim sebagai daftar berurutan, jadi hasilnya konsisten dan bisa dipakai untuk mengisi form notulen.';

  @override
  String get captureHealthViewSourceSystem => 'Audio sistem';

  @override
  String get captureHealthViewSourceMic => 'Mikrofon';

  @override
  String captureHealthViewWentSilent(String sources) {
    return '$sources senyap';
  }

  @override
  String get captureHealthViewConfirmed => 'Rekaman terkonfirmasi';

  @override
  String captureHealthViewWaiting(String sources) {
    return 'Menunggu suara dari $sources';
  }

  @override
  String get captureHealthViewConfirmedTooltip =>
      'Setiap sumber yang diminta sudah menghasilkan suara di atas ambang derau.';

  @override
  String get captureHealthViewUnconfirmedTooltip =>
      'Belum ada suara nyata dari semua sumber yang diminta.';

  @override
  String get captureHealthViewAudioIssue => 'Masalah audio belum teratasi';

  @override
  String captureHealthViewAudioIssueTooltip(String label) {
    return '$label. Mikrofon atau audio sistem belum mengirim suara; lihat pemberitahuan terakhir atau periksa Pengaturan Sistem.';
  }

  @override
  String captureHealthViewSummary(String duration, int segments) {
    return 'Durasi $duration · $segments segmen transkrip';
  }

  @override
  String get captureHealthViewNoSources =>
      'Tidak ada sumber audio yang diminta untuk sesi ini.';

  @override
  String captureHealthViewChannelOk(
    String source,
    String duration,
    String percent,
  ) {
    return '$source: $duration terekam, $percent% senyap';
  }

  @override
  String captureHealthViewChannelSilent(String source, String duration) {
    return '$source: tidak ada suara sama sekali ($duration terekam)';
  }

  @override
  String get captureHealthViewSessionDone => 'Sesi selesai';

  @override
  String get captureHealthViewSessionDoneIssues => 'Sesi selesai, ada masalah';

  @override
  String get captureHealthViewNotSaved => 'Transkrip belum tersimpan.';

  @override
  String get captureHealthViewClose => 'Tutup';

  @override
  String get notulenSettingsSectionPickKopTitle =>
      'Pilih gambar kop surat (PNG)';

  @override
  String get notulenSettingsSectionKopMustBePng =>
      'Kop surat harus berupa berkas PNG.';

  @override
  String notulenSettingsSectionReadFailed(String error) {
    return 'Tidak bisa membaca berkas: $error';
  }

  @override
  String get notulenSettingsSectionTitle => 'Notulen Resmi';

  @override
  String get notulenSettingsSectionIntro =>
      'Isian yang sama di setiap rapat. Dipakai otomatis saat Anda membuat Notulen Rapat.';

  @override
  String get notulenSettingsSectionUnitLabel => 'Instansi / Unit Kerja';

  @override
  String get notulenSettingsSectionUnitHint =>
      'mis. Direktorat Jenderal Anggaran';

  @override
  String get notulenSettingsSectionPlaceLabel =>
      'Tempat/Media yang biasa dipakai';

  @override
  String get notulenSettingsSectionPlaceHint => 'mis. Ruang Rapat Lt. 5 / Zoom';

  @override
  String get notulenSettingsSectionNotulisLabel => 'Nama notulis';

  @override
  String get notulenSettingsSectionNotulisHint =>
      'Nama Anda, untuk blok tanda tangan';

  @override
  String get notulenSettingsSectionKop => 'Kop surat';

  @override
  String get notulenSettingsSectionKopEmpty =>
      'Belum dipilih. Tanpa gambar, kop ditulis sebagai teks dari nama instansi di atas.';

  @override
  String get notulenSettingsSectionRemoveKop => 'Hapus kop surat';

  @override
  String get notulenSettingsSectionPickKop => 'Pilih gambar kop surat';

  @override
  String get platformChromeMinimize => 'Perkecil';

  @override
  String get platformChromeMaximize => 'Perbesar';

  @override
  String get platformChromeClose => 'Tutup';

  @override
  String get platformChromeMenuSettings => 'Pengaturan…';

  @override
  String get platformChromeMenuFile => 'Berkas';

  @override
  String get platformChromeMenuNewSession => 'Sesi Baru';

  @override
  String get platformChromeMenuToggleRecording => 'Mulai atau Berhenti Merekam';

  @override
  String get platformChromeMenuView => 'Tampilan';

  @override
  String get platformChromeMenuSearch => 'Cari di Riwayat Sesi';

  @override
  String get platformChromeMenuHideSidebar => 'Sembunyikan Sidebar';

  @override
  String get platformChromeMenuWindow => 'Jendela';

  @override
  String get platformChromeMenuHelp => 'Bantuan';

  @override
  String get platformChromeMenuShortcuts => 'Pintasan Keyboard';

  @override
  String get modelLabelsLight => 'Ringan';

  @override
  String get modelLabelsFast => 'Cepat';

  @override
  String get modelLabelsFastExperimental => 'Cepat-Eksperimental';

  @override
  String get modelLabelsMedium => 'Sedang';

  @override
  String get modelLabelsHigh => 'Tinggi';

  @override
  String get modelLabelsAccurate => 'Akurat';

  @override
  String get modelLabelsAccurateRecommended => 'Akurat (disarankan)';

  @override
  String get modelLabelsAccurateExperimental => 'Akurat-Eksperimental';

  @override
  String get modelLabelsInstalled => 'Model terpasang';

  @override
  String setupOverlayNeedsAttention(String names) {
    return 'Perlu diperiksa: $names.';
  }

  @override
  String get setupOverlayViewDiagnostics => 'Lihat diagnostik';

  @override
  String get setupOverlayClose => 'Tutup';

  @override
  String get setupOverlayNotReady => 'Trareon belum siap merekam';

  @override
  String get setupOverlayChecking => 'Memeriksa…';

  @override
  String get setupOverlayCheckAgain => 'Periksa Ulang';

  @override
  String get setupOverlayContinueAnyway => 'Lanjutkan saja';

  @override
  String sessionArchiveServiceOpenFailed(String error) {
    return 'Gagal membuka arsip: tidak terbaca atau rusak ($error).';
  }

  @override
  String get sessionArchiveServiceEmpty =>
      'Arsip ini kosong atau bukan arsip sesi Trareon.';

  @override
  String get sessionArchiveServiceNoTranscript =>
      'File ini bukan arsip sesi Trareon yang valid: tidak ada transkrip di dalamnya.';

  @override
  String get completionBannerExportIncomplete =>
      'Transkrip terisi sendiri; ekspor sekarang akan belum lengkap.';

  @override
  String get completionBannerIncomplete => 'Belum selesai';

  @override
  String completionBannerIncompletePercent(int percent) {
    return 'Belum selesai · $percent%';
  }

  @override
  String get completionBannerIncompleteTooltip =>
      'Masih ada audio yang belum ditranskripsi. Transkrip akan dilengkapi otomatis di latar belakang.';

  @override
  String get streamToggleMic => 'Mikrofon';

  @override
  String get streamToggleSpeaker => 'Suara sistem';

  @override
  String get streamToggleStateOn => 'aktif';

  @override
  String get streamToggleStateOff => 'nonaktif';

  @override
  String streamToggleMicAnnouncement(String state) {
    return 'Mikrofon $state';
  }

  @override
  String streamToggleSpeakerAnnouncement(String state) {
    return 'Pengeras suara $state';
  }

  @override
  String get streamToggleOn => 'HIDUP';

  @override
  String get streamToggleOff => 'MATI';

  @override
  String get appFieldSearchPlaceholder => 'Cari…';

  @override
  String get appFieldClearSearch => 'Bersihkan pencarian';

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

  @override
  String setupWizardScreenStepOf(int step, int total) {
    return 'Langkah $step dari $total';
  }

  @override
  String get setupWizardScreenBack => 'Kembali';

  @override
  String get setupWizardScreenClose => 'Tutup';

  @override
  String get setupWizardScreenFinish => 'Selesai';

  @override
  String get setupWizardScreenNext => 'Lanjut';

  @override
  String get setupWizardScreenSpecTitle => '1. Deteksi Spesifikasi';

  @override
  String get setupWizardScreenSpecReady =>
      'Sistem Anda siap! Model direkomendasikan berdasarkan spesifikasi.';

  @override
  String get setupWizardScreenSpecChecking => 'Memeriksa sistem…';

  @override
  String get setupWizardScreenSpecCpu => 'Inti Prosesor';

  @override
  String setupWizardScreenSpecCores(String cores) {
    return '$cores core';
  }

  @override
  String get setupWizardScreenSpecRamEstimate => 'RAM (perkiraan)';

  @override
  String get setupWizardScreenSpecRam => 'RAM';

  @override
  String get setupWizardScreenSpecUnknown => 'tidak diketahui';

  @override
  String get setupWizardScreenSpecSuggestedModel => 'Model Disarankan';

  @override
  String get setupWizardScreenModelFastLabel => '⚡ Cepat';

  @override
  String get setupWizardScreenModelFastDescription =>
      '142 MB · termasuk di aplikasi\nTranskrip muncul cepat, cocok untuk komputer ringan dan catatan sehari-hari.';

  @override
  String get setupWizardScreenModelFastExperimentalLabel =>
      '🧪 Cepat-Eksperimental';

  @override
  String get setupWizardScreenModelFastExperimentalDescription =>
      '631 MB · unduh sekali\nSeakurat model \"Akurat\" tapi secepat model \"Cepat\" (Qwen3-ASR). Baru, belum teruji selengkap model lain.';

  @override
  String get setupWizardScreenModelBalancedLabel => '⚖️ Seimbang';

  @override
  String get setupWizardScreenModelBalancedDescription =>
      '488 MB · unduh sekali\nLebih teliti dari model cepat, tanpa seberat model akurat. Pilihan tengah untuk komputer dengan RAM sedang.';

  @override
  String get setupWizardScreenModelAccurateLabel => '🎯 Akurat';

  @override
  String get setupWizardScreenModelAccurateDescription =>
      '548 MB · unduh sekali\nLebih teliti untuk rapat dan wawancara, tapi jauh lebih lambat di komputer tanpa GPU.';

  @override
  String get setupWizardScreenModelAccurateExperimentalLabel =>
      '🧪 Akurat-Eksperimental';

  @override
  String get setupWizardScreenModelAccurateExperimentalDescription =>
      '1.5 GB · unduh sekali\nModel paling teliti yang tersedia (Qwen3-ASR). Baru, belum teruji selengkap model lain.';

  @override
  String get setupWizardScreenModelTitle => '2. Pilih Model';

  @override
  String get setupWizardScreenModelDescription =>
      'Pilih model Speech-to-Text yang sesuai.';

  @override
  String get setupWizardScreenModelAutoLabel => '🤖 Otomatis (disarankan)';

  @override
  String get setupWizardScreenModelAutoDescription =>
      'Dipilihkan otomatis sesuai spesifikasi komputer ini.';

  @override
  String get setupWizardScreenLoopbackVirtualDriverFound =>
      'Driver audio virtual terdeteksi';

  @override
  String get setupWizardScreenLoopbackSystemAudioReady =>
      'Suara sistem siap direkam';

  @override
  String get setupWizardScreenLoopbackVirtualDriverMissing =>
      'Driver audio virtual belum terpasang';

  @override
  String get setupWizardScreenLoopbackNoOutputDevice =>
      'Belum ada perangkat keluaran yang bisa direkam';

  @override
  String get setupWizardScreenLoopbackReadyMacos =>
      'Suara dari Zoom/Meet bisa direkam lewat perangkat virtual di atas.';

  @override
  String get setupWizardScreenLoopbackReadyLinux =>
      'Trareon merekam suara sistem lewat monitor sink PipeWire/PulseAudio , tidak perlu memasang apa pun.';

  @override
  String get setupWizardScreenLoopbackReadyWindows =>
      'Trareon merekam suara sistem lewat WASAPI loopback, tidak perlu memasang apa pun.';

  @override
  String get setupWizardScreenLoopbackMissingMacos =>
      'Untuk merekam suara dari Zoom/Meet di macOS, pasang BlackHole 2ch.';

  @override
  String get setupWizardScreenLoopbackMissingLinux =>
      'Pilih perangkat keluaran di atas. Jika daftarnya kosong, pastikan PipeWire atau PulseAudio berjalan.';

  @override
  String get setupWizardScreenLoopbackMissingWindows =>
      'Pilih perangkat keluaran di atas. Jika daftarnya kosong, pastikan perangkat pemutar suara aktif di Windows.';

  @override
  String get setupWizardScreenLoopbackGuideMacos =>
      '1. brew install blackhole-2ch\n2. Buka Audio MIDI Setup\n3. Buat Multi-Output Device\n4. Centang pengeras suara Mac Anda + BlackHole 2ch';

  @override
  String get setupWizardScreenLoopbackGuideLinux =>
      '1. Pastikan PipeWire atau PulseAudio berjalan\n2. Jalankan: pactl list short sources\n3. Pilih sumber yang berakhiran .monitor di daftar di atas';

  @override
  String get setupWizardScreenLoopbackGuideWindows =>
      '1. Buka Pengaturan Suara Windows\n2. Pastikan ada perangkat keluaran yang aktif\n3. Pilih perangkat itu di daftar di atas';

  @override
  String get setupWizardScreenAudioTitle => '3. Siapkan Audio';

  @override
  String get setupWizardScreenAudioDescription =>
      'Pilih perangkat mikrofon dan pengeras suara.';

  @override
  String get setupWizardScreenMicLabel => 'Mikrofon (Input)';

  @override
  String get setupWizardScreenSpeakerLabel =>
      'Pengeras Suara / Suara Sistem (Output)';

  @override
  String get setupWizardScreenGuide => 'Panduan';

  @override
  String get setupWizardScreenSystemDefault => 'Bawaan sistem';

  @override
  String get setupWizardScreenRemediationMacos =>
      'Buka Pengaturan Sistem → Suara, naikkan volume, dan pastikan perangkat keluaran yang benar terpilih.';

  @override
  String get setupWizardScreenRemediationLinux =>
      'Periksa volume di pavucontrol atau pengaturan suara desktop Anda, lalu pastikan perangkat keluaran yang benar terpilih.';

  @override
  String get setupWizardScreenRemediationWindows =>
      'Buka Pengaturan Suara Windows, naikkan volume, dan pastikan perangkat keluaran yang benar terpilih.';

  @override
  String get setupWizardScreenToneTitle => '4. Uji Suara';

  @override
  String get setupWizardScreenToneDescription =>
      'Putar nada 440 Hz untuk memastikan pengeras suara berfungsi.';

  @override
  String get setupWizardScreenToneQuestion => 'Apakah Anda mendengar nadanya?';

  @override
  String get setupWizardScreenToneHeard => 'Ya, terdengar';

  @override
  String get setupWizardScreenToneNotHeard => 'Tidak terdengar';

  @override
  String get setupWizardScreenToneWorksTitle => 'Pengeras suara berfungsi';

  @override
  String get setupWizardScreenToneWorksBody =>
      'Tes mikrofon akan aktif saat sesi dimulai.';

  @override
  String get setupWizardScreenToneNotHeardTitle => 'Nada tidak terdengar';

  @override
  String get setupWizardScreenTonePlaybackFailed => 'Nada gagal diputar';

  @override
  String get setupWizardScreenTonePlaying => 'Memutar…';

  @override
  String get setupWizardScreenTonePlay => 'Putar Nada Uji';

  @override
  String get setupWizardScreenTonePlayAgain => 'Putar Ulang';

  @override
  String get srikandiExportDialogSifatSangatSegera => 'Sangat Segera (24 jam)';

  @override
  String get srikandiExportDialogSifatSegera => 'Segera (2x24 jam)';

  @override
  String get srikandiExportDialogSifatBiasa => 'Biasa';

  @override
  String get srikandiExportDialogKlasifikasiSangatRahasia => 'Sangat Rahasia';

  @override
  String get srikandiExportDialogKlasifikasiRahasia => 'Rahasia';

  @override
  String get srikandiExportDialogKlasifikasiTerbatas => 'Terbatas';

  @override
  String get srikandiExportDialogKlasifikasiBiasa => 'Biasa';

  @override
  String get srikandiExportDialogTingkatAsli => 'Asli';

  @override
  String get srikandiExportDialogTingkatSalinan => 'Salinan';

  @override
  String get srikandiExportDialogTingkatTembusan => 'Tembusan';

  @override
  String get srikandiExportDialogTingkatPertinggal => 'Pertinggal';

  @override
  String srikandiExportDialogPrefillFailed(String error) {
    return 'Gagal menyiapkan metadata: $error';
  }

  @override
  String get srikandiExportDialogMetadataIncomplete =>
      'Metadata belum lengkap. Periksa temuan \"Wajib\" di atas.';

  @override
  String get srikandiExportDialogPickFolder =>
      'Pilih folder untuk ekspor SRIKANDI';

  @override
  String srikandiExportDialogExported(int count, String folder) {
    return '$count berkas siap-SRIKANDI tersimpan di $folder';
  }

  @override
  String srikandiExportDialogExportFailed(String error) {
    return 'Gagal mengekspor: $error';
  }

  @override
  String get srikandiExportDialogTitle => 'Ekspor siap-SRIKANDI';

  @override
  String get srikandiExportDialogExporting => 'Mengekspor…';

  @override
  String get srikandiExportDialogExportButton => 'Ekspor (4 berkas)';

  @override
  String get srikandiExportDialogIntro =>
      'Berkas yang dihasilkan hanya disiapkan di perangkat ini. Unggahan ke SRIKANDI tetap dilakukan manual lewat antarmuka instansi (lihat docs/SRIKANDI-EXPORT.md).';

  @override
  String get srikandiExportDialogFieldNomor => 'Nomor naskah';

  @override
  String get srikandiExportDialogFieldTanggal => 'Tanggal';

  @override
  String get srikandiExportDialogFieldJenisNaskah => 'Jenis naskah';

  @override
  String get srikandiExportDialogFieldPerihal => 'Perihal';

  @override
  String get srikandiExportDialogFieldKodeKlasifikasiArsip =>
      'Kode klasifikasi arsip';

  @override
  String get srikandiExportDialogFieldUnitPengolah => 'Unit pengolah';

  @override
  String get srikandiExportDialogFieldPenandatanganNama => 'Nama penandatangan';

  @override
  String get srikandiExportDialogFieldPenandatanganJabatan =>
      'Jabatan penandatangan';

  @override
  String get srikandiExportDialogFieldJumlahLampiran => 'Jumlah lampiran';

  @override
  String get srikandiExportDialogFieldCatatan => 'Catatan';

  @override
  String get srikandiExportDialogNomorHint =>
      'Minta ke Tata Usaha unit, mis. B-125/TU.01/KP.03/10/2026';

  @override
  String get srikandiExportDialogKodeHint =>
      'Minta ke arsiparis unit, mis. UM.03.01';

  @override
  String get srikandiExportDialogGroupSifat => 'Sifat';

  @override
  String get srikandiExportDialogGroupKlasifikasi => 'Klasifikasi keamanan';

  @override
  String get srikandiExportDialogGroupTingkat => 'Tingkat perkembangan';

  @override
  String get srikandiExportDialogGroupChecks => 'Pemeriksaan metadata';

  @override
  String get srikandiExportDialogWajib => 'Wajib';

  @override
  String get srikandiExportDialogSaran => 'Saran';

  @override
  String get sessionSidebarGroupToday => 'Hari ini';

  @override
  String get sessionSidebarGroupYesterday => 'Kemarin';

  @override
  String get sessionSidebarGroupLast7Days => '7 hari terakhir';

  @override
  String get sessionSidebarGroupOlder => 'Lebih lama';

  @override
  String get sessionSidebarNewSession => 'Sesi Baru';

  @override
  String get sessionSidebarSearchPlaceholder => 'Cari sesi…';

  @override
  String get sessionSidebarSearchSemanticLabel => 'Cari di riwayat sesi';

  @override
  String get sessionSidebarAllTags => 'Semua';

  @override
  String get sessionSidebarImportFile => 'Impor berkas';

  @override
  String get sessionSidebarAskArchive => 'Tanya arsip rapat';

  @override
  String get sessionSidebarManageLibrary => 'Kelola perpustakaan';

  @override
  String get sessionSidebarSettings => 'Pengaturan';

  @override
  String sessionSidebarHideSidebar(String shortcut) {
    return 'Sembunyikan sidebar ($shortcut)';
  }

  @override
  String sessionSidebarShowSidebar(String shortcut) {
    return 'Tampilkan sidebar ($shortcut)';
  }

  @override
  String get sessionSidebarNewSessionTooltip => 'Sesi baru';

  @override
  String get sessionSidebarHistoryTooltip => 'Riwayat sesi';

  @override
  String get sessionSidebarRecording => 'Sedang merekam';

  @override
  String sessionSidebarSegments(int count) {
    return '$count segmen';
  }

  @override
  String sessionSidebarFinishing(String source) {
    return 'Menyelesaikan $source';
  }

  @override
  String get sessionSidebarRetranscribeQueued =>
      'Menunggu antrean untuk ditranskrip ulang.';

  @override
  String sessionSidebarRetranscribingStage(String stage) {
    return 'Ditranskrip ulang: $stage';
  }

  @override
  String get sessionSidebarRetranscribing => 'Ditranskrip ulang';

  @override
  String get sessionSidebarHasSummary => 'Ada ringkasan';

  @override
  String get sessionSidebarFolderUnreadable => 'Folder sesi tidak terbaca';

  @override
  String get sessionSidebarNoMatchTitle => 'Tidak ada yang cocok';

  @override
  String get sessionSidebarNoMatchMessage =>
      'Coba kata kunci lain atau lepaskan filter tag.';

  @override
  String get sessionSidebarEmptyTitle => 'Belum ada sesi';

  @override
  String get sessionSidebarEmptyMessage =>
      'Rapat yang sudah direkam muncul di sini.';

  @override
  String get engineAssetsSectionVadTitle => 'Gerbang suara neural (Silero)';

  @override
  String get engineAssetsSectionVadSubtitle =>
      'Memutuskan bagian mana dari rekaman yang berisi suara manusia. Tanpa ini Trareon memakai detektor energi sederhana, yang kadang meloloskan derau ruangan, dan Whisper menjawab derau dengan kalimat karangan. 0,9 MB.';

  @override
  String get engineAssetsSectionSegmentationTitle =>
      'Segmentasi pembicara (pyannote 3.0)';

  @override
  String get engineAssetsSectionSegmentationSubtitle =>
      'Menentukan siapa berbicara kapan. 6 MB.';

  @override
  String get engineAssetsSectionEmbeddingTitle =>
      'Sidik suara pembicara (CAM++)';

  @override
  String get engineAssetsSectionEmbeddingSubtitle =>
      'Mengenali suara yang sama di bagian rekaman yang berbeda. 28 MB.';

  @override
  String engineAssetsSectionInstalledToast(String name) {
    return '$name terpasang.';
  }

  @override
  String get engineAssetsSectionTitle => 'Mesin pengenal suara';

  @override
  String get engineAssetsSectionDiarizationLabel =>
      'Pemisahan pembicara akurat';

  @override
  String engineAssetsSectionDownloadFailed(String error) {
    return 'Unduhan gagal: $error';
  }

  @override
  String get engineAssetsSectionDiarizationOff =>
      'Mati. Memakai pengelompokan akustik sederhana, yang cukup untuk rapat dua sumber (mikrofon = Anda, sistem = peserta) tetapi sering memecah satu suara menjadi beberapa pembicara pada berkas impor.';

  @override
  String get engineAssetsSectionDiarizationIncomplete =>
      'Aktif, tetapi modelnya belum lengkap diunduh. Sementara ini masih memakai pengelompokan akustik sederhana.';

  @override
  String get engineAssetsSectionDiarizationReady =>
      'Segmentasi pyannote + sidik suara CAM++, seluruhnya di komputer ini. Dipakai pada impor berkas, transkrip ulang, dan penyelesaian setelah Stop (bukan pada pratinjau langsung).';

  @override
  String engineAssetsSectionDownloadingPercent(String percent) {
    return 'Mengunduh… $percent%';
  }

  @override
  String get engineAssetsSectionChecking => 'Memeriksa…';

  @override
  String engineAssetsSectionInstalled(String description) {
    return 'Terpasang. $description';
  }

  @override
  String engineAssetsSectionNotDownloaded(String description) {
    return 'Belum diunduh. $description';
  }

  @override
  String get engineAssetsSectionDownloading => 'Mengunduh…';

  @override
  String get engineAssetsSectionDownload => 'Unduh';

  @override
  String get privacyReportScreenTitle => 'Laporan Privasi';

  @override
  String privacyReportScreenNetworkCalls(int count) {
    return '$count panggilan jaringan sejak aplikasi dibuka';
  }

  @override
  String privacyReportScreenSessionRunning(String duration) {
    return 'Sesi berjalan selama $duration';
  }

  @override
  String get privacyReportScreenNoActivity =>
      'Belum ada aktivitas jaringan tercatat.';

  @override
  String get privacyReportScreenHistory => 'Riwayat aktivitas:';

  @override
  String get privacyReportScreenExplanation =>
      'Trareon Transcribe tidak melakukan panggilan jaringan apa pun selama transkripsi berlangsung, baik saat merekam langsung maupun saat mengimpor berkas. Audio tidak pernah keluar dari perangkat ini.\n\nAda empat aktivitas jaringan yang sah, dan semuanya Anda mulai sendiri:\n1. Unduh model whisper: dari huggingface.co, hanya saat Anda memilih model yang belum ada di perangkat.\n2. Ringkasan AI: mengirim teks transkrip (bukan audio) ke endpoint yang Anda atur sendiri. Fitur ini mati secara bawaan dan defaultnya menunjuk ke Ollama di komputer ini (localhost), jadi bawaannya pun tidak keluar dari perangkat.\n3. Cek pembaruan: mengambil satu berkas versi dari raw.githubusercontent.com saat Anda menekan \"Cek Pembaruan\". Tidak ada yang diunduh atau dijalankan secara otomatis.\n4. \"Lihat Rilis\": membuka halaman rilis di peramban Anda.\n\nKeempatnya tercatat di riwayat di atas, lengkap dengan tujuannya. Setiap titik di kode yang bisa memulai salah satunya wajib mencatat dirinya sendiri lebih dulu; hal itu diuji otomatis (test/privacy_proof_test.dart).';

  @override
  String privacyReportScreenDurationHours(int hours, int minutes) {
    return '${hours}j ${minutes}m';
  }

  @override
  String privacyReportScreenDurationMinutes(int minutes, int seconds) {
    return '${minutes}m ${seconds}d';
  }

  @override
  String privacyReportScreenDurationSeconds(int seconds) {
    return '${seconds}d';
  }

  @override
  String bookmarkBarAddTooltip(String shortcut) {
    return 'Tandai poin penting di posisi sekarang ($shortcut)';
  }

  @override
  String get recoveryDialogTitle => 'Pulihkan sesi yang terhenti';

  @override
  String recoveryDialogIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesi berhenti tanpa disimpan. Berikut isinya:',
      one: 'Satu sesi berhenti tanpa disimpan. Berikut isinya:',
    );
    return '$_temp0';
  }

  @override
  String get recoveryDialogLater => 'Nanti saja';

  @override
  String recoveryDialogSegments(int count) {
    return '$count segmen transkrip';
  }

  @override
  String get recoveryDialogEmptyTranscript => 'transkrip kosong';

  @override
  String recoveryDialogMic(String duration) {
    return 'mikrofon $duration';
  }

  @override
  String recoveryDialogSystemAudio(String duration) {
    return 'audio sistem $duration';
  }

  @override
  String get recoveryDialogNoAudio => 'tanpa rekaman audio';

  @override
  String recoveryDialogAudio(String sources) {
    return 'audio: $sources';
  }

  @override
  String get recoveryDialogDiscard => 'Hapus';

  @override
  String get recoveryDialogRecoverTooltip =>
      'Lanjutkan sesi ini dan rekam ke berkas yang sama';

  @override
  String get recoveryDialogBusyTooltip =>
      'Hentikan sesi yang sedang berjalan dulu';

  @override
  String get recoveryDialogRecover => 'Pulihkan';

  @override
  String get calendarInviteImportPickTitle => 'Impor undangan rapat (.ics)';

  @override
  String calendarInviteImportReadFailed(String error) {
    return 'Gagal membaca undangan: $error';
  }

  @override
  String get calendarInviteImportNoEvents =>
      'Tidak ada acara yang terbaca dari berkas itu.';

  @override
  String get calendarInviteImportConfirmTitle => 'Isi dari undangan ini?';

  @override
  String get calendarInviteImportNoTitle => 'Undangan ini tidak punya judul.';

  @override
  String calendarInviteImportWillBeTitle(String summary) {
    return '\"$summary\" akan menjadi judul sesi.';
  }

  @override
  String get calendarInviteImportNo => 'Tidak';

  @override
  String get calendarInviteImportFillTitle => 'Isi judul';

  @override
  String calendarInviteImportAttendees(String attendees) {
    return 'Peserta pada undangan: $attendees';
  }

  @override
  String get archiveChatModelNotFound => 'Tidak ditemukan di arsip rapat.';

  @override
  String get archiveChatModelNeedsEndpoint =>
      'Jawaban otomatis memerlukan endpoint ringkasan yang sudah diatur di Pengaturan → Ringkasan AI. Pencarian arsip tetap bisa dipakai tanpa itu.';

  @override
  String updateCheckerBadStatus(int code) {
    return 'Server merespon dengan kode $code. Coba lagi nanti.';
  }

  @override
  String get updateCheckerEmptyVersion => 'File versi kosong. Coba lagi nanti.';

  @override
  String get updateCheckerNoConnection =>
      'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';

  @override
  String get updateCheckerBadResponse =>
      'Server tidak merespons dengan benar. Coba lagi nanti.';

  @override
  String get updateCheckerTimeout =>
      'Permintaan timeout. Periksa koneksi internet Anda dan coba lagi.';

  @override
  String get updateCheckerInvalidData =>
      'Data yang diterima tidak valid. Coba lagi nanti.';

  @override
  String onboardingModelDownloadFailed(String error) {
    return 'Gagal mengunduh: $error';
  }

  @override
  String shareFileUnsupported(String name) {
    return 'Berbagi file tidak didukung di platform ini. Path disalin: $name';
  }

  @override
  String get preflightServiceTitleLibraryPath => 'Folder penyimpanan';

  @override
  String get preflightServicePurposeLibraryPath =>
      'Tempat rekaman dan transkrip disimpan.';

  @override
  String get preflightServiceTitleModel => 'Model transkripsi';

  @override
  String get preflightServicePurposeModel =>
      'Berkas model yang dipakai untuk mengubah suara jadi teks.';

  @override
  String get preflightServiceTitleConfigDir => 'Folder pengaturan';

  @override
  String get preflightServicePurposeConfigDir =>
      'Tempat pengaturan aplikasi disimpan.';

  @override
  String get preflightServiceTitleAudioInput => 'Perangkat mikrofon';

  @override
  String get preflightServicePurposeAudioInput => 'Sumber suara untuk merekam.';

  @override
  String get preflightServiceTitleDiskSpace => 'Ruang disk';

  @override
  String get preflightServicePurposeDiskSpace =>
      'Rekaman tiga jam butuh sekitar 1,4 GB.';

  @override
  String get downloadConsentQuickModel => 'Model Cepat';

  @override
  String get downloadConsentAccurateModel => 'Model Akurat';

  @override
  String get downloadConsentDialogTitle => 'Unduh model transkripsi?';

  @override
  String get downloadConsentDialogDescription =>
      'Trareon bekerja offline, jadi modelnya perlu ada di perangkat ini. Unduhan hanya sekali dan tercatat di Laporan Privasi.';

  @override
  String get downloadConsentDialogLater => 'Nanti';

  @override
  String get downloadConsentDialogDownloadNow => 'Unduh sekarang';

  @override
  String downloadConsentDialogSize(int megabytes) {
    return '±$megabytes MB';
  }

  @override
  String get downloadConsentDialogTotal => 'Total';

  @override
  String get downloadConsentDialogDeferOnMetered =>
      'Tunda kalau koneksi metered';

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

  @override
  String get notulenTemplatesDinasLabel => 'Notulen Dinas';

  @override
  String get notulenTemplatesDinasDescription =>
      'Notula lengkap sesuai Tata Naskah Dinas: identitas rapat, peserta, acara, jalannya rapat, kesimpulan, tindak lanjut, dan ruang tanda tangan notulis serta pimpinan rapat.';

  @override
  String get notulenTemplatesRisalahLabel => 'Risalah Rapat (verbatim-ringkas)';

  @override
  String get notulenTemplatesRisalahDescription =>
      'Catatan berurutan per pembicara, mendekati verbatim tetapi diringkas. Dipakai untuk sidang dan rapat yang perlu merekam siapa menyampaikan apa.';

  @override
  String get notulenTemplatesBeritaAcaraLabel => 'Berita Acara';

  @override
  String get notulenTemplatesBeritaAcaraDescription =>
      'Naskah pembuktian: menyebut para pihak, apa yang telah dilaksanakan, hasilnya, dan ditutup dengan formula baku \"Demikian Berita Acara ini dibuat dengan sesungguhnya\".';

  @override
  String get notulenTemplatesRingkasLabel => 'Notulen Ringkas';

  @override
  String get notulenTemplatesRingkasDescription =>
      'Satu halaman tanpa kop surat dan tanpa tanda tangan, untuk diedarkan cepat setelah rapat.';
}
