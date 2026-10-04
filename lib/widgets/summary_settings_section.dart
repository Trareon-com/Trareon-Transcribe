import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import 'settings_controls.dart';

/// Settings for the opt-in AI summary.
///
/// Collapsed to a single switch until enabled, because everything below it is
/// meaningless while the app is fully offline — and because the switch is the
/// one control that changes the app's network behaviour, so it should be
/// unmissable rather than buried among endpoint fields.
class SummarySettingsSection extends ConsumerStatefulWidget {
  const SummarySettingsSection({super.key});

  @override
  ConsumerState<SummarySettingsSection> createState() =>
      _SummarySettingsSectionState();
}

class _SummarySettingsSectionState
    extends ConsumerState<SummarySettingsSection> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _customPromptController;

  List<String> _discoveredModels = const [];
  bool _loadingModels = false;
  String? _modelsError;

  @override
  void initState() {
    super.initState();
    final summary = ref.read(settingsProvider).summary;
    _baseUrlController = TextEditingController(text: summary.baseUrl);
    _apiKeyController = TextEditingController(text: summary.apiKey);
    _modelController = TextEditingController(text: summary.model);
    _customPromptController = TextEditingController(text: summary.customPrompt);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  SummarySettings get _summary => ref.read(settingsProvider).summary;

  Future<void> _update(SummarySettings next) =>
      ref.read(settingsProvider.notifier).setSummarySettings(next);

  /// Asks the endpoint which models it has. Sends no transcript content —
  /// this is the cheap way to find out the endpoint works before the user
  /// discovers otherwise mid-meeting.
  Future<void> _loadModels() async {
    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });
    try {
      final models = await ref
          .read(rustBridgeProvider)
          .listSummaryModels(
            provider: _summary.provider,
            baseUrl: _baseUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _discoveredModels = models;
        _loadingModels = false;
        _modelsError = models.isEmpty
            ? 'Endpoint terhubung, tapi tidak ada model terpasang.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _modelsError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final summary = ref.watch(settingsProvider.select((s) => s.summary));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A plain Row rather than SwitchListTile: this section is rendered
        // inside the settings panel's DecoratedBox, and ListTile asserts when
        // it can't find a Material ancestor to paint its ink on.
        Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 18, color: colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktifkan Ringkasan AI',
                    style: TextStyle(color: colors.text, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.enabled
                        ? 'Transkrip dikirim ke endpoint di bawah hanya saat Anda '
                              'menekan "Buat Ringkasan". Tidak ada audio yang dikirim.'
                        : 'Mati — aplikasi tetap 100% offline.',
                    style: TextStyle(color: colors.textTertiary, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Switch(
              value: summary.enabled,
              activeThumbColor: colors.primary,
              onChanged: (v) => _update(summary.copyWith(enabled: v)),
            ),
          ],
        ),
        if (summary.enabled) ...[
          const SizedBox(height: 4),
          _Field(
            label: 'Penyedia',
            child: DropdownButtonFormField<SummaryProvider>(
              initialValue: summary.provider,
              isDense: true,
              decoration: _decoration(),
              items: [
                for (final p in SummaryProvider.values)
                  DropdownMenuItem(value: p, child: Text(summaryProviderLabel(p))),
              ],
              onChanged: (p) {
                if (p == null) return;
                // Switching providers changes the URL shape entirely; nudge
                // the field to the new provider's usual default rather than
                // leaving an Ollama URL under an OpenAI provider.
                final url = p == SummaryProvider.ollama
                    ? 'http://localhost:11434'
                    : 'https://api.openai.com/v1';
                _baseUrlController.text = url;
                setState(() => _discoveredModels = const []);
                _update(summary.copyWith(provider: p, baseUrl: url));
              },
            ),
          ),
          _Field(
            label: 'URL endpoint',
            child: TextField(
              controller: _baseUrlController,
              decoration: _decoration(
                hint: summary.provider == SummaryProvider.ollama
                    ? 'http://localhost:11434'
                    : 'https://api.openai.com/v1',
              ),
              onSubmitted: (v) => _update(summary.copyWith(baseUrl: v.trim())),
              onTapOutside: (_) =>
                  _update(summary.copyWith(baseUrl: _baseUrlController.text.trim())),
            ),
          ),
          if (summary.provider == SummaryProvider.openAiCompatible)
            _Field(
              label: 'Kunci API',
              helper:
                  'Disimpan apa adanya di file pengaturan aplikasi (tanpa keychain).',
              child: TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: _decoration(hint: 'Tempel kunci di sini'),
                onSubmitted: (v) => _update(summary.copyWith(apiKey: v.trim())),
                onTapOutside: (_) =>
                    _update(summary.copyWith(apiKey: _apiKeyController.text.trim())),
              ),
            ),
          _Field(
            label: 'Model',
            child: Row(
              children: [
                Expanded(
                  child: _discoveredModels.isEmpty
                      ? TextField(
                          controller: _modelController,
                          decoration: _decoration(
                            hint: summary.provider == SummaryProvider.ollama
                                ? 'qwen2.5:7b'
                                : 'gpt-4o-mini',
                          ),
                          onSubmitted: (v) =>
                              _update(summary.copyWith(model: v.trim())),
                          onTapOutside: (_) => _update(
                            summary.copyWith(model: _modelController.text.trim()),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _discoveredModels.contains(summary.model)
                              ? summary.model
                              : _discoveredModels.first,
                          isDense: true,
                          isExpanded: true,
                          decoration: _decoration(),
                          items: [
                            for (final m in _discoveredModels)
                              DropdownMenuItem(value: m, child: Text(m)),
                          ],
                          onChanged: (m) {
                            if (m == null) return;
                            _modelController.text = m;
                            _update(summary.copyWith(model: m));
                          },
                        ),
                ),
                const SizedBox(width: 8),
                _loadingModels
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Muat daftar model dari endpoint',
                        onPressed: _loadModels,
                      ),
              ],
            ),
          ),
          if (_modelsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _modelsError!,
                style: TextStyle(color: colors.error, fontSize: 11.5),
              ),
            ),
          _Field(
            label: 'Template default',
            helper: summaryTemplateHint(summary.template),
            child: DropdownButtonFormField<SummaryTemplate>(
              initialValue: summary.template,
              isDense: true,
              isExpanded: true,
              decoration: _decoration(),
              items: [
                for (final t in SummaryTemplate.values)
                  DropdownMenuItem(value: t, child: Text(summaryTemplateLabel(t))),
              ],
              onChanged: (t) {
                if (t != null) _update(summary.copyWith(template: t));
              },
            ),
          ),
          // F7 and F6. Both change what is *asked for*, not where it is
          // sent, so they live under the endpoint rather than next to the
          // master switch.
          SettingsSwitch(
            icon: Icons.format_quote_outlined,
            label: 'Rujukan ke transkrip',
            subtitle:
                'Minta model menyebut nomor segmen untuk setiap poin, '
                'sehingga tiap baris ringkasan bisa diklik ke menit '
                'asalnya. Rujukan yang tidak cocok dibuang.',
            value: summary.withCitations,
            onChanged: (value) =>
                _update(summary.copyWith(withCitations: value)),
          ),
          SettingsSwitch(
            icon: Icons.checklist_outlined,
            label: 'Tindak lanjut terstruktur',
            subtitle:
                'Minta daftar tugas, penanggung jawab, dan tenggat dalam '
                'format yang bisa disunting dan diekspor ke kalender '
                '(.ics) atau tabel (.csv).',
            value: summary.withActionItems,
            onChanged: (value) =>
                _update(summary.copyWith(withActionItems: value)),
          ),
          if (summary.template == SummaryTemplate.kustom)
            _Field(
              label: 'Instruksi kustom',
              child: TextField(
                controller: _customPromptController,
                maxLines: 4,
                minLines: 2,
                decoration: _decoration(
                  hint: 'Contoh: Buat daftar risiko dan mitigasinya.',
                ),
                onTapOutside: (_) => _update(
                  summary.copyWith(
                    customPrompt: _customPromptController.text.trim(),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  InputDecoration _decoration({String? hint}) => InputDecoration(
    hintText: hint,
    isDense: true,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.helper});

  final String label;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          child,
          if (helper != null) ...[
            const SizedBox(height: 3),
            Text(
              helper!,
              style: TextStyle(color: colors.textTertiary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
