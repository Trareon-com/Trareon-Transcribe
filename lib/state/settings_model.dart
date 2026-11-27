import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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
final settingsSaveFailureProvider = StateProvider<SettingsSaveFailure?>(
  (ref) => null,
);

/// Every field of [AppSettings], for the two things the load path has to do
/// per field rather than per object: work out what a setter changed, and
/// re-assemble the state so that a late load cannot undo it.
///
/// `read` returns the field boxed as `Object?` so the setter diff is one
/// expression instead of twenty-nine comparisons.
enum _SettingField {
  theme,
  defaultModel,
  defaultMode,
  libraryPath,
  vadEnabled,
  language,
  autoStopMinutes,
  defaultExportFormat,
  micDeviceId,
  speakerDeviceId,
  progressiveEnabled,
  rtfScore,
  hptMode,
  gpuEnabled,
  gpuDevice,
  audioToDisk,
  summary,
  glossary,
  summaryTemplates,
  notulen,
  autoRetranscribe,
  pdp,
  noiseReduction,
  agcEnabled,
  neuralDiarization,
  defaultModelUpgradeDismissed,
  consentBannerDismissed,
  meetingAutoDetectEnabled,
  silenceAutoStopMinutes;

  Object? read(AppSettings s) => switch (this) {
    theme => s.theme,
    defaultModel => s.defaultModel,
    defaultMode => s.defaultMode,
    libraryPath => s.libraryPath,
    vadEnabled => s.vadEnabled,
    language => s.language,
    autoStopMinutes => s.autoStopMinutes,
    defaultExportFormat => s.defaultExportFormat,
    micDeviceId => s.micDeviceId,
    speakerDeviceId => s.speakerDeviceId,
    progressiveEnabled => s.progressiveEnabled,
    rtfScore => s.rtfScore,
    hptMode => s.hptMode,
    gpuEnabled => s.gpuEnabled,
    gpuDevice => s.gpuDevice,
    audioToDisk => s.audioToDisk,
    summary => s.summary,
    glossary => s.glossary,
    summaryTemplates => s.summaryTemplates,
    notulen => s.notulen,
    autoRetranscribe => s.autoRetranscribe,
    pdp => s.pdp,
    noiseReduction => s.noiseReduction,
    agcEnabled => s.agcEnabled,
    neuralDiarization => s.neuralDiarization,
    defaultModelUpgradeDismissed => s.defaultModelUpgradeDismissed,
    consentBannerDismissed => s.consentBannerDismissed,
    meetingAutoDetectEnabled => s.meetingAutoDetectEnabled,
    silenceAutoStopMinutes => s.silenceAutoStopMinutes,
  };
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final RustBridge _bridge;

  /// Called whenever a write fails, and again with null once one succeeds.
  final void Function(SettingsSaveFailure?)? onSaveFailure;

  /// Completes once the Rust-owned settings — the source of `libraryPath`,
  /// the default model and the GPU flags — are in [state]. Phase 1 of the
  /// two-phase load below; see [ready].
  final Completer<void> _rustLoaded = Completer<void>();

  /// Fields a caller has already changed since launch. A load that lands
  /// afterwards keeps these and applies the rest, instead of the old
  /// all-or-nothing `_userActed` flag that discarded the *entire* saved
  /// configuration — `libraryPath` included — the moment the setup wizard
  /// called `setDefaultModel` during a cold start (issue #62).
  final Set<_SettingField> _touched = <_SettingField>{};

  SettingsNotifier(this._bridge, {this.onSaveFailure})
    : super(AppSettings.defaults()) {
    _load();
  }

  /// Resolves once the Rust-owned settings are applied. Never throws, and
  /// always completes: a bridge that cannot answer leaves the defaults in
  /// place. Callers that must not decide from [AppSettings.defaults] — the
  /// setup wizard's model suggestion and GPU calibration — await this.
  Future<void> get ready => _rustLoaded.future;

  /// The last failure, also exposed directly so tests (and any non-Riverpod
  /// caller) do not have to go through a provider to see it.
  SettingsSaveFailure? lastSaveFailure;

