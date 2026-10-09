import 'dart:io';

import 'package:flutter/material.dart';
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

  test('given a directory the hook returns a different widget', () {
    // Deliberately not mounted via `pumpWidget`: the wrapper's State starts
    // a real `Timer.periodic`, and a live Timer — however long its period —
    // keeps `flutter test`'s isolate from quiescing cleanly between tests.
    // The wrapping behaviour itself (does it produce a new widget, rather
    // than the identical `child`) is checkable without ever mounting it.
    const child = SizedBox(key: Key('probe'));
    final wrapped = wrapForDebugScreenshot(child, dirPath: '/tmp/unused');
    expect(wrapped, isNot(same(child)));
  });

  test('a write lands the final file with no .tmp left behind', () async {
    final dir = await Directory.systemTemp.createTemp('trareon_shot_test');
    addTearDown(() => dir.delete(recursive: true));

    await writeScreenshotAtomically(dir.path, 0, const [1, 2, 3, 4]);

    final entries = dir.listSync().whereType<File>().toList();
    expect(
      entries.map((f) => f.path.split('/').last),
      contains('shot-0000.png'),
    );
    expect(entries.any((f) => f.path.endsWith('.tmp')), isFalse);
    expect(
      await File('${dir.path}/shot-0000.png').readAsBytes(),
      [1, 2, 3, 4],
    );
  });

  test('indices are padded so filenames sort in capture order', () async {
    final dir = await Directory.systemTemp.createTemp('trareon_shot_test');
    addTearDown(() => dir.delete(recursive: true));

    await writeScreenshotAtomically(dir.path, 7, const [0]);

    expect(await File('${dir.path}/shot-0007.png').exists(), isTrue);
  });
}
