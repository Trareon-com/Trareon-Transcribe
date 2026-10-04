/// The session and device controls on the main screen.
///
/// Blueprint §4.3 asks for two groups, *Sesi* and *Perangkat*;
/// `docs/DESIGN-SYSTEM.md` §7.1 says what they look like. The mode decision
/// also appears on the idle hero as three explained cards, because a bare
/// three-way segmented control tells a first-time user nothing about what each
/// mode actually captures.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/audio/device.dart' as rust_device;
import '../state/models.dart';
import '../state/session_model.dart';
import '../state/settings_model.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../utils/model_labels.dart';
import 'model_download_dialog.dart';
import 'ui/app_button.dart';
import 'ui/app_controls.dart';
import 'ui/app_dialog.dart';
import 'ui/app_feedback.dart';
import 'ui/app_field.dart';
import 'ui/app_surface.dart';
import 'ui/interactive.dart';

/// A labelled group of controls.
class ControlGroup extends StatelessWidget {
  const ControlGroup({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: Spacing.xs / 2,
            bottom: Spacing.xs + 2,
          ),
          child: AppGroupLabel(title),
        ),
        child,
      ],
    );
  }
}

/// Title, mode, per-session glossary and the quality menu.
///
/// Named `SessionControlGroup` rather than `SessionGroup`: the sidebar owns
/// `SessionGroup` as the name of a date bucket, and two different meanings of
/// the same identifier in one screen is how an import ambiguity starts.
class SessionControlGroup extends ConsumerWidget {
  const SessionControlGroup({
    super.key,
    required this.titleController,
    required this.onTitleChanged,
    required this.mode,
    required this.onModeChanged,
    required this.modeLocked,
    this.showMode = true,
  });

  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final SessionMode mode;
  final ValueChanged<SessionMode> onModeChanged;

  /// Mode cannot change mid-session: the capture threads are already running
  /// against the previous one.
  final bool modeLocked;

  /// False on the recording strip, where the mode is already decided and the
  /// space belongs to the timer.
  final bool showMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ControlGroup(
      title: 'Sesi',
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: Measure.sidebar,
            child: AppTextField(
              controller: titleController,
              placeholder: 'Judul sesi…',
              prefixIcon: AppIcons.edit,
              onChanged: onTitleChanged,
              onSubmitted: onTitleChanged,
              reserveHelperSpace: false,
            ),
          ),
          if (showMode)
            AppSegmented<SessionMode>(
              semanticLabel: 'Mode sesi',
              enabled: !modeLocked,
              selected: mode,
              onChanged: onModeChanged,
              segments: [
                for (final m in kModeOrder)
                  AppSegment(
                    value: m,
                    label: m.label,
                    icon: modeIcon(m),
                    semanticLabel: modeSemantics(m),
                  ),
              ],
            ),
          const SessionOptionsMenu(),
          const SessionGlossaryPill(),
        ],
      ),
    );
  }
}

/// The order the three modes are *shown* in, everywhere they appear.
///
/// `SessionMode.values` is `webinar, online, offline`, which mirrors the Rust
/// discriminants and must not be reordered. Presentation goes from the
/// simplest setup to the most passive one, and puts the default (Rapat Online)
/// in the middle where the eye lands.
const List<SessionMode> kModeOrder = [
  SessionMode.offline,
  SessionMode.online,
  SessionMode.webinar,
];

/// The glyph each capture mode is shown with, everywhere it appears.
IconData modeIcon(SessionMode mode) => switch (mode) {
  SessionMode.offline => AppIcons.mic,
  SessionMode.online => AppIcons.meetingRoom,
  SessionMode.webinar => AppIcons.systemAudio,
};

/// A full sentence for a screen reader, where the visible label is two words.
String modeSemantics(SessionMode mode) => switch (mode) {
  SessionMode.offline => 'Mode rapat offline: hanya mikrofon',
  SessionMode.online => 'Mode rapat online: mikrofon dan suara sistem',
  SessionMode.webinar => 'Mode webinar: hanya suara sistem',
};

