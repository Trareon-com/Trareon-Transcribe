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
}
