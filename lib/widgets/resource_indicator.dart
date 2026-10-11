/// Resource indicator (F23): surfaces the same memory-pressure ratio the
/// engine already computes for auto-split (`rust_core/src/memory.rs`),
/// which until now was backend-only. Non-intrusive — a small pill in the
/// recording screen's corner, not a dialog or a toast.
///
/// Deliberately qualitative: an awam notulis gains nothing from "RAM
/// 87.3%", and a raw number reads as a crash warning rather than a
/// suggestion. "Normal" / "Tinggi" says the one thing that is actionable.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings_model.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// How often the indicator re-reads system memory. Memory pressure during a
/// meeting builds up over minutes, not seconds — polling faster would only
/// spend CPU the indicator exists to help conserve.
const Duration kResourcePollInterval = Duration(seconds: 15);

/// Polls [RustBridge.systemMemoryUsageRatio] on [kResourcePollInterval] and
/// reports whether it is currently high, per the engine's own threshold.
///
/// A provider rather than a bare `Timer` inside the widget so a widget test
/// can override it with a fixed value instead of waiting on a real timer.
final resourceMemoryHighProvider = StreamProvider.autoDispose<bool>((ref) {
  final bridge = ref.watch(rustBridgeProvider);
  late StreamController<bool> controller;
  Timer? timer;

  Future<void> poll() async {
    try {
      final ratio = await bridge.systemMemoryUsageRatio();
      final high = await bridge.isMemoryUsageHigh(ratio);
      if (!controller.isClosed) controller.add(high);
    } catch (_) {
      // A failed read says nothing about memory pressure; keep showing
      // whatever was last known rather than flashing a false "Tinggi".
    }
  }

  controller = StreamController<bool>(
    onListen: () {
      poll();
      timer = Timer.periodic(kResourcePollInterval, (_) => poll());
    },
    onCancel: () => timer?.cancel(),
  );
  ref.onDispose(() => timer?.cancel());
  return controller.stream;
});

/// The corner pill itself. Shown during recording; absent — not just
/// quiet — when memory is normal, since a permanent "Normal" badge is
/// noise in a screen whose whole point is the transcript.
class ResourceIndicator extends ConsumerWidget {
  const ResourceIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final high = ref.watch(resourceMemoryHighProvider).valueOrNull ?? false;
    if (!high) return const SizedBox.shrink();

    final colors = context.colors;
    return Semantics(
      label: 'Penggunaan memori tinggi, pertimbangkan tutup aplikasi lain',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.warningSubtle,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.warning, size: IconSizes.sm, color: colors.warning),
            const SizedBox(width: Spacing.xs),
            Text(
              'Tinggi, pertimbangkan tutup aplikasi lain',
              style: AppText.caption.c(colors.warning),
            ),
          ],
        ),
      ),
    );
  }
}
