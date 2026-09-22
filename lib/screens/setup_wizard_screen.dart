import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/audio/device.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../utils/model_labels.dart';

class WizardSpecs {
  final int cpuCores;
  final int ramMb;
  final String suggestedModel;
  const WizardSpecs({
    required this.cpuCores,
    required this.ramMb,
    required this.suggestedModel,
  });
}

typedef WizardSpecDetector = Future<WizardSpecs> Function();

class SetupWizardScreen extends ConsumerStatefulWidget {
  final VoidCallback onFinished;
  final WizardSpecDetector? detectSpecs;

  const SetupWizardScreen({super.key, required this.onFinished, this.detectSpecs});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

enum _WizardStep { specDetect, modelChoice, audioSetup, toneTest }

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  _WizardStep _step = _WizardStep.specDetect;
  String _selectedModel = 'base';

  // Spec detection results
  int? _cpuCores;
  int? _ramMb;
  String? _suggestedModel;
  bool _specDetected = false;

  static const _steps = _WizardStep.values;
  int get _stepIndex => _steps.indexOf(_step);

  @override
  void initState() {
    super.initState();
    Future.microtask(_detectSpecs);
  }

  Future<void> _detectSpecs() async {
    final initialSelection = _selectedModel;

    final WizardSpecs specs;
    final custom = widget.detectSpecs;
    if (custom != null) {
      specs = await custom();
    } else {
      specs = await _runNativeSpecDetection();
    }
    final cores = specs.cpuCores;
    final ramMb = specs.ramMb;

    // Suggest model based on RAM
    final suggested = _availableModel(specs.suggestedModel);

    if (mounted) {
      final shouldAutoApply = _selectedModel == initialSelection;
      setState(() {
        _cpuCores = cores;
        _ramMb = ramMb;
        _suggestedModel = suggested;
        if (shouldAutoApply) {
          _selectedModel = suggested;
        }
        _specDetected = true;
      });
      if (shouldAutoApply) {
        ref.read(settingsProvider.notifier).setDefaultModel(suggested);
      }
    }
  }

  Future<WizardSpecs> _runNativeSpecDetection() async {
    final cores = Platform.numberOfProcessors;
    // Try to read RAM via sysctl on macOS, fallback to estimate
    int? ramMb;
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
        if (result.exitCode == 0) {
          ramMb = ((int.tryParse(result.stdout.toString().trim()) ?? 0) / (1024 * 1024)).round();
        }
      }
    } on Object {
      // Fallback: use environment-based heuristic
    }

    ramMb ??= _estimateRamMb(cores);
    return WizardSpecs(
      cpuCores: cores,
      ramMb: ramMb,
      suggestedModel: _suggestModel(ramMb),
    );
  }

  int _estimateRamMb(int cores) {
    // Rough heuristic: assume 2GB per core for modern Macs
    final estimated = cores * 2048;
    // Cap at reasonable values
    if (estimated > 32768) return 32768;
    if (estimated < 4096) return 4096;
    return estimated;
  }

  String _suggestModel(int ramMb) {
    if (ramMb >= 8192) return 'large-v3-turbo-q5'; // 8GB+
    return 'base';                                   // < 8GB
  }

  String _availableModel(String preferred) {
    final libraryPath = ref.read(settingsProvider).libraryPath;
    if (isModelAvailable(preferred, libraryPath: libraryPath)) return preferred;
    for (final candidate in ['base', 'large-v3-turbo-q5']) {
      if (isModelAvailable(candidate, libraryPath: libraryPath)) {
        return candidate;
      }
    }
    return 'base';
  }

  void _next() {
    if (_stepIndex < _steps.length - 1) {
      setState(() => _step = _steps[_stepIndex + 1]);
    } else {
      widget.onFinished();
    }
  }

  void _back() {
    if (_stepIndex > 0) {
      setState(() => _step = _steps[_stepIndex - 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            _WizardProgress(step: _stepIndex, total: _steps.length),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: _buildStepBody(),
              ),
            ),

            // Navigation buttons
            _WizardNavigation(
              isFirst: _stepIndex == 0,
              isLast: _stepIndex == _steps.length - 1,
              onBack: _back,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case _WizardStep.specDetect:
        return _SpecDetectStep(
          cpuCores: _cpuCores,
          ramMb: _ramMb,
          suggestedModel: _suggestedModel,
          detected: _specDetected,
        );
      case _WizardStep.modelChoice:
        return _ModelChoiceStep(
          selected: _selectedModel,
          onChanged: (id) {
            setState(() => _selectedModel = id);
            ref.read(settingsProvider.notifier).setDefaultModel(id);
          },
        );
      case _WizardStep.audioSetup:
        return const _AudioSetupStep();
      case _WizardStep.toneTest:
        return const _ToneTestStep();
    }
  }
}