  /// Two phases, on purpose.
  ///
  /// Phase 1 is the Rust bridge: one call, no `path_provider`, and the only
  /// half that carries `libraryPath`. Phase 2 is `DartPrefs`, whose five
  /// fields are Dart-only. Splitting them is what makes [ready] awaitable in
  /// a widget test: `DartPrefs.load()` never answers there, so a `ready`
  /// that waited on it hung `pumpAndSettle`, and a `timeout()` around it
  /// fixed that by leaving a pending `Timer` that failed 90 other tests.
  Future<void> _load() async {
    await _loadRustSettings();
    await _loadDartPrefs();
  }

  /// Phase 1 — Rust-owned settings.
  Future<void> _loadRustSettings() async {
    try {
      final loaded = await _bridge.loadSettings();
      // The notifier can be disposed while the load is in flight (a test
      // that tears down quickly, a hot restart): writing `state` after
      // dispose throws "Bad state: Tried to use SettingsNotifier after
      // `dispose` was called" and takes an unrelated test down with it.
      if (!mounted) return;
      var merged = _mergeLoaded(loaded);
      var repaired = false;
      // A default model that is not on disk is repaired to `base` — unless
      // the user has already chosen one since launch, in which case theirs
      // wins (it is the newer decision).
      if (!_touched.contains(_SettingField.defaultModel)) {
        final sanitized = _sanitizeDefaultModel(merged);
        repaired = sanitized.defaultModel != merged.defaultModel;
        merged = sanitized;
      }
      state = merged;
      // Keep disk in step with what we now hold. A setter that ran during
      // the load already wrote the *pre-load* state — default `libraryPath`
      // and all — over the saved one, so merging in memory is not enough
      // to stop the next launch from seeing the damage.
      if (repaired || _touched.isNotEmpty) {
        // Best effort: this is a repair, not a user action, and failing it
        // must not put an error banner in front of someone who did nothing.
        try {
          await _bridge.saveSettings(merged);
        } catch (_) {}
      }
    } catch (_) {
      // A bridge that cannot answer leaves the defaults in place; the app
      // stays usable and every later write still goes through.
    } finally {
      if (!_rustLoaded.isCompleted) _rustLoaded.complete();
    }
  }

  /// Phase 2 — the Dart-only fields, from [DartPrefs].
  ///
  /// Additive by construction: it writes the five fields that file owns and
  /// nothing else, and skips any of them a caller has already changed while
  /// this load was in flight.
  Future<void> _loadDartPrefs() async {
    try {
      await DartPrefs.instance.load();
      if (!mounted) return;
      final prefs = DartPrefs.instance;
      final cur = state;
      bool untouched(_SettingField field) => !_touched.contains(field);
      state = cur.copyWith(
        defaultExportFormat: untouched(_SettingField.defaultExportFormat)
            ? prefs.getString('defaultExportFormat') ?? cur.defaultExportFormat
            : cur.defaultExportFormat,
        micDeviceId: untouched(_SettingField.micDeviceId)
            ? prefs.getString('micDeviceId')
            : cur.micDeviceId,
        speakerDeviceId: untouched(_SettingField.speakerDeviceId)
            ? prefs.getString('speakerDeviceId')
            : cur.speakerDeviceId,
        rtfScore: untouched(_SettingField.rtfScore)
            ? prefs.getDouble('rtfScore') ?? cur.rtfScore
            : cur.rtfScore,
        hptMode: untouched(_SettingField.hptMode)
            ? _hptModeFromPrefs(prefs, cur.hptMode)
            : cur.hptMode,
      );
      final settled = state;
      if (settled.progressiveEnabled && settled.rtfScore == 0.0) {
        await _backgroundBenchmark(settled);
      }
    } catch (_) {
      // Prefs are a convenience layer — a corrupt or unreachable file must
      // not take the rest of the settings down with it.
    }
  }

  static HptMode _hptModeFromPrefs(DartPrefs prefs, HptMode fallback) {
    final raw = prefs.getInt('hptMode');
    if (raw == null) return fallback;
    return HptMode.values[raw.clamp(0, HptMode.values.length - 1)];
  }

