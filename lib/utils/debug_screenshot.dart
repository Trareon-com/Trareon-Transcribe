/// Periodic screenshot hook for remote smoke testing (Sprint 12, A8).
///
/// A screen-sharing-free way to see what a build actually did on a machine
/// this agent cannot look at directly — in particular a sandboxed macOS
/// build, where the usual "take a screenshot and scp it" trick needs to
/// know exactly where inside the sandbox container a file can land.
///
/// Disabled by construction unless `TRAREON_SCREENSHOT_DIR` is set: without
/// the env var, [wrapForDebugScreenshot] returns `child` untouched, so a
/// normal run pays nothing for this — no `RepaintBoundary`, no timer, no
/// extra frame work.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Directory screenshots are written into, or `null` when the hook is off.
///
/// Read once at call time (not cached at import time) so a test can set the
/// environment and exercise this without a process restart being possible
/// — `Platform.environment` itself is what is actually read in production.
String? _screenshotDir() => Platform.environment['TRAREON_SCREENSHOT_DIR'];

/// Longest a periodic capture loop will run before giving up on its own —
/// a smoke test that forgot to stop capturing must not grow a container
/// directory forever.
const int maxScreenshots = 120;

const Duration screenshotInterval = Duration(seconds: 2);

/// Wraps [child] in a [RepaintBoundary] and starts writing a PNG of it to
/// [dirPath] (or `TRAREON_SCREENSHOT_DIR` when [dirPath] is omitted) every
/// [screenshotInterval], up to [maxScreenshots] times, as soon as the
/// returned widget is first laid out.
///
/// On macOS the app runs inside its sandbox container, so `dirPath` must be
/// a path this process can actually write to — typically somewhere under
/// `~/Library/Containers/com.trareon.transcribe/Data/tmp/`. This function
/// does not create that directory; whatever launches the app with the env
/// var set is responsible for making sure it exists.
Widget wrapForDebugScreenshot(Widget child, {String? dirPath}) {
  final dir = dirPath ?? _screenshotDir();
  if (dir == null || dir.isEmpty) return child;
  return _DebugScreenshotBoundary(dir: dir, child: child);
}

class _DebugScreenshotBoundary extends StatefulWidget {
  const _DebugScreenshotBoundary({required this.dir, required this.child});

  final String dir;
  final Widget child;

  @override
  State<_DebugScreenshotBoundary> createState() =>
      _DebugScreenshotBoundaryState();
}

class _DebugScreenshotBoundaryState extends State<_DebugScreenshotBoundary> {
  final GlobalKey _boundaryKey = GlobalKey();
  Timer? _timer;
  int _taken = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(screenshotInterval, (_) => _capture());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_taken >= maxScreenshots) {
      _timer?.cancel();
      return;
    }
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;
    try {
      await captureBoundaryToFile(boundary, widget.dir, _taken);
      _taken += 1;
    } catch (e) {
      // A capture failure (e.g. the container directory disappeared) must
      // never crash the app it is only here to observe.
      debugPrint('debug_screenshot: capture failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: _boundaryKey, child: widget.child);
  }
}

/// Renders `boundary` to a PNG and writes it into `dir`. Exposed (not
/// private) so a test can exercise one capture directly, without going
/// through the widget's real [Timer] — a periodic timer inside a widget
/// test easily outlives the test body and hangs the suite.
@visibleForTesting
Future<void> captureBoundaryToFile(
  RenderRepaintBoundary boundary,
  String dir,
  int index,
) async {
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  await _writeAtomically(dir, index, bytes.buffer.asUint8List());
}

/// Writes `bytes` as `shot-<index>.png` under `dir` via temp-file-then-rename
/// in the same directory, so a reader scp-ing the directory mid-write never
/// sees a half-written PNG.
Future<void> _writeAtomically(String dir, int index, List<int> bytes) async {
  final directory = Directory(dir);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final name = 'shot-${index.toString().padLeft(4, '0')}.png';
  final target = File('$dir/$name');
  final temp = File('$dir/.$name.tmp');
  await temp.writeAsBytes(bytes, flush: true);
  await temp.rename(target.path);
}