/// One line explaining what a mode captures, shown on the idle hero cards.
String modeExplanation(SessionMode mode) => switch (mode) {
  SessionMode.offline => 'Rapat di satu ruangan. Hanya mikrofon yang direkam.',
  SessionMode.online => 'Zoom, Meet atau Teams. Mikrofon dan suara sistem.',
  SessionMode.webinar => 'Anda hanya menyimak. Hanya suara sistem.',
};

/// Per-session kamus istilah (F3): terms that matter for *this* meeting only.
///
/// Separate from the global list in Settings because the two have different
/// lifetimes and different priorities. When Whisper's 224-token prompt cannot
/// hold everything, these are the terms that survive.
class SessionGlossaryPill extends ConsumerWidget {
  const SessionGlossaryPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final terms = ref.watch(sessionProvider).sessionGlossaryTerms;
    final globalCount = ref.watch(settingsProvider).glossary.terms.length;

    return Interactive(
      onPressed: () => _edit(context, ref, terms),
      borderRadius: Radii.mdAll,
      tooltip:
          'Istilah khusus rapat ini, di atas $globalCount istilah di Pengaturan',
      semanticLabel: terms.isEmpty
          ? 'Istilah rapat, belum ada'
          : 'Istilah rapat, ${terms.length} istilah',
      builder: (context, state) => Container(
        height: ControlSizes.lg,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: state.active ? colors.surfaceSunken : Colors.transparent,
          borderRadius: Radii.mdAll,
          border: Border.all(color: colors.borderInteractive),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.glossary,
              size: IconSizes.sm,
              color: colors.textSecondary,
            ),
            Spacing.hSm,
            Text(
              terms.isEmpty
                  ? 'Istilah rapat'
                  : 'Istilah rapat (${terms.length})',
              style: AppText.label.c(colors.textSecondary),
            ),
          ],
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
    final saved = await showAppDialog<String>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Istilah khusus rapat ini',
        icon: AppIcons.glossary,
        description:
            'Satu istilah per baris: nama peserta, singkatan, nama program. '
            'Diutamakan di atas kamus di Pengaturan.',
        actions: [
          AppButton(
            label: 'Batal',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton.primary(
            label: 'Simpan',
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          ),
        ],
        child: AppTextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          placeholder: 'Pak Budi Santoso\nSPBE\nRKAKL',
          reserveHelperSpace: false,
        ),
      ),
    );
    controller.dispose();
    if (saved == null) return;
    ref
        .read(sessionProvider.notifier)
        .setSessionGlossaryTerms(
          saved.split(RegExp(r'[,\n;]')),
          global: ref.read(settingsProvider).glossary,
        );
  }
}

/// Per-session options: the quality switch that used to sit next to the title
/// field competing with it for attention (blueprint §4.2).
///
/// The two quality options used to be labelled with a lightning-bolt and a
/// dart emoji. Emoji as UI icons is a tell, and neither glyph renders the same
/// on the three platforms the owner is testing.
class SessionOptionsMenu extends ConsumerWidget {
  const SessionOptionsMenu({super.key});

  static const _accurateId = 'large-v3-turbo-q5';
  static const _quickId = 'base';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = context.colors;
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

    return AppMenu<String>(
      tooltip: 'Opsi sesi',
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
      entries: [
        const AppMenuEntry.header('Kualitas transkripsi'),
        AppMenuEntry(
          value: 'quick',
          label: 'Cepat, muncul lebih dulu',
          checked: !isAccurate,
        ),
        AppMenuEntry(
          value: 'accurate',
          label: 'Akurat, lebih teliti dan lebih lambat',
          checked: isAccurate,
        ),
        AppMenuEntry(
          value: 'vad',
          label: 'Lewati jeda sunyi',
          checked: settings.vadEnabled,
        ),
      ],
      child: Container(
        height: ControlSizes.lg,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          borderRadius: Radii.mdAll,
          border: Border.all(color: colors.borderInteractive),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAccurate ? AppIcons.accurate : AppIcons.quick,
              size: IconSizes.sm,
              color: colors.textSecondary,
            ),
            Spacing.hSm,
            Text(
              isAccurate ? 'Akurat' : 'Cepat',
              style: AppText.label.c(colors.textSecondary),
            ),
            Spacing.hXs,
            Icon(
              AppIcons.expandMore,
              size: IconSizes.sm,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mic and system audio, each as a status chip: on/off, the device that will
/// actually be recorded, and a live level while the session runs.
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
    this.compact = false,
  });

