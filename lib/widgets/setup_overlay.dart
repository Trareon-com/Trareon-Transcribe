import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/diagnostics_screen.dart';
import '../services/preflight_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_icons.dart';

/// Set to true before running tests so preflight does not reach for the
/// native library.
bool skipPreflightChecks = false;

/// Runs `doctor.rs` at start-up and gets out of the way.
///
/// This widget existed before and was never mounted, and when it did run
/// it blocked the whole app behind a spinner and then behind a wall of
/// text for *any* non-Ok check — including warnings like "the accurate
/// model isn't downloaded yet", which is a perfectly usable state
/// (audit A.0-2, A.11 SetupOverlay).
///
/// Now: the app renders immediately, the checks run after the first frame,
/// warnings become a dismissible banner, and only a hard failure — a
/// library folder that cannot be written, no audio input at all — is worth
/// standing in front of the user. Even then there is a way past it,
/// because being wrong about that must not brick the app.
class SetupOverlay extends ConsumerStatefulWidget {
  final Widget child;

  /// Injectable so widget tests can drive every branch without the engine.
  final Future<PreflightResult> Function()? runChecks;

  const SetupOverlay({super.key, required this.child, this.runChecks});

  /// Creates a SetupOverlay that skips preflight checks.
  const SetupOverlay.test({super.key, required this.child}) : runChecks = null;

  @override
  ConsumerState<SetupOverlay> createState() => _SetupOverlayState();
}

class _SetupOverlayState extends ConsumerState<SetupOverlay> {
  PreflightResult? _result;
  bool _running = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (skipPreflightChecks && widget.runChecks == null) return;
    // After the first frame: the point of this rewrite is that the app is
    // on screen before the checks start.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPreflight());
  }

  Future<void> _runPreflight() async {
    if (_running) return;
    setState(() => _running = true);
    final result = await (widget.runChecks ?? runPreflight)();
    if (!mounted) return;
    setState(() {
      _result = result;
      _running = false;
      _dismissed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    if (result == null || _dismissed) return widget.child;

    if (result.hasFailures) {
      return _BlockingFailure(
        result: result,
        busy: _running,
        onRetry: _runPreflight,
        onContinue: () => setState(() => _dismissed = true),
      );
    }

    if (!result.hasWarnings) return widget.child;

    return Column(
      children: [
        Material(
          color: colors.warning.withValues(alpha: 0.12),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.warning,
                    size: IconSizes.md,
                    color: colors.warning,
                  ),
                  Spacing.hSm,
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        'Perlu diperiksa: ${summariseNames(result.warnings)}.',
                        style: TextStyle(
                          color: colors.text,
                          fontSize: FontSizes.body,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => openDiagnostics(context),
                    child: const Text('Lihat diagnostik'),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close, size: IconSizes.md),
                    tooltip: 'Tutup',
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _BlockingFailure extends StatelessWidget {
  const _BlockingFailure({
    required this.result,
    required this.busy,
    required this.onRetry,
    required this.onContinue,
  });

  final PreflightResult result;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(AppIcons.error, size: IconSizes.hero, color: colors.error),
                Spacing.gapLg,
                Text(
                  'Trareon belum siap merekam',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: FontSizes.headline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacing.gapLg,
                for (final check in result.failures)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✗ ${checkTitle(check.name)}',
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacing.gapXs,
                        Text(
                          messageOf(check),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: FontSizes.body,
                          ),
                        ),
                        if (check.remediation != null) ...[
                          Spacing.gapXs,
                          Text(
                            check.remediation!,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: FontSizes.body,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                Spacing.gapSm,
                FilledButton(
                  onPressed: busy ? null : onRetry,
                  child: Text(busy ? 'Memeriksa…' : 'Periksa Ulang'),
                ),
                Spacing.gapSm,
                // Always a way past: a preflight that is wrong about the
                // machine must not be able to lock the user out of their
                // own recordings.
                TextButton(
                  onPressed: onContinue,
                  child: const Text('Lanjutkan saja'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
