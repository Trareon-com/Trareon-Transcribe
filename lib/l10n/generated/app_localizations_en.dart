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
  String get notulenDialogSummaryNotConfigured =>
      'The summary endpoint or model is not set. Fill it in under Settings → AI summary.';

  @override
  String get notulenDialogPickReferenceDocTitle =>
      'Choose a reference document';

  @override
  String notulenDialogReadDocFailed(String error) {
    return 'Couldn\'t read the document: $error';
  }

  @override
  String get notulenDialogPickFolderTitle => 'Choose a folder for the minutes';

  @override
  String notulenDialogSaved(String path) {
    return 'Minutes saved: $path';
  }

  @override
  String notulenDialogExportFailed(String error) {
    return 'Couldn\'t create the minutes: $error';
  }

  @override
  String get notulenDialogTitle => 'Meeting minutes';

  @override
  String get notulenDialogComposing => 'Composing…';

  @override
  String get notulenDialogCreateDocx => 'Create minutes (DOCX)';

  @override
  String get notulenDialogMeetingIdentity => 'Meeting details';

  @override
  String get notulenDialogFieldTitle => 'Meeting title';

  @override
  String get notulenDialogFieldNumber => 'Minutes number';

  @override
  String get notulenDialogFieldNumberHint => 'e.g. ND-12/AG.3/2026';

  @override
  String get notulenDialogFieldAgency => 'Agency (letterhead)';

  @override
  String get notulenDialogFieldUnit => 'Work unit (second letterhead line)';

  @override
  String get notulenDialogFieldDay => 'Day';

  @override
  String get notulenDialogFieldDate => 'Date';

  @override
  String get notulenDialogFieldTime => 'Time';

  @override
  String get notulenDialogFieldPlace => 'Venue/Medium';

  @override
  String get notulenDialogFieldChair => 'Chair';

  @override
  String get notulenDialogFieldMinuteTaker => 'Minute-taker';

  @override
  String get notulenDialogParties => 'Parties';

  @override
  String get notulenDialogPartiesHelp =>
      'The order sets the signature columns: the first party on the right, the second on the left. Give each name with its position.';

  @override
  String get notulenDialogPartyHint => 'Name, position';

  @override
  String get notulenDialogAddParty => 'Add party';

  @override
  String get notulenDialogAttendees => 'Attendees';

  @override
  String get notulenDialogAttendeeHint => 'Attendee name';

  @override
  String get notulenDialogAddAttendee => 'Add attendee';

  @override
  String get notulenDialogAgenda => 'Agenda';

  @override
  String get notulenDialogAgendaHint => 'Agenda item';

  @override
  String get notulenDialogAddAgenda => 'Add agenda item';

  @override
  String get notulenDialogDiscussion => 'Discussion';

  @override
  String get notulenDialogDiscussionHint =>
      'What was discussed. Filled in from the AI summary when there is one.';

  @override
  String get notulenDialogDecisions => 'Decisions';

  @override
  String get notulenDialogDecisionHint => 'Meeting decision';

  @override
  String get notulenDialogAddDecision => 'Add decision';

  @override
  String get notulenDialogFollowUp => 'Action items';

  @override
  String get notulenDialogArchivalExport => 'Archival export';

  @override
  String get notulenDialogExportSrikandi => 'Export for SRIKANDI…';

  @override
  String notulenDialogBookmarksIncluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count key points you marked during the meeting will be included.',
      one: 'The key point you marked during the meeting will be included.',
    );
    return '$_temp0';
  }

  @override
  String get notulenDialogAttachTranscript => 'Attach the full transcript';

  @override
  String notulenDialogTranscriptLines(int count) {
    return 'The transcript is added on a separate page ($count lines).';
  }

  @override
  String get notulenDialogFormType => 'Document type';

  @override
  String get notulenDialogAutoFill => 'Fill in with AI';

  @override
  String get notulenDialogSourceTranscript => 'Session transcript';

  @override
  String get notulenDialogSourceNotes => 'Note points';

  @override
  String get notulenDialogNotesHint =>
      'Paste or type your meeting notes, one point per line.';

  @override
  String get notulenDialogLength => 'Minutes length';

  @override
  String get notulenDialogAddReferenceDoc =>
      'Add a reference document (optional)';

  @override
  String get notulenDialogRemoveReferenceDoc => 'Remove reference document';

  @override
  String get notulenDialogGenerate => 'Generate';

  @override
  String get notulenDialogRetry => 'Try again';

  @override
  String notulenDialogGenerateFailed(String error) {
    return 'Couldn\'t generate the minutes: $error';
  }

  @override
  String get notulenDialogFactCheckSection => 'Fact & style check';

  @override
  String get notulenDialogRecheck => 'Check again';

  @override
  String get notulenDialogFactCheck => 'Check facts';

  @override
  String get notulenDialogTidyRegister => 'Tidy up style';

  @override
  String notulenDialogCheckFailed(String error) {
    return 'Check failed: $error';
  }

  @override
  String notulenDialogFactSummary(int checked, int clean, int flagged) {
    return 'Statements checked: $checked. Clean: $clean. To review: $flagged.';
  }

  @override
  String get notulenDialogTidyPreview => 'Style tidy-up preview';

  @override
  String get notulenDialogApply => 'Apply';

  @override
  String notulenDialogRemoveItem(String item) {
    return 'Remove $item';
  }

  @override
  String get notulenDialogTaskField => 'Task';

  @override
  String get notulenDialogOwnerField => 'Owner';

  @override
  String get notulenDialogDueField => 'Due';

  @override
  String get notulenDialogRemoveTaskRow => 'Remove action item';

  @override
  String get notulenDialogAddTask => 'Add action item';

  @override
  String get notulenDialogIssueNoCitation => 'No segment citation';

  @override
  String get notulenDialogIssueInvalidCitation => 'Invalid segment citation';

  @override
  String get notulenDialogIssueWeakSupport => 'Weak support in the transcript';

  @override
  String get notulenDialogIssueCitationOff =>
      'Citation points to the wrong segment';

  @override
  String get notulenDialogIssueNumberMissing =>
      'Number not found in the transcript';

  @override
  String get notulenDialogIssueNameMissing =>
      'Name not found in the transcript';

  @override
  String notulenDialogRegisterLine(int line, String found) {
    return 'Line $line: \"$found\"';
  }

  @override
  String notulenDialogRegisterSuggestion(String suggestion) {
    return 'Suggestion: \"$suggestion\" (applied by Tidy up style)';
  }

  @override
  String get actionItemsPanelStatusNotStarted => 'Not started';

  @override
  String get actionItemsPanelStatusInProgress => 'In progress';

  @override
  String get actionItemsPanelStatusDone => 'Done';

  @override
  String get actionItemsPanelStatusCancelled => 'Cancelled';

  @override
  String actionItemsPanelSaved(String what, String filename) {
    return 'Saved $what: $filename';
  }

  @override
  String actionItemsPanelSaveFailed(String what, String error) {
    return 'Couldn\'t save $what: $error';
  }

  @override
  String get actionItemsPanelIcsWhat => 'action item calendar';

  @override
  String get actionItemsPanelCsvWhat => 'action item table';

  @override
  String actionItemsPanelIcsFailed(String error) {
    return 'Couldn\'t create the .ics file: $error';
  }

  @override
  String actionItemsPanelCsvFailed(String error) {
    return 'Couldn\'t create the .csv file: $error';
  }

  @override
  String get actionItemsPanelCopied => 'Action items copied.';

  @override
  String get actionItemsPanelTitle => 'Action items';

  @override
  String actionItemsPanelProgress(int done, int total) {
    return '$done/$total done';
  }

  @override
  String get actionItemsPanelEmpty =>
      'No action items yet. Turn on \"Structured action items\" in Settings → AI summary so the next summary fills them in, or add your own below.';

  @override
  String get actionItemsPanelAddTask => 'Add task';

  @override
  String get actionItemsPanelCopy => 'Copy';

  @override
  String get actionItemsPanelExportCsv => 'Export CSV';

  @override
  String get actionItemsPanelShareCsv => 'Share CSV';

  @override
  String get actionItemsPanelExportIcs => 'Export .ics';

  @override
  String get actionItemsPanelShareIcs => 'Share .ics';

  @override
  String actionItemsPanelMarkDone(String task) {
    return 'Mark \"$task\" as done';
  }

  @override
  String get actionItemsPanelTaskLabel => 'Task';

  @override
  String get actionItemsPanelRemoveTask => 'Remove task';

  @override
  String get actionItemsPanelOwnerLabel => 'Owner';

  @override
  String get actionItemsPanelDueLabel => 'Due';

  @override
  String get actionItemsPanelStatusLabel => 'Status';

  @override
  String get diagnosticsScreenSaveDialogTitle => 'Save diagnostic log';

  @override
  String diagnosticsScreenSaved(String path) {
    return 'Diagnostic log saved: $path';
  }

  @override
  String diagnosticsScreenSaveFailed(String error) {
    return 'Couldn\'t save the diagnostic log: $error';
  }

  @override
  String get diagnosticsScreenTitle => 'Diagnostics';

  @override
  String get diagnosticsScreenRecheck => 'Check again';

  @override
  String get diagnosticsScreenIntro =>
      'These checks run entirely on your computer and send nothing to the internet.';

  @override
  String get diagnosticsScreenRunFailedTitle => 'The checks could not run';

  @override
  String get diagnosticsScreenRunFailedRemediation =>
      'The transcription engine may not have loaded. Quit and reopen the app; if it still fails, reinstall Trareon.';

  @override
  String get diagnosticsScreenNoChecksTitle => 'No checks ran';

  @override
  String get diagnosticsScreenNoChecksMessage =>
      'The engine returned no results.';

  @override
  String get diagnosticsScreenHasFailures =>
      'There are problems to fix before recording.';

  @override
  String get diagnosticsScreenHasWarnings =>
      'The app is usable, but some things are worth checking.';

  @override
  String get diagnosticsScreenAllGood => 'All set. The app is ready to record.';

  @override
  String get diagnosticsScreenSeverityOk => 'OK';

  @override
  String get diagnosticsScreenSeverityWarn => 'Needs attention';

  @override
  String get diagnosticsScreenSeverityFail => 'Failed';

  @override
  String get diagnosticsScreenExportTitle => 'Diagnostic log';

  @override
  String get diagnosticsScreenExportBody =>
      'One .zip file with the log files and the check results above. It does not contain your transcripts, audio, or meeting file names.';

  @override
  String diagnosticsScreenExportBodyCount(int count) {
    return 'One .zip file with the log files ($count) and the check results above. It does not contain your transcripts, audio, or meeting file names.';
  }

  @override
  String get diagnosticsScreenExport => 'Export';

  @override
  String get llmSetupWizardScreenTitle => 'Set up AI model';

  @override
  String get llmSetupWizardScreenNotDetected =>
      'Ollama was not detected on this device.';

  @override
  String llmSetupWizardScreenInstallOn(String system) {
    return 'Install Ollama on $system';
  }

  @override
  String llmSetupWizardScreenOpenLink(String url) {
    return 'Open $url';
  }

  @override
  String get llmSetupWizardScreenInstalledRecheck => 'Installed, check again';

  @override
  String llmSetupWizardScreenHardware(String ram, int threads) {
    return 'This device: $ram GB RAM, $threads CPU threads.';
  }

  @override
  String llmSetupWizardScreenHardwareWithVram(
    String ram,
    int threads,
    String vram,
  ) {
    return 'This device: $ram GB RAM, $threads CPU threads, $vram GB VRAM.';
  }

  @override
  String get llmSetupWizardScreenBelowMinimum =>
      'This device is below the recommended minimum; the lightest model is still offered as a best effort.';

  @override
  String get llmSetupWizardScreenChooseModel => 'Choose a model';

  @override
  String llmSetupWizardScreenDownload(String model) {
    return 'Download $model';
  }

  @override
  String llmSetupWizardScreenDownloading(String model) {
    return 'Downloading $model…';
  }

  @override
  String get llmSetupWizardScreenDownloadingShort => 'Downloading';

  @override
  String get llmSetupWizardScreenPreparing => 'Preparing download…';

  @override
  String get llmSetupWizardScreenReady => 'Model ready';

  @override
  String llmSetupWizardScreenReadyBody(String model) {
    return '$model is downloaded and set as the AI summary model.';
  }

  @override
  String get llmSetupWizardScreenDone => 'Done';

  @override
  String llmSetupWizardScreenReadyToast(String model) {
    return 'AI model ready: $model';
  }

  @override
  String llmSetupWizardScreenModelMeta(String tag, String size, int context) {
    return '$tag · $size GB download · $context context';
  }

  @override
  String llmSetupWizardScreenError(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get llmSetupWizardScreenRetry => 'Try again';

  @override
  String get capabilitiesScreenTitle => 'What runs where';

  @override
  String capabilitiesScreenLoadFailed(String error) {
    return 'Couldn\'t read the capability list: $error';
  }

  @override
  String get capabilitiesScreenRunsLocal => 'Local';

  @override
  String get capabilitiesScreenRunsEndpoint => 'Your endpoint';

  @override
  String get capabilitiesScreenRunsInternet => 'Internet';

  @override
  String capabilitiesScreenLocalCount(int local, int total) {
    return '$local of $total capabilities run entirely on this computer.';
  }

  @override
  String capabilitiesScreenNetworked(int count, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count capabilities can use the network; $active of them are on right now. Recording, transcription, and export are not among them; they never use the network.',
      one:
          '1 capability can use the network ($active on right now). Recording, transcription, and export are not among them; they never use the network.',
      zero: 'No capability uses the network.',
    );
    return '$_temp0';
  }

  @override
  String get capabilitiesScreenSourceNote =>
      'This list comes from the same source as the privacy test in rust_core/src/privacy.rs: a row that claims \"Local\" while its module touches the network fails the build.';

  @override
  String capabilitiesScreenRowSemantics(
    String name,
    String runsAt,
    String status,
  ) {
    return '$name. $runsAt. $status.';
  }

  @override
  String get capabilitiesScreenActive => 'On';

  @override
  String get capabilitiesScreenInactive => 'Off';

  @override
  String get capabilitiesScreenRunsAt => 'Runs at: ';

  @override
  String capabilitiesScreenCode(String module) {
    return 'Code: rust_core/src/$module';
  }

  @override
  String get archiveChatScreenTitle => 'Ask the meeting archive';

  @override
  String get archiveChatScreenClear => 'Clear';

  @override
  String archiveChatScreenEmpty(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ask anything about your $count saved meetings.',
      one: 'Ask anything about your 1 saved meeting.',
      zero: 'No meetings in the library yet.',
    );
    return '$_temp0';
  }

  @override
  String get archiveChatScreenExplain =>
      '\"Search\" runs entirely on this computer. \"Answer\" also sends the passages it finds to the summary endpoint you configured, and is logged in the Privacy Report.';

  @override
  String get archiveChatScreenExample1 => 'What was decided about the budget?';

  @override
  String get archiveChatScreenExample2 =>
      'Who is responsible for the financial report?';

  @override
  String get archiveChatScreenExample3 => 'When is the launch deadline?';

  @override
  String get archiveChatScreenSources => 'Sources';

  @override
  String archiveChatScreenSourceSummary(String title, String date) {
    return '$title ($date) · summary';
  }

  @override
  String get archiveChatScreenHint => 'Ask something about your meetings…';

  @override
  String get archiveChatScreenSearch => 'Search';

  @override
  String get archiveChatScreenAnswer => 'Answer';

  @override
  String get redactionPreviewTitle => 'Redaction preview';

  @override
  String get redactionPreviewClose => 'Close';

  @override
  String redactionPreviewFailed(String error) {
    return 'Preview failed: $error';
  }

  @override
  String get redactionPreviewNoneFound =>
      'No personal data detected. The exported file will match the transcript exactly.';

  @override
  String get redactionPreviewNothing => 'Nothing will be redacted.';

  @override
  String redactionPreviewSummaryPart(int count, String kind) {
    return '$kind ($count)';
  }

  @override
  String redactionPreviewSummary(String parts) {
    return 'Will be redacted: $parts.';
  }

  @override
  String get redactionPreviewKindPhone => 'Phone number';

  @override
  String get redactionPreviewKindEmail => 'Email address';

  @override
  String get redactionPreviewKindBankAccount => 'Bank account number';

  @override
  String get redactionPreviewKindName => 'Name';

  @override
  String get liveQaPanelTitle => 'Live Q&A';

  @override
  String get liveQaPanelHint => 'Ask something about this meeting…';

  @override
  String get liveQaPanelAsk => 'Ask';

  @override
  String get liveQaPanelEmpty =>
      'Ask about anything discussed in this meeting so far.';

  @override
  String get liveQaPanelPrivacy =>
      'Answers go through the summary endpoint you set in Settings → AI summary, and are logged in the Privacy Report.';

  @override
  String get liveQaPanelSources => 'Transcript sources';

  @override
  String get recordButtonSaving => 'Saving…';

  @override
  String get recordButtonResume => 'Resume';

  @override
  String get recordButtonStop => 'Stop';

  @override
  String get recordButtonStart => 'Record';

  @override
  String get recordButtonResumeSemantics => 'Resume recording';

  @override
  String get recordButtonStopSemantics => 'Stop recording';

  @override
  String get recordButtonStartSemantics => 'Start recording';

  @override
  String get appDialogClose => 'Close';

  @override
  String get appDialogBarrierLabel => 'Close dialog';

  @override
  String get appDialogContinue => 'Continue';

  @override
  String get trayServiceOpen => 'Open Trareon Transcribe';

  @override
  String get trayServiceQuit => 'Quit';

  @override
  String get personalNotesPanelTitle => 'Personal notes';

  @override
  String get personalNotesPanelSubtitle =>
      'Saved automatically. Enhance merges it with the transcript later.';

  @override
  String get personalNotesPanelHint => 'e.g. IMPORTANT: deadline Friday…';
}