/// Progress indicator
class _WizardProgress extends StatelessWidget {
  final int step;
  final int total;

  const _WizardProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(total, (i) {
              final isDone = i < step;
              final isActive = i == step;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: isDone || isActive ? colors.primary : colors.border,
                        ),
                      ),
                    ),
                    if (i < total - 1) const SizedBox(width: 6),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Langkah ${step + 1} dari $total',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              Text(
                '${((step + 1) / total * 100).round()}%',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Navigation buttons
class _WizardNavigation extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _WizardNavigation({
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: isFirst ? null : onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 14),
            label: const Text('Kembali'),
            style: TextButton.styleFrom(
              foregroundColor: isFirst ? colors.textTertiary : colors.text,
            ),
          ),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isLast ? 'Selesai' : 'Lanjut'),
          ),
        ],
      ),
    );
  }
}

/// Generic step content helper
class _StepContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? child;

  const _StepContent({
    required this.icon,
    required this.title,
    required this.description,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primary.withValues(alpha: 0.1),
          ),
          child: Icon(icon, size: 40, color: colors.primary),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(color: colors.text, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5),
        ),
        if (child != null) ...[const SizedBox(height: 24), child!],
      ],
    );
  }
}

/// Step 1 — System spec detection with real data
class _SpecDetectStep extends StatelessWidget {
  final int? cpuCores;
  final int? ramMb;
  final String? suggestedModel;
  final bool detected;

  const _SpecDetectStep({
    required this.cpuCores,
    required this.ramMb,
    required this.suggestedModel,
    required this.detected,
  });

  String _ramLabel(int mb) {
    if (mb >= 1024) return '${(mb / 1024).round()} GB';
    return '$mb MB';
  }

