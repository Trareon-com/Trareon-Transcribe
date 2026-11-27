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

  /// No description provided for @notulenDialogSummaryNotConfigured.
  ///
  /// In id, this message translates to:
  /// **'Endpoint atau model ringkasan belum diisi. Lengkapi di Pengaturan → Ringkasan AI.'**
  String get notulenDialogSummaryNotConfigured;

  /// Title of the file picker for the optional reference document
  ///
  /// In id, this message translates to:
  /// **'Pilih dokumen rujukan'**
  String get notulenDialogPickReferenceDocTitle;

  /// No description provided for @notulenDialogReadDocFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membaca dokumen: {error}'**
  String notulenDialogReadDocFailed(String error);

  /// Title of the folder picker for the DOCX export
  ///
  /// In id, this message translates to:
  /// **'Pilih folder untuk notulen'**
  String get notulenDialogPickFolderTitle;

  /// No description provided for @notulenDialogSaved.
  ///
  /// In id, this message translates to:
  /// **'Notulen tersimpan: {path}'**
  String notulenDialogSaved(String path);

  /// No description provided for @notulenDialogExportFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat notulen: {error}'**
  String notulenDialogExportFailed(String error);

  /// No description provided for @notulenDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Notulen Rapat'**
  String get notulenDialogTitle;

  /// Button label while the minutes are being generated or exported
  ///
  /// In id, this message translates to:
  /// **'Menyusun…'**
  String get notulenDialogComposing;

  /// No description provided for @notulenDialogCreateDocx.
  ///
  /// In id, this message translates to:
  /// **'Buat Notulen (DOCX)'**
  String get notulenDialogCreateDocx;

  /// Group label above the meeting title/number/date fields
  ///
  /// In id, this message translates to:
  /// **'Identitas rapat'**
  String get notulenDialogMeetingIdentity;

  /// No description provided for @notulenDialogFieldTitle.
  ///
  /// In id, this message translates to:
  /// **'Judul Rapat'**
  String get notulenDialogFieldTitle;

  /// Official document number of the minutes
  ///
  /// In id, this message translates to:
  /// **'Nomor Notulen'**
  String get notulenDialogFieldNumber;

  /// No description provided for @notulenDialogFieldNumberHint.
  ///
  /// In id, this message translates to:
  /// **'mis. ND-12/AG.3/2026'**
  String get notulenDialogFieldNumberHint;

  /// No description provided for @notulenDialogFieldAgency.
  ///
  /// In id, this message translates to:
  /// **'Instansi (kop surat)'**
  String get notulenDialogFieldAgency;

  /// No description provided for @notulenDialogFieldUnit.
  ///
  /// In id, this message translates to:
  /// **'Unit kerja (baris kedua kop)'**
  String get notulenDialogFieldUnit;

  /// No description provided for @notulenDialogFieldDay.
  ///
  /// In id, this message translates to:
  /// **'Hari'**
  String get notulenDialogFieldDay;

  /// No description provided for @notulenDialogFieldDate.
  ///
  /// In id, this message translates to:
  /// **'Tanggal'**
  String get notulenDialogFieldDate;

  /// No description provided for @notulenDialogFieldTime.
  ///
  /// In id, this message translates to:
  /// **'Waktu'**
  String get notulenDialogFieldTime;

  /// Where the meeting took place, or the online medium used
  ///
  /// In id, this message translates to:
  /// **'Tempat/Media'**
  String get notulenDialogFieldPlace;

  /// No description provided for @notulenDialogFieldChair.
  ///
  /// In id, this message translates to:
  /// **'Pimpinan Rapat'**
  String get notulenDialogFieldChair;

  /// No description provided for @notulenDialogFieldMinuteTaker.
  ///
  /// In id, this message translates to:
  /// **'Notulis'**
  String get notulenDialogFieldMinuteTaker;

  /// The named parties of a berita acara (official record of an act)
  ///
  /// In id, this message translates to:
  /// **'Para Pihak'**
  String get notulenDialogParties;

  /// No description provided for @notulenDialogPartiesHelp.
  ///
  /// In id, this message translates to:
  /// **'Urutan menentukan kolom tanda tangan: pihak pertama di kanan, pihak kedua di kiri. Sebutkan nama beserta jabatannya.'**
  String get notulenDialogPartiesHelp;

  /// No description provided for @notulenDialogPartyHint.
  ///
  /// In id, this message translates to:
  /// **'Nama, jabatan'**
  String get notulenDialogPartyHint;

  /// No description provided for @notulenDialogAddParty.
  ///
  /// In id, this message translates to:
  /// **'Tambah pihak'**
  String get notulenDialogAddParty;

  /// No description provided for @notulenDialogAttendees.
  ///
  /// In id, this message translates to:
  /// **'Peserta'**
  String get notulenDialogAttendees;

  /// No description provided for @notulenDialogAttendeeHint.
  ///
  /// In id, this message translates to:
  /// **'Nama peserta'**
  String get notulenDialogAttendeeHint;

  /// No description provided for @notulenDialogAddAttendee.
  ///
  /// In id, this message translates to:
  /// **'Tambah peserta'**
  String get notulenDialogAddAttendee;

  /// No description provided for @notulenDialogAgenda.
  ///
  /// In id, this message translates to:
  /// **'Agenda'**
  String get notulenDialogAgenda;

  /// No description provided for @notulenDialogAgendaHint.
  ///
  /// In id, this message translates to:
  /// **'Butir agenda'**
  String get notulenDialogAgendaHint;

  /// No description provided for @notulenDialogAddAgenda.
  ///
  /// In id, this message translates to:
  /// **'Tambah agenda'**
  String get notulenDialogAddAgenda;

  /// No description provided for @notulenDialogDiscussion.
  ///
  /// In id, this message translates to:
  /// **'Pembahasan'**
  String get notulenDialogDiscussion;

  /// No description provided for @notulenDialogDiscussionHint.
  ///
  /// In id, this message translates to:
  /// **'Isi pembahasan. Terisi otomatis dari ringkasan AI kalau ada.'**
  String get notulenDialogDiscussionHint;

  /// No description provided for @notulenDialogDecisions.
  ///
  /// In id, this message translates to:
  /// **'Keputusan'**
  String get notulenDialogDecisions;

  /// No description provided for @notulenDialogDecisionHint.
  ///
  /// In id, this message translates to:
  /// **'Keputusan rapat'**
  String get notulenDialogDecisionHint;

  /// No description provided for @notulenDialogAddDecision.
  ///
  /// In id, this message translates to:
  /// **'Tambah keputusan'**
  String get notulenDialogAddDecision;

  /// No description provided for @notulenDialogFollowUp.
  ///
  /// In id, this message translates to:
  /// **'Tindak Lanjut'**
  String get notulenDialogFollowUp;

  /// No description provided for @notulenDialogArchivalExport.
  ///
  /// In id, this message translates to:
  /// **'Ekspor kearsipan'**
  String get notulenDialogArchivalExport;

  /// No description provided for @notulenDialogExportSrikandi.
  ///
  /// In id, this message translates to:
  /// **'Ekspor siap-SRIKANDI…'**
  String get notulenDialogExportSrikandi;

  /// Shown only when at least one bookmark exists
  ///
  /// In id, this message translates to:
  /// **'{count, plural, other{{count} poin penting yang Anda tandai saat rapat akan disertakan.}}'**
  String notulenDialogBookmarksIncluded(int count);

  /// No description provided for @notulenDialogAttachTranscript.
  ///
  /// In id, this message translates to:
  /// **'Lampirkan transkrip lengkap'**
  String get notulenDialogAttachTranscript;

  /// No description provided for @notulenDialogTranscriptLines.
  ///
  /// In id, this message translates to:
  /// **'{count} baris transkrip ditambahkan di halaman terpisah.'**
  String notulenDialogTranscriptLines(int count);

  /// Label of the minutes template picker
  ///
  /// In id, this message translates to:
  /// **'Bentuk naskah'**
  String get notulenDialogFormType;

  /// No description provided for @notulenDialogAutoFill.
  ///
  /// In id, this message translates to:
  /// **'Isi otomatis dengan AI'**
  String get notulenDialogAutoFill;

  /// No description provided for @notulenDialogSourceTranscript.
  ///
  /// In id, this message translates to:
  /// **'Transkrip sesi'**
  String get notulenDialogSourceTranscript;

  /// Source option: generate the minutes from notes the user types instead of the transcript
  ///
  /// In id, this message translates to:
  /// **'Poin catatan'**
  String get notulenDialogSourceNotes;

  /// No description provided for @notulenDialogNotesHint.
  ///
  /// In id, this message translates to:
  /// **'Tempel atau ketik butir-butir catatan rapat, satu poin per baris.'**
  String get notulenDialogNotesHint;

  /// No description provided for @notulenDialogLength.
  ///
  /// In id, this message translates to:
  /// **'Panjang notulen'**
  String get notulenDialogLength;

  /// No description provided for @notulenDialogAddReferenceDoc.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan dokumen rujukan (opsional)'**
  String get notulenDialogAddReferenceDoc;

  /// No description provided for @notulenDialogRemoveReferenceDoc.
  ///
  /// In id, this message translates to:
  /// **'Hapus dokumen rujukan'**
  String get notulenDialogRemoveReferenceDoc;

  /// No description provided for @notulenDialogGenerate.
  ///
  /// In id, this message translates to:
  /// **'Buat Otomatis'**
  String get notulenDialogGenerate;

  /// No description provided for @notulenDialogRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get notulenDialogRetry;

  /// No description provided for @notulenDialogGenerateFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat notulen otomatis: {error}'**
  String notulenDialogGenerateFailed(String error);

  /// No description provided for @notulenDialogFactCheckSection.
  ///
  /// In id, this message translates to:
  /// **'Periksa Fakta & Ragam'**
  String get notulenDialogFactCheckSection;

  /// No description provided for @notulenDialogRecheck.
  ///
  /// In id, this message translates to:
  /// **'Periksa Ulang'**
  String get notulenDialogRecheck;

  /// No description provided for @notulenDialogFactCheck.
  ///
  /// In id, this message translates to:
  /// **'Periksa Fakta'**
  String get notulenDialogFactCheck;

  /// Rewrites the discussion in standard official Indonesian (EYD V)
  ///
  /// In id, this message translates to:
  /// **'Rapikan Ragam'**
  String get notulenDialogTidyRegister;

  /// No description provided for @notulenDialogCheckFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memeriksa: {error}'**
  String notulenDialogCheckFailed(String error);

  /// No description provided for @notulenDialogFactSummary.
  ///
  /// In id, this message translates to:
  /// **'{checked} pernyataan diperiksa, {clean} bersih, {flagged} butir perlu ditinjau.'**
  String notulenDialogFactSummary(int checked, int clean, int flagged);

  /// No description provided for @notulenDialogTidyPreview.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau Rapikan Ragam'**
  String get notulenDialogTidyPreview;

  /// No description provided for @notulenDialogApply.
  ///
  /// In id, this message translates to:
  /// **'Terapkan'**
  String get notulenDialogApply;

  /// Tooltip of the delete button on a list chip
  ///
  /// In id, this message translates to:
  /// **'Hapus {item}'**
  String notulenDialogRemoveItem(String item);

  /// No description provided for @notulenDialogTaskField.
  ///
  /// In id, this message translates to:
  /// **'Tugas'**
  String get notulenDialogTaskField;

  /// No description provided for @notulenDialogOwnerField.
  ///
  /// In id, this message translates to:
  /// **'Penanggung Jawab'**
  String get notulenDialogOwnerField;

  /// No description provided for @notulenDialogDueField.
  ///
  /// In id, this message translates to:
  /// **'Tenggat'**
  String get notulenDialogDueField;

  /// No description provided for @notulenDialogRemoveTaskRow.
  ///
  /// In id, this message translates to:
  /// **'Hapus baris tindak lanjut'**
  String get notulenDialogRemoveTaskRow;

  /// No description provided for @notulenDialogAddTask.
  ///
  /// In id, this message translates to:
  /// **'Tambah tindak lanjut'**
  String get notulenDialogAddTask;

  /// No description provided for @notulenDialogIssueNoCitation.
  ///
  /// In id, this message translates to:
  /// **'Tanpa rujukan segmen'**
  String get notulenDialogIssueNoCitation;

  /// No description provided for @notulenDialogIssueInvalidCitation.
  ///
  /// In id, this message translates to:
  /// **'Rujukan segmen tidak sah'**
  String get notulenDialogIssueInvalidCitation;

  /// No description provided for @notulenDialogIssueWeakSupport.
  ///
  /// In id, this message translates to:
  /// **'Dukungan dari transkrip lemah'**
  String get notulenDialogIssueWeakSupport;

  /// No description provided for @notulenDialogIssueCitationOff.
  ///
  /// In id, this message translates to:
  /// **'Rujukan segmen meleset'**
  String get notulenDialogIssueCitationOff;

  /// No description provided for @notulenDialogIssueNumberMissing.
  ///
  /// In id, this message translates to:
  /// **'Angka tidak ditemukan di transkrip'**
  String get notulenDialogIssueNumberMissing;

  /// No description provided for @notulenDialogIssueNameMissing.
  ///
  /// In id, this message translates to:
  /// **'Nama tidak ditemukan di transkrip'**
  String get notulenDialogIssueNameMissing;

  /// A style finding: the line number and the text found there
  ///
  /// In id, this message translates to:
  /// **'Baris {line}: \"{found}\"'**
  String notulenDialogRegisterLine(int line, String found);

  /// No description provided for @notulenDialogRegisterSuggestion.
  ///
  /// In id, this message translates to:
  /// **'Saran: \"{suggestion}\" (diterapkan oleh Rapikan Ragam)'**
  String notulenDialogRegisterSuggestion(String suggestion);

  /// No description provided for @actionItemsPanelStatusNotStarted.
  ///
  /// In id, this message translates to:
  /// **'Belum mulai'**
  String get actionItemsPanelStatusNotStarted;

  /// No description provided for @actionItemsPanelStatusInProgress.
  ///
  /// In id, this message translates to:
  /// **'Sedang berjalan'**
  String get actionItemsPanelStatusInProgress;

  /// No description provided for @actionItemsPanelStatusDone.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get actionItemsPanelStatusDone;

  /// No description provided for @actionItemsPanelStatusCancelled.
  ///
  /// In id, this message translates to:
  /// **'Dibatalkan'**
  String get actionItemsPanelStatusCancelled;

  /// Toast after an export; {what} is actionItemsPanelIcsWhat or actionItemsPanelCsvWhat
  ///
  /// In id, this message translates to:
  /// **'{what} disimpan: {filename}'**
  String actionItemsPanelSaved(String what, String filename);

  /// No description provided for @actionItemsPanelSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan {what}: {error}'**
  String actionItemsPanelSaveFailed(String what, String error);

  /// Inserted into actionItemsPanelSaved / actionItemsPanelSaveFailed
  ///
  /// In id, this message translates to:
  /// **'Kalender tindak lanjut'**
  String get actionItemsPanelIcsWhat;

  /// Inserted into actionItemsPanelSaved / actionItemsPanelSaveFailed
  ///
  /// In id, this message translates to:
  /// **'Tabel tindak lanjut'**
  String get actionItemsPanelCsvWhat;

  /// No description provided for @actionItemsPanelIcsFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat .ics: {error}'**
  String actionItemsPanelIcsFailed(String error);

  /// No description provided for @actionItemsPanelCsvFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat .csv: {error}'**
  String actionItemsPanelCsvFailed(String error);

  /// No description provided for @actionItemsPanelCopied.
  ///
  /// In id, this message translates to:
  /// **'Tindak lanjut disalin.'**
  String get actionItemsPanelCopied;

  /// No description provided for @actionItemsPanelTitle.
  ///
  /// In id, this message translates to:
  /// **'Tindak Lanjut'**
  String get actionItemsPanelTitle;

  /// No description provided for @actionItemsPanelProgress.
  ///
  /// In id, this message translates to:
  /// **'{done}/{total} selesai'**
  String actionItemsPanelProgress(int done, int total);

  /// No description provided for @actionItemsPanelEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada tindak lanjut. Nyalakan \"Tindak lanjut terstruktur\" di Pengaturan → Ringkasan AI agar ringkasan berikutnya mengisinya sendiri, atau tambahkan sendiri di bawah.'**
  String get actionItemsPanelEmpty;

  /// No description provided for @actionItemsPanelAddTask.
  ///
  /// In id, this message translates to:
  /// **'Tambah tugas'**
  String get actionItemsPanelAddTask;

  /// No description provided for @actionItemsPanelCopy.
  ///
  /// In id, this message translates to:
  /// **'Salin'**
  String get actionItemsPanelCopy;

  /// No description provided for @actionItemsPanelExportCsv.
  ///
  /// In id, this message translates to:
  /// **'Ekspor CSV'**
  String get actionItemsPanelExportCsv;

  /// No description provided for @actionItemsPanelShareCsv.
  ///
  /// In id, this message translates to:
  /// **'Bagikan CSV'**
  String get actionItemsPanelShareCsv;

  /// No description provided for @actionItemsPanelExportIcs.
  ///
  /// In id, this message translates to:
  /// **'Ekspor .ics'**
  String get actionItemsPanelExportIcs;

  /// No description provided for @actionItemsPanelShareIcs.
  ///
  /// In id, this message translates to:
  /// **'Bagikan .ics'**
  String get actionItemsPanelShareIcs;

  /// Screen-reader label of the done checkbox
  ///
  /// In id, this message translates to:
  /// **'Tandai \"{task}\" selesai'**
  String actionItemsPanelMarkDone(String task);

  /// No description provided for @actionItemsPanelTaskLabel.
  ///
  /// In id, this message translates to:
  /// **'Tugas'**
  String get actionItemsPanelTaskLabel;

  /// No description provided for @actionItemsPanelRemoveTask.
  ///
  /// In id, this message translates to:
  /// **'Hapus tugas'**
  String get actionItemsPanelRemoveTask;

  /// No description provided for @actionItemsPanelOwnerLabel.
  ///
  /// In id, this message translates to:
  /// **'Penanggung jawab'**
  String get actionItemsPanelOwnerLabel;

  /// No description provided for @actionItemsPanelDueLabel.
  ///
  /// In id, this message translates to:
  /// **'Tenggat'**
  String get actionItemsPanelDueLabel;

  /// No description provided for @actionItemsPanelStatusLabel.
  ///
  /// In id, this message translates to:
  /// **'Status'**
  String get actionItemsPanelStatusLabel;

  /// No description provided for @diagnosticsScreenSaveDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Simpan log diagnostik'**
  String get diagnosticsScreenSaveDialogTitle;

  /// No description provided for @diagnosticsScreenSaved.
  ///
  /// In id, this message translates to:
  /// **'Log diagnostik tersimpan: {path}'**
  String diagnosticsScreenSaved(String path);

  /// No description provided for @diagnosticsScreenSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan log diagnostik: {error}'**
  String diagnosticsScreenSaveFailed(String error);

  /// No description provided for @diagnosticsScreenTitle.
  ///
  /// In id, this message translates to:
  /// **'Diagnostik'**
  String get diagnosticsScreenTitle;

  /// No description provided for @diagnosticsScreenRecheck.
  ///
  /// In id, this message translates to:
  /// **'Periksa ulang'**
  String get diagnosticsScreenRecheck;

  /// No description provided for @diagnosticsScreenIntro.
  ///
  /// In id, this message translates to:
  /// **'Pemeriksaan ini berjalan sepenuhnya di komputer Anda dan tidak mengirim apa pun ke internet.'**
  String get diagnosticsScreenIntro;

  /// No description provided for @diagnosticsScreenRunFailedTitle.
  ///
  /// In id, this message translates to:
  /// **'Pemeriksaan gagal dijalankan'**
  String get diagnosticsScreenRunFailedTitle;

  /// No description provided for @diagnosticsScreenRunFailedRemediation.
  ///
  /// In id, this message translates to:
  /// **'Mesin transkripsi mungkin tidak termuat. Tutup dan buka ulang aplikasi; jika tetap gagal, pasang ulang Trareon.'**
  String get diagnosticsScreenRunFailedRemediation;

  /// No description provided for @diagnosticsScreenNoChecksTitle.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada pemeriksaan yang berjalan'**
  String get diagnosticsScreenNoChecksTitle;

  /// No description provided for @diagnosticsScreenNoChecksMessage.
  ///
  /// In id, this message translates to:
  /// **'Mesin tidak mengembalikan hasil apa pun.'**
  String get diagnosticsScreenNoChecksMessage;

  /// No description provided for @diagnosticsScreenHasFailures.
  ///
  /// In id, this message translates to:
  /// **'Ada masalah yang perlu diperbaiki sebelum merekam.'**
  String get diagnosticsScreenHasFailures;

  /// No description provided for @diagnosticsScreenHasWarnings.
  ///
  /// In id, this message translates to:
  /// **'Aplikasi bisa dipakai, tapi ada hal yang sebaiknya diperiksa.'**
  String get diagnosticsScreenHasWarnings;

  /// No description provided for @diagnosticsScreenAllGood.
  ///
  /// In id, this message translates to:
  /// **'Semua siap. Aplikasi bisa merekam.'**
  String get diagnosticsScreenAllGood;

  /// Screen-reader word for the ✓ marker
  ///
  /// In id, this message translates to:
  /// **'Baik'**
  String get diagnosticsScreenSeverityOk;

  /// Screen-reader word for the ! marker
  ///
  /// In id, this message translates to:
  /// **'Perlu diperiksa'**
  String get diagnosticsScreenSeverityWarn;

  /// Screen-reader word for the ✗ marker
  ///
  /// In id, this message translates to:
  /// **'Gagal'**
  String get diagnosticsScreenSeverityFail;

  /// No description provided for @diagnosticsScreenExportTitle.
  ///
  /// In id, this message translates to:
  /// **'Log Diagnostik'**
  String get diagnosticsScreenExportTitle;

  /// Used before the number of log files is known
  ///
  /// In id, this message translates to:
  /// **'Satu berkas .zip berisi berkas log dan hasil pemeriksaan di atas. Tidak berisi transkrip, audio, atau nama berkas rapat Anda.'**
  String get diagnosticsScreenExportBody;

  /// No description provided for @diagnosticsScreenExportBodyCount.
  ///
  /// In id, this message translates to:
  /// **'Satu berkas .zip berisi {count} berkas log dan hasil pemeriksaan di atas. Tidak berisi transkrip, audio, atau nama berkas rapat Anda.'**
  String diagnosticsScreenExportBodyCount(int count);

  /// No description provided for @diagnosticsScreenExport.
  ///
  /// In id, this message translates to:
  /// **'Ekspor'**
  String get diagnosticsScreenExport;

  /// No description provided for @llmSetupWizardScreenTitle.
  ///
  /// In id, this message translates to:
  /// **'Siapkan Model AI'**
  String get llmSetupWizardScreenTitle;

  /// No description provided for @llmSetupWizardScreenNotDetected.
  ///
  /// In id, this message translates to:
  /// **'Ollama tidak terdeteksi di perangkat ini.'**
  String get llmSetupWizardScreenNotDetected;

  /// {system} is the operating system name
  ///
  /// In id, this message translates to:
  /// **'Pasang Ollama di {system}'**
  String llmSetupWizardScreenInstallOn(String system);

  /// No description provided for @llmSetupWizardScreenOpenLink.
  ///
  /// In id, this message translates to:
  /// **'Buka {url}'**
  String llmSetupWizardScreenOpenLink(String url);

  /// No description provided for @llmSetupWizardScreenInstalledRecheck.
  ///
  /// In id, this message translates to:
  /// **'Sudah dipasang, periksa ulang'**
  String get llmSetupWizardScreenInstalledRecheck;

  /// {ram} is already formatted with one decimal
  ///
  /// In id, this message translates to:
  /// **'Perangkat ini: {ram} GB RAM, {threads} thread CPU.'**
  String llmSetupWizardScreenHardware(String ram, int threads);

  /// No description provided for @llmSetupWizardScreenHardwareWithVram.
  ///
  /// In id, this message translates to:
  /// **'Perangkat ini: {ram} GB RAM, {threads} thread CPU, {vram} GB VRAM.'**
  String llmSetupWizardScreenHardwareWithVram(
    String ram,
    int threads,
    String vram,
  );

  /// No description provided for @llmSetupWizardScreenBelowMinimum.
  ///
  /// In id, this message translates to:
  /// **'Perangkat ini di bawah rekomendasi minimum; model teringan tetap ditawarkan sebagai usaha terbaik.'**
  String get llmSetupWizardScreenBelowMinimum;

  /// No description provided for @llmSetupWizardScreenChooseModel.
  ///
  /// In id, this message translates to:
  /// **'Pilih model'**
  String get llmSetupWizardScreenChooseModel;

  /// No description provided for @llmSetupWizardScreenDownload.
  ///
  /// In id, this message translates to:
  /// **'Unduh {model}'**
  String llmSetupWizardScreenDownload(String model);

  /// No description provided for @llmSetupWizardScreenDownloading.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh {model}…'**
  String llmSetupWizardScreenDownloading(String model);

  /// Screen-reader label of the download progress bar
  ///
  /// In id, this message translates to:
  /// **'Mengunduh'**
  String get llmSetupWizardScreenDownloadingShort;

  /// No description provided for @llmSetupWizardScreenPreparing.
  ///
  /// In id, this message translates to:
  /// **'Menyiapkan unduhan…'**
  String get llmSetupWizardScreenPreparing;

  /// No description provided for @llmSetupWizardScreenReady.
  ///
  /// In id, this message translates to:
  /// **'Model siap dipakai'**
  String get llmSetupWizardScreenReady;

  /// No description provided for @llmSetupWizardScreenReadyBody.
  ///
  /// In id, this message translates to:
  /// **'{model} sudah terunduh dan disetel sebagai model Ringkasan AI.'**
  String llmSetupWizardScreenReadyBody(String model);

  /// No description provided for @llmSetupWizardScreenDone.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get llmSetupWizardScreenDone;

  /// No description provided for @llmSetupWizardScreenReadyToast.
  ///
  /// In id, this message translates to:
  /// **'Model AI siap: {model}'**
  String llmSetupWizardScreenReadyToast(String model);

  /// {context} is the context window in tokens
  ///
  /// In id, this message translates to:
  /// **'{tag} · unduh {size} GB · konteks {context}'**
  String llmSetupWizardScreenModelMeta(String tag, String size, int context);

  /// No description provided for @llmSetupWizardScreenError.
  ///
  /// In id, this message translates to:
  /// **'Terjadi kesalahan: {error}'**
  String llmSetupWizardScreenError(String error);

  /// No description provided for @llmSetupWizardScreenRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get llmSetupWizardScreenRetry;

  /// No description provided for @capabilitiesScreenTitle.
  ///
  /// In id, this message translates to:
  /// **'Apa Jalan di Mana'**
  String get capabilitiesScreenTitle;

  /// No description provided for @capabilitiesScreenLoadFailed.
  ///
  /// In id, this message translates to:
  /// **'Daftar kemampuan tidak bisa dibaca: {error}'**
  String capabilitiesScreenLoadFailed(String error);

  /// No description provided for @capabilitiesScreenRunsLocal.
  ///
  /// In id, this message translates to:
  /// **'Lokal'**
  String get capabilitiesScreenRunsLocal;

  /// The summary endpoint the user configured
  ///
  /// In id, this message translates to:
  /// **'Endpoint Anda'**
  String get capabilitiesScreenRunsEndpoint;

  /// No description provided for @capabilitiesScreenRunsInternet.
  ///
  /// In id, this message translates to:
  /// **'Internet'**
  String get capabilitiesScreenRunsInternet;

  /// No description provided for @capabilitiesScreenLocalCount.
  ///
  /// In id, this message translates to:
  /// **'{local} dari {total} kemampuan berjalan sepenuhnya di komputer ini.'**
  String capabilitiesScreenLocalCount(int local, int total);

  /// No description provided for @capabilitiesScreenNetworked.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =0{Tidak ada kemampuan yang memakai jaringan.} other{{count} kemampuan bisa memakai jaringan; {active} di antaranya aktif sekarang. Perekaman, transkripsi, dan ekspor tidak termasuk, itu tidak pernah memakai jaringan.}}'**
  String capabilitiesScreenNetworked(int count, int active);

  /// No description provided for @capabilitiesScreenSourceNote.
  ///
  /// In id, this message translates to:
  /// **'Daftar ini dibuat dari sumber yang sama dengan uji privasi di rust_core/src/privacy.rs: baris yang mengaku \"Lokal\" tetapi modulnya menyentuh jaringan akan menggagalkan build.'**
  String get capabilitiesScreenSourceNote;

  /// Screen-reader label of one capability row
  ///
  /// In id, this message translates to:
  /// **'{name}. {runsAt}. {status}.'**
  String capabilitiesScreenRowSemantics(
    String name,
    String runsAt,
    String status,
  );

  /// No description provided for @capabilitiesScreenActive.
  ///
  /// In id, this message translates to:
  /// **'Aktif'**
  String get capabilitiesScreenActive;

  /// No description provided for @capabilitiesScreenInactive.
  ///
  /// In id, this message translates to:
  /// **'Tidak aktif'**
  String get capabilitiesScreenInactive;

  /// Followed by where the capability runs; keep the trailing space
  ///
  /// In id, this message translates to:
  /// **'Berjalan di: '**
  String get capabilitiesScreenRunsAt;

  /// No description provided for @capabilitiesScreenCode.
  ///
  /// In id, this message translates to:
  /// **'Kode: rust_core/src/{module}'**
  String capabilitiesScreenCode(String module);

  /// No description provided for @archiveChatScreenTitle.
  ///
  /// In id, this message translates to:
  /// **'Tanya Arsip Rapat'**
  String get archiveChatScreenTitle;

  /// No description provided for @archiveChatScreenClear.
  ///
  /// In id, this message translates to:
  /// **'Bersihkan'**
  String get archiveChatScreenClear;

  /// No description provided for @archiveChatScreenEmpty.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =0{Belum ada rapat di perpustakaan.} other{Tanyakan apa saja tentang {count} rapat yang tersimpan.}}'**
  String archiveChatScreenEmpty(int count);

  /// No description provided for @archiveChatScreenExplain.
  ///
  /// In id, this message translates to:
  /// **'\"Cari\" bekerja sepenuhnya di komputer ini. \"Jawab\" juga mengirim kutipan yang ditemukan ke endpoint ringkasan yang Anda atur, dan dicatat di Laporan Privasi.'**
  String get archiveChatScreenExplain;

  /// No description provided for @archiveChatScreenExample1.
  ///
  /// In id, this message translates to:
  /// **'Apa keputusan soal anggaran?'**
  String get archiveChatScreenExample1;

  /// No description provided for @archiveChatScreenExample2.
  ///
  /// In id, this message translates to:
  /// **'Siapa penanggung jawab laporan keuangan?'**
  String get archiveChatScreenExample2;

  /// No description provided for @archiveChatScreenExample3.
  ///
  /// In id, this message translates to:
  /// **'Kapan tenggat peluncuran?'**
  String get archiveChatScreenExample3;

  /// No description provided for @archiveChatScreenSources.
  ///
  /// In id, this message translates to:
  /// **'Kutipan'**
  String get archiveChatScreenSources;

  /// A citation that points at a meeting's summary rather than a moment
  ///
  /// In id, this message translates to:
  /// **'{title} ({date}) · ringkasan'**
  String archiveChatScreenSourceSummary(String title, String date);

  /// No description provided for @archiveChatScreenHint.
  ///
  /// In id, this message translates to:
  /// **'Tanyakan sesuatu tentang rapat-rapat Anda…'**
  String get archiveChatScreenHint;

  /// No description provided for @archiveChatScreenSearch.
  ///
  /// In id, this message translates to:
  /// **'Cari'**
  String get archiveChatScreenSearch;

  /// No description provided for @archiveChatScreenAnswer.
  ///
  /// In id, this message translates to:
  /// **'Jawab'**
  String get archiveChatScreenAnswer;

  /// No description provided for @redactionPreviewTitle.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau penyamaran'**
  String get redactionPreviewTitle;

  /// No description provided for @redactionPreviewClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get redactionPreviewClose;

  /// No description provided for @redactionPreviewFailed.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau gagal: {error}'**
  String redactionPreviewFailed(String error);

  /// No description provided for @redactionPreviewNoneFound.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada data pribadi yang terdeteksi. File hasil ekspor akan sama persis dengan transkrip.'**
  String get redactionPreviewNoneFound;

  /// No description provided for @redactionPreviewNothing.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang akan disamarkan.'**
  String get redactionPreviewNothing;

  /// One category in the redaction summary, e.g. "3 NIK"
  ///
  /// In id, this message translates to:
  /// **'{count} {kind}'**
  String redactionPreviewSummaryPart(int count, String kind);

  /// {parts} is a comma-separated list of redactionPreviewSummaryPart
  ///
  /// In id, this message translates to:
  /// **'{parts} akan disamarkan.'**
  String redactionPreviewSummary(String parts);

  /// No description provided for @redactionPreviewKindPhone.
  ///
  /// In id, this message translates to:
  /// **'Nomor telepon'**
  String get redactionPreviewKindPhone;

  /// No description provided for @redactionPreviewKindEmail.
  ///
  /// In id, this message translates to:
  /// **'Alamat email'**
  String get redactionPreviewKindEmail;

  /// No description provided for @redactionPreviewKindBankAccount.
  ///
  /// In id, this message translates to:
  /// **'Nomor rekening'**
  String get redactionPreviewKindBankAccount;

  /// No description provided for @redactionPreviewKindName.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get redactionPreviewKindName;

  /// No description provided for @liveQaPanelTitle.
  ///
  /// In id, this message translates to:
  /// **'Tanya Langsung'**
  String get liveQaPanelTitle;

  /// No description provided for @liveQaPanelHint.
  ///
  /// In id, this message translates to:
  /// **'Tanyakan sesuatu tentang rapat ini…'**
  String get liveQaPanelHint;

  /// No description provided for @liveQaPanelAsk.
  ///
  /// In id, this message translates to:
  /// **'Tanya'**
  String get liveQaPanelAsk;

  /// No description provided for @liveQaPanelEmpty.
  ///
  /// In id, this message translates to:
  /// **'Tanyakan apa saja yang sudah dibahas di rapat ini sejauh ini.'**
  String get liveQaPanelEmpty;

  /// No description provided for @liveQaPanelPrivacy.
  ///
  /// In id, this message translates to:
  /// **'Jawaban dikirim ke endpoint ringkasan yang Anda atur di Pengaturan → Ringkasan AI, dan dicatat di Laporan Privasi.'**
  String get liveQaPanelPrivacy;

  /// No description provided for @liveQaPanelSources.
  ///
  /// In id, this message translates to:
  /// **'Kutipan transkrip'**
  String get liveQaPanelSources;

  /// No description provided for @recordButtonSaving.
  ///
  /// In id, this message translates to:
  /// **'Menyimpan…'**
  String get recordButtonSaving;

  /// No description provided for @recordButtonResume.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan'**
  String get recordButtonResume;

  /// No description provided for @recordButtonStop.
  ///
  /// In id, this message translates to:
  /// **'Berhenti'**
  String get recordButtonStop;

  /// No description provided for @recordButtonStart.
  ///
  /// In id, this message translates to:
  /// **'Mulai Rekam'**
  String get recordButtonStart;

  /// No description provided for @recordButtonResumeSemantics.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan rekaman'**
  String get recordButtonResumeSemantics;

  /// No description provided for @recordButtonStopSemantics.
  ///
  /// In id, this message translates to:
  /// **'Berhenti merekam'**
  String get recordButtonStopSemantics;

  /// No description provided for @recordButtonStartSemantics.
  ///
  /// In id, this message translates to:
  /// **'Mulai merekam'**
  String get recordButtonStartSemantics;

  /// No description provided for @appDialogClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get appDialogClose;

  /// Screen-reader label of the dimmed area behind a dialog
  ///
  /// In id, this message translates to:
  /// **'Tutup dialog'**
  String get appDialogBarrierLabel;

  /// Default confirm button of a confirmation dialog
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan'**
  String get appDialogContinue;

  /// No description provided for @trayServiceOpen.
  ///
  /// In id, this message translates to:
  /// **'Buka Trareon Transcribe'**
  String get trayServiceOpen;

  /// No description provided for @trayServiceQuit.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get trayServiceQuit;

  /// No description provided for @personalNotesPanelTitle.
  ///
  /// In id, this message translates to:
  /// **'Catatan Pribadi'**
  String get personalNotesPanelTitle;

  /// "Enhance" is the name of the feature button; keep it
  ///
  /// In id, this message translates to:
  /// **'Tersimpan otomatis. Enhance nanti menggabungkannya dengan transkrip.'**
  String get personalNotesPanelSubtitle;

  /// No description provided for @personalNotesPanelHint.
  ///
  /// In id, this message translates to:
  /// **'mis. PENTING: deadline Jumat…'**
  String get personalNotesPanelHint;

  /// Why the audio tuning is what it is: the user set the switches by hand
  ///
  /// In id, this message translates to:
  /// **'Dipilih manual'**
  String get qualityProfileReasonManual;

  /// No description provided for @qualityProfileReasonUnmeasured.
  ///
  /// In id, this message translates to:
  /// **'Belum terukur; pengaturan konservatif dipakai'**
  String get qualityProfileReasonUnmeasured;

  /// No description provided for @qualityProfileReasonClean.
  ///
  /// In id, this message translates to:
  /// **'Ruangan bersih; derau dan AGC dimatikan agar tidak memakan kata'**
  String get qualityProfileReasonClean;

  /// No description provided for @qualityProfileReasonLightNoiseGain.
  ///
  /// In id, this message translates to:
  /// **'Derau ringan; hanya level yang dinaikkan'**
  String get qualityProfileReasonLightNoiseGain;

  /// No description provided for @qualityProfileReasonLightNoiseNoGain.
  ///
  /// In id, this message translates to:
  /// **'Derau ringan; level sudah cukup, gain tidak dipakai'**
  String get qualityProfileReasonLightNoiseNoGain;

  /// No description provided for @qualityProfileReasonNoisy.
  ///
  /// In id, this message translates to:
  /// **'Derau tinggi; pengurangan derau dinyalakan'**
  String get qualityProfileReasonNoisy;

  /// Minutes length preset, about 250 words
  ///
  /// In id, this message translates to:
  /// **'Ringkas'**
  String get notulenGenerationLengthShort;

  /// Minutes length preset, about 1000 words
  ///
  /// In id, this message translates to:
  /// **'Sedang'**
  String get notulenGenerationLengthMedium;

  /// Minutes length preset, about 3000 words
  ///
  /// In id, this message translates to:
  /// **'Lengkap'**
  String get notulenGenerationLengthFull;

  /// "Tanya Langsung" is the feature that answers questions about the meeting still being recorded
  ///
  /// In id, this message translates to:
  /// **'Tanya Langsung memerlukan endpoint ringkasan yang sudah diatur di Pengaturan → Ringkasan AI.'**
  String get liveQaModelNeedsEndpoint;

  /// Privacy Report event line; a timestamp is appended after a comma
  ///
  /// In id, this message translates to:
  /// **'Mengunduh model \"{modelId}\" dari huggingface.co'**
  String privacyReportModelEventModelDownload(String modelId);

  /// Privacy Report event line
  ///
  /// In id, this message translates to:
  /// **'Ringkasan AI dikirim ke {endpoint}'**
  String privacyReportModelEventSummary(String endpoint);

  /// Privacy Report event line
  ///
  /// In id, this message translates to:
  /// **'Pertanyaan arsip dikirim ke {endpoint} ({passageCount, plural, other{{passageCount} kutipan rapat}})'**
  String privacyReportModelEventArchiveQuestion(
    String endpoint,
    int passageCount,
  );

  /// Privacy Report event line
  ///
  /// In id, this message translates to:
  /// **'Pertanyaan Tanya Langsung dikirim ke {endpoint} ({passageCount, plural, other{{passageCount} kutipan transkrip}})'**
  String privacyReportModelEventLiveQaQuestion(
    String endpoint,
    int passageCount,
  );

  /// Privacy Report event line
  ///
  /// In id, this message translates to:
  /// **'Memeriksa pembaruan ke {endpoint}'**
  String privacyReportModelEventUpdateCheck(String endpoint);

  /// Privacy Report event line
  ///
  /// In id, this message translates to:
  /// **'Membuka {url} di peramban'**
  String privacyReportModelEventExternalLink(String url);

  /// Screen-reader label of the playback scrubber
  ///
  /// In id, this message translates to:
  /// **'Garis waktu rekaman'**
  String get speechTimelineSemanticLabel;

  /// Screen-reader value of the playback scrubber
  ///
  /// In id, this message translates to:
  /// **'{percent} persen'**
  String speechTimelinePercent(int percent);

  /// Toast while recording when the mic returns pure digital silence
  ///
  /// In id, this message translates to:
  /// **'Mikrofon belum diberi izin, atau tidak mengirim suara sama sekali. Periksa izin Mikrofon di Pengaturan Sistem.'**
  String get audioWatchdogModelMicSilent;

  /// Quoted text is the macOS privacy permission name
  ///
  /// In id, this message translates to:
  /// **'Audio sistem tidak terdeteksi sama sekali. Periksa izin \"Rekam Layar & Audio Sistem\" di Pengaturan Sistem.'**
  String get audioWatchdogModelSystemAudioSilent;

  /// No description provided for @audioWatchdogModelBothSilent.
  ///
  /// In id, this message translates to:
  /// **'Mikrofon maupun audio sistem belum diberi izin. Periksa Pengaturan Sistem untuk Mikrofon dan \"Rekam Layar & Audio Sistem\".'**
  String get audioWatchdogModelBothSilent;

  /// No description provided for @audioWatchdogModelNoSound.
  ///
  /// In id, this message translates to:
  /// **'Belum ada suara terdeteksi. Periksa izin Mikrofon dan \"Rekam Layar & Audio Sistem\" di Pengaturan Sistem, atau pastikan sumber audio yang dipilih sudah benar.'**
  String get audioWatchdogModelNoSound;

  /// No description provided for @modelDownloadDialogDownloading.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh…'**
  String get modelDownloadDialogDownloading;

  /// No description provided for @modelDownloadDialogDownloadingName.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh {name}…'**
  String modelDownloadDialogDownloadingName(String name);

  /// No description provided for @modelDownloadDialogDownloadingProgress.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh {name}… {percent}%'**
  String modelDownloadDialogDownloadingProgress(String name, int percent);

  /// No description provided for @modelDownloadDialogFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengunduh: {error}'**
  String modelDownloadDialogFailed(String error);

  /// Dialog title; name is the model display name
  ///
  /// In id, this message translates to:
  /// **'Unduh {name}'**
  String modelDownloadDialogTitle(String name);

  /// No description provided for @modelDownloadDialogPrompt.
  ///
  /// In id, this message translates to:
  /// **'{name} belum diunduh. Apakah Anda ingin mengunduh sekarang?'**
  String modelDownloadDialogPrompt(String name);

  /// Button that starts a model download
  ///
  /// In id, this message translates to:
  /// **'Unduh'**
  String get modelDownloadDialogDownload;

  /// No description provided for @retranscribeDialogEngineFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal transkrip ulang: {error}. Transkrip lama tetap dipertahankan.'**
  String retranscribeDialogEngineFailed(String error);

  /// No description provided for @retranscribeDialogNoSpeech.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada ucapan terdeteksi. Transkrip lama tetap dipertahankan.'**
  String get retranscribeDialogNoSpeech;

  /// No description provided for @retranscribeDialogFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal transkrip ulang (transkrip lama tetap aman): {error}'**
  String retranscribeDialogFailed(String error);

  /// No description provided for @retranscribeDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Transkrip Ulang'**
  String get retranscribeDialogTitle;

  /// No description provided for @retranscribeDialogDescription.
  ///
  /// In id, this message translates to:
  /// **'Audio asli akan ditranskrip ulang. Transkrip lama diganti hanya kalau proses berhasil.'**
  String get retranscribeDialogDescription;

  /// No description provided for @retranscribeDialogModelLabel.
  ///
  /// In id, this message translates to:
  /// **'Kualitas model'**
  String get retranscribeDialogModelLabel;

  /// Transcription language for the re-run
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get retranscribeDialogLanguageLabel;

  /// Transcription language option
  ///
  /// In id, this message translates to:
  /// **'Deteksi otomatis'**
  String get retranscribeDialogAutoDetect;

  /// Transcription language option
  ///
  /// In id, this message translates to:
  /// **'Indonesia'**
  String get retranscribeDialogIndonesian;

  /// No description provided for @retranscribeDialogNoModels.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada model terpasang.'**
  String get retranscribeDialogNoModels;

  /// No description provided for @retranscribeDialogProcessing.
  ///
  /// In id, this message translates to:
  /// **'Memproses… ini bisa memakan waktu untuk rekaman panjang.'**
  String get retranscribeDialogProcessing;

  /// Starts the re-transcription
  ///
  /// In id, this message translates to:
  /// **'Mulai'**
  String get retranscribeDialogStart;

  /// No description provided for @auditLogViewTitle.
  ///
  /// In id, this message translates to:
  /// **'Log audit'**
  String get auditLogViewTitle;

  /// No description provided for @auditLogViewClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get auditLogViewClose;

  /// No description provided for @auditLogViewReadError.
  ///
  /// In id, this message translates to:
  /// **'Log audit tidak bisa dibaca: {error}'**
  String auditLogViewReadError(String error);

  /// No description provided for @auditLogViewEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada catatan. Log terisi saat sesi dibuat, transkrip diekspor, atau data dihapus.'**
  String get auditLogViewEmpty;

  /// Audit-log action label in the viewer (the log file itself is not translated)
  ///
  /// In id, this message translates to:
  /// **'Sesi dibuat'**
  String get auditLogViewActionSessionCreated;

  /// No description provided for @auditLogViewActionSessionExported.
  ///
  /// In id, this message translates to:
  /// **'Transkrip diekspor'**
  String get auditLogViewActionSessionExported;

  /// No description provided for @auditLogViewActionSummarySent.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan dikirim ke endpoint'**
  String get auditLogViewActionSummarySent;

  /// No description provided for @auditLogViewActionSessionDeleted.
  ///
  /// In id, this message translates to:
  /// **'Sesi dihapus'**
  String get auditLogViewActionSessionDeleted;

  /// No description provided for @auditLogViewActionAudioDeleted.
  ///
  /// In id, this message translates to:
  /// **'Audio dihapus'**
  String get auditLogViewActionAudioDeleted;

  /// No description provided for @auditLogViewActionTranscriptDeleted.
  ///
  /// In id, this message translates to:
  /// **'Transkrip dihapus'**
  String get auditLogViewActionTranscriptDeleted;

  /// No description provided for @auditLogViewActionConsentAcknowledged.
  ///
  /// In id, this message translates to:
  /// **'Pemberitahuan perekaman disampaikan'**
  String get auditLogViewActionConsentAcknowledged;

  /// No description provided for @auditLogViewActionRedactionApplied.
  ///
  /// In id, this message translates to:
  /// **'Penyamaran data pribadi diterapkan'**
  String get auditLogViewActionRedactionApplied;

  /// No description provided for @auditLogViewActionRetentionApplied.
  ///
  /// In id, this message translates to:
  /// **'Kebijakan retensi dijalankan'**
  String get auditLogViewActionRetentionApplied;

  /// No description provided for @auditLogViewActionAuditExported.
  ///
  /// In id, this message translates to:
  /// **'Log audit diekspor'**
  String get auditLogViewActionAuditExported;

  /// No description provided for @auditLogViewActionModelPulled.
  ///
  /// In id, this message translates to:
  /// **'Model notulen diunduh'**
  String get auditLogViewActionModelPulled;

  /// No description provided for @auditLogViewActionDocumentContextUsed.
  ///
  /// In id, this message translates to:
  /// **'Konteks dokumen digunakan'**
  String get auditLogViewActionDocumentContextUsed;

  /// No description provided for @auditLogViewActionTranscriptEnhanced.
  ///
  /// In id, this message translates to:
  /// **'Transkrip diperhalus otomatis'**
  String get auditLogViewActionTranscriptEnhanced;

  /// First-run greeting. Keep the product name spelled exactly "Trareon Transcribe".
  ///
  /// In id, this message translates to:
  /// **'Selamat datang di Trareon Transcribe'**
  String get onboardingScreenWelcome;

  /// No description provided for @onboardingScreenReady.
  ///
  /// In id, this message translates to:
  /// **'Siap merekam'**
  String get onboardingScreenReady;

  /// No description provided for @onboardingScreenPostponed.
  ///
  /// In id, this message translates to:
  /// **'Unduhan ditunda'**
  String get onboardingScreenPostponed;

  /// No description provided for @onboardingScreenNeedsDownload.
  ///
  /// In id, this message translates to:
  /// **'Model perlu diunduh'**
  String get onboardingScreenNeedsDownload;

  /// No description provided for @onboardingScreenDownloading.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh model'**
  String get onboardingScreenDownloading;

  /// No description provided for @onboardingScreenReadyBody.
  ///
  /// In id, this message translates to:
  /// **'Kedua model sudah ada di perangkat ini. Transkripsi berjalan sepenuhnya offline.'**
  String get onboardingScreenReadyBody;

  /// No description provided for @onboardingScreenOfflineBody.
  ///
  /// In id, this message translates to:
  /// **'Trareon bekerja 100% offline, jadi modelnya perlu ada di perangkat Anda. Hanya sekali.'**
  String get onboardingScreenOfflineBody;

  /// No description provided for @onboardingScreenRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba Lagi'**
  String get onboardingScreenRetry;

  /// No description provided for @onboardingScreenDownloadNow.
  ///
  /// In id, this message translates to:
  /// **'Unduh sekarang'**
  String get onboardingScreenDownloadNow;

  /// No description provided for @onboardingScreenContinueWithoutModels.
  ///
  /// In id, this message translates to:
  /// **'Masuk tanpa model'**
  String get onboardingScreenContinueWithoutModels;

  /// No description provided for @onboardingScreenStartRecording.
  ///
  /// In id, this message translates to:
  /// **'Mulai Merekam'**
  String get onboardingScreenStartRecording;

  /// Disabled button while the download consent dialog is open
  ///
  /// In id, this message translates to:
  /// **'Menunggu izin unduh'**
  String get onboardingScreenAwaitingConsent;

  /// No description provided for @onboardingScreenDownloadingButton.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh…'**
  String get onboardingScreenDownloadingButton;

  /// No description provided for @onboardingScreenFooterReady.
  ///
  /// In id, this message translates to:
  /// **'Model tidak akan pernah dikirim ke mana pun.'**
  String get onboardingScreenFooterReady;

  /// No description provided for @onboardingScreenFooterPostponed.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang diunduh. Tanpa model, rekaman belum bisa ditranskripsi; ajakan mengunduh muncul lagi saat Anda mulai merekam.'**
  String get onboardingScreenFooterPostponed;

  /// No description provided for @onboardingScreenFooterWaiting.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang diunduh sebelum Anda setuju.'**
  String get onboardingScreenFooterWaiting;

  /// No description provided for @onboardingScreenFooterDownloading.
  ///
  /// In id, this message translates to:
  /// **'Anda boleh menutup aplikasi, unduhan dilanjutkan di latar belakang.'**
  String get onboardingScreenFooterDownloading;

  /// First-run progress strip, step 1
  ///
  /// In id, this message translates to:
  /// **'Izin mikrofon & audio sistem'**
  String get onboardingScreenStepPermissions;

  /// First-run progress strip, step 2
  ///
  /// In id, this message translates to:
  /// **'Pilih model'**
  String get onboardingScreenStepModel;

  /// First-run progress strip, step 3
  ///
  /// In id, this message translates to:
  /// **'Siap rekam'**
  String get onboardingScreenStepReady;

  /// Screen-reader label of the first-run progress strip
  ///
  /// In id, this message translates to:
  /// **'Langkah {step} dari {total}: {label}'**
  String onboardingScreenStepSemantics(int step, int total, String label);

  /// No description provided for @onboardingScreenQuickModelTitle.
  ///
  /// In id, this message translates to:
  /// **'Model Cepat'**
  String get onboardingScreenQuickModelTitle;

  /// No description provided for @onboardingScreenQuickModelSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Transkripsi cepat, akurasi Bahasa Indonesia maksimal'**
  String get onboardingScreenQuickModelSubtitle;

  /// No description provided for @onboardingScreenAccurateModelTitle.
  ///
  /// In id, this message translates to:
  /// **'Model Akurat'**
  String get onboardingScreenAccurateModelTitle;

  /// No description provided for @onboardingScreenAccurateModelSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Menyempurnakan transkrip di latar belakang, akurasi global terbaik'**
  String get onboardingScreenAccurateModelSubtitle;

  /// No description provided for @sessionModelSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Sesi berhenti, tapi gagal menyimpan transkrip ke {outputDir}: {error}'**
  String sessionModelSaveFailed(String outputDir, String error);

  /// Settings banner after a failed write; label is one of the settingsModelLabel* names
  ///
  /// In id, this message translates to:
  /// **'Pengaturan \"{label}\" gagal disimpan: {message}. Perubahan dikembalikan.'**
  String settingsModelSaveFailed(String label, String message);

  /// Setting name shown in the save-failure banner
  ///
  /// In id, this message translates to:
  /// **'Tema'**
  String get settingsModelLabelTheme;

  /// No description provided for @settingsModelLabelProgressive.
  ///
  /// In id, this message translates to:
  /// **'Cepat dulu, lalu diperhalus'**
  String get settingsModelLabelProgressive;

  /// No description provided for @settingsModelLabelGpu.
  ///
  /// In id, this message translates to:
  /// **'Akselerasi GPU'**
  String get settingsModelLabelGpu;

  /// No description provided for @settingsModelLabelGpuDevice.
  ///
  /// In id, this message translates to:
  /// **'Perangkat GPU'**
  String get settingsModelLabelGpuDevice;

  /// No description provided for @settingsModelLabelBenchmark.
  ///
  /// In id, this message translates to:
  /// **'Skor benchmark'**
  String get settingsModelLabelBenchmark;

  /// No description provided for @settingsModelLabelHptMode.
  ///
  /// In id, this message translates to:
  /// **'Cara transkripsi bertahap'**
  String get settingsModelLabelHptMode;

  /// No description provided for @settingsModelLabelSummary.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan AI'**
  String get settingsModelLabelSummary;

  /// No description provided for @settingsModelLabelGlossary.
  ///
  /// In id, this message translates to:
  /// **'Kamus istilah'**
  String get settingsModelLabelGlossary;

  /// No description provided for @settingsModelLabelNeuralDiarization.
  ///
  /// In id, this message translates to:
  /// **'Pemisahan pembicara akurat'**
  String get settingsModelLabelNeuralDiarization;

  /// No description provided for @settingsModelLabelEngineModels.
  ///
  /// In id, this message translates to:
  /// **'Model mesin'**
  String get settingsModelLabelEngineModels;

  /// No description provided for @settingsModelLabelPdp.
  ///
  /// In id, this message translates to:
  /// **'Mode Kepatuhan PDP'**
  String get settingsModelLabelPdp;

  /// No description provided for @settingsModelLabelSummaryTemplates.
  ///
  /// In id, this message translates to:
  /// **'Template ringkasan'**
  String get settingsModelLabelSummaryTemplates;

  /// No description provided for @settingsModelLabelNotulenLetterhead.
  ///
  /// In id, this message translates to:
  /// **'Kop surat notulen'**
  String get settingsModelLabelNotulenLetterhead;

  /// No description provided for @settingsModelLabelAutoRetranscribe.
  ///
  /// In id, this message translates to:
  /// **'Perhalus transkrip otomatis'**
  String get settingsModelLabelAutoRetranscribe;

  /// No description provided for @settingsModelLabelDefaultModel.
  ///
  /// In id, this message translates to:
  /// **'Model default'**
  String get settingsModelLabelDefaultModel;

  /// Setting name: the transcription language (not the UI language)
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get settingsModelLabelLanguage;

  /// No description provided for @settingsModelLabelDefaultMode.
  ///
  /// In id, this message translates to:
  /// **'Mode default'**
  String get settingsModelLabelDefaultMode;

  /// No description provided for @settingsModelLabelVad.
  ///
  /// In id, this message translates to:
  /// **'Abaikan jeda sunyi'**
  String get settingsModelLabelVad;

  /// No description provided for @settingsModelLabelNoiseReduction.
  ///
  /// In id, this message translates to:
  /// **'Pengurangan derau'**
  String get settingsModelLabelNoiseReduction;

  /// No description provided for @settingsModelLabelAgc.
  ///
  /// In id, this message translates to:
  /// **'Penguatan suara otomatis'**
  String get settingsModelLabelAgc;

  /// No description provided for @settingsModelLabelAutoAudioTuning.
  ///
  /// In id, this message translates to:
  /// **'Penyetelan audio otomatis'**
  String get settingsModelLabelAutoAudioTuning;

  /// No description provided for @settingsModelLabelSimpleMode.
  ///
  /// In id, this message translates to:
  /// **'Mode Sederhana'**
  String get settingsModelLabelSimpleMode;

  /// No description provided for @settingsModelLabelDeferDownloads.
  ///
  /// In id, this message translates to:
  /// **'Tunda unduhan'**
  String get settingsModelLabelDeferDownloads;

  /// No description provided for @settingsModelLabelUpgradeOffer.
  ///
  /// In id, this message translates to:
  /// **'Tawaran tingkatkan akurasi'**
  String get settingsModelLabelUpgradeOffer;

  /// No description provided for @settingsModelLabelConsentReminder.
  ///
  /// In id, this message translates to:
  /// **'Pengingat persetujuan perekaman'**
  String get settingsModelLabelConsentReminder;

  /// No description provided for @settingsModelLabelAutoStop.
  ///
  /// In id, this message translates to:
  /// **'Berhenti sendiri saat sunyi'**
  String get settingsModelLabelAutoStop;

  /// No description provided for @settingsModelLabelExportFormat.
  ///
  /// In id, this message translates to:
  /// **'Format ekspor default'**
  String get settingsModelLabelExportFormat;

  /// No description provided for @settingsModelLabelOutputFolder.
  ///
  /// In id, this message translates to:
  /// **'Folder output'**
  String get settingsModelLabelOutputFolder;

  /// No description provided for @settingsModelLabelMicrophone.
  ///
  /// In id, this message translates to:
  /// **'Mikrofon'**
  String get settingsModelLabelMicrophone;

  /// No description provided for @settingsModelLabelSpeaker.
  ///
  /// In id, this message translates to:
  /// **'Pengeras suara'**
  String get settingsModelLabelSpeaker;

  /// Label of the session control group
  ///
  /// In id, this message translates to:
  /// **'Sesi'**
  String get sessionControlsSessionGroup;

  /// No description provided for @sessionControlsTitlePlaceholder.
  ///
  /// In id, this message translates to:
  /// **'Judul sesi…'**
  String get sessionControlsTitlePlaceholder;

  /// Screen-reader label of the capture-mode selector
  ///
  /// In id, this message translates to:
  /// **'Mode sesi'**
  String get sessionControlsModeSemantics;

  /// Before the attendee chips imported from a calendar invite
  ///
  /// In id, this message translates to:
  /// **'Peserta:'**
  String get sessionControlsAttendees;

  /// Screen-reader label for the in-room meeting capture mode
  ///
  /// In id, this message translates to:
  /// **'Mode rapat offline: hanya mikrofon'**
  String get sessionControlsModeOfflineSemantics;

  /// No description provided for @sessionControlsModeOnlineSemantics.
  ///
  /// In id, this message translates to:
  /// **'Mode rapat online: mikrofon dan suara sistem'**
  String get sessionControlsModeOnlineSemantics;

  /// No description provided for @sessionControlsModeWebinarSemantics.
  ///
  /// In id, this message translates to:
  /// **'Mode webinar: hanya suara sistem'**
  String get sessionControlsModeWebinarSemantics;

  /// No description provided for @sessionControlsModeOfflineExplanation.
  ///
  /// In id, this message translates to:
  /// **'Rapat di satu ruangan. Hanya mikrofon yang direkam.'**
  String get sessionControlsModeOfflineExplanation;

  /// No description provided for @sessionControlsModeOnlineExplanation.
  ///
  /// In id, this message translates to:
  /// **'Zoom, Meet atau Teams. Mikrofon dan suara sistem.'**
  String get sessionControlsModeOnlineExplanation;

  /// No description provided for @sessionControlsModeWebinarExplanation.
  ///
  /// In id, this message translates to:
  /// **'Anda hanya menyimak. Hanya suara sistem.'**
  String get sessionControlsModeWebinarExplanation;

  /// No description provided for @sessionControlsGlossaryTooltip.
  ///
  /// In id, this message translates to:
  /// **'Istilah khusus rapat ini, di atas {globalCount} istilah di Pengaturan'**
  String sessionControlsGlossaryTooltip(int globalCount);

  /// No description provided for @sessionControlsGlossarySemanticsEmpty.
  ///
  /// In id, this message translates to:
  /// **'Istilah rapat, belum ada'**
  String get sessionControlsGlossarySemanticsEmpty;

  /// No description provided for @sessionControlsGlossarySemanticsCount.
  ///
  /// In id, this message translates to:
  /// **'Istilah rapat, {count, plural, other{{count} istilah}}'**
  String sessionControlsGlossarySemanticsCount(int count);

  /// Button that opens the per-meeting glossary
  ///
  /// In id, this message translates to:
  /// **'Istilah rapat'**
  String get sessionControlsGlossaryPill;

  /// No description provided for @sessionControlsGlossaryPillCount.
  ///
  /// In id, this message translates to:
  /// **'Istilah rapat ({count})'**
  String sessionControlsGlossaryPillCount(int count);

  /// No description provided for @sessionControlsGlossaryDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Istilah khusus rapat ini'**
  String get sessionControlsGlossaryDialogTitle;

  /// No description provided for @sessionControlsGlossaryDialogDescription.
  ///
  /// In id, this message translates to:
  /// **'Satu istilah per baris: nama peserta, singkatan, nama program. Diutamakan di atas kamus di Pengaturan.'**
  String get sessionControlsGlossaryDialogDescription;

  /// No description provided for @sessionControlsOptionsTooltip.
  ///
  /// In id, this message translates to:
  /// **'Opsi sesi'**
  String get sessionControlsOptionsTooltip;

  /// No description provided for @sessionControlsQualityHeader.
  ///
  /// In id, this message translates to:
  /// **'Kualitas transkripsi'**
  String get sessionControlsQualityHeader;

  /// No description provided for @sessionControlsSkipSilence.
  ///
  /// In id, this message translates to:
  /// **'Lewati jeda sunyi'**
  String get sessionControlsSkipSilence;

  /// No description provided for @sessionControlsLanguageHeader.
  ///
  /// In id, this message translates to:
  /// **'Bahasa rapat ini'**
  String get sessionControlsLanguageHeader;

  /// No description provided for @sessionControlsLanguageAuto.
  ///
  /// In id, this message translates to:
  /// **'Otomatis (deteksi per kalimat)'**
  String get sessionControlsLanguageAuto;

  /// Meeting language option
  ///
  /// In id, this message translates to:
  /// **'Indonesia'**
  String get sessionControlsLanguageIndonesian;

  /// Meeting language option
  ///
  /// In id, this message translates to:
  /// **'Inggris'**
  String get sessionControlsLanguageEnglish;

  /// No description provided for @sessionControlsLanguageMismatch.
  ///
  /// In id, this message translates to:
  /// **'Banyak kalimat terakhir terdeteksi bukan bahasa yang dipilih untuk sesi ini.'**
  String get sessionControlsLanguageMismatch;

  /// No description provided for @sessionControlsSwitchToAuto.
  ///
  /// In id, this message translates to:
  /// **'Ganti ke Otomatis'**
  String get sessionControlsSwitchToAuto;

  /// No description provided for @sessionControlsConsentReminder.
  ///
  /// In id, this message translates to:
  /// **'Pastikan semua peserta tahu rapat ini direkam.'**
  String get sessionControlsConsentReminder;

  /// No description provided for @sessionControlsDontShowAgain.
  ///
  /// In id, this message translates to:
  /// **'Jangan tampilkan lagi'**
  String get sessionControlsDontShowAgain;

  /// No description provided for @sessionControlsMicrophone.
  ///
  /// In id, this message translates to:
  /// **'Mikrofon'**
  String get sessionControlsMicrophone;

  /// No description provided for @sessionControlsSystemAudio.
  ///
  /// In id, this message translates to:
  /// **'Suara sistem'**
  String get sessionControlsSystemAudio;

  /// Label of the capture device control group
  ///
  /// In id, this message translates to:
  /// **'Perangkat'**
  String get sessionControlsDevicesGroup;

  /// Shown when no explicit capture device is picked
  ///
  /// In id, this message translates to:
  /// **'Bawaan sistem'**
  String get sessionControlsSystemDefault;

  /// Screen-reader label of a capture-source switch; label is Microphone or System audio
  ///
  /// In id, this message translates to:
  /// **'{label} aktif'**
  String sessionControlsDeviceOn(String label);

  /// No description provided for @sessionControlsDeviceOff.
  ///
  /// In id, this message translates to:
  /// **'{label} nonaktif'**
  String sessionControlsDeviceOff(String label);

  /// No description provided for @sessionControlsChooseDevice.
  ///
  /// In id, this message translates to:
  /// **'Pilih perangkat {label}'**
  String sessionControlsChooseDevice(String label);

  /// No description provided for @sessionControlsDeviceAuto.
  ///
  /// In id, this message translates to:
  /// **'Otomatis (bawaan sistem)'**
  String get sessionControlsDeviceAuto;

  /// No description provided for @sessionControlsReloadDevices.
  ///
  /// In id, this message translates to:
  /// **'Muat ulang daftar perangkat {label}'**
  String sessionControlsReloadDevices(String label);

  /// Screen-reader label of a live audio level meter
  ///
  /// In id, this message translates to:
  /// **'Level {label}'**
  String sessionControlsLevel(String label);

  /// Bullet in the quit confirmation
  ///
  /// In id, this message translates to:
  /// **'Rekaman masih berjalan.'**
  String get mainScreenQuitReasonRecording;

  /// Bullet in the quit confirmation
  ///
  /// In id, this message translates to:
  /// **'{count, plural, other{{count} rekaman masih diselesaikan transkripnya, pekerjaan ini dilanjutkan otomatis saat aplikasi dibuka lagi.}}'**
  String mainScreenQuitReasonOutstanding(int count);

  /// Bullet in the quit confirmation
  ///
  /// In id, this message translates to:
  /// **'Masih ada transkrip yang sedang diperhalus.'**
  String get mainScreenQuitReasonRefining;

  /// No description provided for @mainScreenQuitTitle.
  ///
  /// In id, this message translates to:
  /// **'Keluar sekarang?'**
  String get mainScreenQuitTitle;

  /// No description provided for @mainScreenQuitStay.
  ///
  /// In id, this message translates to:
  /// **'Tetap di aplikasi'**
  String get mainScreenQuitStay;

  /// No description provided for @mainScreenQuit.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get mainScreenQuit;

  /// No description provided for @mainScreenMeetingDetectedTitle.
  ///
  /// In id, this message translates to:
  /// **'Rapat terdeteksi'**
  String get mainScreenMeetingDetectedTitle;

  /// app is the meeting app, e.g. Zoom
  ///
  /// In id, this message translates to:
  /// **'Terdeteksi rapat ({app}). Mulai rekam?'**
  String mainScreenMeetingDetectedBody(String app);

  /// No description provided for @mainScreenIgnore.
  ///
  /// In id, this message translates to:
  /// **'Abaikan'**
  String get mainScreenIgnore;

  /// No description provided for @mainScreenStartRecording.
  ///
  /// In id, this message translates to:
  /// **'Mulai Rekam'**
  String get mainScreenStartRecording;

  /// No description provided for @mainScreenSilenceTitle.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada suara'**
  String get mainScreenSilenceTitle;

  /// No description provided for @mainScreenSilenceBody.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada suara selama {minutes, plural, other{{minutes} menit}}. Rekaman akan berhenti otomatis kecuali dilanjutkan.'**
  String mainScreenSilenceBody(int minutes);

  /// Keeps recording after the silence warning
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan'**
  String get mainScreenContinue;

  /// detail is a sentence from the engine about free space
  ///
  /// In id, this message translates to:
  /// **'Ruang disk di {path} tidak cukup untuk merekam. {detail} Kosongkan ruang atau ubah lokasi perpustakaan di Pengaturan.'**
  String mainScreenDiskFull(String path, String detail);

  /// Folder picker title
  ///
  /// In id, this message translates to:
  /// **'Simpan transkrip ke folder lain'**
  String get mainScreenSaveElsewhereDialogTitle;

  /// No description provided for @mainScreenTranscriptSaved.
  ///
  /// In id, this message translates to:
  /// **'Transkrip tersimpan.'**
  String get mainScreenTranscriptSaved;

  /// No description provided for @mainScreenSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan: {error}'**
  String mainScreenSaveFailed(String error);

  /// No description provided for @mainScreenRecoverFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memulihkan sesi: {error}'**
  String mainScreenRecoverFailed(String error);

  /// No description provided for @mainScreenRecovered.
  ///
  /// In id, this message translates to:
  /// **'\"{title}\" dipulihkan: {segments, plural, other{{segments} segmen}} dan {duration} audio.'**
  String mainScreenRecovered(String title, int segments, String duration);

  /// No description provided for @mainScreenDeleteFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menghapus: {error}'**
  String mainScreenDeleteFailed(String error);

  /// No description provided for @mainScreenDeleted.
  ///
  /// In id, this message translates to:
  /// **'\"{title}\" dihapus.'**
  String mainScreenDeleted(String title);

  /// Start of the recovery banner line
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{1 sesi terhenti} other{{count} sesi terhenti}}'**
  String mainScreenRecoveryCount(int count);

  /// Part of the recovery banner line
  ///
  /// In id, this message translates to:
  /// **'{count, plural, other{{count} segmen transkrip}}'**
  String mainScreenRecoverySegments(int count);

  /// Part of the recovery banner line
  ///
  /// In id, this message translates to:
  /// **'{duration} audio'**
  String mainScreenRecoveryAudio(String duration);

  /// Joins the recoverable parts of the recovery banner line, with surrounding spaces
  ///
  /// In id, this message translates to:
  /// **' dan '**
  String get mainScreenRecoveryJoiner;

  /// count is mainScreenRecoveryCount
  ///
  /// In id, this message translates to:
  /// **'{count} tanpa transkrip atau audio yang tersisa.'**
  String mainScreenRecoveryNothingLeft(String count);

  /// count is mainScreenRecoveryCount; contents lists what can be recovered
  ///
  /// In id, this message translates to:
  /// **'{count}: {contents} bisa dipulihkan.'**
  String mainScreenRecoveryContents(String count, String contents);

  /// No description provided for @mainScreenStopTitle.
  ///
  /// In id, this message translates to:
  /// **'Berhenti merekam?'**
  String get mainScreenStopTitle;

  /// No description provided for @mainScreenStopBody.
  ///
  /// In id, this message translates to:
  /// **'Sesi ini punya {count, plural, other{{count} segmen transkrip}}. Sesi akan disimpan otomatis saat berhenti.'**
  String mainScreenStopBody(int count);

  /// No description provided for @mainScreenStop.
  ///
  /// In id, this message translates to:
  /// **'Berhenti'**
  String get mainScreenStop;

  /// No description provided for @mainScreenStopFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menghentikan sesi: {error}'**
  String mainScreenStopFailed(String error);

  /// No description provided for @mainScreenSessionSaved.
  ///
  /// In id, this message translates to:
  /// **'Sesi tersimpan ({count, plural, other{{count} segmen}}).'**
  String mainScreenSessionSaved(int count);

  /// No description provided for @mainScreenNothingToBookmark.
  ///
  /// In id, this message translates to:
  /// **'Belum ada rekaman untuk ditandai.'**
  String get mainScreenNothingToBookmark;

  /// No description provided for @mainScreenBookmarked.
  ///
  /// In id, this message translates to:
  /// **'Ditandai di {time}.'**
  String mainScreenBookmarked(String time);

  /// No description provided for @mainScreenModelMissingTitle.
  ///
  /// In id, this message translates to:
  /// **'Model belum diunduh'**
  String get mainScreenModelMissingTitle;

  /// size is empty or " (±142 MB)" with a leading space
  ///
  /// In id, this message translates to:
  /// **'Rekaman perlu {model} di perangkat ini. Unduh sekarang{size}? Unduhan tercatat di Laporan Privasi.'**
  String mainScreenModelMissingMessage(String model, String size);

  /// No description provided for @mainScreenDownloadNow.
  ///
  /// In id, this message translates to:
  /// **'Unduh sekarang'**
  String get mainScreenDownloadNow;

  /// No description provided for @mainScreenLater.
  ///
  /// In id, this message translates to:
  /// **'Nanti'**
  String get mainScreenLater;

  /// No description provided for @mainScreenNothingToExport.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada transkrip untuk diekspor.'**
  String get mainScreenNothingToExport;

  /// Folder picker title
  ///
  /// In id, this message translates to:
  /// **'Pilih folder ekspor'**
  String get mainScreenChooseExportFolder;

  /// No description provided for @mainScreenExportSucceeded.
  ///
  /// In id, this message translates to:
  /// **'Ekspor berhasil ke: {dir}'**
  String mainScreenExportSucceeded(String dir);

  /// No description provided for @mainScreenExportFailed.
  ///
  /// In id, this message translates to:
  /// **'Ekspor gagal: {error}'**
  String mainScreenExportFailed(String error);

  /// No description provided for @mainScreenCannotOpen.
  ///
  /// In id, this message translates to:
  /// **'\"{title}\" tidak bisa dibuka.'**
  String mainScreenCannotOpen(String title);

  /// Toast action that opens the OS privacy settings
  ///
  /// In id, this message translates to:
  /// **'Buka Pengaturan Sistem'**
  String get mainScreenOpenSystemSettings;

  /// Record button label while a session starts
  ///
  /// In id, this message translates to:
  /// **'Memulai…'**
  String get mainScreenStarting;

  /// No description provided for @mainScreenSaving.
  ///
  /// In id, this message translates to:
  /// **'Menyimpan…'**
  String get mainScreenSaving;

  /// No description provided for @mainScreenSwitchPanel.
  ///
  /// In id, this message translates to:
  /// **'Ganti panel'**
  String get mainScreenSwitchPanel;

  /// No description provided for @mainScreenPersonalNotes.
  ///
  /// In id, this message translates to:
  /// **'Catatan Pribadi'**
  String get mainScreenPersonalNotes;

  /// Panel for asking questions about the meeting still being recorded
  ///
  /// In id, this message translates to:
  /// **'Tanya Langsung'**
  String get mainScreenLiveQa;

  /// No description provided for @mainScreenReady.
  ///
  /// In id, this message translates to:
  /// **'Siap merekam'**
  String get mainScreenReady;

  /// No description provided for @mainScreenLocalOnly.
  ///
  /// In id, this message translates to:
  /// **'Semua transkripsi berjalan di komputer ini. Tidak ada audio yang keluar.'**
  String get mainScreenLocalOnly;

  /// No description provided for @mainScreenTitlePlaceholder.
  ///
  /// In id, this message translates to:
  /// **'Judul sesi…'**
  String get mainScreenTitlePlaceholder;

  /// No description provided for @mainScreenStartFromTemplate.
  ///
  /// In id, this message translates to:
  /// **'Mulai dari template'**
  String get mainScreenStartFromTemplate;

  /// No description provided for @mainScreenImportInvite.
  ///
  /// In id, this message translates to:
  /// **'Impor undangan (.ics)'**
  String get mainScreenImportInvite;

  /// Followed by the keyboard shortcut keycap
  ///
  /// In id, this message translates to:
  /// **'atau tekan'**
  String get mainScreenOrPress;

  /// Tooltip of the button that opens the session sidebar
  ///
  /// In id, this message translates to:
  /// **'Riwayat sesi'**
  String get mainScreenSessionHistory;

  /// No description provided for @mainScreenRecordingDuration.
  ///
  /// In id, this message translates to:
  /// **'Durasi rekaman'**
  String get mainScreenRecordingDuration;

  /// No description provided for @mainScreenPaused.
  ///
  /// In id, this message translates to:
  /// **'Dijeda'**
  String get mainScreenPaused;

  /// No description provided for @mainScreenBookmarkTooltip.
  ///
  /// In id, this message translates to:
  /// **'Tandai poin penting ({shortcut})'**
  String mainScreenBookmarkTooltip(String shortcut);

  /// No description provided for @mainScreenExport.
  ///
  /// In id, this message translates to:
  /// **'Ekspor'**
  String get mainScreenExport;

  /// message is the save error sentence
  ///
  /// In id, this message translates to:
  /// **'{message} Transkrip masih ada di memori, jangan tutup aplikasi sebelum tersimpan.'**
  String mainScreenSaveFailedBanner(String message);

  /// No description provided for @mainScreenSaveElsewhere.
  ///
  /// In id, this message translates to:
  /// **'Simpan ke folder lain'**
  String get mainScreenSaveElsewhere;

  /// No description provided for @mainScreenRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba Lagi'**
  String get mainScreenRetry;

  /// No description provided for @mainScreenViewAndRecover.
  ///
  /// In id, this message translates to:
  /// **'Lihat & Pulihkan'**
  String get mainScreenViewAndRecover;

  /// Footer transcript segment count
  ///
  /// In id, this message translates to:
  /// **'{count, plural, other{{count} segmen}}'**
  String mainScreenSegmentCount(int count);

  /// No description provided for @mainScreenShowShortcuts.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan pintasan keyboard'**
  String get mainScreenShowShortcuts;

  /// No description provided for @mainScreenShortcuts.
  ///
  /// In id, this message translates to:
  /// **'Pintasan'**
  String get mainScreenShortcuts;

  /// No description provided for @mainScreenKeyboardShortcuts.
  ///
  /// In id, this message translates to:
  /// **'Pintasan keyboard'**
  String get mainScreenKeyboardShortcuts;

  /// No description provided for @mainScreenClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get mainScreenClose;

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
