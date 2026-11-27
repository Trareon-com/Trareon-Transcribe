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
  String get qualityProfileReasonManual => 'Set manually';

  @override
  String get qualityProfileReasonUnmeasured =>
      'Not measured yet, so conservative settings are used';

  @override
  String get qualityProfileReasonClean =>
      'Quiet room, so noise reduction and AGC are off to avoid losing words';

  @override
  String get qualityProfileReasonLightNoiseGain =>
      'Light noise, so only the level is raised';

  @override
  String get qualityProfileReasonLightNoiseNoGain =>
      'Light noise and the level is fine, so no gain is applied';

  @override
  String get qualityProfileReasonNoisy =>
      'Heavy noise, so noise reduction is on';

  @override
  String get notulenGenerationLengthShort => 'Brief';

  @override
  String get notulenGenerationLengthMedium => 'Standard';

  @override
  String get notulenGenerationLengthFull => 'Detailed';

  @override
  String get liveQaModelNeedsEndpoint =>
      'Live Q&A needs a summary endpoint set up in Settings → AI summary.';

  @override
  String privacyReportModelEventModelDownload(String modelId) {
    return 'Downloaded model \"$modelId\" from huggingface.co';
  }

  @override
  String privacyReportModelEventSummary(String endpoint) {
    return 'AI summary sent to $endpoint';
  }

  @override
  String privacyReportModelEventArchiveQuestion(
    String endpoint,
    int passageCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      passageCount,
      locale: localeName,
      other: '$passageCount meeting excerpts',
      one: '1 meeting excerpt',
    );
    return 'Archive question sent to $endpoint ($_temp0)';
  }

  @override
  String privacyReportModelEventLiveQaQuestion(
    String endpoint,
    int passageCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      passageCount,
      locale: localeName,
      other: '$passageCount transcript excerpts',
      one: '1 transcript excerpt',
    );
    return 'Live Q&A question sent to $endpoint ($_temp0)';
  }

  @override
  String privacyReportModelEventUpdateCheck(String endpoint) {
    return 'Checked for updates at $endpoint';
  }

  @override
  String privacyReportModelEventExternalLink(String url) {
    return 'Opened $url in the browser';
  }

  @override
  String get speechTimelineSemanticLabel => 'Recording timeline';

  @override
  String speechTimelinePercent(int percent) {
    return '$percent percent';
  }

  @override
  String get audioWatchdogModelMicSilent =>
      'The microphone has no permission or is sending no sound at all. Check the Microphone permission in System Settings.';

  @override
  String get audioWatchdogModelSystemAudioSilent =>
      'No system audio detected at all. Check the \"Screen & System Audio Recording\" permission in System Settings.';

  @override
  String get audioWatchdogModelBothSilent =>
      'Neither the microphone nor system audio has permission. Check Microphone and \"Screen & System Audio Recording\" in System Settings.';

  @override
  String get audioWatchdogModelNoSound =>
      'No sound detected yet. Check the Microphone and \"Screen & System Audio Recording\" permissions in System Settings, or make sure the right audio source is selected.';

  @override
  String get modelDownloadDialogDownloading => 'Downloading…';

  @override
  String modelDownloadDialogDownloadingName(String name) {
    return 'Downloading $name…';
  }

  @override
  String modelDownloadDialogDownloadingProgress(String name, int percent) {
    return 'Downloading $name… $percent%';
  }

  @override
  String modelDownloadDialogFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String modelDownloadDialogTitle(String name) {
    return 'Download $name';
  }

  @override
  String modelDownloadDialogPrompt(String name) {
    return '$name hasn\'t been downloaded yet. Download it now?';
  }

  @override
  String get modelDownloadDialogDownload => 'Download';

  @override
  String retranscribeDialogEngineFailed(String error) {
    return 'Re-transcription failed: $error. The previous transcript is kept.';
  }

  @override
  String get retranscribeDialogNoSpeech =>
      'No speech detected. The previous transcript is kept.';

  @override
  String retranscribeDialogFailed(String error) {
    return 'Re-transcription failed (the previous transcript is safe): $error';
  }

  @override
  String get retranscribeDialogTitle => 'Re-transcribe';

  @override
  String get retranscribeDialogDescription =>
      'The original audio will be transcribed again. The old transcript is replaced only if this succeeds.';

  @override
  String get retranscribeDialogModelLabel => 'Model quality';

  @override
  String get retranscribeDialogLanguageLabel => 'Language';

  @override
  String get retranscribeDialogAutoDetect => 'Auto-detect';

  @override
  String get retranscribeDialogIndonesian => 'Indonesian';

  @override
  String get retranscribeDialogNoModels => 'No models installed.';

  @override
  String get retranscribeDialogProcessing =>
      'Processing… this can take a while for long recordings.';

  @override
  String get retranscribeDialogStart => 'Start';

  @override
  String get auditLogViewTitle => 'Audit log';

  @override
  String get auditLogViewClose => 'Close';

  @override
  String auditLogViewReadError(String error) {
    return 'The audit log can\'t be read: $error';
  }

  @override
  String get auditLogViewEmpty =>
      'No entries yet. The log fills in when a session is created, a transcript is exported, or data is deleted.';

  @override
  String get auditLogViewActionSessionCreated => 'Session created';

  @override
  String get auditLogViewActionSessionExported => 'Transcript exported';

  @override
  String get auditLogViewActionSummarySent => 'Summary sent to endpoint';

  @override
  String get auditLogViewActionSessionDeleted => 'Session deleted';

  @override
  String get auditLogViewActionAudioDeleted => 'Audio deleted';

  @override
  String get auditLogViewActionTranscriptDeleted => 'Transcript deleted';

  @override
  String get auditLogViewActionConsentAcknowledged => 'Recording notice given';

  @override
  String get auditLogViewActionRedactionApplied => 'Personal data redacted';

  @override
  String get auditLogViewActionRetentionApplied => 'Retention policy applied';

  @override
  String get auditLogViewActionAuditExported => 'Audit log exported';

  @override
  String get auditLogViewActionModelPulled => 'Minutes model downloaded';

  @override
  String get auditLogViewActionDocumentContextUsed => 'Document context used';

  @override
  String get auditLogViewActionTranscriptEnhanced =>
      'Transcript refined automatically';

  @override
  String get onboardingScreenWelcome => 'Welcome to Trareon Transcribe';

  @override
  String get onboardingScreenReady => 'Ready to record';

  @override
  String get onboardingScreenPostponed => 'Download postponed';

  @override
  String get onboardingScreenNeedsDownload => 'Models need to be downloaded';

  @override
  String get onboardingScreenDownloading => 'Downloading models';

  @override
  String get onboardingScreenReadyBody =>
      'Both models are on this device. Transcription runs fully offline.';

  @override
  String get onboardingScreenOfflineBody =>
      'Trareon works 100% offline, so the models need to be on your device. This happens only once.';

  @override
  String get onboardingScreenRetry => 'Try again';

  @override
  String get onboardingScreenDownloadNow => 'Download now';

  @override
  String get onboardingScreenContinueWithoutModels => 'Continue without models';

  @override
  String get onboardingScreenStartRecording => 'Start recording';

  @override
  String get onboardingScreenAwaitingConsent =>
      'Waiting for download permission';

  @override
  String get onboardingScreenDownloadingButton => 'Downloading…';

  @override
  String get onboardingScreenFooterReady =>
      'The models are never sent anywhere.';

  @override
  String get onboardingScreenFooterPostponed =>
      'Nothing was downloaded. Without models, recordings can\'t be transcribed yet. You\'ll be asked again when you start recording.';

  @override
  String get onboardingScreenFooterWaiting =>
      'Nothing is downloaded until you agree.';

  @override
  String get onboardingScreenFooterDownloading =>
      'You can close the app. The download continues in the background.';

  @override
  String get onboardingScreenStepPermissions =>
      'Microphone & system audio permission';

  @override
  String get onboardingScreenStepModel => 'Choose models';

  @override
  String get onboardingScreenStepReady => 'Ready to record';

  @override
  String onboardingScreenStepSemantics(int step, int total, String label) {
    return 'Step $step of $total: $label';
  }

  @override
  String get onboardingScreenQuickModelTitle => 'Fast model';

  @override
  String get onboardingScreenQuickModelSubtitle =>
      'Fast transcription, best accuracy for Indonesian';

  @override
  String get onboardingScreenAccurateModelTitle => 'Accurate model';

  @override
  String get onboardingScreenAccurateModelSubtitle =>
      'Refines the transcript in the background, best accuracy across languages';

  @override
  String sessionModelSaveFailed(String outputDir, String error) {
    return 'The session stopped, but the transcript couldn\'t be saved to $outputDir: $error';
  }

  @override
  String settingsModelSaveFailed(String label, String message) {
    return 'The \"$label\" setting couldn\'t be saved: $message. The change was reverted.';
  }

  @override
  String get settingsModelLabelTheme => 'Theme';

  @override
  String get settingsModelLabelProgressive => 'Fast first, then refined';

  @override
  String get settingsModelLabelGpu => 'GPU acceleration';

  @override
  String get settingsModelLabelGpuDevice => 'GPU device';

  @override
  String get settingsModelLabelBenchmark => 'Benchmark score';

  @override
  String get settingsModelLabelHptMode => 'Progressive transcription method';

  @override
  String get settingsModelLabelSummary => 'AI summary';

  @override
  String get settingsModelLabelGlossary => 'Glossary';

  @override
  String get settingsModelLabelNeuralDiarization =>
      'Accurate speaker separation';

  @override
  String get settingsModelLabelEngineModels => 'Engine models';

  @override
  String get settingsModelLabelPdp => 'PDP compliance mode';

  @override
  String get settingsModelLabelSummaryTemplates => 'Summary templates';

  @override
  String get settingsModelLabelNotulenLetterhead => 'Minutes letterhead';

  @override
  String get settingsModelLabelAutoRetranscribe =>
      'Refine transcripts automatically';

  @override
  String get settingsModelLabelDefaultModel => 'Default model';

  @override
  String get settingsModelLabelLanguage => 'Transcription language';

  @override
  String get settingsModelLabelDefaultMode => 'Default mode';

  @override
  String get settingsModelLabelVad => 'Skip silent pauses';

  @override
  String get settingsModelLabelNoiseReduction => 'Noise reduction';

  @override
  String get settingsModelLabelAgc => 'Automatic gain';

  @override
  String get settingsModelLabelAutoAudioTuning => 'Automatic audio tuning';

  @override
  String get settingsModelLabelSimpleMode => 'Simple mode';

  @override
  String get settingsModelLabelDeferDownloads => 'Postpone downloads';

  @override
  String get settingsModelLabelUpgradeOffer => 'Accuracy upgrade offer';

  @override
  String get settingsModelLabelConsentReminder => 'Recording consent reminder';

  @override
  String get settingsModelLabelAutoStop => 'Auto-stop on silence';

  @override
  String get settingsModelLabelExportFormat => 'Default export format';

  @override
  String get settingsModelLabelOutputFolder => 'Output folder';

  @override
  String get settingsModelLabelMicrophone => 'Microphone';

  @override
  String get settingsModelLabelSpeaker => 'Speaker';

  @override
  String get sessionControlsSessionGroup => 'Session';

  @override
  String get sessionControlsTitlePlaceholder => 'Session title…';

  @override
  String get sessionControlsModeSemantics => 'Session mode';

  @override
  String get sessionControlsAttendees => 'Attendees:';

  @override
  String get sessionControlsModeOfflineSemantics =>
      'In-person meeting mode: microphone only';

  @override
  String get sessionControlsModeOnlineSemantics =>
      'Online meeting mode: microphone and system audio';

  @override
  String get sessionControlsModeWebinarSemantics =>
      'Webinar mode: system audio only';

  @override
  String get sessionControlsModeOfflineExplanation =>
      'A meeting in one room. Only the microphone is recorded.';

  @override
  String get sessionControlsModeOnlineExplanation =>
      'Zoom, Meet or Teams. Microphone and system audio.';

  @override
  String get sessionControlsModeWebinarExplanation =>
      'You\'re only listening. System audio only.';

  @override
  String sessionControlsGlossaryTooltip(int globalCount) {
    return 'Terms for this meeting only, on top of the $globalCount glossary terms in Settings';
  }

  @override
  String get sessionControlsGlossarySemanticsEmpty => 'Meeting terms, none yet';

  @override
  String sessionControlsGlossarySemanticsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count terms',
      one: '1 term',
    );
    return 'Meeting terms, $_temp0';
  }

  @override
  String get sessionControlsGlossaryPill => 'Meeting terms';

  @override
  String sessionControlsGlossaryPillCount(int count) {
    return 'Meeting terms ($count)';
  }

  @override
  String get sessionControlsGlossaryDialogTitle => 'Terms for this meeting';

  @override
  String get sessionControlsGlossaryDialogDescription =>
      'One term per line: attendee names, abbreviations, program names. These take priority over the glossary in Settings.';

  @override
  String get sessionControlsOptionsTooltip => 'Session options';

  @override
  String get sessionControlsQualityHeader => 'Transcription quality';

  @override
  String get sessionControlsSkipSilence => 'Skip silent pauses';

  @override
  String get sessionControlsLanguageHeader => 'Language for this meeting';

  @override
  String get sessionControlsLanguageAuto => 'Automatic (detect per sentence)';

  @override
  String get sessionControlsLanguageIndonesian => 'Indonesian';

  @override
  String get sessionControlsLanguageEnglish => 'English';

  @override
  String get sessionControlsLanguageMismatch =>
      'Many recent sentences were detected in a language other than the one chosen for this session.';

  @override
  String get sessionControlsSwitchToAuto => 'Switch to automatic';

  @override
  String get sessionControlsConsentReminder =>
      'Make sure everyone in the meeting knows it is being recorded.';

  @override
  String get sessionControlsDontShowAgain => 'Don\'t show again';

  @override
  String get sessionControlsMicrophone => 'Microphone';

  @override
  String get sessionControlsSystemAudio => 'System audio';

  @override
  String get sessionControlsDevicesGroup => 'Devices';

  @override
  String get sessionControlsSystemDefault => 'System default';

  @override
  String sessionControlsDeviceOn(String label) {
    return '$label on';
  }

  @override
  String sessionControlsDeviceOff(String label) {
    return '$label off';
  }

  @override
  String sessionControlsChooseDevice(String label) {
    return 'Choose $label device';
  }

  @override
  String get sessionControlsDeviceAuto => 'Automatic (system default)';

  @override
  String sessionControlsReloadDevices(String label) {
    return 'Reload $label device list';
  }

  @override
  String sessionControlsLevel(String label) {
    return '$label level';
  }

  @override
  String get mainScreenQuitReasonRecording => 'A recording is still running.';

  @override
  String mainScreenQuitReasonOutstanding(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count recordings are still being transcribed. This resumes automatically when the app opens again.',
      one: '1 recording is still being transcribed. This resumes automatically when the app opens again.',
    );
    return '$_temp0';
  }

  @override
  String get mainScreenQuitReasonRefining =>
      'A transcript is still being refined.';

  @override
  String get mainScreenQuitTitle => 'Quit now?';

  @override
  String get mainScreenQuitStay => 'Stay in the app';

  @override
  String get mainScreenQuit => 'Quit';

  @override
  String get mainScreenMeetingDetectedTitle => 'Meeting detected';

  @override
  String mainScreenMeetingDetectedBody(String app) {
    return 'A meeting was detected ($app). Start recording?';
  }

  @override
  String get mainScreenIgnore => 'Ignore';

  @override
  String get mainScreenStartRecording => 'Start recording';

  @override
  String get mainScreenSilenceTitle => 'No sound';

  @override
  String mainScreenSilenceBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'No sound for $_temp0. Recording will stop automatically unless you continue.';
  }

  @override
  String get mainScreenContinue => 'Continue';

  @override
  String mainScreenDiskFull(String path, String detail) {
    return 'There isn\'t enough disk space at $path to record. $detail Free up space or change the library location in Settings.';
  }

  @override
  String get mainScreenSaveElsewhereDialogTitle =>
      'Save transcript to another folder';

  @override
  String get mainScreenTranscriptSaved => 'Transcript saved.';

  @override
  String mainScreenSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String mainScreenRecoverFailed(String error) {
    return 'Couldn\'t recover the session: $error';
  }

  @override
  String mainScreenRecovered(String title, int segments, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      segments,
      locale: localeName,
      other: '$segments segments',
      one: '1 segment',
    );
    return '\"$title\" recovered: $_temp0 and $duration of audio.';
  }

  @override
  String mainScreenDeleteFailed(String error) {
    return 'Couldn\'t delete: $error';
  }

  @override
  String mainScreenDeleted(String title) {
    return '\"$title\" deleted.';
  }

  @override
  String mainScreenRecoveryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count interrupted sessions',
      one: '1 interrupted session',
    );
    return '$_temp0';
  }

  @override
  String mainScreenRecoverySegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transcript segments',
      one: '1 transcript segment',
    );
    return '$_temp0';
  }

  @override
  String mainScreenRecoveryAudio(String duration) {
    return '$duration of audio';
  }

  @override
  String get mainScreenRecoveryJoiner => ' and ';

  @override
  String mainScreenRecoveryNothingLeft(String count) {
    return '$count, with no transcript or audio left.';
  }

  @override
  String mainScreenRecoveryContents(String count, String contents) {
    return '$count: $contents can be recovered.';
  }

  @override
  String get mainScreenStopTitle => 'Stop recording?';

  @override
  String mainScreenStopBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transcript segments',
      one: '1 transcript segment',
    );
    return 'This session has $_temp0. It will be saved automatically when you stop.';
  }

  @override
  String get mainScreenStop => 'Stop';

  @override
  String mainScreenStopFailed(String error) {
    return 'Couldn\'t stop the session: $error';
  }

  @override
  String mainScreenSessionSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '1 segment',
    );
    return 'Session saved ($_temp0).';
  }

  @override
  String get mainScreenNothingToBookmark =>
      'Nothing has been recorded to mark yet.';

  @override
  String mainScreenBookmarked(String time) {
    return 'Marked at $time.';
  }

  @override
  String get mainScreenModelMissingTitle => 'Model not downloaded';

  @override
  String mainScreenModelMissingMessage(String model, String size) {
    return 'Recording needs $model on this device. Download it now$size? The download is logged in the Privacy Report.';
  }

  @override
  String get mainScreenDownloadNow => 'Download now';

  @override
  String get mainScreenLater => 'Later';

  @override
  String get mainScreenNothingToExport => 'There is no transcript to export.';

  @override
  String get mainScreenChooseExportFolder => 'Choose export folder';

  @override
  String mainScreenExportSucceeded(String dir) {
    return 'Exported to: $dir';
  }

  @override
  String mainScreenExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String mainScreenCannotOpen(String title) {
    return '\"$title\" can\'t be opened.';
  }

  @override
  String get mainScreenOpenSystemSettings => 'Open System Settings';

  @override
  String get mainScreenStarting => 'Starting…';

  @override
  String get mainScreenSaving => 'Saving…';

  @override
  String get mainScreenSwitchPanel => 'Switch panel';

  @override
  String get mainScreenPersonalNotes => 'Personal notes';

  @override
  String get mainScreenLiveQa => 'Live Q&A';

  @override
  String get mainScreenReady => 'Ready to record';

  @override
  String get mainScreenLocalOnly =>
      'All transcription runs on this computer. No audio leaves it.';

  @override
  String get mainScreenTitlePlaceholder => 'Session title…';

  @override
  String get mainScreenStartFromTemplate => 'Start from a template';

  @override
  String get mainScreenImportInvite => 'Import invite (.ics)';

  @override
  String get mainScreenOrPress => 'or press';

  @override
  String get mainScreenSessionHistory => 'Session history';

  @override
  String get mainScreenRecordingDuration => 'Recording duration';

  @override
  String get mainScreenPaused => 'Paused';

  @override
  String mainScreenBookmarkTooltip(String shortcut) {
    return 'Mark an important point ($shortcut)';
  }

  @override
  String get mainScreenExport => 'Export';

  @override
  String mainScreenSaveFailedBanner(String message) {
    return '$message The transcript is still in memory. Don\'t close the app until it\'s saved.';
  }

  @override
  String get mainScreenSaveElsewhere => 'Save to another folder';

  @override
  String get mainScreenRetry => 'Try again';

  @override
  String get mainScreenViewAndRecover => 'View & recover';

  @override
  String mainScreenSegmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '1 segment',
    );
    return '$_temp0';
  }

  @override
  String get mainScreenShowShortcuts => 'Show keyboard shortcuts';

  @override
  String get mainScreenShortcuts => 'Shortcuts';

  @override
  String get mainScreenKeyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get mainScreenClose => 'Close';
}