  String _modelLabel(String id) {
    return modelDisplayLabel(id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return _StepContent(
      icon: Icons.memory,
      title: '1. Deteksi Spesifikasi',
      description: detected
          ? 'Sistem Anda siap! Model direkomendasikan berdasarkan spesifikasi.'
          : 'Memeriksa sistem...',
      child: detected
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  _SpecRow(
                    icon: Icons.computer,
                    label: 'CPU Cores',
                    value: '$cpuCores core',
                  ),
                  const SizedBox(height: 12),
                  _SpecRow(
                    icon: Icons.memory_outlined,
                    label: 'RAM',
                    value: _ramLabel(ramMb ?? 8192),
                  ),
                  const SizedBox(height: 12),
                  _SpecRow(
                    icon: Icons.psychology,
                    label: 'Model Rekomendasi',
                    value: _modelLabel(suggestedModel ?? 'tiny'),
                    highlighted: true,
                  ),
                ],
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;

  const _SpecRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Row(
      children: [
        Icon(icon, size: 20, color: highlighted ? colors.primary : colors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: highlighted ? colors.primary : colors.text,
            fontWeight: highlighted ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// Step 2 — Model choice
class _ModelChoiceStep extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ModelChoiceStep({required this.selected, required this.onChanged});

  static const _models = [
    ('base', '⚡ Cepat', '142 MB · ✅ Termasuk di aplikasi\n🇮🇩 ID: Sangat baik · 🇬🇧 EN: Baik\nCocok: transkrip cepat & ringan'),
    ('large-v3-turbo-q5', '🎯 Akurat', '548 MB · ✅ Termasuk di aplikasi\n🇮🇩 ID: ~96% · 🇬🇧 EN: ~97%\n🏆 Akurasi global terbaik — rekomendasi!'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return _StepContent(
      icon: Icons.psychology,
      title: '2. Pilih Model',
      description: 'Pilih model Speech-to-Text yang sesuai.',
      child: Column(
        children: _models.map((m) {
          final isSelected = selected == m.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onChanged(m.$1),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_off,
                      color: isSelected ? colors.primary : colors.textTertiary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.$2, style: TextStyle(
                            color: colors.text,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          )),
                          Text(m.$3, style: TextStyle(
                            color: isSelected ? colors.primary : colors.textTertiary,
                            fontSize: 12,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Step 3 — Audio setup
class _AudioSetupStep extends ConsumerStatefulWidget {
  const _AudioSetupStep();

  @override
  ConsumerState<_AudioSetupStep> createState() => _AudioSetupStepState();
}

class _AudioSetupStepState extends ConsumerState<_AudioSetupStep> {
  bool _loading = true;
  List<AudioDeviceInfo> _inputDevices = [];
  List<AudioDeviceInfo> _outputDevices = [];
  String? _selectedMic;
  String? _selectedSpeaker;
  bool _showGuide = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    final bridge = ref.read(rustBridgeProvider);
    final settings = ref.read(settingsProvider);
    final inputs = await bridge.listAudioDevices();
    final outputs = await bridge.listOutputAudioDevices();
    if (mounted) {
      // Pre-populate from saved prefs if available, otherwise auto-detect.
      final savedMic = settings.micDeviceId;
      final savedSpeaker = settings.speakerDeviceId;
      final mic = savedMic != null && inputs.any((d) => d.name == savedMic)
          ? savedMic
          : (inputs.isNotEmpty
              ? inputs.firstWhere((d) => d.isDefault, orElse: () => inputs.first).name
              : null);
      final speaker = savedSpeaker != null && outputs.any((d) => d.name == savedSpeaker)
          ? savedSpeaker
          : outputs
              .firstWhere(
                (d) => d.name.toLowerCase().contains('blackhole') ||
                    d.name.toLowerCase().contains('loopback'),
                orElse: () => outputs.isNotEmpty
                    ? outputs.first
                    : AudioDeviceInfo(
                        name: 'Default',
                        deviceId: '',
                        isDefault: true,
                        channels: 2,
                        sampleRates: Uint32List(0),
                      ),
              )
              .name;
      setState(() {
        _loading = false;
        _inputDevices = inputs;
        _outputDevices = outputs;
        _selectedMic = mic;
        _selectedSpeaker = speaker;
      });
      // Only auto-save if no preference was already stored.
      final notifier = ref.read(settingsProvider.notifier);
      if (savedMic == null && mic != null) await notifier.setMicDeviceName(mic);
      if (savedSpeaker == null) await notifier.setSpeakerDeviceName(speaker);
    }
  }

  bool get _hasBlackHole => _outputDevices.any(
    (d) => d.name.toLowerCase().contains('blackhole') || d.name.toLowerCase().contains('loopback'),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return _StepContent(
      icon: Icons.speaker_group_outlined,
      title: '3. Setup Audio',
      description: 'Pilih perangkat input mikrofon dan output speaker.',
      child: _loading
          ? const CircularProgressIndicator()
          : Column(
              children: [
                _AudioDropdown(
                  label: 'Mikrofon (Input)',
                  value: _selectedMic,
                  devices: _inputDevices,
                  onChanged: (v) {
                    setState(() => _selectedMic = v);
                    ref.read(settingsProvider.notifier).setMicDeviceName(v);
                  },
                ),
                const SizedBox(height: 12),
                _AudioDropdown(
                  label: 'Speaker / Loopback (Output)',
                  value: _selectedSpeaker,
                  devices: _outputDevices,
                  onChanged: (v) {
                    setState(() => _selectedSpeaker = v);
                    ref.read(settingsProvider.notifier).setSpeakerDeviceName(v);
                  },
                ),
                const SizedBox(height: 16),
                // BlackHole status
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _hasBlackHole
                        ? AppColors.statusActive.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _hasBlackHole
                          ? AppColors.statusActive.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasBlackHole ? Icons.check_circle_outline : Icons.info_outline,
                            color: _hasBlackHole ? AppColors.statusActive : Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _hasBlackHole
                                  ? 'BlackHole 2ch terdeteksi!'
                                  : 'Virtual Audio Driver belum terinstall',
                              style: TextStyle(
                                color: _hasBlackHole ? AppColors.statusActive : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!_hasBlackHole) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Untuk merekam suara dari Zoom/Meet, install BlackHole 2ch.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _showGuide = !_showGuide),
                          icon: Icon(_showGuide ? Icons.expand_less : Icons.help_outline, size: 16),
                          label: Text(_showGuide ? 'Sembunyikan' : 'Panduan Install'),
                          style: OutlinedButton.styleFrom(foregroundColor: colors.text),
                        ),
                        if (_showGuide) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.chipBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '1. brew install blackhole-2ch\n2. Buka Audio MIDI Setup\n3. Buat Multi-Output Device\n4. Centang MacBook Pro Speakers + BlackHole 2ch',
                              style: TextStyle(fontSize: 12, height: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _AudioDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<AudioDeviceInfo> devices;
  final ValueChanged<String?> onChanged;

  const _AudioDropdown({
    required this.label,
    required this.value,
    required this.devices,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: colors.surface,
        style: TextStyle(color: colors.text, fontSize: 14),
        items: devices.isNotEmpty
            ? devices.map((d) => DropdownMenuItem(value: d.name, child: Text(d.name))).toList()
            : [DropdownMenuItem(value: value, child: Text(value ?? 'Default'))],
        onChanged: onChanged,
      ),
    );
  }
}

/// Step 5 — Tone test
class _ToneTestStep extends StatefulWidget {
  const _ToneTestStep();

  @override
  State<_ToneTestStep> createState() => _ToneTestStepState();
}

class _ToneTestStepState extends State<_ToneTestStep> {
  bool _isPlaying = false;
  bool _tested = false;
  AudioPlayer? _player;

  /// Generates a 440 Hz sine wave as a PCM WAV in memory.
  static Uint8List _generate440HzWav() {
    const sampleRate = 22050;
    const frequency = 440.0;
    const numSamples = sampleRate; // 1 second
    const amplitude = 16000;
    const fadeLen = sampleRate ~/ 20; // 50 ms fade-in/out to avoid clicks

    final dataBytes = numSamples * 2;
    final wav = ByteData(44 + dataBytes);

    // RIFF header
    for (final pair in [
      [0, 0x52], [1, 0x49], [2, 0x46], [3, 0x46], // "RIFF"
      [8, 0x57], [9, 0x41], [10, 0x56], [11, 0x45], // "WAVE"
      [12, 0x66], [13, 0x6D], [14, 0x74], [15, 0x20], // "fmt "
      [36, 0x64], [37, 0x61], [38, 0x74], [39, 0x61], // "data"
    ]) { wav.setUint8(pair[0], pair[1]); }
    wav.setUint32(4, 36 + dataBytes, Endian.little);
    wav.setUint32(16, 16, Endian.little);   // fmt chunk size
    wav.setUint16(20, 1, Endian.little);    // PCM
    wav.setUint16(22, 1, Endian.little);    // mono
    wav.setUint32(24, sampleRate, Endian.little);
    wav.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    wav.setUint16(32, 2, Endian.little);    // block align
    wav.setUint16(34, 16, Endian.little);   // bits/sample
    wav.setUint32(40, dataBytes, Endian.little);

    for (var i = 0; i < numSamples; i++) {
      double envelope = 1.0;
      if (i < fadeLen) envelope = i / fadeLen;
      if (i > numSamples - fadeLen) envelope = (numSamples - i) / fadeLen;
      final sample = (amplitude * envelope *
              math.sin(2 * math.pi * frequency * i / sampleRate))
          .round()
          .clamp(-32768, 32767);
      wav.setInt16(44 + i * 2, sample, Endian.little);
    }

    return wav.buffer.asUint8List();
  }

  Future<void> _startToneTest() async {
    setState(() => _isPlaying = true);

    final player = AudioPlayer();
    _player = player;
    try {
      await player.play(BytesSource(_generate440HzWav()));
      await player.onPlayerComplete.first;
    } catch (_) {
      // Playback failure — still mark tested so the user can proceed
    } finally {
      if (_player == player) _player = null;
      try {
        await player.dispose();
      } catch (_) {
        // Already disposed elsewhere (e.g. widget disposed mid-test)
      }
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _tested = true;
      });
    }
  }

  @override
  void dispose() {
    final player = _player;
    _player = null;
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return _StepContent(
      icon: Icons.graphic_eq,
      title: '4. Tone Test',
      description: 'Putar nada 440 Hz untuk memastikan speaker berfungsi.',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isPlaying ? colors.primary : colors.border),
        ),
        child: Column(
          children: [
            if (_tested) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.statusActive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.statusActive.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.statusActive, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Speaker berfungsi dengan baik',
                        style: TextStyle(
                          color: AppColors.statusActive,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.chipBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colors.textSecondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tes mikrofon akan aktif saat sesi dimulai',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _isPlaying ? null : () => _startToneTest(),
              icon: Icon(_isPlaying ? Icons.graphic_eq : Icons.play_arrow),
              label: Text(_isPlaying ? 'Memutar...' : (_tested ? 'Putar Ulang' : 'Putar Nada Uji')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