  /// [loaded] with every field a caller has already changed kept from the
  /// current state.
  ///
  /// Built through the full constructor on purpose: the previous version
  /// listed the fields by hand and quietly left six out (`audioToDisk`,
  /// `glossary`, `summaryTemplates`, `notulen`, `autoRetranscribe`,
  /// `meetingAutoDetectEnabled`, ...), so they reset to their defaults on
  /// every launch. Naming every field means a new one is a compile error
  /// here rather than a silent reset.
  AppSettings _mergeLoaded(AppSettings loaded) {
    final cur = state;
    T pick<T>(_SettingField field, T current, T stored) =>
        _touched.contains(field) ? current : stored;
    return AppSettings(
      theme: pick(_SettingField.theme, cur.theme, loaded.theme),
      defaultModel: pick(
        _SettingField.defaultModel,
        cur.defaultModel,
        loaded.defaultModel,
      ),
      defaultMode: pick(
        _SettingField.defaultMode,
        cur.defaultMode,
        loaded.defaultMode,
      ),
      libraryPath: pick(
        _SettingField.libraryPath,
        cur.libraryPath,
        loaded.libraryPath,
      ),
      vadEnabled: pick(_SettingField.vadEnabled, cur.vadEnabled, loaded.vadEnabled),
      language: pick(_SettingField.language, cur.language, loaded.language),
      autoStopMinutes: pick(
        _SettingField.autoStopMinutes,
        cur.autoStopMinutes,
        loaded.autoStopMinutes,
      ),
      defaultExportFormat: pick(
        _SettingField.defaultExportFormat,
        cur.defaultExportFormat,
        loaded.defaultExportFormat,
      ),
      micDeviceId: pick(
        _SettingField.micDeviceId,
        cur.micDeviceId,
        loaded.micDeviceId,
      ),
      speakerDeviceId: pick(
        _SettingField.speakerDeviceId,
        cur.speakerDeviceId,
        loaded.speakerDeviceId,
      ),
      progressiveEnabled: pick(
        _SettingField.progressiveEnabled,
        cur.progressiveEnabled,
        loaded.progressiveEnabled,
      ),
      rtfScore: pick(_SettingField.rtfScore, cur.rtfScore, loaded.rtfScore),
      hptMode: pick(_SettingField.hptMode, cur.hptMode, loaded.hptMode),
      gpuEnabled: pick(_SettingField.gpuEnabled, cur.gpuEnabled, loaded.gpuEnabled),
      gpuDevice: pick(_SettingField.gpuDevice, cur.gpuDevice, loaded.gpuDevice),
      audioToDisk: pick(
        _SettingField.audioToDisk,
        cur.audioToDisk,
        loaded.audioToDisk,
      ),
      summary: pick(_SettingField.summary, cur.summary, loaded.summary),
      glossary: pick(_SettingField.glossary, cur.glossary, loaded.glossary),
      summaryTemplates: pick(
        _SettingField.summaryTemplates,
        cur.summaryTemplates,
        loaded.summaryTemplates,
      ),
      notulen: pick(_SettingField.notulen, cur.notulen, loaded.notulen),
      autoRetranscribe: pick(
        _SettingField.autoRetranscribe,
        cur.autoRetranscribe,
        loaded.autoRetranscribe,
      ),
      pdp: pick(_SettingField.pdp, cur.pdp, loaded.pdp),
      noiseReduction: pick(
        _SettingField.noiseReduction,
        cur.noiseReduction,
        loaded.noiseReduction,
      ),
      agcEnabled: pick(_SettingField.agcEnabled, cur.agcEnabled, loaded.agcEnabled),
      neuralDiarization: pick(
        _SettingField.neuralDiarization,
        cur.neuralDiarization,
        loaded.neuralDiarization,
      ),
      defaultModelUpgradeDismissed: pick(
        _SettingField.defaultModelUpgradeDismissed,
        cur.defaultModelUpgradeDismissed,
        loaded.defaultModelUpgradeDismissed,
      ),
      consentBannerDismissed: pick(
        _SettingField.consentBannerDismissed,
        cur.consentBannerDismissed,
        loaded.consentBannerDismissed,
      ),
      meetingAutoDetectEnabled: pick(
        _SettingField.meetingAutoDetectEnabled,
        cur.meetingAutoDetectEnabled,
        loaded.meetingAutoDetectEnabled,
      ),
      silenceAutoStopMinutes: pick(
        _SettingField.silenceAutoStopMinutes,
        cur.silenceAutoStopMinutes,
        loaded.silenceAutoStopMinutes,
      ),
    );
  }

