import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/services/bridge_service.dart';

/// Leaks in [RustEngineBridge]'s own bookkeeping: both of these used to run
/// forever with nothing able to stop them.
void main() {
  group('stopSession', () {
    test(
      'tears down the Dart plumbing even when the engine stop throws',
      () async {
        final bridge = RustEngineBridge()
          ..stopEngineSession = (_) async =>
              throw StateError('session registry lock poisoned');
        bridge.openSessionStreamsForTest('s-1');
        expect(bridge.openStreamCount, 4);

        // The caller still learns the stop failed...
        await expectLater(
          bridge.stopSession('s-1'),
          throwsA(isA<StateError>()),
        );

        // ...but it no longer costs the cleanup. Before the `finally`, all
        // three StreamControllers and the 200 ms poll timer stayed open and
        // registered for the life of the app, with the UI still listening to
        // a session the engine had already dropped.
        expect(
          bridge.openStreamCount,
          0,
          reason:
              'controllers and poll timer must be gone whatever the engine did',
        );
      },
    );

    test('a successful stop tears everything down too', () async {
      final stopped = <String>[];
      final bridge = RustEngineBridge()
        ..stopEngineSession = (id) async => stopped.add(id);
      bridge.openSessionStreamsForTest('s-1');

      await bridge.stopSession('s-1');

      expect(stopped, ['s-1']);
      expect(bridge.openStreamCount, 0);
    });
  });

  group('pollDownloadProgress', () {
    test(
      'reports progress and closes itself when the download completes',
      () async {
        var polls = 0;
        final stream = pollDownloadProgress(() async {
          polls++;
          return (BigInt.from(polls * 50), BigInt.from(100));
        }, interval: const Duration(milliseconds: 1));

        expect(await stream.toList(), [0.5, 1.0]);
        // Closed by reaching 1.0, and the timer stopped with it.
        final after = polls;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(polls, after, reason: 'no polling after the stream closed');
      },
    );

    test('stops polling when the subscription is cancelled', () async {
      var polls = 0;
      // A stalled download: `total` is never known, so the ratio never
      // reaches 1.0 and nothing ever closes the stream on its own. This is
      // the shape that leaked.
      final stream = pollDownloadProgress(() async {
        polls++;
        return (BigInt.zero, BigInt.zero);
      }, interval: const Duration(milliseconds: 1));

      final sub = stream.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(polls, greaterThan(0), reason: 'precondition: it was polling');
      await sub.cancel();

      final atCancel = polls;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        polls,
        atCancel,
        reason: 'a cancelled download must not keep calling into Rust forever',
      );
    });

    test('a null reading is skipped without ending the stream', () async {
      var polls = 0;
      final stream = pollDownloadProgress(() async {
        polls++;
        // Nothing started yet, then real progress.
        if (polls < 3) return null;
        return (BigInt.from(100), BigInt.from(100));
      }, interval: const Duration(milliseconds: 1));

      expect(await stream.toList(), [1.0]);
    });
  });
}
