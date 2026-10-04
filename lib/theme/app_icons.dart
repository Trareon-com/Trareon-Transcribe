/// The app's single icon vocabulary.
///
/// One family: Material Symbols Rounded, reached through the glyphs Flutter
/// already bundles (`Icons.*_rounded`). No second icon package, and no
/// hand-rolled SVG paths, which `design-taste-frontend` §9.E bans outright.
///
/// Names are **semantic**, not visual: `AppIcons.record`, not
/// `Icons.fiber_manual_record`. A glyph can then be swapped once here
/// instead of with a sweep through forty files. Before this existed the app
/// mixed `_outlined`, `_rounded`, filled and bare glyphs from 142 different
/// Material entries, sometimes two variants in the same row.
///
/// `Icons.` is banned everywhere else in `lib/`; `test/design_lint_test.dart`
/// fails the build on it. See `docs/DESIGN-SYSTEM.md` §5.
library;

import 'package:flutter/material.dart';

abstract final class AppIcons {
  static const IconData accurate = Icons.my_location_rounded;

  static const IconData add = Icons.add_rounded;

  static const IconData analytics = Icons.analytics_rounded;

  static const IconData announce = Icons.campaign_rounded;

  static const IconData appearance = Icons.palette_rounded;

  static const IconData arrowRight = Icons.arrow_forward_rounded;

  static const IconData article = Icons.article_rounded;

  static const IconData audioTrack = Icons.audiotrack_rounded;

  static const IconData autoFix = Icons.auto_fix_high_rounded;

  static const IconData avatar = Icons.person_rounded;

  static const IconData back = Icons.arrow_back_ios_new_rounded;

  static const IconData block = Icons.block_rounded;

  static const IconData bookmark = Icons.bookmark_rounded;

  static const IconData bookmarkAdd = Icons.bookmark_add_rounded;

  static const IconData bookmarkFilled = Icons.bookmark_rounded;

  static const IconData bugReport = Icons.bug_report_rounded;

  static const IconData calendar = Icons.calendar_today_rounded;

  static const IconData cancel = Icons.cancel_rounded;

  static const IconData captions = Icons.closed_caption_rounded;

  static const IconData chat = Icons.forum_rounded;

  static const IconData check = Icons.check_circle_rounded;

  /// Replaces `Icons.check_circle`, `Icons.check_circle_rounded`.
  static const IconData checkFilled = Icons.check_circle_rounded;

  static const IconData checkPlain = Icons.check_rounded;

  static const IconData checklist = Icons.checklist_rounded;

  static const IconData chevronDown = Icons.keyboard_arrow_down_rounded;

  static const IconData chevronLeft = Icons.chevron_left_rounded;

  static const IconData chevronRight = Icons.chevron_right_rounded;

  static const IconData chevronUp = Icons.keyboard_arrow_up_rounded;

  /// Replaces `Icons.memory`, `Icons.memory_outlined`.
  static const IconData chip = Icons.memory_rounded;

  static const IconData clear = Icons.clear_rounded;

  static const IconData clearAll = Icons.clear_all_rounded;

  /// Replaces `Icons.access_time`, `Icons.schedule`, `Icons.schedule_outlined`.
  static const IconData clock = Icons.access_time_rounded;

  static const IconData close = Icons.close_rounded;

  static const IconData cloud = Icons.cloud_rounded;

  static const IconData cloudDownload = Icons.cloud_download_rounded;

  static const IconData cloudUpload = Icons.cloud_upload_rounded;

  /// Replaces `Icons.computer`, `Icons.computer_outlined`.
  static const IconData computer = Icons.computer_rounded;

  static const IconData copy = Icons.copy_rounded;

  static const IconData delete = Icons.delete_rounded;

  static const IconData deleteSweep = Icons.delete_sweep_rounded;

  static const IconData document = Icons.description_rounded;

  static const IconData dot = Icons.fiber_manual_record_rounded;

  static const IconData dotFilled = Icons.fiber_manual_record_rounded;

  static const IconData download = Icons.download_rounded;

