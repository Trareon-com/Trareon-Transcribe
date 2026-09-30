import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/theme/contrast.dart';
import 'package:transcribe/utils/speaker_color.dart';

/// The speaker accent is used as *text* colour for the speaker name on every
/// transcript row, so it is held to AA for normal text (4.5:1) — not the 3:1
/// component threshold. Six of the eight colours in the previous shared
/// palette were between 2.3:1 and 4.2:1 on the light transcript background.
void main() {
  for (final (theme, colors) in <(String, AppColorSet)>[
    ('light', AppColors.light),
    ('dark', AppColors.dark),
  ]) {
    group('$theme speaker palette', () {
      test('has eight distinct entries', () {
        expect(colors.speakerPalette, hasLength(8));
        expect(colors.speakerPalette.toSet(), hasLength(8));
      });

      for (var i = 0; i < colors.speakerPalette.length; i++) {
        final color = colors.speakerPalette[i];
        final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');

        test('entry $i ($hex) is AA on the transcript background', () {
          final ratio = contrastRatio(color, colors.transcriptBackground);
          expect(
            ratio,
            greaterThanOrEqualTo(kWcagAaNormalText),
            reason:
                '$theme speaker colour $hex is ${ratio.toStringAsFixed(2)}:1 '
                'on the transcript background',
          );
        });

        test('entry $i ($hex) is AA on the app background', () {
          final ratio = contrastRatio(color, colors.background);
          expect(
            ratio,
            greaterThanOrEqualTo(kWcagAaNormalText),
            reason: '$theme speaker colour $hex on background',
          );
        });

        test('entry $i ($hex) is AA on its own avatar tint', () {
          // SpeakerAvatar fills the circle with the accent at 15% over the
          // surface and then draws the initials in the accent itself.
          final tint = Color.alphaBlend(
            color.withValues(alpha: 0.15),
            colors.surface,
          );
          final ratio = contrastRatio(color, tint);
          expect(
            ratio,
            greaterThanOrEqualTo(kWcagAaNormalText),
            reason:
                '$theme speaker colour $hex on its avatar tint is '
                '${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });
  }

  test('speakerColor is stable for a given name', () {
    expect(
      speakerColor('Pembicara 1', AppColors.light),
      equals(speakerColor('Pembicara 1', AppColors.light)),
    );
    // FNV-1a is fixed by construction, so this pins the mapping: if the hash
    // or the palette order changes, existing sessions change colour.
    expect(speakerHash(''), 0x811c9dc5);
    expect(speakerHash('MIC'), isNot(equals(speakerHash('SPK'))));
  });

  test('speakerColor always returns a palette entry of the active theme', () {
    for (final name in ['MIC', 'SPK', 'Pembicara 1', 'Budi', 'Siti Aminah']) {
      expect(
        AppColors.light.speakerPalette,
        contains(speakerColor(name, AppColors.light)),
      );
      expect(
        AppColors.dark.speakerPalette,
        contains(speakerColor(name, AppColors.dark)),
      );
    }
  });

  test('an unnamed speaker falls back to the theme primary', () {
    expect(speakerColor('', AppColors.light), AppColors.light.primary);
    expect(speakerColor('', AppColors.dark), AppColors.dark.primary);
  });
}
