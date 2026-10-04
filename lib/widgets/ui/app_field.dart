/// Text inputs and search. `docs/DESIGN-SYSTEM.md` §6.3.
///
/// Label above the field, never a placeholder-as-label. The helper slot is
/// always in the tree so focusing a field does not reflow the form, and an
/// error replaces the helper rather than pushing it down.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';
import 'key_hint.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.helper,
    this.error,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.mono = false,
    this.reserveHelperSpace = true,
  });

  final TextEditingController? controller;

  /// Rendered above the field. Required for anything a form submits; optional
  /// for a bare inline editor whose purpose is obvious from context.
  final String? label;

  /// Ends with an ellipsis character and shows an example of the expected
  /// shape, never the field's name.
  final String? placeholder;

  final String? helper;

  /// When set, replaces [helper] and turns the border and the text red.
  final String? error;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;

  /// Renders the value in the mono face. For paths, IDs and figures.
  final bool mono;

  /// Keeps an empty helper line in the layout so the form does not jump when
  /// an error appears. Off for a field in a tight toolbar.
  final bool reserveHelperSpace;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _ownsFocus = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focused != _focus.hasFocus) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final hasError = widget.error != null;
    final multiline = (widget.maxLines ?? 1) > 1;

    final border = !widget.enabled
        ? colors.borderDisabled
        : hasError
        ? colors.error
        : _focused
        ? colors.primary
        : colors.borderInteractive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppText.captionStrong.c(
              widget.enabled ? colors.textSecondary : colors.textDisabled,
            ),
          ),
          const SizedBox(height: Spacing.xs + 2),
        ],
        AnimatedContainer(
          duration: motion.fast,
          curve: AppEasing.standard,
          constraints: BoxConstraints(
            minHeight: multiline ? ControlSizes.lg : ControlSizes.lg,
          ),
          decoration: BoxDecoration(
            color: widget.enabled ? colors.surfaceSunken : Colors.transparent,
            borderRadius: Radii.mdAll,
            border: Border.all(
              color: border,
              width: _focused || hasError ? Strokes.focusRing : Strokes.hairline,
            ),
            // A 3 px halo on focus, so the ring is visible even where the
            // field sits against a same-coloured neighbour.
            boxShadow: _focused && widget.enabled
                ? [
                    BoxShadow(
                      color: (hasError ? colors.error : colors.focusRing)
                          .withValues(alpha: 0.18),
                      blurRadius: 0,
                      spreadRadius: Strokes.focusRing,
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: multiline
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (widget.prefixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: Spacing.md,
                    right: Spacing.sm,
                    top: Spacing.sm,
                    bottom: Spacing.sm,
                  ),
                  child: ExcludeSemantics(
                    child: Icon(
                      widget.prefixIcon,
                      size: IconSizes.sm,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: widget.prefixIcon == null ? Spacing.md : 0,
                    right: widget.suffix == null ? Spacing.md : Spacing.xs,
                    top: multiline ? Spacing.sm : 0,
                    bottom: multiline ? Spacing.sm : 0,
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    minLines: widget.minLines,
                    maxLines: widget.maxLines,
                    maxLength: widget.maxLength,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.inputFormatters,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    cursorColor: colors.primary,
                    cursorWidth: Strokes.focusRing,
                    style: (widget.mono ? AppText.mono : AppText.body).c(
                      widget.enabled ? colors.text : colors.textDisabled,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.placeholder,
                      hintStyle: AppText.body.c(colors.textTertiary),
                    ),
                  ),
                ),
              ),
              if (widget.suffix != null)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: widget.suffix,
                ),
            ],
          ),
        ),
        if (widget.helper != null || hasError || widget.reserveHelperSpace)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs, left: Spacing.xs),
            child: Semantics(
              liveRegion: hasError,
              child: Text(
                widget.error ?? widget.helper ?? '',
                style: AppText.caption.c(
                  hasError ? colors.error : colors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A search field: leading glyph, a clear button that only exists when there
/// is something to clear, and an optional shortcut hint on the right.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.placeholder = 'Cari…',
    this.focusNode,
    this.shortcut,
    this.dense = true,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final FocusNode? focusNode;

  /// Rendered as keycaps at the right edge, platform-aware.
  final AppShortcut? shortcut;

  final bool dense;
  final String? semanticLabel;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _ownsFocus = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _focus.addListener(_onFocus);
    widget.controller.addListener(_onText);
  }

  void _onFocus() {
    if (_focused != _focus.hasFocus) setState(() => _focused = _focus.hasFocus);
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    widget.controller.removeListener(_onText);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final hasText = widget.controller.text.isNotEmpty;

    return Semantics(
      textField: true,
      label: widget.semanticLabel ?? widget.placeholder,
      child: AnimatedContainer(
        duration: motion.fast,
        curve: AppEasing.standard,
        height: widget.dense ? ControlSizes.md : ControlSizes.lg,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: Radii.mdAll,
          border: Border.all(
            color: _focused ? colors.primary : colors.hairline,
            width: _focused ? Strokes.focusRing : Strokes.hairline,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: Spacing.sm),
            ExcludeSemantics(
              child: Icon(
                AppIcons.search,
                size: IconSizes.sm,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                onChanged: widget.onChanged,
                cursorColor: colors.primary,
                cursorWidth: Strokes.focusRing,
                style: AppText.body.c(colors.text),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: widget.placeholder,
                  hintStyle: AppText.body.c(colors.textTertiary),
                ),
              ),
            ),
            if (hasText)
              AppIconButton(
                icon: AppIcons.clear,
                tooltip: 'Bersihkan pencarian',
                size: IconSizes.xs,
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
              )
            else if (widget.shortcut != null)
              Padding(
                padding: const EdgeInsets.only(right: Spacing.sm),
                child: KeyHint(widget.shortcut!),
              )
            else
              const SizedBox(width: Spacing.sm),
          ],
        ),
      ),
    );
  }
}
