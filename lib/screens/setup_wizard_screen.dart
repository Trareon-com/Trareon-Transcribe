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
import '../utils/system_specs.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

class WizardSpecs {
  final int cpuCores;
  final int ramMb;
  final String suggestedModel;

  /// True when [ramMb] is the cores-based fallback rather than a reading
  /// from the OS. Shown to the user: a guess presented as a measurement is
  /// what the audit flagged (A.6, P2).
  final bool ramIsEstimate;

  const WizardSpecs({
    required this.cpuCores,
    required this.ramMb,
    required this.suggestedModel,
    this.ramIsEstimate = false,
  });
}

typedef WizardSpecDetector = Future<WizardSpecs> Function();

class SetupWizardScreen extends ConsumerStatefulWidget {
  final VoidCallback onFinished;
  final WizardSpecDetector? detectSpecs;

  /// Shown as a "Tutup" affordance when the wizard is re-run from
  /// Settings rather than driven once at first launch.
  final VoidCallback? onCancel;

  const SetupWizardScreen({
    super.key,
    required this.onFinished,
    this.detectSpecs,
    this.onCancel,
  });

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
  bool _ramIsEstimate = false;
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
        _ramIsEstimate = specs.ramIsEstimate;
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
    // Real reading on Linux (/proc/meminfo), macOS (sysctl) and Windows
    // (CIM); only if all three fail does this fall back to a guess, and
    // then it says so. See utils/system_specs.dart.
    final ram = await detectTotalRam(coreCount: cores);
    return WizardSpecs(
      cpuCores: cores,
      ramMb: ram.megabytes,
      suggestedModel: _suggestModel(ram.megabytes),
      ramIsEstimate: ram.isEstimate,
    );
  }

  String _suggestModel(int ramMb) {
    if (ramMb >= 8192) return 'large-v3-turbo-q5'; // 8GB+
    return 'base'; // < 8GB
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
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xxl,
                  vertical: Spacing.lg,
                ),
                child: _buildStepBody(),
              ),
            ),

            // Navigation buttons
            _WizardNavigation(
              isFirst: _stepIndex == 0,
              isLast: _stepIndex == _steps.length - 1,
              onBack: _back,
              onNext: _next,
              onCancel: widget.onCancel,
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
          ramIsEstimate: _ramIsEstimate,
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
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xxl,
        vertical: Spacing.md,
      ),
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
                          borderRadius: BorderRadius.circular(Radii.xs),
                          color: isDone || isActive
                              ? colors.primary
                              : colors.border,
                        ),
                      ),
                    ),
                    if (i < total - 1) Spacing.hSm,
                  ],
                ),
              );
            }),
          ),
          Spacing.gapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Langkah ${step + 1} dari $total',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: FontSizes.body,
                ),
              ),
              Text(
                '${((step + 1) / total * 100).round()}%',
                style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: FontSizes.caption,
                ),
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

  /// Present when the wizard was opened from Settings rather than run once
  /// at first launch, so the user can leave without walking all four steps.
  final VoidCallback? onCancel;

  const _WizardNavigation({
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: isFirst ? null : onBack,
                icon: const Icon(AppIcons.back, size: IconSizes.xs),
                label: const Text('Kembali'),
                style: TextButton.styleFrom(
                  foregroundColor: isFirst ? colors.textTertiary : colors.text,
                ),
              ),
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                  ),
                  child: const Text('Tutup'),
                ),
            ],
          ),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xl,
                vertical: Spacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
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
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
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
          child: Icon(icon, size: IconSizes.hero, color: colors.primary),
        ),
        Spacing.gapLg,
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: FontSizes.headline,
            fontWeight: FontWeight.bold,
          ),
        ),
        Spacing.gapMd,
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: FontSizes.bodyLarge,
            height: 1.5,
          ),
        ),
        if (child != null) ...[Spacing.gapXl, child!],
      ],
    );
  }
}

/// Step 1 — System spec detection with real data
class _SpecDetectStep extends StatelessWidget {
  final int? cpuCores;
  final int? ramMb;
  final bool ramIsEstimate;
  final String? suggestedModel;
  final bool detected;

