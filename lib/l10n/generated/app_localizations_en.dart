// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Trareon Transcribe';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageLabel => 'Interface language';

  @override
  String get languageSubtitle =>
      'The language of buttons and menus. Does not change the transcription language.';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get alreadyRunningTitle => 'Trareon Transcribe is already running';

  @override
  String get alreadyRunningBody =>
      'Only one instance of Trareon Transcribe can run at a time. Close this window and use the one that is already open.';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionHide => 'Hide';

  @override
  String get actionCancelThis => 'Cancel';

  @override
  String get actionCancelAll => 'Cancel all';

  @override
  String get enhanceQueueTitle => 'Refining transcript';

  @override
  String get enhanceQueuePaused => 'Paused while a recording is in progress.';

  @override
  String get enhanceJobRunning =>
      'Using the accurate model… your current transcript stays safe until it finishes.';

  @override
  String get enhanceJobFailed =>
      'Failed. The previous transcript is still in use.';

  @override
  String get enhanceJobQueued => 'Waiting in the queue.';

  @override
  String storageSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
      zero: 'No sessions yet',
    );
    return '$_temp0';
  }

  @override
  String storageTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Storage: $count sessions saved',
      one: 'Storage: 1 session saved',
      zero: 'Storage: no sessions saved yet',
    );
    return '$_temp0';
  }

  @override
  String get storageEmptyCompact => '📂 Empty';

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
  String get bookmarkAdd => 'Mark';

  @override
  String get bookmarkAddTooltip =>
      'Mark an important point at the current position (Ctrl+B)';

  @override
  String get bookmarkAddWithNoteTooltip => 'Mark and write a note';

  @override
  String bookmarkNoteDialogTitle(String time) {
    return 'Note for $time';
  }

  @override
  String get bookmarkNoteLabel => 'Note (optional)';

  @override
  String get bookmarkNoteHint => 'e.g. key decision, follow-up';

  @override
  String bookmarkMarkedAt(String time) {
    return 'Point marked at $time';
  }

  @override
  String get bookmarkNone => 'No points marked yet.';

  @override
  String bookmarkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points marked.',
      one: '1 point marked.',
    );
    return '$_temp0';
  }

  @override
  String bookmarkRemoveTooltip(String time) {
    return 'Remove the mark at $time';
  }

  @override
  String bookmarkJumpTooltip(String time) {
    return 'Click: jump to $time · Hold: edit note';
  }

  @override
  String get bookmarkEditNoteTooltip => 'Click to edit the note';

  @override
  String bookmarkRowLabel(String time, String note) {
    return '$time · $note';
  }

  @override
  String transcriptPlayerScreenBookmarkSaveFailed(String error) {
    return 'Couldn\'t save the bookmark: $error';
  }

  @override
  String get transcriptPlayerScreenAudioUnavailable =>
      'The source audio file isn\'t available for playback.';

  @override
  String transcriptPlayerScreenSpeakerChangesApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count speaker changes applied.',
      one: '1 speaker change applied.',
    );
    return '$_temp0';
  }

  @override
  String transcriptPlayerScreenSaveFailed(String path, String error) {
    return 'Couldn\'t save transcript changes to $path: $error';
  }

  @override
  String get transcriptPlayerScreenSaveElsewhereDialogTitle =>
      'Save transcript to another folder';

  @override
  String get transcriptPlayerScreenSaved => 'Transcript saved.';

  @override
  String transcriptPlayerScreenBackupFailed(String error) {
    return 'Couldn\'t back up the current transcript ($error), so re-transcription was cancelled. Your transcript is unchanged.';
  }

  @override
  String transcriptPlayerScreenRetranscribed(int count, String model) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '1 segment',
    );
    return 'Transcript updated: $_temp0 ($model). The previous version was backed up.';
  }

  @override
  String get transcriptPlayerScreenRestore => 'Restore';

  @override
  String get transcriptPlayerScreenBackupUnreadable =>
      'The transcript backup couldn\'t be read.';

  @override
  String transcriptPlayerScreenBackupRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '1 segment',
    );
    return 'Restored the transcript from before re-transcription ($_temp0).';
  }

  @override
  String transcriptPlayerScreenGlossaryReplaceSaved(
    String before,
    String after,
  ) {
    return 'Saved. \"$before\" will be written as \"$after\" from now on.';
  }

  @override
  String transcriptPlayerScreenGlossaryAdded(String term) {
    return '\"$term\" added to the glossary.';
  }

  @override
  String get transcriptPlayerScreenCloseSession => 'Close session';

  @override
  String get transcriptPlayerScreenBack => 'Back';

  @override
  String get transcriptPlayerScreenSaveAsTemplate => 'Save as meeting template';

  @override
  String get transcriptPlayerScreenShortcutsTooltip =>
      'Shortcuts: Space play/pause · ←/→ 5 sec · J/K/L 10 sec';

  @override
  String get transcriptPlayerScreenSaveElsewhere => 'Save to another folder';

  @override
  String get transcriptPlayerScreenSaving => 'Saving…';

  @override
  String get transcriptPlayerScreenRetry => 'Try again';

  @override
  String get transcriptPlayerScreenRewind => 'Back 10 seconds (J)';

  @override
  String get transcriptPlayerScreenPause => 'Pause (Space)';

  @override
  String get transcriptPlayerScreenPlay => 'Play (Space)';

  @override
  String get transcriptPlayerScreenForward => 'Forward 10 seconds (L)';

  @override
  String get transcriptPlayerScreenPlaybackSpeed => 'Playback speed';

  @override
  String get transcriptPlayerScreenSpeedHeader => 'Speed';

  @override
  String get transcriptPlayerScreenBookmarkHere => 'Mark here';

  @override
  String get transcriptPlayerScreenMinutes => 'Meeting minutes';

  @override
  String get transcriptPlayerScreenRestoreBackup => 'Restore backup';

  @override
  String get transcriptPlayerScreenRetranscribe => 'Re-transcribe';

  @override
  String get transcriptPlayerScreenTags => 'Tags';

  @override
  String transcriptPlayerScreenTagsCount(int count) {
    return 'Tags ($count)';
  }

  @override
  String get transcriptPlayerScreenSpeakers => 'Speakers';

  @override
  String get transcriptPlayerScreenExport => 'Export';

  @override
  String transcriptPlayerScreenTemplateSaved(String title) {
    return 'Template \"$title\" saved.';
  }

  @override
  String get transcriptPlayerScreenShortcutHelpTitle => 'Player shortcuts';

  @override
  String get transcriptPlayerScreenShortcutHelpPlay =>
      'Space or K: play or pause';

  @override
  String get transcriptPlayerScreenShortcutHelpSeek5 =>
      'Left or right arrow: back or forward 5 seconds';

  @override
  String get transcriptPlayerScreenShortcutHelpSeek10 =>
      'J or L: back or forward 10 seconds';

  @override
  String get transcriptPlayerScreenShortcutHelpClickRow =>
      'Click a transcript line: jump to that time';

  @override
  String get transcriptPlayerScreenShortcutHelpClickMark =>
      'Click a marker on the timeline: jump to that bookmark';

  @override
  String get transcriptPlayerScreenClose => 'Close';

  @override
  String get fileUploadZoneQueueEmpty => 'No files in the queue yet.';

  @override
  String fileUploadZoneQueueSummary(int count, int pending) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 · $pending waiting';
  }

  @override
  String get fileUploadZoneRemoveDone => 'Remove finished';

  @override
  String get fileUploadZoneClear => 'Clear';

  @override
  String get fileUploadZoneProcessing => 'Processing…';

  @override
  String get fileUploadZoneStart => 'Start transcription';

  @override
  String fileUploadZoneRejectedMore(int count) {
    return ' and $count more';
  }

  @override
  String fileUploadZoneRejected(String detail, String more) {
    return 'Skipped: $detail$more.';
  }

  @override
  String get fileUploadZoneDropAreaSemantics =>
      'File import area, drag and drop audio or video files here';

  @override
  String get fileUploadZoneDropRelease => 'Release to add to the queue';

  @override
  String get fileUploadZoneDropHint => 'Drag & drop audio/video files here';

  @override
  String fileUploadZoneFormats(String formats) {
    return 'Formats: $formats';
  }

  @override
  String fileUploadZoneMaxSize(String size) {
    return 'Up to $size per file';
  }

  @override
  String get fileUploadZonePickSemantics => 'Choose files to upload';

  @override
  String get fileUploadZonePick => 'Choose files';

  @override
  String get fileUploadZoneLanguage => 'Language';

  @override
  String get fileUploadZoneAutoDetect => 'Auto-detect';

  @override
  String get fileUploadZoneIndonesian => 'Indonesian';

  @override
  String get fileUploadZoneModel => 'Model';

  @override
  String get fileUploadZoneSpeakerCount => 'Number of speakers';

  @override
  String fileUploadZoneSpeakerCountOption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get fileUploadZonePreviewFailed => 'Can\'t play this file.';

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
  String get fileUploadZoneStopPreview => 'Stop preview';

  @override
  String get fileUploadZonePreview => 'Preview audio';

  @override
  String get fileUploadZoneRetry => 'Try again';

  @override
  String get fileUploadZoneCancelFile => 'Cancel this file';

  @override
  String get fileUploadZoneStatusQueued => 'Queued';

  @override
  String get fileUploadZoneStatusDecoding => 'Reading file';

  @override
  String get fileUploadZoneStatusTranscribing => 'Transcribing';

  @override
  String get fileUploadZoneStatusDone => 'Done';

  @override
  String get fileUploadZoneStatusError => 'Failed';

  @override
  String get fileUploadZoneStatusCancelled => 'Cancelled';

  @override
  String libraryScreenDeleted(String title) {
    return '\"$title\" deleted.';
  }

  @override
  String get libraryScreenUndo => 'Undo';

  @override
  String get libraryScreenRenameTitle => 'Rename session';

  @override
  String get libraryScreenRenameLabel => 'Session name';

  @override
  String libraryScreenRenameFailed(String error) {
    return 'Couldn\'t rename: $error';
  }

  @override
  String get libraryScreenSaveArchiveDialogTitle => 'Save session archive';

  @override
  String libraryScreenArchiveSaved(String path) {
    return 'Session archive saved: $path';
  }

  @override
  String libraryScreenArchiveExportFailed(String error) {
    return 'Couldn\'t export the session archive: $error';
  }

  @override
  String get libraryScreenPickArchiveDialogTitle =>
      'Choose a session archive (.zip)';

  @override
  String get libraryScreenImportSkipped => 'Session archive import skipped.';

  @override
  String libraryScreenImported(String name) {
    return 'Session \"$name\" imported.';
  }

  @override
  String get libraryScreenConflictTitle => 'Session already exists';

  @override
  String libraryScreenConflictBody(String name) {
    return 'A session named \"$name\" is already in this library. What would you like to do?';
  }

  @override
  String get libraryScreenImportDuplicate => 'Import as duplicate';

  @override
  String get libraryScreenOverwrite => 'Overwrite';

  @override
  String libraryScreenOpenFailed(String title) {
    return '\"$title\" couldn\'t be opened.';
  }

  @override
  String get libraryScreenTitle => 'Library';

  @override
  String get libraryScreenBack => 'Back';

  @override
  String get libraryScreenTabSessions => 'Sessions';

  @override
  String get libraryScreenTabImport => 'Import files';

  @override
  String get libraryScreenSearchHint =>
      'Search titles, transcripts, or summaries…';

  @override
  String get libraryScreenClearSearch => 'Clear search';

  @override
  String get libraryScreenDeepSearching => 'Searching inside transcripts…';

  @override
  String get libraryScreenEmptyTitle => 'No saved sessions yet';

  @override
  String get libraryScreenEmptySubtitle =>
      'Transcription sessions will appear here';

  @override
  String get libraryScreenNoMatch => 'No matching sessions';

  @override
  String get libraryScreenImportArchive => 'Import session archive (.zip)';

  @override
  String exportDialogTitle(String title) {
    return 'Export \"$title\"';
  }

  @override
  String get exportDialogIncomplete =>
      'This session\'s transcript isn\'t complete yet. Some audio is still being transcribed, and an export now will leave that part out.';

  @override
  String get exportDialogChooseFormat => 'Choose export formats:';

  @override
  String get exportDialogFormatMd => 'With timestamps & speaker names';

  @override
  String get exportDialogFormatTxt => 'Plain text without timestamps';

  @override
  String get exportDialogFormatJson => 'Full data for other programs';

  @override
  String get exportDialogFormatSrt => 'Subtitles for video players';

  @override
  String get exportDialogFormatVtt => 'Subtitles for the web';

  @override
  String get exportDialogFormatHtml => 'Formatted web page';

  @override
  String get exportDialogFormatDocx => 'Microsoft Word document';

  @override
  String get exportDialogFormatPdf =>
      'Print-ready document with embedded fonts';

  @override
  String get exportDialogFormatCsv => 'One row per segment, for spreadsheets';

  @override
  String exportDialogBookmarksIncluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookmarks included',
      one: '1 bookmark included',
    );
    return '$_temp0 as the \"Poin Penting\" section';
  }

  @override
  String get exportDialogSummaryIncluded =>
      'AI summary included in Markdown, TXT, HTML & DOCX';

  @override
  String get exportDialogPdpRedaction =>
      'PDP compliance mode is on. Personal data will be masked in the exported files. The saved transcript stays unchanged.';

  @override
  String get exportDialogPreview => 'Preview';

  @override
  String get exportDialogSingleFolder => 'All files go in one folder';

  @override
  String get exportDialogChooseFolder => 'Choose folder';

  @override
  String exportDialogFolderPickerTitle(String title) {
    return 'Choose an export folder for \"$title\"';
  }

  @override
  String exportDialogExporting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formats',
      one: '1 format',
    );
    return 'Exporting $_temp0…';
  }

  @override
  String exportDialogSuccess(String path) {
    return 'Exported to: $path';
  }

  @override
  String get exportDialogShare => 'Share';

  @override
  String exportDialogFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String speakerManagerDialogRenameTitle(String name) {
    return 'Rename \"$name\"';
  }

  @override
  String get speakerManagerDialogNameLabel => 'Name';

  @override
  String get speakerManagerDialogNameHelper => 'Applies to this whole session.';

  @override
  String get speakerManagerDialogRenameConfirm => 'Rename';

  @override
  String speakerManagerDialogMergeTitle(String name) {
    return 'Merge \"$name\" into which speaker?';
  }

  @override
  String speakerManagerDialogMergeOption(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '1 segment',
    );
    return '$name ($_temp0)';
  }

  @override
  String get speakerManagerDialogTitle => 'Manage speakers';

  @override
  String get speakerManagerDialogNoSpeakers =>
      'This transcript has no speakers yet.';

  @override
  String speakerManagerDialogPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending changes',
      one: '1 pending change',
    );
    return '$_temp0. Press Apply to write them to the transcript.';
  }

  @override
  String get speakerManagerDialogNothingRemembered =>
      'No remembered names yet.';

  @override
  String get speakerManagerDialogForgotten =>
      'Remembered speaker names cleared.';

  @override
  String get speakerManagerDialogForgetAll => 'Forget saved names';

  @override
  String get speakerManagerDialogApply => 'Apply';

  @override
  String speakerManagerDialogStatsSeconds(int segments, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      segments,
      locale: localeName,
      other: '$segments segments',
      one: '1 segment',
    );
    return '$_temp0 · $seconds sec';
  }

  @override
  String speakerManagerDialogStatsMinutes(int segments, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      segments,
      locale: localeName,
      other: '$segments segments',
      one: '1 segment',
    );
    return '$_temp0 · $minutes min';
  }

  @override
  String get speakerManagerDialogRename => 'Rename';

  @override
  String get speakerManagerDialogMerge => 'Merge with another speaker';

  @override
  String get speakerManagerDialogNoMerge => 'No other speakers to merge with';

  @override
  String speakerManagerDialogSuggestion(String name) {
    return 'Remembered from a previous meeting: $name';
  }

  @override
  String get speakerManagerDialogUseSuggestion => 'Use';

  @override
  String speakerManagerDialogRememberUnrenamed(String label) {
    return 'Remember this name for label \"$label\" in future meetings (rename it first)';
  }

  @override
  String speakerManagerDialogRemember(String name, String label) {
    return 'Remember \"$name\" for label \"$label\" in future meetings';
  }

  @override
  String sessionCardDurationHours(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String sessionCardDurationMinutes(int minutes) {
    return '$minutes min';
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
  String get sessionCardMonthMay => 'May';

  @override
  String get sessionCardMonthJun => 'Jun';

  @override
  String get sessionCardMonthJul => 'Jul';

  @override
  String get sessionCardMonthAug => 'Aug';

  @override
  String get sessionCardMonthSep => 'Sep';

  @override
  String get sessionCardMonthOct => 'Oct';

  @override
  String get sessionCardMonthNov => 'Nov';

  @override
  String get sessionCardMonthDec => 'Dec';

  @override
  String get sessionCardHasSummary => 'Has an AI summary';

  @override
  String sessionCardSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '1 segment',
    );
    return '$_temp0';
  }

  @override
  String get sessionCardRename => 'Rename';

  @override
  String get sessionCardExport => 'Export';

  @override
  String get sessionCardExportArchive => 'Export as archive (.zip)';

  @override
  String get sessionCardDelete => 'Delete';

  @override
  String get dictionaryLearningDialogTitle => 'Remember this correction?';

  @override
  String get dictionaryLearningDialogDescription =>
      'You changed one word. Trareon can remember it so you don\'t have to correct it again in future meetings.';

  @override
  String get dictionaryLearningDialogDontRemember => 'Don\'t remember';

  @override
  String dictionaryLearningDialogAddToGlossary(String term) {
    return 'Add \"$term\" to the glossary';
  }

  @override
  String get dictionaryLearningDialogAddToGlossaryHelper =>
      'The speech recognizer is told about this term before it transcribes, so it is more likely to get it right from the start.';

  @override
  String dictionaryLearningDialogAutoReplace(String before, String after) {
    return 'Automatically replace \"$before\" → \"$after\" from now on';
  }

  @override
  String dictionaryLearningDialogAutoReplaceHelper(
    String before,
    String after,
  ) {
    return 'Every standalone \"$before\" will be written as \"$after\" in future transcripts. You can remove this in Settings → Glossary.';
  }

  @override
  String get dictionaryLearningDialogPickOne =>
      'Choose at least one so there is something to save.';

  @override
  String get tagEditorDialogTitle => 'Session tags';

  @override
  String get tagEditorDialogDescription =>
      'Tags filter the session list in the left sidebar. No files are moved.';

  @override
  String get tagEditorDialogAddLabel => 'Add tag';

  @override
  String get tagEditorDialogAdd => 'Add';

  @override
  String get tagEditorDialogEmpty => 'This session has no tags yet.';

  @override
  String get tagEditorDialogSuggestions => 'Other tags in the library';

  @override
  String get appShortcutsStartStop => 'Start or stop recording';

  @override
  String get appShortcutsPauseResume => 'Pause or resume';

  @override
  String get appShortcutsSearchSessions => 'Search session history';

  @override
  String get appShortcutsBookmark => 'Bookmark a key moment';

  @override
  String get appShortcutsSettings => 'Open Settings';

  @override
  String get appShortcutsShortcutsPanel => 'Show keyboard shortcuts';

  @override
  String get appShortcutsToggleSidebar => 'Hide or show the sidebar';

  @override
  String formatTimeSeconds(int seconds) {
    return '$seconds sec';
  }

  @override
  String formatTimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String formatTimeHours(int hours) {
    return '$hours hr';
  }

  @override
  String formatTimeHoursMinutes(int hours, int minutes) {
    return '$hours hr $minutes min';
  }

  @override
  String get modelDownloadCardNotDownloaded => 'Not downloaded';

  @override
  String get modelDownloadCardReady => 'Ready';

  @override
  String get modelDownloadCardFailed => 'Failed, try again';

  @override
  String appFeedbackPercent(int percent) {
    return '$percent percent';
  }

  @override
  String appChipDelete(String label) {
    return 'Remove $label';
  }

  @override
  String get resourceIndicatorSemantics =>
      'Memory usage is high, consider closing other apps';

  @override
  String get resourceIndicatorHigh => 'High, consider closing other apps';

  @override
  String summaryModelSaveActionItemsFailed(String error) {
    return 'Couldn\'t save the action items: $error';
  }

  @override
  String get summaryModelDisabled =>
      'AI summary is turned off. Turn it on in Settings → AI summary.';

  @override
  String get summaryModelNotConfigured =>
      'The summary endpoint or model is not set. Fill them in under Settings → AI summary.';

  @override
  String get summaryModelEmptyTranscriptSummarize =>
      'The transcript is empty, so there is nothing to summarize.';

  @override
  String summaryModelTemplateUnusable(String name, String error) {
    return 'Template \"$name\" can\'t be used: $error';
  }

  @override
  String summaryModelGenerateFailed(String error) {
    return 'Couldn\'t create the summary (your transcript is safe): $error';
  }

  @override
  String get summaryModelEmptyTranscriptMerge =>
      'The transcript is empty, so there is nothing to merge.';

  @override
  String summaryModelEnhanceFailed(String error) {
    return 'Couldn\'t merge your notes with the transcript: $error';
  }

  @override
  String summaryModelSaveFailed(String error) {
    return 'Couldn\'t save the summary: $error';
  }
}
