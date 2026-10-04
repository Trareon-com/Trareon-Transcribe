/// The two control groups the redesign asks for (blueprint §4.3):
/// **Sesi** (title, mode, per-session options) and **Perangkat** (mic and
/// speaker, each with the device it will actually use and a live level).
///
/// The old control bar was nine controls in three undifferentiated rows,
/// with "⚡ Cepat" glued to the title field and no way to see — let alone
/// change — which microphone was about to be recorded.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/audio/device.dart' as rust_device;
import '../state/models.dart';
import '../state/session_model.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/model_labels.dart';
import '../widgets/mode_selector.dart';
import 'model_download_dialog.dart';
import '../theme/app_icons.dart';

class ControlGroup extends StatelessWidget {
  const ControlGroup({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Spacing.xs, bottom: Spacing.xs),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: FontSizes.overline,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: colors.textTertiary,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Title, mode, and the per-session options menu that "⚡ Cepat" moved into.
class SessionGroup extends ConsumerWidget {
  const SessionGroup({
    super.key,
    required this.titleController,
    required this.onTitleChanged,
    required this.mode,
    required this.onModeChanged,
    required this.modeLocked,
  });

  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final SessionMode mode;
  final ValueChanged<SessionMode> onModeChanged;

  /// Mode cannot change mid-session: the capture threads are already
  /// running against the previous one.
  final bool modeLocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return ControlGroup(
      title: 'Sesi',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            height: 36,
            child: TextField(
              controller: titleController,
              onChanged: onTitleChanged,
              onSubmitted: onTitleChanged,
              style: TextStyle(color: colors.text, fontSize: FontSizes.body),
              decoration: InputDecoration(
                hintText: 'Judul sesi...',
                hintStyle: TextStyle(color: colors.textTertiary, fontSize: FontSizes.body),
                prefixIcon:
                    Icon(AppIcons.edit, size: IconSizes.sm, color: colors.textTertiary),
                filled: true,
                fillColor: colors.chipBackground,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: modeLocked,
            child: Opacity(
              opacity: modeLocked ? 0.5 : 1.0,
              child: ModeSelector(selected: mode, onChanged: onModeChanged),
            ),
          ),
          const SessionOptionsMenu(),
          const SessionGlossaryPill(),
        ],
      ),
    );
  }
}

/// Per-session kamus istilah (F3): terms that matter for *this* meeting only.
///
/// Separate from the global list in Settings because the two have different
/// lifetimes and different priorities — the names of today's attendees are not
/// vocabulary the office always wants, and when Whisper's 224-token prompt
/// cannot hold everything these are the terms that must survive.
class SessionGlossaryPill extends ConsumerWidget {
  const SessionGlossaryPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final terms = ref.watch(sessionProvider).sessionGlossaryTerms;
    final globalCount = ref.watch(settingsProvider).glossary.terms.length;

    return Tooltip(
      message: 'Istilah khusus rapat ini, di atas $globalCount istilah '
          'di Pengaturan',
      child: InkWell(
        borderRadius: Radii.smAll,
        onTap: () => _edit(context, ref, terms),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: colors.chipBackground,
            borderRadius: Radii.smAll,
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.glossary,
                  size: IconSizes.sm, color: colors.textSecondary),
              const SizedBox(width: Spacing.sm),
              Text(
                terms.isEmpty ? 'Istilah rapat' : 'Istilah rapat (${terms.length})',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: FontSizes.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    List<String> terms,
  ) async {
    final controller = TextEditingController(text: terms.join('\n'));
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Istilah khusus rapat ini'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Satu istilah per baris: nama peserta, singkatan, nama '
                'program. Diutamakan di atas kamus di Pengaturan.',
              ),
              Spacing.gapMd,
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Pak Budi Santoso\nSPBE\nRKAKL',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null) return;
    ref.read(sessionProvider.notifier).setSessionGlossaryTerms(
          saved.split(RegExp(r'[,\n;]')),
          global: ref.read(settingsProvider).glossary,
        );
  }
}

/// Per-session options. Holds the quality switch that used to sit next to
/// the title field competing with it for attention (blueprint §4.2).
class SessionOptionsMenu extends ConsumerWidget {
  const SessionOptionsMenu({super.key});

  static const _accurateId = 'large-v3-turbo-q5';
  static const _quickId = 'base';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final isAccurate = settings.defaultModel == _accurateId;

    Future<void> chooseModel(String modelId) async {
      if (!isModelAvailable(modelId, libraryPath: settings.libraryPath)) {
        final ok = await showModelDownloadDialog(
          context: context,
          bridge: ref.read(rustBridgeProvider),
          modelId: modelId,
          modelsDir: resolveTilde(settings.libraryPath),
          displayName: modelDisplayLabel(modelId),
        );
        if (!ok) return;
      }
      await notifier.setDefaultModel(modelId);
    }

