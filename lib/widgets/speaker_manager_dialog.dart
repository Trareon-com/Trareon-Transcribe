/// "Kelola Pembicara" (F10).
///
/// Renaming a speaker from a transcript row already renamed every row in
/// the session. Two things it could not do, and both are the ones a
/// notulis actually needs:
///
/// * **Merge.** The clustering over-splits: one person across a long
///   meeting comes back as `Peserta 2` and `Peserta 4`. Without a merge,
///   the only repair is renaming both to the same name and living with a
///   transcript that claims two people said the same sentence.
/// * **Remember.** The same weekly meeting produces the same labels, and
///   retyping four names every week is work the app should absorb. Only
///   ever a suggestion, never applied silently — see
///   `services/speaker_aliases.dart` for why by-label is the honest
///   granularity.
library;

import 'package:flutter/material.dart';

import '../services/speaker_aliases.dart';
import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_toast.dart';
import '../theme/app_icons.dart';

/// What the dialog asks the host screen to do.
sealed class SpeakerAction {
  const SpeakerAction();
}

/// Rename [from] to [to] everywhere in the session.
class RenameSpeaker extends SpeakerAction {
  const RenameSpeaker(this.from, this.to);
  final String from;
  final String to;
}

/// Fold every segment of [from] into [into].
class MergeSpeakers extends SpeakerAction {
  const MergeSpeakers(this.from, this.into);
  final String from;
  final String into;
}

/// One speaker as it appears in the transcript.
class SpeakerSummary {
  const SpeakerSummary({
    required this.label,
    required this.segments,
    required this.seconds,
  });

  final String label;
  final int segments;
  final double seconds;
}

/// Speakers in a transcript, most-spoken first.
///
/// Partials are excluded: they are a live-preview artifact and counting
/// them would show a speaker who said nothing final as the busiest.
List<SpeakerSummary> speakersIn(List<TranscriptSegment> segments) {
  final counts = <String, int>{};
  final seconds = <String, double>{};
  for (final segment in segments) {
    if (segment.isPartial) continue;
    final label = segment.speaker.trim().isEmpty
        ? segment.source
        : segment.speaker.trim();
    counts[label] = (counts[label] ?? 0) + 1;
    seconds[label] = (seconds[label] ?? 0) + segment.duration;
  }
  final out = [
    for (final entry in counts.entries)
      SpeakerSummary(
        label: entry.key,
        segments: entry.value,
        seconds: seconds[entry.key] ?? 0,
      ),
  ];
  out.sort((a, b) => b.seconds.compareTo(a.seconds));
  return out;
}

/// Opens the manager. Returns the actions to apply, in order, or null if
/// the user cancelled.
Future<List<SpeakerAction>?> showSpeakerManager(
  BuildContext context, {
  required List<TranscriptSegment> segments,
}) {
  return showDialog<List<SpeakerAction>>(
    context: context,
    builder: (_) => _SpeakerManagerDialog(segments: segments),
  );
}

class _SpeakerManagerDialog extends StatefulWidget {
  const _SpeakerManagerDialog({required this.segments});

  final List<TranscriptSegment> segments;

  @override
  State<_SpeakerManagerDialog> createState() => _SpeakerManagerDialogState();
}

class _SpeakerManagerDialogState extends State<_SpeakerManagerDialog> {
  /// Working copy of the labels, so merges and renames compose before
  /// anything is applied to the transcript.
  late List<SpeakerSummary> _speakers;

  /// Actions to hand back, in the order the user made them.
  final List<SpeakerAction> _actions = [];

  late Map<String, String> _suggestions;

  /// `current label -> the engine label it started as`.
  ///
  /// What gets remembered is keyed by the *engine's* label, because that
  /// is what the next session will produce — remembering under the name
  /// the user just typed would match nothing ever again.
  final Map<String, String> _origin = {};

  /// Current labels the user ticked "remember".
  final Set<String> _toRemember = {};

  @override
  void initState() {
    super.initState();
    _speakers = speakersIn(widget.segments);
    for (final speaker in _speakers) {
      _origin[speaker.label] = speaker.label;
    }
    _suggestions = suggestionsFor(_speakers.map((s) => s.label));
  }

  /// Applies a rename to the working copy.
  void _rename(String from, String to) {
    final target = to.trim();
    if (target.isEmpty || target == from) return;
    // Renaming onto a name that already exists *is* a merge, and
    // pretending otherwise would leave two rows with one name.
    final existing = _speakers.indexWhere((s) => s.label == target);
    if (existing >= 0) {
      _merge(from, target);
      return;
    }
    setState(() {
      _actions.add(RenameSpeaker(from, target));
      _speakers = [
        for (final speaker in _speakers)
          if (speaker.label == from)
            SpeakerSummary(
              label: target,
              segments: speaker.segments,
              seconds: speaker.seconds,
            )
          else
            speaker,
      ];
      final origin = _origin.remove(from) ?? from;
      _origin[target] = origin;
      if (_toRemember.remove(from)) _toRemember.add(target);
      _suggestions.remove(from);
    });
  }

  void _merge(String from, String into) {
    if (from == into) return;
    setState(() {
      _actions.add(MergeSpeakers(from, into));
      final source = _speakers.firstWhere((s) => s.label == from);
      _speakers = [
        for (final speaker in _speakers)
          if (speaker.label == from)
            null
          else if (speaker.label == into)
            SpeakerSummary(
              label: into,
              segments: speaker.segments + source.segments,
              seconds: speaker.seconds + source.seconds,
            )
          else
            speaker,
      ].whereType<SpeakerSummary>().toList()
        ..sort((a, b) => b.seconds.compareTo(a.seconds));
      _suggestions.remove(from);
      _toRemember.remove(from);
      _origin.remove(from);
    });
  }

