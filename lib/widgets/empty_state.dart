/// Centred icon and message for a pane with nothing in it yet.
///
/// Shrinks and then scrolls rather than overflowing. At the app's smallest
/// window the transcript pane is only about 140 px tall while a session is
/// starting, and the full-size layout (a hero glyph plus two lines of text)
/// needs about 220: it used to paint the yellow-and-black overflow stripes
/// exactly where the first transcript line was about to appear.
///
/// The richer composition (an icon plate with a badged second glyph, and an
/// action) lives in `ui/app_feedback.dart` as `AppEmptyState`. This one stays
/// for the panes that only ever need a glyph and two lines, and is where the
/// short-pane behaviour is tested.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  /// Below this pane height the glyph and the generous padding are dropped,
  /// so the words survive rather than the decoration.
  static const double compactBelow = 220;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Every current caller sits in an Expanded, but a scroll view given
        // unbounded height throws outright, which is a worse failure than the
        // overflow above, so the scrolling is conditional on having a height.
        final bounded = constraints.hasBoundedHeight;
        final compact = bounded && constraints.maxHeight < compactBelow;
        final padding = EdgeInsets.all(compact ? Spacing.lg : Spacing.xxxl);
        final body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              // Decorative: it repeats what the title already says.
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: IconSizes.hero,
                  color: colors.textTertiary,
                ),
              ),
              Spacing.gapLg,
            ],
            Semantics(
              header: true,
              child: Text(
                title,
                style: AppText.subheading.c(colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            if (subtitle != null) ...[
              Spacing.gapSm,
              Text(
                subtitle!,
                style: AppText.body.c(colors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              compact ? Spacing.gapMd : Spacing.gapLg,
              action!,
            ],
          ],
        );
        return Center(
          child: bounded
              ? SingleChildScrollView(padding: padding, child: body)
              : Padding(padding: padding, child: body),
        );
      },
    );
  }
}