  static const IconData downloading = Icons.downloading_rounded;

  static const IconData edit = Icons.edit_rounded;

  static const IconData editNote = Icons.edit_note_rounded;

  /// Replaces `Icons.auto_awesome`, `Icons.auto_awesome_outlined`.
  static const IconData enhance = Icons.auto_awesome_rounded;

  static const IconData enhanceQueue = Icons.auto_awesome_motion_rounded;

  static const IconData error = Icons.error_rounded;

  static const IconData errorFilled = Icons.error_rounded;

  static const IconData event = Icons.event_rounded;

  static const IconData expandLess = Icons.expand_less_rounded;

  static const IconData expandMore = Icons.expand_more_rounded;

  static const IconData factCheck = Icons.fact_check_rounded;

  static const IconData fileDownload = Icons.file_download_rounded;

  static const IconData fileUpload = Icons.file_upload_rounded;

  static const IconData filter = Icons.filter_list_rounded;

  static const IconData flag = Icons.flag_rounded;

  static const IconData flagFilled = Icons.flag_rounded;

  static const IconData folder = Icons.folder_rounded;

  static const IconData folderAdd = Icons.create_new_folder_rounded;

  static const IconData folderDelete = Icons.folder_delete_rounded;

  static const IconData folderOpen = Icons.folder_open_rounded;

  static const IconData forward10 = Icons.forward_10_rounded;

  static const IconData glossary = Icons.menu_book_rounded;

  static const IconData guide = Icons.assistant_direction_rounded;

  static const IconData health = Icons.health_and_safety_rounded;

  static const IconData help = Icons.help_rounded;

  static const IconData hide = Icons.visibility_off_rounded;

  static const IconData hierarchy = Icons.account_tree_rounded;

  static const IconData history = Icons.history_rounded;

  static const IconData idea = Icons.lightbulb_rounded;

  static const IconData image = Icons.image_rounded;

  /// Replaces `Icons.info_outline`, `Icons.info_outlined`.
  static const IconData info = Icons.info_rounded;

  static const IconData institution = Icons.account_balance_rounded;

  static const IconData json = Icons.data_object_rounded;

  static const IconData keyboard = Icons.keyboard_rounded;

  static const IconData language = Icons.language_rounded;

  static const IconData link = Icons.link_rounded;

  static const IconData locate = Icons.my_location_rounded;

  static const IconData lock = Icons.lock_outline_rounded;

  static const IconData maximize = Icons.crop_square_rounded;

  static const IconData meetingRoom = Icons.meeting_room_rounded;

  static const IconData menu = Icons.menu_rounded;

  static const IconData merge = Icons.merge_rounded;

  /// Replaces `Icons.mic`, `Icons.mic_none_outlined`, `Icons.mic_outlined`.
  static const IconData mic = Icons.mic_rounded;

  static const IconData minimize = Icons.remove_rounded;

  /// Replaces `Icons.psychology`, `Icons.psychology_outlined`.
  static const IconData model = Icons.psychology_rounded;

  static const IconData moon = Icons.dark_mode_rounded;

  static const IconData more = Icons.more_horiz_rounded;

  static const IconData moreVertical = Icons.more_vert_rounded;

  static const IconData noise = Icons.noise_control_off_rounded;

  static const IconData noteAdd = Icons.note_add_rounded;

  static const IconData offline = Icons.location_disabled_rounded;

  static const IconData offlineBadge = Icons.wifi_off_rounded;

  static const IconData open = Icons.open_in_new_rounded;

  static const IconData pause = Icons.pause_circle_rounded;

  static const IconData pauseFilled = Icons.pause_circle_rounded;

  static const IconData pdf = Icons.picture_as_pdf_rounded;

  static const IconData people = Icons.people_rounded;

  static const IconData play = Icons.play_arrow_rounded;

  static const IconData playCircle = Icons.play_circle_rounded;

  static const IconData playFilled = Icons.play_circle_rounded;

  static const IconData privacy = Icons.privacy_tip_rounded;