  Future<void> _promptRename(SpeakerSummary speaker) async {
    final controller = TextEditingController(
      text: _suggestions[speaker.label] ?? speaker.label,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ganti nama "${speaker.label}"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama',
            border: OutlineInputBorder(),
            helperText: 'Berlaku untuk seluruh sesi ini.',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Ganti'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) _rename(speaker.label, result);
  }

  Future<void> _promptMerge(SpeakerSummary speaker) async {
    final others = _speakers.where((s) => s.label != speaker.label).toList();
    if (others.isEmpty) return;
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Gabungkan "${speaker.label}" ke siapa?'),
        children: [
          for (final other in others)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(other.label),
              child: Text('${other.label} (${other.segments} segmen)'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (target != null) _merge(speaker.label, target);
  }

  Future<void> _confirm() async {
    for (final current in _toRemember) {
      final engineLabel = _origin[current] ?? current;
      // A label the user never renamed remembers nothing: engineLabel
      // equals current, which `rememberSpeakerAlias` treats as "forget".
      await rememberSpeakerAlias(engineLabel, current);
    }
    if (!mounted) return;
    Navigator.of(context).pop(_actions);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return AlertDialog(
      title: const Text('Kelola Pembicara'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_speakers.isEmpty)
              Text(
                'Transkrip ini belum punya pembicara.',
                style: TextStyle(color: colors.textSecondary),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final speaker in _speakers)
                      _SpeakerRow(
                        key: ValueKey(speaker.label),
                        speaker: speaker,
                        colors: colors,
                        suggestion: _suggestions[speaker.label],
                        canMerge: _speakers.length > 1,
                        remembered: _rememberedLabelFor(speaker.label),
                        engineLabel: _origin[speaker.label] ?? speaker.label,
                        onRename: () => _promptRename(speaker),
                        onMerge: () => _promptMerge(speaker),
                        onApplySuggestion: () => _rename(
                          speaker.label,
                          _suggestions[speaker.label]!,
                        ),
                        onRememberChanged: (value) => setState(() {
                          if (value) {
                            _toRemember.add(speaker.label);
                          } else {
                            _toRemember.remove(speaker.label);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            if (_actions.isNotEmpty) ...[
              Spacing.gapSm,
              Text(
                '${_actions.length} perubahan menunggu. Tekan Terapkan untuk '
                'menuliskannya ke transkrip.',
                style: TextStyle(
                  fontSize: FontSizes.micro,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (readSpeakerAliases().isEmpty) {
              AppToast.show(context, 'Belum ada nama yang diingat.');
              return;
            }
            await forgetAllSpeakerAliases();
            if (!context.mounted) return;
            setState(() => _suggestions = const {});
            AppToast.show(context, 'Nama pembicara yang diingat dihapus.');
          },
          child: const Text('Lupakan nama tersimpan'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _actions.isEmpty && _toRemember.isEmpty ? null : _confirm,
          child: const Text('Terapkan'),
        ),
      ],
    );
  }

  bool _rememberedLabelFor(String label) => _toRemember.contains(label);
}

class _SpeakerRow extends StatelessWidget {
  const _SpeakerRow({
    super.key,
    required this.speaker,
    required this.colors,
    required this.canMerge,
    required this.remembered,
    required this.engineLabel,
    required this.onRename,
    required this.onMerge,
    required this.onApplySuggestion,
    required this.onRememberChanged,
    this.suggestion,
  });

  final SpeakerSummary speaker;
  final AppColorSet colors;
  final bool canMerge;
  final bool remembered;

  /// The label the diarizer produced, which is what a remembered name is
  /// keyed by.
  final String engineLabel;

  final String? suggestion;
  final VoidCallback onRename;
  final VoidCallback onMerge;
  final VoidCallback onApplySuggestion;
  final ValueChanged<bool> onRememberChanged;

  @override
  Widget build(BuildContext context) {
    final minutes = speaker.seconds / 60;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      speaker.label,
                      style: TextStyle(
                        fontSize: FontSizes.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      '${speaker.segments} segmen · '
                      '${minutes < 1 ? "${speaker.seconds.round()} detik" : "${minutes.round()} menit"}',
                      style: TextStyle(
                        fontSize: FontSizes.micro,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ganti nama',
                icon: const Icon(AppIcons.edit, size: IconSizes.sm),
                onPressed: onRename,
              ),
              IconButton(
                tooltip: canMerge
                    ? 'Gabungkan dengan pembicara lain'
                    : 'Tidak ada pembicara lain untuk digabung',
                icon: const Icon(AppIcons.merge, size: IconSizes.sm),
                onPressed: canMerge ? onMerge : null,
              ),
            ],
          ),
          if (suggestion != null)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.xs),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Spacing.xs,
                children: [
                  Text(
                    'Diingat dari rapat sebelumnya: $suggestion',
                    style: TextStyle(
                      fontSize: FontSizes.micro,
                      color: colors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: onApplySuggestion,
                    child: const Text('Pakai'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: Spacing.xs),
            child: Row(
              children: [
                Checkbox(
                  value: remembered,
                  onChanged: (value) => onRememberChanged(value == true),
                ),
                Expanded(
                  child: Text(
                    engineLabel == speaker.label
                        ? 'Ingat nama ini untuk label "${speaker.label}" di '
                            'rapat berikutnya (ganti namanya dulu)'
                        : 'Ingat "${speaker.label}" untuk label '
                            '"$engineLabel" di rapat berikutnya',
                    style: TextStyle(
                      fontSize: FontSizes.micro,
                      color: colors.textSecondary,
                    ),
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
