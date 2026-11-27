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
  String get settingsScreenTitle => 'Settings';

  @override
  String get settingsScreenCategoryAppearance => 'Appearance';

  @override
  String get settingsScreenCategoryModelMode => 'Model & mode';

  @override
  String get settingsScreenCategoryAudio => 'Audio & sound';

  @override
  String get settingsScreenCategoryGlossary => 'Glossary';

  @override
  String get settingsScreenCategoryStorage => 'Storage';

  @override
  String get settingsScreenCategorySummary => 'AI summary';

  @override
  String get settingsScreenCategoryMinutes => 'Official minutes';

  @override
  String get settingsScreenCategoryCompliance => 'PDP compliance';

  @override
  String get settingsScreenCategorySetup => 'Setup & diagnostics';

  @override
  String get settingsScreenCategoryAbout => 'About';

  @override
  String get settingsScreenDismiss => 'Dismiss';

  @override
  String get settingsScreenRetry => 'Try again';

  @override
  String get settingsScreenTheme => 'Theme';

  @override
  String get settingsScreenThemeSystemSubtitle =>
      'Follows your operating system\'s current theme.';

  @override
  String get settingsScreenThemeLightSubtitle =>
      'Always light, whatever the system theme.';

  @override
  String get settingsScreenThemeDarkSubtitle =>
      'Always dark, whatever the system theme.';

  @override
  String get settingsScreenThemeLight => 'Light';

  @override
  String get settingsScreenThemeDark => 'Dark';

  @override
  String get settingsScreenThemeSystem => 'System';

  @override
  String get settingsScreenSimpleMode => 'Simple mode';

  @override
  String get settingsScreenSimpleModeOnSubtitle =>
      'Only controls that change the transcript are shown. The rest are under \"Advanced settings\".';

  @override
  String get settingsScreenSimpleModeOffSubtitle => 'All controls are shown.';

  @override
  String get settingsScreenAutoAudioTuning => 'Automatic audio tuning';

  @override
  String get settingsScreenAutoAudioTuningOffSubtitle =>
      'Turned off because you changed noise reduction/AGC yourself. Your values are used.';

  @override
  String get settingsScreenChangeManually => 'Adjust manually';

  @override
  String get settingsScreenUseAutomatic => 'Use automatic';

  @override
  String get settingsScreenDefaultModel => 'Default model';

  @override
  String get settingsScreenModelAvailable => 'Available on this computer.';

  @override
  String get settingsScreenModelNotDownloaded =>
      'Not downloaded yet. Select it to download.';

  @override
  String get settingsScreenProgressive => 'Fast first, then refined';

  @override
  String get settingsScreenProgressiveOnSubtitle =>
      'Text appears quickly, then is corrected automatically by a more careful model.';

  @override
  String get settingsScreenProgressiveOffSubtitle =>
      'Uses a single model. Text appears once, already final.';

  @override
  String get settingsScreenAutoRetranscribe =>
      'Automatically refine with a more accurate model in the background';

  @override
  String get settingsScreenAutoRetranscribeMissingSubtitle =>
      'The accurate model is not installed on this computer. Download it from \"Default model\" above before turning this on.';

  @override
  String get settingsScreenAutoRetranscribeOnSubtitle =>
      'After a recording or upload finishes, the transcript is refined in the background without interrupting your work. The old transcript is replaced only if this succeeds.';

  @override
  String get settingsScreenAutoRetranscribeOffSubtitle =>
      'Off. Transcripts are not refined automatically after recording.';

  @override
  String get settingsScreenGpu => 'GPU acceleration';

  @override
  String get settingsScreenDefaultMode => 'Default mode';

  @override
  String get settingsScreenModeWebinarSubtitle =>
      'Microphone off, system audio recorded.';

  @override
  String get settingsScreenModeOnlineSubtitle =>
      'Microphone and system audio recorded.';

  @override
  String get settingsScreenModeOfflineSubtitle =>
      'Only the microphone is recorded.';

  @override
  String get settingsScreenTranscriptionLanguage => 'Transcription language';

  @override
  String get settingsScreenLanguageAutoSubtitle =>
      'Language is detected automatically for each segment.';

  @override
  String get settingsScreenLanguageForcedSubtitle =>
      'Locked to one language. More accurate when the meeting is in a single language.';

  @override
  String get settingsScreenLanguageAuto => 'Detect automatically';

  @override
  String get settingsScreenLanguageIndonesian => 'Indonesian';

  @override
  String get settingsScreenHideAdvanced => 'Hide advanced settings';

  @override
  String get settingsScreenShowAdvanced => 'Advanced settings';

  @override
  String get settingsScreenAdvancedSubtitle =>
      'GPU acceleration · fast-then-refined · background refinement · recording mode.';

  @override
  String get settingsScreenTranscription => 'Transcription';

  @override
  String get settingsScreenSpeedComparison => 'Speed comparison';

  @override
  String get settingsScreenSpeedComparisonSubtitle =>
      'Indonesian: light 3 s · fast 10 s · accurate 56 s per minute of audio.\nThe accurate model is recommended for meetings and interviews.';

  @override
  String settingsScreenAudioDecision(String reason, String noise, String agc) {
    return '$reason. Noise reduction $noise, AGC $agc.';
  }

  @override
  String get settingsScreenStateOn => 'on';

  @override
  String get settingsScreenStateOff => 'off';

  @override
  String get settingsScreenGpuUnknownOnSubtitle =>
      'Will use the GPU if this build supports it.';

  @override
  String get settingsScreenGpuCpuSubtitle => 'Transcription uses the CPU.';

  @override
  String get settingsScreenGpuNotCompiledSubtitle =>
      'This build was compiled without GPU support, so transcription uses the CPU even with this switch on.';

  @override
  String settingsScreenGpuOnSubtitle(String backend) {
    return 'Transcription uses the GPU ($backend).';
  }

  @override
  String settingsScreenGpuAvailableOffSubtitle(String backend) {
    return 'GPU ($backend) is available, but transcription uses the CPU.';
  }

  @override
  String get settingsScreenDecidedAutomatically => 'Decided automatically';

  @override
  String get settingsScreenVad => 'Skip silent pauses';

  @override
  String get settingsScreenVadOnSubtitle =>
      'Silent parts are skipped, so transcription is faster. Takes effect from the next session.';

  @override
  String get settingsScreenVadOffSubtitle =>
      'All audio is transcribed, including silent parts.';

  @override
  String get settingsScreenNoiseReduction => 'Noise reduction (RNNoise)';

  @override
  String get settingsScreenNoiseReductionOnSubtitle =>
      'Room noise (fans, air conditioning, traffic) is suppressed before transcription. Takes effect from the next audio chunk.';

  @override
  String get settingsScreenNoiseReductionOffSubtitle =>
      'Off. Turn it on if your room is noisy. On recordings that are already clean it can drop a consonant or two.';

  @override
  String get settingsScreenAgc => 'Automatic gain control (AGC)';

  @override
  String get settingsScreenAgcOnSubtitle =>
      'Quiet but real speech is boosted before transcription so it is not read as silence.';

  @override
  String get settingsScreenAgcOffSubtitle =>
      'Off. Audio is transcribed at its original volume.';

  @override
  String get settingsScreenDedup => 'Remove duplicate audio';

  @override
  String get settingsScreenDedupOnlineSubtitle =>
      'Active in Online meeting mode: MIC/SPK duplicates are removed.';

  @override
  String get settingsScreenDedupOtherSubtitle =>
      'Only applies in Online meeting mode.';

  @override
  String get settingsScreenDedupInfo =>
      'Compares microphone and speaker audio, then removes anything heard twice.';

  @override
  String get settingsScreenAutoStop => 'Stop automatically when silent';

  @override
  String settingsScreenAutoStopOnSubtitle(int minutes) {
    return 'Stops after $minutes min without sound.';
  }

  @override
  String get settingsScreenAutoStopOffSubtitle =>
      'Recording continues until you stop it.';

  @override
  String get settingsScreenAutoStopDelay => 'Silence before stopping';

  @override
  String settingsScreenMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsScreenOutputStorage => 'Output & storage';

  @override
  String get settingsScreenOutputFolder => 'Output folder';

  @override
  String get settingsScreenPickOutputFolder => 'Choose output folder';

  @override
  String get settingsScreenDefaultExportFormat => 'Default export format';

  @override
  String get settingsScreenDefaultExportFormatSubtitle =>
      'The format already selected when the Export dialog opens.';

  @override
  String get settingsScreenDiagnostics => 'Diagnostics';

  @override
  String get settingsScreenDiagnosticsSubtitle =>
      'Check folders, models, microphone and disk space. Everything stays local.';

  @override
  String get settingsScreenRerunSetup => 'Run setup again';

  @override
  String get settingsScreenRerunSetupSubtitle =>
      'Choose the microphone, speakers and model again, then test the sound.';

  @override
  String get settingsScreenPrivacyReport => 'Privacy Report';

  @override
  String get settingsScreenPrivacyReportSubtitle =>
      'Everything that has ever left this computer.';

  @override
  String get settingsScreenCapabilities => 'What runs where';

  @override
  String get settingsScreenCapabilitiesSubtitle =>
      'Every capability, where it runs, and its current status.';

  @override
  String get settingsScreenUsageDashboard => 'Usage dashboard';

  @override
  String get settingsScreenUsageDashboardSubtitle =>
      'How long you record, per week.';

  @override
  String get settingsScreenCheckUpdate => 'Check for updates';

  @override
  String settingsScreenCheckUpdateSubtitle(String version) {
    return 'Current version $version. Checking for updates contacts GitHub and is logged in the Privacy Report.';
  }

  @override
  String get settingsScreenAboutTrareon => 'About Trareon';

  @override
  String get settingsScreenTagline =>
      'Offline transcription, guaranteed privacy.';

  @override
  String get settingsScreenUpdateAvailableTitle => 'Update available';

  @override
  String settingsScreenUpdateAvailableBody(String latest, String current) {
    return 'Version $latest is available (current: $current).';
  }

  @override
  String get settingsScreenLater => 'Later';

  @override
  String get settingsScreenViewRelease => 'View release';

  @override
  String get settingsScreenUpToDate => 'You\'re on the latest version.';

  @override
  String settingsScreenUpdateCheckFailed(String error) {
    return 'Couldn\'t check for updates: $error';
  }

  @override
  String settingsScreenBrowserFailed(String url) {
    return 'Couldn\'t open the browser. Open $url manually.';
  }

  @override
  String get settingsScreenBuiltWith => 'Built with Flutter + Rust';

  @override
  String settingsScreenUpgradeOffer(String model) {
    return 'This computer can run $model for better accuracy.';
  }

  @override
  String get settingsScreenUpgradeAccuracy => 'Improve accuracy';

  @override
  String get settingsScreenNotNow => 'Not now';

  @override
  String get summaryPanelSaved => 'Summary saved.';

  @override
  String summaryPanelShareFailed(String error) {
    return 'Couldn\'t prepare the summary for sharing: $error';
  }

  @override
  String get summaryPanelTitle => 'AI summary';

  @override
  String get summaryPanelUnsaved => 'unsaved';

  @override
  String get summaryPanelDisabledNotice =>
      'AI summary is off. It is the only feature that uses the network. Turn it on in Settings, AI summary, if you want to use it.';

  @override
  String get summaryPanelTemplateLabel => 'Template';

  @override
  String get summaryPanelCustomTemplateHelper => 'Your own template';

  @override
  String get summaryPanelManageTemplates => 'Manage summary templates';

  @override
  String get summaryPanelRegenerate => 'Regenerate';

  @override
  String get summaryPanelGenerate => 'Generate summary';

  @override
  String get summaryPanelPlaceholder =>
      'The summary will appear here. You can edit it before saving.';

  @override
  String summaryPanelDroppedCitations(int count) {
    return 'Citations discarded for not matching the transcript: $count. Review this summary more carefully.';
  }

  @override
  String get summaryPanelViewCitations => 'View citations';

  @override
  String get summaryPanelEdit => 'Edit';

  @override
  String get summaryPanelCopied => 'Summary copied.';

  @override
  String get summaryPanelCopy => 'Copy';

  @override
  String get summaryPanelShare => 'Share';

  @override
  String get summaryPanelPersonalNotes => 'Personal notes';

  @override
  String get summaryPanelEnhance => 'Enhance';

  @override
  String get summaryPanelNoNotes =>
      'No notes were written during the meeting. Enhance still works, but the result will be a summary of the transcript only.';

  @override
  String get summaryPanelMergedResult => 'Combined result (AI)';

  @override
  String summaryPanelPlayCitation(int segment, String time) {
    return 'Play segment $segment at $time';
  }

  @override
  String get summaryTemplateEditorManagerTitle => 'Summary templates';

  @override
  String get summaryTemplateEditorManagerIntro =>
      'Create your own templates with your own section headings and instructions. Stored on this computer.';

  @override
  String get summaryTemplateEditorEmpty => 'No templates of your own yet.';

  @override
  String get summaryTemplateEditorNoHeadings => 'No section headings';

  @override
  String summaryTemplateEditorEditTooltip(String name) {
    return 'Edit $name';
  }

  @override
  String summaryTemplateEditorDuplicateTooltip(String name) {
    return 'Duplicate $name';
  }

  @override
  String summaryTemplateEditorDeleteTooltip(String name) {
    return 'Delete $name';
  }

  @override
  String summaryTemplateEditorCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get summaryTemplateEditorStartFromBuiltin =>
      'Start from a built-in template';

  @override
  String summaryTemplateEditorDuplicateBuiltinTooltip(String name) {
    return 'Duplicate \"$name\" as your own template';
  }

  @override
  String summaryTemplateEditorMineName(String name) {
    return '$name (mine)';
  }

  @override
  String get summaryTemplateEditorBlank => 'Blank';

  @override
  String get summaryTemplateEditorBlankTooltip =>
      'Create a template from scratch';

  @override
  String get summaryTemplateEditorDefaultName => 'My template';

  @override
  String get summaryTemplateEditorClose => 'Close';

  @override
  String get summaryTemplateEditorEditTitle => 'Edit template';

  @override
  String get summaryTemplateEditorNameLabel => 'Template name';

  @override
  String get summaryTemplateEditorHeadingsLabel =>
      'Section headings (one per line)';

  @override
  String get summaryTemplateEditorHeadingsHint => 'Summary\nDecisions\nRisks';

  @override
  String get summaryTemplateEditorInstructionsLabel =>
      'Additional instructions';

  @override
  String get summaryTemplateEditorInstructionsHint =>
      'e.g. Focus on budget risks and quote figures exactly as they appear in the transcript.';

  @override
  String get summaryTemplateEditorHeadingsNote =>
      'Section headings are sent as an ordered list, so the output stays consistent and can fill in the minutes form.';

  @override
  String get captureHealthViewSourceSystem => 'System audio';

  @override
  String get captureHealthViewSourceMic => 'Microphone';

  @override
  String captureHealthViewWentSilent(String sources) {
    return '$sources went silent';
  }

  @override
  String get captureHealthViewConfirmed => 'Recording confirmed';

  @override
  String captureHealthViewWaiting(String sources) {
    return 'Waiting for sound from $sources';
  }

  @override
  String get captureHealthViewConfirmedTooltip =>
      'Every requested source has produced sound above the noise floor.';

  @override
  String get captureHealthViewUnconfirmedTooltip =>
      'Not every requested source has produced real sound yet.';

  @override
  String get captureHealthViewAudioIssue => 'Unresolved audio problem';

  @override
  String captureHealthViewAudioIssueTooltip(String label) {
    return '$label. The microphone or system audio is not sending sound. See the latest notification or check System Settings.';
  }

  @override
  String captureHealthViewSummary(String duration, int segments) {
    return 'Duration $duration · $segments transcript segments';
  }

  @override
  String get captureHealthViewNoSources =>
      'No audio sources were requested for this session.';

  @override
  String captureHealthViewChannelOk(
    String source,
    String duration,
    String percent,
  ) {
    return '$source: $duration recorded, $percent% silent';
  }

  @override
  String captureHealthViewChannelSilent(String source, String duration) {
    return '$source: no sound at all ($duration recorded)';
  }

  @override
  String get captureHealthViewSessionDone => 'Session finished';

  @override
  String get captureHealthViewSessionDoneIssues =>
      'Session finished with problems';

  @override
  String get captureHealthViewNotSaved => 'The transcript has not been saved.';

  @override
  String get captureHealthViewClose => 'Close';

  @override
  String get notulenSettingsSectionPickKopTitle =>
      'Choose a letterhead image (PNG)';

  @override
  String get notulenSettingsSectionKopMustBePng =>
      'The letterhead must be a PNG file.';

  @override
  String notulenSettingsSectionReadFailed(String error) {
    return 'Couldn\'t read the file: $error';
  }

  @override
  String get notulenSettingsSectionTitle => 'Official minutes';

  @override
  String get notulenSettingsSectionIntro =>
      'Details that stay the same for every meeting. Filled in automatically when you create meeting minutes.';

  @override
  String get notulenSettingsSectionUnitLabel => 'Agency / work unit';

  @override
  String get notulenSettingsSectionUnitHint =>
      'e.g. Directorate General of Budget';

  @override
  String get notulenSettingsSectionPlaceLabel => 'Usual venue/medium';

  @override
  String get notulenSettingsSectionPlaceHint =>
      'e.g. 5th-floor meeting room / Zoom';

  @override
  String get notulenSettingsSectionNotulisLabel => 'Minute-taker name';

  @override
  String get notulenSettingsSectionNotulisHint =>
      'Your name, for the signature block';

  @override
  String get notulenSettingsSectionKop => 'Letterhead';

  @override
  String get notulenSettingsSectionKopEmpty =>
      'None chosen. Without an image, the letterhead is written as text from the agency name above.';

  @override
  String get notulenSettingsSectionRemoveKop => 'Remove letterhead';

  @override
  String get notulenSettingsSectionPickKop => 'Choose letterhead image';

  @override
  String get platformChromeMinimize => 'Minimize';

  @override
  String get platformChromeMaximize => 'Maximize';

  @override
  String get platformChromeClose => 'Close';

  @override
  String get platformChromeMenuSettings => 'Settings…';

  @override
  String get platformChromeMenuFile => 'File';

  @override
  String get platformChromeMenuNewSession => 'New Session';

  @override
  String get platformChromeMenuToggleRecording => 'Start or Stop Recording';

  @override
  String get platformChromeMenuView => 'View';

  @override
  String get platformChromeMenuSearch => 'Search Session History';

  @override
  String get platformChromeMenuHideSidebar => 'Hide Sidebar';

  @override
  String get platformChromeMenuWindow => 'Window';

  @override
  String get platformChromeMenuHelp => 'Help';

  @override
  String get platformChromeMenuShortcuts => 'Keyboard Shortcuts';

  @override
  String get modelLabelsLight => 'Light';

  @override
  String get modelLabelsFast => 'Fast';

  @override
  String get modelLabelsFastExperimental => 'Fast-Experimental';

  @override
  String get modelLabelsMedium => 'Medium';

  @override
  String get modelLabelsHigh => 'High';

  @override
  String get modelLabelsAccurate => 'Accurate';

  @override
  String get modelLabelsAccurateRecommended => 'Accurate (recommended)';

  @override
  String get modelLabelsAccurateExperimental => 'Accurate-Experimental';

  @override
  String get modelLabelsInstalled => 'Installed model';

  @override
  String setupOverlayNeedsAttention(String names) {
    return 'Needs attention: $names.';
  }

  @override
  String get setupOverlayViewDiagnostics => 'View diagnostics';

  @override
  String get setupOverlayClose => 'Close';

  @override
  String get setupOverlayNotReady => 'Trareon isn\'t ready to record';

  @override
  String get setupOverlayChecking => 'Checking…';

  @override
  String get setupOverlayCheckAgain => 'Check again';

  @override
  String get setupOverlayContinueAnyway => 'Continue anyway';

  @override
  String sessionArchiveServiceOpenFailed(String error) {
    return 'Couldn\'t open the archive: it is unreadable or damaged ($error).';
  }

  @override
  String get sessionArchiveServiceEmpty =>
      'This archive is empty or is not a Trareon session archive.';

  @override
  String get sessionArchiveServiceNoTranscript =>
      'This file is not a valid Trareon session archive: it contains no transcript.';

  @override
  String get completionBannerExportIncomplete =>
      'The transcript is still filling in. An export now will be incomplete.';

  @override
  String get completionBannerIncomplete => 'Incomplete';

  @override
  String completionBannerIncompletePercent(int percent) {
    return 'Incomplete · $percent%';
  }

  @override
  String get completionBannerIncompleteTooltip =>
      'Some audio has not been transcribed yet. The transcript will be completed automatically in the background.';

  @override
  String get streamToggleMic => 'Microphone';

  @override
  String get streamToggleSpeaker => 'System audio';

  @override
  String get streamToggleStateOn => 'on';

  @override
  String get streamToggleStateOff => 'off';

  @override
  String streamToggleMicAnnouncement(String state) {
    return 'Microphone $state';
  }

  @override
  String streamToggleSpeakerAnnouncement(String state) {
    return 'Speaker $state';
  }

  @override
  String get streamToggleOn => 'ON';

  @override
  String get streamToggleOff => 'OFF';

  @override
  String get appFieldSearchPlaceholder => 'Search…';

  @override
  String get appFieldClearSearch => 'Clear search';

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

  @override
  String setupWizardScreenStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get setupWizardScreenBack => 'Back';

  @override
  String get setupWizardScreenClose => 'Close';

  @override
  String get setupWizardScreenFinish => 'Finish';

  @override
  String get setupWizardScreenNext => 'Next';

  @override
  String get setupWizardScreenSpecTitle => '1. Detect specs';

  @override
  String get setupWizardScreenSpecReady =>
      'Your system is ready! A model is recommended based on its specs.';

  @override
  String get setupWizardScreenSpecChecking => 'Checking your system…';

  @override
  String get setupWizardScreenSpecCpu => 'CPU cores';

  @override
  String setupWizardScreenSpecCores(String cores) {
    return '$cores cores';
  }

  @override
  String get setupWizardScreenSpecRamEstimate => 'RAM (estimated)';

  @override
  String get setupWizardScreenSpecRam => 'RAM';

  @override
  String get setupWizardScreenSpecUnknown => 'unknown';

  @override
  String get setupWizardScreenSpecSuggestedModel => 'Suggested model';

  @override
  String get setupWizardScreenModelFastLabel => '⚡ Fast';

  @override
  String get setupWizardScreenModelFastDescription =>
      '142 MB · included with the app\nTranscripts appear quickly. Good for lighter computers and everyday notes.';

  @override
  String get setupWizardScreenModelFastExperimentalLabel =>
      '🧪 Fast (experimental)';

  @override
  String get setupWizardScreenModelFastExperimentalDescription =>
      '631 MB · one-time download\nAs accurate as the \"Accurate\" model but as quick as \"Fast\" (Qwen3-ASR). New, and not yet tested as thoroughly as the others.';

  @override
  String get setupWizardScreenModelBalancedLabel => '⚖️ Balanced';

  @override
  String get setupWizardScreenModelBalancedDescription =>
      '488 MB · one-time download\nMore precise than the fast model without the weight of the accurate one. A middle option for computers with moderate RAM.';

  @override
  String get setupWizardScreenModelAccurateLabel => '🎯 Accurate';

  @override
  String get setupWizardScreenModelAccurateDescription =>
      '548 MB · one-time download\nMore precise for meetings and interviews, but much slower on computers without a GPU.';

  @override
  String get setupWizardScreenModelAccurateExperimentalLabel =>
      '🧪 Accurate (experimental)';

  @override
  String get setupWizardScreenModelAccurateExperimentalDescription =>
      '1.5 GB · one-time download\nThe most precise model available (Qwen3-ASR). New, and not yet tested as thoroughly as the others.';

  @override
  String get setupWizardScreenModelTitle => '2. Choose a model';

  @override
  String get setupWizardScreenModelDescription =>
      'Choose the speech-to-text model that suits you.';

  @override
  String get setupWizardScreenModelAutoLabel => '🤖 Automatic (recommended)';

  @override
  String get setupWizardScreenModelAutoDescription =>
      'Picked automatically to suit this computer\'s specs.';

  @override
  String get setupWizardScreenLoopbackVirtualDriverFound =>
      'Virtual audio driver detected';

  @override
  String get setupWizardScreenLoopbackSystemAudioReady =>
      'System audio is ready to record';

  @override
  String get setupWizardScreenLoopbackVirtualDriverMissing =>
      'No virtual audio driver installed';

  @override
  String get setupWizardScreenLoopbackNoOutputDevice =>
      'No output device available to record';

  @override
  String get setupWizardScreenLoopbackReadyMacos =>
      'Audio from Zoom/Meet can be recorded through the virtual device above.';

  @override
  String get setupWizardScreenLoopbackReadyLinux =>
      'Trareon records system audio through a PipeWire/PulseAudio monitor sink. Nothing to install.';

  @override
  String get setupWizardScreenLoopbackReadyWindows =>
      'Trareon records system audio through WASAPI loopback. Nothing to install.';

  @override
  String get setupWizardScreenLoopbackMissingMacos =>
      'To record audio from Zoom/Meet on macOS, install BlackHole 2ch.';

  @override
  String get setupWizardScreenLoopbackMissingLinux =>
      'Choose an output device above. If the list is empty, make sure PipeWire or PulseAudio is running.';

  @override
  String get setupWizardScreenLoopbackMissingWindows =>
      'Choose an output device above. If the list is empty, make sure a playback device is enabled in Windows.';

  @override
  String get setupWizardScreenLoopbackGuideMacos =>
      '1. brew install blackhole-2ch\n2. Open Audio MIDI Setup\n3. Create a Multi-Output Device\n4. Tick your Mac speakers + BlackHole 2ch';

  @override
  String get setupWizardScreenLoopbackGuideLinux =>
      '1. Make sure PipeWire or PulseAudio is running\n2. Run: pactl list short sources\n3. Choose the source ending in .monitor in the list above';

  @override
  String get setupWizardScreenLoopbackGuideWindows =>
      '1. Open Windows Sound settings\n2. Make sure an output device is enabled\n3. Choose that device in the list above';

  @override
  String get setupWizardScreenAudioTitle => '3. Set up audio';

  @override
  String get setupWizardScreenAudioDescription =>
      'Choose your microphone and speakers.';

  @override
  String get setupWizardScreenMicLabel => 'Microphone (input)';

  @override
  String get setupWizardScreenSpeakerLabel =>
      'Speakers / system audio (output)';

  @override
  String get setupWizardScreenGuide => 'Guide';

  @override
  String get setupWizardScreenSystemDefault => 'System default';

  @override
  String get setupWizardScreenRemediationMacos =>
      'Open System Settings → Sound, turn the volume up, and make sure the right output device is selected.';

  @override
  String get setupWizardScreenRemediationLinux =>
      'Check the volume in pavucontrol or your desktop\'s sound settings, then make sure the right output device is selected.';

  @override
  String get setupWizardScreenRemediationWindows =>
      'Open Windows Sound settings, turn the volume up, and make sure the right output device is selected.';

  @override
  String get setupWizardScreenToneTitle => '4. Test sound';

  @override
  String get setupWizardScreenToneDescription =>
      'Play a 440 Hz tone to check that your speakers work.';

  @override
  String get setupWizardScreenToneQuestion => 'Did you hear the tone?';

  @override
  String get setupWizardScreenToneHeard => 'Yes, I heard it';

  @override
  String get setupWizardScreenToneNotHeard => 'No, I didn\'t';

  @override
  String get setupWizardScreenToneWorksTitle => 'Speakers are working';

  @override
  String get setupWizardScreenToneWorksBody =>
      'The microphone test runs when a session starts.';

  @override
  String get setupWizardScreenToneNotHeardTitle => 'Tone not heard';

  @override
  String get setupWizardScreenTonePlaybackFailed => 'The tone couldn\'t play';

  @override
  String get setupWizardScreenTonePlaying => 'Playing…';

  @override
  String get setupWizardScreenTonePlay => 'Play test tone';

  @override
  String get setupWizardScreenTonePlayAgain => 'Play again';

  @override
  String get srikandiExportDialogSifatSangatSegera => 'Top urgent (24 hours)';

  @override
  String get srikandiExportDialogSifatSegera => 'Urgent (2x24 hours)';

  @override
  String get srikandiExportDialogSifatBiasa => 'Routine';

  @override
  String get srikandiExportDialogKlasifikasiSangatRahasia => 'Top secret';

  @override
  String get srikandiExportDialogKlasifikasiRahasia => 'Secret';

  @override
  String get srikandiExportDialogKlasifikasiTerbatas => 'Restricted';

  @override
  String get srikandiExportDialogKlasifikasiBiasa => 'Unclassified';

  @override
  String get srikandiExportDialogTingkatAsli => 'Original';

  @override
  String get srikandiExportDialogTingkatSalinan => 'Copy';

  @override
  String get srikandiExportDialogTingkatTembusan => 'Carbon copy';

  @override
  String get srikandiExportDialogTingkatPertinggal => 'File copy';

  @override
  String srikandiExportDialogPrefillFailed(String error) {
    return 'Could not prepare the metadata: $error';
  }

  @override
  String get srikandiExportDialogMetadataIncomplete =>
      'The metadata is incomplete. Check the \"Required\" findings above.';

  @override
  String get srikandiExportDialogPickFolder =>
      'Choose a folder for the SRIKANDI export';

  @override
  String srikandiExportDialogExported(int count, String folder) {
    return '$count SRIKANDI-ready files saved to $folder';
  }

  @override
  String srikandiExportDialogExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get srikandiExportDialogTitle => 'SRIKANDI-ready export';

  @override
  String get srikandiExportDialogExporting => 'Exporting…';

  @override
  String get srikandiExportDialogExportButton => 'Export (4 files)';

  @override
  String get srikandiExportDialogIntro =>
      'The files are only prepared on this device. Uploading to SRIKANDI is still done by hand through your agency\'s interface (see docs/SRIKANDI-EXPORT.md).';

  @override
  String get srikandiExportDialogFieldNomor => 'Document number';

  @override
  String get srikandiExportDialogFieldTanggal => 'Date';

  @override
  String get srikandiExportDialogFieldJenisNaskah => 'Document type';

  @override
  String get srikandiExportDialogFieldPerihal => 'Subject';

  @override
  String get srikandiExportDialogFieldKodeKlasifikasiArsip =>
      'Archive classification code';

  @override
  String get srikandiExportDialogFieldUnitPengolah => 'Processing unit';

  @override
  String get srikandiExportDialogFieldPenandatanganNama => 'Signatory name';

  @override
  String get srikandiExportDialogFieldPenandatanganJabatan =>
      'Signatory position';

  @override
  String get srikandiExportDialogFieldJumlahLampiran => 'Number of attachments';

  @override
  String get srikandiExportDialogFieldCatatan => 'Notes';

  @override
  String get srikandiExportDialogNomorHint =>
      'Ask your unit\'s administration office, e.g. B-125/TU.01/KP.03/10/2026';

  @override
  String get srikandiExportDialogKodeHint =>
      'Ask your unit\'s archivist, e.g. UM.03.01';

  @override
  String get srikandiExportDialogGroupSifat => 'Urgency';

  @override
  String get srikandiExportDialogGroupKlasifikasi => 'Security classification';

  @override
  String get srikandiExportDialogGroupTingkat => 'Document stage';

  @override
  String get srikandiExportDialogGroupChecks => 'Metadata check';

  @override
  String get srikandiExportDialogWajib => 'Required';

  @override
  String get srikandiExportDialogSaran => 'Suggestion';

  @override
  String get sessionSidebarGroupToday => 'Today';

  @override
  String get sessionSidebarGroupYesterday => 'Yesterday';

  @override
  String get sessionSidebarGroupLast7Days => 'Last 7 days';

  @override
  String get sessionSidebarGroupOlder => 'Older';

  @override
  String get sessionSidebarNewSession => 'New session';

  @override
  String get sessionSidebarSearchPlaceholder => 'Search sessions…';

  @override
  String get sessionSidebarSearchSemanticLabel => 'Search session history';

  @override
  String get sessionSidebarAllTags => 'All';

  @override
  String get sessionSidebarImportFile => 'Import file';

  @override
  String get sessionSidebarAskArchive => 'Ask the meeting archive';

  @override
  String get sessionSidebarManageLibrary => 'Manage library';

  @override
  String get sessionSidebarSettings => 'Settings';

  @override
  String sessionSidebarHideSidebar(String shortcut) {
    return 'Hide sidebar ($shortcut)';
  }

  @override
  String sessionSidebarShowSidebar(String shortcut) {
    return 'Show sidebar ($shortcut)';
  }

  @override
  String get sessionSidebarNewSessionTooltip => 'New session';

  @override
  String get sessionSidebarHistoryTooltip => 'Session history';

  @override
  String get sessionSidebarRecording => 'Recording';

  @override
  String sessionSidebarSegments(int count) {
    return '$count segments';
  }

  @override
  String sessionSidebarFinishing(String source) {
    return 'Finishing $source';
  }

  @override
  String get sessionSidebarRetranscribeQueued =>
      'Waiting in the queue to be re-transcribed.';

  @override
  String sessionSidebarRetranscribingStage(String stage) {
    return 'Re-transcribing: $stage';
  }

  @override
  String get sessionSidebarRetranscribing => 'Re-transcribing';

  @override
  String get sessionSidebarHasSummary => 'Has summary';

  @override
  String get sessionSidebarFolderUnreadable =>
      'Can\'t read the sessions folder';

  @override
  String get sessionSidebarNoMatchTitle => 'No matches';

  @override
  String get sessionSidebarNoMatchMessage =>
      'Try another keyword or clear the tag filter.';

  @override
  String get sessionSidebarEmptyTitle => 'No sessions yet';

  @override
  String get sessionSidebarEmptyMessage => 'Recorded meetings appear here.';

  @override
  String get engineAssetsSectionVadTitle => 'Neural voice gate (Silero)';

  @override
  String get engineAssetsSectionVadSubtitle =>
      'Decides which parts of a recording contain human speech. Without it Trareon uses a simple energy detector, which sometimes lets room noise through, and Whisper answers noise with made-up sentences. 0.9 MB.';

  @override
  String get engineAssetsSectionSegmentationTitle =>
      'Speaker segmentation (pyannote 3.0)';

  @override
  String get engineAssetsSectionSegmentationSubtitle =>
      'Works out who spoke when. 6 MB.';

  @override
  String get engineAssetsSectionEmbeddingTitle => 'Speaker voiceprint (CAM++)';

  @override
  String get engineAssetsSectionEmbeddingSubtitle =>
      'Recognises the same voice across different parts of a recording. 28 MB.';

  @override
  String engineAssetsSectionInstalledToast(String name) {
    return '$name installed.';
  }

  @override
  String get engineAssetsSectionTitle => 'Speech engine';

  @override
  String get engineAssetsSectionDiarizationLabel =>
      'Accurate speaker separation';

  @override
  String engineAssetsSectionDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get engineAssetsSectionDiarizationOff =>
      'Off. Uses simple acoustic clustering, which is enough for two-source meetings (microphone = you, system = participants) but often splits one voice into several speakers in imported files.';

  @override
  String get engineAssetsSectionDiarizationIncomplete =>
      'On, but its models haven\'t finished downloading. Simple acoustic clustering is used in the meantime.';

  @override
  String get engineAssetsSectionDiarizationReady =>
      'pyannote segmentation + CAM++ voiceprints, entirely on this computer. Used for file imports, re-transcription and the finishing pass after Stop (not the live preview).';

  @override
  String engineAssetsSectionDownloadingPercent(String percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get engineAssetsSectionChecking => 'Checking…';

  @override
  String engineAssetsSectionInstalled(String description) {
    return 'Installed. $description';
  }

  @override
  String engineAssetsSectionNotDownloaded(String description) {
    return 'Not downloaded. $description';
  }

  @override
  String get engineAssetsSectionDownloading => 'Downloading…';

  @override
  String get engineAssetsSectionDownload => 'Download';

  @override
  String get privacyReportScreenTitle => 'Privacy Report';

  @override
  String privacyReportScreenNetworkCalls(int count) {
    return '$count network calls since the app opened';
  }

  @override
  String privacyReportScreenSessionRunning(String duration) {
    return 'Session running for $duration';
  }

  @override
  String get privacyReportScreenNoActivity =>
      'No network activity recorded yet.';

  @override
  String get privacyReportScreenHistory => 'Activity log:';

  @override
  String get privacyReportScreenExplanation =>
      'Trareon Transcribe makes no network calls at all while transcribing, whether recording live or importing a file. Audio never leaves this device.\n\nThere are four legitimate kinds of network activity, and you start all of them yourself:\n1. Whisper model download: from huggingface.co, only when you choose a model that isn\'t on this device yet.\n2. AI summary: sends the transcript text (not the audio) to an endpoint you set yourself. This feature is off by default and points to Ollama on this computer (localhost) by default, so even the default never leaves the device.\n3. Update check: fetches a single version file from raw.githubusercontent.com when you press \"Check for updates\". Nothing is downloaded or run automatically.\n4. \"View release\": opens the releases page in your browser.\n\nAll four are recorded in the log above, along with where they went. Every place in the code that can start one of them must record itself first, and this is tested automatically (test/privacy_proof_test.dart).';

  @override
  String privacyReportScreenDurationHours(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String privacyReportScreenDurationMinutes(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String privacyReportScreenDurationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String bookmarkBarAddTooltip(String shortcut) {
    return 'Mark an important point at the current position ($shortcut)';
  }

  @override
  String get recoveryDialogTitle => 'Recover an interrupted session';

  @override
  String recoveryDialogIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sessions stopped without being saved. Here is what they contain:',
      one: 'One session stopped without being saved. Here is what it contains:',
    );
    return '$_temp0';
  }

  @override
  String get recoveryDialogLater => 'Not now';

  @override
  String recoveryDialogSegments(int count) {
    return '$count transcript segments';
  }

  @override
  String get recoveryDialogEmptyTranscript => 'empty transcript';

  @override
  String recoveryDialogMic(String duration) {
    return 'microphone $duration';
  }

  @override
  String recoveryDialogSystemAudio(String duration) {
    return 'system audio $duration';
  }

  @override
  String get recoveryDialogNoAudio => 'no audio recorded';

  @override
  String recoveryDialogAudio(String sources) {
    return 'audio: $sources';
  }

  @override
  String get recoveryDialogDiscard => 'Delete';

  @override
  String get recoveryDialogRecoverTooltip =>
      'Continue this session and record into the same file';

  @override
  String get recoveryDialogBusyTooltip => 'Stop the session in progress first';

  @override
  String get recoveryDialogRecover => 'Recover';

  @override
  String get calendarInviteImportPickTitle => 'Import meeting invite (.ics)';

  @override
  String calendarInviteImportReadFailed(String error) {
    return 'Couldn\'t read the invite: $error';
  }

  @override
  String get calendarInviteImportNoEvents =>
      'No events could be read from that file.';

  @override
  String get calendarInviteImportConfirmTitle => 'Fill in from this invite?';

  @override
  String get calendarInviteImportNoTitle => 'This invite has no title.';

  @override
  String calendarInviteImportWillBeTitle(String summary) {
    return '\"$summary\" will become the session title.';
  }

  @override
  String get calendarInviteImportNo => 'No';

  @override
  String get calendarInviteImportFillTitle => 'Fill in title';

  @override
  String calendarInviteImportAttendees(String attendees) {
    return 'Attendees on the invite: $attendees';
  }

  @override
  String get archiveChatModelNotFound => 'Not found in the meeting archive.';

  @override
  String get archiveChatModelNeedsEndpoint =>
      'Automatic answers need a summary endpoint set up in Settings → AI summary. Archive search still works without it.';

  @override
  String updateCheckerBadStatus(int code) {
    return 'The server responded with code $code. Try again later.';
  }

  @override
  String get updateCheckerEmptyVersion =>
      'The version file is empty. Try again later.';

  @override
  String get updateCheckerNoConnection =>
      'Can\'t connect to the server. Check your internet connection.';

  @override
  String get updateCheckerBadResponse =>
      'The server didn\'t respond correctly. Try again later.';

  @override
  String get updateCheckerTimeout =>
      'The request timed out. Check your internet connection and try again.';

  @override
  String get updateCheckerInvalidData =>
      'The data received was invalid. Try again later.';

  @override
  String onboardingModelDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String shareFileUnsupported(String name) {
    return 'File sharing isn\'t supported on this platform. Path copied: $name';
  }

  @override
  String get preflightServiceTitleLibraryPath => 'Storage folder';

  @override
  String get preflightServicePurposeLibraryPath =>
      'Where recordings and transcripts are saved.';

  @override
  String get preflightServiceTitleModel => 'Transcription model';

  @override
  String get preflightServicePurposeModel =>
      'The model file used to turn speech into text.';

  @override
  String get preflightServiceTitleConfigDir => 'Settings folder';

  @override
  String get preflightServicePurposeConfigDir =>
      'Where the app\'s settings are saved.';

  @override
  String get preflightServiceTitleAudioInput => 'Microphone device';

  @override
  String get preflightServicePurposeAudioInput =>
      'The sound source for recording.';

  @override
  String get preflightServiceTitleDiskSpace => 'Disk space';

  @override
  String get preflightServicePurposeDiskSpace =>
      'A three-hour recording needs about 1.4 GB.';

  @override
  String get downloadConsentQuickModel => 'Fast model';

  @override
  String get downloadConsentAccurateModel => 'Accurate model';

  @override
  String get downloadConsentDialogTitle => 'Download the transcription models?';

  @override
  String get downloadConsentDialogDescription =>
      'Trareon works offline, so the models need to be on this device. You download them once, and the download is recorded in the Privacy Report.';

  @override
  String get downloadConsentDialogLater => 'Later';

  @override
  String get downloadConsentDialogDownloadNow => 'Download now';

  @override
  String downloadConsentDialogSize(int megabytes) {
    return '±$megabytes MB';
  }

  @override
  String get downloadConsentDialogTotal => 'Total';

  @override
  String get downloadConsentDialogDeferOnMetered =>
      'Wait when on a metered connection';

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
