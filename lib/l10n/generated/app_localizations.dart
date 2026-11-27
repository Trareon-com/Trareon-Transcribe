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
