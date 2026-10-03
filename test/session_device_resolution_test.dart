import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;

import 'test_helpers.dart';

class _DeviceListBridge extends NoopBridge {
  _DeviceListBridge(this._inputs, {List<rust_device.AudioDeviceInfo>? outputs})
    : _outputs = outputs ?? const [];

  final List<rust_device.AudioDeviceInfo> _inputs;
  final List<rust_device.AudioDeviceInfo> _outputs;
  SessionConfig? capturedConfig;

  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => _inputs;

  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async =>
      _outputs;

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

  test('no speaker device is guessed, so the engine resolves system audio itself', () async {
    // The old heuristic picked the first "blackhole"/"loopback"-looking
    // output and otherwise outputs.first. A concrete name here makes macOS
    // skip ScreenCaptureKit and try to open a *playback* device as a
    // capture source, and hands Linux a sink name that is not a monitor —
    // which is how "Audio sistem" came back empty or as the microphone.
    final bridge = _DeviceListBridge(
      [_device('MacBook Pro Microphone', isDefault: true)],
      outputs: [_device('MacBook Pro Speakers', isDefault: true)],
    );
    final notifier = SessionNotifier(bridge, SessionMode.webinar, 'models/ggml-base.bin');

    await notifier.start();

    expect(notifier.state.config.speakerEnabled, isTrue, reason: 'precondition');
    expect(bridge.capturedConfig?.speakerDeviceId, isNull);
  });

  test('a speaker device the user did choose is passed through untouched', () async {
    final bridge = _DeviceListBridge(
      [_device('MacBook Pro Microphone', isDefault: true)],
      outputs: [_device('MacBook Pro Speakers', isDefault: true)],
    );
    final notifier = SessionNotifier(bridge, SessionMode.webinar, 'models/ggml-base.bin');
    // How a real choice arrives: the setup wizard writes it to settings.
    notifier.syncDefaultSettings(
      AppSettings.defaults().copyWith(
        defaultMode: SessionMode.webinar,
        speakerDeviceId: 'BlackHole 2ch',
      ),
    );

    await notifier.start();

    expect(bridge.capturedConfig?.speakerDeviceId, 'BlackHole 2ch');
  });
}
