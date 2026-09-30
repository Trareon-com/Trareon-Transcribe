import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'session_model.dart';
import 'settings_model.dart';

/// Streams VU levels for the currently active session; auto-disposes its
/// subscription when the widget tree stops watching it.
final vuLevelProvider = StreamProvider<VuLevel>((ref) {
  final bridge = ref.watch(rustBridgeProvider);
  final sessionId = ref.watch(sessionProvider).sessionId;
  if (sessionId == null) {
    return const Stream<VuLevel>.empty();
  }
  return bridge.vuMeterStream(sessionId);
});

/// Capture problems the engine reports for the active session (a source that
/// couldn't be opened, or one that died mid-recording). The UI shows each as
/// a toast — see `main_screen.dart`.
final sessionNoticeProvider = StreamProvider<SessionNotice>((ref) {
  final bridge = ref.watch(rustBridgeProvider);
  final sessionId = ref.watch(sessionProvider).sessionId;
  if (sessionId == null) {
    return const Stream<SessionNotice>.empty();
  }
  return bridge.noticeStream(sessionId);
});