  const _SpecDetectStep({
    required this.cpuCores,
    required this.ramMb,
    required this.ramIsEstimate,
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
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return _StepContent(
      icon: AppIcons.chip,
      title: '1. Deteksi Spesifikasi',
      description: detected
          ? 'Sistem Anda siap! Model direkomendasikan berdasarkan spesifikasi.'
          : 'Memeriksa sistem…',
      child: detected
          ? Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  _SpecRow(
                    icon: AppIcons.computer,
                    label: 'Inti Prosesor',
                    value: '$cpuCores core',
                  ),
                  Spacing.gapMd,
                  _SpecRow(
                    icon: AppIcons.chip,
                    label: ramIsEstimate ? 'RAM (perkiraan)' : 'RAM',
                    value: ramMb == null
                        ? 'tidak diketahui'
                        : _ramLabel(ramMb!),
                  ),
                  Spacing.gapMd,
                  _SpecRow(
                    icon: AppIcons.model,
                    label: 'Model Disarankan',
                    value: _modelLabel(suggestedModel ?? 'base'),
                    highlighted: true,
                  ),
                ],
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(Spacing.lg),
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
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Row(
      children: [
        Icon(
          icon,
          size: IconSizes.lg,
          color: highlighted ? colors.primary : colors.textSecondary,
        ),
        Spacing.hMd,
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: FontSizes.body,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: highlighted ? colors.primary : colors.text,
            fontWeight: highlighted ? FontWeight.bold : FontWeight.normal,
            fontSize: FontSizes.body,
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

  // No accuracy percentages: nothing in this repository measures them,
  // and the audit flagged the old "🇮🇩 ID: ~96%" as an unsupported claim
  // (A.6, P3). Relative speed and size are things we do know.
  static const _models = [
    (
      'base',
      '⚡ Cepat',
      '142 MB · termasuk di aplikasi\nTranskrip muncul cepat, cocok untuk '
          'komputer ringan dan catatan sehari-hari.',
    ),
    (
      'large-v3-turbo-q5',
      '🎯 Akurat',
      '548 MB · unduh sekali\nLebih teliti untuk rapat dan wawancara, tapi '
          'jauh lebih lambat di komputer tanpa GPU.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return _StepContent(
      icon: AppIcons.model,
      title: '2. Pilih Model',
      description: 'Pilih model Speech-to-Text yang sesuai.',
      child: Column(
        children: _models.map((m) {
          final isSelected = selected == m.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: InkWell(
              onTap: () => onChanged(m.$1),
              borderRadius: BorderRadius.circular(Radii.md),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.1)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? AppIcons.checkFilled : AppIcons.radioOff,
                      color: isSelected ? colors.primary : colors.textTertiary,
                      size: IconSizes.lg,
                    ),
                    Spacing.hMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.$2,
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: FontSizes.bodyLarge,
                            ),
                          ),
                          Text(
                            m.$3,
                            style: TextStyle(
                              color: isSelected
                                  ? colors.primary
                                  : colors.textTertiary,
                              fontSize: FontSizes.caption,
                            ),
                          ),
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
                ? inputs
                      .firstWhere(
                        (d) => d.isDefault,
                        orElse: () => inputs.first,
                      )
                      .name
                : null);
      final speaker =
          savedSpeaker != null && outputs.any((d) => d.name == savedSpeaker)
          ? savedSpeaker
          : outputs
                .firstWhere(
                  (d) =>
                      d.name.toLowerCase().contains('blackhole') ||
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

  /// Whether a loopback path for system audio looks available.
  ///
  /// What counts differs per platform, and the wizard used to assert the
  /// macOS answer everywhere: a Linux user was told to `brew install` a
  /// macOS kernel extension (audit A.6, P1).
  bool get _loopbackReady {
    if (Platform.isMacOS) {
      return _outputDevices.any(
        (d) =>
            d.name.toLowerCase().contains('blackhole') ||
            d.name.toLowerCase().contains('loopback'),
      );
    }
    if (Platform.isLinux) {
      // PipeWire/PulseAudio expose every sink as a `.monitor` source; the
      // engine picks one automatically.
      return _inputDevices.any(
            (d) => d.name.toLowerCase().contains('monitor'),
          ) ||
          _outputDevices.isNotEmpty;
    }
    // Windows: WASAPI loopback needs no driver at all, only an output
    // device to capture from.
    return _outputDevices.isNotEmpty;
  }

  String get _loopbackTitle => _loopbackReady
      ? switch (Platform.operatingSystem) {
          'macos' => 'Driver audio virtual terdeteksi',
          'linux' => 'Suara sistem siap direkam',
          _ => 'Suara sistem siap direkam',
        }
      : switch (Platform.operatingSystem) {
          'macos' => 'Driver audio virtual belum terpasang',
          'linux' => 'Belum ada perangkat keluaran yang bisa direkam',
          _ => 'Belum ada perangkat keluaran yang bisa direkam',
        };

  String get _loopbackBody {
    if (_loopbackReady) {
      return switch (Platform.operatingSystem) {
        'macos' =>
          'Suara dari Zoom/Meet bisa direkam lewat perangkat virtual di atas.',
        'linux' =>
          'Trareon merekam suara sistem lewat monitor sink PipeWire/PulseAudio '
              ', tidak perlu memasang apa pun.',
        _ =>
          'Trareon merekam suara sistem lewat WASAPI loopback, tidak '
              'perlu memasang apa pun.',
      };
    }
    return switch (Platform.operatingSystem) {
      'macos' =>
        'Untuk merekam suara dari Zoom/Meet di macOS, pasang BlackHole 2ch.',
      'linux' =>
        'Pilih perangkat keluaran di atas. Jika daftarnya kosong, pastikan '
            'PipeWire atau PulseAudio berjalan.',
      _ =>
        'Pilih perangkat keluaran di atas. Jika daftarnya kosong, '
            'pastikan perangkat pemutar suara aktif di Windows.',
    };
  }

  String get _loopbackGuide => switch (Platform.operatingSystem) {
    'macos' =>
      '1. brew install blackhole-2ch\n'
          '2. Buka Audio MIDI Setup\n'
          '3. Buat Multi-Output Device\n'
          '4. Centang pengeras suara Mac Anda + BlackHole 2ch',
    'linux' =>
      '1. Pastikan PipeWire atau PulseAudio berjalan\n'
          '2. Jalankan: pactl list short sources\n'
          '3. Pilih sumber yang berakhiran .monitor di daftar di atas',
    _ =>
      '1. Buka Pengaturan Suara Windows\n'
          '2. Pastikan ada perangkat keluaran yang aktif\n'
          '3. Pilih perangkat itu di daftar di atas',
  };

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final ready = _loopbackReady;
    final accent = ready ? colors.success : colors.warning;
    return _StepContent(
      icon: AppIcons.speakers,
      title: '3. Siapkan Audio',
      description: 'Pilih perangkat mikrofon dan pengeras suara.',
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
                Spacing.gapMd,
                _AudioDropdown(
                  label: 'Pengeras Suara / Suara Sistem (Output)',
                  value: _selectedSpeaker,
                  devices: _outputDevices,
                  onChanged: (v) {
                    setState(() => _selectedSpeaker = v);
                    ref.read(settingsProvider.notifier).setSpeakerDeviceName(v);
                  },
                ),
                Spacing.gapLg,
                Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ready ? AppIcons.check : AppIcons.info,
                            color: accent,
                            size: IconSizes.md,
                          ),
                          Spacing.hSm,
                          Expanded(
                            child: Text(
                              _loopbackTitle,
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.bold,
                                fontSize: FontSizes.body,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Spacing.gapSm,
                      Text(
                        _loopbackBody,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: FontSizes.caption,
                        ),
                      ),
                      if (!ready) ...[
                        Spacing.gapSm,
                        OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _showGuide = !_showGuide),
                          icon: Icon(
                            _showGuide ? AppIcons.expandLess : AppIcons.help,
                            size: IconSizes.sm,
                          ),
                          label: Text(_showGuide ? 'Sembunyikan' : 'Panduan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.text,
                          ),
                        ),
                        if (_showGuide) ...[
                          Spacing.gapSm,
                          Container(
                            padding: const EdgeInsets.all(Spacing.sm),
                            decoration: BoxDecoration(
                              color: colors.chipBackground,
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: Text(
                              _loopbackGuide,
                              style: const TextStyle(
                                fontSize: FontSizes.caption,
                                height: 1.5,
                              ),
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
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    // The label used to be a constructor parameter the widget never
    // rendered, so both pickers were unlabelled dropdowns of device ids.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Spacing.xs, bottom: Spacing.xs),
          child: Text(
            label,
            style: TextStyle(
              fontSize: FontSizes.micro,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: colors.border),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: colors.surface,
            style: AppText.reading.c(colors.text),
            items: devices.isNotEmpty
                ? devices
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.name,
                          child: Text(d.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList()
                : [
                    DropdownMenuItem(
                      value: value,
                      child: Text(value ?? 'Bawaan sistem'),
                    ),
                  ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Step 4 — speaker check.
///
/// The old version played a tone, swallowed any playback exception, marked
/// itself `_tested = true` regardless, and then asserted "Speaker berfungsi
/// dengan baik" — a false positive on exactly the machine that needed the
/// warning. It also never asked the only question that makes this a test
/// (audit A.6, P2).
class _ToneTestStep extends StatefulWidget {
  const _ToneTestStep();

  @override
  State<_ToneTestStep> createState() => _ToneTestStepState();
}

enum _ToneOutcome { untested, heard, notHeard, playbackFailed }

class _ToneTestStepState extends State<_ToneTestStep> {
  bool _isPlaying = false;

  /// True once a tone has finished playing and the user has been asked.
  bool _awaitingAnswer = false;

  _ToneOutcome _outcome = _ToneOutcome.untested;
  String? _playbackError;
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
    ]) {
      wav.setUint8(pair[0], pair[1]);
    }
    wav.setUint32(4, 36 + dataBytes, Endian.little);
    wav.setUint32(16, 16, Endian.little); // fmt chunk size
    wav.setUint16(20, 1, Endian.little); // PCM
    wav.setUint16(22, 1, Endian.little); // mono
    wav.setUint32(24, sampleRate, Endian.little);
    wav.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    wav.setUint16(32, 2, Endian.little); // block align
    wav.setUint16(34, 16, Endian.little); // bits/sample
    wav.setUint32(40, dataBytes, Endian.little);

    for (var i = 0; i < numSamples; i++) {
      double envelope = 1.0;
      if (i < fadeLen) envelope = i / fadeLen;
      if (i > numSamples - fadeLen) envelope = (numSamples - i) / fadeLen;
      final sample =
          (amplitude *
                  envelope *
                  math.sin(2 * math.pi * frequency * i / sampleRate))
              .round()
              .clamp(-32768, 32767);
      wav.setInt16(44 + i * 2, sample, Endian.little);
    }

    return wav.buffer.asUint8List();
  }

  Future<void> _startToneTest() async {
    setState(() {
      _isPlaying = true;
      _playbackError = null;
      _awaitingAnswer = false;
      _outcome = _ToneOutcome.untested;
    });

    final player = AudioPlayer();
    _player = player;
    String? error;
    try {
      await player.play(BytesSource(_generate440HzWav()));
      await player.onPlayerComplete.first;
    } catch (e) {
      error = '$e';
    } finally {
      if (_player == player) _player = null;
      try {
        await player.dispose();
      } catch (_) {
        // Already disposed elsewhere (e.g. widget disposed mid-test)
      }
    }

    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      if (error != null) {
        _playbackError = error;
        _outcome = _ToneOutcome.playbackFailed;
      } else {
        _awaitingAnswer = true;
      }
    });
  }

  @override
  void dispose() {
    final player = _player;
    _player = null;
    player?.dispose();
    super.dispose();
  }

  String get _remediation => switch (Platform.operatingSystem) {
    'macos' =>
      'Buka Pengaturan Sistem → Suara, naikkan volume, dan pastikan '
          'perangkat keluaran yang benar terpilih.',
    'linux' =>
      'Periksa volume di pavucontrol atau pengaturan suara desktop Anda, '
          'lalu pastikan perangkat keluaran yang benar terpilih.',
    _ =>
      'Buka Pengaturan Suara Windows, naikkan volume, dan pastikan '
          'perangkat keluaran yang benar terpilih.',
  };

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return _StepContent(
      icon: AppIcons.waveform,
      title: '4. Uji Suara',
      description:
          'Putar nada 440 Hz untuk memastikan pengeras suara berfungsi.',
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: _isPlaying ? colors.primary : colors.border,
          ),
        ),
        child: Column(
          children: [
            if (_awaitingAnswer) ...[
              Text(
                'Apakah Anda mendengar nadanya?',
                style: TextStyle(
                  color: colors.text,
                  fontSize: FontSizes.bodyLarge,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacing.gapSm,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () => setState(() {
                      _awaitingAnswer = false;
                      _outcome = _ToneOutcome.heard;
                    }),
                    child: const Text('Ya, terdengar'),
                  ),
                  Spacing.hSm,
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _awaitingAnswer = false;
                      _outcome = _ToneOutcome.notHeard;
                    }),
                    child: const Text('Tidak terdengar'),
                  ),
                ],
              ),
              Spacing.gapLg,
            ],
            if (_outcome == _ToneOutcome.heard) ...[
              _ToneResultCard(
                color: colors.success,
                icon: AppIcons.checkFilled,
                title: 'Pengeras suara berfungsi',
                body: 'Tes mikrofon akan aktif saat sesi dimulai.',
              ),
              Spacing.gapLg,
            ],
            if (_outcome == _ToneOutcome.notHeard) ...[
              _ToneResultCard(
                color: colors.warning,
                icon: AppIcons.volumeOff,
                title: 'Nada tidak terdengar',
                body: _remediation,
              ),
              Spacing.gapLg,
            ],
            if (_outcome == _ToneOutcome.playbackFailed) ...[
              _ToneResultCard(
                color: colors.error,
                icon: AppIcons.error,
                title: 'Nada gagal diputar',
                body: '${_playbackError ?? ''}\n$_remediation',
              ),
              Spacing.gapLg,
            ],
            FilledButton.icon(
              onPressed: _isPlaying ? null : _startToneTest,
              icon: Icon(_isPlaying ? AppIcons.waveform : AppIcons.play),
              label: Text(
                _isPlaying
                    ? 'Memutar…'
                    : (_outcome == _ToneOutcome.untested && !_awaitingAnswer
                          ? 'Putar Nada Uji'
                          : 'Putar Ulang'),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToneResultCard extends StatelessWidget {
  const _ToneResultCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: IconSizes.lg),
          Spacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: FontSizes.body,
                  ),
                ),
                Spacing.gapXs,
                Text(
                  body,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: FontSizes.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
