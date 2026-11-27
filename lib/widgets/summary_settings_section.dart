import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../screens/llm_setup_wizard_screen.dart';
import '../src/rust/api.dart' show llmDefaultModel;
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import 'settings_controls.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import 'ui/app_button.dart';

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

  /// Placeholder for the Ollama model field, replaced by the engine's
  /// default tag once it answers. Neutral until then: a hint naming a
  /// model the catalogue does not contain is worse than no name at all,
  /// because a user who types it verbatim pulls a model the app has no
  /// measurements for. That is exactly what the previous hardcoded
  /// `qwen2.5:7b` did.
  ///
  /// `null` until then, which shows the localized neutral hint.
  String? _ollamaModelHint;

  @override
  void initState() {
    super.initState();
    final summary = ref.read(settingsProvider).summary;
    _baseUrlController = TextEditingController(text: summary.baseUrl);
    _apiKeyController = TextEditingController(text: summary.apiKey);
    _modelController = TextEditingController(text: summary.model);
    _customPromptController = TextEditingController(text: summary.customPrompt);
    _loadDefaultModelHint();
  }

  Future<void> _loadDefaultModelHint() async {
    try {
      final tag = await llmDefaultModel();
      if (!mounted) return;
      setState(() => _ollamaModelHint = tag);
    } catch (_) {
      // No bridge (widget tests) or a failed load. The neutral hint is
      // still correct, and a placeholder is not worth surfacing an error
      // for.
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  /// Opens the first-run setup wizard manually from Settings. The wizard
  /// writes the chosen model straight into [settingsProvider] on success,
  /// so this only needs to refresh the local controller to match.
  Future<void> _openSetupWizard() async {
    final tag = await openLlmSetupWizard(context);
    if (tag == null || !mounted) return;
    _modelController.text = tag;
    setState(() {});
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
            ? context.l10n.summarySettingsSectionNoModels
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
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final summary = ref.watch(settingsProvider.select((s) => s.summary));
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A plain Row rather than SwitchListTile: this section is rendered
        // inside the settings panel's DecoratedBox, and ListTile asserts when
        // it can't find a Material ancestor to paint its ink on.
        Row(
          children: [
            Icon(
              AppIcons.enhance,
              size: IconSizes.md,
              color: colors.textSecondary,
            ),
            Spacing.hSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.summarySettingsSectionEnable,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: FontSizes.bodyLarge,
                    ),
                  ),
                  Spacing.gapXs,
                  Text(
                    summary.enabled
                        ? l10n.summarySettingsSectionEnabledSubtitle
                        : l10n.summarySettingsSectionDisabledSubtitle,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: FontSizes.micro,
                    ),
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
          Spacing.gapXs,
          _Field(
            label: l10n.summarySettingsSectionProvider,
            child: DropdownButtonFormField<SummaryProvider>(
              initialValue: summary.provider,
              isDense: true,
              decoration: _decoration(),
              items: [
                for (final p in SummaryProvider.values)
                  DropdownMenuItem(
                    value: p,
                    child: Text(_providerLabel(l10n, p)),
                  ),
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
            label: l10n.summarySettingsSectionEndpointUrl,
            child: TextField(
              controller: _baseUrlController,
              decoration: _decoration(
                hint: summary.provider == SummaryProvider.ollama
                    ? 'http://localhost:11434'
                    : 'https://api.openai.com/v1',
              ),
              onSubmitted: (v) => _update(summary.copyWith(baseUrl: v.trim())),
              onTapOutside: (_) => _update(
                summary.copyWith(baseUrl: _baseUrlController.text.trim()),
              ),
            ),
          ),
          if (summary.provider == SummaryProvider.openAiCompatible)
            _Field(
              label: l10n.summarySettingsSectionApiKey,
              helper: l10n.summarySettingsSectionApiKeyHelper,
              child: TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: _decoration(
                  hint: l10n.summarySettingsSectionApiKeyHint,
                ),
                onSubmitted: (v) => _update(summary.copyWith(apiKey: v.trim())),
                onTapOutside: (_) => _update(
                  summary.copyWith(apiKey: _apiKeyController.text.trim()),
                ),
              ),
            ),
          _Field(
            label: l10n.summarySettingsSectionModel,
            child: Row(
              children: [
                Expanded(
                  child: _discoveredModels.isEmpty
                      ? TextField(
                          controller: _modelController,
                          decoration: _decoration(
                            hint: summary.provider == SummaryProvider.ollama
                                ? _ollamaModelHint ??
                                      l10n.summarySettingsSectionOllamaModelHint
                                : 'gpt-4o-mini',
                          ),
                          onSubmitted: (v) =>
                              _update(summary.copyWith(model: v.trim())),
                          onTapOutside: (_) => _update(
                            summary.copyWith(
                              model: _modelController.text.trim(),
                            ),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue:
                              _discoveredModels.contains(summary.model)
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
                Spacing.hSm,
                _loadingModels
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(AppIcons.refresh, size: IconSizes.md),
                        tooltip: l10n.summarySettingsSectionLoadModels,
                        onPressed: _loadModels,
                      ),
              ],
            ),
          ),
          if (_modelsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Text(
                _modelsError!,
                style: TextStyle(
                  color: colors.error,
                  fontSize: FontSizes.micro,
                ),
              ),
            ),
          if (summary.provider == SummaryProvider.ollama)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: AppButton(
                label: l10n.summarySettingsSectionSetupWizard,
                icon: AppIcons.download,
                onPressed: () => _openSetupWizard(),
              ),
            ),
          _Field(
            label: l10n.summarySettingsSectionDefaultTemplate,
            helper: _templateHint(l10n, summary.template),
            child: DropdownButtonFormField<SummaryTemplate>(
              initialValue: summary.template,
              isDense: true,
              isExpanded: true,
              decoration: _decoration(),
              items: [
                for (final t in SummaryTemplate.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(_templateLabel(l10n, t)),
                  ),
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
            icon: AppIcons.quote,
            label: l10n.summarySettingsSectionCitations,
            subtitle: l10n.summarySettingsSectionCitationsSubtitle,
            value: summary.withCitations,
            onChanged: (value) =>
                _update(summary.copyWith(withCitations: value)),
          ),
          SettingsSwitch(
            icon: AppIcons.checklist,
            label: l10n.summarySettingsSectionActionItems,
            subtitle: l10n.summarySettingsSectionActionItemsSubtitle,
            value: summary.withActionItems,
            onChanged: (value) =>
                _update(summary.copyWith(withActionItems: value)),
          ),
          if (summary.template == SummaryTemplate.kustom)
            _Field(
              label: l10n.summarySettingsSectionCustomInstructions,
              child: TextField(
                controller: _customPromptController,
                maxLines: 4,
                minLines: 2,
                decoration: _decoration(
                  hint: l10n.summarySettingsSectionCustomInstructionsHint,
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
    contentPadding: const EdgeInsets.symmetric(
      horizontal: Spacing.sm,
      vertical: Spacing.sm,
    ),
  );
}

/// Localized counterparts of `summaryProviderLabel`, `summaryTemplateLabel`
/// and `summaryTemplateHint` in `state/models.dart`, which stays free of the
/// widget layer (and so of `AppLocalizations`). Same wording in Indonesian.
String _providerLabel(AppLocalizations l10n, SummaryProvider provider) =>
    switch (provider) {
      SummaryProvider.ollama => l10n.modelsSummaryProviderOllama,
      SummaryProvider.openAiCompatible =>
        l10n.modelsSummaryProviderOpenAiCompatible,
    };

String _templateLabel(AppLocalizations l10n, SummaryTemplate template) =>
    switch (template) {
      SummaryTemplate.notulenRapat => l10n.modelsSummaryTemplateNotulenRapat,
      SummaryTemplate.ringkasanEksekutif =>
        l10n.modelsSummaryTemplateRingkasanEksekutif,
      SummaryTemplate.actionItems => l10n.modelsSummaryTemplateActionItems,
      SummaryTemplate.standup => l10n.modelsSummaryTemplateStandup,
      SummaryTemplate.kustom => l10n.modelsSummaryTemplateKustom,
    };

String _templateHint(AppLocalizations l10n, SummaryTemplate template) =>
    switch (template) {
      SummaryTemplate.notulenRapat =>
        l10n.modelsSummaryTemplateHintNotulenRapat,
      SummaryTemplate.ringkasanEksekutif =>
        l10n.modelsSummaryTemplateHintRingkasanEksekutif,
      SummaryTemplate.actionItems => l10n.modelsSummaryTemplateHintActionItems,
      SummaryTemplate.standup => l10n.modelsSummaryTemplateHintStandup,
      SummaryTemplate.kustom => l10n.modelsSummaryTemplateHintKustom,
    };

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.helper});

  final String label;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: FontSizes.caption,
            ),
          ),
          Spacing.gapXs,
          child,
          if (helper != null) ...[
            Spacing.gapXs,
            Text(
              helper!,
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: FontSizes.micro,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
