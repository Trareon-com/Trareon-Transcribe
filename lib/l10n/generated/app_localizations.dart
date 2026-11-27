import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// Product name. Not translated in either locale.
  ///
  /// In id, this message translates to:
  /// **'Trareon Transcribe'**
  String get appTitle;

  /// Heading of the language pane in Settings
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get languageSectionTitle;

  /// Label of the UI-language selector
  ///
  /// In id, this message translates to:
  /// **'Bahasa antarmuka'**
  String get languageLabel;

  /// Clarifies that this is distinct from the transcription language, which has its own setting
  ///
  /// In id, this message translates to:
  /// **'Bahasa tombol dan menu. Tidak mengubah bahasa transkripsi.'**
  String get languageSubtitle;

  /// Follow the operating system language
  ///
  /// In id, this message translates to:
  /// **'Ikuti sistem'**
  String get languageSystem;

  /// No description provided for @languageIndonesian.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Indonesia'**
  String get languageIndonesian;

  /// No description provided for @languageEnglish.
  ///
  /// In id, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Shown when a second instance is launched
  ///
  /// In id, this message translates to:
  /// **'Trareon Transcribe sudah berjalan'**
  String get alreadyRunningTitle;

  /// No description provided for @alreadyRunningBody.
  ///
  /// In id, this message translates to:
  /// **'Hanya satu instance Trareon Transcribe yang bisa berjalan pada saat yang sama. Tutup jendela ini dan gunakan instance yang sudah terbuka.'**
  String get alreadyRunningBody;

  /// No description provided for @actionSave.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get actionCancel;

  /// No description provided for @actionSkip.
  ///
  /// In id, this message translates to:
  /// **'Lewati'**
  String get actionSkip;

  /// No description provided for @actionHide.
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan'**
  String get actionHide;

  /// No description provided for @actionCancelThis.
  ///
  /// In id, this message translates to:
  /// **'Batalkan'**
  String get actionCancelThis;

  /// No description provided for @actionCancelAll.
  ///
  /// In id, this message translates to:
  /// **'Batalkan semua'**
  String get actionCancelAll;

  /// Sidebar heading for the background re-transcribe queue (F5)
  ///
  /// In id, this message translates to:
  /// **'Memperhalus transkrip'**
  String get enhanceQueueTitle;

  /// No description provided for @enhanceQueuePaused.
  ///
  /// In id, this message translates to:
  /// **'Ditunda selama ada rekaman berjalan.'**
  String get enhanceQueuePaused;

  /// No description provided for @enhanceJobRunning.
  ///
  /// In id, this message translates to:
  /// **'Memakai model akurat… transkrip lama tetap aman sampai selesai.'**
  String get enhanceJobRunning;

  /// No description provided for @enhanceJobFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal. Transkrip lama dipakai.'**
  String get enhanceJobFailed;

  /// No description provided for @enhanceJobQueued.
  ///
  /// In id, this message translates to:
  /// **'Menunggu antrean.'**
  String get enhanceJobQueued;

  /// Number of saved sessions in the storage bar
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =0{Belum ada sesi} other{{count} sesi}}'**
  String storageSessionCount(int count);

  /// No description provided for @storageTooltip.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =0{Penyimpanan: belum ada sesi tersimpan} other{Penyimpanan: {count} sesi tersimpan}}'**
  String storageTooltip(int count);

  /// Collapsed-sidebar storage indicator when nothing is saved
  ///
  /// In id, this message translates to:
  /// **'📂 Kosong'**
  String get storageEmptyCompact;

  /// No description provided for @storageCountCompact.
  ///
  /// In id, this message translates to:
  /// **'📁 {count}'**
  String storageCountCompact(int count);

  /// Session count joined with the formatted byte size
  ///
  /// In id, this message translates to:
  /// **'{sessions} · {size}'**
  String storageSummary(String sessions, String size);

  /// No description provided for @bytesKb.
  ///
  /// In id, this message translates to:
  /// **'{value} KB'**
  String bytesKb(String value);

  /// No description provided for @bytesMb.
  ///
  /// In id, this message translates to:
  /// **'{value} MB'**
  String bytesMb(String value);

  /// No description provided for @bytesGb.
  ///
  /// In id, this message translates to:
  /// **'{value} GB'**
  String bytesGb(String value);

  /// Button that marks the current moment during recording (F9)
  ///
  /// In id, this message translates to:
  /// **'Tandai'**
  String get bookmarkAdd;

  /// No description provided for @bookmarkAddTooltip.
  ///
  /// In id, this message translates to:
  /// **'Tandai poin penting di posisi sekarang (Ctrl+B)'**
  String get bookmarkAddTooltip;

  /// No description provided for @bookmarkAddWithNoteTooltip.
  ///
  /// In id, this message translates to:
  /// **'Tandai dan tulis catatan'**
  String get bookmarkAddWithNoteTooltip;

  /// No description provided for @bookmarkNoteDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Catatan untuk {time}'**
  String bookmarkNoteDialogTitle(String time);

  /// No description provided for @bookmarkNoteLabel.
  ///
  /// In id, this message translates to:
  /// **'Catatan (opsional)'**
  String get bookmarkNoteLabel;

  /// No description provided for @bookmarkNoteHint.
  ///
  /// In id, this message translates to:
  /// **'mis. keputusan penting, tindak lanjut'**
  String get bookmarkNoteHint;

  /// No description provided for @bookmarkMarkedAt.
  ///
  /// In id, this message translates to:
  /// **'Poin ditandai pada {time}'**
  String bookmarkMarkedAt(String time);

  /// No description provided for @bookmarkNone.
  ///
  /// In id, this message translates to:
  /// **'Belum ada poin yang ditandai.'**
  String get bookmarkNone;

  /// No description provided for @bookmarkCount.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, other{{count} poin ditandai.}}'**
  String bookmarkCount(int count);

  /// No description provided for @bookmarkRemoveTooltip.
  ///
  /// In id, this message translates to:
  /// **'Hapus tanda {time}'**
  String bookmarkRemoveTooltip(String time);

  /// No description provided for @bookmarkJumpTooltip.
  ///
  /// In id, this message translates to:
  /// **'Klik: lompat ke {time} · Tahan: ubah catatan'**
  String bookmarkJumpTooltip(String time);

  /// No description provided for @bookmarkEditNoteTooltip.
  ///
  /// In id, this message translates to:
  /// **'Klik untuk ubah catatan'**
  String get bookmarkEditNoteTooltip;

  /// No description provided for @bookmarkRowLabel.
  ///
  /// In id, this message translates to:
  /// **'{time} · {note}'**
  String bookmarkRowLabel(String time, String note);

  /// Wizard progress
  ///
  /// In id, this message translates to:
  /// **'Langkah {step} dari {total}'**
  String setupWizardScreenStepOf(int step, int total);

  /// No description provided for @setupWizardScreenBack.
  ///
  /// In id, this message translates to:
  /// **'Kembali'**
  String get setupWizardScreenBack;

  /// No description provided for @setupWizardScreenClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get setupWizardScreenClose;

  /// No description provided for @setupWizardScreenFinish.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get setupWizardScreenFinish;

  /// No description provided for @setupWizardScreenNext.
  ///
  /// In id, this message translates to:
  /// **'Lanjut'**
  String get setupWizardScreenNext;

  /// Step 1 heading
  ///
  /// In id, this message translates to:
  /// **'1. Deteksi Spesifikasi'**
  String get setupWizardScreenSpecTitle;

  /// No description provided for @setupWizardScreenSpecReady.
  ///
  /// In id, this message translates to:
  /// **'Sistem Anda siap! Model direkomendasikan berdasarkan spesifikasi.'**
  String get setupWizardScreenSpecReady;

  /// No description provided for @setupWizardScreenSpecChecking.
  ///
  /// In id, this message translates to:
  /// **'Memeriksa sistem…'**
  String get setupWizardScreenSpecChecking;

  /// No description provided for @setupWizardScreenSpecCpu.
  ///
  /// In id, this message translates to:
  /// **'Inti Prosesor'**
  String get setupWizardScreenSpecCpu;

  /// CPU core count; the value is preformatted
  ///
  /// In id, this message translates to:
  /// **'{cores} core'**
  String setupWizardScreenSpecCores(String cores);

  /// No description provided for @setupWizardScreenSpecRamEstimate.
  ///
  /// In id, this message translates to:
  /// **'RAM (perkiraan)'**
  String get setupWizardScreenSpecRamEstimate;

  /// No description provided for @setupWizardScreenSpecRam.
  ///
  /// In id, this message translates to:
  /// **'RAM'**
  String get setupWizardScreenSpecRam;

  /// Shown when the RAM size could not be read
  ///
  /// In id, this message translates to:
  /// **'tidak diketahui'**
  String get setupWizardScreenSpecUnknown;

  /// No description provided for @setupWizardScreenSpecSuggestedModel.
  ///
  /// In id, this message translates to:
  /// **'Model Disarankan'**
  String get setupWizardScreenSpecSuggestedModel;

  /// No description provided for @setupWizardScreenModelFastLabel.
  ///
  /// In id, this message translates to:
  /// **'⚡ Cepat'**
  String get setupWizardScreenModelFastLabel;

  /// No description provided for @setupWizardScreenModelFastDescription.
  ///
  /// In id, this message translates to:
  /// **'142 MB · termasuk di aplikasi\nTranskrip muncul cepat, cocok untuk komputer ringan dan catatan sehari-hari.'**
  String get setupWizardScreenModelFastDescription;

  /// No description provided for @setupWizardScreenModelFastExperimentalLabel.
  ///
  /// In id, this message translates to:
  /// **'🧪 Cepat-Eksperimental'**
  String get setupWizardScreenModelFastExperimentalLabel;

  /// No description provided for @setupWizardScreenModelFastExperimentalDescription.
  ///
  /// In id, this message translates to:
  /// **'631 MB · unduh sekali\nSeakurat model \"Akurat\" tapi secepat model \"Cepat\" (Qwen3-ASR). Baru, belum teruji selengkap model lain.'**
  String get setupWizardScreenModelFastExperimentalDescription;

  /// No description provided for @setupWizardScreenModelBalancedLabel.
  ///
  /// In id, this message translates to:
  /// **'⚖️ Seimbang'**
  String get setupWizardScreenModelBalancedLabel;

  /// No description provided for @setupWizardScreenModelBalancedDescription.
  ///
  /// In id, this message translates to:
  /// **'488 MB · unduh sekali\nLebih teliti dari model cepat, tanpa seberat model akurat. Pilihan tengah untuk komputer dengan RAM sedang.'**
  String get setupWizardScreenModelBalancedDescription;

  /// No description provided for @setupWizardScreenModelAccurateLabel.
  ///
  /// In id, this message translates to:
  /// **'🎯 Akurat'**
  String get setupWizardScreenModelAccurateLabel;

  /// No description provided for @setupWizardScreenModelAccurateDescription.
  ///
  /// In id, this message translates to:
  /// **'548 MB · unduh sekali\nLebih teliti untuk rapat dan wawancara, tapi jauh lebih lambat di komputer tanpa GPU.'**
  String get setupWizardScreenModelAccurateDescription;

  /// No description provided for @setupWizardScreenModelAccurateExperimentalLabel.
  ///
  /// In id, this message translates to:
  /// **'🧪 Akurat-Eksperimental'**
  String get setupWizardScreenModelAccurateExperimentalLabel;

  /// No description provided for @setupWizardScreenModelAccurateExperimentalDescription.
  ///
  /// In id, this message translates to:
  /// **'1.5 GB · unduh sekali\nModel paling teliti yang tersedia (Qwen3-ASR). Baru, belum teruji selengkap model lain.'**
  String get setupWizardScreenModelAccurateExperimentalDescription;

  /// Step 2 heading
  ///
  /// In id, this message translates to:
  /// **'2. Pilih Model'**
  String get setupWizardScreenModelTitle;

  /// No description provided for @setupWizardScreenModelDescription.
  ///
  /// In id, this message translates to:
  /// **'Pilih model Speech-to-Text yang sesuai.'**
  String get setupWizardScreenModelDescription;

  /// No description provided for @setupWizardScreenModelAutoLabel.
  ///
  /// In id, this message translates to:
  /// **'🤖 Otomatis (disarankan)'**
  String get setupWizardScreenModelAutoLabel;

  /// No description provided for @setupWizardScreenModelAutoDescription.
  ///
  /// In id, this message translates to:
  /// **'Dipilihkan otomatis sesuai spesifikasi komputer ini.'**
  String get setupWizardScreenModelAutoDescription;

  /// No description provided for @setupWizardScreenLoopbackVirtualDriverFound.
  ///
  /// In id, this message translates to:
  /// **'Driver audio virtual terdeteksi'**
  String get setupWizardScreenLoopbackVirtualDriverFound;

  /// No description provided for @setupWizardScreenLoopbackSystemAudioReady.
  ///
  /// In id, this message translates to:
  /// **'Suara sistem siap direkam'**
  String get setupWizardScreenLoopbackSystemAudioReady;

  /// No description provided for @setupWizardScreenLoopbackVirtualDriverMissing.
  ///
  /// In id, this message translates to:
  /// **'Driver audio virtual belum terpasang'**
  String get setupWizardScreenLoopbackVirtualDriverMissing;

  /// No description provided for @setupWizardScreenLoopbackNoOutputDevice.
  ///
  /// In id, this message translates to:
  /// **'Belum ada perangkat keluaran yang bisa direkam'**
  String get setupWizardScreenLoopbackNoOutputDevice;

  /// No description provided for @setupWizardScreenLoopbackReadyMacos.
  ///
  /// In id, this message translates to:
  /// **'Suara dari Zoom/Meet bisa direkam lewat perangkat virtual di atas.'**
  String get setupWizardScreenLoopbackReadyMacos;

  /// No description provided for @setupWizardScreenLoopbackReadyLinux.
  ///
  /// In id, this message translates to:
  /// **'Trareon merekam suara sistem lewat monitor sink PipeWire/PulseAudio , tidak perlu memasang apa pun.'**
  String get setupWizardScreenLoopbackReadyLinux;

  /// No description provided for @setupWizardScreenLoopbackReadyWindows.
  ///
  /// In id, this message translates to:
  /// **'Trareon merekam suara sistem lewat WASAPI loopback, tidak perlu memasang apa pun.'**
  String get setupWizardScreenLoopbackReadyWindows;

  /// No description provided for @setupWizardScreenLoopbackMissingMacos.
  ///
  /// In id, this message translates to:
  /// **'Untuk merekam suara dari Zoom/Meet di macOS, pasang BlackHole 2ch.'**
  String get setupWizardScreenLoopbackMissingMacos;

  /// No description provided for @setupWizardScreenLoopbackMissingLinux.
  ///
  /// In id, this message translates to:
  /// **'Pilih perangkat keluaran di atas. Jika daftarnya kosong, pastikan PipeWire atau PulseAudio berjalan.'**
  String get setupWizardScreenLoopbackMissingLinux;

  /// No description provided for @setupWizardScreenLoopbackMissingWindows.
  ///
  /// In id, this message translates to:
  /// **'Pilih perangkat keluaran di atas. Jika daftarnya kosong, pastikan perangkat pemutar suara aktif di Windows.'**
  String get setupWizardScreenLoopbackMissingWindows;

  /// Setup steps; keep the command and macOS menu names as they are
  ///
  /// In id, this message translates to:
  /// **'1. brew install blackhole-2ch\n2. Buka Audio MIDI Setup\n3. Buat Multi-Output Device\n4. Centang pengeras suara Mac Anda + BlackHole 2ch'**
  String get setupWizardScreenLoopbackGuideMacos;

  /// Setup steps; keep the command as it is
  ///
  /// In id, this message translates to:
  /// **'1. Pastikan PipeWire atau PulseAudio berjalan\n2. Jalankan: pactl list short sources\n3. Pilih sumber yang berakhiran .monitor di daftar di atas'**
  String get setupWizardScreenLoopbackGuideLinux;

  /// No description provided for @setupWizardScreenLoopbackGuideWindows.
  ///
  /// In id, this message translates to:
  /// **'1. Buka Pengaturan Suara Windows\n2. Pastikan ada perangkat keluaran yang aktif\n3. Pilih perangkat itu di daftar di atas'**
  String get setupWizardScreenLoopbackGuideWindows;

  /// Step 3 heading
  ///
  /// In id, this message translates to:
  /// **'3. Siapkan Audio'**
  String get setupWizardScreenAudioTitle;

  /// No description provided for @setupWizardScreenAudioDescription.
  ///
  /// In id, this message translates to:
  /// **'Pilih perangkat mikrofon dan pengeras suara.'**
  String get setupWizardScreenAudioDescription;

  /// No description provided for @setupWizardScreenMicLabel.
  ///
  /// In id, this message translates to:
  /// **'Mikrofon (Input)'**
  String get setupWizardScreenMicLabel;

  /// No description provided for @setupWizardScreenSpeakerLabel.
  ///
  /// In id, this message translates to:
  /// **'Pengeras Suara / Suara Sistem (Output)'**
  String get setupWizardScreenSpeakerLabel;

  /// Button that shows setup steps for system audio
  ///
  /// In id, this message translates to:
  /// **'Panduan'**
  String get setupWizardScreenGuide;

  /// Audio device dropdown when no devices are listed
  ///
  /// In id, this message translates to:
  /// **'Bawaan sistem'**
  String get setupWizardScreenSystemDefault;

  /// No description provided for @setupWizardScreenRemediationMacos.
  ///
  /// In id, this message translates to:
  /// **'Buka Pengaturan Sistem → Suara, naikkan volume, dan pastikan perangkat keluaran yang benar terpilih.'**
  String get setupWizardScreenRemediationMacos;

  /// No description provided for @setupWizardScreenRemediationLinux.
  ///
  /// In id, this message translates to:
  /// **'Periksa volume di pavucontrol atau pengaturan suara desktop Anda, lalu pastikan perangkat keluaran yang benar terpilih.'**
  String get setupWizardScreenRemediationLinux;

  /// No description provided for @setupWizardScreenRemediationWindows.
  ///
  /// In id, this message translates to:
  /// **'Buka Pengaturan Suara Windows, naikkan volume, dan pastikan perangkat keluaran yang benar terpilih.'**
  String get setupWizardScreenRemediationWindows;

  /// Step 4 heading
  ///
  /// In id, this message translates to:
  /// **'4. Uji Suara'**
  String get setupWizardScreenToneTitle;

  /// No description provided for @setupWizardScreenToneDescription.
  ///
  /// In id, this message translates to:
  /// **'Putar nada 440 Hz untuk memastikan pengeras suara berfungsi.'**
  String get setupWizardScreenToneDescription;

  /// No description provided for @setupWizardScreenToneQuestion.
  ///
  /// In id, this message translates to:
  /// **'Apakah Anda mendengar nadanya?'**
  String get setupWizardScreenToneQuestion;

  /// No description provided for @setupWizardScreenToneHeard.
  ///
  /// In id, this message translates to:
  /// **'Ya, terdengar'**
  String get setupWizardScreenToneHeard;

  /// No description provided for @setupWizardScreenToneNotHeard.
  ///
  /// In id, this message translates to:
  /// **'Tidak terdengar'**
  String get setupWizardScreenToneNotHeard;

  /// No description provided for @setupWizardScreenToneWorksTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengeras suara berfungsi'**
  String get setupWizardScreenToneWorksTitle;

  /// No description provided for @setupWizardScreenToneWorksBody.
  ///
  /// In id, this message translates to:
  /// **'Tes mikrofon akan aktif saat sesi dimulai.'**
  String get setupWizardScreenToneWorksBody;

  /// No description provided for @setupWizardScreenToneNotHeardTitle.
  ///
  /// In id, this message translates to:
  /// **'Nada tidak terdengar'**
  String get setupWizardScreenToneNotHeardTitle;

  /// No description provided for @setupWizardScreenTonePlaybackFailed.
  ///
  /// In id, this message translates to:
  /// **'Nada gagal diputar'**
  String get setupWizardScreenTonePlaybackFailed;

  /// No description provided for @setupWizardScreenTonePlaying.
  ///
  /// In id, this message translates to:
  /// **'Memutar…'**
  String get setupWizardScreenTonePlaying;

  /// No description provided for @setupWizardScreenTonePlay.
  ///
  /// In id, this message translates to:
  /// **'Putar Nada Uji'**
  String get setupWizardScreenTonePlay;

  /// No description provided for @setupWizardScreenTonePlayAgain.
  ///
  /// In id, this message translates to:
  /// **'Putar Ulang'**
  String get setupWizardScreenTonePlayAgain;

  /// SRIKANDI urgency level (sifat naskah)
  ///
  /// In id, this message translates to:
  /// **'Sangat Segera (24 jam)'**
  String get srikandiExportDialogSifatSangatSegera;

  /// SRIKANDI urgency level (sifat naskah)
  ///
  /// In id, this message translates to:
  /// **'Segera (2x24 jam)'**
  String get srikandiExportDialogSifatSegera;

  /// SRIKANDI urgency level (sifat naskah): not urgent
  ///
  /// In id, this message translates to:
  /// **'Biasa'**
  String get srikandiExportDialogSifatBiasa;

  /// SRIKANDI security classification
  ///
  /// In id, this message translates to:
  /// **'Sangat Rahasia'**
  String get srikandiExportDialogKlasifikasiSangatRahasia;

  /// SRIKANDI security classification
  ///
  /// In id, this message translates to:
  /// **'Rahasia'**
  String get srikandiExportDialogKlasifikasiRahasia;

  /// SRIKANDI security classification
  ///
  /// In id, this message translates to:
  /// **'Terbatas'**
  String get srikandiExportDialogKlasifikasiTerbatas;

  /// SRIKANDI security classification: ordinary
  ///
  /// In id, this message translates to:
  /// **'Biasa'**
  String get srikandiExportDialogKlasifikasiBiasa;

  /// SRIKANDI document stage (tingkat perkembangan)
  ///
  /// In id, this message translates to:
  /// **'Asli'**
  String get srikandiExportDialogTingkatAsli;

  /// SRIKANDI document stage (tingkat perkembangan)
  ///
  /// In id, this message translates to:
  /// **'Salinan'**
  String get srikandiExportDialogTingkatSalinan;

  /// SRIKANDI document stage (tingkat perkembangan)
  ///
  /// In id, this message translates to:
  /// **'Tembusan'**
  String get srikandiExportDialogTingkatTembusan;

  /// SRIKANDI document stage: the copy kept by the sender
  ///
  /// In id, this message translates to:
  /// **'Pertinggal'**
  String get srikandiExportDialogTingkatPertinggal;

  /// No description provided for @srikandiExportDialogPrefillFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyiapkan metadata: {error}'**
  String srikandiExportDialogPrefillFailed(String error);

  /// No description provided for @srikandiExportDialogMetadataIncomplete.
  ///
  /// In id, this message translates to:
  /// **'Metadata belum lengkap. Periksa temuan \"Wajib\" di atas.'**
  String get srikandiExportDialogMetadataIncomplete;

  /// Title of the native folder picker
  ///
  /// In id, this message translates to:
  /// **'Pilih folder untuk ekspor SRIKANDI'**
  String get srikandiExportDialogPickFolder;

  /// Toast after export
  ///
  /// In id, this message translates to:
  /// **'{count} berkas siap-SRIKANDI tersimpan di {folder}'**
  String srikandiExportDialogExported(int count, String folder);

  /// No description provided for @srikandiExportDialogExportFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengekspor: {error}'**
  String srikandiExportDialogExportFailed(String error);

  /// No description provided for @srikandiExportDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Ekspor siap-SRIKANDI'**
  String get srikandiExportDialogTitle;

  /// No description provided for @srikandiExportDialogExporting.
  ///
  /// In id, this message translates to:
  /// **'Mengekspor…'**
  String get srikandiExportDialogExporting;

  /// No description provided for @srikandiExportDialogExportButton.
  ///
  /// In id, this message translates to:
  /// **'Ekspor (4 berkas)'**
  String get srikandiExportDialogExportButton;

  /// No description provided for @srikandiExportDialogIntro.
  ///
  /// In id, this message translates to:
  /// **'Berkas yang dihasilkan hanya disiapkan di perangkat ini. Unggahan ke SRIKANDI tetap dilakukan manual lewat antarmuka instansi (lihat docs/SRIKANDI-EXPORT.md).'**
  String get srikandiExportDialogIntro;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Nomor naskah'**
  String get srikandiExportDialogFieldNomor;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Tanggal'**
  String get srikandiExportDialogFieldTanggal;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Jenis naskah'**
  String get srikandiExportDialogFieldJenisNaskah;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Perihal'**
  String get srikandiExportDialogFieldPerihal;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Kode klasifikasi arsip'**
  String get srikandiExportDialogFieldKodeKlasifikasiArsip;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Unit pengolah'**
  String get srikandiExportDialogFieldUnitPengolah;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Nama penandatangan'**
  String get srikandiExportDialogFieldPenandatanganNama;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Jabatan penandatangan'**
  String get srikandiExportDialogFieldPenandatanganJabatan;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Jumlah lampiran'**
  String get srikandiExportDialogFieldJumlahLampiran;

  /// SRIKANDI metadata field label
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get srikandiExportDialogFieldCatatan;

  /// No description provided for @srikandiExportDialogNomorHint.
  ///
  /// In id, this message translates to:
  /// **'Minta ke Tata Usaha unit, mis. B-125/TU.01/KP.03/10/2026'**
  String get srikandiExportDialogNomorHint;

  /// No description provided for @srikandiExportDialogKodeHint.
  ///
  /// In id, this message translates to:
  /// **'Minta ke arsiparis unit, mis. UM.03.01'**
  String get srikandiExportDialogKodeHint;

  /// SRIKANDI field: sifat naskah
  ///
  /// In id, this message translates to:
  /// **'Sifat'**
  String get srikandiExportDialogGroupSifat;

  /// No description provided for @srikandiExportDialogGroupKlasifikasi.
  ///
  /// In id, this message translates to:
  /// **'Klasifikasi keamanan'**
  String get srikandiExportDialogGroupKlasifikasi;

  /// SRIKANDI field: tingkat perkembangan
  ///
  /// In id, this message translates to:
  /// **'Tingkat perkembangan'**
  String get srikandiExportDialogGroupTingkat;

  /// No description provided for @srikandiExportDialogGroupChecks.
  ///
  /// In id, this message translates to:
  /// **'Pemeriksaan metadata'**
  String get srikandiExportDialogGroupChecks;

  /// Severity of a metadata finding that blocks export
  ///
  /// In id, this message translates to:
  /// **'Wajib'**
  String get srikandiExportDialogWajib;

  /// Severity of an advisory metadata finding
  ///
  /// In id, this message translates to:
  /// **'Saran'**
  String get srikandiExportDialogSaran;

  /// Session list date group
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get sessionSidebarGroupToday;

  /// Session list date group
  ///
  /// In id, this message translates to:
  /// **'Kemarin'**
  String get sessionSidebarGroupYesterday;

  /// Session list date group
  ///
  /// In id, this message translates to:
  /// **'7 hari terakhir'**
  String get sessionSidebarGroupLast7Days;

  /// Session list date group
  ///
  /// In id, this message translates to:
  /// **'Lebih lama'**
  String get sessionSidebarGroupOlder;

  /// Primary sidebar button
  ///
  /// In id, this message translates to:
  /// **'Sesi Baru'**
  String get sessionSidebarNewSession;

  /// No description provided for @sessionSidebarSearchPlaceholder.
  ///
  /// In id, this message translates to:
  /// **'Cari sesi…'**
  String get sessionSidebarSearchPlaceholder;

  /// No description provided for @sessionSidebarSearchSemanticLabel.
  ///
  /// In id, this message translates to:
  /// **'Cari di riwayat sesi'**
  String get sessionSidebarSearchSemanticLabel;

  /// Chip that clears the tag filter
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get sessionSidebarAllTags;

  /// No description provided for @sessionSidebarImportFile.
  ///
  /// In id, this message translates to:
  /// **'Impor berkas'**
  String get sessionSidebarImportFile;

  /// No description provided for @sessionSidebarAskArchive.
  ///
  /// In id, this message translates to:
  /// **'Tanya arsip rapat'**
  String get sessionSidebarAskArchive;

  /// No description provided for @sessionSidebarManageLibrary.
  ///
  /// In id, this message translates to:
  /// **'Kelola perpustakaan'**
  String get sessionSidebarManageLibrary;

  /// No description provided for @sessionSidebarSettings.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get sessionSidebarSettings;

  /// No description provided for @sessionSidebarHideSidebar.
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan sidebar ({shortcut})'**
  String sessionSidebarHideSidebar(String shortcut);

  /// No description provided for @sessionSidebarShowSidebar.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan sidebar ({shortcut})'**
  String sessionSidebarShowSidebar(String shortcut);

  /// Icon-rail tooltip
  ///
  /// In id, this message translates to:
  /// **'Sesi baru'**
  String get sessionSidebarNewSessionTooltip;

  /// No description provided for @sessionSidebarHistoryTooltip.
  ///
  /// In id, this message translates to:
  /// **'Riwayat sesi'**
  String get sessionSidebarHistoryTooltip;

  /// Row pinned above the history while a session records
  ///
  /// In id, this message translates to:
  /// **'Sedang merekam'**
  String get sessionSidebarRecording;

  /// Transcript segment count on a session row
  ///
  /// In id, this message translates to:
  /// **'{count} segmen'**
  String sessionSidebarSegments(int count);

  /// Stage of a background completion job; source is the audio source label
  ///
  /// In id, this message translates to:
  /// **'Menyelesaikan {source}'**
  String sessionSidebarFinishing(String source);

  /// No description provided for @sessionSidebarRetranscribeQueued.
  ///
  /// In id, this message translates to:
  /// **'Menunggu antrean untuk ditranskrip ulang.'**
  String get sessionSidebarRetranscribeQueued;

  /// No description provided for @sessionSidebarRetranscribingStage.
  ///
  /// In id, this message translates to:
  /// **'Ditranskrip ulang: {stage}'**
  String sessionSidebarRetranscribingStage(String stage);

  /// Badge on a session being re-transcribed in the background
  ///
  /// In id, this message translates to:
  /// **'Ditranskrip ulang'**
  String get sessionSidebarRetranscribing;

  /// No description provided for @sessionSidebarHasSummary.
  ///
  /// In id, this message translates to:
  /// **'Ada ringkasan'**
  String get sessionSidebarHasSummary;

  /// No description provided for @sessionSidebarFolderUnreadable.
  ///
  /// In id, this message translates to:
  /// **'Folder sesi tidak terbaca'**
  String get sessionSidebarFolderUnreadable;

  /// No description provided for @sessionSidebarNoMatchTitle.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang cocok'**
  String get sessionSidebarNoMatchTitle;

  /// No description provided for @sessionSidebarNoMatchMessage.
  ///
  /// In id, this message translates to:
  /// **'Coba kata kunci lain atau lepaskan filter tag.'**
  String get sessionSidebarNoMatchMessage;

  /// No description provided for @sessionSidebarEmptyTitle.
  ///
  /// In id, this message translates to:
  /// **'Belum ada sesi'**
  String get sessionSidebarEmptyTitle;

  /// No description provided for @sessionSidebarEmptyMessage.
  ///
  /// In id, this message translates to:
  /// **'Rapat yang sudah direkam muncul di sini.'**
  String get sessionSidebarEmptyMessage;

  /// No description provided for @engineAssetsSectionVadTitle.
  ///
  /// In id, this message translates to:
  /// **'Gerbang suara neural (Silero)'**
  String get engineAssetsSectionVadTitle;

  /// No description provided for @engineAssetsSectionVadSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Memutuskan bagian mana dari rekaman yang berisi suara manusia. Tanpa ini Trareon memakai detektor energi sederhana, yang kadang meloloskan derau ruangan, dan Whisper menjawab derau dengan kalimat karangan. 0,9 MB.'**
  String get engineAssetsSectionVadSubtitle;

  /// No description provided for @engineAssetsSectionSegmentationTitle.
  ///
  /// In id, this message translates to:
  /// **'Segmentasi pembicara (pyannote 3.0)'**
  String get engineAssetsSectionSegmentationTitle;

  /// No description provided for @engineAssetsSectionSegmentationSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Menentukan siapa berbicara kapan. 6 MB.'**
  String get engineAssetsSectionSegmentationSubtitle;

  /// No description provided for @engineAssetsSectionEmbeddingTitle.
  ///
  /// In id, this message translates to:
  /// **'Sidik suara pembicara (CAM++)'**
  String get engineAssetsSectionEmbeddingTitle;

  /// No description provided for @engineAssetsSectionEmbeddingSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mengenali suara yang sama di bagian rekaman yang berbeda. 28 MB.'**
  String get engineAssetsSectionEmbeddingSubtitle;

  /// Toast after a model asset downloads
  ///
  /// In id, this message translates to:
  /// **'{name} terpasang.'**
  String engineAssetsSectionInstalledToast(String name);

  /// Settings section heading
  ///
  /// In id, this message translates to:
  /// **'Mesin pengenal suara'**
  String get engineAssetsSectionTitle;

  /// No description provided for @engineAssetsSectionDiarizationLabel.
  ///
  /// In id, this message translates to:
  /// **'Pemisahan pembicara akurat'**
  String get engineAssetsSectionDiarizationLabel;

  /// No description provided for @engineAssetsSectionDownloadFailed.
  ///
  /// In id, this message translates to:
  /// **'Unduhan gagal: {error}'**
  String engineAssetsSectionDownloadFailed(String error);

  /// No description provided for @engineAssetsSectionDiarizationOff.
  ///
  /// In id, this message translates to:
  /// **'Mati. Memakai pengelompokan akustik sederhana, yang cukup untuk rapat dua sumber (mikrofon = Anda, sistem = peserta) tetapi sering memecah satu suara menjadi beberapa pembicara pada berkas impor.'**
  String get engineAssetsSectionDiarizationOff;

  /// No description provided for @engineAssetsSectionDiarizationIncomplete.
  ///
  /// In id, this message translates to:
  /// **'Aktif, tetapi modelnya belum lengkap diunduh. Sementara ini masih memakai pengelompokan akustik sederhana.'**
  String get engineAssetsSectionDiarizationIncomplete;

  /// No description provided for @engineAssetsSectionDiarizationReady.
  ///
  /// In id, this message translates to:
  /// **'Segmentasi pyannote + sidik suara CAM++, seluruhnya di komputer ini. Dipakai pada impor berkas, transkrip ulang, dan penyelesaian setelah Stop (bukan pada pratinjau langsung).'**
  String get engineAssetsSectionDiarizationReady;

  /// No description provided for @engineAssetsSectionDownloadingPercent.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh… {percent}%'**
  String engineAssetsSectionDownloadingPercent(String percent);

  /// No description provided for @engineAssetsSectionChecking.
  ///
  /// In id, this message translates to:
  /// **'Memeriksa…'**
  String get engineAssetsSectionChecking;

  /// No description provided for @engineAssetsSectionInstalled.
  ///
  /// In id, this message translates to:
  /// **'Terpasang. {description}'**
  String engineAssetsSectionInstalled(String description);

  /// No description provided for @engineAssetsSectionNotDownloaded.
  ///
  /// In id, this message translates to:
  /// **'Belum diunduh. {description}'**
  String engineAssetsSectionNotDownloaded(String description);

  /// No description provided for @engineAssetsSectionDownloading.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh…'**
  String get engineAssetsSectionDownloading;

  /// No description provided for @engineAssetsSectionDownload.
  ///
  /// In id, this message translates to:
  /// **'Unduh'**
  String get engineAssetsSectionDownload;

  /// No description provided for @privacyReportScreenTitle.
  ///
  /// In id, this message translates to:
  /// **'Laporan Privasi'**
  String get privacyReportScreenTitle;

  /// No description provided for @privacyReportScreenNetworkCalls.
  ///
  /// In id, this message translates to:
  /// **'{count} panggilan jaringan sejak aplikasi dibuka'**
  String privacyReportScreenNetworkCalls(int count);

  /// No description provided for @privacyReportScreenSessionRunning.
  ///
  /// In id, this message translates to:
  /// **'Sesi berjalan selama {duration}'**
  String privacyReportScreenSessionRunning(String duration);

  /// No description provided for @privacyReportScreenNoActivity.
  ///
  /// In id, this message translates to:
  /// **'Belum ada aktivitas jaringan tercatat.'**
  String get privacyReportScreenNoActivity;

  /// No description provided for @privacyReportScreenHistory.
  ///
  /// In id, this message translates to:
  /// **'Riwayat aktivitas:'**
  String get privacyReportScreenHistory;

  /// Explains the only network activity the app performs. The quoted button names refer to buttons elsewhere in the app
  ///
  /// In id, this message translates to:
  /// **'Trareon Transcribe tidak melakukan panggilan jaringan apa pun selama transkripsi berlangsung, baik saat merekam langsung maupun saat mengimpor berkas. Audio tidak pernah keluar dari perangkat ini.\n\nAda empat aktivitas jaringan yang sah, dan semuanya Anda mulai sendiri:\n1. Unduh model whisper: dari huggingface.co, hanya saat Anda memilih model yang belum ada di perangkat.\n2. Ringkasan AI: mengirim teks transkrip (bukan audio) ke endpoint yang Anda atur sendiri. Fitur ini mati secara bawaan dan defaultnya menunjuk ke Ollama di komputer ini (localhost), jadi bawaannya pun tidak keluar dari perangkat.\n3. Cek pembaruan: mengambil satu berkas versi dari raw.githubusercontent.com saat Anda menekan \"Cek Pembaruan\". Tidak ada yang diunduh atau dijalankan secara otomatis.\n4. \"Lihat Rilis\": membuka halaman rilis di peramban Anda.\n\nKeempatnya tercatat di riwayat di atas, lengkap dengan tujuannya. Setiap titik di kode yang bisa memulai salah satunya wajib mencatat dirinya sendiri lebih dulu; hal itu diuji otomatis (test/privacy_proof_test.dart).'**
  String get privacyReportScreenExplanation;

  /// Compact duration: hours and minutes
  ///
  /// In id, this message translates to:
  /// **'{hours}j {minutes}m'**
  String privacyReportScreenDurationHours(int hours, int minutes);

  /// Compact duration: minutes and seconds
  ///
  /// In id, this message translates to:
  /// **'{minutes}m {seconds}d'**
  String privacyReportScreenDurationMinutes(int minutes, int seconds);

  /// Compact duration: seconds
  ///
  /// In id, this message translates to:
  /// **'{seconds}d'**
  String privacyReportScreenDurationSeconds(int seconds);

  /// Bookmark button tooltip; shortcut is the platform key combination
  ///
  /// In id, this message translates to:
  /// **'Tandai poin penting di posisi sekarang ({shortcut})'**
  String bookmarkBarAddTooltip(String shortcut);

  /// No description provided for @recoveryDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan sesi yang terhenti'**
  String get recoveryDialogTitle;

  /// No description provided for @recoveryDialogIntro.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{Satu sesi berhenti tanpa disimpan. Berikut isinya:} other{{count} sesi berhenti tanpa disimpan. Berikut isinya:}}'**
  String recoveryDialogIntro(int count);

  /// No description provided for @recoveryDialogLater.
  ///
  /// In id, this message translates to:
  /// **'Nanti saja'**
  String get recoveryDialogLater;

  /// No description provided for @recoveryDialogSegments.
  ///
  /// In id, this message translates to:
  /// **'{count} segmen transkrip'**
  String recoveryDialogSegments(int count);

  /// No description provided for @recoveryDialogEmptyTranscript.
  ///
  /// In id, this message translates to:
  /// **'transkrip kosong'**
  String get recoveryDialogEmptyTranscript;

  /// Recovered microphone audio length
  ///
  /// In id, this message translates to:
  /// **'mikrofon {duration}'**
  String recoveryDialogMic(String duration);

  /// Recovered system audio length
  ///
  /// In id, this message translates to:
  /// **'audio sistem {duration}'**
  String recoveryDialogSystemAudio(String duration);

  /// No description provided for @recoveryDialogNoAudio.
  ///
  /// In id, this message translates to:
  /// **'tanpa rekaman audio'**
  String get recoveryDialogNoAudio;

  /// Comma-separated list of recovered audio sources
  ///
  /// In id, this message translates to:
  /// **'audio: {sources}'**
  String recoveryDialogAudio(String sources);

  /// No description provided for @recoveryDialogDiscard.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get recoveryDialogDiscard;

  /// No description provided for @recoveryDialogRecoverTooltip.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan sesi ini dan rekam ke berkas yang sama'**
  String get recoveryDialogRecoverTooltip;

  /// No description provided for @recoveryDialogBusyTooltip.
  ///
  /// In id, this message translates to:
  /// **'Hentikan sesi yang sedang berjalan dulu'**
  String get recoveryDialogBusyTooltip;

  /// No description provided for @recoveryDialogRecover.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan'**
  String get recoveryDialogRecover;

  /// Title of the native file picker
  ///
  /// In id, this message translates to:
  /// **'Impor undangan rapat (.ics)'**
  String get calendarInviteImportPickTitle;

  /// No description provided for @calendarInviteImportReadFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membaca undangan: {error}'**
  String calendarInviteImportReadFailed(String error);

  /// No description provided for @calendarInviteImportNoEvents.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada acara yang terbaca dari berkas itu.'**
  String get calendarInviteImportNoEvents;

  /// No description provided for @calendarInviteImportConfirmTitle.
  ///
  /// In id, this message translates to:
  /// **'Isi dari undangan ini?'**
  String get calendarInviteImportConfirmTitle;

  /// No description provided for @calendarInviteImportNoTitle.
  ///
  /// In id, this message translates to:
  /// **'Undangan ini tidak punya judul.'**
  String get calendarInviteImportNoTitle;

  /// No description provided for @calendarInviteImportWillBeTitle.
  ///
  /// In id, this message translates to:
  /// **'\"{summary}\" akan menjadi judul sesi.'**
  String calendarInviteImportWillBeTitle(String summary);

  /// No description provided for @calendarInviteImportNo.
  ///
  /// In id, this message translates to:
  /// **'Tidak'**
  String get calendarInviteImportNo;

  /// No description provided for @calendarInviteImportFillTitle.
  ///
  /// In id, this message translates to:
  /// **'Isi judul'**
  String get calendarInviteImportFillTitle;

  /// No description provided for @calendarInviteImportAttendees.
  ///
  /// In id, this message translates to:
  /// **'Peserta pada undangan: {attendees}'**
  String calendarInviteImportAttendees(String attendees);

  /// No description provided for @archiveChatModelNotFound.
  ///
  /// In id, this message translates to:
  /// **'Tidak ditemukan di arsip rapat.'**
  String get archiveChatModelNotFound;

  /// No description provided for @archiveChatModelNeedsEndpoint.
  ///
  /// In id, this message translates to:
  /// **'Jawaban otomatis memerlukan endpoint ringkasan yang sudah diatur di Pengaturan → Ringkasan AI. Pencarian arsip tetap bisa dipakai tanpa itu.'**
  String get archiveChatModelNeedsEndpoint;

  /// HTTP status code from the update server
  ///
  /// In id, this message translates to:
  /// **'Server merespon dengan kode {code}. Coba lagi nanti.'**
  String updateCheckerBadStatus(int code);

  /// No description provided for @updateCheckerEmptyVersion.
  ///
  /// In id, this message translates to:
  /// **'File versi kosong. Coba lagi nanti.'**
  String get updateCheckerEmptyVersion;

  /// No description provided for @updateCheckerNoConnection.
  ///
  /// In id, this message translates to:
  /// **'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.'**
  String get updateCheckerNoConnection;

  /// No description provided for @updateCheckerBadResponse.
  ///
  /// In id, this message translates to:
  /// **'Server tidak merespons dengan benar. Coba lagi nanti.'**
  String get updateCheckerBadResponse;

  /// No description provided for @updateCheckerTimeout.
  ///
  /// In id, this message translates to:
  /// **'Permintaan timeout. Periksa koneksi internet Anda dan coba lagi.'**
  String get updateCheckerTimeout;

  /// No description provided for @updateCheckerInvalidData.
  ///
  /// In id, this message translates to:
  /// **'Data yang diterima tidak valid. Coba lagi nanti.'**
  String get updateCheckerInvalidData;

  /// No description provided for @onboardingModelDownloadFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengunduh: {error}'**
  String onboardingModelDownloadFailed(String error);

  /// Toast when the path was copied to the clipboard instead of shared
  ///
  /// In id, this message translates to:
  /// **'Berbagi file tidak didukung di platform ini. Path disalin: {name}'**
  String shareFileUnsupported(String name);

  /// Name of the "library_path" preflight check
  ///
  /// In id, this message translates to:
  /// **'Folder penyimpanan'**
  String get preflightServiceTitleLibraryPath;

  /// Why the "library_path" preflight check exists
  ///
  /// In id, this message translates to:
  /// **'Tempat rekaman dan transkrip disimpan.'**
  String get preflightServicePurposeLibraryPath;

  /// Name of the "model" preflight check
  ///
  /// In id, this message translates to:
  /// **'Model transkripsi'**
  String get preflightServiceTitleModel;

  /// Why the "model" preflight check exists
  ///
  /// In id, this message translates to:
  /// **'Berkas model yang dipakai untuk mengubah suara jadi teks.'**
  String get preflightServicePurposeModel;

  /// Name of the "config_dir" preflight check
  ///
  /// In id, this message translates to:
  /// **'Folder pengaturan'**
  String get preflightServiceTitleConfigDir;

  /// Why the "config_dir" preflight check exists
  ///
  /// In id, this message translates to:
  /// **'Tempat pengaturan aplikasi disimpan.'**
  String get preflightServicePurposeConfigDir;

  /// Name of the "audio_input" preflight check
  ///
  /// In id, this message translates to:
  /// **'Perangkat mikrofon'**
  String get preflightServiceTitleAudioInput;

  /// Why the "audio_input" preflight check exists
  ///
  /// In id, this message translates to:
  /// **'Sumber suara untuk merekam.'**
  String get preflightServicePurposeAudioInput;

  /// Name of the "disk_space" preflight check
  ///
  /// In id, this message translates to:
  /// **'Ruang disk'**
  String get preflightServiceTitleDiskSpace;

  /// Why the "disk_space" preflight check exists
  ///
  /// In id, this message translates to:
  /// **'Rekaman tiga jam butuh sekitar 1,4 GB.'**
  String get preflightServicePurposeDiskSpace;

  /// First-run download item: the fast transcription model
  ///
  /// In id, this message translates to:
  /// **'Model Cepat'**
  String get downloadConsentQuickModel;

  /// First-run download item: the accurate transcription model
  ///
  /// In id, this message translates to:
  /// **'Model Akurat'**
  String get downloadConsentAccurateModel;

  /// No description provided for @downloadConsentDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Unduh model transkripsi?'**
  String get downloadConsentDialogTitle;

  /// No description provided for @downloadConsentDialogDescription.
  ///
  /// In id, this message translates to:
  /// **'Trareon bekerja offline, jadi modelnya perlu ada di perangkat ini. Unduhan hanya sekali dan tercatat di Laporan Privasi.'**
  String get downloadConsentDialogDescription;

  /// No description provided for @downloadConsentDialogLater.
  ///
  /// In id, this message translates to:
  /// **'Nanti'**
  String get downloadConsentDialogLater;

  /// No description provided for @downloadConsentDialogDownloadNow.
  ///
  /// In id, this message translates to:
  /// **'Unduh sekarang'**
  String get downloadConsentDialogDownloadNow;

  /// Approximate download size
  ///
  /// In id, this message translates to:
  /// **'±{megabytes} MB'**
  String downloadConsentDialogSize(int megabytes);

  /// No description provided for @downloadConsentDialogTotal.
  ///
  /// In id, this message translates to:
  /// **'Total'**
  String get downloadConsentDialogTotal;

  /// No description provided for @downloadConsentDialogDeferOnMetered.
  ///
  /// In id, this message translates to:
  /// **'Tunda kalau koneksi metered'**
  String get downloadConsentDialogDeferOnMetered;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
