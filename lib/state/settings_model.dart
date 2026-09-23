import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../services/bridge_service.dart';
import '../services/dart_prefs.dart';
import 'models.dart';

final rustBridgeProvider = Provider<RustBridge>((ref) => RustEngineBridge());

class SettingsNotifier extends StateNotifier<AppSettings> {
  final RustBridge _bridge;
  bool _userActed = false;

  SettingsNotifier(this._bridge) : super(AppSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    await DartPrefs.instance.load();
    final loaded = await _bridge.loadSettings();
    if (_userActed) return;
    _userActed = true;
    final withDartPrefs = AppSettings(
      theme: loaded.theme,
      defaultModel: loaded.defaultModel,
      defaultMode: loaded.defaultMode,
      libraryPath: loaded.libraryPath,
      vadEnabled: loaded.vadEnabled,
      language: loaded.language,
      autoStopMinutes: loaded.autoStopMinutes,
      defaultExportFormat: DartPrefs.instance.getString('defaultExportFormat') ?? 'markdown',
      micDeviceId: DartPrefs.instance.getString('micDeviceId'),
      speakerDeviceId: DartPrefs.instance.getString('speakerDeviceId'),
      progressiveEnabled: loaded.progressiveEnabled,
      rtfScore: DartPrefs.instance.getDouble('rtfScore') ?? 0.0,
      gpuEnabled: loaded.gpuEnabled,
      gpuDevice: loaded.gpuDevice,
      hptMode: (() {
        final raw = DartPrefs.instance.getInt('hptMode');
        if (raw == null) return HptMode.auto;
        return HptMode.values[raw.clamp(0, HptMode.values.length - 1)];
      })(),
    );
    final sanitized = _sanitizeDefaultModel(withDartPrefs);
    state = sanitized;
    if (sanitized.defaultModel != loaded.defaultModel) {
      await _bridge.saveSettings(sanitized);
    }
    if (sanitized.progressiveEnabled && sanitized.rtfScore == 0.0) {
      _backgroundBenchmark(sanitized);
    }
  }

  Future<void> _backgroundBenchmark(AppSettings settings) async {
    if (state.rtfScore != 0.0) return;
    final q5Path = modelPathForId('large-v3-turbo-q5', libraryPath: settings.libraryPath);
    final q5File = File(q5Path);
    if (!await q5File.exists()) return;
    try {
      final score = await RustEngineBridge().benchmarkRtf(q5Path);
      if (score > 0) setRtfScore(score);
    } catch (_) {}
  }

  // NOTE: this intentionally accepts any available model, not just
  // kKnownModelIds (the 2 models the Settings dropdown lists) — power users
  // can have 'tiny'/'small'/'medium' etc. on disk (e.g. via an older
  // release, or a manual download) and those should keep working for
  // transcription. The Settings dropdown itself is what clamps display to
  // kKnownModelIds (see settings_side_panel.dart) so an out-of-catalog
  // value can't crash it, without discarding the user's actual selection.
  AppSettings _sanitizeDefaultModel(AppSettings settings) {
    if (isModelAvailable(settings.defaultModel, libraryPath: settings.libraryPath)) {
      return settings;
    }
    const fallback = 'base';
    if (settings.defaultModel == fallback) return settings;
    return settings.copyWith(defaultModel: fallback);
  }

  Future<void> setTheme(AppThemeMode theme) async {
    _userActed = true;
    state = state.copyWith(theme: theme);
    await _bridge.saveSettings(state);
  }

  Future<void> toggleTheme() async {
    final next = state.theme == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark;
    await setTheme(next);
  }

  Future<void> setProgressiveEnabled(bool enabled) async {
    _userActed = true;
    state = state.copyWith(progressiveEnabled: enabled);
    DartPrefs.instance.setBool('progressiveEnabled', enabled);
    await DartPrefs.instance.save();
    await _bridge.saveSettings(state);
  }

  Future<void> setGpuEnabled(bool enabled) async {
    _userActed = true;
    state = state.copyWith(gpuEnabled: enabled);
    await _bridge.saveSettings(state);
  }

  Future<void> setGpuDevice(int device) async {
    _userActed = true;
    state = state.copyWith(gpuDevice: device);
    await _bridge.saveSettings(state);
  }

  Future<void> setRtfScore(double score) async {
    _userActed = true;
    state = state.copyWith(rtfScore: score);
    DartPrefs.instance.setDouble('rtfScore', score);
    await DartPrefs.instance.save();
  }

  Future<void> setHptMode(HptMode mode) async {
    _userActed = true;
    state = state.copyWith(hptMode: mode);
    DartPrefs.instance.setInt('hptMode', mode.index);
    await DartPrefs.instance.save();
    await _bridge.saveSettings(state);
  }

  Future<void> setDefaultModel(String modelId) async {
    _userActed = true;
    state = state.copyWith(defaultModel: modelId);
    await _bridge.saveSettings(state);
  }

  Future<void> setLanguage(String? language) async {
    _userActed = true;
    state = state.copyWith(language: language);
    await _bridge.saveSettings(state);
  }

  Future<void> setDefaultMode(SessionMode mode) async {
    _userActed = true;
    state = state.copyWith(defaultMode: mode);
    await _bridge.saveSettings(state);
  }

  Future<void> setVadEnabled(bool enabled) async {
    _userActed = true;
    state = state.copyWith(vadEnabled: enabled);
    await _bridge.saveSettings(state);
  }

  Future<void> setAutoStopMinutes(int? minutes) async {
    _userActed = true;
    state = state.copyWith(autoStopMinutes: minutes);
    await _bridge.saveSettings(state);
  }

  Future<void> setDefaultExportFormat(String format) async {
    _userActed = true;
    state = state.copyWith(defaultExportFormat: format);
    DartPrefs.instance.setString('defaultExportFormat', format);
    await DartPrefs.instance.save();
    await _bridge.saveSettings(state);
  }

  Future<void> setLibraryPath(String path) async {
    _userActed = true;
    state = state.copyWith(libraryPath: path);
    await _bridge.saveSettings(state);
  }

  Future<void> setMicDeviceName(String? name) async {
    _userActed = true;
    state = state.copyWith(micDeviceId: name);
    if (name != null) {
      DartPrefs.instance.setString('micDeviceId', name);
    } else {
      DartPrefs.instance.remove('micDeviceId');
    }
    await DartPrefs.instance.save();
    await _bridge.saveSettings(state);
  }

  Future<void> setSpeakerDeviceName(String? name) async {
    _userActed = true;
    state = state.copyWith(speakerDeviceId: name);
    if (name != null) {
      DartPrefs.instance.setString('speakerDeviceId', name);
    } else {
      DartPrefs.instance.remove('speakerDeviceId');
    }
    await DartPrefs.instance.save();
    await _bridge.saveSettings(state);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.read(rustBridgeProvider));
});
