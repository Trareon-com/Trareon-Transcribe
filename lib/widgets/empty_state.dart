import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Centred icon + message for a pane with nothing in it yet.
///
/// Shrinks and then scrolls rather than overflowing. At 800x600 — the app's
/// smallest window — the transcript pane is only ~140px tall while a session
/// is starting, and the full-size layout (40px padding, 40px glyph, two
/// lines of text) needs about 220px: it used to paint the yellow-and-black
/// overflow stripes right where the first transcript line was about to
/// appear. Same `compact` rule as the idle workspace in main_screen.dart.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  @override Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return LayoutBuilder(builder: (context, constraints) {
      // Every current caller sits in an Expanded, but a scroll view given
      // unbounded height throws outright — a worse failure than the overflow
      // above — so the scrolling is conditional on actually having a height.
      final bounded = constraints.hasBoundedHeight;
      final compact = bounded && constraints.maxHeight < 220;
      final padding = EdgeInsets.all(compact ? 16 : 40);
      final body = Column(mainAxisSize: MainAxisSize.min, children: [
        if (!compact) ...[
          Icon(icon, size: 40, color: colors.textTertiary),
          const SizedBox(height: 16),
        ],
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textSecondary), textAlign: TextAlign.center),
        if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle!, style: TextStyle(fontSize: 13, color: colors.textTertiary), textAlign: TextAlign.center)],
        if (action != null) ...[SizedBox(height: compact ? 12 : 20), action!],
      ]);
      return Center(child: bounded
          ? SingleChildScrollView(padding: padding, child: body)
          : Padding(padding: padding, child: body));
    });
  }
}
