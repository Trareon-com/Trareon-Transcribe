/// WCAG 2.1 contrast maths, used both by the theme tests and by
/// `speakerColor` to pick a palette entry that is actually readable.
///
/// Kept in `lib/` rather than `test/` on purpose: a contrast rule that only
/// exists in a test can be satisfied by changing the test. Production code
/// that needs a readable colour calls the same function the gate does.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG AA minimum for normal-size body text.
const double kWcagAaNormalText = 4.5;

/// WCAG AA minimum for large text (>= 18pt, or >= 14pt bold) and for
/// non-text UI components such as borders, icons and focus rings.
const double kWcagAaLargeText = 3.0;

/// Relative luminance of [color] per WCAG 2.1, ignoring alpha.
double relativeLuminance(Color color) {
  double channel(double component) {
    return component <= 0.04045
        ? component / 12.92
        : math.pow((component + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Contrast ratio between [a] and [b], in the range 1.0 (identical) to
/// 21.0 (black on white). Order-independent.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Composites [foreground] over [background] and returns the contrast of the
/// result against [background]. Use this for semi-transparent foregrounds —
/// comparing the unblended colours overstates their contrast.
double contrastRatioBlended(Color foreground, Color background) {
  return contrastRatio(Color.alphaBlend(foreground, background), background);
}