  static const IconData quick = Icons.bolt_rounded;

  static const IconData quote = Icons.format_quote_rounded;

  static const IconData radioOff = Icons.radio_button_off_rounded;

  static const IconData record = Icons.fiber_manual_record_rounded;

  static const IconData refresh = Icons.refresh_rounded;

  static const IconData rename = Icons.drive_file_rename_outline_rounded;

  static const IconData replay10 = Icons.replay_10_rounded;

  static const IconData report = Icons.report_gmailerrorred_rounded;

  /// Replaces `Icons.restore`, `Icons.restore_outlined`.
  static const IconData restore = Icons.restore_rounded;

  static const IconData restoreWindow = Icons.filter_none_rounded;

  static const IconData save = Icons.save_rounded;

  static const IconData saveAs = Icons.save_alt_rounded;

  static const IconData scrollToBottom = Icons.vertical_align_bottom_rounded;

  static const IconData search = Icons.search_rounded;

  static const IconData searchOff = Icons.search_off_rounded;

  static const IconData segments = Icons.chat_bubble_rounded;

  static const IconData settings = Icons.settings_rounded;

  static const IconData shield = Icons.shield_outlined;

  static const IconData shortText = Icons.short_text_rounded;

  static const IconData show = Icons.visibility_rounded;

  static const IconData sidebarCollapse =
      Icons.keyboard_double_arrow_left_rounded;

  static const IconData sidebarExpand =
      Icons.keyboard_double_arrow_right_rounded;

  static const IconData sort = Icons.swap_vert_rounded;

  static const IconData spatialAudio = Icons.spatial_audio_rounded;

  static const IconData speakers = Icons.speaker_group_rounded;

  static const IconData speed = Icons.speed_rounded;

  static const IconData stop = Icons.stop_rounded;

  static const IconData stopCircle = Icons.stop_circle_rounded;

  static const IconData storage = Icons.storage_rounded;

  static const IconData sun = Icons.light_mode_rounded;

  static const IconData system = Icons.brightness_auto_rounded;

  static const IconData systemAudio = Icons.volume_up_rounded;

  static const IconData table = Icons.table_view_rounded;

  static const IconData tag = Icons.label_rounded;

  static const IconData textSnippet = Icons.text_snippet_rounded;

  static const IconData timer = Icons.timer_rounded;

  static const IconData timer10 = Icons.timer_10_rounded;

  static const IconData todayGroup = Icons.today_rounded;

  static const IconData translate = Icons.translate_rounded;

  static const IconData tune = Icons.tune_rounded;

  static const IconData undo = Icons.undo_rounded;

  static const IconData update = Icons.system_update_alt_rounded;

  static const IconData upload = Icons.upload_rounded;

  static const IconData uploadFile = Icons.upload_file_rounded;

  static const IconData verified = Icons.verified_rounded;

  static const IconData verifiedUser = Icons.verified_user_rounded;

  static const IconData volumeOff = Icons.volume_off_rounded;

  static const IconData waiting = Icons.hourglass_empty_rounded;

  /// Replaces `Icons.warning_amber_outlined`, `Icons.warning_amber_rounded`.
  static const IconData warning = Icons.warning_amber_rounded;

  /// Replaces `Icons.graphic_eq`, `Icons.graphic_eq_outlined`.
  static const IconData waveform = Icons.graphic_eq_rounded;

  static const IconData web = Icons.web_rounded;

