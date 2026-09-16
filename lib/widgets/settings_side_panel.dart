import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:file_picker/file_picker.dart';

import '../services/update_checker.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../utils/model_labels.dart';
import '../screens/privacy_report_screen.dart';
import '../screens/usage_dashboard_screen.dart';

/// OBS-style side panel settings that slides in from the right
class SettingsSidePanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final bool embedded;

  const SettingsSidePanel({
    super.key,
    this.onClose,
    this.embedded = false,
  });

  @override
  ConsumerState<SettingsSidePanel> createState() => _SettingsSidePanelState();
}

class _SettingsSidePanelState extends ConsumerState<SettingsSidePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 8,
          color: colors.surface,
          child: Container(
            width: 380,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                left: BorderSide(color: colors.divider, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Header (hidden when embedded)
                if (!widget.embedded)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: colors.headerBackground,
                      border: Border(
                        bottom: BorderSide(color: colors.divider, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.settings, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Pengaturan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: _close,
                          tooltip: 'Tutup',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _SettingsSection(
                        title: 'Tampilan',
                        children: [
                          _SettingsTile(
                            icon: Icons.palette_outlined,
                            label: 'Tema',
                            trailing: _CompactDropdown<AppThemeMode>(
                              value: settings.theme,
                              items: AppThemeMode.values,
                              labelBuilder: _themeLabel,
                              onChanged: notifier.setTheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SettingsSection(
                        title: 'Model & Mode',
                        children: [
                          _SettingsTile(
                            icon: Icons.psychology_outlined,
                            label: 'Model default',
                            trailing: _CompactDropdown<String>(
                              // settings.defaultModel can be an older/power-user
                              // model (e.g. 'tiny') that's still available on
                              // disk but outside the 2-model catalog this
                              // dropdown offers — feeding that straight in as
                              // `value` trips DropdownButton's "exactly one
                              // matching item" assertion. Clamp for display
                              // only; the real setting is untouched unless the
                              // user picks something here.
                              value: kKnownModelIds.contains(settings.defaultModel)
                                  ? settings.defaultModel
                                  : kKnownModelIds.first,
                              items: kKnownModelIds,
                              labelBuilder: modelDisplayLabel,
                              onChanged: (modelId) {
                                if (!isModelAvailable(modelId,
                                    libraryPath: settings.libraryPath)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          'Model pilihan belum tersedia. Selesaikan Setup Wizard terlebih dahulu.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                notifier.setDefaultModel(modelId);
                              },
                            ),
                          ),
                          const _SettingsDivider(),
                          _SettingsSwitch(
                            icon: Icons.speed_outlined,
                            label: 'Progressive Mode',
                            subtitle: settings.progressiveEnabled
                                ? 'Mulai cepat → sempurnakan jadi akurat di latar belakang'
                                : 'Gunakan satu model saja (lebih cepat)',
                            value: settings.progressiveEnabled,
                            onChanged: notifier.setProgressiveEnabled,
                          ),
                          const _SettingsDivider(),
                          _SettingsTile(
                            icon: Icons.meeting_room_outlined,
                            label: 'Mode default',
                            trailing: _CompactDropdown<SessionMode>(
                              value: settings.defaultMode,
                              items: SessionMode.values,
                              labelBuilder: (m) => m.label,
                              onChanged: notifier.setDefaultMode,
                            ),
                          ),
                          const _SettingsDivider(),
                          _SettingsTile(
                            icon: Icons.translate_outlined,
                            label: 'Bahasa',
                            trailing: _CompactDropdown<String?>(
                              value: settings.language,
                              items: const [null, 'id', 'en'],
                              labelBuilder: (s) =>
                                  s == null ? 'Auto-detect' : (s == 'id' ? 'Indonesia' : 'English'),
                              onChanged: notifier.setLanguage,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SettingsSection(
                        title: 'Audio & Suara',
                        children: [
                          _SettingsSwitch(
                            icon: Icons.graphic_eq_outlined,
                            label: 'VAD (deteksi suara)',
                            subtitle:
                                'Filter noise sekitar, hanya rekam saat ada suara. Berlaku mulai sesi berikutnya.',
                            value: settings.vadEnabled,
                            onChanged: notifier.setVadEnabled,
                          ),
                          const _SettingsDivider(),
                          _SettingsTile(
                            icon: Icons.spatial_audio_outlined,
                            label: 'Echo Dedupe',
                            subtitle:
                                'Cegah duplikasi transkrip dari MIC dan SPK — aktif otomatis di mode Rapat Online',
                            trailing: _InfoBadge(
                              message:
                                  'Membandingkan kemiripan audio dari mikrofon dan speaker, lalu menghapus duplikat.',
                            ),
                          ),
                          const _SettingsDivider(),
                          _SettingsSwitch(
                            icon: Icons.timer_outlined,
                            label: 'Auto-Stop saat diam',
                            subtitle: settings.autoStopMinutes != null
                                ? 'Berhenti setelah ${settings.autoStopMinutes} menit tanpa suara'
                                : 'Nonaktifkan untuk rekaman manual penuh',
                            value: settings.autoStopMinutes != null,
                            onChanged: (v) =>
                                notifier.setAutoStopMinutes(v ? 5 : null),
                          ),
                          if (settings.autoStopMinutes != null) ...[
                            const _SettingsDivider(),
                            _SettingsTile(
                              icon: Icons.timer_10_outlined,
                              label: 'Durasi diam',
                              trailing: _CompactDropdown<int>(
                                value: settings.autoStopMinutes!,
                                items: const [1, 2, 3, 5, 10, 15],
                                labelBuilder: (m) => '$m menit',
                                onChanged: notifier.setAutoStopMinutes,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SettingsSection(
                        title: 'Output & Penyimpanan',
                        children: [
                          _SettingsTile(
                            icon: Icons.folder_outlined,
                            label: 'Folder output',
                            subtitle: settings.libraryPath,
                            trailing: Icon(Icons.chevron_right,
                                color: colors.textTertiary, size: 18),
                            onTap: () async {
                              final dir = await FilePicker.platform.getDirectoryPath(
                                dialogTitle: 'Pilih folder output',
                                initialDirectory: settings.libraryPath,
                              );
                              if (dir != null && dir != settings.libraryPath) {
                                notifier.setLibraryPath(dir);
                              }
                            },
                          ),
                          const _SettingsDivider(),
                          _SettingsTile(
                            icon: Icons.save_alt_outlined,
                            label: 'Format ekspor default',
                            trailing: _CompactDropdown<String>(
                              value: settings.defaultExportFormat,
                              items: const ['markdown', 'txt', 'json', 'srt', 'vtt', 'html', 'docx'],
                              labelBuilder: (f) => f,
                              onChanged: notifier.setDefaultExportFormat,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SettingsSection(
                        title: 'Transkripsi',
                        children: [
                          _SettingsTile(
                            icon: Icons.speed_outlined,
                            label: 'Perbandingan Kecepatan',
                            subtitle:
                                'Bahasa Indonesia: ringan 3s · cepat 10s · akurat 56s per 1 menit audio.\n'
                                'Model akurat disarankan untuk meeting & wawancara.',
                            trailing: const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SettingsSection(
                        title: 'Lainnya',
                        children: [
                          _SettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Laporan Privasi',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PrivacyReportScreen(),
                              ),
                            ),
                          ),
                          const _SettingsDivider(),
                          _SettingsTile(
                            icon: Icons.analytics_outlined,
                            label: 'Dasbor Penggunaan',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => UsageDashboardScreen(),
                              ),
                            ),
                          ),
                          const _SettingsDivider(),
                          _SettingsTile(
                            icon: Icons.system_update_alt_outlined,
                            label: 'Cek Pembaruan',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () async {
                              final update = UpdateChecker();
                              final info = await update.checkForUpdate();
                              if (!context.mounted) return;
                              if (info.isUpdateAvailable) {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Pembaruan Tersedia'),
                                    content: Text(
                                      'Versi ${info.latestVersion} tersedia (saat ini ${info.currentVersion}).',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Nanti'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          // Open release page
                                        },
                                        child: const Text('Lihat Rilis'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sudah versi terbaru')),
                                );
                              }
                            },
                          ),
                          const _SettingsDivider(),
                          _SettingsTile(
                            icon: Icons.info_outlined,
                            label: 'Tentang',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => _showAboutDialog(context, colors),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppColorSet colors) {
    showAboutDialog(
      context: context,
      applicationName: 'Trareon Transcribe',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.mic, size: 48, color: Colors.teal),
      children: [
        const Text('Transkripsi offline, privasi terjamin.'),
        const SizedBox(height: 16),
        const Text('Dibangun dengan Flutter + Rust'),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Shared UI components (extracted from SettingsScreen)
// ──────────────────────────────────────────────────────────────────────────

String _themeLabel(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return 'Terang';
    case AppThemeMode.dark:
      return 'Gelap';
    case AppThemeMode.system:
      return 'Sistem';
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.divider,
      indent: 56,
      endIndent: 16,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: trailing,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textTertiary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.primary,
            activeTrackColor: colors.primary.withValues(alpha: 0.3),
            inactiveThumbColor: colors.textTertiary,
            inactiveTrackColor: colors.border,
          ),
        ],
      ),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const _CompactDropdown({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      labelBuilder(item),
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
          dropdownColor: colors.surface,
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: colors.textSecondary),
          style: TextStyle(fontSize: 13, color: colors.text),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String message;

  const _InfoBadge({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return InkWell(
      onTap: () => _showInfoDialog(context, colors),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 14, color: colors.primary),
            const SizedBox(width: 4),
            Text(
              'Info',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, AppColorSet colors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Informasi', style: TextStyle(color: colors.text)),
        content: Text(message, style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Model availability helper
// ──────────────────────────────────────────────────────────────────────────

bool isModelAvailable(String modelId, {required String libraryPath}) {
  final modelsDir = Directory(libraryPath);
  if (!modelsDir.existsSync()) return false;
  return modelsDir.listSync().any((f) =>
      f.path.endsWith('.bin') &&
      f.uri.pathSegments.last.toLowerCase().contains(modelId.toLowerCase()));
}