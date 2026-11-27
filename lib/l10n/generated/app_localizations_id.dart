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
}
