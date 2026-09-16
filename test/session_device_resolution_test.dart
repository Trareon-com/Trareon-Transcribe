import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;

import 'test_helpers.dart';

class _DeviceListBridge extends NoopBridge {
  _DeviceListBridge(this._inputs);

  final List<rust_device.AudioDeviceInfo> _inputs;
  SessionConfig? capturedConfig;

  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => _inputs;

  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async => const [];

  @override
  Future<String> startSession(SessionConfig config) async {
    capturedConfig = config;
    return 'test-session';
  }
}

rust_device.AudioDeviceInfo _device(String name, {bool isDefault = false}) {
  return rust_device.AudioDeviceInfo(
    name: name,
    deviceId: name,
    isDefault: isDefault,
    channels: 1,
    sampleRates: Uint32List.fromList([16000]),
  );
}

void main() {
  test('mic auto-selection prefers the OS default device, not just the first in the list', () async {
    // BlackHole (or any other virtual/loopback input) enumerating before
    // the real microphone used to make the app silently record from it
    // instead — see session_model.dart _resolveDevices.
    final bridge = _DeviceListBridge([
      _device('BlackHole 2ch'),
      _device('MacBook Pro Microphone', isDefault: true),
    ]);
    final notifier = SessionNotifier(bridge, SessionMode.offline, 'models/ggml-base.bin');

    await notifier.start();

    expect(bridge.capturedConfig?.micDeviceId, 'MacBook Pro Microphone');
  });

  test('mic auto-selection falls back to the first device when none is marked default', () async {
    final bridge = _DeviceListBridge([_device('Some Input A'), _device('Some Input B')]);
    final notifier = SessionNotifier(bridge, SessionMode.offline, 'models/ggml-base.bin');

    await notifier.start();

    expect(bridge.capturedConfig?.micDeviceId, 'Some Input A');
  });
}
