/// Sprint 13 B7: the non-blocking low-quality/Bluetooth mic advisory.
/// The actual decision logic (`mic_quality_advisory`) is Rust and tested
/// with the fixtures the brief asked for in
/// `rust_core/src/audio/device.rs`. What this covers is the Dart side:
/// that the banner never crashes the screen (no device selected, or no
/// native engine to ask — e.g. in a widget test).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/widgets/session_controls.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('renders nothing when no mic device is selected yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: const Scaffold(body: MicQualityBanner(device: null)),
      ),
    );
    await tester.pump();

    expect(find.byType(MicQualityBanner), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MicQualityBanner),
        matching: find.byType(Material),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'does not crash the screen when the engine call fails (no native lib '
    'in a widget test)',
    (tester) async {
      final device = rust_device.AudioDeviceInfo(
        name: 'bluez_input.AA_BB_CC_DD_EE_FF',
        deviceId: 'bluez_input.AA_BB_CC_DD_EE_FF',
        isDefault: true,
        channels: 1,
        sampleRates: Uint32List.fromList([]),
      );
      await tester.pumpWidget(
        buildTestApp(child: Scaffold(body: MicQualityBanner(device: device))),
      );
      await tester.pump();

      // No engine available in the test binary, so the advisory call
      // throws and the banner falls back to showing nothing — the point
      // being that it falls back rather than crashing the build.
      expect(find.byType(MicQualityBanner), findsOneWidget);
    },
  );
}
