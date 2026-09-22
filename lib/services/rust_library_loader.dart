import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

/// Resolves the compiled `rust_core` native library.
///
/// This is a stand-in for proper build-system wiring (an Xcode "Run
/// Script" build phase on macOS, a CMake step on Windows — what
/// `flutter_rust_bridge_codegen integrate`'s cargokit machinery normally
/// automates). That command is destructive against this project's
/// existing structure (see ARCHITECTURE.md), so the native build phase
/// hasn't been added yet; hand-editing the generated Xcode project file
/// blindly is riskier than shipping this explicit-path loader for now.
///
/// Search order:
/// 1. Next to the running executable's `Frameworks/` folder (the eventual
///    packaged location once a real build phase copies the library in).
/// 2. `rust_core/target/{release,debug}/` relative to the repo root — for
///    `flutter run`/`flutter test` during development, where `cargo build`
///    output already exists but nothing has copied it into a bundle.
ExternalLibrary? tryLoadRustCoreLibrary() {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return null; // mobile/web aren't targeted per the project blueprint
  }

  final libraryFileName = switch (Platform.operatingSystem) {
    'macos' => 'librust_core.dylib',
    'windows' => 'rust_core.dll',
    _ => 'librust_core.so',
  };

  final candidates = <String>[
    _bundledFrameworksPath(libraryFileName),
    // Dev build output paths can't exist in a release bundle, so skip the
    // disk-check sweep entirely there.
    if (!kReleaseMode) ..._devBuildOutputPaths(libraryFileName),
  ];

  for (final path in candidates) {
    if (File(path).existsSync()) {
      return ExternalLibrary.open(path);
    }
  }
  return null;
}

String _bundledFrameworksPath(String libraryFileName) {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  if (Platform.isMacOS) {
    return '$exeDir/../Frameworks/$libraryFileName';
  }
  return '$exeDir/$libraryFileName';
}

List<String> _devBuildOutputPaths(String libraryFileName) {
  // Walk up from the executable looking for a `rust_core/target` directory
  // — works for `flutter run` (exe under build/{platform}/.../Debug) without
  // hardcoding a repo-root assumption.
  var dir = File(Platform.resolvedExecutable).parent;
  final paths = <String>[];
  for (var i = 0; i < 14; i++) {
    for (final profile in ['release', 'debug']) {
      paths.add('${dir.path}/rust_core/target/$profile/$libraryFileName');
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return paths;
}
