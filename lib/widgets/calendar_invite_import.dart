/// F22: the inbound half of calendar integration — manual `.ics` import
/// before a session starts. No OAuth, no watch-folder: those are either
/// an online dependency or bigger than this pass (see
/// `docs/MULTI_DEVICE_HANDOFF_AUDIT.md`-style scoping notes in the sprint
/// report). Opt-in and easy to decline, per the brief.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings_model.dart';
import '../src/rust/calendar_import.dart' as rust_calendar;
import 'app_toast.dart';
import 'ui/app_button.dart';
import 'ui/app_dialog.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Picks an `.ics` file, parses it, and — if the user confirms — returns
/// the event whose title should pre-fill the new session. Returns `null`
/// on cancel, an unreadable file, or a file with no events, each of
/// which has already been toasted.
///
/// Takes a plain [BuildContext] rather than a `WidgetRef`: the entry
/// point (`_IdleHero`) is a `StatelessWidget` several layers below the
/// nearest `ConsumerWidget`, and threading `ref` down just for this one
/// call would mean converting it.
Future<rust_calendar.CalendarEvent?> importCalendarInvite(
  BuildContext context,
) async {
  final picked = await FilePicker.platform.pickFiles(
    dialogTitle: 'Impor undangan rapat (.ics)',
    type: FileType.custom,
    allowedExtensions: const ['ics'],
  );
  final path = picked?.files.singleOrNull?.path;
  if (path == null) return null;

  List<rust_calendar.CalendarEvent> events;
  try {
    final content = await File(path).readAsString();
    if (!context.mounted) return null;
    final bridge = ProviderScope.containerOf(context).read(rustBridgeProvider);
    events = await bridge.parseIcsInvite(content);
  } catch (e) {
    if (context.mounted) {
      AppToast.show(context, 'Gagal membaca undangan: $e', type: ToastType.error);
    }
    return null;
  }

  if (events.isEmpty) {
    if (context.mounted) {
      AppToast.show(
        context,
        'Tidak ada acara yang terbaca dari berkas itu.',
        type: ToastType.error,
      );
    }
    return null;
  }

  final event = events.first;
  if (!context.mounted) return null;
  final confirmed = await confirmCalendarInvite(context, event);
  return confirmed ? event : null;
}

/// The opt-in confirmation step on its own, so it can be exercised by a
/// widget test without going through the real file picker.
Future<bool> confirmCalendarInvite(
  BuildContext context,
  rust_calendar.CalendarEvent event,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => InviteConfirmDialog(event: event),
  );
  return confirmed == true;
}

class InviteConfirmDialog extends StatelessWidget {
  const InviteConfirmDialog({super.key, required this.event});

  final rust_calendar.CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppDialog(
      title: 'Isi dari undangan ini?',
      icon: AppIcons.event,
      description: event.summary.isEmpty
          ? 'Undangan ini tidak punya judul.'
          : '"${event.summary}" akan menjadi judul sesi.',
      actions: [
        AppButton(
          label: 'Tidak',
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Isi judul',
          variant: AppButtonVariant.primary,
          onPressed: event.summary.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(true),
        ),
      ],
      child: event.attendees.isEmpty
          ? const SizedBox.shrink()
          : Text(
              'Peserta pada undangan: ${event.attendees.join(', ')}',
              style: AppText.caption.c(colors.textSecondary),
            ),
    );
  }
}
