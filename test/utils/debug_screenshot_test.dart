import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/utils/debug_screenshot.dart';

void main() {
  testWidgets('without a directory the hook is a pass-through', (
    tester,
  ) async {
    const child = SizedBox(key: Key('probe'));
    final wrapped = wrapForDebugScreenshot(child);
    expect(wrapped, same(child));
    await tester.pumpWidget(wrapped);
    expect(find.byType(RepaintBoundary), findsNothing);
  });

  testWidgets('given a directory the hook wraps in a RepaintBoundary', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('trareon_shot_test');
    addTearDown(() => dir.delete(recursive: true));

    final wrapped = wrapForDebugScreenshot(
      const SizedBox(key: Key('probe')),
      dirPath: dir.path,
    );
    await tester.pumpWidget(wrapped);
    expect(find.byType(RepaintBoundary), findsOneWidget);
    // Unmount before the test ends: the widget's internal Timer.periodic
    // must be cancelled in dispose(), or a real periodic timer outlives
    // the test body and the suite hangs waiting for it.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a capture writes a PNG into the directory atomically', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('trareon_shot_test');
    addTearDown(() => dir.delete(recursive: true));
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(key: key, child: const ColoredBox(color: Colors.blue)),
      ),
    );

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() => captureBoundaryToFile(boundary, dir.path, 0));

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList();
    expect(files, isNotEmpty, reason: 'expected at least one PNG written');
    final tmpFiles = dir.listSync().where((f) => f.path.endsWith('.tmp'));
    expect(tmpFiles, isEmpty);
  });
}
