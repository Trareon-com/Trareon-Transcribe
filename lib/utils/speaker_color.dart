import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Stable 32-bit FNV-1a hash of [name].
///
/// `String.hashCode` is not specified to be stable across Dart releases or
/// isolates, which for a speaker palette means the same meeting can render
/// "Pembicara 1" teal today and red after an SDK bump. This is stable by
/// construction, so a session keeps its colours.
@visibleForTesting
int speakerHash(String name) {
  var hash = 0x811c9dc5;
  for (final unit in name.codeUnits) {
    hash ^= unit & 0xff;
    hash = (hash * 0x01000193) & 0xffffffff;
    if (unit > 0xff) {
      hash ^= (unit >> 8) & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
  }
  return hash;
}

/// The accent used for [name] throughout the transcript: the speaker label
/// text, the avatar initials, the timeline strip and the search highlight.
///
/// The palette comes from the active [AppColorSet] rather than being a
/// module-level constant, because the same colour cannot be legible on both
/// the light and dark transcript background — the previous shared palette
/// failed WCAG AA on 6 of its 8 entries in light mode, on the app's
/// most-repeated text.
Color speakerColor(String name, AppColorSet colors) {
  if (name.isEmpty) return colors.primary;
  final palette = colors.speakerPalette;
  return palette[speakerHash(name) % palette.length];
}
