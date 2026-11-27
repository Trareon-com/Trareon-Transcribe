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
}