  final bool micEnabled;
  final bool speakerEnabled;
  final ValueChanged<bool> onMicToggled;
  final ValueChanged<bool> onSpeakerToggled;
  final double micLevel;
  final double speakerLevel;

  /// True while a session is running. The level bars only mean something then.
  final bool live;

  /// Drops the group label, for the recording strip.
  final bool compact;

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
      // No engine (tests) or no audio server: the chips still render and say
      // "Bawaan sistem" rather than the screen failing to build.
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = context.colors;
    final chips = Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        DeviceStatusChip(
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
        DeviceStatusChip(
          icon: AppIcons.systemAudio,
          label: 'Suara sistem',
          enabled: widget.speakerEnabled,
          onToggled: widget.onSpeakerToggled,
          devices: _outputs.map((d) => d.name).toList(),
          selected: settings.speakerDeviceId,
          onDeviceSelected: notifier.setSpeakerDeviceName,
          level: widget.speakerLevel,
          showLevel: widget.live && widget.speakerEnabled,
          accent: colors.info,
          onRefresh: _loadDevices,
        ),
      ],
    );
    if (widget.compact) return chips;
    return ControlGroup(title: 'Perangkat', child: chips);
  }
}

/// One capture source: glyph, name, device picker, toggle, live level.
///
/// The off state is fully neutral and the on state borrows only a hairline of
/// the accent. The old pill filled itself with an 8 % accent wash whether or
/// not anything was recording, which is a large part of why the screen read as
/// teal everywhere.
class DeviceStatusChip extends StatelessWidget {
  const DeviceStatusChip({
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

  /// Width of one capture-source chip. Two of them plus the `sm` gap have to
  /// fit the workspace side by side at the narrowest window the layout still
  /// supports: 800 px total, minus a 260 px sidebar and 2x24 px of hero
  /// padding, leaves 492.
  static const double width = 236;

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
    final colors = context.colors;
    final deviceLabel = selected ?? 'Bawaan sistem';
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.sm,
        Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(
          color: enabled ? colors.borderInteractive : colors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: IconSizes.sm,
                color: enabled ? accent : colors.textDisabled,
              ),
              Spacing.hSm,
              Expanded(
                child: Text(
                  label,
                  style: AppText.subheading.c(
                    enabled ? colors.text : colors.textTertiary,
                  ),
                ),
              ),
              AppSwitch(
                value: enabled,
                onChanged: onToggled,
                semanticLabel: '$label ${enabled ? 'aktif' : 'nonaktif'}',
              ),
            ],
          ),
          Spacing.gapXs,
          Row(
            children: [
              Expanded(
                child: AppMenu<String>(
                  enabled: devices.isNotEmpty,
                  tooltip: 'Pilih perangkat $label',
                  onSelected: onDeviceSelected,
                  entries: [
                    for (final device in devices)
                      AppMenuEntry(value: device, label: device),
                  ],
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          deviceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.micro.c(colors.textTertiary),
                        ),
                      ),
                      Icon(
                        AppIcons.expandMore,
                        size: IconSizes.xs,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              AppIconButton(
                icon: AppIcons.refresh,
                tooltip: 'Muat ulang daftar perangkat $label',
                size: IconSizes.xs,
                onPressed: onRefresh,
              ),
            ],
          ),
          if (showLevel) ...[
            Spacing.gapXs,
            LevelMeter(
              level: level,
              color: accent,
              semanticLabel: 'Level $label',
            ),
          ],
        ],
      ),
    );
  }
}