  /// Every glyph in the vocabulary, keyed by its semantic name. Used by
  /// the design-system gallery golden and by the lint test, which asserts
  /// the set is non-empty so it cannot pass vacuously.
  static const Map<String, IconData> all = {
    'accurate': accurate,
    'add': add,
    'analytics': analytics,
    'announce': announce,
    'appearance': appearance,
    'arrowRight': arrowRight,
    'article': article,
    'audioTrack': audioTrack,
    'autoFix': autoFix,
    'avatar': avatar,
    'back': back,
    'block': block,
    'bookmark': bookmark,
    'bookmarkAdd': bookmarkAdd,
    'bookmarkFilled': bookmarkFilled,
    'bugReport': bugReport,
    'calendar': calendar,
    'cancel': cancel,
    'captions': captions,
    'chat': chat,
    'check': check,
    'checkFilled': checkFilled,
    'checkPlain': checkPlain,
    'checklist': checklist,
    'chevronDown': chevronDown,
    'chevronLeft': chevronLeft,
    'chevronRight': chevronRight,
    'chevronUp': chevronUp,
    'chip': chip,
    'clear': clear,
    'clearAll': clearAll,
    'clock': clock,
    'close': close,
    'cloud': cloud,
    'cloudDownload': cloudDownload,
    'cloudUpload': cloudUpload,
    'computer': computer,
    'copy': copy,
    'delete': delete,
    'deleteSweep': deleteSweep,
    'document': document,
    'dot': dot,
    'dotFilled': dotFilled,
    'download': download,
    'downloading': downloading,
    'edit': edit,
    'editNote': editNote,
    'enhance': enhance,
    'enhanceQueue': enhanceQueue,
    'error': error,
    'errorFilled': errorFilled,
    'event': event,
    'expandLess': expandLess,
    'expandMore': expandMore,
    'factCheck': factCheck,
    'fileDownload': fileDownload,
    'fileUpload': fileUpload,
    'filter': filter,
    'flag': flag,
    'flagFilled': flagFilled,
    'folder': folder,
    'folderAdd': folderAdd,
    'folderDelete': folderDelete,
    'folderOpen': folderOpen,
    'forward10': forward10,
    'glossary': glossary,
    'guide': guide,
    'health': health,
    'help': help,
    'hide': hide,
    'hierarchy': hierarchy,
    'history': history,
    'idea': idea,
    'image': image,
    'info': info,
    'institution': institution,
    'json': json,
    'keyboard': keyboard,
    'language': language,
    'link': link,
    'locate': locate,
    'lock': lock,
    'maximize': maximize,
    'meetingRoom': meetingRoom,
    'menu': menu,
    'merge': merge,
    'mic': mic,
    'minimize': minimize,
    'model': model,
    'moon': moon,
    'more': more,
    'moreVertical': moreVertical,
    'noise': noise,
    'noteAdd': noteAdd,
    'offline': offline,
    'offlineBadge': offlineBadge,
    'open': open,
    'pause': pause,
    'pauseFilled': pauseFilled,
    'pdf': pdf,
    'people': people,
    'play': play,
    'playCircle': playCircle,
    'playFilled': playFilled,
    'privacy': privacy,
    'quick': quick,
    'quote': quote,
    'radioOff': radioOff,
    'record': record,
    'refresh': refresh,
    'rename': rename,
    'replay10': replay10,
    'report': report,
    'restore': restore,
    'restoreWindow': restoreWindow,
    'save': save,
    'saveAs': saveAs,
    'scrollToBottom': scrollToBottom,
    'search': search,
    'searchOff': searchOff,
    'segments': segments,
    'settings': settings,
    'shield': shield,
    'shortText': shortText,
    'show': show,
    'sidebarCollapse': sidebarCollapse,
    'sidebarExpand': sidebarExpand,
    'sort': sort,
    'spatialAudio': spatialAudio,
    'speakers': speakers,
    'speed': speed,
    'stop': stop,
    'stopCircle': stopCircle,
    'storage': storage,
    'sun': sun,
    'system': system,
    'systemAudio': systemAudio,
    'table': table,
    'tag': tag,
    'textSnippet': textSnippet,
    'timer': timer,
    'timer10': timer10,
    'todayGroup': todayGroup,
    'translate': translate,
    'tune': tune,
    'undo': undo,
    'update': update,
    'upload': upload,
    'uploadFile': uploadFile,
    'verified': verified,
    'verifiedUser': verifiedUser,
    'volumeOff': volumeOff,
    'waiting': waiting,
    'warning': warning,
    'waveform': waveform,
    'web': web,
  };
}
