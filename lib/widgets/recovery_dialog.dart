import 'package:flutter/material.dart';

import '../src/rust/session.dart' as rust_session;
import '../theme/app_colors.dart';
import '../utils/format_time.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// What the user chose in [showRecoveryDialog].
sealed class RecoveryChoice {
  const RecoveryChoice();
}

/// Restore this session and carry on recording into it.
class RecoverSession extends RecoveryChoice {
  const RecoverSession(this.session);
  final rust_session.RecoverableSession session;
}

/// Discard this session and everything it held.
class DiscardSession extends RecoveryChoice {
  const DiscardSession(this.session);
  final rust_session.RecoverableSession session;
}

/// Lists the sessions a crash left behind, saying for each one exactly
/// what can be recovered.
///
/// This replaces a banner that said "Ada N sesi yang bisa dipulihkan",
/// offered a single "Pulihkan" that silently acted on the *first* entry,
/// and whose only other option was "Abaikan" — which hid the list without
/// deleting anything, so the same sessions came back on the next launch
/// forever. It also said "bisa dipulihkan" about sessions whose transcript
/// was not in fact recoverable at all.
///
/// Returns `null` if the user dismissed the dialog without choosing.
Future<RecoveryChoice?> showRecoveryDialog(
  BuildContext context,
  List<rust_session.RecoverableSession> sessions, {
  /// Recovery resumes capture, and only one session can be live at a
  /// time. Disabled (with the reason shown) rather than silently ignored.
  bool canRecover = true,
}) {
  return showDialog<RecoveryChoice>(
    context: context,
    builder: (context) => _RecoveryDialog(sessions: sessions, canRecover: canRecover),
  );
}

class _RecoveryDialog extends StatelessWidget {
  const _RecoveryDialog({required this.sessions, required this.canRecover});

  final List<rust_session.RecoverableSession> sessions;
  final bool canRecover;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return AlertDialog(
      title: const Text('Pulihkan sesi yang terhenti'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sessions.length == 1
                  ? 'Satu sesi berhenti tanpa disimpan. Berikut isinya:'
                  : '${sessions.length} sesi berhenti tanpa disimpan. Berikut isinya:',
              style: TextStyle(color: colors.textSecondary, fontSize: FontSizes.body),
            ),
            Spacing.gapMd,
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sessions.length,
                separatorBuilder: (_, _) => Divider(color: colors.divider, height: 16),
                itemBuilder: (context, index) => _RecoverableTile(
                  session: sessions[index],
                  canRecover: canRecover,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nanti saja'),
        ),
      ],
    );
  }
}

class _RecoverableTile extends StatelessWidget {
  const _RecoverableTile({required this.session, required this.canRecover});

  final rust_session.RecoverableSession session;
  final bool canRecover;

  /// What recovery will actually hand back, stated per session rather than
  /// promised in general.
  String get _contents {
    final parts = <String>[];
    parts.add(
      session.segmentCount > 0
          ? '${session.segmentCount} segmen transkrip'
          : 'transkrip kosong',
    );
    final audio = <String>[];
    if (session.micAudioSecs > 0) {
      audio.add('mikrofon ${formatDurationId(session.micAudioSecs)}');
    }
    if (session.speakerAudioSecs > 0) {
      audio.add('audio sistem ${formatDurationId(session.speakerAudioSecs)}');
    }
    parts.add(audio.isEmpty ? 'tanpa rekaman audio' : 'audio: ${audio.join(', ')}');
    return parts.join(' · ');
  }

  String get _startedAt {
    final started = DateTime.fromMillisecondsSinceEpoch(
      session.startedAtUnixMs.toInt(),
    );
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(started.day)}/${two(started.month)}/${started.year} '
        '${two(started.hour)}:${two(started.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final hasAnything = session.segmentCount > 0 ||
        session.micAudioSecs > 0 ||
        session.speakerAudioSecs > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.title,
          style: TextStyle(
            color: colors.text,
            fontSize: FontSizes.bodyLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
        Spacing.gapXs,
        Text(
          '$_startedAt · ${formatDurationId(session.durationSecs)}',
          style: TextStyle(color: colors.textSecondary, fontSize: FontSizes.caption),
        ),
        Spacing.gapXs,
        Text(
          _contents,
          style: TextStyle(
            color: hasAnything ? colors.textSecondary : colors.error,
            fontSize: FontSizes.caption,
          ),
        ),
        Spacing.gapSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(DiscardSession(session)),
              icon: const Icon(AppIcons.delete, size: IconSizes.sm),
              label: const Text('Hapus'),
              style: TextButton.styleFrom(foregroundColor: colors.error),
            ),
            Spacing.hSm,
            Tooltip(
              message: canRecover
                  ? 'Lanjutkan sesi ini dan rekam ke berkas yang sama'
                  : 'Hentikan sesi yang sedang berjalan dulu',
              child: FilledButton.icon(
                onPressed: canRecover
                    ? () => Navigator.of(context).pop(RecoverSession(session))
                    : null,
                icon: const Icon(AppIcons.restore, size: IconSizes.sm),
                label: const Text('Pulihkan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
