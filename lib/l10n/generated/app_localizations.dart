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
