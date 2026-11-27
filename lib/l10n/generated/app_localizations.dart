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

  /// No description provided for @transcriptPlayerScreenBookmarkSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Tanda poin gagal disimpan: {error}'**
  String transcriptPlayerScreenBookmarkSaveFailed(String error);

  /// No description provided for @transcriptPlayerScreenAudioUnavailable.
  ///
  /// In id, this message translates to:
  /// **'File audio sumber tidak tersedia untuk diputar.'**
  String get transcriptPlayerScreenAudioUnavailable;

  /// Toast after applying the speaker manager's renames and merges
  ///
  /// In id, this message translates to:
  /// **'{count} perubahan pembicara diterapkan.'**
  String transcriptPlayerScreenSpeakerChangesApplied(int count);

  /// No description provided for @transcriptPlayerScreenSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Perubahan transkrip gagal disimpan ke {path}: {error}'**
  String transcriptPlayerScreenSaveFailed(String path, String error);

  /// Title of the OS folder picker
  ///
  /// In id, this message translates to:
  /// **'Simpan transkrip ke folder lain'**
  String get transcriptPlayerScreenSaveElsewhereDialogTitle;

  /// No description provided for @transcriptPlayerScreenSaved.
  ///
  /// In id, this message translates to:
  /// **'Transkrip tersimpan.'**
  String get transcriptPlayerScreenSaved;

  /// No description provided for @transcriptPlayerScreenBackupFailed.
  ///
  /// In id, this message translates to:
  /// **'Transkrip lama gagal dicadangkan ({error}), jadi transkrip ulang dibatalkan. Transkrip Anda tidak diubah.'**
  String transcriptPlayerScreenBackupFailed(String error);

  /// Toast after re-transcribing; model is the model's display name
  ///
  /// In id, this message translates to:
  /// **'Transkrip diperbarui: {count} segmen ({model}). Versi sebelumnya dicadangkan.'**
  String transcriptPlayerScreenRetranscribed(int count, String model);

  /// Toast action that restores the pre-re-transcription backup
  ///
  /// In id, this message translates to:
  /// **'Pulihkan'**
  String get transcriptPlayerScreenRestore;

  /// No description provided for @transcriptPlayerScreenBackupUnreadable.
  ///
  /// In id, this message translates to:
  /// **'Cadangan transkrip tidak bisa dibaca.'**
  String get transcriptPlayerScreenBackupUnreadable;

  /// No description provided for @transcriptPlayerScreenBackupRestored.
  ///
  /// In id, this message translates to:
  /// **'Transkrip sebelum transkrip ulang dipulihkan ({count} segmen).'**
  String transcriptPlayerScreenBackupRestored(int count);

  /// No description provided for @transcriptPlayerScreenGlossaryReplaceSaved.
  ///
  /// In id, this message translates to:
  /// **'Disimpan. \"{before}\" akan ditulis \"{after}\" selanjutnya.'**
  String transcriptPlayerScreenGlossaryReplaceSaved(
    String before,
    String after,
  );

  /// No description provided for @transcriptPlayerScreenGlossaryAdded.
  ///
  /// In id, this message translates to:
  /// **'\"{term}\" ditambahkan ke kamus istilah.'**
  String transcriptPlayerScreenGlossaryAdded(String term);

  /// No description provided for @transcriptPlayerScreenCloseSession.
  ///
  /// In id, this message translates to:
  /// **'Tutup sesi'**
  String get transcriptPlayerScreenCloseSession;

  /// No description provided for @transcriptPlayerScreenBack.
  ///
  /// In id, this message translates to:
  /// **'Kembali'**
  String get transcriptPlayerScreenBack;

  /// No description provided for @transcriptPlayerScreenSaveAsTemplate.
  ///
  /// In id, this message translates to:
  /// **'Simpan sebagai template rapat'**
  String get transcriptPlayerScreenSaveAsTemplate;

  /// No description provided for @transcriptPlayerScreenShortcutsTooltip.
  ///
  /// In id, this message translates to:
  /// **'Pintasan: Spasi putar/jeda · ←/→ 5 detik · J/K/L 10 detik'**
  String get transcriptPlayerScreenShortcutsTooltip;

  /// No description provided for @transcriptPlayerScreenSaveElsewhere.
  ///
  /// In id, this message translates to:
  /// **'Simpan ke folder lain'**
  String get transcriptPlayerScreenSaveElsewhere;

  /// No description provided for @transcriptPlayerScreenSaving.
  ///
  /// In id, this message translates to:
  /// **'Menyimpan…'**
  String get transcriptPlayerScreenSaving;

  /// No description provided for @transcriptPlayerScreenRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get transcriptPlayerScreenRetry;

  /// No description provided for @transcriptPlayerScreenRewind.
  ///
  /// In id, this message translates to:
  /// **'Mundur 10 detik (J)'**
  String get transcriptPlayerScreenRewind;

  /// No description provided for @transcriptPlayerScreenPause.
  ///
  /// In id, this message translates to:
  /// **'Jeda (Spasi)'**
  String get transcriptPlayerScreenPause;

  /// No description provided for @transcriptPlayerScreenPlay.
  ///
  /// In id, this message translates to:
  /// **'Putar (Spasi)'**
  String get transcriptPlayerScreenPlay;

  /// No description provided for @transcriptPlayerScreenForward.
  ///
  /// In id, this message translates to:
  /// **'Maju 10 detik (L)'**
  String get transcriptPlayerScreenForward;

  /// No description provided for @transcriptPlayerScreenPlaybackSpeed.
  ///
  /// In id, this message translates to:
  /// **'Kecepatan pemutaran'**
  String get transcriptPlayerScreenPlaybackSpeed;

  /// Header of the playback-speed menu
  ///
  /// In id, this message translates to:
  /// **'Kecepatan'**
  String get transcriptPlayerScreenSpeedHeader;

  /// Button that bookmarks the current playback position
  ///
  /// In id, this message translates to:
  /// **'Tandai di sini'**
  String get transcriptPlayerScreenBookmarkHere;

  /// Button that opens the meeting-minutes generator
  ///
  /// In id, this message translates to:
  /// **'Notulen Rapat'**
  String get transcriptPlayerScreenMinutes;

  /// No description provided for @transcriptPlayerScreenRestoreBackup.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan cadangan'**
  String get transcriptPlayerScreenRestoreBackup;

  /// No description provided for @transcriptPlayerScreenRetranscribe.
  ///
  /// In id, this message translates to:
  /// **'Transkrip Ulang'**
  String get transcriptPlayerScreenRetranscribe;

  /// No description provided for @transcriptPlayerScreenTags.
  ///
  /// In id, this message translates to:
  /// **'Tag'**
  String get transcriptPlayerScreenTags;

  /// No description provided for @transcriptPlayerScreenTagsCount.
  ///
  /// In id, this message translates to:
  /// **'Tag ({count})'**
  String transcriptPlayerScreenTagsCount(int count);

  /// No description provided for @transcriptPlayerScreenSpeakers.
  ///
  /// In id, this message translates to:
  /// **'Pembicara'**
  String get transcriptPlayerScreenSpeakers;

  /// No description provided for @transcriptPlayerScreenExport.
  ///
  /// In id, this message translates to:
  /// **'Ekspor'**
  String get transcriptPlayerScreenExport;

  /// No description provided for @transcriptPlayerScreenTemplateSaved.
  ///
  /// In id, this message translates to:
  /// **'Template \"{title}\" disimpan.'**
  String transcriptPlayerScreenTemplateSaved(String title);

  /// No description provided for @transcriptPlayerScreenShortcutHelpTitle.
  ///
  /// In id, this message translates to:
  /// **'Pintasan pemutar'**
  String get transcriptPlayerScreenShortcutHelpTitle;

  /// No description provided for @transcriptPlayerScreenShortcutHelpPlay.
  ///
  /// In id, this message translates to:
  /// **'Spasi atau K: putar atau jeda'**
  String get transcriptPlayerScreenShortcutHelpPlay;

  /// No description provided for @transcriptPlayerScreenShortcutHelpSeek5.
  ///
  /// In id, this message translates to:
  /// **'Panah kiri atau kanan: mundur atau maju 5 detik'**
  String get transcriptPlayerScreenShortcutHelpSeek5;

  /// No description provided for @transcriptPlayerScreenShortcutHelpSeek10.
  ///
  /// In id, this message translates to:
  /// **'J atau L: mundur atau maju 10 detik'**
  String get transcriptPlayerScreenShortcutHelpSeek10;

  /// No description provided for @transcriptPlayerScreenShortcutHelpClickRow.
  ///
  /// In id, this message translates to:
  /// **'Klik baris transkrip: lompat ke waktu itu'**
  String get transcriptPlayerScreenShortcutHelpClickRow;

  /// No description provided for @transcriptPlayerScreenShortcutHelpClickMark.
  ///
  /// In id, this message translates to:
  /// **'Klik tanda di garis waktu: lompat ke poin yang ditandai'**
  String get transcriptPlayerScreenShortcutHelpClickMark;

  /// No description provided for @transcriptPlayerScreenClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get transcriptPlayerScreenClose;

  /// No description provided for @fileUploadZoneQueueEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada berkas di antrean.'**
  String get fileUploadZoneQueueEmpty;

  /// No description provided for @fileUploadZoneQueueSummary.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas · {pending} menunggu'**
  String fileUploadZoneQueueSummary(int count, int pending);

  /// No description provided for @fileUploadZoneRemoveDone.
  ///
  /// In id, this message translates to:
  /// **'Hapus selesai'**
  String get fileUploadZoneRemoveDone;

  /// Empties the whole import queue
  ///
  /// In id, this message translates to:
  /// **'Kosongkan'**
  String get fileUploadZoneClear;

  /// No description provided for @fileUploadZoneProcessing.
  ///
  /// In id, this message translates to:
  /// **'Memproses…'**
  String get fileUploadZoneProcessing;

  /// No description provided for @fileUploadZoneStart.
  ///
  /// In id, this message translates to:
  /// **'Mulai Transkripsi'**
  String get fileUploadZoneStart;

  /// Appended to fileUploadZoneRejected when more than three files were skipped. Keep the leading space.
  ///
  /// In id, this message translates to:
  /// **' dan {count} lainnya'**
  String fileUploadZoneRejectedMore(int count);

  /// detail lists up to three 'file (reason)' pairs; more is fileUploadZoneRejectedMore or empty
  ///
  /// In id, this message translates to:
  /// **'Dilewati: {detail}{more}.'**
  String fileUploadZoneRejected(String detail, String more);

  /// Screen-reader label of the drop zone
  ///
  /// In id, this message translates to:
  /// **'Area impor berkas, tarik dan lepas berkas audio atau video ke sini'**
  String get fileUploadZoneDropAreaSemantics;

  /// No description provided for @fileUploadZoneDropRelease.
  ///
  /// In id, this message translates to:
  /// **'Lepaskan untuk menambahkan ke antrean'**
  String get fileUploadZoneDropRelease;

  /// No description provided for @fileUploadZoneDropHint.
  ///
  /// In id, this message translates to:
  /// **'Tarik & lepas berkas audio/video ke sini'**
  String get fileUploadZoneDropHint;

  /// No description provided for @fileUploadZoneFormats.
  ///
  /// In id, this message translates to:
  /// **'Format: {formats}'**
  String fileUploadZoneFormats(String formats);

  /// No description provided for @fileUploadZoneMaxSize.
  ///
  /// In id, this message translates to:
  /// **'Maksimum {size} per berkas'**
  String fileUploadZoneMaxSize(String size);

  /// No description provided for @fileUploadZonePickSemantics.
  ///
  /// In id, this message translates to:
  /// **'Pilih file untuk diupload'**
  String get fileUploadZonePickSemantics;

  /// No description provided for @fileUploadZonePick.
  ///
  /// In id, this message translates to:
  /// **'Pilih Berkas'**
  String get fileUploadZonePick;

  /// Label of the transcription-language picker for imported files
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get fileUploadZoneLanguage;

  /// No description provided for @fileUploadZoneAutoDetect.
  ///
  /// In id, this message translates to:
  /// **'Deteksi otomatis'**
  String get fileUploadZoneAutoDetect;

  /// Transcription-language option
  ///
  /// In id, this message translates to:
  /// **'Indonesia'**
  String get fileUploadZoneIndonesian;

  /// No description provided for @fileUploadZoneModel.
  ///
  /// In id, this message translates to:
  /// **'Model'**
  String get fileUploadZoneModel;

  /// No description provided for @fileUploadZoneSpeakerCount.
  ///
  /// In id, this message translates to:
  /// **'Jumlah pembicara'**
  String get fileUploadZoneSpeakerCount;

  /// Option in the expected-speaker-count picker
  ///
  /// In id, this message translates to:
  /// **'{count} orang'**
  String fileUploadZoneSpeakerCountOption(int count);

  /// No description provided for @fileUploadZonePreviewFailed.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa memutar berkas ini.'**
  String get fileUploadZonePreviewFailed;

  /// Screen-reader label of a queued file
  ///
  /// In id, this message translates to:
  /// **'{filename}: {status}'**
  String fileUploadZoneEntrySemantics(String filename, String status);

  /// No description provided for @fileUploadZoneEntrySemanticsError.
  ///
  /// In id, this message translates to:
  /// **'{filename}: {status}, error: {error}'**
  String fileUploadZoneEntrySemanticsError(
    String filename,
    String status,
    String error,
  );

  /// No description provided for @fileUploadZoneStopPreview.
  ///
  /// In id, this message translates to:
  /// **'Hentikan pratinjau'**
  String get fileUploadZoneStopPreview;

  /// No description provided for @fileUploadZonePreview.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau audio'**
  String get fileUploadZonePreview;

  /// No description provided for @fileUploadZoneRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get fileUploadZoneRetry;

  /// No description provided for @fileUploadZoneCancelFile.
  ///
  /// In id, this message translates to:
  /// **'Batalkan berkas ini'**
  String get fileUploadZoneCancelFile;

  /// No description provided for @fileUploadZoneStatusQueued.
  ///
  /// In id, this message translates to:
  /// **'Antre'**
  String get fileUploadZoneStatusQueued;

  /// No description provided for @fileUploadZoneStatusDecoding.
  ///
  /// In id, this message translates to:
  /// **'Membaca berkas'**
  String get fileUploadZoneStatusDecoding;

  /// No description provided for @fileUploadZoneStatusTranscribing.
  ///
  /// In id, this message translates to:
  /// **'Transkripsi'**
  String get fileUploadZoneStatusTranscribing;

  /// No description provided for @fileUploadZoneStatusDone.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get fileUploadZoneStatusDone;

  /// No description provided for @fileUploadZoneStatusError.
  ///
  /// In id, this message translates to:
  /// **'Gagal'**
  String get fileUploadZoneStatusError;

  /// No description provided for @fileUploadZoneStatusCancelled.
  ///
  /// In id, this message translates to:
  /// **'Dibatalkan'**
  String get fileUploadZoneStatusCancelled;

  /// No description provided for @libraryScreenDeleted.
  ///
  /// In id, this message translates to:
  /// **'\"{title}\" dihapus.'**
  String libraryScreenDeleted(String title);

  /// No description provided for @libraryScreenUndo.
  ///
  /// In id, this message translates to:
  /// **'Urungkan'**
  String get libraryScreenUndo;

  /// No description provided for @libraryScreenRenameTitle.
  ///
  /// In id, this message translates to:
  /// **'Ganti Nama Sesi'**
  String get libraryScreenRenameTitle;

  /// No description provided for @libraryScreenRenameLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama sesi'**
  String get libraryScreenRenameLabel;

  /// No description provided for @libraryScreenRenameFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengganti nama: {error}'**
  String libraryScreenRenameFailed(String error);

  /// Title of the OS save dialog
  ///
  /// In id, this message translates to:
  /// **'Simpan arsip sesi'**
  String get libraryScreenSaveArchiveDialogTitle;

  /// No description provided for @libraryScreenArchiveSaved.
  ///
  /// In id, this message translates to:
  /// **'Arsip sesi tersimpan: {path}'**
  String libraryScreenArchiveSaved(String path);

  /// No description provided for @libraryScreenArchiveExportFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengekspor arsip sesi: {error}'**
  String libraryScreenArchiveExportFailed(String error);

  /// Title of the OS open dialog
  ///
  /// In id, this message translates to:
  /// **'Pilih arsip sesi (.zip)'**
  String get libraryScreenPickArchiveDialogTitle;

  /// No description provided for @libraryScreenImportSkipped.
  ///
  /// In id, this message translates to:
  /// **'Impor arsip sesi dilewati.'**
  String get libraryScreenImportSkipped;

  /// No description provided for @libraryScreenImported.
  ///
  /// In id, this message translates to:
  /// **'Sesi \"{name}\" diimpor.'**
  String libraryScreenImported(String name);

  /// No description provided for @libraryScreenConflictTitle.
  ///
  /// In id, this message translates to:
  /// **'Sesi sudah ada'**
  String get libraryScreenConflictTitle;

  /// No description provided for @libraryScreenConflictBody.
  ///
  /// In id, this message translates to:
  /// **'Sesi dengan nama \"{name}\" sudah ada di perpustakaan ini. Apa yang ingin dilakukan?'**
  String libraryScreenConflictBody(String name);

  /// No description provided for @libraryScreenImportDuplicate.
  ///
  /// In id, this message translates to:
  /// **'Impor sebagai duplikat'**
  String get libraryScreenImportDuplicate;

  /// No description provided for @libraryScreenOverwrite.
  ///
  /// In id, this message translates to:
  /// **'Timpa'**
  String get libraryScreenOverwrite;

  /// No description provided for @libraryScreenOpenFailed.
  ///
  /// In id, this message translates to:
  /// **'\"{title}\" tidak bisa dibuka.'**
  String libraryScreenOpenFailed(String title);

  /// No description provided for @libraryScreenTitle.
  ///
  /// In id, this message translates to:
  /// **'Perpustakaan'**
  String get libraryScreenTitle;

  /// No description provided for @libraryScreenBack.
  ///
  /// In id, this message translates to:
  /// **'Kembali'**
  String get libraryScreenBack;

  /// No description provided for @libraryScreenTabSessions.
  ///
  /// In id, this message translates to:
  /// **'Sesi'**
  String get libraryScreenTabSessions;

  /// No description provided for @libraryScreenTabImport.
  ///
  /// In id, this message translates to:
  /// **'Impor Berkas'**
  String get libraryScreenTabImport;

  /// No description provided for @libraryScreenSearchHint.
  ///
  /// In id, this message translates to:
  /// **'Cari judul, isi transkrip, atau ringkasan…'**
  String get libraryScreenSearchHint;

  /// No description provided for @libraryScreenClearSearch.
  ///
  /// In id, this message translates to:
  /// **'Bersihkan pencarian'**
  String get libraryScreenClearSearch;

  /// No description provided for @libraryScreenDeepSearching.
  ///
  /// In id, this message translates to:
  /// **'Mencari di dalam transkrip…'**
  String get libraryScreenDeepSearching;

  /// No description provided for @libraryScreenEmptyTitle.
  ///
  /// In id, this message translates to:
  /// **'Belum ada sesi tersimpan'**
  String get libraryScreenEmptyTitle;

  /// No description provided for @libraryScreenEmptySubtitle.
  ///
  /// In id, this message translates to:
  /// **'Sesi transkripsi akan muncul di sini'**
  String get libraryScreenEmptySubtitle;

  /// No description provided for @libraryScreenNoMatch.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada sesi cocok'**
  String get libraryScreenNoMatch;

  /// No description provided for @libraryScreenImportArchive.
  ///
  /// In id, this message translates to:
  /// **'Impor arsip sesi (.zip)'**
  String get libraryScreenImportArchive;

  /// No description provided for @exportDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Ekspor \"{title}\"'**
  String exportDialogTitle(String title);

  /// No description provided for @exportDialogIncomplete.
  ///
  /// In id, this message translates to:
  /// **'Transkrip sesi ini belum lengkap, masih ada audio yang sedang ditranskripsi. Hasil ekspor sekarang akan kehilangan bagian itu.'**
  String get exportDialogIncomplete;

  /// No description provided for @exportDialogChooseFormat.
  ///
  /// In id, this message translates to:
  /// **'Pilih format ekspor:'**
  String get exportDialogChooseFormat;

  /// Description of the Markdown export format
  ///
  /// In id, this message translates to:
  /// **'Dengan waktu & nama pembicara'**
  String get exportDialogFormatMd;

  /// Description of the TXT export format
  ///
  /// In id, this message translates to:
  /// **'Teks biasa tanpa waktu'**
  String get exportDialogFormatTxt;

  /// Description of the JSON export format
  ///
  /// In id, this message translates to:
  /// **'Data lengkap untuk program lain'**
  String get exportDialogFormatJson;

  /// Description of the SRT export format
  ///
  /// In id, this message translates to:
  /// **'Takarir untuk pemutar video'**
  String get exportDialogFormatSrt;

  /// Description of the VTT export format
  ///
  /// In id, this message translates to:
  /// **'Takarir untuk web'**
  String get exportDialogFormatVtt;

  /// Description of the HTML export format
  ///
  /// In id, this message translates to:
  /// **'Halaman web yang sudah ditata'**
  String get exportDialogFormatHtml;

  /// Description of the DOCX export format
  ///
  /// In id, this message translates to:
  /// **'Dokumen Microsoft Word'**
  String get exportDialogFormatDocx;

  /// Description of the PDF export format
  ///
  /// In id, this message translates to:
  /// **'Dokumen siap cetak, font ikut disertakan'**
  String get exportDialogFormatPdf;

  /// Description of the CSV export format
  ///
  /// In id, this message translates to:
  /// **'Tabel per segmen untuk spreadsheet'**
  String get exportDialogFormatCsv;

  /// "Poin Penting" is the section heading the exporter writes into the document, which stays Indonesian, so it is quoted verbatim
  ///
  /// In id, this message translates to:
  /// **'{count} poin penting disertakan sebagai bagian \"Poin Penting\"'**
  String exportDialogBookmarksIncluded(int count);

  /// No description provided for @exportDialogSummaryIncluded.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan AI disertakan di Markdown, TXT, HTML & DOCX'**
  String get exportDialogSummaryIncluded;

  /// No description provided for @exportDialogPdpRedaction.
  ///
  /// In id, this message translates to:
  /// **'Mode Kepatuhan PDP aktif: data pribadi akan disamarkan di file hasil ekspor. Transkrip tersimpan tidak berubah.'**
  String get exportDialogPdpRedaction;

  /// Opens the redaction preview
  ///
  /// In id, this message translates to:
  /// **'Pratinjau'**
  String get exportDialogPreview;

  /// No description provided for @exportDialogSingleFolder.
  ///
  /// In id, this message translates to:
  /// **'Semua file dalam 1 folder'**
  String get exportDialogSingleFolder;

  /// No description provided for @exportDialogChooseFolder.
  ///
  /// In id, this message translates to:
  /// **'Pilih Folder'**
  String get exportDialogChooseFolder;

  /// Title of the OS folder picker
  ///
  /// In id, this message translates to:
  /// **'Pilih folder ekspor untuk \"{title}\"'**
  String exportDialogFolderPickerTitle(String title);

  /// No description provided for @exportDialogExporting.
  ///
  /// In id, this message translates to:
  /// **'Mengekspor {count} format…'**
  String exportDialogExporting(int count);

  /// No description provided for @exportDialogSuccess.
  ///
  /// In id, this message translates to:
  /// **'Ekspor berhasil ke: {path}'**
  String exportDialogSuccess(String path);

  /// No description provided for @exportDialogShare.
  ///
  /// In id, this message translates to:
  /// **'Bagikan'**
  String get exportDialogShare;

  /// No description provided for @exportDialogFailed.
  ///
  /// In id, this message translates to:
  /// **'Ekspor gagal: {error}'**
  String exportDialogFailed(String error);

  /// No description provided for @speakerManagerDialogRenameTitle.
  ///
  /// In id, this message translates to:
  /// **'Ganti nama \"{name}\"'**
  String speakerManagerDialogRenameTitle(String name);

  /// No description provided for @speakerManagerDialogNameLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get speakerManagerDialogNameLabel;

  /// No description provided for @speakerManagerDialogNameHelper.
  ///
  /// In id, this message translates to:
  /// **'Berlaku untuk seluruh sesi ini.'**
  String get speakerManagerDialogNameHelper;

  /// Confirms a speaker rename
  ///
  /// In id, this message translates to:
  /// **'Ganti'**
  String get speakerManagerDialogRenameConfirm;

  /// No description provided for @speakerManagerDialogMergeTitle.
  ///
  /// In id, this message translates to:
  /// **'Gabungkan \"{name}\" ke siapa?'**
  String speakerManagerDialogMergeTitle(String name);

  /// No description provided for @speakerManagerDialogMergeOption.
  ///
  /// In id, this message translates to:
  /// **'{name} ({count} segmen)'**
  String speakerManagerDialogMergeOption(String name, int count);

  /// No description provided for @speakerManagerDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Kelola Pembicara'**
  String get speakerManagerDialogTitle;

  /// No description provided for @speakerManagerDialogNoSpeakers.
  ///
  /// In id, this message translates to:
  /// **'Transkrip ini belum punya pembicara.'**
  String get speakerManagerDialogNoSpeakers;

  /// No description provided for @speakerManagerDialogPending.
  ///
  /// In id, this message translates to:
  /// **'{count} perubahan menunggu. Tekan Terapkan untuk menuliskannya ke transkrip.'**
  String speakerManagerDialogPending(int count);

  /// No description provided for @speakerManagerDialogNothingRemembered.
  ///
  /// In id, this message translates to:
  /// **'Belum ada nama yang diingat.'**
  String get speakerManagerDialogNothingRemembered;

  /// No description provided for @speakerManagerDialogForgotten.
  ///
  /// In id, this message translates to:
  /// **'Nama pembicara yang diingat dihapus.'**
  String get speakerManagerDialogForgotten;

  /// No description provided for @speakerManagerDialogForgetAll.
  ///
  /// In id, this message translates to:
  /// **'Lupakan nama tersimpan'**
  String get speakerManagerDialogForgetAll;

  /// No description provided for @speakerManagerDialogApply.
  ///
  /// In id, this message translates to:
  /// **'Terapkan'**
  String get speakerManagerDialogApply;

  /// Speaker row stats for a speaker who talked under a minute
  ///
  /// In id, this message translates to:
  /// **'{segments} segmen · {seconds} detik'**
  String speakerManagerDialogStatsSeconds(int segments, int seconds);

  /// No description provided for @speakerManagerDialogStatsMinutes.
  ///
  /// In id, this message translates to:
  /// **'{segments} segmen · {minutes} menit'**
  String speakerManagerDialogStatsMinutes(int segments, int minutes);

  /// No description provided for @speakerManagerDialogRename.
  ///
  /// In id, this message translates to:
  /// **'Ganti nama'**
  String get speakerManagerDialogRename;

  /// No description provided for @speakerManagerDialogMerge.
  ///
  /// In id, this message translates to:
  /// **'Gabungkan dengan pembicara lain'**
  String get speakerManagerDialogMerge;

  /// No description provided for @speakerManagerDialogNoMerge.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada pembicara lain untuk digabung'**
  String get speakerManagerDialogNoMerge;

  /// No description provided for @speakerManagerDialogSuggestion.
  ///
  /// In id, this message translates to:
  /// **'Diingat dari rapat sebelumnya: {name}'**
  String speakerManagerDialogSuggestion(String name);

  /// No description provided for @speakerManagerDialogUseSuggestion.
  ///
  /// In id, this message translates to:
  /// **'Pakai'**
  String get speakerManagerDialogUseSuggestion;

  /// label is the diarizer's speaker label, e.g. Pembicara 1
  ///
  /// In id, this message translates to:
  /// **'Ingat nama ini untuk label \"{label}\" di rapat berikutnya (ganti namanya dulu)'**
  String speakerManagerDialogRememberUnrenamed(String label);

  /// No description provided for @speakerManagerDialogRemember.
  ///
  /// In id, this message translates to:
  /// **'Ingat \"{name}\" untuk label \"{label}\" di rapat berikutnya'**
  String speakerManagerDialogRemember(String name, String label);

  /// Compact session duration, e.g. 1j 32m
  ///
  /// In id, this message translates to:
  /// **'{hours}j {minutes}m'**
  String sessionCardDurationHours(int hours, int minutes);

  /// No description provided for @sessionCardDurationMinutes.
  ///
  /// In id, this message translates to:
  /// **'{minutes} menit'**
  String sessionCardDurationMinutes(int minutes);

  /// Session date; month is one of the sessionCardMonth* abbreviations
  ///
  /// In id, this message translates to:
  /// **'{day} {month} {year}'**
  String sessionCardDate(String day, String month, String year);

  /// No description provided for @sessionCardMonthJan.
  ///
  /// In id, this message translates to:
  /// **'Jan'**
  String get sessionCardMonthJan;

  /// No description provided for @sessionCardMonthFeb.
  ///
  /// In id, this message translates to:
  /// **'Feb'**
  String get sessionCardMonthFeb;

  /// No description provided for @sessionCardMonthMar.
  ///
  /// In id, this message translates to:
  /// **'Mar'**
  String get sessionCardMonthMar;

  /// No description provided for @sessionCardMonthApr.
  ///
  /// In id, this message translates to:
  /// **'Apr'**
  String get sessionCardMonthApr;

  /// No description provided for @sessionCardMonthMay.
  ///
  /// In id, this message translates to:
  /// **'Mei'**
  String get sessionCardMonthMay;

  /// No description provided for @sessionCardMonthJun.
  ///
  /// In id, this message translates to:
  /// **'Jun'**
  String get sessionCardMonthJun;

  /// No description provided for @sessionCardMonthJul.
  ///
  /// In id, this message translates to:
  /// **'Jul'**
  String get sessionCardMonthJul;

  /// No description provided for @sessionCardMonthAug.
  ///
  /// In id, this message translates to:
  /// **'Agu'**
  String get sessionCardMonthAug;

  /// No description provided for @sessionCardMonthSep.
  ///
  /// In id, this message translates to:
  /// **'Sep'**
  String get sessionCardMonthSep;

  /// No description provided for @sessionCardMonthOct.
  ///
  /// In id, this message translates to:
  /// **'Okt'**
  String get sessionCardMonthOct;

  /// No description provided for @sessionCardMonthNov.
  ///
  /// In id, this message translates to:
  /// **'Nov'**
  String get sessionCardMonthNov;

  /// No description provided for @sessionCardMonthDec.
  ///
  /// In id, this message translates to:
  /// **'Des'**
  String get sessionCardMonthDec;

  /// No description provided for @sessionCardHasSummary.
  ///
  /// In id, this message translates to:
  /// **'Punya ringkasan AI'**
  String get sessionCardHasSummary;

  /// No description provided for @sessionCardSegments.
  ///
  /// In id, this message translates to:
  /// **'{count} segmen'**
  String sessionCardSegments(int count);

  /// No description provided for @sessionCardRename.
  ///
  /// In id, this message translates to:
  /// **'Ganti nama'**
  String get sessionCardRename;

  /// No description provided for @sessionCardExport.
  ///
  /// In id, this message translates to:
  /// **'Ekspor'**
  String get sessionCardExport;

  /// No description provided for @sessionCardExportArchive.
  ///
  /// In id, this message translates to:
  /// **'Ekspor sebagai arsip (.zip)'**
  String get sessionCardExportArchive;

  /// No description provided for @sessionCardDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get sessionCardDelete;

  /// No description provided for @dictionaryLearningDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Ingat koreksi ini?'**
  String get dictionaryLearningDialogTitle;

  /// No description provided for @dictionaryLearningDialogDescription.
  ///
  /// In id, this message translates to:
  /// **'Anda mengubah satu kata. Trareon bisa mengingatnya agar tidak perlu dikoreksi lagi di rapat berikutnya.'**
  String get dictionaryLearningDialogDescription;

  /// No description provided for @dictionaryLearningDialogDontRemember.
  ///
  /// In id, this message translates to:
  /// **'Jangan ingat'**
  String get dictionaryLearningDialogDontRemember;

  /// No description provided for @dictionaryLearningDialogAddToGlossary.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan \"{term}\" ke kamus istilah'**
  String dictionaryLearningDialogAddToGlossary(String term);

  /// No description provided for @dictionaryLearningDialogAddToGlossaryHelper.
  ///
  /// In id, this message translates to:
  /// **'Mesin pengenal suara diberi tahu istilah ini sebelum mentranskrip, sehingga lebih mungkin menuliskannya dengan benar sejak awal.'**
  String get dictionaryLearningDialogAddToGlossaryHelper;

  /// No description provided for @dictionaryLearningDialogAutoReplace.
  ///
  /// In id, this message translates to:
  /// **'Ganti otomatis \"{before}\" → \"{after}\" selanjutnya'**
  String dictionaryLearningDialogAutoReplace(String before, String after);

  /// No description provided for @dictionaryLearningDialogAutoReplaceHelper.
  ///
  /// In id, this message translates to:
  /// **'Setiap kata \"{before}\" yang berdiri sendiri akan ditulis \"{after}\" di transkrip berikutnya. Bisa dihapus di Pengaturan → Kamus istilah.'**
  String dictionaryLearningDialogAutoReplaceHelper(String before, String after);

  /// No description provided for @dictionaryLearningDialogPickOne.
  ///
  /// In id, this message translates to:
  /// **'Pilih setidaknya satu agar ada yang disimpan.'**
  String get dictionaryLearningDialogPickOne;

  /// No description provided for @tagEditorDialogTitle.
  ///
  /// In id, this message translates to:
  /// **'Tag sesi'**
  String get tagEditorDialogTitle;

  /// No description provided for @tagEditorDialogDescription.
  ///
  /// In id, this message translates to:
  /// **'Tag dipakai untuk memfilter daftar sesi di bilah kiri. Tidak ada berkas yang dipindahkan.'**
  String get tagEditorDialogDescription;

  /// No description provided for @tagEditorDialogAddLabel.
  ///
  /// In id, this message translates to:
  /// **'Tambah tag'**
  String get tagEditorDialogAddLabel;

  /// No description provided for @tagEditorDialogAdd.
  ///
  /// In id, this message translates to:
  /// **'Tambah'**
  String get tagEditorDialogAdd;

  /// No description provided for @tagEditorDialogEmpty.
  ///
  /// In id, this message translates to:
  /// **'Sesi ini belum punya tag.'**
  String get tagEditorDialogEmpty;

  /// No description provided for @tagEditorDialogSuggestions.
  ///
  /// In id, this message translates to:
  /// **'Tag lain di perpustakaan'**
  String get tagEditorDialogSuggestions;

  /// Keyboard shortcut action name
  ///
  /// In id, this message translates to:
  /// **'Mulai atau berhenti merekam'**
  String get appShortcutsStartStop;

  /// Keyboard shortcut action name
  ///
  /// In id, this message translates to:
  /// **'Jeda atau lanjutkan'**
  String get appShortcutsPauseResume;

  /// Keyboard shortcut action name
  ///
  /// In id, this message translates to:
  /// **'Cari di riwayat sesi'**
  String get appShortcutsSearchSessions;

  /// Keyboard shortcut action name
  ///
  /// In id, this message translates to:
  /// **'Tandai poin penting'**
  String get appShortcutsBookmark;

  /// Keyboard shortcut action name
  ///
  /// In id, this message translates to:
  /// **'Buka Pengaturan'**
  String get appShortcutsSettings;

  /// Keyboard shortcut action name
  ///
  /// In id, this message translates to:
  /// **'Tampilkan pintasan keyboard'**
  String get appShortcutsShortcutsPanel;

  /// Keyboard shortcut action name
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan atau tampilkan sidebar'**
  String get appShortcutsToggleSidebar;

  /// Coarse duration in list rows and status lines
  ///
  /// In id, this message translates to:
  /// **'{seconds} detik'**
  String formatTimeSeconds(int seconds);

  /// Coarse duration in list rows and status lines
  ///
  /// In id, this message translates to:
  /// **'{minutes} menit'**
  String formatTimeMinutes(int minutes);

  /// Coarse duration in list rows and status lines
  ///
  /// In id, this message translates to:
  /// **'{hours} jam'**
  String formatTimeHours(int hours);

  /// Coarse duration in list rows and status lines
  ///
  /// In id, this message translates to:
  /// **'{hours} jam {minutes} menit'**
  String formatTimeHoursMinutes(int hours, int minutes);

  /// No description provided for @modelDownloadCardNotDownloaded.
  ///
  /// In id, this message translates to:
  /// **'Belum diunduh'**
  String get modelDownloadCardNotDownloaded;

  /// No description provided for @modelDownloadCardReady.
  ///
  /// In id, this message translates to:
  /// **'Siap'**
  String get modelDownloadCardReady;

  /// No description provided for @modelDownloadCardFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal, coba lagi'**
  String get modelDownloadCardFailed;

  /// Screen-reader value of a progress bar or level meter
  ///
  /// In id, this message translates to:
  /// **'{percent} persen'**
  String appFeedbackPercent(int percent);

  /// Default tooltip of a chip's delete button
  ///
  /// In id, this message translates to:
  /// **'Hapus {label}'**
  String appChipDelete(String label);

  /// No description provided for @resourceIndicatorSemantics.
  ///
  /// In id, this message translates to:
  /// **'Penggunaan memori tinggi, pertimbangkan tutup aplikasi lain'**
  String get resourceIndicatorSemantics;

  /// Memory-pressure pill shown while recording
  ///
  /// In id, this message translates to:
  /// **'Tinggi, pertimbangkan tutup aplikasi lain'**
  String get resourceIndicatorHigh;

  /// No description provided for @summaryModelSaveActionItemsFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan tindak lanjut: {error}'**
  String summaryModelSaveActionItemsFailed(String error);

  /// No description provided for @summaryModelDisabled.
  ///
  /// In id, this message translates to:
  /// **'Ringkasan AI belum diaktifkan. Nyalakan di Pengaturan → Ringkasan AI.'**
  String get summaryModelDisabled;

  /// No description provided for @summaryModelNotConfigured.
  ///
  /// In id, this message translates to:
  /// **'Endpoint atau model ringkasan belum diisi. Lengkapi di Pengaturan → Ringkasan AI.'**
  String get summaryModelNotConfigured;

  /// No description provided for @summaryModelEmptyTranscriptSummarize.
  ///
  /// In id, this message translates to:
  /// **'Transkrip kosong, tidak ada yang bisa diringkas.'**
  String get summaryModelEmptyTranscriptSummarize;

  /// No description provided for @summaryModelTemplateUnusable.
  ///
  /// In id, this message translates to:
  /// **'Template \"{name}\" tidak bisa dipakai: {error}'**
  String summaryModelTemplateUnusable(String name, String error);

  /// No description provided for @summaryModelGenerateFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat ringkasan (transkrip tetap aman): {error}'**
  String summaryModelGenerateFailed(String error);

  /// No description provided for @summaryModelEmptyTranscriptMerge.
  ///
  /// In id, this message translates to:
  /// **'Transkrip kosong, tidak ada yang bisa digabung.'**
  String get summaryModelEmptyTranscriptMerge;

  /// No description provided for @summaryModelEnhanceFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menggabungkan catatan dengan transkrip: {error}'**
  String summaryModelEnhanceFailed(String error);

  /// No description provided for @summaryModelSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan ringkasan: {error}'**
  String summaryModelSaveFailed(String error);
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
