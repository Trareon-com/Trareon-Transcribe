/// The interaction substrate every control in the kit is built on.
///
/// Material's `InkWell` gives a ripple, a 40 px splash box and a focus
/// highlight that cannot be told apart from hover. A dense desktop app needs
/// the opposite of all three: a surface tint instead of a ripple (5,000
/// transcript rows with ripples drop frames), an explicit hit box, and a focus
/// ring that appears on keyboard traversal and *not* on click.
///
/// [Interactive] gives a builder the four states the design system requires
/// (`docs/DESIGN-SYSTEM.md` §6) and draws the focus ring itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

/// The visual state of a control at one moment.
@immutable
class InteractionState {
  const InteractionState({
    required this.hovered,
    required this.pressed,
    required this.focused,
    required this.disabled,
  });

  final bool hovered;
  final bool pressed;
  final bool focused;
  final bool disabled;

  /// True when the control should look like it is being touched: hovered or
  /// pressed, and not disabled.
  bool get active => !disabled && (hovered || pressed);
}

/// Wraps [builder] with hover, press and focus tracking, a keyboard
/// activation handler, and an optional focus ring.
class Interactive extends StatefulWidget {
  const Interactive({
    super.key,
    required this.builder,
    this.onPressed,
    this.onLongPress,
    this.onSecondaryTap,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius = Radii.mdAll,
    this.showFocusRing = true,
    this.cursor = SystemMouseCursors.click,
    this.semanticLabel,
    this.isButton = true,
    this.selected,
    this.toggled,
    this.tooltip,
    this.pressScale = false,
    this.onHoverChanged,
  });

  final Widget Function(BuildContext context, InteractionState state) builder;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius borderRadius;

  /// Off for controls that draw their own ring (an input field turns its own
  /// border accent-coloured instead).
  final bool showFocusRing;

  final MouseCursor cursor;

  /// Announced instead of the subtree. Leave null when the child already
  /// contains the words a screen reader should read.
  final String? semanticLabel;

  final bool isButton;
  final bool? selected;
  final bool? toggled;

  /// Shown on hover and focus. Every icon-only control in the app sets this.
  final String? tooltip;

  /// Presses the control down by 2 % on pointer-down. Buttons use it; list
  /// rows do not, because a row that shrinks under the cursor reads as a
  /// glitch rather than as a press.
  final bool pressScale;

  final ValueChanged<bool>? onHoverChanged;

  @override
  State<Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<Interactive> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final state = InteractionState(
      hovered: _hovered,
      pressed: _pressed,
      focused: _focused,
      disabled: !_enabled,
    );

    Widget child = widget.builder(context, state);

    if (widget.pressScale) {
      child = AnimatedScale(
        scale: _pressed && _enabled ? motion.pressScale : 1.0,
        duration: motion.instant,
        curve: AppEasing.standard,
        child: child,
      );
    }

    // The ring is drawn outside the control's own box so it never clips
    // against a neighbouring row, which is SC 2.4.11 "focus not obscured".
    child = AnimatedContainer(
      duration: motion.fast,
      curve: AppEasing.standard,
      decoration: BoxDecoration(
        borderRadius:
            widget.borderRadius.add(
                  BorderRadius.circular(Strokes.focusRingOffset),
                )
                as BorderRadius,
        border: Border.all(
          color: _focused && widget.showFocusRing && _enabled
              ? colors.focusRing
              : Colors.transparent,
          width: Strokes.focusRing,
        ),
      ),
      padding: const EdgeInsets.all(Strokes.focusRingOffset),
      child: child,
    );

    child = Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: _enabled,
      onFocusChange: (value) {
        if (_focused != value) setState(() => _focused = value);
      },
      onKeyEvent: (node, event) {
        if (!_enabled) return KeyEventResult.ignored;
        final isActivator =
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter;
        if (!isActivator) return KeyEventResult.ignored;
        if (event is KeyDownEvent) {
          setState(() => _pressed = true);
          return KeyEventResult.handled;
        }
        if (event is KeyUpEvent) {
          setState(() => _pressed = false);
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: _enabled ? widget.cursor : SystemMouseCursors.basic,
        onEnter: (_) => _setHovered(true),
        onExit: (_) {
          _setHovered(false);
          if (_pressed) setState(() => _pressed = false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? widget.onPressed : null,
          onLongPress: _enabled ? widget.onLongPress : null,
          onSecondaryTap: _enabled ? widget.onSecondaryTap : null,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          child: child,
        ),
      ),
    );

    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }

    return Semantics(
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: child,
    );
  }
}

/// The surface tint a control shows on hover and press, composited over
/// whatever it is sitting on. Returns null when the control is at rest, so a
/// caller can fall back to its own resting fill.
Color? interactionTint(BuildContext context, InteractionState state) {
  final colors = context.colors;
  if (state.disabled) return null;
  if (state.pressed) return colors.pressedOverlay;
  if (state.hovered) return colors.hoverOverlay;
  return null;
}
