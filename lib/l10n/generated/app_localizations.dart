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

  /// Tooltip of the close button on a toast
  ///
  /// In id, this message translates to:
  /// **'Tutup pemberitahuan'**
  String get appToastDismissTooltip;

  /// Small badge next to a setting that opens an explanation dialog
  ///
  /// In id, this message translates to:
  /// **'Penjelasan'**
  String get settingsControlsInfoBadge;

  /// No description provided for @settingsControlsInfoDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Informasi'**
  String get settingsControlsInfoDialogTitle;

  /// No description provided for @settingsControlsClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get settingsControlsClose;

  /// Generic status line of a failed background task
  ///
  /// In id, this message translates to:
  /// **'Gagal.'**
  String get taskProgressTileFailed;

  /// No description provided for @taskProgressTileCancelled.
  ///
  /// In id, this message translates to:
  /// **'Dibatalkan.'**
  String get taskProgressTileCancelled;

  /// No description provided for @taskProgressTileDone.
  ///
  /// In id, this message translates to:
  /// **'Selesai.'**
  String get taskProgressTileDone;

  /// No description provided for @taskProgressTileQueued.
  ///
  /// In id, this message translates to:
  /// **'Menunggu antrean.'**
  String get taskProgressTileQueued;

  /// Default stage name of a running task; an ellipsis and percentage are appended
  ///
  /// In id, this message translates to:
  /// **'Memproses'**
  String get taskProgressTileProcessing;

  /// Sidebar heading when the queue is filling in audio that was never transcribed (a repair, not a polish)
  ///
  /// In id, this message translates to:
  /// **'Menyelesaikan transkrip'**
  String get enhanceQueueViewCompletingTitle;

  /// Stage of a completion job. source is a lower-case source name such as "mikrofon"
  ///
  /// In id, this message translates to:
  /// **'Menyelesaikan {source}'**
  String enhanceQueueViewCompletingSource(String source);

  /// Estimated time remaining, e.g. "sisa 5 menit"
  ///
  /// In id, this message translates to:
  /// **'sisa {eta}'**
  String enhanceQueueViewEtaRemaining(String eta);

  /// No description provided for @enhanceQueueViewQueuedCompletion.
  ///
  /// In id, this message translates to:
  /// **'Menunggu antrean, ada audio yang belum ditranskripsi.'**
  String get enhanceQueueViewQueuedCompletion;

  /// Lower-case name of the microphone track, used inside sentences
  ///
  /// In id, this message translates to:
  /// **'mikrofon'**
  String get enhanceQueueModelSourceMic;

  /// Lower-case name of the system-audio (speaker) track, used inside sentences
  ///
  /// In id, this message translates to:
  /// **'audio sistem'**
  String get enhanceQueueModelSourceSystem;

  /// Lower-case name of an imported file track, used inside sentences
  ///
  /// In id, this message translates to:
  /// **'rekaman'**
  String get enhanceQueueModelSourceRecording;

  /// Player status line while completion jobs are queued; count is the number of tracks
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{Menunggu antrean untuk menyelesaikan transkrip.} other{Menunggu antrean untuk menyelesaikan {count} rekaman.}}'**
  String enhanceQueueModelQueuedForCompletion(int count);

  /// Player status line of a running completion job. source is empty or " (mikrofon)"; eta is empty or the enhanceQueueModelEtaSuffix text
  ///
  /// In id, this message translates to:
  /// **'Menyelesaikan transkrip…{source} {percent}%{eta}'**
  String enhanceQueueModelCompletingLine(
    String source,
    int percent,
    String eta,
  );

  /// Appended to the completion status line; note the leading comma and space
  ///
  /// In id, this message translates to:
  /// **', sisa {eta}'**
  String enhanceQueueModelEtaSuffix(String eta);

  /// No description provided for @enhanceQueueModelEtaSeconds.
  ///
  /// In id, this message translates to:
  /// **'{seconds} detik'**
  String enhanceQueueModelEtaSeconds(int seconds);

  /// No description provided for @enhanceQueueModelEtaMinutes.
  ///
  /// In id, this message translates to:
  /// **'{minutes} menit'**
  String enhanceQueueModelEtaMinutes(int minutes);

  /// No description provided for @enhanceQueueModelEtaHours.
  ///
  /// In id, this message translates to:
  /// **'{hours} jam'**
  String enhanceQueueModelEtaHours(int hours);

  /// No description provided for @enhanceQueueModelEtaHoursMinutes.
  ///
  /// In id, this message translates to:
  /// **'{hours} jam {minutes} menit'**
  String enhanceQueueModelEtaHoursMinutes(int hours, int minutes);

  /// Stage of the background accurate pass
  ///
  /// In id, this message translates to:
  /// **'Menyiapkan model'**
  String get enhanceQueueModelStagePreparing;

  /// Stage of the background accurate pass
  ///
  /// In id, this message translates to:
  /// **'Mentranskripsi'**
  String get enhanceQueueModelStageTranscribing;

  /// Stage of the background accurate pass: writing the merged transcript
  ///
  /// In id, this message translates to:
  /// **'Menggabungkan'**
  String get enhanceQueueModelStageMerging;

  /// No description provided for @enhanceQueueModelNoSpeech.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada ucapan terdeteksi.'**
  String get enhanceQueueModelNoSpeech;

  /// Why a dropped file was rejected; shown after the file name
  ///
  /// In id, this message translates to:
  /// **'format tidak didukung'**
  String get batchUploadModelUnsupportedFormat;

  /// Why a dropped file was rejected; shown after the file name
  ///
  /// In id, this message translates to:
  /// **'lebih besar dari batas 2 GB'**
  String get batchUploadModelTooLarge;

  /// Per-file import error (no trailing period, unlike enhanceQueueModelNoSpeech)
  ///
  /// In id, this message translates to:
  /// **'Tidak ada ucapan terdeteksi'**
  String get batchUploadModelNoSpeech;

  /// No description provided for @batchUploadModelStoppedEarly.
  ///
  /// In id, this message translates to:
  /// **'Proses berhenti sebelum file ini selesai'**
  String get batchUploadModelStoppedEarly;

  /// Built-in AI summary template name
  ///
  /// In id, this message translates to:
  /// **'Notulen Rapat'**
  String get modelsSummaryTemplateNotulenRapat;

  /// Built-in AI summary template name
  ///
  /// In id, this message translates to:
  /// **'Ringkasan Eksekutif'**
  String get modelsSummaryTemplateRingkasanEksekutif;

  /// Built-in AI summary template name
  ///
  /// In id, this message translates to:
  /// **'Keputusan & Tindak Lanjut'**
  String get modelsSummaryTemplateActionItems;

  /// Built-in AI summary template name
  ///
  /// In id, this message translates to:
  /// **'Laporan Harian'**
  String get modelsSummaryTemplateStandup;

  /// AI summary template that uses the user's own instructions
  ///
  /// In id, this message translates to:
  /// **'Kustom'**
  String get modelsSummaryTemplateKustom;

  /// One-line description under the template picker
  ///
  /// In id, this message translates to:
  /// **'Ringkasan, peserta, pembahasan, keputusan, tindak lanjut'**
  String get modelsSummaryTemplateHintNotulenRapat;

  /// One-line description under the template picker
  ///
  /// In id, this message translates to:
  /// **'Paragraf singkat untuk yang tidak hadir'**
  String get modelsSummaryTemplateHintRingkasanEksekutif;

  /// One-line description under the template picker
  ///
  /// In id, this message translates to:
  /// **'Hanya keputusan dan tugas beserta penanggung jawabnya'**
  String get modelsSummaryTemplateHintActionItems;

  /// One-line description under the template picker
  ///
  /// In id, this message translates to:
  /// **'Per orang: selesai, berikutnya, hambatan'**
  String get modelsSummaryTemplateHintStandup;

  /// One-line description under the template picker
  ///
  /// In id, this message translates to:
  /// **'Instruksi sendiri'**
  String get modelsSummaryTemplateHintKustom;

  /// AI summary provider option
  ///
  /// In id, this message translates to:
  /// **'Ollama (lokal)'**
  String get modelsSummaryProviderOllama;

  /// AI summary provider option
  ///
  /// In id, this message translates to:
  /// **'Layanan serupa OpenAI'**
  String get modelsSummaryProviderOpenAiCompatible;

  /// Session mode: system audio only
  ///
  /// In id, this message translates to:
  /// **'Webinar'**
  String get modelsSessionModeWebinar;

  /// Session mode: microphone and system audio
  ///
  /// In id, this message translates to:
  /// **'Rapat Online'**
  String get modelsSessionModeOnline;

  /// Session mode: microphone only, everyone in the room
  ///
  /// In id, this message translates to:
  /// **'Rapat Offline'**
  String get modelsSessionModeOffline;

  /// No description provided for @usageDashboardScreenTitle.
  ///
  /// In id, this message translates to:
  /// **'Dasbor Penggunaan'**
  String get usageDashboardScreenTitle;

  /// No description provided for @usageDashboardScreenTotalSessions.
  ///
  /// In id, this message translates to:
  /// **'Total Sesi'**
  String get usageDashboardScreenTotalSessions;

  /// No description provided for @usageDashboardScreenHoursTranscribed.
  ///
  /// In id, this message translates to:
  /// **'Jam Ditranskrip'**
  String get usageDashboardScreenHoursTranscribed;

  /// No description provided for @usageDashboardScreenTotalSegments.
  ///
  /// In id, this message translates to:
  /// **'Total Segmen Transkrip'**
  String get usageDashboardScreenTotalSegments;

  /// No description provided for @usageDashboardScreenEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada data sesi tersimpan.'**
  String get usageDashboardScreenEmpty;

  /// No description provided for @usageDashboardScreenSessionsByMode.
  ///
  /// In id, this message translates to:
  /// **'Sesi per Mode'**
  String get usageDashboardScreenSessionsByMode;

  /// No description provided for @usageDashboardScreenSessionCount.
  ///
  /// In id, this message translates to:
  /// **'{count} sesi'**
  String usageDashboardScreenSessionCount(int count);

  /// No description provided for @meetingTemplatePickerModeWebinar.
  ///
  /// In id, this message translates to:
  /// **'Webinar'**
  String get meetingTemplatePickerModeWebinar;

  /// No description provided for @meetingTemplatePickerModeOnline.
  ///
  /// In id, this message translates to:
  /// **'Rapat online'**
  String get meetingTemplatePickerModeOnline;

  /// No description provided for @meetingTemplatePickerModeOffline.
  ///
  /// In id, this message translates to:
  /// **'Rapat tatap muka'**
  String get meetingTemplatePickerModeOffline;

  /// Transcription language: detect automatically
  ///
  /// In id, this message translates to:
  /// **'Otomatis'**
  String get meetingTemplatePickerLanguageAuto;

  /// Transcription language option
  ///
  /// In id, this message translates to:
  /// **'Indonesia'**
  String get meetingTemplatePickerLanguageIndonesian;

  /// Transcription language option
  ///
  /// In id, this message translates to:
  /// **'Inggris'**
  String get meetingTemplatePickerLanguageEnglish;

  /// No description provided for @meetingTemplatePickerTitle.
  ///
  /// In id, this message translates to:
  /// **'Mulai dari template'**
  String get meetingTemplatePickerTitle;

  /// No description provided for @meetingTemplatePickerEmptyDescription.
  ///
  /// In id, this message translates to:
  /// **'Belum ada template tersimpan. Buat satu agar judul, peserta, agenda, bahasa, dan mode rapat yang sering dipakai tidak perlu diisi ulang setiap kali.'**
  String get meetingTemplatePickerEmptyDescription;

  /// No description provided for @meetingTemplatePickerDescription.
  ///
  /// In id, this message translates to:
  /// **'Pilih template untuk mengisi judul, mode, dan bahasa sesi secara otomatis.'**
  String get meetingTemplatePickerDescription;

  /// No description provided for @meetingTemplatePickerCreate.
  ///
  /// In id, this message translates to:
  /// **'Buat template baru'**
  String get meetingTemplatePickerCreate;

  /// Quoted text is the label of the main-screen new-meeting button
  ///
  /// In id, this message translates to:
  /// **'Template tidak wajib. \"Rapat baru\" tetap memulai sesi kosong seperti biasa.'**
  String get meetingTemplatePickerOptionalNote;

  /// No description provided for @meetingTemplatePickerParticipantCount.
  ///
  /// In id, this message translates to:
  /// **'{count} peserta'**
  String meetingTemplatePickerParticipantCount(int count);

  /// No description provided for @meetingTemplatePickerAgendaCount.
  ///
  /// In id, this message translates to:
  /// **'{count} agenda'**
  String meetingTemplatePickerAgendaCount(int count);

  /// No description provided for @meetingTemplatePickerDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus template'**
  String get meetingTemplatePickerDelete;

  /// Button that applies a saved meeting template
  ///
  /// In id, this message translates to:
  /// **'Pakai'**
  String get meetingTemplatePickerUse;

  /// No description provided for @meetingTemplatePickerNewTitle.
  ///
  /// In id, this message translates to:
  /// **'Template baru'**
  String get meetingTemplatePickerNewTitle;

  /// No description provided for @meetingTemplatePickerNamePlaceholder.
  ///
  /// In id, this message translates to:
  /// **'Nama template, mis. \"Rapat Mingguan Tim\"'**
  String get meetingTemplatePickerNamePlaceholder;

  /// No description provided for @meetingTemplatePickerParticipantsPlaceholder.
  ///
  /// In id, this message translates to:
  /// **'Peserta default (satu nama per baris)'**
  String get meetingTemplatePickerParticipantsPlaceholder;

  /// No description provided for @meetingTemplatePickerAgendaPlaceholder.
  ///
  /// In id, this message translates to:
  /// **'Agenda default (satu poin per baris)'**
  String get meetingTemplatePickerAgendaPlaceholder;

  /// No description provided for @meetingTemplatePickerModeLabel.
  ///
  /// In id, this message translates to:
  /// **'Mode'**
  String get meetingTemplatePickerModeLabel;

  /// Transcription language of the template
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get meetingTemplatePickerLanguageLabel;

  /// No description provided for @glossarySettingsSectionImportDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Impor kamus istilah'**
  String get glossarySettingsSectionImportDialogTitle;

  /// No description provided for @glossarySettingsSectionImportEmpty.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada istilah di berkas itu.'**
  String get glossarySettingsSectionImportEmpty;

  /// No description provided for @glossarySettingsSectionImported.
  ///
  /// In id, this message translates to:
  /// **'{added} istilah baru ditambahkan dari {lines} baris.'**
  String glossarySettingsSectionImported(int added, int lines);

  /// No description provided for @glossarySettingsSectionImportFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengimpor: {error}'**
  String glossarySettingsSectionImportFailed(String error);

  /// No description provided for @glossarySettingsSectionExportDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Simpan kamus istilah'**
  String get glossarySettingsSectionExportDialogTitle;

  /// No description provided for @glossarySettingsSectionExported.
  ///
  /// In id, this message translates to:
  /// **'{count} istilah diekspor ke {path}'**
  String glossarySettingsSectionExported(int count, String path);

  /// No description provided for @glossarySettingsSectionExportFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengekspor: {error}'**
  String glossarySettingsSectionExportFailed(String error);

  /// No description provided for @glossarySettingsSectionTitle.
  ///
  /// In id, this message translates to:
  /// **'Kamus Istilah'**
  String get glossarySettingsSectionTitle;

  /// No description provided for @glossarySettingsSectionEnable.
  ///
  /// In id, this message translates to:
  /// **'Pakai kamus istilah'**
  String get glossarySettingsSectionEnable;

  /// No description provided for @glossarySettingsSectionEnabledSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Istilah di bawah dibisikkan ke mesin transkripsi supaya singkatan dan nama lembaga tidak salah tulis.'**
  String get glossarySettingsSectionEnabledSubtitle;

  /// No description provided for @glossarySettingsSectionDisabledSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mesin transkripsi menebak sendiri semua istilah.'**
  String get glossarySettingsSectionDisabledSubtitle;

  /// No description provided for @glossarySettingsSectionPostCorrection.
  ///
  /// In id, this message translates to:
  /// **'Perbaiki ejaan yang mirip'**
  String get glossarySettingsSectionPostCorrection;

  /// No description provided for @glossarySettingsSectionPostCorrectionOnSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Kata yang hampir sama dengan istilah di kamus diperbaiki setelah transkripsi. Kata lain tidak disentuh.'**
  String get glossarySettingsSectionPostCorrectionOnSubtitle;

  /// No description provided for @glossarySettingsSectionPostCorrectionOffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Hasil transkripsi dibiarkan apa adanya.'**
  String get glossarySettingsSectionPostCorrectionOffSubtitle;

  /// No description provided for @glossarySettingsSectionListTitle.
  ///
  /// In id, this message translates to:
  /// **'Daftar Istilah ({count})'**
  String glossarySettingsSectionListTitle(int count);

  /// No description provided for @glossarySettingsSectionAddLabel.
  ///
  /// In id, this message translates to:
  /// **'Tambah istilah'**
  String get glossarySettingsSectionAddLabel;

  /// Example terms; the Indonesian acronyms and name are deliberate
  ///
  /// In id, this message translates to:
  /// **'mis. PPBJ, Kemenkeu, Pak Budi Santoso'**
  String get glossarySettingsSectionAddHint;

  /// No description provided for @glossarySettingsSectionAdd.
  ///
  /// In id, this message translates to:
  /// **'Tambah'**
  String get glossarySettingsSectionAdd;

  /// Screen-reader label of a glossary term chip
  ///
  /// In id, this message translates to:
  /// **'Istilah {term}'**
  String glossarySettingsSectionTermSemantics(String term);

  /// No description provided for @glossarySettingsSectionRemoveTerm.
  ///
  /// In id, this message translates to:
  /// **'Hapus {term}'**
  String glossarySettingsSectionRemoveTerm(String term);

  /// No description provided for @glossarySettingsSectionSuggestions.
  ///
  /// In id, this message translates to:
  /// **'Saran istilah umum'**
  String get glossarySettingsSectionSuggestions;

  /// No description provided for @glossarySettingsSectionAddSuggestion.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan {term} ke kamus'**
  String glossarySettingsSectionAddSuggestion(String term);

  /// No description provided for @glossarySettingsSectionImportButton.
  ///
  /// In id, this message translates to:
  /// **'Impor .txt / .csv'**
  String get glossarySettingsSectionImportButton;

  /// No description provided for @glossarySettingsSectionExportTxt.
  ///
  /// In id, this message translates to:
  /// **'Ekspor .txt'**
  String get glossarySettingsSectionExportTxt;

  /// No description provided for @glossarySettingsSectionExportCsv.
  ///
  /// In id, this message translates to:
  /// **'Ekspor .csv'**
  String get glossarySettingsSectionExportCsv;

  /// No description provided for @glossarySettingsSectionNoTerms.
  ///
  /// In id, this message translates to:
  /// **'Belum ada istilah. Tanpa kamus, mesin transkripsi menebak sendiri.'**
  String get glossarySettingsSectionNoTerms;

  /// Shown when the glossary does not fit the transcription prompt
  ///
  /// In id, this message translates to:
  /// **'{used} dari {total} istilah dipakai, daftar terlalu panjang untuk dibisikkan sekaligus. Istilah paling atas yang dibuang; pindahkan yang penting ke atas atau kurangi daftarnya.'**
  String glossarySettingsSectionBudgetOverflow(int used, int total);

  /// No description provided for @glossarySettingsSectionBudgetAll.
  ///
  /// In id, this message translates to:
  /// **'Semua {total} istilah dipakai.'**
  String glossarySettingsSectionBudgetAll(int total);

  /// Placeholder of the model field until the engine supplies its default model tag
  ///
  /// In id, this message translates to:
  /// **'nama model Ollama'**
  String get summarySettingsSectionOllamaModelHint;

  /// No description provided for @summarySettingsSectionNoModels.
  ///
  /// In id, this message translates to:
  /// **'Endpoint terhubung, tapi tidak ada model terpasang.'**
  String get summarySettingsSectionNoModels;

  /// No description provided for @summarySettingsSectionEnable.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan Ringkasan AI'**
  String get summarySettingsSectionEnable;

  /// Quoted text is the label of the summary panel's generate button
  ///
  /// In id, this message translates to:
  /// **'Transkrip dikirim ke endpoint di bawah hanya saat Anda menekan \"Buat Ringkasan\". Tidak ada audio yang dikirim.'**
  String get summarySettingsSectionEnabledSubtitle;

  /// No description provided for @summarySettingsSectionDisabledSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Mati. Aplikasi tetap 100% offline.'**
  String get summarySettingsSectionDisabledSubtitle;

  /// No description provided for @summarySettingsSectionProvider.
  ///
  /// In id, this message translates to:
  /// **'Penyedia'**
  String get summarySettingsSectionProvider;

  /// No description provided for @summarySettingsSectionEndpointUrl.
  ///
  /// In id, this message translates to:
  /// **'URL endpoint'**
  String get summarySettingsSectionEndpointUrl;

  /// No description provided for @summarySettingsSectionApiKey.
  ///
  /// In id, this message translates to:
  /// **'Kunci API'**
  String get summarySettingsSectionApiKey;

  /// No description provided for @summarySettingsSectionApiKeyHelper.
  ///
  /// In id, this message translates to:
  /// **'Disimpan apa adanya di file pengaturan aplikasi (tanpa keychain).'**
  String get summarySettingsSectionApiKeyHelper;

  /// No description provided for @summarySettingsSectionApiKeyHint.
  ///
  /// In id, this message translates to:
  /// **'Tempel kunci di sini'**
  String get summarySettingsSectionApiKeyHint;

  /// No description provided for @summarySettingsSectionModel.
  ///
  /// In id, this message translates to:
  /// **'Model'**
  String get summarySettingsSectionModel;

  /// No description provided for @summarySettingsSectionLoadModels.
  ///
  /// In id, this message translates to:
  /// **'Muat daftar model dari endpoint'**
  String get summarySettingsSectionLoadModels;

  /// No description provided for @summarySettingsSectionSetupWizard.
  ///
  /// In id, this message translates to:
  /// **'Siapkan Model AI (deteksi, pasang, unduh)…'**
  String get summarySettingsSectionSetupWizard;

  /// No description provided for @summarySettingsSectionDefaultTemplate.
  ///
  /// In id, this message translates to:
  /// **'Template default'**
  String get summarySettingsSectionDefaultTemplate;

  /// No description provided for @summarySettingsSectionCitations.
  ///
  /// In id, this message translates to:
  /// **'Rujukan ke transkrip'**
  String get summarySettingsSectionCitations;

  /// No description provided for @summarySettingsSectionCitationsSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Minta model menyebut nomor segmen untuk setiap poin, sehingga tiap baris ringkasan bisa diklik ke menit asalnya. Rujukan yang tidak cocok dibuang.'**
  String get summarySettingsSectionCitationsSubtitle;

  /// No description provided for @summarySettingsSectionActionItems.
  ///
  /// In id, this message translates to:
  /// **'Tindak lanjut terstruktur'**
  String get summarySettingsSectionActionItems;

  /// No description provided for @summarySettingsSectionActionItemsSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Minta daftar tugas, penanggung jawab, dan tenggat dalam format yang bisa disunting dan diekspor ke kalender (.ics) atau tabel (.csv).'**
  String get summarySettingsSectionActionItemsSubtitle;

  /// No description provided for @summarySettingsSectionCustomInstructions.
  ///
  /// In id, this message translates to:
  /// **'Instruksi kustom'**
  String get summarySettingsSectionCustomInstructions;

  /// No description provided for @summarySettingsSectionCustomInstructionsHint.
  ///
  /// In id, this message translates to:
  /// **'Contoh: Buat daftar risiko dan mitigasinya.'**
  String get summarySettingsSectionCustomInstructionsHint;

  /// Retention choice: never delete
  ///
  /// In id, this message translates to:
  /// **'Simpan selamanya'**
  String get pdpSettingsSectionRetentionForever;

  /// Retention choice
  ///
  /// In id, this message translates to:
  /// **'{days} hari'**
  String pdpSettingsSectionRetentionDays(int days);

  /// Retention choice, e.g. "90 hari (3 bulan)"
  ///
  /// In id, this message translates to:
  /// **'{days} hari ({months} bulan)'**
  String pdpSettingsSectionRetentionDaysMonths(int days, int months);

  /// Retention choice
  ///
  /// In id, this message translates to:
  /// **'{years} tahun'**
  String pdpSettingsSectionRetentionYears(int years);

  /// UU PDP is the Indonesian personal data protection law; keep "PDP"
  ///
  /// In id, this message translates to:
  /// **'Kepatuhan UU PDP'**
  String get pdpSettingsSectionTitle;

  /// No description provided for @pdpSettingsSectionEnable.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan Mode Kepatuhan PDP'**
  String get pdpSettingsSectionEnable;

  /// No description provided for @pdpSettingsSectionEnableSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Penyamaran data pribadi saat ekspor, batas retensi, log audit, dan pemberitahuan perekaman. Mati secara bawaan.'**
  String get pdpSettingsSectionEnableSubtitle;

  /// No description provided for @pdpSettingsSectionRedactionTitle.
  ///
  /// In id, this message translates to:
  /// **'Penyamaran saat ekspor'**
  String get pdpSettingsSectionRedactionTitle;

  /// No description provided for @pdpSettingsSectionRedactionIntro.
  ///
  /// In id, this message translates to:
  /// **'Transkrip tersimpan tidak diubah. Penyamaran hanya berlaku pada salinan yang diekspor, dan selalu bisa dilihat dulu sebelum file ditulis.'**
  String get pdpSettingsSectionRedactionIntro;

  /// Indonesian national identity number (Nomor Induk Kependudukan)
  ///
  /// In id, this message translates to:
  /// **'NIK'**
  String get pdpSettingsSectionNik;

  /// No description provided for @pdpSettingsSectionNikHint.
  ///
  /// In id, this message translates to:
  /// **'16 digit dengan kode provinsi yang sah'**
  String get pdpSettingsSectionNikHint;

  /// Indonesian taxpayer identification number
  ///
  /// In id, this message translates to:
  /// **'NPWP'**
  String get pdpSettingsSectionNpwp;

  /// No description provided for @pdpSettingsSectionNpwpHint.
  ///
  /// In id, this message translates to:
  /// **'15 digit, dengan atau tanpa titik'**
  String get pdpSettingsSectionNpwpHint;

  /// No description provided for @pdpSettingsSectionPhone.
  ///
  /// In id, this message translates to:
  /// **'Nomor telepon'**
  String get pdpSettingsSectionPhone;

  /// No description provided for @pdpSettingsSectionPhoneHint.
  ///
  /// In id, this message translates to:
  /// **'08…, +62…, dan nomor kantor dengan kode area'**
  String get pdpSettingsSectionPhoneHint;

  /// No description provided for @pdpSettingsSectionEmail.
  ///
  /// In id, this message translates to:
  /// **'Alamat email'**
  String get pdpSettingsSectionEmail;

  /// Example email address format
  ///
  /// In id, this message translates to:
  /// **'nama@instansi.go.id'**
  String get pdpSettingsSectionEmailHint;

  /// No description provided for @pdpSettingsSectionBankAccount.
  ///
  /// In id, this message translates to:
  /// **'Nomor rekening'**
  String get pdpSettingsSectionBankAccount;

  /// Keep the Indonesian word "rekening" in quotes: it is the keyword the detector looks for in the transcript
  ///
  /// In id, this message translates to:
  /// **'Hanya bila ada kata \"rekening\" atau nama bank di dekatnya, supaya angka anggaran tidak ikut disamarkan'**
  String get pdpSettingsSectionBankAccountHint;

  /// No description provided for @pdpSettingsSectionNamesTitle.
  ///
  /// In id, this message translates to:
  /// **'Nama yang disamarkan'**
  String get pdpSettingsSectionNamesTitle;

  /// No description provided for @pdpSettingsSectionNamesIntro.
  ///
  /// In id, this message translates to:
  /// **'Hanya Anda yang tahu nama mana yang sensitif di rapat ini. Entri kurang dari 3 huruf diabaikan.'**
  String get pdpSettingsSectionNamesIntro;

  /// No description provided for @pdpSettingsSectionNameHint.
  ///
  /// In id, this message translates to:
  /// **'Mis. Budi Santoso'**
  String get pdpSettingsSectionNameHint;

  /// No description provided for @pdpSettingsSectionAdd.
  ///
  /// In id, this message translates to:
  /// **'Tambah'**
  String get pdpSettingsSectionAdd;

  /// No description provided for @pdpSettingsSectionRetentionTitle.
  ///
  /// In id, this message translates to:
  /// **'Retensi data'**
  String get pdpSettingsSectionRetentionTitle;

  /// No description provided for @pdpSettingsSectionRetentionIntro.
  ///
  /// In id, this message translates to:
  /// **'Audio dan transkrip punya batas sendiri-sendiri: rekaman biasanya harus dihapus jauh lebih cepat daripada notulennya. Tidak ada yang dihapus otomatis. Anda melihat daftarnya dulu.'**
  String get pdpSettingsSectionRetentionIntro;

  /// No description provided for @pdpSettingsSectionDeleteAudioAfter.
  ///
  /// In id, this message translates to:
  /// **'Hapus audio setelah'**
  String get pdpSettingsSectionDeleteAudioAfter;

  /// No description provided for @pdpSettingsSectionDeleteTranscriptAfter.
  ///
  /// In id, this message translates to:
  /// **'Hapus transkrip (seluruh sesi) setelah'**
  String get pdpSettingsSectionDeleteTranscriptAfter;

  /// No description provided for @pdpSettingsSectionPreviewRetention.
  ///
  /// In id, this message translates to:
  /// **'Lihat & jalankan sekarang'**
  String get pdpSettingsSectionPreviewRetention;

  /// No description provided for @pdpSettingsSectionRetentionDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Jalankan kebijakan retensi?'**
  String get pdpSettingsSectionRetentionDialogTitle;

  /// Item in the retention preview; days is the session age
  ///
  /// In id, this message translates to:
  /// **'Seluruh sesi · {days} hari'**
  String pdpSettingsSectionWholeSessionAge(int days);

  /// Item in the retention preview; days is the session age
  ///
  /// In id, this message translates to:
  /// **'Audio saja · {days} hari'**
  String pdpSettingsSectionAudioOnlyAge(int days);

  /// No description provided for @pdpSettingsSectionCannotUndo.
  ///
  /// In id, this message translates to:
  /// **'Tindakan ini tidak bisa dibatalkan.'**
  String get pdpSettingsSectionCannotUndo;

  /// No description provided for @pdpSettingsSectionDeleteNow.
  ///
  /// In id, this message translates to:
  /// **'Hapus sekarang'**
  String get pdpSettingsSectionDeleteNow;

  /// No description provided for @pdpSettingsSectionRetentionApplied.
  ///
  /// In id, this message translates to:
  /// **'{count} item dihapus sesuai kebijakan retensi.'**
  String pdpSettingsSectionRetentionApplied(int count);

  /// No description provided for @pdpSettingsSectionRetentionPartial.
  ///
  /// In id, this message translates to:
  /// **'{deleted} dihapus, {failed} gagal.'**
  String pdpSettingsSectionRetentionPartial(int deleted, int failed);

  /// No description provided for @pdpSettingsSectionRetentionPreviewFailed.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau retensi gagal: {error}'**
  String pdpSettingsSectionRetentionPreviewFailed(String error);

  /// No description provided for @pdpSettingsSectionConsentTitle.
  ///
  /// In id, this message translates to:
  /// **'Pemberitahuan perekaman'**
  String get pdpSettingsSectionConsentTitle;

  /// No description provided for @pdpSettingsSectionConsentReminder.
  ///
  /// In id, this message translates to:
  /// **'Ingatkan sebelum mulai merekam'**
  String get pdpSettingsSectionConsentReminder;

  /// No description provided for @pdpSettingsSectionConsentReminderSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan teks pemberitahuan yang bisa disalin ke obrolan rapat, dan catat penyampaiannya di log audit.'**
  String get pdpSettingsSectionConsentReminderSubtitle;

  /// No description provided for @pdpSettingsSectionConsentTextLabel.
  ///
  /// In id, this message translates to:
  /// **'Teks pemberitahuan'**
  String get pdpSettingsSectionConsentTextLabel;

  /// titleToken and dateToken are the literal template tokens "{judul}" and "{tanggal}", passed in from code so the braces survive ICU parsing; they must not be translated
  ///
  /// In id, this message translates to:
  /// **'{titleToken} dan {dateToken} diganti otomatis. Kosongkan untuk memakai teks bawaan.'**
  String pdpSettingsSectionConsentTextHelper(
    String titleToken,
    String dateToken,
  );

  /// No description provided for @pdpSettingsSectionCopyNotice.
  ///
  /// In id, this message translates to:
  /// **'Salin teks pemberitahuan'**
  String get pdpSettingsSectionCopyNotice;

  /// No description provided for @pdpSettingsSectionNoticeCopied.
  ///
  /// In id, this message translates to:
  /// **'Teks pemberitahuan disalin.'**
  String get pdpSettingsSectionNoticeCopied;

  /// No description provided for @pdpSettingsSectionCopyFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyalin: {error}'**
  String pdpSettingsSectionCopyFailed(String error);

  /// No description provided for @pdpSettingsSectionAuditTitle.
  ///
  /// In id, this message translates to:
  /// **'Log audit'**
  String get pdpSettingsSectionAuditTitle;

  /// No description provided for @pdpSettingsSectionAuditIntro.
  ///
  /// In id, this message translates to:
  /// **'Catatan lokal tentang apa yang terjadi pada data: sesi dibuat, transkrip diekspor, ringkasan dikirim, data dihapus. Isinya hanya metadata, tidak ada kutipan transkrip di dalamnya.'**
  String get pdpSettingsSectionAuditIntro;

  /// No description provided for @pdpSettingsSectionViewLog.
  ///
  /// In id, this message translates to:
  /// **'Lihat log'**
  String get pdpSettingsSectionViewLog;

  /// No description provided for @pdpSettingsSectionExportCsv.
  ///
  /// In id, this message translates to:
  /// **'Ekspor CSV'**
  String get pdpSettingsSectionExportCsv;

  /// No description provided for @pdpSettingsSectionSaveAuditDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Simpan log audit'**
  String get pdpSettingsSectionSaveAuditDialogTitle;

  /// No description provided for @pdpSettingsSectionAuditSaved.
  ///
  /// In id, this message translates to:
  /// **'Log audit disimpan ke {path}'**
  String pdpSettingsSectionAuditSaved(String path);

  /// No description provided for @pdpSettingsSectionAuditExportFailed.
  ///
  /// In id, this message translates to:
  /// **'Ekspor log gagal: {error}'**
  String pdpSettingsSectionAuditExportFailed(String error);

  /// Screen-reader announcement when several transcript lines arrive at once (count is always 2 or more)
  ///
  /// In id, this message translates to:
  /// **'{count} baris baru. Terakhir, {speaker}: {text}'**
  String transcriptViewNewLinesAnnouncement(
    int count,
    String speaker,
    String text,
  );

  /// No description provided for @transcriptViewSegmentCopied.
  ///
  /// In id, this message translates to:
  /// **'Segmen disalin.'**
  String get transcriptViewSegmentCopied;

  /// No description provided for @transcriptViewTranscriptCopied.
  ///
  /// In id, this message translates to:
  /// **'Transkrip disalin.'**
  String get transcriptViewTranscriptCopied;

  /// No description provided for @transcriptViewEmptyTitle.
  ///
  /// In id, this message translates to:
  /// **'Belum ada transkrip'**
  String get transcriptViewEmptyTitle;

  /// "Mulai" is the record button label; shortcut is a key combination such as Ctrl+R
  ///
  /// In id, this message translates to:
  /// **'Mulai sesi untuk memulai transkripsi\nTekan Mulai atau {shortcut}'**
  String transcriptViewEmptySubtitle(String shortcut);

  /// No description provided for @transcriptViewSearchHint.
  ///
  /// In id, this message translates to:
  /// **'Cari…'**
  String get transcriptViewSearchHint;

  /// No description provided for @transcriptViewClearSearch.
  ///
  /// In id, this message translates to:
  /// **'Bersihkan pencarian'**
  String get transcriptViewClearSearch;

  /// No description provided for @transcriptViewSegmentCount.
  ///
  /// In id, this message translates to:
  /// **'{count} segmen'**
  String transcriptViewSegmentCount(int count);

  /// Segment count while a search is active
  ///
  /// In id, this message translates to:
  /// **'{shown} dari {total} segmen'**
  String transcriptViewFilteredSegmentCount(int shown, int total);

  /// Segments a background refine pass has not finished yet
  ///
  /// In id, this message translates to:
  /// **'{count} sedang diperbaiki'**
  String transcriptViewRefiningCount(int count);

  /// No description provided for @transcriptViewFollowPlaybackOn.
  ///
  /// In id, this message translates to:
  /// **'Ikuti pemutaran: aktif'**
  String get transcriptViewFollowPlaybackOn;

  /// No description provided for @transcriptViewFollowPlaybackOff.
  ///
  /// In id, this message translates to:
  /// **'Ikuti pemutaran: mati'**
  String get transcriptViewFollowPlaybackOff;

  /// No description provided for @transcriptViewAutoScrollOn.
  ///
  /// In id, this message translates to:
  /// **'Auto-scroll aktif'**
  String get transcriptViewAutoScrollOn;

  /// No description provided for @transcriptViewAutoScrollOff.
  ///
  /// In id, this message translates to:
  /// **'Auto-scroll mati'**
  String get transcriptViewAutoScrollOff;

  /// No description provided for @transcriptViewReviewOnly.
  ///
  /// In id, this message translates to:
  /// **'Tinjau: hanya segmen yang perlu diperiksa'**
  String get transcriptViewReviewOnly;

  /// No description provided for @transcriptViewReviewCount.
  ///
  /// In id, this message translates to:
  /// **'Tinjau ({count} segmen perlu diperiksa)'**
  String transcriptViewReviewCount(int count);

  /// No description provided for @transcriptViewCopyAll.
  ///
  /// In id, this message translates to:
  /// **'Salin semua'**
  String get transcriptViewCopyAll;

  /// No description provided for @transcriptViewNoMatches.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada segmen cocok'**
  String get transcriptViewNoMatches;

  /// Keyboard crib while editing a segment; split is a key combination
  ///
  /// In id, this message translates to:
  /// **'Enter simpan · Esc batal · {split} pisah di kursor'**
  String transcriptViewEditingHint(String split);

  /// Keyboard crib for the transcript list; move and merge are key combinations
  ///
  /// In id, this message translates to:
  /// **'↑↓ pilih · Enter sunting · {move} pindahkan · {merge} gabung ke atas'**
  String transcriptViewBrowsingHint(String move, String merge);

  /// Screen-reader label of a transcript row
  ///
  /// In id, this message translates to:
  /// **'{speaker} pada {time}: {text}'**
  String transcriptViewSegmentSemantics(
    String speaker,
    String time,
    String text,
  );

  /// Row badge: the refine pass is working on this segment now
  ///
  /// In id, this message translates to:
  /// **'Diproses…'**
  String get transcriptViewProcessing;

  /// Row badge: the refine pass has not reached this segment yet
  ///
  /// In id, this message translates to:
  /// **'Antre'**
  String get transcriptViewQueued;

  /// No description provided for @transcriptViewLowConfidence.
  ///
  /// In id, this message translates to:
  /// **'Kepercayaan rendah'**
  String get transcriptViewLowConfidence;

  /// No description provided for @transcriptViewCopySegment.
  ///
  /// In id, this message translates to:
  /// **'Salin segmen'**
  String get transcriptViewCopySegment;

  /// No description provided for @transcriptViewEdit.
  ///
  /// In id, this message translates to:
  /// **'Edit'**
  String get transcriptViewEdit;

  /// No description provided for @transcriptViewEditDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Edit Transkrip'**
  String get transcriptViewEditDialogTitle;

  /// No description provided for @transcriptViewEditHint.
  ///
  /// In id, this message translates to:
  /// **'Ketik koreksi transkrip…'**
  String get transcriptViewEditHint;

  /// No description provided for @transcriptViewRenameSpeakerTitle.
  ///
  /// In id, this message translates to:
  /// **'Ganti Nama Pembicara'**
  String get transcriptViewRenameSpeakerTitle;

  /// No description provided for @transcriptViewNewNameHint.
  ///
  /// In id, this message translates to:
  /// **'Nama baru…'**
  String get transcriptViewNewNameHint;

  /// Screen-reader label of the not-yet-confirmed live words
  ///
  /// In id, this message translates to:
  /// **'Sementara, belum final: {text}'**
  String transcriptViewTentativeSemantics(String text);

  /// Prefix before the not-yet-confirmed live words; note the trailing space
  ///
  /// In id, this message translates to:
  /// **'sementara · '**
  String get transcriptViewTentativePrefix;
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