  Future<void> _backgroundBenchmark(AppSettings settings) async {
    if (state.rtfScore != 0.0) return;
    final q5Path = modelPathForId(
      'large-v3-turbo-q5',
      libraryPath: settings.libraryPath,
    );
    final q5File = File(q5Path);
    if (!await q5File.exists()) return;
    try {
      final score = await RustEngineBridge().benchmarkRtf(q5Path);
      if (!mounted) return;
      if (score > 0) setRtfScore(score);
    } catch (_) {}
  }

  // NOTE: this intentionally accepts any available model, not just
  // kKnownModelIds (the models the Settings dropdown lists) — power users
  // can have 'tiny'/'medium' etc. on disk (e.g. via an older release, or a
  // manual download) and those should keep working for transcription. The
  // Settings dropdown itself is what clamps display to kKnownModelIds (see
  // settings_screen.dart) so an out-of-catalog value can't crash it,
  // without discarding the user's actual selection.
  AppSettings _sanitizeDefaultModel(AppSettings settings) {
    if (isModelAvailable(
      settings.defaultModel,
      libraryPath: settings.libraryPath,
    )) {
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
    final previous = state;
    // Record *which* fields this write changes, so a settings load that is
    // still in flight applies its saved values to everything else instead of
    // throwing the lot away.
    _touched.addAll(
      _SettingField.values.where(
        (field) => field.read(previous) != field.read(next),
      ),
    );
    state = next;
    try {
      if (savePrefs != null) await savePrefs();
      if (saveToBridge) await _bridge.saveSettings(next);
      if (!mounted) return;
      _report(null);
    } catch (e) {
      // Same race as _load: the write can land after dispose, and rolling
      // back into a disposed notifier must not crash the caller.
      if (!mounted) return;
      state = previous;
      _report(
        SettingsSaveFailure(
          label: label,
          message: '$e',
          pending: next,
          saveToBridge: saveToBridge,
          savePrefs: savePrefs,
        ),
      );
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
    final next = state.theme == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    await setTheme(next);
  }

  Future<void> setProgressiveEnabled(bool enabled) => _apply(
    state.copyWith(progressiveEnabled: enabled),
    // Rust owns this now. It used to be written to DartPrefs and never
    // read back, so the toggle silently reverted to "on" on every launch.
    label: 'Cepat dulu, lalu diperhalus',
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
    label: 'Cara transkripsi bertahap',
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

  // ── Kamus istilah (F3) ────────────────────────────────────────────────

  Future<void> setGlossary(GlossarySettings glossary) =>
      _apply(state.copyWith(glossary: glossary), label: 'Kamus istilah');

  /// "Pemisahan pembicara akurat" (sherpa-onnx neural diarization).
  Future<void> setNeuralDiarization(bool enabled) => _apply(
    state.copyWith(neuralDiarization: enabled),
    label: 'Pemisahan pembicara akurat',
  );

  /// Re-sends the current settings to the engine without changing them.
  ///
  /// The engine resolves the Silero VAD and diarization model paths when
  /// settings are saved (`api::apply_engine_settings`), so a file that was
  /// downloaded *after* the last save is invisible until something saves
  /// again. Called by the download flow so a freshly installed model takes
  /// effect on the next pass rather than the next launch.
  Future<void> reapply() => _apply(state, label: 'Model mesin');

  /// Mode Kepatuhan UU PDP (F13).
  Future<void> setPdp(PdpSettings pdp) =>
      _apply(state.copyWith(pdp: pdp), label: 'Mode Kepatuhan PDP');

  Future<void> setGlossaryEnabled(bool enabled) =>
      setGlossary(state.glossary.copyWith(enabled: enabled));

  Future<void> setGlossaryPostCorrection(bool enabled) =>
      setGlossary(state.glossary.copyWith(postCorrection: enabled));

  /// Replaces the term list, trimming blanks and case-insensitive duplicates
  /// so the same term cannot occupy the prompt budget twice.
  Future<void> setGlossaryTerms(List<String> terms) =>
      setGlossary(state.glossary.copyWith(terms: dedupeTerms(terms)));

  Future<void> addGlossaryTerm(String term) =>
      setGlossaryTerms([...state.glossary.terms, term]);

  Future<void> removeGlossaryTerm(String term) => setGlossaryTerms(
    state.glossary.terms
        .where((t) => t.toLowerCase() != term.toLowerCase())
        .toList(),
  );

  // ── Template ringkasan buatan sendiri (F8) ────────────────────────────

  Future<void> saveSummaryTemplate(CustomSummaryTemplate template) {
    final existing = state.summaryTemplates.indexWhere(
      (candidate) => candidate.id == template.id,
    );
    final next = [...state.summaryTemplates];
    if (existing >= 0) {
      next[existing] = template;
    } else {
      next.add(template);
    }
    return _apply(
      state.copyWith(summaryTemplates: next),
      label: 'Template ringkasan',
    );
  }

  Future<void> deleteSummaryTemplate(String id) => _apply(
    state.copyWith(
      summaryTemplates: state.summaryTemplates
          .where((t) => t.id != id)
          .toList(),
    ),
    label: 'Template ringkasan',
  );

  // ── Notulen resmi (F2) ────────────────────────────────────────────────

  Future<void> setNotulenDefaults(NotulenDefaults notulen) =>
      _apply(state.copyWith(notulen: notulen), label: 'Kop surat notulen');

  // ── Transkrip ulang otomatis (F5) ─────────────────────────────────────

  Future<void> setAutoRetranscribe(bool? enabled) => _apply(
    state.copyWith(autoRetranscribe: enabled),
    label: 'Perhalus transkrip otomatis',
  );

  Future<void> setDefaultModel(String modelId) =>
      _apply(state.copyWith(defaultModel: modelId), label: 'Model default');

  Future<void> setLanguage(String? language) =>
      _apply(state.copyWith(language: language), label: 'Bahasa');

  Future<void> setDefaultMode(SessionMode mode) =>
      _apply(state.copyWith(defaultMode: mode), label: 'Mode default');

  Future<void> setVadEnabled(bool enabled) =>
      _apply(state.copyWith(vadEnabled: enabled), label: 'Abaikan jeda sunyi');

  Future<void> setNoiseReduction(bool enabled) => _apply(
    state.copyWith(noiseReduction: enabled),
    label: 'Pengurangan derau',
  );

  Future<void> setAgcEnabled(bool enabled) => _apply(
    state.copyWith(agcEnabled: enabled),
    label: 'Penguatan suara otomatis',
  );

  /// Dismisses the "Tingkatkan akurasi" offer without changing
  /// [AppSettings.defaultModel]. Persisted so the offer does not reappear
  /// every time Settings is opened (Sprint 14a item 6).
  Future<void> dismissDefaultModelUpgradeOffer() => _apply(
    state.copyWith(defaultModelUpgradeDismissed: true),
    label: 'Tawaran tingkatkan akurasi',
  );

  /// Dismisses the pre-recording consent reminder with "jangan tampilkan
  /// lagi" (Sprint 13 E1). Persisted so the reminder does not reappear on
  /// every session start; the per-session audit acknowledgement still
  /// happens regardless, via `acknowledgeConsent` on the bridge.
  Future<void> dismissConsentBanner() => _apply(
    state.copyWith(consentBannerDismissed: true),
    label: 'Pengingat persetujuan perekaman',
  );

  Future<void> setAutoStopMinutes(int? minutes) => _apply(
    minutes == null
        ? state.copyWith(clearAutoStop: true)
        : state.copyWith(autoStopMinutes: minutes),
    label: 'Berhenti sendiri saat sunyi',
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

/// Trims blanks and case-insensitive duplicates while keeping the user's
/// ordering — the kamus istilah's prompt budget is per term, so a duplicate
/// costs vocabulary space for nothing. Mirrors
/// `GlossaryConfig::prioritised_terms` on the Rust side.
List<String> dedupeTerms(Iterable<String> terms) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in terms) {
    final term = raw.trim();
    if (term.isEmpty) continue;
    if (!seen.add(term.toLowerCase())) continue;
    out.add(term);
  }
  return out;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier(
    ref.read(rustBridgeProvider),
    onSaveFailure: (failure) =>
        ref.read(settingsSaveFailureProvider.notifier).state = failure,
  );
});