    return PopupMenuButton<String>(
      tooltip: 'Opsi sesi',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        switch (value) {
          case 'quick':
            chooseModel(_quickId);
          case 'accurate':
            chooseModel(_accurateId);
          case 'vad':
            notifier.setVadEnabled(!settings.vadEnabled);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('Kualitas transkripsi'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'quick',
          checked: !isAccurate,
          child: const Text('⚡ Cepat — muncul lebih dulu'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'accurate',
          checked: isAccurate,
          child: const Text('🎯 Akurat — lebih teliti, lebih lambat'),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<String>(
          value: 'vad',
          checked: settings.vadEnabled,
          child: const Text('Lewati jeda sunyi'),
        ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        decoration: BoxDecoration(
          color: colors.chipBackground,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAccurate ? '🎯' : '⚡', style: const TextStyle(fontSize: FontSizes.caption)),
            Spacing.hSm,
            Text(
              isAccurate ? 'Akurat' : 'Cepat',
              style: TextStyle(color: colors.textSecondary, fontSize: FontSizes.caption),
            ),
            Spacing.hXs,
            Icon(AppIcons.expandMore, size: IconSizes.sm, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Mic and speaker, each as a pill: on/off, the device that will actually
/// be recorded, and a live level while the session runs.
class DeviceGroup extends ConsumerStatefulWidget {
  const DeviceGroup({
    super.key,
    required this.micEnabled,
    required this.speakerEnabled,
    required this.onMicToggled,
    required this.onSpeakerToggled,
    required this.micLevel,
    required this.speakerLevel,
    required this.live,
  });

  final bool micEnabled;
  final bool speakerEnabled;
  final ValueChanged<bool> onMicToggled;
  final ValueChanged<bool> onSpeakerToggled;
  final double micLevel;
  final double speakerLevel;

  /// True while a session is running — the level bars only mean something
  /// then.
  final bool live;

  @override
  ConsumerState<DeviceGroup> createState() => _DeviceGroupState();
}

class _DeviceGroupState extends ConsumerState<DeviceGroup> {
  List<rust_device.AudioDeviceInfo> _inputs = const [];
  List<rust_device.AudioDeviceInfo> _outputs = const [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final bridge = ref.read(rustBridgeProvider);
    try {
      final inputs = await bridge.listAudioDevices();
      final outputs = await bridge.listOutputAudioDevices();
      if (!mounted) return;
      setState(() {
        _inputs = inputs;
        _outputs = outputs;
      });
    } catch (_) {
      // No engine (tests) or no audio server: the pills still render and
      // say "Bawaan sistem" rather than the screen failing to build.
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return ControlGroup(
      title: 'Perangkat',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          DevicePill(
            icon: AppIcons.mic,
            label: 'Mikrofon',
            enabled: widget.micEnabled,
            onToggled: widget.onMicToggled,
            devices: _inputs.map((d) => d.name).toList(),
            selected: settings.micDeviceId,
            onDeviceSelected: notifier.setMicDeviceName,
            level: widget.micLevel,
            showLevel: widget.live && widget.micEnabled,
            accent: colors.success,
            onRefresh: _loadDevices,
          ),
          DevicePill(
            icon: AppIcons.systemAudio,
            label: 'Suara sistem',
            enabled: widget.speakerEnabled,
            onToggled: widget.onSpeakerToggled,
            devices: _outputs.map((d) => d.name).toList(),
            selected: settings.speakerDeviceId,
            onDeviceSelected: notifier.setSpeakerDeviceName,
            level: widget.speakerLevel,
            showLevel: widget.live && widget.speakerEnabled,
            accent: colors.warning,
            onRefresh: _loadDevices,
          ),
        ],
      ),
    );
  }
}

class DevicePill extends StatelessWidget {
  const DevicePill({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onToggled,
    required this.devices,
    required this.selected,
    required this.onDeviceSelected,
    required this.level,
    required this.showLevel,
    required this.accent,
    required this.onRefresh,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggled;
  final List<String> devices;
  final String? selected;
  final ValueChanged<String?> onDeviceSelected;
  final double level;
  final bool showLevel;
  final Color accent;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final deviceLabel = selected ?? 'Bawaan sistem';
    return Container(
      width: 244,
      padding: const EdgeInsets.fromLTRB(Spacing.sm, Spacing.sm, Spacing.sm, Spacing.sm),
      decoration: BoxDecoration(
        color: enabled ? accent.withValues(alpha: 0.08) : colors.chipBackground,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: enabled ? accent.withValues(alpha: 0.45) : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: IconSizes.sm, color: enabled ? accent : colors.textTertiary),
              Spacing.hSm,
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: FontSizes.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Semantics(
                label: '$label ${enabled ? 'aktif' : 'mati'}',
                toggled: enabled,
                child: Switch(
                  value: enabled,
                  onChanged: onToggled,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<String>(
                  enabled: devices.isNotEmpty,
                  tooltip: 'Pilih perangkat $label',
                  position: PopupMenuPosition.under,
                  onSelected: onDeviceSelected,
                  itemBuilder: (context) => [
                    for (final device in devices)
                      PopupMenuItem<String>(
                        value: device,
                        child: Text(device, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          deviceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: FontSizes.micro,
                          ),
                        ),
                      ),
                      Icon(AppIcons.expandMore,
                          size: IconSizes.xs, color: colors.textTertiary),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.refresh, size: IconSizes.xs),
                tooltip: 'Muat ulang daftar perangkat',
                onPressed: onRefresh,
                color: colors.textTertiary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          if (showLevel)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs, right: Spacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.xs),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: level.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    color: accent,
                    backgroundColor: colors.border.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
