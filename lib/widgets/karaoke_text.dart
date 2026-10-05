import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';

/// A transcript line rendered word by word, from Whisper's word timestamps.
///
/// Three things the plain `Text` it replaces could not do:
///
/// * **Karaoke highlight** — the word being spoken right now is picked out,
///   so a notulis checking a long meeting can see where in the line the
///   audio is rather than only which line.
/// * **Click a word to seek** — the ordinary way to re-listen to a phrase
///   you are not sure the engine heard correctly. Seeking to the start of
///   the whole segment means hearing twenty words to check one.
/// * **Low-confidence underline** — a wavy underline under the words
///   Whisper itself was unsure of. This is the same signal the "Tinjau"
///   filter uses at segment level, at the resolution the correction
///   actually happens at.
///
/// Falls back to [fallbackText] when there are no word timings: every
/// transcript written before Sprint 4b, and any segment the user has
/// edited by hand (the typed words were never aligned to the audio, so
/// keeping the old spans would highlight the wrong word).
class KaraokeText extends StatefulWidget {
  final List<TranscriptWord> words;

  /// Used when [words] is empty.
  final String fallbackText;

  /// Lowercased search term to highlight, or empty.
  final String searchQuery;

  final TextStyle baseStyle;

  /// Colour of the search-match highlight. The speaker's colour, so a
  /// match reads as belonging to the row it is in.
  final Color searchHighlight;

  /// Playhead position in recording seconds, or `null` when nothing is
  /// playing — in which case no word is highlighted.
  final double? positionSecs;

  /// Seek here. `null` disables click-to-seek (the live-recording view,
  /// where there is nothing to seek in yet).
  final void Function(TranscriptWord word)? onTapWord;

  const KaraokeText({
    super.key,
    required this.words,
    required this.fallbackText,
    required this.baseStyle,
    required this.searchHighlight,
    this.searchQuery = '',
    this.positionSecs,
    this.onTapWord,
  });

  @override
  State<KaraokeText> createState() => _KaraokeTextState();
}

class _KaraokeTextState extends State<KaraokeText> {
  /// One recognizer per word, rebuilt only when the word list changes.
  ///
  /// `TextSpan.recognizer` does not own its recognizer, so building them
  /// inline in `build` would leak one per word per frame — and this is the
  /// most frequently rebuilt text in the app (the active row rebuilds on
  /// every position tick).
  List<TapGestureRecognizer> _recognizers = const [];

  @override
  void initState() {
    super.initState();
    _rebuildRecognizers();
  }

  @override
  void didUpdateWidget(KaraokeText old) {
    super.didUpdateWidget(old);
    final sameLength = old.words.length == widget.words.length;
    final sameHandler = (old.onTapWord == null) == (widget.onTapWord == null);
    if (!sameLength || !sameHandler) _rebuildRecognizers();
  }

  void _rebuildRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    if (widget.onTapWord == null) {
      _recognizers = const [];
      return;
    }
    _recognizers = List.generate(
      widget.words.length,
      (index) => TapGestureRecognizer()
        ..onTap = () {
          // Read the word off the *current* widget: the recognizers
          // outlive a rebuild that only changed timings.
          if (index < widget.words.length) {
            widget.onTapWord?.call(widget.words[index]);
          }
        },
    );
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    if (widget.words.isEmpty) {
      return Text.rich(
        TextSpan(
          children: highlightQuery(
            widget.fallbackText,
            widget.searchQuery,
            widget.baseStyle,
            widget.searchHighlight,
          ),
        ),
      );
    }

    final position = widget.positionSecs;
    final spans = <InlineSpan>[];
    for (var index = 0; index < widget.words.length; index++) {
      final word = widget.words[index];
      final isActive = position != null && word.contains(position);
      var style = widget.baseStyle;
      if (word.isLowConfidence) {
        style = style.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: colors.warning,
        );
      }
      if (isActive) {
        style = style.copyWith(
          backgroundColor: colors.primarySubtle,
          color: colors.primaryText,
          fontWeight: FontWeight.w600,
        );
      }
      if (index > 0) {
        spans.add(TextSpan(text: ' ', style: widget.baseStyle));
      }
      spans.addAll(
        highlightQuery(
          word.word,
          widget.searchQuery,
          style,
          widget.searchHighlight,
          recognizer: index < _recognizers.length ? _recognizers[index] : null,
        ),
      );
    }
    return Text.rich(TextSpan(children: spans));
  }
}

/// Splits `text` into spans with every occurrence of `query` highlighted.
///
/// Shared with the plain (no word timings) path so a search match looks the
/// same whichever renderer drew the line. `recognizer` is attached to every
/// resulting span, so tapping the highlighted part of a word seeks as
/// readily as tapping the rest of it.
List<TextSpan> highlightQuery(
  String text,
  String query,
  TextStyle baseStyle,
  Color highlightColor, {
  GestureRecognizer? recognizer,
}) {
  if (query.isEmpty) {
    return [TextSpan(text: text, style: baseStyle, recognizer: recognizer)];
  }

  final lower = text.toLowerCase();
  final results = <TextSpan>[];
  int start = 0;

  while (true) {
    final index = lower.indexOf(query, start);
    if (index == -1) {
      results.add(
        TextSpan(
          text: text.substring(start),
          style: baseStyle,
          recognizer: recognizer,
        ),
      );
      break;
    }
    if (index > start) {
      results.add(
        TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
          recognizer: recognizer,
        ),
      );
    }
    results.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle.copyWith(
          backgroundColor: highlightColor.withValues(alpha: 0.4),
          fontWeight: FontWeight.w600,
        ),
        recognizer: recognizer,
      ),
    );
    start = index + query.length;
  }
  return results;
}
