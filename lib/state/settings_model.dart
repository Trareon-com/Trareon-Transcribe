import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../services/bridge_service.dart';
import '../services/dart_prefs.dart';
import 'models.dart';

final rustBridgeProvider = Provider<RustBridge>((ref) => RustEngineBridge());

/// A settings write that did not reach disk.
///
/// Every setter used to be `state = …; await _bridge.saveSettings(state);`
/// with no `try`. A failed write — a read-only config directory, a full
/// disk, a permissions change — left the switch flipped on screen and
/// nothing saved, and the user found out on the next launch (audit A.4-7).
class SettingsSaveFailure {
  /// Indonesian name of the setting, for the message.
  final String label;
  final String message;

  /// The value that failed to save, so "Coba lagi" retries the same thing
  /// rather than whatever the state happens to be by then.
  final AppSettings pending;

  final bool saveToBridge;
  final Future<void> Function()? savePrefs;

  const SettingsSaveFailure({
    required this.label,
    required this.message,
    required this.pending,
    required this.saveToBridge,
    this.savePrefs,
  });

  String get userMessage =>
      'Pengaturan "$label" gagal disimpan: $message. Perubahan dikembalikan.';
}

/// The last settings write that failed, or null. Watched by the settings
/// UI, which shows a banner with a retry until the write succeeds.
final settingsSaveFailureProvider =
    StateProvider<SettingsSaveFailure?>((ref) => null);

class SettingsNotifier extends StateNotifier<AppSettings> {
  final RustBridge _bridge;

  /// Called whenever a write fails, and again with null once one succeeds.
  final void Function(SettingsSaveFailure?)? onSaveFailure;
  bool _userActed = false;

  SettingsNotifier(this._bridge, {this.onSaveFailure})
      : super(AppSettings.defaults()) {
    _load();
  }

  /// The last failure, also exposed directly so tests (and any non-Riverpod
  /// caller) do not have to go through a provider to see it.
  SettingsSaveFailure? lastSaveFailure;

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
      summary: loaded.summary,
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
      // Best effort: this is a repair, not a user action, and failing it
      // must not put an error banner in front of someone who did nothing.
      try {
        await _bridge.saveSettings(sanitized);
      } catch (_) {}
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

  /// Applies [next] optimistically, persists it, and rolls back with a
  /// reported failure if the write does not land.
  ///
  /// Rolling back is the honest behaviour: a toggle that stays on after a
  /// failed save is telling the user something that is not true.
  Future<void> _apply(
    AppSettings next, {
    required String label,
    bool saveToBridge = true,
    Future<void> Function()? savePrefs,
  }) async {
    _userActed = true;
    final previous = state;
    state = next;
    try {
      if (savePrefs != null) await savePrefs();
      if (saveToBridge) await _bridge.saveSettings(next);
      _report(null);
    } catch (e) {
      state = previous;
      _report(SettingsSaveFailure(
        label: label,
        message: '$e',
        pending: next,
        saveToBridge: saveToBridge,
        savePrefs: savePrefs,
      ));
    }
  }

  void _report(SettingsSaveFailure? failure) {
    if (failure == null && lastSaveFailure == null) return;
    lastSaveFailure = failure;
    onSaveFailure?.call(failure);
  }

  /// Re-runs the write behind [lastSaveFailure].
  Future<void> retryLastSave() async {
    final failure = lastSaveFailure;
    if (failure == null) return;
    await _apply(
      failure.pending,
      label: failure.label,
      saveToBridge: failure.saveToBridge,
      savePrefs: failure.savePrefs,
    );
  }

  /// Drops a failure the user has acknowledged.
  void dismissSaveFailure() => _report(null);

  Future<void> setTheme(AppThemeMode theme) =>
      _apply(state.copyWith(theme: theme), label: 'Tema');

  Future<void> toggleTheme() async {
    final next = state.theme == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark;
    await setTheme(next);
  }

  Future<void> setProgressiveEnabled(bool enabled) => _apply(
        state.copyWith(progressiveEnabled: enabled),
        // Rust owns this now. It used to be written to DartPrefs and never
        // read back, so the toggle silently reverted to "on" on every launch.
        label: 'Progressive Mode',
      );

  Future<void> setGpuEnabled(bool enabled) =>
      _apply(state.copyWith(gpuEnabled: enabled), label: 'Akselerasi GPU');

  Future<void> setGpuDevice(int device) =>
      _apply(state.copyWith(gpuDevice: device), label: 'Perangkat GPU');

  Future<void> setRtfScore(double score) => _apply(
        state.copyWith(rtfScore: score),
        label: 'Skor benchmark',
        saveToBridge: false,
        savePrefs: () async {
          DartPrefs.instance.setDouble('rtfScore', score);
          await DartPrefs.instance.save();
        },
      );

  Future<void> setHptMode(HptMode mode) => _apply(
        state.copyWith(hptMode: mode),
        label: 'Mode transkripsi bertahap',
        savePrefs: () async {
          DartPrefs.instance.setInt('hptMode', mode.index);
          await DartPrefs.instance.save();
        },
      );

  /// Updates the opt-in AI-summary configuration. Persisted through Rust
  /// alongside the rest of the settings (see `SummarySettings` for why the
  /// API key lives in the same file).
  Future<void> setSummarySettings(SummarySettings summary) =>
      _apply(state.copyWith(summary: summary), label: 'Ringkasan AI');

  Future<void> setDefaultModel(String modelId) =>
      _apply(state.copyWith(defaultModel: modelId), label: 'Model default');

  Future<void> setLanguage(String? language) =>
      _apply(state.copyWith(language: language), label: 'Bahasa');

  Future<void> setDefaultMode(SessionMode mode) =>
      _apply(state.copyWith(defaultMode: mode), label: 'Mode default');

  Future<void> setVadEnabled(bool enabled) =>
      _apply(state.copyWith(vadEnabled: enabled), label: 'VAD (deteksi suara)');

  Future<void> setAutoStopMinutes(int? minutes) => _apply(
        minutes == null
            ? state.copyWith(clearAutoStop: true)
            : state.copyWith(autoStopMinutes: minutes),
        label: 'Auto-Stop saat diam',
      );

  Future<void> setDefaultExportFormat(String format) => _apply(
        state.copyWith(defaultExportFormat: format),
        label: 'Format ekspor default',
        savePrefs: () async {
          DartPrefs.instance.setString('defaultExportFormat', format);
          await DartPrefs.instance.save();
        },
      );

  Future<void> setLibraryPath(String path) =>
      _apply(state.copyWith(libraryPath: path), label: 'Folder output');

  Future<void> setMicDeviceName(String? name) => _apply(
        state.copyWith(micDeviceId: name),
        label: 'Mikrofon',
        savePrefs: () async {
          if (name != null) {
            DartPrefs.instance.setString('micDeviceId', name);
          } else {
            DartPrefs.instance.remove('micDeviceId');
          }
          await DartPrefs.instance.save();
        },
      );

  Future<void> setSpeakerDeviceName(String? name) => _apply(
        state.copyWith(speakerDeviceId: name),
        label: 'Pengeras suara',
        savePrefs: () async {
          if (name != null) {
            DartPrefs.instance.setString('speakerDeviceId', name);
          } else {
            DartPrefs.instance.remove('speakerDeviceId');
          }
          await DartPrefs.instance.save();
        },
      );
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(
    ref.read(rustBridgeProvider),
    onSaveFailure: (failure) =>
        ref.read(settingsSaveFailureProvider.notifier).state = failure,
  );
});
