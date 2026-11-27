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

  /// Settings screen app-bar title
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get settingsScreenTitle;

  /// Settings category and section title
  ///
  /// In id, this message translates to:
  /// **'Tampilan'**
  String get settingsScreenCategoryAppearance;

  /// Settings category and section title
  ///
  /// In id, this message translates to:
  /// **'Model & Mode'**
  String get settingsScreenCategoryModelMode;

  /// Settings category and section title
  ///
  /// In id, this message translates to:
  /// **'Audio & Suara'**
  String get settingsScreenCategoryAudio;

  /// Settings category
  ///
  /// In id, this message translates to:
  /// **'Kamus Istilah'**
  String get settingsScreenCategoryGlossary;

  /// Settings category
  ///
  /// In id, this message translates to:
  /// **'Penyimpanan'**
  String get settingsScreenCategoryStorage;

  /// Settings category and section title
  ///
  /// In id, this message translates to:
  /// **'Ringkasan AI'**
  String get settingsScreenCategorySummary;

  /// Settings category for the official meeting-minutes defaults
  ///
  /// In id, this message translates to:
  /// **'Notulen Resmi'**
  String get settingsScreenCategoryMinutes;

  /// Settings category for Indonesian personal-data-protection (PDP) law compliance
  ///
  /// In id, this message translates to:
  /// **'Kepatuhan PDP'**
  String get settingsScreenCategoryCompliance;

  /// Settings category and section title
  ///
  /// In id, this message translates to:
  /// **'Penyiapan & Diagnostik'**
  String get settingsScreenCategorySetup;

  /// Settings category and section title
  ///
  /// In id, this message translates to:
  /// **'Tentang'**
  String get settingsScreenCategoryAbout;

  /// Dismisses the settings save-failure banner
  ///
  /// In id, this message translates to:
  /// **'Abaikan'**
  String get settingsScreenDismiss;

  /// Retries the failed settings save
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get settingsScreenRetry;

  /// No description provided for @settingsScreenTheme.
  ///
  /// In id, this message translates to:
  /// **'Tema'**
  String get settingsScreenTheme;

  /// No description provided for @settingsScreenThemeSystemSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mengikuti tema sistem operasi Anda saat ini.'**
  String get settingsScreenThemeSystemSubtitle;

  /// No description provided for @settingsScreenThemeLightSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Selalu terang, apa pun tema sistem.'**
  String get settingsScreenThemeLightSubtitle;

  /// No description provided for @settingsScreenThemeDarkSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Selalu gelap, apa pun tema sistem.'**
  String get settingsScreenThemeDarkSubtitle;

  /// Light theme option
  ///
  /// In id, this message translates to:
  /// **'Terang'**
  String get settingsScreenThemeLight;

  /// Dark theme option
  ///
  /// In id, this message translates to:
  /// **'Gelap'**
  String get settingsScreenThemeDark;

  /// Follow-system theme option
  ///
  /// In id, this message translates to:
  /// **'Sistem'**
  String get settingsScreenThemeSystem;

  /// No description provided for @settingsScreenSimpleMode.
  ///
  /// In id, this message translates to:
  /// **'Mode Sederhana'**
  String get settingsScreenSimpleMode;

  /// No description provided for @settingsScreenSimpleModeOnSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Hanya kontrol yang mengubah hasil transkrip yang tampil. Sisanya ada di balik \"Pengaturan lanjutan\".'**
  String get settingsScreenSimpleModeOnSubtitle;

  /// No description provided for @settingsScreenSimpleModeOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Semua kontrol ditampilkan.'**
  String get settingsScreenSimpleModeOffSubtitle;

  /// No description provided for @settingsScreenAutoAudioTuning.
  ///
  /// In id, this message translates to:
  /// **'Penyetelan audio otomatis'**
  String get settingsScreenAutoAudioTuning;

  /// No description provided for @settingsScreenAutoAudioTuningOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Dimatikan karena Anda pernah mengubah derau/AGC sendiri. Nilai Anda yang dipakai.'**
  String get settingsScreenAutoAudioTuningOffSubtitle;

  /// No description provided for @settingsScreenChangeManually.
  ///
  /// In id, this message translates to:
  /// **'Ubah manual'**
  String get settingsScreenChangeManually;

  /// No description provided for @settingsScreenUseAutomatic.
  ///
  /// In id, this message translates to:
  /// **'Pakai otomatis'**
  String get settingsScreenUseAutomatic;

  /// No description provided for @settingsScreenDefaultModel.
  ///
  /// In id, this message translates to:
  /// **'Model default'**
  String get settingsScreenDefaultModel;

  /// No description provided for @settingsScreenModelAvailable.
  ///
  /// In id, this message translates to:
  /// **'Tersedia di komputer ini.'**
  String get settingsScreenModelAvailable;

  /// No description provided for @settingsScreenModelNotDownloaded.
  ///
  /// In id, this message translates to:
  /// **'Belum diunduh. Pilih untuk mengunduhnya.'**
  String get settingsScreenModelNotDownloaded;

  /// Progressive transcription: fast model first, accurate model refines
  ///
  /// In id, this message translates to:
  /// **'Cepat dulu, lalu diperhalus'**
  String get settingsScreenProgressive;

  /// No description provided for @settingsScreenProgressiveOnSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Teks muncul cepat, lalu diperbaiki sendiri dengan model yang lebih teliti.'**
  String get settingsScreenProgressiveOnSubtitle;

  /// No description provided for @settingsScreenProgressiveOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Pakai satu model saja. Teks muncul sekali, sudah final.'**
  String get settingsScreenProgressiveOffSubtitle;

  /// No description provided for @settingsScreenAutoRetranscribe.
  ///
  /// In id, this message translates to:
  /// **'Perhalus otomatis dengan model lebih akurat di latar belakang'**
  String get settingsScreenAutoRetranscribe;

  /// No description provided for @settingsScreenAutoRetranscribeMissingSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Model akurat belum terpasang di komputer ini. Unduh dulu lewat \"Model default\" di atas sebelum menyalakan ini.'**
  String get settingsScreenAutoRetranscribeMissingSubtitle;

  /// No description provided for @settingsScreenAutoRetranscribeOnSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Setelah rekam/unggah selesai, transkrip diperhalus di latar belakang tanpa menghentikan pekerjaan Anda. Transkrip lama diganti hanya kalau prosesnya berhasil.'**
  String get settingsScreenAutoRetranscribeOnSubtitle;

  /// No description provided for @settingsScreenAutoRetranscribeOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mati. Transkrip tidak diperhalus otomatis setelah rekaman selesai.'**
  String get settingsScreenAutoRetranscribeOffSubtitle;

  /// No description provided for @settingsScreenGpu.
  ///
  /// In id, this message translates to:
  /// **'Akselerasi GPU'**
  String get settingsScreenGpu;

  /// Default recording mode (webinar / online / offline)
  ///
  /// In id, this message translates to:
  /// **'Mode default'**
  String get settingsScreenDefaultMode;

  /// No description provided for @settingsScreenModeWebinarSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mikrofon mati, suara sistem direkam.'**
  String get settingsScreenModeWebinarSubtitle;

  /// No description provided for @settingsScreenModeOnlineSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mikrofon dan suara sistem direkam.'**
  String get settingsScreenModeOnlineSubtitle;

  /// No description provided for @settingsScreenModeOfflineSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Hanya mikrofon yang direkam.'**
  String get settingsScreenModeOfflineSubtitle;

  /// Language the speech is transcribed in, not the UI language
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get settingsScreenTranscriptionLanguage;

  /// No description provided for @settingsScreenLanguageAutoSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Bahasa dideteksi otomatis per segmen.'**
  String get settingsScreenLanguageAutoSubtitle;

  /// No description provided for @settingsScreenLanguageForcedSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Dipaksa ke satu bahasa, lebih akurat kalau rapatnya memang satu bahasa.'**
  String get settingsScreenLanguageForcedSubtitle;

  /// No description provided for @settingsScreenLanguageAuto.
  ///
  /// In id, this message translates to:
  /// **'Deteksi otomatis'**
  String get settingsScreenLanguageAuto;

  /// Transcription language option
  ///
  /// In id, this message translates to:
  /// **'Indonesia'**
  String get settingsScreenLanguageIndonesian;

  /// No description provided for @settingsScreenHideAdvanced.
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan pengaturan lanjutan'**
  String get settingsScreenHideAdvanced;

  /// No description provided for @settingsScreenShowAdvanced.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan lanjutan'**
  String get settingsScreenShowAdvanced;

  /// Lists what the folded advanced settings contain
  ///
  /// In id, this message translates to:
  /// **'Akselerasi GPU · cepat-lalu-diperhalus · perbaikan di latar belakang · mode rekaman.'**
  String get settingsScreenAdvancedSubtitle;

  /// No description provided for @settingsScreenTranscription.
  ///
  /// In id, this message translates to:
  /// **'Transkripsi'**
  String get settingsScreenTranscription;

  /// No description provided for @settingsScreenSpeedComparison.
  ///
  /// In id, this message translates to:
  /// **'Perbandingan Kecepatan'**
  String get settingsScreenSpeedComparison;

  /// No description provided for @settingsScreenSpeedComparisonSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Indonesia: ringan 3 detik · cepat 10 detik · akurat 56 detik untuk tiap 1 menit audio.\nModel akurat disarankan untuk rapat dan wawancara.'**
  String get settingsScreenSpeedComparisonSubtitle;

  /// Automatic audio-tuning summary. reason comes from the quality-profile resolver; noise and agc are settingsScreenStateOn/Off
  ///
  /// In id, this message translates to:
  /// **'{reason}. Derau {noise}, AGC {agc}.'**
  String settingsScreenAudioDecision(String reason, String noise, String agc);

  /// Lower-case on state inside settingsScreenAudioDecision
  ///
  /// In id, this message translates to:
  /// **'nyala'**
  String get settingsScreenStateOn;

  /// Lower-case off state inside settingsScreenAudioDecision
  ///
  /// In id, this message translates to:
  /// **'mati'**
  String get settingsScreenStateOff;

  /// No description provided for @settingsScreenGpuUnknownOnSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Akan memakai GPU bila build ini mendukungnya.'**
  String get settingsScreenGpuUnknownOnSubtitle;

  /// No description provided for @settingsScreenGpuCpuSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Transkripsi memakai CPU.'**
  String get settingsScreenGpuCpuSubtitle;

  /// No description provided for @settingsScreenGpuNotCompiledSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Build ini dikompilasi tanpa dukungan GPU, jadi transkripsi tetap memakai CPU meski sakelar ini aktif.'**
  String get settingsScreenGpuNotCompiledSubtitle;

  /// backend is a GPU API name such as Metal or Vulkan
  ///
  /// In id, this message translates to:
  /// **'Transkripsi memakai GPU ({backend}).'**
  String settingsScreenGpuOnSubtitle(String backend);

  /// No description provided for @settingsScreenGpuAvailableOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'GPU ({backend}) tersedia, tapi transkripsi memakai CPU.'**
  String settingsScreenGpuAvailableOffSubtitle(String backend);

  /// No description provided for @settingsScreenDecidedAutomatically.
  ///
  /// In id, this message translates to:
  /// **'Diputuskan otomatis'**
  String get settingsScreenDecidedAutomatically;

  /// Voice activity detection switch
  ///
  /// In id, this message translates to:
  /// **'Abaikan jeda sunyi'**
  String get settingsScreenVad;

  /// No description provided for @settingsScreenVadOnSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Bagian yang sunyi dilewati, jadi transkripsi lebih cepat. Berlaku mulai sesi berikutnya.'**
  String get settingsScreenVadOnSubtitle;

  /// No description provided for @settingsScreenVadOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Semua audio ditranskrip, termasuk bagian yang sunyi.'**
  String get settingsScreenVadOffSubtitle;

  /// No description provided for @settingsScreenNoiseReduction.
  ///
  /// In id, this message translates to:
  /// **'Pengurangan derau (RNNoise)'**
  String get settingsScreenNoiseReduction;

  /// No description provided for @settingsScreenNoiseReductionOnSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Derau ruangan (kipas, AC, lalu lintas) ditekan sebelum transkripsi. Berlaku mulai potongan audio berikutnya.'**
  String get settingsScreenNoiseReductionOnSubtitle;

  /// No description provided for @settingsScreenNoiseReductionOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mati. Nyalakan bila ruangan Anda berisik; pada rekaman yang sudah bersih ini bisa menghilangkan satu-dua konsonan.'**
  String get settingsScreenNoiseReductionOffSubtitle;

  /// No description provided for @settingsScreenAgc.
  ///
  /// In id, this message translates to:
  /// **'Penguatan suara otomatis (AGC)'**
  String get settingsScreenAgc;

  /// No description provided for @settingsScreenAgcOnSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Suara pelan tapi nyata dikuatkan sebelum transkripsi, agar tidak terbaca sebagai sunyi.'**
  String get settingsScreenAgcOnSubtitle;

  /// No description provided for @settingsScreenAgcOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mati. Audio ditranskrip pada volume aslinya.'**
  String get settingsScreenAgcOffSubtitle;

  /// Removes speech captured by both mic and speaker
  ///
  /// In id, this message translates to:
  /// **'Hapus suara ganda'**
  String get settingsScreenDedup;

  /// No description provided for @settingsScreenDedupOnlineSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Aktif di mode Rapat Online: duplikasi MIC/SPK dibuang.'**
  String get settingsScreenDedupOnlineSubtitle;

  /// No description provided for @settingsScreenDedupOtherSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Hanya berlaku di mode Rapat Online.'**
  String get settingsScreenDedupOtherSubtitle;

  /// No description provided for @settingsScreenDedupInfo.
  ///
  /// In id, this message translates to:
  /// **'Membandingkan kemiripan audio dari mikrofon dan pengeras suara, lalu menghapus yang terdengar dua kali.'**
  String get settingsScreenDedupInfo;

  /// No description provided for @settingsScreenAutoStop.
  ///
  /// In id, this message translates to:
  /// **'Berhenti sendiri saat sunyi'**
  String get settingsScreenAutoStop;

  /// No description provided for @settingsScreenAutoStopOnSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Berhenti setelah {minutes} menit tanpa suara.'**
  String settingsScreenAutoStopOnSubtitle(int minutes);

  /// No description provided for @settingsScreenAutoStopOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Rekaman berjalan sampai Anda menghentikannya sendiri.'**
  String get settingsScreenAutoStopOffSubtitle;

  /// No description provided for @settingsScreenAutoStopDelay.
  ///
  /// In id, this message translates to:
  /// **'Lama sunyi sebelum berhenti'**
  String get settingsScreenAutoStopDelay;

  /// Auto-stop delay option
  ///
  /// In id, this message translates to:
  /// **'{minutes} menit'**
  String settingsScreenMinutes(int minutes);

  /// No description provided for @settingsScreenOutputStorage.
  ///
  /// In id, this message translates to:
  /// **'Output & Penyimpanan'**
  String get settingsScreenOutputStorage;

  /// No description provided for @settingsScreenOutputFolder.
  ///
  /// In id, this message translates to:
  /// **'Folder output'**
  String get settingsScreenOutputFolder;

  /// Folder picker dialog title
  ///
  /// In id, this message translates to:
  /// **'Pilih folder output'**
  String get settingsScreenPickOutputFolder;

  /// No description provided for @settingsScreenDefaultExportFormat.
  ///
  /// In id, this message translates to:
  /// **'Format ekspor default'**
  String get settingsScreenDefaultExportFormat;

  /// No description provided for @settingsScreenDefaultExportFormatSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Format yang sudah tercentang saat dialog Ekspor dibuka.'**
  String get settingsScreenDefaultExportFormatSubtitle;

  /// No description provided for @settingsScreenDiagnostics.
  ///
  /// In id, this message translates to:
  /// **'Diagnostik'**
  String get settingsScreenDiagnostics;

  /// No description provided for @settingsScreenDiagnosticsSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Periksa folder, model, mikrofon dan ruang disk. Semuanya lokal.'**
  String get settingsScreenDiagnosticsSubtitle;

  /// No description provided for @settingsScreenRerunSetup.
  ///
  /// In id, this message translates to:
  /// **'Jalankan Ulang Penyiapan'**
  String get settingsScreenRerunSetup;

  /// No description provided for @settingsScreenRerunSetupSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih ulang mikrofon, pengeras suara dan model, lalu uji suara.'**
  String get settingsScreenRerunSetupSubtitle;

  /// No description provided for @settingsScreenPrivacyReport.
  ///
  /// In id, this message translates to:
  /// **'Laporan Privasi'**
  String get settingsScreenPrivacyReport;

  /// No description provided for @settingsScreenPrivacyReportSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Apa yang pernah keluar dari komputer ini.'**
  String get settingsScreenPrivacyReportSubtitle;

  /// Opens the capabilities screen: what runs locally and what over the network
  ///
  /// In id, this message translates to:
  /// **'Apa Jalan di Mana'**
  String get settingsScreenCapabilities;

  /// No description provided for @settingsScreenCapabilitiesSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Setiap kemampuan, tempatnya berjalan, dan statusnya sekarang.'**
  String get settingsScreenCapabilitiesSubtitle;

  /// No description provided for @settingsScreenUsageDashboard.
  ///
  /// In id, this message translates to:
  /// **'Dasbor Penggunaan'**
  String get settingsScreenUsageDashboard;

  /// No description provided for @settingsScreenUsageDashboardSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Berapa lama Anda merekam, per minggu.'**
  String get settingsScreenUsageDashboardSubtitle;

  /// No description provided for @settingsScreenCheckUpdate.
  ///
  /// In id, this message translates to:
  /// **'Cek Pembaruan'**
  String get settingsScreenCheckUpdate;

  /// No description provided for @settingsScreenCheckUpdateSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Versi saat ini {version}. Memeriksa pembaruan menghubungi GitHub dan dicatat di Laporan Privasi.'**
  String settingsScreenCheckUpdateSubtitle(String version);

  /// No description provided for @settingsScreenAboutTrareon.
  ///
  /// In id, this message translates to:
  /// **'Tentang Trareon'**
  String get settingsScreenAboutTrareon;

  /// Product tagline in Settings and the About dialog
  ///
  /// In id, this message translates to:
  /// **'Transkripsi offline, privasi terjamin.'**
  String get settingsScreenTagline;

  /// No description provided for @settingsScreenUpdateAvailableTitle.
  ///
  /// In id, this message translates to:
  /// **'Pembaruan Tersedia'**
  String get settingsScreenUpdateAvailableTitle;

  /// No description provided for @settingsScreenUpdateAvailableBody.
  ///
  /// In id, this message translates to:
  /// **'Versi {latest} tersedia (saat ini {current}).'**
  String settingsScreenUpdateAvailableBody(String latest, String current);

  /// No description provided for @settingsScreenLater.
  ///
  /// In id, this message translates to:
  /// **'Nanti'**
  String get settingsScreenLater;

  /// No description provided for @settingsScreenViewRelease.
  ///
  /// In id, this message translates to:
  /// **'Lihat Rilis'**
  String get settingsScreenViewRelease;

  /// No description provided for @settingsScreenUpToDate.
  ///
  /// In id, this message translates to:
  /// **'Sudah versi terbaru.'**
  String get settingsScreenUpToDate;

  /// No description provided for @settingsScreenUpdateCheckFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memeriksa pembaruan: {error}'**
  String settingsScreenUpdateCheckFailed(String error);

  /// No description provided for @settingsScreenBrowserFailed.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa membuka peramban. Buka {url} secara manual.'**
  String settingsScreenBrowserFailed(String url);

  /// No description provided for @settingsScreenBuiltWith.
  ///
  /// In id, this message translates to:
  /// **'Dibangun dengan Flutter + Rust'**
  String get settingsScreenBuiltWith;

  /// model is a modelLabels* display label
  ///
  /// In id, this message translates to:
  /// **'Komputer ini sanggup menjalankan {model} untuk akurasi lebih baik.'**
  String settingsScreenUpgradeOffer(String model);

  /// No description provided for @settingsScreenUpgradeAccuracy.
  ///
  /// In id, this message translates to:
  /// **'Tingkatkan akurasi'**
  String get settingsScreenUpgradeAccuracy;

  /// No description provided for @settingsScreenNotNow.
  ///
  /// In id, this message translates to:
  /// **'Nanti saja'**
  String get settingsScreenNotNow;

  /// No description provided for @summaryPanelSaved.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan tersimpan.'**
  String get summaryPanelSaved;

  /// No description provided for @summaryPanelShareFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyiapkan ringkasan untuk dibagikan: {error}'**
  String summaryPanelShareFailed(String error);

  /// Header and semantic label of the collapsible AI summary panel
  ///
  /// In id, this message translates to:
  /// **'Ringkasan AI'**
  String get summaryPanelTitle;

  /// Marker next to the panel title when the summary has unsaved edits
  ///
  /// In id, this message translates to:
  /// **'belum disimpan'**
  String get summaryPanelUnsaved;

  /// No description provided for @summaryPanelDisabledNotice.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan AI mati. Fitur ini satu-satunya yang memakai jaringan, nyalakan di Pengaturan, Ringkasan AI, bila ingin memakainya.'**
  String get summaryPanelDisabledNotice;

  /// No description provided for @summaryPanelTemplateLabel.
  ///
  /// In id, this message translates to:
  /// **'Template'**
  String get summaryPanelTemplateLabel;

  /// No description provided for @summaryPanelCustomTemplateHelper.
  ///
  /// In id, this message translates to:
  /// **'Template buatan sendiri'**
  String get summaryPanelCustomTemplateHelper;

  /// No description provided for @summaryPanelManageTemplates.
  ///
  /// In id, this message translates to:
  /// **'Kelola template ringkasan'**
  String get summaryPanelManageTemplates;

  /// No description provided for @summaryPanelRegenerate.
  ///
  /// In id, this message translates to:
  /// **'Buat Ulang'**
  String get summaryPanelRegenerate;

  /// No description provided for @summaryPanelGenerate.
  ///
  /// In id, this message translates to:
  /// **'Buat Ringkasan'**
  String get summaryPanelGenerate;

  /// No description provided for @summaryPanelPlaceholder.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan akan muncul di sini. Anda bisa menyuntingnya sebelum menyimpan.'**
  String get summaryPanelPlaceholder;

  /// No description provided for @summaryPanelDroppedCitations.
  ///
  /// In id, this message translates to:
  /// **'{count} rujukan dibuang karena tidak cocok dengan transkrip. Periksa ringkasan ini lebih teliti.'**
  String summaryPanelDroppedCitations(int count);

  /// No description provided for @summaryPanelViewCitations.
  ///
  /// In id, this message translates to:
  /// **'Lihat rujukan'**
  String get summaryPanelViewCitations;

  /// No description provided for @summaryPanelEdit.
  ///
  /// In id, this message translates to:
  /// **'Sunting'**
  String get summaryPanelEdit;

  /// No description provided for @summaryPanelCopied.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan disalin.'**
  String get summaryPanelCopied;

  /// No description provided for @summaryPanelCopy.
  ///
  /// In id, this message translates to:
  /// **'Salin'**
  String get summaryPanelCopy;

  /// No description provided for @summaryPanelShare.
  ///
  /// In id, this message translates to:
  /// **'Bagikan'**
  String get summaryPanelShare;

  /// No description provided for @summaryPanelPersonalNotes.
  ///
  /// In id, this message translates to:
  /// **'Catatan Pribadi'**
  String get summaryPanelPersonalNotes;

  /// Feature name (F11) kept in English in both locales: merges personal notes with the transcript
  ///
  /// In id, this message translates to:
  /// **'Enhance'**
  String get summaryPanelEnhance;

  /// No description provided for @summaryPanelNoNotes.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada catatan yang ditulis selama rapat. Enhance tetap bisa dipakai, hasilnya akan berupa ringkasan dari transkrip saja.'**
  String get summaryPanelNoNotes;

  /// No description provided for @summaryPanelMergedResult.
  ///
  /// In id, this message translates to:
  /// **'Hasil Gabungan (AI)'**
  String get summaryPanelMergedResult;

  /// Semantic label of a citation chip
  ///
  /// In id, this message translates to:
  /// **'Putar segmen {segment} pada {time}'**
  String summaryPanelPlayCitation(int segment, String time);

  /// No description provided for @summaryTemplateEditorManagerTitle.
  ///
  /// In id, this message translates to:
  /// **'Template Ringkasan'**
  String get summaryTemplateEditorManagerTitle;

  /// No description provided for @summaryTemplateEditorManagerIntro.
  ///
  /// In id, this message translates to:
  /// **'Buat template sendiri dengan judul bagian dan instruksi Anda. Disimpan di komputer ini.'**
  String get summaryTemplateEditorManagerIntro;

  /// No description provided for @summaryTemplateEditorEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada template buatan sendiri.'**
  String get summaryTemplateEditorEmpty;

  /// No description provided for @summaryTemplateEditorNoHeadings.
  ///
  /// In id, this message translates to:
  /// **'Tanpa judul bagian'**
  String get summaryTemplateEditorNoHeadings;

  /// No description provided for @summaryTemplateEditorEditTooltip.
  ///
  /// In id, this message translates to:
  /// **'Ubah {name}'**
  String summaryTemplateEditorEditTooltip(String name);

  /// No description provided for @summaryTemplateEditorDuplicateTooltip.
  ///
  /// In id, this message translates to:
  /// **'Duplikat {name}'**
  String summaryTemplateEditorDuplicateTooltip(String name);

  /// No description provided for @summaryTemplateEditorDeleteTooltip.
  ///
  /// In id, this message translates to:
  /// **'Hapus {name}'**
  String summaryTemplateEditorDeleteTooltip(String name);

  /// Default name of a duplicated template (the user can rename it)
  ///
  /// In id, this message translates to:
  /// **'{name} (salinan)'**
  String summaryTemplateEditorCopyName(String name);

  /// No description provided for @summaryTemplateEditorStartFromBuiltin.
  ///
  /// In id, this message translates to:
  /// **'Mulai dari template bawaan'**
  String get summaryTemplateEditorStartFromBuiltin;

  /// No description provided for @summaryTemplateEditorDuplicateBuiltinTooltip.
  ///
  /// In id, this message translates to:
  /// **'Duplikat \"{name}\" jadi template sendiri'**
  String summaryTemplateEditorDuplicateBuiltinTooltip(String name);

  /// Default name of a template started from a built-in one
  ///
  /// In id, this message translates to:
  /// **'{name} (saya)'**
  String summaryTemplateEditorMineName(String name);

  /// Chip that starts a template from scratch
  ///
  /// In id, this message translates to:
  /// **'Kosong'**
  String get summaryTemplateEditorBlank;

  /// No description provided for @summaryTemplateEditorBlankTooltip.
  ///
  /// In id, this message translates to:
  /// **'Buat template dari nol'**
  String get summaryTemplateEditorBlankTooltip;

  /// Default name of a template started from scratch
  ///
  /// In id, this message translates to:
  /// **'Template saya'**
  String get summaryTemplateEditorDefaultName;

  /// No description provided for @summaryTemplateEditorClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get summaryTemplateEditorClose;

  /// No description provided for @summaryTemplateEditorEditTitle.
  ///
  /// In id, this message translates to:
  /// **'Ubah template'**
  String get summaryTemplateEditorEditTitle;

  /// No description provided for @summaryTemplateEditorNameLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama template'**
  String get summaryTemplateEditorNameLabel;

  /// No description provided for @summaryTemplateEditorHeadingsLabel.
  ///
  /// In id, this message translates to:
  /// **'Judul bagian (satu per baris)'**
  String get summaryTemplateEditorHeadingsLabel;

  /// Example headings, one per line
  ///
  /// In id, this message translates to:
  /// **'Ringkasan\nKeputusan\nRisiko'**
  String get summaryTemplateEditorHeadingsHint;

  /// No description provided for @summaryTemplateEditorInstructionsLabel.
  ///
  /// In id, this message translates to:
  /// **'Instruksi tambahan'**
  String get summaryTemplateEditorInstructionsLabel;

  /// No description provided for @summaryTemplateEditorInstructionsHint.
  ///
  /// In id, this message translates to:
  /// **'mis. Fokus pada risiko anggaran dan sebutkan angka persis seperti di transkrip.'**
  String get summaryTemplateEditorInstructionsHint;

  /// No description provided for @summaryTemplateEditorHeadingsNote.
  ///
  /// In id, this message translates to:
  /// **'Judul bagian dikirim sebagai daftar berurutan, jadi hasilnya konsisten dan bisa dipakai untuk mengisi form notulen.'**
  String get summaryTemplateEditorHeadingsNote;

  /// No description provided for @captureHealthViewSourceSystem.
  ///
  /// In id, this message translates to:
  /// **'Audio sistem'**
  String get captureHealthViewSourceSystem;

  /// No description provided for @captureHealthViewSourceMic.
  ///
  /// In id, this message translates to:
  /// **'Mikrofon'**
  String get captureHealthViewSourceMic;

  /// sources is one or more source names joined with " & "
  ///
  /// In id, this message translates to:
  /// **'{sources} senyap'**
  String captureHealthViewWentSilent(String sources);

  /// No description provided for @captureHealthViewConfirmed.
  ///
  /// In id, this message translates to:
  /// **'Rekaman terkonfirmasi'**
  String get captureHealthViewConfirmed;

  /// No description provided for @captureHealthViewWaiting.
  ///
  /// In id, this message translates to:
  /// **'Menunggu suara dari {sources}'**
  String captureHealthViewWaiting(String sources);

  /// No description provided for @captureHealthViewConfirmedTooltip.
  ///
  /// In id, this message translates to:
  /// **'Setiap sumber yang diminta sudah menghasilkan suara di atas ambang derau.'**
  String get captureHealthViewConfirmedTooltip;

  /// No description provided for @captureHealthViewUnconfirmedTooltip.
  ///
  /// In id, this message translates to:
  /// **'Belum ada suara nyata dari semua sumber yang diminta.'**
  String get captureHealthViewUnconfirmedTooltip;

  /// No description provided for @captureHealthViewAudioIssue.
  ///
  /// In id, this message translates to:
  /// **'Masalah audio belum teratasi'**
  String get captureHealthViewAudioIssue;

  /// label is captureHealthViewAudioIssue
  ///
  /// In id, this message translates to:
  /// **'{label}. Mikrofon atau audio sistem belum mengirim suara; lihat pemberitahuan terakhir atau periksa Pengaturan Sistem.'**
  String captureHealthViewAudioIssueTooltip(String label);

  /// No description provided for @captureHealthViewSummary.
  ///
  /// In id, this message translates to:
  /// **'Durasi {duration} · {segments} segmen transkrip'**
  String captureHealthViewSummary(String duration, int segments);

  /// No description provided for @captureHealthViewNoSources.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada sumber audio yang diminta untuk sesi ini.'**
  String get captureHealthViewNoSources;

  /// No description provided for @captureHealthViewChannelOk.
  ///
  /// In id, this message translates to:
  /// **'{source}: {duration} terekam, {percent}% senyap'**
  String captureHealthViewChannelOk(
    String source,
    String duration,
    String percent,
  );

  /// No description provided for @captureHealthViewChannelSilent.
  ///
  /// In id, this message translates to:
  /// **'{source}: tidak ada suara sama sekali ({duration} terekam)'**
  String captureHealthViewChannelSilent(String source, String duration);

  /// No description provided for @captureHealthViewSessionDone.
  ///
  /// In id, this message translates to:
  /// **'Sesi selesai'**
  String get captureHealthViewSessionDone;

  /// No description provided for @captureHealthViewSessionDoneIssues.
  ///
  /// In id, this message translates to:
  /// **'Sesi selesai, ada masalah'**
  String get captureHealthViewSessionDoneIssues;

  /// No description provided for @captureHealthViewNotSaved.
  ///
  /// In id, this message translates to:
  /// **'Transkrip belum tersimpan.'**
  String get captureHealthViewNotSaved;

  /// No description provided for @captureHealthViewClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get captureHealthViewClose;

  /// File picker dialog title
  ///
  /// In id, this message translates to:
  /// **'Pilih gambar kop surat (PNG)'**
  String get notulenSettingsSectionPickKopTitle;

  /// No description provided for @notulenSettingsSectionKopMustBePng.
  ///
  /// In id, this message translates to:
  /// **'Kop surat harus berupa berkas PNG.'**
  String get notulenSettingsSectionKopMustBePng;

  /// No description provided for @notulenSettingsSectionReadFailed.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa membaca berkas: {error}'**
  String notulenSettingsSectionReadFailed(String error);

  /// No description provided for @notulenSettingsSectionTitle.
  ///
  /// In id, this message translates to:
  /// **'Notulen Resmi'**
  String get notulenSettingsSectionTitle;

  /// No description provided for @notulenSettingsSectionIntro.
  ///
  /// In id, this message translates to:
  /// **'Isian yang sama di setiap rapat. Dipakai otomatis saat Anda membuat Notulen Rapat.'**
  String get notulenSettingsSectionIntro;

  /// No description provided for @notulenSettingsSectionUnitLabel.
  ///
  /// In id, this message translates to:
  /// **'Instansi / Unit Kerja'**
  String get notulenSettingsSectionUnitLabel;

  /// No description provided for @notulenSettingsSectionUnitHint.
  ///
  /// In id, this message translates to:
  /// **'mis. Direktorat Jenderal Anggaran'**
  String get notulenSettingsSectionUnitHint;

  /// No description provided for @notulenSettingsSectionPlaceLabel.
  ///
  /// In id, this message translates to:
  /// **'Tempat/Media yang biasa dipakai'**
  String get notulenSettingsSectionPlaceLabel;

  /// No description provided for @notulenSettingsSectionPlaceHint.
  ///
  /// In id, this message translates to:
  /// **'mis. Ruang Rapat Lt. 5 / Zoom'**
  String get notulenSettingsSectionPlaceHint;

  /// No description provided for @notulenSettingsSectionNotulisLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama notulis'**
  String get notulenSettingsSectionNotulisLabel;

  /// No description provided for @notulenSettingsSectionNotulisHint.
  ///
  /// In id, this message translates to:
  /// **'Nama Anda, untuk blok tanda tangan'**
  String get notulenSettingsSectionNotulisHint;

  /// No description provided for @notulenSettingsSectionKop.
  ///
  /// In id, this message translates to:
  /// **'Kop surat'**
  String get notulenSettingsSectionKop;

  /// No description provided for @notulenSettingsSectionKopEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum dipilih. Tanpa gambar, kop ditulis sebagai teks dari nama instansi di atas.'**
  String get notulenSettingsSectionKopEmpty;

  /// No description provided for @notulenSettingsSectionRemoveKop.
  ///
  /// In id, this message translates to:
  /// **'Hapus kop surat'**
  String get notulenSettingsSectionRemoveKop;

  /// No description provided for @notulenSettingsSectionPickKop.
  ///
  /// In id, this message translates to:
  /// **'Pilih gambar kop surat'**
  String get notulenSettingsSectionPickKop;

  /// Windows caption button
  ///
  /// In id, this message translates to:
  /// **'Perkecil'**
  String get platformChromeMinimize;

  /// Windows caption button
  ///
  /// In id, this message translates to:
  /// **'Perbesar'**
  String get platformChromeMaximize;

  /// Windows caption button
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get platformChromeClose;

  /// macOS application menu item
  ///
  /// In id, this message translates to:
  /// **'Pengaturan…'**
  String get platformChromeMenuSettings;

  /// macOS menu bar menu
  ///
  /// In id, this message translates to:
  /// **'Berkas'**
  String get platformChromeMenuFile;

  /// No description provided for @platformChromeMenuNewSession.
  ///
  /// In id, this message translates to:
  /// **'Sesi Baru'**
  String get platformChromeMenuNewSession;

  /// No description provided for @platformChromeMenuToggleRecording.
  ///
  /// In id, this message translates to:
  /// **'Mulai atau Berhenti Merekam'**
  String get platformChromeMenuToggleRecording;

  /// macOS menu bar menu
  ///
  /// In id, this message translates to:
  /// **'Tampilan'**
  String get platformChromeMenuView;

  /// No description provided for @platformChromeMenuSearch.
  ///
  /// In id, this message translates to:
  /// **'Cari di Riwayat Sesi'**
  String get platformChromeMenuSearch;

  /// No description provided for @platformChromeMenuHideSidebar.
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan Sidebar'**
  String get platformChromeMenuHideSidebar;

  /// macOS menu bar menu
  ///
  /// In id, this message translates to:
  /// **'Jendela'**
  String get platformChromeMenuWindow;

  /// macOS menu bar menu
  ///
  /// In id, this message translates to:
  /// **'Bantuan'**
  String get platformChromeMenuHelp;

  /// No description provided for @platformChromeMenuShortcuts.
  ///
  /// In id, this message translates to:
  /// **'Pintasan Keyboard'**
  String get platformChromeMenuShortcuts;

  /// Generic display name of the tiny transcription model
  ///
  /// In id, this message translates to:
  /// **'Ringan'**
  String get modelLabelsLight;

  /// Generic display name of the fast transcription model
  ///
  /// In id, this message translates to:
  /// **'Cepat'**
  String get modelLabelsFast;

  /// No description provided for @modelLabelsFastExperimental.
  ///
  /// In id, this message translates to:
  /// **'Cepat-Eksperimental'**
  String get modelLabelsFastExperimental;

  /// No description provided for @modelLabelsMedium.
  ///
  /// In id, this message translates to:
  /// **'Sedang'**
  String get modelLabelsMedium;

  /// No description provided for @modelLabelsHigh.
  ///
  /// In id, this message translates to:
  /// **'Tinggi'**
  String get modelLabelsHigh;

  /// No description provided for @modelLabelsAccurate.
  ///
  /// In id, this message translates to:
  /// **'Akurat'**
  String get modelLabelsAccurate;

  /// No description provided for @modelLabelsAccurateRecommended.
  ///
  /// In id, this message translates to:
  /// **'Akurat (disarankan)'**
  String get modelLabelsAccurateRecommended;

  /// No description provided for @modelLabelsAccurateExperimental.
  ///
  /// In id, this message translates to:
  /// **'Akurat-Eksperimental'**
  String get modelLabelsAccurateExperimental;

  /// Fallback display name for a model id without its own label
  ///
  /// In id, this message translates to:
  /// **'Model terpasang'**
  String get modelLabelsInstalled;

  /// Preflight warning banner; names is a list of check names
  ///
  /// In id, this message translates to:
  /// **'Perlu diperiksa: {names}.'**
  String setupOverlayNeedsAttention(String names);

  /// No description provided for @setupOverlayViewDiagnostics.
  ///
  /// In id, this message translates to:
  /// **'Lihat diagnostik'**
  String get setupOverlayViewDiagnostics;

  /// No description provided for @setupOverlayClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get setupOverlayClose;

  /// No description provided for @setupOverlayNotReady.
  ///
  /// In id, this message translates to:
  /// **'Trareon belum siap merekam'**
  String get setupOverlayNotReady;

  /// No description provided for @setupOverlayChecking.
  ///
  /// In id, this message translates to:
  /// **'Memeriksa…'**
  String get setupOverlayChecking;

  /// No description provided for @setupOverlayCheckAgain.
  ///
  /// In id, this message translates to:
  /// **'Periksa Ulang'**
  String get setupOverlayCheckAgain;

  /// No description provided for @setupOverlayContinueAnyway.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan saja'**
  String get setupOverlayContinueAnyway;

  /// No description provided for @sessionArchiveServiceOpenFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuka arsip: tidak terbaca atau rusak ({error}).'**
  String sessionArchiveServiceOpenFailed(String error);

  /// No description provided for @sessionArchiveServiceEmpty.
  ///
  /// In id, this message translates to:
  /// **'Arsip ini kosong atau bukan arsip sesi Trareon.'**
  String get sessionArchiveServiceEmpty;

  /// No description provided for @sessionArchiveServiceNoTranscript.
  ///
  /// In id, this message translates to:
  /// **'File ini bukan arsip sesi Trareon yang valid: tidak ada transkrip di dalamnya.'**
  String get sessionArchiveServiceNoTranscript;

  /// No description provided for @completionBannerExportIncomplete.
  ///
  /// In id, this message translates to:
  /// **'Transkrip terisi sendiri; ekspor sekarang akan belum lengkap.'**
  String get completionBannerExportIncomplete;

  /// Library badge for a session still being transcribed
  ///
  /// In id, this message translates to:
  /// **'Belum selesai'**
  String get completionBannerIncomplete;

  /// No description provided for @completionBannerIncompletePercent.
  ///
  /// In id, this message translates to:
  /// **'Belum selesai · {percent}%'**
  String completionBannerIncompletePercent(int percent);

  /// No description provided for @completionBannerIncompleteTooltip.
  ///
  /// In id, this message translates to:
  /// **'Masih ada audio yang belum ditranskripsi. Transkrip akan dilengkapi otomatis di latar belakang.'**
  String get completionBannerIncompleteTooltip;

  /// Capture-source chip label
  ///
  /// In id, this message translates to:
  /// **'Mikrofon'**
  String get streamToggleMic;

  /// Capture-source chip label
  ///
  /// In id, this message translates to:
  /// **'Suara sistem'**
  String get streamToggleSpeaker;

  /// Lower-case state inside the screen-reader announcement
  ///
  /// In id, this message translates to:
  /// **'aktif'**
  String get streamToggleStateOn;

  /// Lower-case state inside the screen-reader announcement
  ///
  /// In id, this message translates to:
  /// **'nonaktif'**
  String get streamToggleStateOff;

  /// Screen-reader announcement; state is streamToggleStateOn/Off
  ///
  /// In id, this message translates to:
  /// **'Mikrofon {state}'**
  String streamToggleMicAnnouncement(String state);

  /// Screen-reader announcement; state is streamToggleStateOn/Off
  ///
  /// In id, this message translates to:
  /// **'Pengeras suara {state}'**
  String streamToggleSpeakerAnnouncement(String state);

  /// Upper-case chip badge
  ///
  /// In id, this message translates to:
  /// **'HIDUP'**
  String get streamToggleOn;

  /// Upper-case chip badge
  ///
  /// In id, this message translates to:
  /// **'MATI'**
  String get streamToggleOff;

  /// Default search-field placeholder
  ///
  /// In id, this message translates to:
  /// **'Cari…'**
  String get appFieldSearchPlaceholder;

  /// No description provided for @appFieldClearSearch.
  ///
  /// In id, this message translates to:
  /// **'Bersihkan pencarian'**
  String get appFieldClearSearch;
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
