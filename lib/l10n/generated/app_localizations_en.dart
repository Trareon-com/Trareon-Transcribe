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
  String get appToastDismissTooltip => 'Dismiss notification';

  @override
  String get settingsControlsInfoBadge => 'Explanation';

  @override
  String get settingsControlsInfoDialogTitle => 'Information';

  @override
  String get settingsControlsClose => 'Close';

  @override
  String get taskProgressTileFailed => 'Failed.';

  @override
  String get taskProgressTileCancelled => 'Cancelled.';

  @override
  String get taskProgressTileDone => 'Done.';

  @override
  String get taskProgressTileQueued => 'Waiting in queue.';

  @override
  String get taskProgressTileProcessing => 'Processing';

  @override
  String get enhanceQueueViewCompletingTitle => 'Completing transcript';

  @override
  String enhanceQueueViewCompletingSource(String source) {
    return 'Completing $source';
  }

  @override
  String enhanceQueueViewEtaRemaining(String eta) {
    return '$eta left';
  }

  @override
  String get enhanceQueueViewQueuedCompletion =>
      'Waiting in queue. Some audio hasn\'t been transcribed yet.';

  @override
  String get enhanceQueueModelSourceMic => 'microphone';

  @override
  String get enhanceQueueModelSourceSystem => 'system audio';

  @override
  String get enhanceQueueModelSourceRecording => 'recording';

  @override
  String enhanceQueueModelQueuedForCompletion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Waiting in queue to complete $count recordings.',
      one: 'Waiting in queue to complete the transcript.',
    );
    return '$_temp0';
  }

  @override
  String enhanceQueueModelCompletingLine(
    String source,
    int percent,
    String eta,
  ) {
    return 'Completing transcript…$source $percent%$eta';
  }

  @override
  String enhanceQueueModelEtaSuffix(String eta) {
    return ', $eta left';
  }

  @override
  String enhanceQueueModelEtaSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String enhanceQueueModelEtaMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String enhanceQueueModelEtaHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String enhanceQueueModelEtaHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0 $_temp1';
  }

  @override
  String get enhanceQueueModelStagePreparing => 'Preparing model';

  @override
  String get enhanceQueueModelStageTranscribing => 'Transcribing';

  @override
  String get enhanceQueueModelStageMerging => 'Merging';

  @override
  String get enhanceQueueModelNoSpeech => 'No speech detected.';

  @override
  String get batchUploadModelUnsupportedFormat => 'unsupported format';

  @override
  String get batchUploadModelTooLarge => 'larger than the 2 GB limit';

  @override
  String get batchUploadModelNoSpeech => 'No speech detected';

  @override
  String get batchUploadModelStoppedEarly =>
      'Processing stopped before this file finished';

  @override
  String get modelsSummaryTemplateNotulenRapat => 'Meeting minutes';

  @override
  String get modelsSummaryTemplateRingkasanEksekutif => 'Executive summary';

  @override
  String get modelsSummaryTemplateActionItems => 'Decisions & follow-ups';

  @override
  String get modelsSummaryTemplateStandup => 'Daily report';

  @override
  String get modelsSummaryTemplateKustom => 'Custom';

  @override
  String get modelsSummaryTemplateHintNotulenRapat =>
      'Summary, attendees, discussion, decisions, follow-ups';

  @override
  String get modelsSummaryTemplateHintRingkasanEksekutif =>
      'A short paragraph for those who weren\'t there';

  @override
  String get modelsSummaryTemplateHintActionItems =>
      'Only decisions and tasks, with who owns each';

  @override
  String get modelsSummaryTemplateHintStandup =>
      'Per person: done, next, blockers';

  @override
  String get modelsSummaryTemplateHintKustom => 'Your own instructions';

  @override
  String get modelsSummaryProviderOllama => 'Ollama (local)';

  @override
  String get modelsSummaryProviderOpenAiCompatible =>
      'OpenAI-compatible service';

  @override
  String get modelsSessionModeWebinar => 'Webinar';

  @override
  String get modelsSessionModeOnline => 'Online meeting';

  @override
  String get modelsSessionModeOffline => 'In-person meeting';

  @override
  String get usageDashboardScreenTitle => 'Usage dashboard';

  @override
  String get usageDashboardScreenTotalSessions => 'Total sessions';

  @override
  String get usageDashboardScreenHoursTranscribed => 'Hours transcribed';

  @override
  String get usageDashboardScreenTotalSegments => 'Total transcript segments';

  @override
  String get usageDashboardScreenEmpty => 'No saved session data yet.';

  @override
  String get usageDashboardScreenSessionsByMode => 'Sessions by mode';

  @override
  String usageDashboardScreenSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String get meetingTemplatePickerModeWebinar => 'Webinar';

  @override
  String get meetingTemplatePickerModeOnline => 'Online meeting';

  @override
  String get meetingTemplatePickerModeOffline => 'In-person meeting';

  @override
  String get meetingTemplatePickerLanguageAuto => 'Automatic';

  @override
  String get meetingTemplatePickerLanguageIndonesian => 'Indonesian';

  @override
  String get meetingTemplatePickerLanguageEnglish => 'English';

  @override
  String get meetingTemplatePickerTitle => 'Start from a template';

  @override
  String get meetingTemplatePickerEmptyDescription =>
      'No saved templates yet. Create one so the title, participants, agenda, language and meeting mode you use often don\'t have to be filled in every time.';

  @override
  String get meetingTemplatePickerDescription =>
      'Pick a template to fill in the session\'s title, mode and language automatically.';

  @override
  String get meetingTemplatePickerCreate => 'Create new template';

  @override
  String get meetingTemplatePickerOptionalNote =>
      'Templates are optional. \"New meeting\" still starts a blank session as usual.';

  @override
  String meetingTemplatePickerParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String meetingTemplatePickerAgendaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agenda items',
      one: '1 agenda item',
    );
    return '$_temp0';
  }

  @override
  String get meetingTemplatePickerDelete => 'Delete template';

  @override
  String get meetingTemplatePickerUse => 'Use';

  @override
  String get meetingTemplatePickerNewTitle => 'New template';

  @override
  String get meetingTemplatePickerNamePlaceholder =>
      'Template name, e.g. \"Weekly team meeting\"';

  @override
  String get meetingTemplatePickerParticipantsPlaceholder =>
      'Default participants (one name per line)';

  @override
  String get meetingTemplatePickerAgendaPlaceholder =>
      'Default agenda (one item per line)';

  @override
  String get meetingTemplatePickerModeLabel => 'Mode';

  @override
  String get meetingTemplatePickerLanguageLabel => 'Language';

  @override
  String get glossarySettingsSectionImportDialogTitle => 'Import glossary';

  @override
  String get glossarySettingsSectionImportEmpty =>
      'No terms found in that file.';

  @override
  String glossarySettingsSectionImported(int added, int lines) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added new terms',
      one: '1 new term',
    );
    String _temp1 = intl.Intl.pluralLogic(
      lines,
      locale: localeName,
      other: '$lines lines',
      one: '1 line',
    );
    return '$_temp0 added from $_temp1.';
  }

  @override
  String glossarySettingsSectionImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get glossarySettingsSectionExportDialogTitle => 'Save glossary';

  @override
  String glossarySettingsSectionExported(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count terms',
      one: '1 term',
    );
    return '$_temp0 exported to $path';
  }

  @override
  String glossarySettingsSectionExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get glossarySettingsSectionTitle => 'Glossary';

  @override
  String get glossarySettingsSectionEnable => 'Use glossary';

  @override
  String get glossarySettingsSectionEnabledSubtitle =>
      'The terms below are hinted to the transcription engine so abbreviations and agency names are spelled correctly.';

  @override
  String get glossarySettingsSectionDisabledSubtitle =>
      'The transcription engine guesses every term on its own.';

  @override
  String get glossarySettingsSectionPostCorrection => 'Fix near-miss spellings';

  @override
  String get glossarySettingsSectionPostCorrectionOnSubtitle =>
      'Words that nearly match a glossary term are corrected after transcription. Other words are left alone.';

  @override
  String get glossarySettingsSectionPostCorrectionOffSubtitle =>
      'The transcription is left as is.';

  @override
  String glossarySettingsSectionListTitle(int count) {
    return 'Terms ($count)';
  }

  @override
  String get glossarySettingsSectionAddLabel => 'Add term';

  @override
  String get glossarySettingsSectionAddHint =>
      'e.g. PPBJ, Kemenkeu, Pak Budi Santoso';

  @override
  String get glossarySettingsSectionAdd => 'Add';

  @override
  String glossarySettingsSectionTermSemantics(String term) {
    return 'Term $term';
  }

  @override
  String glossarySettingsSectionRemoveTerm(String term) {
    return 'Remove $term';
  }

  @override
  String get glossarySettingsSectionSuggestions => 'Common term suggestions';

  @override
  String glossarySettingsSectionAddSuggestion(String term) {
    return 'Add $term to the glossary';
  }

  @override
  String get glossarySettingsSectionImportButton => 'Import .txt / .csv';

  @override
  String get glossarySettingsSectionExportTxt => 'Export .txt';

  @override
  String get glossarySettingsSectionExportCsv => 'Export .csv';

  @override
  String get glossarySettingsSectionNoTerms =>
      'No terms yet. Without a glossary, the transcription engine guesses on its own.';

  @override
  String glossarySettingsSectionBudgetOverflow(int used, int total) {
    return '$used of $total terms in use; the list is too long to hint all at once. Terms further down the list are dropped first, so move the important ones up or shorten the list.';
  }

  @override
  String glossarySettingsSectionBudgetAll(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'All $total terms in use.',
      one: 'The term is in use.',
    );
    return '$_temp0';
  }

  @override
  String get summarySettingsSectionOllamaModelHint => 'Ollama model name';

  @override
  String get summarySettingsSectionNoModels =>
      'Connected to the endpoint, but no models are installed.';

  @override
  String get summarySettingsSectionEnable => 'Turn on AI summary';

  @override
  String get summarySettingsSectionEnabledSubtitle =>
      'The transcript is sent to the endpoint below only when you press \"Create summary\". No audio is ever sent.';

  @override
  String get summarySettingsSectionDisabledSubtitle =>
      'Off. The app stays 100% offline.';

  @override
  String get summarySettingsSectionProvider => 'Provider';

  @override
  String get summarySettingsSectionEndpointUrl => 'Endpoint URL';

  @override
  String get summarySettingsSectionApiKey => 'API key';

  @override
  String get summarySettingsSectionApiKeyHelper =>
      'Stored as is in the app\'s settings file (no keychain).';

  @override
  String get summarySettingsSectionApiKeyHint => 'Paste the key here';

  @override
  String get summarySettingsSectionModel => 'Model';

  @override
  String get summarySettingsSectionLoadModels =>
      'Load the model list from the endpoint';

  @override
  String get summarySettingsSectionSetupWizard =>
      'Set up AI model (detect, install, download)…';

  @override
  String get summarySettingsSectionDefaultTemplate => 'Default template';

  @override
  String get summarySettingsSectionCitations => 'Transcript references';

  @override
  String get summarySettingsSectionCitationsSubtitle =>
      'Ask the model to cite a segment number for every point, so each summary line can be clicked through to the minute it came from. References that do not match are dropped.';

  @override
  String get summarySettingsSectionActionItems => 'Structured follow-ups';

  @override
  String get summarySettingsSectionActionItemsSubtitle =>
      'Ask for tasks, owners and deadlines in a format you can edit and export to a calendar (.ics) or a spreadsheet (.csv).';

  @override
  String get summarySettingsSectionCustomInstructions => 'Custom instructions';

  @override
  String get summarySettingsSectionCustomInstructionsHint =>
      'Example: List the risks and how to mitigate them.';

  @override
  String get pdpSettingsSectionRetentionForever => 'Keep forever';

  @override
  String pdpSettingsSectionRetentionDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String pdpSettingsSectionRetentionDaysMonths(int days, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$days days ($_temp0)';
  }

  @override
  String pdpSettingsSectionRetentionYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String get pdpSettingsSectionTitle => 'PDP Law compliance';

  @override
  String get pdpSettingsSectionEnable => 'Turn on PDP compliance mode';

  @override
  String get pdpSettingsSectionEnableSubtitle =>
      'Personal data masking on export, retention limits, an audit log and recording notices. Off by default.';

  @override
  String get pdpSettingsSectionRedactionTitle => 'Masking on export';

  @override
  String get pdpSettingsSectionRedactionIntro =>
      'Saved transcripts are never changed. Masking applies only to the exported copy, and you can always preview it before the file is written.';

  @override
  String get pdpSettingsSectionNik => 'NIK (national ID number)';

  @override
  String get pdpSettingsSectionNikHint =>
      '16 digits with a valid province code';

  @override
  String get pdpSettingsSectionNpwp => 'NPWP (tax ID)';

  @override
  String get pdpSettingsSectionNpwpHint => '15 digits, with or without dots';

  @override
  String get pdpSettingsSectionPhone => 'Phone number';

  @override
  String get pdpSettingsSectionPhoneHint =>
      '08…, +62…, and office numbers with an area code';

  @override
  String get pdpSettingsSectionEmail => 'Email address';

  @override
  String get pdpSettingsSectionEmailHint => 'name@agency.go.id';

  @override
  String get pdpSettingsSectionBankAccount => 'Bank account number';

  @override
  String get pdpSettingsSectionBankAccountHint =>
      'Only when the word \"rekening\" or a bank name is nearby, so budget figures are not masked too';

  @override
  String get pdpSettingsSectionNamesTitle => 'Masked names';

  @override
  String get pdpSettingsSectionNamesIntro =>
      'Only you know which names are sensitive in this meeting. Entries shorter than 3 letters are ignored.';

  @override
  String get pdpSettingsSectionNameHint => 'E.g. Budi Santoso';

  @override
  String get pdpSettingsSectionAdd => 'Add';

  @override
  String get pdpSettingsSectionRetentionTitle => 'Data retention';

  @override
  String get pdpSettingsSectionRetentionIntro =>
      'Audio and transcripts have separate limits: recordings usually have to be deleted much sooner than the minutes. Nothing is deleted automatically. You see the list first.';

  @override
  String get pdpSettingsSectionDeleteAudioAfter => 'Delete audio after';

  @override
  String get pdpSettingsSectionDeleteTranscriptAfter =>
      'Delete transcript (whole session) after';

  @override
  String get pdpSettingsSectionPreviewRetention => 'Review & run now';

  @override
  String get pdpSettingsSectionRetentionDialogTitle =>
      'Run the retention policy?';

  @override
  String pdpSettingsSectionWholeSessionAge(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Whole session · $_temp0';
  }

  @override
  String pdpSettingsSectionAudioOnlyAge(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Audio only · $_temp0';
  }

  @override
  String get pdpSettingsSectionCannotUndo => 'This can\'t be undone.';

  @override
  String get pdpSettingsSectionDeleteNow => 'Delete now';

  @override
  String pdpSettingsSectionRetentionApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items deleted',
      one: '1 item deleted',
    );
    return '$_temp0 under the retention policy.';
  }

  @override
  String pdpSettingsSectionRetentionPartial(int deleted, int failed) {
    return '$deleted deleted, $failed failed.';
  }

  @override
  String pdpSettingsSectionRetentionPreviewFailed(String error) {
    return 'Retention preview failed: $error';
  }

  @override
  String get pdpSettingsSectionConsentTitle => 'Recording notice';

  @override
  String get pdpSettingsSectionConsentReminder =>
      'Remind me before recording starts';

  @override
  String get pdpSettingsSectionConsentReminderSubtitle =>
      'Show a notice you can copy into the meeting chat, and note in the audit log that it was given.';

  @override
  String get pdpSettingsSectionConsentTextLabel => 'Notice text';

  @override
  String pdpSettingsSectionConsentTextHelper(
    String titleToken,
    String dateToken,
  ) {
    return '$titleToken and $dateToken are filled in automatically. Leave empty to use the default text.';
  }

  @override
  String get pdpSettingsSectionCopyNotice => 'Copy notice text';

  @override
  String get pdpSettingsSectionNoticeCopied => 'Notice text copied.';

  @override
  String pdpSettingsSectionCopyFailed(String error) {
    return 'Copy failed: $error';
  }

  @override
  String get pdpSettingsSectionAuditTitle => 'Audit log';

  @override
  String get pdpSettingsSectionAuditIntro =>
      'A local record of what happened to the data: sessions created, transcripts exported, summaries sent, data deleted. It holds metadata only, never transcript excerpts.';

  @override
  String get pdpSettingsSectionViewLog => 'View log';

  @override
  String get pdpSettingsSectionExportCsv => 'Export CSV';

  @override
  String get pdpSettingsSectionSaveAuditDialogTitle => 'Save audit log';

  @override
  String pdpSettingsSectionAuditSaved(String path) {
    return 'Audit log saved to $path';
  }

  @override
  String pdpSettingsSectionAuditExportFailed(String error) {
    return 'Log export failed: $error';
  }

  @override
  String transcriptViewNewLinesAnnouncement(
    int count,
    String speaker,
    String text,
  ) {
    return '$count new lines. Latest from $speaker: $text';
  }

  @override
  String get transcriptViewSegmentCopied => 'Segment copied.';

  @override
  String get transcriptViewTranscriptCopied => 'Transcript copied.';

  @override
  String get transcriptViewEmptyTitle => 'No transcript yet';

  @override
  String transcriptViewEmptySubtitle(String shortcut) {
    return 'Start a session to begin transcribing\nPress Start or $shortcut';
  }

  @override
  String get transcriptViewSearchHint => 'Search…';

  @override
  String get transcriptViewClearSearch => 'Clear search';

  @override
  String transcriptViewSegmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '1 segment',
    );
    return '$_temp0';
  }

  @override
  String transcriptViewFilteredSegmentCount(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total segments',
      one: '1 segment',
    );
    return '$shown of $_temp0';
  }

  @override
  String transcriptViewRefiningCount(int count) {
    return '$count being refined';
  }

  @override
  String get transcriptViewFollowPlaybackOn => 'Follow playback: on';

  @override
  String get transcriptViewFollowPlaybackOff => 'Follow playback: off';

  @override
  String get transcriptViewAutoScrollOn => 'Auto-scroll on';

  @override
  String get transcriptViewAutoScrollOff => 'Auto-scroll off';

  @override
  String get transcriptViewReviewOnly =>
      'Review: only segments that need checking';

  @override
  String transcriptViewReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Review ($count segments need checking)',
      one: 'Review (1 segment needs checking)',
    );
    return '$_temp0';
  }

  @override
  String get transcriptViewCopyAll => 'Copy all';

  @override
  String get transcriptViewNoMatches => 'No matching segments';

  @override
  String transcriptViewEditingHint(String split) {
    return 'Enter save · Esc cancel · $split split at cursor';
  }

  @override
  String transcriptViewBrowsingHint(String move, String merge) {
    return '↑↓ select · Enter edit · $move move · $merge merge up';
  }

  @override
  String transcriptViewSegmentSemantics(
    String speaker,
    String time,
    String text,
  ) {
    return '$speaker at $time: $text';
  }

  @override
  String get transcriptViewProcessing => 'Processing…';

  @override
  String get transcriptViewQueued => 'Queued';

  @override
  String get transcriptViewLowConfidence => 'Low confidence';

  @override
  String get transcriptViewCopySegment => 'Copy segment';

  @override
  String get transcriptViewEdit => 'Edit';

  @override
  String get transcriptViewEditDialogTitle => 'Edit transcript';

  @override
  String get transcriptViewEditHint => 'Type your correction…';

  @override
  String get transcriptViewRenameSpeakerTitle => 'Rename speaker';

  @override
  String get transcriptViewNewNameHint => 'New name…';

  @override
  String transcriptViewTentativeSemantics(String text) {
    return 'Tentative, not final: $text';
  }

  @override
  String get transcriptViewTentativePrefix => 'tentative · ';
}
