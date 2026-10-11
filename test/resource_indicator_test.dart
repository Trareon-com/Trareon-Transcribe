/// Sprint 15 F23: the memory-pressure corner pill on the recording screen.
///
/// The ratio computation itself is Rust and already unit-tested in
/// `rust_core/src/memory.rs`. What this covers is the Dart side: the
/// indicator renders nothing when memory is normal, and shows the
/// qualitative "Tinggi" pill — never a raw percentage — when it isn't.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/widgets/resource_indicator.dart';

import 'test_helpers.dart';

class _FixedMemoryBridge extends NoopBridge {
  _FixedMemoryBridge(this.ratio);
  final double ratio;

  @override
  Future<double> systemMemoryUsageRatio() async => ratio;

  @override
  Future<bool> isMemoryUsageHigh(double r) async => r >= 0.8;
}

void main() {
  testWidgets('renders nothing when memory usage is normal', (tester) async {
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          rustBridgeProvider.overrideWithValue(_FixedMemoryBridge(0.4)),
        ],
        child: const Scaffold(body: ResourceIndicator()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ResourceIndicator), findsOneWidget);
    expect(find.textContaining('Tinggi'), findsNothing);
  });

  testWidgets('shows a qualitative warning, never a raw number, when high', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestAppWithOverrides(
        overrides: [
          rustBridgeProvider.overrideWithValue(_FixedMemoryBridge(0.92)),
        ],
        child: const Scaffold(body: ResourceIndicator()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Tinggi'), findsOneWidget);
    expect(find.textContaining('92'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });
}
